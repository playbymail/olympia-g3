#!/usr/bin/env python3
"""Chaos Goblin: the first Ultron brain (#105).

Reads an engine state export (--state-export), the fixture backlog
(tests/ultron/backlog.tsv) and, optionally, the latest coverage dump
(--coverage), and writes one plain player order file per faction in the
export: <out>/<faction id>, one "<unit>:<order>" per line (order.c:248).

The goblin "selects legal but unexpected actions". It picks a (verb, outcome)
cell for every order, weighted toward cells the backlog still marks todo or
the coverage dump counts as zero, then shapes the order toward that outcome:

  ok        plausible arguments drawn from the state, issued by a unit
  rejected  issued by an entity the verb's allow string excludes (a faction
            issuing a unit-only verb, or a unit issuing a faction-only one)
  fail      garbled arguments, issued by a unit

The state informs the pick; it does not gate it. Illegal orders are coverage
too (doc/ultron-harness-architecture.md §2.2).

Hard rule: the output is order files only, run by the normal -r -S turn.
This script never links against, calls, or drives the engine.

Reproducible: the same seed and inputs give byte-identical order files.
Nothing here iterates a set or hashes a string, so PYTHONHASHSEED is moot.
"""

import argparse
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_BACKLOG = os.path.join(HERE, "..", "backlog.tsv")

OUTCOMES = ("ok", "rejected", "fail")

# Families with no player-order-path fixture wanted (backlog "n/a" rows).
SKIP_FAMILIES = ("gm-immediate", "directive")

# Verbs the goblin leaves alone unless asked: QUIT drops the faction, which
# ends the run for every later turn of the loop.
DEFAULT_EXCLUDE = ("quit",)

