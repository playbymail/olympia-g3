-- combat-attack.lua -- build the combat-attack scenario (issue #128).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions meet in plain province 10113 (not
-- a safe haven, so combat is allowed):
--
--   raider    50 soldiers; sets behind, then attacks the victim
--   victim    no soldiers; guards the province
--   yielder   surrenders to the captor on day 1
--   captor    waits out the surrender, then executes its prisoner
--   razer     owns a tower in the province and razes it
--
-- Every start returns TRUE (ok).

local oly = require "oly"

local SOLDIERS = 12			-- items

local PROV = 10113			-- plain province, as in guard-pillage

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	oly.poof(f.noble, PROV)
	assert(oly.loc(f.noble) == PROV, noble_name .. " must be in the province")
	return f
end

local raiders = faction(300, "Raiders", "raider", "Raider One")
local victims = faction(301, "Victims", "victim", "Victim One")
local yielders = faction(302, "Yielders", "yielder", "Yielder One")
local captors = faction(303, "Captors", "captor", "Captor One")
local razers = faction(304, "Razers", "razer", "Razer One")
local raider, victim = raiders.noble, victims.noble
local yielder, captor, razer = yielders.noble, captors.noble, razers.noble

oly.additem(raider, SOLDIERS, 50)
assert(oly.has_item(raider, SOLDIERS), "the raider has no soldiers")

-- the first character inside a building is its owner
local tower = oly.makeloc(razer, "tower", "tower")
oly.poof(razer, tower)
assert(oly.loc(tower) == PROV, "the tower must be in the province")
assert(oly.loc(razer) == tower, "the razer must own the tower")

oly.order(raider, "behind 1")
oly.order(raider, "attack " .. victim)
oly.order(victim, "guard 1")
oly.order(yielder, "surrender " .. captor)
oly.order(captor, "wait time 2")
oly.order(captor, "execute " .. yielder)
oly.order(razer, "raze")

oly.save("./lib")

print(string.format("built combat-attack: raider=%d victim=%d yielder=%d "
	.. "captor=%d razer=%d tower=%d", raider, victim, yielder, captor,
	razer, tower))
