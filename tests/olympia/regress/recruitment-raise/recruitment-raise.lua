-- recruitment-raise.lua -- build the recruitment-raise scenario (issue #130).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0) and
-- are poofed to Plain [13450], a province with peasants and a mob cookie:
--
--   recruiter  recruits two of the province's peasants
--   agitator   raises a peasant mob (seven days), then rallies it, so the
--              mob stacks under the agitator
--
-- Every start returns TRUE (ok).
--
-- The mob's id is minted during the turn, so the agitator's rally names it
-- by the id the turn gives it. new_ent() draws ids from the per-turn `mint`
-- stream, so the id is fixed for this frozen scenario; if an engine change
-- moves it, check.sh reports rally missing its ok cell.

local oly = require "oly"

local PEASANT = 10				-- item
local RAISE_MOB, RALLY_MOB = 673, 674		-- skills

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450
local MOB = 122602			-- the mob d_raise creates this turn

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

oly.poof(recruiter, PLAIN)

oly.know(agitator, RAISE_MOB)
oly.know(agitator, RALLY_MOB)
oly.poof(agitator, PLAIN)

assert(oly.loc(recruiter) == PLAIN, "the recruiter must be on the plain")
assert(oly.loc(agitator) == PLAIN, "the agitator must be on the plain")
assert(oly.has_item(PLAIN, PEASANT), "the plain needs peasants")

oly.order(recruiter, "recruit 2")
oly.order(agitator, "raise")
oly.order(agitator, "rally " .. MOB)

oly.save("./lib")

print(string.format("built recruitment-raise: recruiter=%d agitator=%d mob=%d",
	recruiter, agitator, MOB))
