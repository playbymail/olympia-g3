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
--   binder     a weather mage aboard a roundship in Ocean [13351], north of
--              Greyfell's forest (Greyfell is a safe haven, where magic may
--              not be used): summons rain over the ocean, then binds the new
--              storm to the ship. Nothing in oly makes a storm, so the summon
--              runs in the turn, and the storm's id is read from a run
--
-- Every start returns TRUE (ok).

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local OCEAN = 13351			-- north of Greyfell's forest, holds a rain cookie
local PEASANT, OX = 10, 76		-- items
local BEAST, BREED = 650, 654		-- skills: Beastmastery, Breed beasts
local ADV, TRANCE = 920, 921		-- skills: Advanced sorcery, Trance
local MAGIC, WEATHER = 800, 820		-- skills: Magic, Weather magic
local BIND, RAIN = 822, 825		-- skills: Bind storm to ship, Summon rain
local STORM = 122602		-- the storm the summon mints (read from a run)

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

-- each magic skill learned adds one aura: 6 here, 3 to summon and 3 to bind
for _, sk in ipairs{ MAGIC, 801, 802, WEATHER, BIND, RAIN } do
	oly.know(binder, sk)
end
oly.poof(binder, OCEAN)
local ship = oly.makeloc(binder, "roundship", "ship")
oly.poof(binder, ship)
assert(oly.loc(ship) == OCEAN, "the ship must be built at sea")
assert(oly.loc(binder) == ship, "the binder must be aboard the ship")

oly.order(trancer, "trance")
oly.order(breeder, "breed " .. PEASANT .. " " .. OX)
oly.order(binder, "use " .. RAIN .. " 3")
oly.order(binder, "bind " .. STORM)

oly.save("./lib")

print(string.format("built magic-cast: trancer=%d breeder=%d binder=%d "
	.. "ship=%d", trancer, breeder, binder, ship))
