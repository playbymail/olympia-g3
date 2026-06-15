-- guard-pillage.lua -- rebuild the guard-pillage scenario as ONE script.
--
-- The scripted equivalent of build-scenario.sh's six-tool dance (tar + oly -s
-- + hand-written Join-g3 + oly -a + awk-recover-ids + piped oly -i +
-- hand-written orders). It is run by check-lua.sh against the bare-map fixture
-- and must produce a `lib` whose post-turn manifest is BYTE-IDENTICAL to the
-- committed EXPECT.sha256 -- the prototype's pass/fail gate (doc
-- scripting-tool.md §8, §9). See run-by check-lua.sh, NOT check.sh.
--
-- Determinism (doc §3): a single deterministic process loading the fixed
-- randseed reproduces the legacy 3-process rnd() draw sequence exactly (the
-- -s pass's init draws are discarded unsaved, so a single process is
-- equivalent). Faction boxes are allocated at explicit ids (no rnd); the
-- nobles are minted by the engine and NAMED here via the registry, so the
-- awk id-recovery step is gone -- the author writes `pil.noble`, never 2355.

local oly = require "oly"

-- 1-2. load the bare map + write startloc (replaces tar + `oly -s`).
oly.load("./lib")
oly.extract_startlocs()

-- 3-5. two regular factions, each a starting noble. add_player mints the
--      faction at the explicit box id and binds the noble's name in the
--      registry (subsumes the Join-g3 files, the -a pass, and the awk step).
local pil = oly.add_player{
	id = 300, faction = "Pillager Horde",
	name = "pillager", noble = "grok", noble_name = "Warlord Grok",
	start = "0", full_name = "P Layer One", email = "pillager@example.com",
}
local grd = oly.add_player{
	id = 301, faction = "Guard Order",
	name = "guard", noble = "vigil", noble_name = "Captain Vigil",
	start = "1", full_name = "P Layer Two", email = "guard@example.com",
}

-- 6. sculpt the pre-turn world (replaces the piped be/poof/additem/guard).
--    Each op takes an explicit subject -- no dangling `be` state.
local PROV, SOLDIERS = 10113, 12	-- plain province 10113; item 12 = soldiers

oly.poof(pil.noble, PROV)
oly.additem(pil.noble, SOLDIERS, 50)

oly.poof(grd.noble, PROV)
oly.additem(grd.noble, SOLDIERS, 20)
oly.guard(grd.noble, true)

-- branch on real state -- the capability immediate mode never had.
assert(oly.loc(pil.noble) == PROV and oly.loc(grd.noble) == PROV,
	"both nobles must share the province for the battle to trigger")
assert(oly.has_item(pil.noble, SOLDIERS),
	"pillager has no soldiers -- scenario would be a no-op")

-- 7. turn orders (replaces hand-written lib/orders/<n>).
oly.order(pil.noble, "pillage 1")
oly.order(grd.noble, "guard 1")

-- 8. freeze the pre-turn world; check-lua.sh runs the turn and hashes it.
oly.save("./lib")

print(string.format("built guard-pillage: pillager=%d guard=%d province=%d",
	pil.noble, grd.noble, PROV))
