-- inventory-refused.lua -- build the inventory-refused scenario (issue #127).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- The stranger has no orders and has accepted nothing. The fumbler orders
-- every inventory verb but accept and reclaim, and each fails:
--
--   give      the stranger refuses peasants it has not accepted
--   get, take the stranger is not in the fumbler's faction
--   pay       the fumbler keeps more gold back than it has
--   claim     the faction has no fish to claim
--   discard, drop  the fumbler has no fish
--
-- The fumblers' player entity orders the same verbs plus reclaim (rejected:
-- noble-only verbs). The garrison of Catchclaw, seeded by oly.load, orders
-- accept (rejected: a garrison may issue no accept). accept and reclaim
-- always return TRUE, so they have no fail outcome.

local oly = require "oly"

local GOLD, PEASANT, FISH = 1, 10, 87	-- items

local GREYFELL = 57081			-- start city 0
local CATCHCLAW = 58706			-- a city with a seeded garrison

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

local fumblers = faction(300, "Fumblers", "fumbler", "Fumbler One")
local strangers = faction(301, "Strangers", "stranger", "Stranger One")
local fumbler, stranger = fumblers.noble, strangers.noble
local garrison = oly.garrison(CATCHCLAW)
assert(garrison, "Catchclaw must have a garrison")

assert(not oly.has_item(fumbler, FISH), "the fumbler must have no fish")
assert(not oly.has_item(fumblers.player, FISH), "the faction must have no fish")

local orders = {
	"give " .. stranger .. " " .. PEASANT .. " 1",
	"get " .. stranger .. " " .. PEASANT .. " 1",
	"take " .. stranger .. " " .. PEASANT .. " 1",
	"pay " .. stranger .. " 10 9999",
	"claim " .. FISH .. " 1",
	"discard " .. FISH .. " 1",
	"drop " .. FISH .. " 1",
}

for _, o in ipairs(orders) do
	oly.order(fumbler, o)
end
for _, o in ipairs(orders) do
	oly.order(fumblers.player, o)
end
oly.order(fumblers.player, "reclaim")
oly.order(garrison, "accept 0 0 0")

oly.save("./lib")

print(string.format("built inventory-refused: player=%d fumbler=%d "
	.. "stranger=%d garrison=%d", fumblers.player, fumbler, stranger,
	garrison))
