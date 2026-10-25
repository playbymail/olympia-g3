-- use-weather.lua -- build the use-weather scenario (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Six factions start in Greyfell (start city 0)
-- and are moved out of it, since magic may not be used in a safe haven.
-- Each mage knows the Weather magic school and the skills it uses; each
-- skill known adds one aura. The storms are raised by oly.storm:
--
--   windcaller  Plain [13450], a tower    use 829 <gale> 2,
--               there, a blank scroll;    use 827 <gale> 13449,
--               owns the wind <gale>      use 821 <gale> <tower> 1,
--                                         use 823 821
--   rainmaker   Forest [13550]; owns the  use 831 <shower> <victim> 1,
--               rain <shower> and the     use 833 <mist> <victim> 1,
--               fog <mist> there          use 828 <shower>
--   victim      Forest [13550], peasants  (no orders)
--   binder      a ship in Ocean [13350];  use 822 <squall>, use 824
--               owns the rain <squall>
--   seizer      the same ship; the fog    use 832 <haze>
--               <haze> there has no owner
--   summoner    Forest [13449]            use 825, use 826
--
-- Every start returns TRUE (ok). The windcaller renews its gale, directs it
-- west to Forest [13449] for month end, makes it buffet the tower and then
-- scribes Fierce wind. The wind spends one strength of the gale, and the
-- rest moves west at month end. The rainmaker strikes the
-- victim with lightning, kills two of its peasants with the fog and
-- dissipates what is left of the rain. The binder binds its squall to the
-- ship and summons a wind at sea; the seizer takes the haze. The summoner
-- raises a rain and a fog over Forest [13449].

local oly = require "oly"

local WEATHER = 820					-- the school
local FIERCE, BIND, WRITE, WIND = 821, 822, 823, 824	-- skills
local RAIN, FOG, DIRECT, DISSIPATE = 825, 826, 827, 828
local RENEW, LIGHTNING, SEIZE, DEATH_FOG = 829, 831, 832, 833

local PEASANT, BLANK_SCROLL = 10, 84	-- items

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest: a wind cookie
local FOREST = 13550			-- south of the plain: rain and fog cookies
local WEST = 13449			-- west of the plain: rain and fog cookies
local OCEAN = 13350			-- north of the plain: all three

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, where, skills)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	if #skills > 0 then
		oly.know(f.noble, WEATHER)
	end
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be in " .. where)
	return f.noble
end

-- the windcaller scribes Fierce wind onto a blank scroll
local windcaller = noble(300, "Windcallers", "windcaller", "Windcaller One",
	PLAIN, { FIERCE, WRITE, DIRECT, RENEW })
oly.additem(windcaller, BLANK_SCROLL, 1)
local tower = oly.makeloc(windcaller, "tower", "tower")
assert(oly.loc(tower) == PLAIN, "the tower must be on the plain")
local gale = oly.storm(PLAIN, "wind", 6, windcaller, "gale")

local rainmaker = noble(301, "Rainmakers", "rainmaker", "Rainmaker One",
	FOREST, { LIGHTNING, DEATH_FOG, DISSIPATE })
local shower = oly.storm(FOREST, "rain", 6, rainmaker, "shower")
local mist = oly.storm(FOREST, "fog", 6, rainmaker, "mist")

-- lightning and the fog strike only a character in the storm's province
local victim = noble(302, "Victims", "victim", "Victim One", FOREST, {})
oly.additem(victim, PEASANT, 10)

-- the binder's ship is built at sea; binding costs three aura of its six,
-- leaving the three a summons needs
local binder = noble(303, "Binders", "binder", "Binder One", OCEAN,
	{ BIND, WIND, RAIN, FOG, FIERCE })
local ship = oly.makeloc(binder, "roundship", "ship")
oly.poof(binder, ship)
assert(oly.loc(ship) == OCEAN, "the ship must be at sea")
local squall = oly.storm(OCEAN, "rain", 6, binder, "squall")
local haze = oly.storm(OCEAN, "fog", 6, 0, "haze")

-- seizing costs five aura
local seizer = noble(304, "Seizers", "seizer", "Seizer One", ship,
	{ SEIZE, WIND, RAIN, FOG })

-- each summons costs three aura, charged as it finishes
local summoner = noble(305, "Summoners", "summoner", "Summoner One", WEST,
	{ RAIN, FOG, WIND, FIERCE, RENEW })

oly.order(windcaller, "use " .. RENEW .. " " .. gale .. " 2")
oly.order(windcaller, "use " .. DIRECT .. " " .. gale .. " " .. WEST)
oly.order(windcaller, "use " .. FIERCE .. " " .. gale .. " " .. tower .. " 1")
oly.order(windcaller, "use " .. WRITE .. " " .. FIERCE)
oly.order(rainmaker, "use " .. LIGHTNING .. " " .. shower .. " " .. victim
	.. " 1")
oly.order(rainmaker, "use " .. DEATH_FOG .. " " .. mist .. " " .. victim
	.. " 1")
oly.order(rainmaker, "use " .. DISSIPATE .. " " .. shower)
oly.order(binder, "use " .. BIND .. " " .. squall)
oly.order(binder, "use " .. WIND)
oly.order(seizer, "use " .. SEIZE .. " " .. haze)
oly.order(summoner, "use " .. RAIN)
oly.order(summoner, "use " .. FOG)

oly.save("./lib")

print(string.format("built use-weather: windcaller=%d tower=%d gale=%d "
	.. "rainmaker=%d shower=%d mist=%d victim=%d binder=%d ship=%d "
	.. "squall=%d haze=%d seizer=%d summoner=%d", windcaller, tower, gale,
	rainmaker, shower, mist, victim, binder, ship, squall, haze, seizer,
	summoner))
