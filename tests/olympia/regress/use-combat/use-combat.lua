-- use-combat.lua -- build the use-combat scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction, 300 "Men at Arms", starts in
-- Greyfell (start city 0). Its noble knows the combat school and the five
-- usable combat skills, and has 3 wood and 3 workers for a catapult:
--
--   use 612 1    fight_to_death: troops break at 50% (instant)
--   use 613      make_catapult: no start, so v_use hands it to
--                skill_produce; 14 days on, d_use makes a catapult
--   use 614      defense: 7 days, then the defense rating rises
--   use 615      archery: 7 days, then the missile rating rises
--   use 616      swordplay: 7 days, then the attack rating rises
--
-- Every start returns TRUE (ok). None of 612 and 614-616 can fail, and 613
-- has no start, so the school has no refused fixture.

local oly = require "oly"

local WORKER, WOOD = 11, 77		-- items
local COMBAT, FIGHT_TO_DEATH, MAKE_CATAPULT = 610, 612, 613	-- skills
local DEFENSE, ARCHERY, SWORDPLAY = 614, 615, 616

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local f = oly.add_player{
	id = 300, faction = "Men at Arms",
	noble = "warrior", noble_name = "Warrior One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local warrior = f.noble

assert(oly.loc(warrior) == GREYFELL, "the warrior must start in Greyfell")

for _, sk in ipairs{ COMBAT, FIGHT_TO_DEATH, MAKE_CATAPULT,
		DEFENSE, ARCHERY, SWORDPLAY } do
	oly.know(warrior, sk)
end

-- a catapult takes 3 wood, and 3 workers to build it
oly.additem(warrior, WOOD, 3)
oly.additem(warrior, WORKER, 3)

oly.order(warrior, "use " .. FIGHT_TO_DEATH .. " 1")
for _, sk in ipairs{ MAKE_CATAPULT, DEFENSE, ARCHERY, SWORDPLAY } do
	oly.order(warrior, "use " .. sk)
end

oly.save("./lib")

print(string.format("built use-combat: warrior=%d", warrior))
