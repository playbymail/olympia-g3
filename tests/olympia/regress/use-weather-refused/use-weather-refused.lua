-- use-weather-refused.lua -- build the use-weather-refused scenario
-- (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0);
-- its noble is moved to Plain [13450], since magic may not be used in a
-- safe haven. It knows the Weather magic school and every skill in it, for
-- 13 aura, and holds a blank scroll. oly.storm raises two storms it owns:
-- the wind <gale> over the plain, which spends the plain's wind cookie, and
-- the rain <shower> over Forest [13550], to the south.
--
--   use 821 <gale> 13450      the plain is not a building
--   use 822 <gale>            not on a ship
--   use 823 840               does not know Scrying
--   use 824                   the plain has no wind left to summon
--   use 825, use 826          no rain or fog on a plain
--   use 827 13450             controls no storm [13450]
--   use 828 <shower>          the shower is not here
--   use 829 13450             [13450] is not a storm
--   use 831 <gale> <bungler>  the gale is not a rain storm
--   use 832 <gale>            already controls the gale
--   use 833 <shower> <bungler> the shower is not a fog
--
-- Every start fails.

local oly = require "oly"

local WEATHER = 820					-- the school
local FIERCE, BIND, WRITE, WIND = 821, 822, 823, 824	-- skills
local RAIN, FOG, DIRECT, DISSIPATE = 825, 826, 827, 828
local RENEW, LIGHTNING, SEIZE, DEATH_FOG = 829, 831, 832, 833
local SCRY = 840			-- a school the bungler does not know

local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest: a wind cookie
local FOREST = 13550			-- south of the plain

oly.load("./lib")
oly.extract_startlocs()

local f = oly.add_player{
	id = 300, faction = "Bunglers",
	noble = "bungler", noble_name = "Bungler One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local bungler = f.noble
assert(oly.loc(bungler) == GREYFELL, "the bungler must start in Greyfell")

for _, sk in ipairs{ WEATHER, FIERCE, BIND, WRITE, WIND, RAIN, FOG, DIRECT,
		DISSIPATE, RENEW, LIGHTNING, SEIZE, DEATH_FOG } do
	oly.know(bungler, sk)
end
-- the scroll gets the scribe past meets_requirements, to its start
oly.additem(bungler, BLANK_SCROLL, 1)
oly.poof(bungler, PLAIN)
assert(oly.loc(bungler) == PLAIN, "the bungler must be on the plain")

local gale = oly.storm(PLAIN, "wind", 6, bungler, "gale")
local shower = oly.storm(FOREST, "rain", 6, bungler, "shower")

oly.order(bungler, "use " .. FIERCE .. " " .. gale .. " " .. PLAIN)
oly.order(bungler, "use " .. BIND .. " " .. gale)
oly.order(bungler, "use " .. WRITE .. " " .. SCRY)
oly.order(bungler, "use " .. WIND)
oly.order(bungler, "use " .. RAIN)
oly.order(bungler, "use " .. FOG)
oly.order(bungler, "use " .. DIRECT .. " " .. PLAIN)
oly.order(bungler, "use " .. DISSIPATE .. " " .. shower)
oly.order(bungler, "use " .. RENEW .. " " .. PLAIN)
oly.order(bungler, "use " .. LIGHTNING .. " " .. gale .. " " .. bungler)
oly.order(bungler, "use " .. SEIZE .. " " .. gale)
oly.order(bungler, "use " .. DEATH_FOG .. " " .. shower .. " " .. bungler)

oly.save("./lib")

print(string.format("built use-weather-refused: bungler=%d gale=%d "
	.. "shower=%d", bungler, gale, shower))
