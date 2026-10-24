-- magic-cast.lua -- build the magic-cast scenario (issue #149).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0):
--
--   trancer    knows Advanced sorcery and Trance: trances for 28 days, which
--              restores aura and health
--   breeder    knows Beastmastery and Breed beasts, and holds an ox beside
--              its peasants: breeds a peasant with the ox (a minotaur); the
--              breeding accidents and the offspring are draws on the social
--              stream
--   binder     a weather mage aboard a roundship in Greyfell's port, owning a
--              rain storm over Greyfell's forest [13451] (made by oly.storm):
--              binds the storm to the ship
--
-- Every start returns TRUE (ok).

local oly = require "oly"

local GREYFELL = 57081			-- start city 0, a port
local FOREST = 13451			-- Greyfell's province, holds a rain cookie
local PEASANT, OX = 10, 76		-- items
local BEAST, BREED = 650, 654		-- skills: Beastmastery, Breed beasts
local ADV, TRANCE = 920, 921		-- skills: Advanced sorcery, Trance
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

local trancers = faction(300, "Trancers", "trancer", "Trancer One")
local breeders = faction(301, "Breeders", "breeder", "Breeder One")
local binders = faction(302, "Binders", "binder", "Binder One")
local trancer, breeder, binder = trancers.noble, breeders.noble, binders.noble

oly.know(trancer, ADV)
oly.know(trancer, TRANCE)

oly.know(breeder, BEAST)
oly.know(breeder, BREED)
oly.additem(breeder, OX, 1)

-- each magic skill learned adds one aura: 3 here, what bind costs
for _, sk in ipairs{ MAGIC, WEATHER, BIND } do
	oly.know(binder, sk)
end
local ship = oly.makeloc(binder, "roundship", "ship")
oly.poof(binder, ship)
assert(oly.loc(ship) == GREYFELL, "the ship must be built in Greyfell")
assert(oly.loc(binder) == ship, "the binder must be aboard the ship")
assert(oly.loc(GREYFELL) == FOREST, "Greyfell must be in the forest")
local storm = oly.storm(FOREST, "rain", 6, binder, "storm")
assert(oly.loc(storm) == FOREST, "the storm must be over the forest")

oly.order(trancer, "trance")
oly.order(breeder, "breed " .. PEASANT .. " " .. OX)
oly.order(binder, "bind " .. storm)

oly.save("./lib")

print(string.format("built magic-cast: trancer=%d breeder=%d binder=%d "
	.. "ship=%d storm=%d", trancer, breeder, binder, ship, storm))
