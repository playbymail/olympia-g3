-- recruitment-raise.lua -- build the recruitment-raise scenario (issue #130).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0)
-- and are poofed to provinces with peasants and a mob cookie:
--
--   recruiter  Plain [13450]    recruits two of the province's peasants
--   agitator   Plain [13450]    raises a peasant mob (seven days)
--   rallier    Forest [13449]   rallies a mob seeded there by oly.mob (#139),
--                               so the mob stacks under the rallier
--
-- Every start returns TRUE (ok). The seeded mob spends Forest's mob cookie,
-- so it is seeded away from the agitator's Plain.

local oly = require "oly"

local PEASANT = 10				-- item
local RAISE_MOB, RALLY_MOB = 673, 674		-- skills

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

local recruiter = noble(300, "Recruiters", "recruiter", "Recruiter One")
local agitator = noble(301, "Agitators", "agitator", "Agitator One")
local rallier = noble(302, "Ralliers", "rallier", "Rallier One")

oly.poof(recruiter, PLAIN)

oly.know(agitator, RAISE_MOB)
oly.poof(agitator, PLAIN)

oly.know(rallier, RALLY_MOB)
oly.poof(rallier, FOREST)
local mob = oly.mob(FOREST, "mob")

assert(oly.loc(recruiter) == PLAIN, "the recruiter must be on the plain")
assert(oly.loc(agitator) == PLAIN, "the agitator must be on the plain")
assert(oly.loc(rallier) == FOREST, "the rallier must be in the forest")
assert(oly.loc(mob) == FOREST, "the mob must be in the forest")
assert(oly.has_item(PLAIN, PEASANT), "the plain needs peasants")

oly.order(recruiter, "recruit 2")
oly.order(agitator, "raise")
oly.order(rallier, "rally " .. mob)

oly.save("./lib")

print(string.format("built recruitment-raise: recruiter=%d agitator=%d "
	.. "rallier=%d mob=%d", recruiter, agitator, rallier, mob))
