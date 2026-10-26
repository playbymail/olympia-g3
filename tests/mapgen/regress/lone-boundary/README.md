# lone-boundary — boundary squares reached from both sides

Pins the #281 fix.

`read_map()` marks the Uldim (`^ v { }`) and Summerbridge (`] [`) squares
`region_boundary`. `flood_land_inside()` gives a boundary square the region of
the first flood that reaches it and stops there. When a second region's flood
later touched the same square, it found the square claimed and asserted
(`flood_land_inside(...) error`, exit 134). Boundaries therefore worked only
as two-wide pairs with a `Regions` seed on each side.

A flood now treats another region's boundary square as a wall. The assert is
still there for any other conflict; seeds and floods cannot produce one.
Maps that ran before produce the same output.

This directory's `Map` and `Regions` add, in open sea:

| Square | Glyphs | Seeds | Result |
|---|---|---|---|
| (2,36-42) | `ppp^ppp` | west side only | West takes `^`; the east side is its own region |
| (2,44-51) | `ppp{}ppp` | west side only | West takes `{`; the unnamed scan reaches `}` first, so `}` is a 1-square region and the east side another |
| (2,53-59) | `sss]sss` | none | the west side's unnamed flood takes `]`; the east side is its own region |
| (77,25-31) | `ppp[ppp` | on the `[` itself | `[` is its own region; each side is its own region |

The other inputs come from `tests/mapgen/fixtures`. `EXPECT.sha256` pins
`gate`, `loc`, `road` and stderr.

```bash
./tests/mapgen/regress/lone-boundary/check.sh           # YES = pass
./tests/mapgen/regress/lone-boundary/check.sh --update  # refresh EXPECT.sha256 (C build only)
```
