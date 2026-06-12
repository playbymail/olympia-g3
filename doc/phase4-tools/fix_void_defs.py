#!/usr/bin/env python3
"""Convert empty-paren function DEFINITIONS (name()) to name(void) at the
given strict-prototype sites. Operates per file, bottom-to-top."""
import sys, re, collections

sites_file = sys.argv[1]
sites = [l.strip().split(":") for l in open(sites_file) if l.strip()]

# group line numbers per file
byfile = collections.defaultdict(list)
for f, l in sites:
    byfile[f].append(int(l))

skipped = []
for f, lns in byfile.items():
    L = open(f).read().split("\n")
    for ln in sorted(lns, reverse=True):
        i = ln - 1
        line = L[i]
        nxt = L[i+1].strip() if i+1 < len(L) else ""
        # only treat as a definition if followed by '{' (or line ends with '{')
        if not (nxt.startswith("{") or line.rstrip().endswith("{")):
            continue
        # replace the first empty () after an identifier
        new = re.sub(r"([A-Za-z0-9_])\(\)", r"\1(void)", line, count=1)
        if new == line:
            skipped.append((f, ln, line.strip()))
            continue
        L[i] = new
    open(f, "w").write("\n".join(L))

print(f"processed {sum(len(v) for v in byfile.values())} sites")
if skipped:
    print(f"SKIPPED (no empty paren / not a def) {len(skipped)}:")
    for s in skipped[:40]:
        print("  ", s)
