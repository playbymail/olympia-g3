#!/usr/bin/env python3
"""Ultron loop driver (#106): run N turns of brain-picked orders.

Wires steps 1-6 of the harness loop (doc/ultron-harness-architecture.md §4):

  1. export state      olympia-g3 -l lib --state-export turn-NNN/state.json
  2. brain             tests/ultron/brain/chaos_goblin.py picks orders
  3. order files       written into lib/orders/*, copied to turn-NNN/orders/
  4. run the turn      olympia-g3 -r -l lib -S --coverage turn-NNN/coverage.tsv
  5. read coverage     summed into coverage-total.tsv
  6. next targets      coverage-total.tsv is the brain's --coverage next turn

The scenario (a scenario.tgz, or an olyscript-g3 .lua run on the bare-map
fixture) is unpacked into a scratch work directory, by default
run/ultron/<scenario>-s<seed>. Nothing is written into the golden trees.

On a failure (non-zero exit, a signal, an assert, a sanitizer diagnostic, or a
timeout) the loop stops and freezes the pre-turn lib, orders included, as a
candidate regress fixture under <work>/fixtures/<name>/, with a check.sh that
replays it. Post-#25 a turn depends only on (master seed, order files), so
that is enough to reproduce it.

Same seed and scenario give identical per-turn order files and coverage.
"""

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRAIN = os.path.join(HERE, "brain", "chaos_goblin.py")
BACKLOG = os.path.join(HERE, "backlog.tsv")
BARE_MAP = os.path.join(ROOT, "tests", "olympia", "fixtures", "lib.tgz")
OUTCOMES = ("rejected", "unimplemented", "ok", "fail")
CONST_DATE = "test-use-const-report-date"

ASAN_RE = re.compile(r"ERROR: (Address|Leak)Sanitizer: ([A-Za-z-]+)")
UBSAN_RE = re.compile(r"runtime error:")
ASSERT_RE = re.compile(r"Assertion failed: .*?file (\S+?), line (\d+)"
                       r"|(\S+?):(\d+): .*Assertion .* failed")


def rel(path):
    """Repo-relative path when under the repo, for the frozen metadata."""
    p = os.path.abspath(path)
    return os.path.relpath(p, ROOT) if p.startswith(ROOT + os.sep) else p


def scenario_name(path):
    base = os.path.basename(path)
    if base == "scenario.tgz":
        return os.path.basename(os.path.dirname(os.path.abspath(path)))
    return base.split(".")[0]


def unpack_scenario(path, work, script_bin):
    if path.endswith(".lua"):
        with tarfile.open(BARE_MAP) as t:
            t.extractall(work, filter="data")
        master = os.path.join(work, "lib", "master")
        if os.path.exists(master):
            os.remove(master)
        r = subprocess.run([script_bin, os.path.abspath(path)], cwd=work,
                           stdin=subprocess.DEVNULL, capture_output=True)
        if r.returncode != 0:
            sys.exit("loop: %s failed:\n%s" % (path, r.stderr.decode(
                "latin-1")))
    else:
        with tarfile.open(path) as t:
            t.extractall(work, filter="data")
    if not os.path.isdir(os.path.join(work, "lib")):
        sys.exit("loop: %s has no lib/" % path)
    os.makedirs(os.path.join(work, "lib", "orders"), exist_ok=True)


def classify(rc, log):
    """Return a failure signature, or None for a clean run."""
    m = ASAN_RE.search(log)
    if m:
        return "asan-" + m.group(2).lower()
    if UBSAN_RE.search(log):
        return "ubsan"
    m = ASSERT_RE.search(log)
    if m:
        f, line = (m.group(1), m.group(2)) if m.group(1) else \
            (m.group(3), m.group(4))
        return "assert-%s-%s" % (os.path.basename(f),
                                 line)
    if rc == "timeout":
        return "timeout"
    if rc < 0:
        try:
            return signal.Signals(-rc).name.lower()
        except ValueError:
            return "signal%d" % -rc
    if rc != 0:
        return "exit%d" % rc
    return None


