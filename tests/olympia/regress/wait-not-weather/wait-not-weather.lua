-- wait-not-weather.lua -- build the wait-not-weather scenario (issue #247).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0)
-- and are poofed out to where oly.storm has raised storms of strength 6:
--
--   rainy    Forest [13550], under rain and fog   wait not rain time 3
--   foggy    the same forest                      wait not fog time 3
--   windy    Plain [13450], under a wind          wait not wind time 3
--   wet      the same forest                      wait rain time 3
--   dry      Forest [13449], no weather           wait not rain time 3
--
-- weather_here() returns the summed strength of the storms, not 0/1. Before
-- the fix `cond = not - cond` made `wait not rain` (and fog, wind) end at
-- once under a storm of strength 2 or more, reporting "it is not raining."
-- With it, rainy, foggy and windy wait the three days out. wet and dry end
-- at once either way: they pin the forms that already worked.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450			-- a wind cookie
local FOREST = 13550			-- rain and fog cookies
local WEST = 13449			-- no storm

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, where)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be in " .. where)
	return f.noble
end

local rain = oly.storm(FOREST, "rain", 6, 0, "rain")
local fog = oly.storm(FOREST, "fog", 6, 0, "fog")
local wind = oly.storm(PLAIN, "wind", 6, 0, "wind")

local rainy = noble(300, "Rainy", "rainy", "Rainy One", FOREST)
local foggy = noble(301, "Foggy", "foggy", "Foggy One", FOREST)
local windy = noble(302, "Windy", "windy", "Windy One", PLAIN)
local wet = noble(303, "Wet", "wet", "Wet One", FOREST)
local dry = noble(304, "Dry", "dry", "Dry One", WEST)

oly.order(rainy, "wait not rain time 3")
oly.order(foggy, "wait not fog time 3")
oly.order(windy, "wait not wind time 3")
oly.order(wet, "wait rain time 3")
oly.order(dry, "wait not rain time 3")

oly.save("./lib")

print(string.format("built wait-not-weather: rain=%d fog=%d wind=%d "
	.. "rainy=%d foggy=%d windy=%d wet=%d dry=%d", rain, fog, wind,
	rainy, foggy, windy, wet, dry))