# Argument templates per verb. Tokens are filled from the state:
#   UNIT  another character the unit can see (else any known unit)
#   SELF  the issuing unit
#   FACT  a faction id
#   ITEM  an item the unit holds (else any known item)
#   QTY   1..held quantity of the last ITEM
#   NUM   a small number
#   GOLD  1..the unit's gold
#   SKILL a skill the unit knows (else any known skill)
#   LOC   an exit destination or the unit's location
#   DIR   a direction with an exit from the unit's location
#   BUILD a buildable structure kind
#   WAIT  a WAIT condition
#   TEXT  a word of flavour text
# A verb with several templates picks one; "" means no arguments.
TEMPLATES = {
    "accept": ["UNIT ITEM QTY", "0 ITEM"],
    "admit": ["UNIT UNIT", "UNIT"],
    "attack": ["UNIT", "LOC"],
    "banner": ["TEXT"],
    "behind": ["NUM"],
    "bind": ["UNIT", ""],
    "board": ["LOC"],
    "breed": ["ITEM ITEM"],
    "bribe": ["UNIT GOLD"],
    "build": ["BUILD", "BUILD NUM"],
    "buy": ["ITEM QTY GOLD"],
    "catch": ["NUM", ""],
    "claim": ["ITEM QTY", "ITEM"],
    "collect": ["ITEM QTY", "ITEM"],
    "contact": ["UNIT", "FACT"],
    "credit": ["UNIT GOLD"],
    "decree": ["watch UNIT", "hostile UNIT"],
    "default": ["UNIT", "FACT"],
    "defend": ["UNIT", "FACT"],
    "die": [""],
    "discard": ["ITEM QTY", "ITEM"],
    "drop": ["ITEM QTY", "ITEM"],
    "emote": ["UNIT TEXT"],
    "execute": ["UNIT", ""],
    "explore": [""],
    "fee": ["GOLD"],
    "ferry": [""],
    "fish": ["NUM", ""],
    "flag": ["TEXT"],
    "fly": ["DIR", "LOC"],
    "forget": ["SKILL"],
    "form": ["NUM", ""],
    "format": ["NUM", ""],
    "garrison": [""],
    "get": ["UNIT ITEM QTY", "UNIT ITEM"],
    "give": ["UNIT ITEM QTY", "UNIT ITEM"],
    "go": ["DIR", "LOC"],
    "guard": ["1", "0"],
    "hide": ["1", "0"],
    "honor": ["NUM"],
    "honour": ["NUM"],
    "hostile": ["UNIT", "FACT"],
    "improve": ["", "LOC"],
    "incite": ["UNIT UNIT", "UNIT"],
    "make": ["ITEM QTY", "ITEM"],
    "mallorn": ["NUM", ""],
    "message": ["1 UNIT"],
    "move": ["DIR", "LOC"],
    "name": ["TEXT"],
    "neutral": ["UNIT", "FACT"],
    "notab": ["1", "0"],
    "oath": ["NUM"],
    "opium": ["NUM", ""],
    "pay": ["UNIT GOLD"],
    "pillage": ["", "1"],
    "pledge": ["UNIT"],
    "plugh": [""],
    "post": ["1"],
    "press": ["1"],
    "promote": ["UNIT"],
    "public": ["1", "0"],
    "quarry": ["NUM", ""],
    "quest": [""],
    "quit": [""],
    "raise": [""],
    "rally": [""],
    "raze": ["", "LOC"],
    "realname": ["TEXT"],
    "reclaim": ["ITEM QTY", "ITEM"],
    "recruit": ["NUM", ""],
    "relore": ["UNIT SKILL"],
    "repair": [""],
    "research": ["SKILL"],
    "rumor": ["1"],
    "sail": ["DIR", "LOC"],
    "seek": ["UNIT", ""],
    "sell": ["ITEM QTY GOLD"],
    "sneak": ["LOC"],
    "split": ["NUM NUM"],
    "stack": ["UNIT"],
    "stone": ["NUM", ""],
    "stop": [""],
    "study": ["SKILL"],
    "surrender": ["UNIT"],
    "swear": ["UNIT"],
    "take": ["UNIT ITEM QTY", "UNIT ITEM"],
    "terrorize": ["UNIT NUM"],
    "times": ["1", "0"],
    "torture": ["UNIT"],
    "train": ["ITEM QTY", "ITEM"],
    "trance": [""],
    "unload": [""],
    "ungarrison": [""],
    "unstack": ["UNIT", ""],
    "use": ["SKILL", "SKILL ITEM", "ITEM"],
    "wait": ["WAIT"],
    "wood": ["NUM", ""],
    "xyzzy": [""],
    "yew": ["NUM", ""],
}

# Compass and enter/exit verbs take no arguments, or a destination.
for _v in ("north", "n", "south", "s", "east", "e", "west", "w",
       "exit", "out"):
    TEMPLATES[_v] = [""]
for _v in ("enter", "in"):
    TEMPLATES[_v] = ["LOC", ""]

BUILD_KINDS = ("galley", "roundship", "raft", "temple", "inn", "castle",
           "mine", "tower")
WAIT_CONDS = ("time NUM", "day NUM", "unit UNIT", "gold GOLD", "item ITEM QTY",
          "flag TEXT", "loc LOC", "stack UNIT", "top", "ship LOC", "rain",
          "fog", "wind", "not rain", "owner", "clear", "month NUM",
          "turn NUM")
WORDS = ("goblin", "mischief", "turnip", "Hello", "bogus", "snarl")
JUNK = ("", "0", "-1", "99999", "xyzzy", "none", "all", "1e9", "?")

# Per-cell weights. A cell is one (verb, outcome) pair.
W_BASE = 1.0
W_TODO = 4.0        # backlog cell is todo
W_ZERO = 4.0        # latest coverage counts it zero
ALIAS_FACTOR = 0.5  # an alias shares its target's start function


