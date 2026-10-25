-- use-persuasion.lua -- build the use-persuasion scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0)
-- and are poofed to provinces with peasants and a mob cookie:
--
--   persuader  Forest [13449]   use 671 (bribe the mark with 100 gold),
--                               use 672 (persuade the mark) and use 674
--                               (rally a mob seeded there by oly.mob)
--   mark       Forest [13449]   the target of the bribe and the persuasion
--   agitator   Plain [13450]    use 673: raises a peasant mob
--
-- Every start returns TRUE (ok). The mark is oath-2, so the bribe is
-- pocketed or reported and the persuasion fails to convince it, as in
-- social-bribe. incite_mob (675) is covered there. The seeded mob spends
-- Forest's mob cookie, so it is seeded away from the agitator's Plain, as
-- in recruitment-raise.

local oly = require "oly"

local PERSUASION, BRIBE_NOBLE, PERSUADE_OATH = 670, 671, 672	-- skills
local RAISE_MOB, RALLY_MOB = 673, 674

local GREYFELL = 57081			-- start city 0
local PLAIN, FOREST = 13450, 13449

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	return f.noble
end

local persuader = noble(300, "Persuaders", "persuader", "Persuader One")
local mark = noble(301, "Marks", "mark", "Mark One")
local agitator = noble(302, "Agitators", "agitator", "Agitator One")

for _, sk in ipairs{ PERSUASION, BRIBE_NOBLE, PERSUADE_OATH, RALLY_MOB } do
	oly.know(persuader, sk)
end
oly.know(agitator, PERSUASION)
oly.know(agitator, RAISE_MOB)

oly.poof(persuader, FOREST)
oly.poof(mark, FOREST)
oly.poof(agitator, PLAIN)
local mob = oly.mob(FOREST, "mob")

assert(oly.loc(persuader) == FOREST, "the persuader must be in the forest")
assert(oly.loc(mark) == FOREST, "the mark must be in the forest")
assert(oly.loc(mob) == FOREST, "the mob must be in the forest")
assert(oly.loc(agitator) == PLAIN, "the agitator must be on the plain")

oly.order(persuader, "use " .. BRIBE_NOBLE .. " " .. mark .. " 100")
oly.order(persuader, "use " .. PERSUADE_OATH .. " " .. mark)
oly.order(persuader, "use " .. RALLY_MOB .. " " .. mob)
oly.order(agitator, "use " .. RAISE_MOB)

oly.save("./lib")

print(string.format("built use-persuasion: persuader=%d mark=%d agitator=%d "
	.. "mob=%d", persuader, mark, agitator, mob))
