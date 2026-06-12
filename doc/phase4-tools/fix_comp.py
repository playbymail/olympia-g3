#!/usr/bin/env python3
"""Rewrite qsort comparators to the canonical (const void*, const void*)
signature, casting back to the real pointer type via local variables so the
body stays byte-identical."""
import re, sys

# (file, name, type) -- type includes trailing ' ' handling below
COMPS = [
    ("olympia/buy.c",    "seller_comp",        "trades_list"),
    ("olympia/gm.c",     "skill_use_comp",     "int *"),
    ("olympia/gm.c",     "skills_known_comp",  "int *"),
    ("olympia/gm.c",     "region_occupy_comp", "int *"),
    ("olympia/gm.c",     "wealth_list_comp",   "int *"),
    ("olympia/gm.c",     "nobles_list_comp",   "int *"),
    ("olympia/input.c",  "exec_comp",          "int *"),
    ("olympia/lore.c",   "lore_comp",          "int *"),
    ("olympia/perm.c",   "admit_comp",         "admits_list"),
    ("olympia/seed.c",   "int_comp",           "int *"),
    ("olympia/report.c", "output_order_comp",  "int *"),
    ("olympia/report.c", "inv_item_comp",      "item_ents_list"),
    ("olympia/use.c",    "rep_skill_comp",     "skill_ents_list"),
    ("olympia/use.c",    "flat_skill_comp",    "skill_ents_list"),
]

def decl(t, var, src):
    sep = "" if t.endswith("*") else " "
    return f"\t{t}{sep}{var} = ({t}) {src};\n"

from collections import defaultdict
byfile = defaultdict(list)
for f, n, t in COMPS:
    byfile[f].append((n, t))

for f, items in byfile.items():
    with open(f) as fh:
        src = fh.read()
    for name, t in items:
        # match:  NAME(TYPE a, TYPE b)\n{\n
        pat = re.compile(
            r"^" + re.escape(name) + r"\([^\n)]*\)\n\{\n",
            re.M)
        m = pat.search(src)
        if not m:
            print(f"MISS {f}:{name}", file=sys.stderr); continue
        repl = (f"{name}(const void *av, const void *bv)\n{{\n"
                + decl(t, "a", "av") + decl(t, "b", "bv"))
        src = src[:m.start()] + repl + src[m.end():]
    with open(f, "w") as fh:
        fh.write(src)
    print(f"updated {f}: {[n for n,_ in items]}")
