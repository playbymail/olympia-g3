-- rng-repeat-leaves.lua -- build the rng-repeat-leaves scenario (issue #186).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Each faction repeats a 7-day skill command four
-- times in one turn (days 7, 14, 21, 28), so the report shows whether the
-- repeats draw independently:
--
--   archer      in Greyfell, knows Archery: trains it (`use 615`) four
--               times (the 5% critical gate and the rating bonus)
--   researcher  owns a tower in Greyfell and knows Stealth: researches
--               Stealth four times (the 25% success gate and the pick among
--               its four researchable skills)
--
-- Before #186 both leaves were keyed on (noble, skill) alone, so every
-- repeat replayed the first roll: the same bonus each week, and a failed
-- research failed on every retry that turn.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local COMBAT, ARCHERY = 610, 615	-- skills
local STEALTH = 630

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
	return f.noble
end

local archer = faction(300, "Archers", "archer", "Archer One")
local researcher = faction(301, "Researchers", "researcher", "Researcher One")

oly.know(archer, COMBAT)
oly.know(archer, ARCHERY)

oly.know(researcher, STEALTH)
local tower = oly.makeloc(researcher, "tower", "tower")
oly.poof(researcher, tower)
assert(oly.loc(researcher) == tower, "the researcher must own the tower")

for _ = 1, 4 do oly.order(archer, "use " .. ARCHERY) end
for _ = 1, 4 do oly.order(researcher, "research " .. STEALTH) end

oly.save("./lib")

print(string.format("built rng-repeat-leaves: archer=%d researcher=%d "
	.. "tower=%d", archer, researcher, tower))
