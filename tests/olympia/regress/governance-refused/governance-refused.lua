-- governance-refused.lua -- build the governance-refused scenario (issue #150).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Seven factions start in Greyfell (start city 0):
--
--   lord       stands in a castle made by oly.makeloc in the city: its
--              garrison fails below province level, and it rules no
--              garrison, so every decree fails
--   squire     stands in the forest province around the city with five
--              soldiers: each garrison and ungarrison fails a different check
--   pretender  stands in the plain west of the forest with ten soldiers: the
--              lord's castle is not in this province, and no garrison bound
--              to it adjoins
--   outlander  stands in a plain of Idar with ten soldiers: the lord's
--              castle is in Provinia, another region
--   usurper    stands in Catchclaw, whose seeded garrison is bound to no
--              castle, so nobody rules it
--   marshal    stands in a plain east of the coast with ten soldiers, next to
--              a castle of its own made there; oly.add_garrison binds six
--              garrisons to that castle, one more than a level-0 castle
--              supports
--   intruder   stands with ten soldiers in a forest that holds one of the
--              marshal's garrisons
--
-- Catchclaw's garrison orders all three verbs, which are for nobles (c), so
-- each is rejected. The castles, the unfinished castle, the tower and the
-- marshal's six garrisons are minted here, before the turn.

local oly = require "oly"

local SOLDIER = 12			-- item

local GREYFELL = 57081			-- start city 0
local FOREST = 13451			-- Greyfell's province
local PLAIN = 13450			-- west of the forest
local CATCHCLAW = 58706			-- a city with a seeded garrison
local IDAR_PLAIN = 10113		-- a province of Idar, not Provinia
local FAR_PLAIN = 13457			-- Provinia, east across the water
local FAR_FOREST = 13458		-- east of FAR_PLAIN
-- six more Provinia provinces near FAR_PLAIN, one garrison each
local MARCHES = { FAR_FOREST, 13459, 13556, 13557, 13558, 13559 }

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, noble_name .. " must start in Greyfell")
	return f
end

local lords = faction(300, "Lords", "lord", "Lord One")
local squires = faction(301, "Squires", "squire", "Squire One")
local pretenders = faction(302, "Pretenders", "pretender", "Pretender One")
local usurpers = faction(303, "Usurpers", "usurper", "Usurper One")
local outlanders = faction(304, "Outlanders", "outlander", "Outlander One")
local marshals = faction(305, "Marshals", "marshal", "Marshal One")
local intruders = faction(306, "Intruders", "intruder", "Intruder One")
local lord, squire = lords.noble, squires.noble
local pretender, usurper = pretenders.noble, usurpers.noble
local outlander = outlanders.noble
local marshal, intruder = marshals.noble, intruders.noble

local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

local castle = oly.makeloc(lord, "castle", "castle")
local unfinished = oly.makeloc(lord, "castle-in-progress", "unfinished")
local tower = oly.makeloc(lord, "tower", "tower")
oly.poof(lord, castle)
assert(oly.loc(lord) == castle, "the lord must be in the castle")

oly.poof(squire, FOREST)
assert(oly.loc(squire) == FOREST, "the squire must be in the forest")
assert(not oly.garrison(FOREST), "the forest must have no garrison")
oly.additem(squire, SOLDIER, 5)

oly.poof(pretender, PLAIN)
assert(oly.loc(pretender) == PLAIN, "the pretender must be in the plain")
assert(not oly.garrison(PLAIN), "the plain must have no garrison")
oly.additem(pretender, SOLDIER, 10)

oly.poof(outlander, IDAR_PLAIN)
assert(oly.loc(outlander) == IDAR_PLAIN, "the outlander must be in Idar")
assert(not oly.garrison(IDAR_PLAIN), "the Idar plain must have no garrison")
oly.additem(outlander, SOLDIER, 10)

oly.poof(usurper, CATCHCLAW)
assert(oly.loc(usurper) == CATCHCLAW, "the usurper must be in Catchclaw")

oly.poof(marshal, FAR_PLAIN)
assert(oly.loc(marshal) == FAR_PLAIN, "the marshal must be in the far plain")
local keep = oly.makeloc(marshal, "castle", "keep")
oly.additem(marshal, SOLDIER, 10)
for i, where in ipairs(MARCHES) do
	assert(not oly.garrison(where), where .. " must have no garrison")
	oly.add_garrison(where, keep, SOLDIER, 10, "march" .. i)
end
assert(not oly.garrison(FAR_PLAIN), "the far plain must have no garrison")

oly.poof(intruder, FAR_FOREST)
assert(oly.loc(intruder) == FAR_FOREST, "the intruder must be in the far forest")
oly.additem(intruder, SOLDIER, 10)

for _, o in ipairs{
		"garrison " .. castle,
		"decree",
		"decree tax",
		"decree watch " .. GREYFELL,
		"decree watch " .. squire,
		"decree hostile " .. squire } do
	oly.order(lord, o)
end
for _, o in ipairs{
		"garrison",
		"garrison " .. unfinished,
		"garrison " .. tower,
		"garrison " .. castle,
		"ungarrison",
		"ungarrison " .. garrison } do
	oly.order(squire, o)
end
oly.order(pretender, "garrison " .. castle)
oly.order(outlander, "garrison " .. castle)
oly.order(usurper, "ungarrison")
oly.order(marshal, "garrison " .. keep)
oly.order(intruder, "garrison " .. keep)
for _, o in ipairs{
		"garrison " .. castle,
		"ungarrison",
		"decree watch " .. lord } do
	oly.order(garrison, o)
end

oly.save("./lib")

print(string.format("built governance-refused: lord=%d squire=%d "
	.. "pretender=%d outlander=%d usurper=%d marshal=%d intruder=%d "
	.. "garrison=%d castle=%d unfinished=%d tower=%d keep=%d march1=%d",
	lord, squire, pretender, outlander, usurper, marshal, intruder,
	garrison, castle, unfinished, tower, keep, oly.id("march1")))
