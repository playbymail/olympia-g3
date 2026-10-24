-- magic-refused.lua -- build the magic-refused scenario (issue #149).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0):
--
--   bungler     stays in Greyfell and knows no skills: trance, breed and
--               bind fail (requires the skill; bind has no storm to name)
--   breeder     stays in Greyfell, knows Breed beasts and holds one ox:
--               breed fails four ways (usage, not an item, don't have any,
--               don't have two)
--   landlubber  stays in Greyfell, owning a rain storm over Greyfell's forest
--               [13451] (made by oly.storm): bind fails (not on a ship)
--   pauper      a mage with 1 aura aboard a roundship in Greyfell's port,
--               owning a fog storm over the forest: bind fails (too little
--               aura)
--
-- Rejected: trance, breed and bind are for nobles (c), so the player
-- entity's orders are refused.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0, a port
local FOREST = 13451			-- Greyfell's province: a rain and a fog cookie
local PEASANT, OX = 10, 76		-- items
local BEAST, BREED = 650, 654		-- skills: Beastmastery, Breed beasts
local MAGIC, WEATHER = 800, 820		-- skills: Magic, Weather magic
local BIND = 822			-- skill: Bind storm to ship

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

local bunglers = faction(300, "Bunglers", "bungler", "Bungler One")
local breeders = faction(301, "Breeders", "breeder", "Breeder One")
local landlubbers = faction(302, "Landlubbers", "landlubber", "Landlubber One")
local paupers = faction(303, "Paupers", "pauper", "Pauper One")
local bungler, breeder = bunglers.noble, breeders.noble
local landlubber, pauper = landlubbers.noble, paupers.noble

oly.know(breeder, BEAST)
oly.know(breeder, BREED)
oly.additem(breeder, OX, 1)

-- each magic skill learned adds one aura: 3 for the landlubber, 1 for the
-- pauper, short of the 3 that bind costs
for _, sk in ipairs{ MAGIC, WEATHER, BIND } do
	oly.know(landlubber, sk)
end
local gale = oly.storm(FOREST, "rain", 6, landlubber, "gale")

oly.know(pauper, BIND)
local ship = oly.makeloc(pauper, "roundship", "ship")
oly.poof(pauper, ship)
assert(oly.loc(ship) == GREYFELL, "the ship must be built in Greyfell")
assert(oly.loc(pauper) == ship, "the pauper must be aboard the ship")
assert(oly.loc(GREYFELL) == FOREST, "Greyfell must be in the forest")
local shower = oly.storm(FOREST, "fog", 6, pauper, "shower")

oly.order(bungler, "trance")
oly.order(bungler, "breed " .. PEASANT .. " " .. OX)
oly.order(bungler, "bind " .. GREYFELL)
oly.order(breeder, "breed " .. PEASANT)
oly.order(breeder, "breed " .. GREYFELL .. " " .. PEASANT)
oly.order(breeder, "breed " .. PEASANT .. " 51")	-- no wild horse
oly.order(breeder, "breed " .. OX .. " " .. OX)
oly.order(landlubber, "bind " .. gale)
oly.order(pauper, "bind " .. shower)
for _, o in ipairs{ "trance", "breed " .. PEASANT .. " " .. OX,
		"bind " .. GREYFELL } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built magic-refused: player=%d bungler=%d breeder=%d "
	.. "landlubber=%d pauper=%d ship=%d gale=%d shower=%d", bunglers.player,
	bungler, breeder, landlubber, pauper, ship, gale, shower))