def run_engine(argv, cwd, timeout):
    try:
        r = subprocess.run(argv, cwd=cwd, stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout)
        return r.returncode, r.stdout.decode("latin-1")
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode("latin-1") if e.stdout else ""
        return "timeout", out


def read_coverage(path):
    cov = {}
    with open(path, encoding="latin-1") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            row = dict(zip(header, line.rstrip("\n").split("\t")))
            cov[row["verb"]] = [int(row[o]) for o in OUTCOMES]
    return cov


def write_coverage(path, cov):
    with open(path, "w", encoding="latin-1", newline="\n") as f:
        f.write("verb\t" + "\t".join(OUTCOMES) + "\n")
        for verb in sorted(cov):
            f.write(verb + "\t" + "\t".join(str(n) for n in cov[verb]) + "\n")


def add_coverage(total, cov):
    for verb, counts in cov.items():
        t = total.setdefault(verb, [0] * len(OUTCOMES))
        for i, n in enumerate(counts):
            t[i] += n


def copy_orders(lib, dst):
    src = os.path.join(lib, "orders")
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if name[:1].isdigit():
            shutil.copyfile(os.path.join(src, name), os.path.join(dst, name))


CHECK_SH = """#!/bin/bash
# Replays a failure the Ultron loop driver froze (tests/ultron/loop.py).
# Prints YES while the turn still fails with the frozen signature (see
# meta.json), NO once it no longer does. Uses OLYMPIA_PRESET (default: the
# preset the failure was found on).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "${HERE}" rev-parse --show-toplevel 2>/dev/null)" ||
	ROOT="%s"	# the repo the failure was frozen from
exec python3 "${ROOT}/tests/ultron/loop.py" --replay "${HERE}"
"""


