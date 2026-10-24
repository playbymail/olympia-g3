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
--   landlubber  a weather mage poofed to Plain [13450], which is not a safe
--               haven and holds a wind cookie: summons wind, then bind
--               fails (not on a ship)
--   pauper      a weather mage with 4 aura aboard a roundship in Ocean
--               [13351]: summons rain for 3, then bind fails (too little
--               aura)
--
-- Nothing in oly makes a storm, so both storms are summoned in the turn and
-- their ids are read from a run.
--
-- Rejected: trance, breed and bind are for nobles (c), so the player
-- entity's orders are refused.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local PLAIN = 13450			-- holds a wind cookie, not a safe haven
local OCEAN = 13351			-- north of Greyfell's forest, holds a rain cookie
local PEASANT, OX = 10, 76		-- items
local BEAST, BREED = 650, 654		-- skills: Beastmastery, Breed beasts
local MAGIC, WEATHER = 800, 820		-- skills: Magic, Weather magic
local BIND = 822			-- skill: Bind storm to ship
local WIND, RAIN = 824, 825		-- skills: Summon wind, Summon rain
local GALE = 122602			-- the landlubber's storm (read from a run)
local SHOWER = 103520		-- the pauper's storm (read from a run)

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

-- each magic skill learned adds one aura: 4 apiece
for _, sk in ipairs{ MAGIC, WEATHER, BIND, WIND } do
	oly.know(landlubber, sk)
end
oly.poof(landlubber, PLAIN)
assert(oly.loc(landlubber) == PLAIN, "the landlubber must be in Plain")

for _, sk in ipairs{ MAGIC, WEATHER, BIND, RAIN } do
	oly.know(pauper, sk)
end
oly.poof(pauper, OCEAN)
local ship = oly.makeloc(pauper, "roundship", "ship")
oly.poof(pauper, ship)
assert(oly.loc(ship) == OCEAN, "the ship must be built at sea")
assert(oly.loc(pauper) == ship, "the pauper must be aboard the ship")

oly.order(bungler, "trance")
oly.order(bungler, "breed " .. PEASANT .. " " .. OX)
oly.order(bungler, "bind " .. GREYFELL)
oly.order(breeder, "breed " .. PEASANT)
oly.order(breeder, "breed " .. GREYFELL .. " " .. PEASANT)
oly.order(breeder, "breed " .. PEASANT .. " 51")	-- no wild horse
oly.order(breeder, "breed " .. OX .. " " .. OX)
oly.order(landlubber, "use " .. WIND .. " 3")
oly.order(landlubber, "bind " .. GALE)
oly.order(pauper, "use " .. RAIN .. " 3")
oly.order(pauper, "bind " .. SHOWER)
for _, o in ipairs{ "trance", "breed " .. PEASANT .. " " .. OX,
		"bind " .. GREYFELL } do
	oly.order(bunglers.player, o)
end

oly.save("./lib")

print(string.format("built magic-refused: player=%d bungler=%d breeder=%d "
	.. "landlubber=%d pauper=%d ship=%d", bunglers.player, bungler,
	breeder, landlubber, pauper, ship))