def load_backlog(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            cols = line.rstrip("\n").split("\t")
            rows.append(dict(zip(header, cols)))
    return rows


def load_coverage(path):
    cov = {}
    if path is None:
        return None
    with open(path, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            cols = line.rstrip("\n").split("\t")
            row = dict(zip(header, cols))
            cov[row["verb"]] = {o: int(row.get(o, "0")) for o in OUTCOMES}
    return cov


def can_reject(allow):
    """A rejection is reachable when units or factions are excluded."""
    return "c" not in allow or "p" not in allow


def build_cells(backlog, coverage, exclude):
    """Return [(verb, outcome, allow, weight)] in backlog order."""
    cells = []
    for row in backlog:
        verb = row["verb"]
        if row["family"] in SKIP_FAMILIES or verb in exclude:
            continue
        if verb not in TEMPLATES:
            continue
        for outcome in OUTCOMES:
            if outcome == "rejected" and not can_reject(row["allow"]):
                continue
            w = W_BASE
            if row.get(outcome) == "todo":
                w += W_TODO
            if coverage is not None and \
               coverage.get(verb, {}).get(outcome, 0) == 0:
                w += W_ZERO
            if row.get("alias_of"):
                w *= ALIAS_FACTOR
            cells.append((verb, outcome, row["allow"], w))
    return cells


class World:
    """Pools of ids drawn from the whole export, in first-seen order."""

    def __init__(self, state):
        self.locs = {}
        self.units = []
        self.factions = []
        self.items = []
        self.skills = []
        for fac in state.get("factions", []):
            self.factions.append(fac["id"])
            for loc in fac.get("locations", []):
                self.locs[loc["id"]] = loc
                for h in loc.get("here", []):
                    self._add(self.units, h["id"])
                    self._add(self.factions, h["faction"])
            for u in fac.get("units", []):
                self._add(self.units, u["id"])
                for it in u.get("items", []):
                    self._add(self.items, it["id"])
                for sk in u.get("skills", []):
                    self._add(self.skills, sk["id"])

    @staticmethod
    def _add(lst, v):
        if v not in lst:
            lst.append(v)


class Goblin:
    def __init__(self, rng, world, cells):
        self.rng = rng
        self.world = world
        self.cells = cells
        self.weights = [c[3] for c in cells]

    def pick_cell(self):
        return self.rng.choices(self.cells, weights=self.weights)[0]

    def _pool_or(self, mine, pool):
        if mine and self.rng.random() < 0.8:
            return self.rng.choice(mine)
        if pool:
            return self.rng.choice(pool)
        return self.rng.randrange(1, 100000)

    def fill(self, template, unit):
        rng = self.rng
        loc = self.world.locs.get(unit["where"], {})
        exits = loc.get("exits", [])
        others = [h["id"] for h in loc.get("here", [])
              if h["id"] != unit["id"]]
        items = unit.get("items", [])
        gold = next((it["qty"] for it in items if it["id"] == 1), 0)
        last_qty = 1
        out = []
        for tok in template.split():
            if tok == "UNIT":
                out.append(self._pool_or(others, self.world.units))
            elif tok == "SELF":
                out.append(unit["id"])
            elif tok == "FACT":
                out.append(rng.choice(self.world.factions))
            elif tok == "ITEM":
                if items and rng.random() < 0.8:
                    it = rng.choice(items)
                    last_qty = it["qty"]
                    out.append(it["id"])
                else:
                    out.append(self._pool_or([],
                            self.world.items))
            elif tok == "QTY":
                out.append(rng.randint(1, max(1, last_qty)))
            elif tok == "NUM":
                out.append(rng.randint(0, 12))
            elif tok == "GOLD":
                out.append(rng.randint(1, max(1, gold)))
            elif tok == "SKILL":
                out.append(self._pool_or(
                    [s["id"] for s in unit.get("skills", [])],
                    self.world.skills))
            elif tok == "LOC":
                out.append(self._pool_or(
                    [x["destination"] for x in exits] +
                    [unit["where"]], list(self.world.locs)))
            elif tok == "DIR":
                if exits and rng.random() < 0.8:
                    out.append(rng.choice(exits)["direction"])
                else:
                    out.append(rng.choice(("north", "east",
                        "south", "west", "up", "down",
                        "in", "out")))
            elif tok == "BUILD":
                out.append(rng.choice(BUILD_KINDS))
            elif tok == "WAIT":
                out.append(self.fill(rng.choice(WAIT_CONDS), unit))
            elif tok == "TEXT":
                out.append(rng.choice(WORDS))
            else:
                out.append(tok)
        return " ".join(str(x) for x in out)

    def garble(self, args):
        """Bend arguments out of shape to steer toward a fail."""
        rng = self.rng
        toks = args.split()
        r = rng.random()
        if not toks or r < 0.3:
            toks.append(rng.choice(JUNK) or "xyzzy")
        elif r < 0.6:
            toks[rng.randrange(len(toks))] = rng.choice(JUNK)
        elif r < 0.8:
            toks = toks[:rng.randrange(len(toks))]
        else:
            toks[rng.randrange(len(toks))] = \
                str(rng.randrange(1, 200000))
        return " ".join(t for t in toks if t)

    def order(self, faction, unit):
        """Return (issuer, order text) for one pick."""
        verb, outcome, allow, _ = self.pick_cell()
        args = self.fill(self.rng.choice(TEMPLATES[verb]), unit)
        issuer = unit["id"]
        if outcome == "rejected":
            # check_allow() keys on the issuer's kind: 'c' for a
            # unit, 'p' for a faction. Issue it from one excluded.
            if "c" in allow:
                issuer = faction["id"]
        elif outcome == "ok" and "c" not in allow and "p" in allow:
            issuer = faction["id"]
        elif outcome == "fail":
            args = self.garble(args)
        return issuer, (verb + " " + args).strip()


def write_orders(goblin, state, out_dir, per_unit):
    written = []
    for fac in state.get("factions", []):
        lines = []
        for unit in fac.get("units", []):
            for _ in range(per_unit):
                issuer, text = goblin.order(fac, unit)
                lines.append("%d:%s\n" % (issuer, text))
        path = os.path.join(out_dir, str(fac["id"]))
        with open(path, "w", encoding="latin-1", newline="\n") as f:
            f.writelines(lines)
        written.append((path, len(lines)))
    return written


def main(argv):
    ap = argparse.ArgumentParser(
        description="Chaos Goblin: write player order files from a "
                "state export (Ultron brain, #105).")
    ap.add_argument("--state", required=True,
            help="state export JSON (olympia-g3 --state-export)")
    ap.add_argument("--out", required=True,
            help="orders directory to write, normally lib/orders")
    ap.add_argument("--seed", type=int, required=True,
            help="RNG seed; same seed and inputs, same files")
    ap.add_argument("--coverage",
            help="latest coverage.tsv (olympia-g3 --coverage)")
    ap.add_argument("--backlog", default=DEFAULT_BACKLOG,
            help="fixture backlog (default: tests/ultron/backlog.tsv)")
    ap.add_argument("--orders-per-unit", type=int, default=8,
            help="orders to pick for each unit (default 8)")
    ap.add_argument("--allow", action="append", default=[],
            metavar="VERB",
            help="let the goblin pick a default-excluded verb (quit)")
    ap.add_argument("--exclude", action="append", default=[],
            metavar="VERB", help="never pick VERB")
    a = ap.parse_args(argv)

    with open(a.state, encoding="latin-1") as f:
        state = json.load(f)
    exclude = [v for v in DEFAULT_EXCLUDE if v not in a.allow] + a.exclude
    cells = build_cells(load_backlog(a.backlog),
                load_coverage(a.coverage), exclude)
    if not cells:
        print("chaos_goblin: no verbs to pick from", file=sys.stderr)
        return 2

    os.makedirs(a.out, exist_ok=True)
    goblin = Goblin(random.Random(a.seed), World(state), cells)
    for path, n in write_orders(goblin, state, a.out, a.orders_per_unit):
        print("wrote %s (%d orders)" % (path, n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
