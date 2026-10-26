-- coast-rocks.lua -- build the coast-rocks scenario (issue #254).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Six factions start in Greyfell (start city 0);
-- each noble is poofed out to an ocean province, builds a roundship there
-- and goes aboard. Nobody has orders: the ships sit at sea all month.
--
--   rocks1..rocks4   oceans whose only land neighbor is a mountain
--   reef1, reef2     oceans next to a forest or a plain, no mountain
--
-- near_rocky_coast() took subkind() of the comparison's result instead of
-- comparing the destination's subkind with sub_mountain, so it never found
-- a dangerous coast: a ship next to a mountain rolled for the ordinary
-- coastal reef (1 in 75, 3-5 damage). With the fix it rolls for submerged
-- rocks (1 in 50, 6-9 damage). The reef ships are controls.

local oly = require "oly"

local PEASANT = 10			-- item: peasants (25 per new noble)
local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local function captain(id, faction, handle, name, where)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.subitem(f.noble, PEASANT, 25)
	oly.poof(f.noble, where)
	local ship = oly.makeloc(f.noble, "roundship", "ship")
	oly.poof(f.noble, ship)
	assert(oly.loc(ship) == where, name .. "'s ship must be in " .. where)
	assert(oly.loc(f.noble) == ship, name .. " must be aboard the ship")
	return f.noble, ship
end

local fleet = {
	{ 300, "Rocks One", "rocks1", 13235 },	-- mountain to the south
	{ 301, "Rocks Two", "rocks2", 13244 },
	{ 302, "Rocks Three", "rocks3", 13249 },
	{ 303, "Rocks Four", "rocks4", 13377 },
	{ 304, "Reef One", "reef1", 13245 },	-- a plain
	{ 305, "Reef Two", "reef2", 13351 },	-- a forest
}

local out = {}
for _, s in ipairs(fleet) do
	local who, ship = captain(s[1], s[2], s[3], s[2] .. " Captain", s[4])
	out[#out + 1] = string.format("%s=%d/%d", s[3], who, ship)
end

oly.save("./lib")

print("built coast-rocks: " .. table.concat(out, " "))
