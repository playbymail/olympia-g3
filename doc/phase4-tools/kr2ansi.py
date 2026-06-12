#!/usr/bin/env python3
"""Convert K&R function definitions to ANSI prototyped form, in place.

Conservative: rewrites ONLY the parameter list on the definition line and
deletes the following K&R parameter-declaration lines (up to the '{').
Return types and everything else are left byte-for-byte untouched.

Usage: kr2ansi.py <file> <line1> [<line2> ...]
Lines are the 1-based line numbers of the function-name line (the K&R def).
Processes bottom-to-top so earlier line numbers stay valid.
"""
import re, sys

path = sys.argv[1]
lines_to_fix = sorted((int(x) for x in sys.argv[2:]), reverse=True)

with open(path) as f:
    src = f.readlines()  # keep newlines

ident = r"[A-Za-z_][A-Za-z0-9_]*"

def parse_decl(line):
    """Parse a K&R decl line like 'unsigned short *a, b[3];' ->
    list of (name, ansi_type_string)."""
    # strip comments and trailing ;
    line = re.sub(r"/\*.*?\*/", "", line)
    line = line.strip()
    if line.endswith(";"):
        line = line[:-1]
    line = line.strip()
    if not line:
        return []
    segs = [s.strip() for s in line.split(",")]
    # base type from first segment: everything before first '*' or the last identifier
    first = segs[0]
    m = re.search(r"(\**)\s*(" + ident + r")\s*(\[[^\]]*\])?$", first)
    if not m:
        return []
    base = first[:m.start()].strip()
    result = []
    for i, seg in enumerate(segs):
        mm = re.search(r"(\**)\s*(" + ident + r")\s*(\[[^\]]*\])?$", seg)
        if not mm:
            return []
        stars, name, dims = mm.group(1), mm.group(2), (mm.group(3) or "")
        # build ansi type: base + space + stars + name + dims
        sep = "" if (base.endswith("*") or stars) else " "
        if base.endswith("*"):
            t = f"{base}{stars}{name}{dims}"
        else:
            t = f"{base} {stars}{name}{dims}"
        result.append((name, t))
    return result

for ln in lines_to_fix:
    idx = ln - 1
    defline = src[idx]
    m = re.search(r"(" + ident + r")\s*\(([^)]*)\)", defline)
    if not m:
        print(f"SKIP {path}:{ln}: no paren signature", file=sys.stderr)
        continue
    params = [p.strip() for p in m.group(2).split(",") if p.strip()]
    # collect K&R decl lines until the line that starts with '{'
    j = idx + 1
    decls = {}
    decl_end = idx  # exclusive
    while j < len(src):
        s = src[j].strip()
        if s.startswith("{"):
            decl_end = j
            break
        for name, t in parse_decl(src[j]):
            decls[name] = t
        j += 1
    else:
        print(f"SKIP {path}:{ln}: no opening brace found", file=sys.stderr)
        continue
    # build ANSI param list in original order
    ansi = []
    for p in params:
        if p in decls:
            ansi.append(decls[p])
        else:
            ansi.append("int " + p)  # K&R implicit-int param
    new_params = ", ".join(ansi) if ansi else "void"
    # replace the param list in the def line (preserve prefix/suffix incl comments)
    start, end = m.start(2), m.end(2)
    new_defline = defline[:start] + new_params + defline[end:]
    # splice: new def line, drop decl lines [idx+1 .. decl_end-1]
    src[idx] = new_defline
    del src[idx+1:decl_end]

with open(path, "w") as f:
    f.writelines(src)
print(f"converted {len(lines_to_fix)} defs in {path}")
