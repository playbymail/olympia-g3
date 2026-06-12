#!/usr/bin/env python3
"""Generate extern prototypes for every missing-prototype function, extracting
return type + parameter list directly from the source definition (robust;
ctags typeref is unreliable for implicit-int functions).

Args: <warn_log_relative_paths> <out.h> <path-prefix-filter ...>
The warning log must have repo-relative paths (olympia/foo.c:line:col).
"""
import re, sys, collections

warn_log = sys.argv[1]
out_path = sys.argv[2]
prefixes = tuple(sys.argv[3:]) if len(sys.argv) > 3 else None

ident = r"[A-Za-z_][A-Za-z0-9_]*"
TYPE_LINE = re.compile(
    r"^\s*(?:static\s+|const\s+|volatile\s+|register\s+)*"
    r"(?:unsigned\s+|signed\s+)?"
    r"(?:struct\s+\w+|union\s+\w+|enum\s+\w+|\w+)\s*\**\s*$")

files = {}
def get_lines(f):
    if f not in files:
        files[f] = open(f).read().split("\n")
    return files[f]

def extract(f, line, name):
    src = get_lines(f)
    idx = line - 1
    defline = src[idx]
    # locate the function name + '(' on the def line
    m = re.search(re.escape(name) + r"\s*\(", defline)
    if not m:
        return None
    # params: paren-match from the '(' after the name
    popen = defline.index("(", m.start())
    depth = 0; pend = None
    for i in range(popen, len(defline)):
        if defline[i] == "(": depth += 1
        elif defline[i] == ")":
            depth -= 1
            if depth == 0: pend = i; break
    if pend is None:
        return None
    params = defline[popen+1:pend].strip()
    if params == "" or params == "void":
        params = "void"
    # return type: prefix on def line, else previous non-blank line(s)
    prefix = defline[:m.start()].strip()
    if prefix:
        ret = prefix
    else:
        j = idx - 1
        while j >= 0 and src[j].strip() == "":
            j -= 1
        if j >= 0 and TYPE_LINE.match(src[j]) and src[j].strip() not in ("else",):
            ret = src[j].strip()
        else:
            ret = "int"   # implicit int
    return ret, name, params

pat = re.compile(r"^(.*?):(\d+):\d+: warning: no previous prototype for function '([^']+)'")
seen = set()
rows = []
with open(warn_log) as fh:
    for ln in fh:
        m = pat.match(ln)
        if not m:
            continue
        f, line, name = m.group(1), int(m.group(2)), m.group(3)
        if prefixes and not f.startswith(prefixes):
            continue
        if name in seen:
            continue
        seen.add(name)
        r = extract(f, line, name)
        if r is None:
            print(f"EXTRACT-FAIL {f}:{line} {name}", file=sys.stderr); continue
        rows.append((f, r))

def proto(ret, name, params):
    sep = "" if ret.endswith("*") else " "
    return f"extern {ret}{sep}{name}({params});"

groups = collections.OrderedDict()
for f, (ret, name, params) in sorted(rows):
    groups.setdefault(f, []).append((ret, name, params))

out = ["#ifndef OLY_PROTO_H", "#define OLY_PROTO_H", "",
       "/*", " *  proto.h -- generated ANSI prototypes for cross-file (non-static)",
       " *  functions, extracted from their definitions (Phase 4 modernization).",
       " *  Eliminates -Wmissing-prototypes at the definitions and",
       " *  -Wimplicit-function-declaration at the call sites.",
       " */", ""]
for f, items in groups.items():
    out.append(f"/* {f} */")
    for ret, name, params in items:
        out.append(proto(ret, name, params))
    out.append("")
out.append("#endif")
open(out_path, "w").write("\n".join(out) + "\n")
print(f"emitted {len(rows)} prototypes to {out_path}")