def freeze(work, snapshot, meta, log):
    name = "ultron-%s-s%d-t%03d-%s" % (meta["scenario"], meta["seed"],
                                      meta["turn"], meta["signature"])
    fx = os.path.join(work, "fixtures", name)
    if os.path.exists(fx):
        shutil.rmtree(fx)
    os.makedirs(fx)
    with tarfile.open(os.path.join(fx, "scenario.tgz"), "w:gz") as t:
        t.add(os.path.join(snapshot, "lib"), arcname="lib")
    copy_orders(os.path.join(snapshot, "lib"), os.path.join(fx, "orders"))
    with open(os.path.join(fx, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")
    with open(os.path.join(fx, "failure.log"), "w", encoding="latin-1") as f:
        f.write(log)
    with open(os.path.join(fx, "check.sh"), "w") as f:
        f.write(CHECK_SH % ROOT)
    os.chmod(os.path.join(fx, "check.sh"), 0o755)
    return fx


def engine_path(engine, preset):
    if engine:
        return os.path.abspath(os.path.join(ROOT, engine)
                               if not os.path.isabs(engine) else engine)
    return os.path.join(ROOT, "build", preset, "olympia-g3")


def replay(fx):
    with open(os.path.join(fx, "meta.json")) as f:
        meta = json.load(f)
    preset = os.environ.get("OLYMPIA_PRESET", meta["preset"])
    eng = engine_path(meta.get("engine"), preset)
    scratch = os.path.join(fx, ".replay")
    if os.path.exists(scratch):
        shutil.rmtree(scratch)
    os.makedirs(scratch)
    try:
        with tarfile.open(os.path.join(fx, "scenario.tgz")) as t:
            t.extractall(scratch, filter="data")
        env = dict(os.environ, OLYMPIA_PRESET=preset)
        argv = [eng] + meta["args"]
        r = subprocess.run(argv, cwd=scratch, stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           env=env, timeout=meta.get("timeout"))
        sig = classify(r.returncode, r.stdout.decode("latin-1"))
    except subprocess.TimeoutExpired:
        sig = "timeout"
    finally:
        shutil.rmtree(scratch)
    if sig == meta["signature"]:
        print("YES")
        return 0
    print("NO  (got %s, frozen %s)" % (sig or "a clean run",
                                       meta["signature"]))
    return 1


def summarize(total, out):
    """Backlog cells still todo that this run hit at least once."""
    idx = {"ok": 2, "rejected": 0, "fail": 3}
    hit = []
    with open(BACKLOG, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            row = dict(zip(header, line.rstrip("\n").split("\t")))
            counts = total.get(row["verb"])
            if counts is None:
                continue
            for o in ("ok", "rejected", "fail"):
                if row.get(o) == "todo" and counts[idx[o]] > 0:
                    hit.append((row["verb"], o, counts[idx[o]]))
    with open(out, "w", newline="\n") as f:
        f.write("verb\toutcome\tcount\n")
        for verb, o, n in hit:
            f.write("%s\t%s\t%d\n" % (verb, o, n))
    fired = sum(1 for c in total.values() if sum(c) > 0)
    print("coverage: %d verbs fired; %d backlog todo cells newly hit "
          "(%s)" % (fired, len(hit), rel(out)))
    for o in ("ok", "rejected", "fail"):
        verbs = [v for v, oo, _ in hit if oo == o]
        if verbs:
            print("  %-8s %d: %s" % (o, len(verbs), " ".join(verbs)))


def parse_inject(spec):
    turn, faction, unit, order = spec.split(":", 3)
    return int(turn), int(faction), int(unit), order


def main(argv):
    ap = argparse.ArgumentParser(
        description="Ultron loop driver: run N turns of brain-picked orders "
                    "and freeze any failure as a fixture (#106).")
    ap.add_argument("--scenario",
                    help="scenario.tgz, or an olyscript-g3 .lua")
    ap.add_argument("--turns", type=int, default=3,
                    help="turns to run (default 3)")
    ap.add_argument("--seed", type=int, default=1,
                    help="brain seed (default 1)")
    ap.add_argument("--work",
                    help="work directory (default run/ultron/<scenario>-s<seed>)")
    ap.add_argument("--force", action="store_true",
                    help="replace an existing work directory")
    ap.add_argument("--preset", default=os.environ.get("OLYMPIA_PRESET",
                                                       "debug"),
                    help="build preset (default $OLYMPIA_PRESET or debug)")
    ap.add_argument("--engine",
                    help="engine to run in place of build/<preset>/olympia-g3")
    ap.add_argument("--orders-per-unit", type=int, default=8)
    ap.add_argument("--allow", action="append", default=[],
                    metavar="VERB[,VERB...]",
                    help="passed to the brain: re-enable a default-excluded "
                         "verb; repeatable")
    ap.add_argument("--exclude", action="append", default=[],
                    metavar="VERB[,VERB...]",
                    help="passed to the brain: never pick VERB; repeatable")
    ap.add_argument("--timeout", type=int, default=600,
                    help="seconds before a run counts as a hang")
    ap.add_argument("--inject", action="append", default=[],
                    metavar="TURN:FACTION:UNIT:ORDER",
                    help="append a raw order line to a faction's orders on "
                         "a turn, after the brain")
    ap.add_argument("--replay", metavar="FIXTURE",
                    help="replay a frozen fixture; YES while it still fails")
    a = ap.parse_args(argv)

    if a.replay:
        return replay(os.path.abspath(a.replay))
    if not a.scenario:
        ap.error("--scenario is required")

    eng = engine_path(a.engine, a.preset)
    script_bin = os.path.join(ROOT, "build", a.preset, "olyscript-g3")
    if not os.access(eng, os.X_OK):
        sys.exit("loop: missing %s (build the %s preset first)" %
                 (eng, a.preset))
    name = scenario_name(a.scenario)
    work = os.path.abspath(a.work or os.path.join(
        ROOT, "run", "ultron", "%s-s%d" % (name, a.seed)))
    if os.path.realpath(work).startswith(os.path.join(ROOT, "tests") + os.sep):
        sys.exit("loop: refusing a work directory under tests/")
    if os.path.exists(work):
        if not a.force:
            sys.exit("loop: %s exists (pass --force to replace it)" % work)
        shutil.rmtree(work)
    os.makedirs(work)
    unpack_scenario(a.scenario, work, script_bin)
    injects = [parse_inject(s) for s in a.inject]

    lib = os.path.join(work, "lib")
    snapshot = os.path.join(work, ".pre-turn")
    total = {}
    total_path = os.path.join(work, "coverage-total.tsv")
    os.environ["OLYMPIA_PRESET"] = a.preset  # for an --engine wrapper
    print("loop: %s, seed %d, %d turns, %s -> %s" %
          (rel(a.scenario), a.seed, a.turns, a.preset, rel(work)))

    for turn in range(1, a.turns + 1):
        td = os.path.join(work, "turn-%03d" % turn)
        os.makedirs(td)
        meta = {"scenario": name, "source": rel(a.scenario), "seed": a.seed,
                "turn": turn, "preset": a.preset, "timeout": a.timeout,
                "engine": rel(a.engine) if a.engine else None}

        # 1. state export
        state = os.path.join(td, "state.json")
        args = ["-l", "./lib", CONST_DATE, "--state-export", state]
        if os.path.exists(snapshot):
            shutil.rmtree(snapshot)
        shutil.copytree(lib, os.path.join(snapshot, "lib"))
        rc, log = run_engine([eng] + args, work, a.timeout)
        sig = classify(rc, log)
        if sig is None and not os.path.exists(state):
            sig = "no-export"
        if sig:
            meta.update(phase="export", signature=sig,
                        args=["-l", "./lib", CONST_DATE, "--state-export",
                              "state.json"])
            return failed(work, snapshot, meta, log, turn)

        # 2-3. brain writes lib/orders/*
        r = subprocess.run([sys.executable, BRAIN, "--state", state,
                            "--out", os.path.join(lib, "orders"),
                            "--seed", str(a.seed * 1000003 + turn),
                            "--orders-per-unit", str(a.orders_per_unit)] +
                           (["--coverage", total_path] if total else []) +
                           [x for v in a.allow for x in ("--allow", v)] +
                           [x for v in a.exclude for x in ("--exclude", v)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("loop: brain failed on turn %d:\n%s" % (turn, r.stderr))
        for t, faction, unit, order in injects:
            if t == turn:
                with open(os.path.join(lib, "orders", str(faction)), "a",
                          encoding="latin-1", newline="\n") as f:
                    f.write("%d:%s\n" % (unit, order))
        copy_orders(lib, os.path.join(td, "orders"))

        # 4. run the turn on a snapshot-backed lib
        if os.path.exists(snapshot):
            shutil.rmtree(snapshot)
        shutil.copytree(lib, os.path.join(snapshot, "lib"))
        cov = os.path.join(td, "coverage.tsv")
        args = ["-r", "-l", "./lib", "-S", CONST_DATE]
        rc, log = run_engine([eng] + args + ["--coverage", cov], work,
                             a.timeout)
        with open(os.path.join(td, "turn.log"), "w", encoding="latin-1") as f:
            f.write(log)
        sig = classify(rc, log)
        if sig is None and not os.path.exists(cov):
            sig = "no-coverage"
        if sig:
            meta.update(phase="turn", signature=sig, args=args)
            return failed(work, snapshot, meta, log, turn)

        # 5-6. fold coverage in; it steers the next turn's picks
        this = read_coverage(cov)
        add_coverage(total, this)
        write_coverage(total_path, total)
        print("turn %d: ok, %d verbs fired" %
              (turn, sum(1 for c in this.values() if sum(c) > 0)))

    shutil.rmtree(snapshot, ignore_errors=True)
    summarize(total, os.path.join(work, "newly-hit.tsv"))
    return 0


def failed(work, snapshot, meta, log, turn):
    fx = freeze(work, snapshot, meta, log)
    shutil.rmtree(snapshot, ignore_errors=True)
    print("turn %d: FAILED in %s (%s)" % (turn, meta["phase"],
                                          meta["signature"]))
    print("froze %s" % rel(fx))
    print("replay: %s/check.sh" % rel(fx))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
