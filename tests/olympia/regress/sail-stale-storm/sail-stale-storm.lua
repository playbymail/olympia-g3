-- sail-stale-storm.lua -- build the sail-stale-storm scenario (issue #250).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0);
-- its captain is moved to Ocean [13350], builds a roundship there, crews it
-- and boards it. It knows Weather magic (bind storm and dissipate) and
-- Sailing, and owns two storms that oly.storm raises over the ocean:
--
--   stale  a rain, bound to the ship the way bind storm did before #169
--          (PR #174): the ship's bound-storm list names it, but the storm's
--          own bind field names the storm itself, not the ship
--   gust   a wind, bound to the ship during the turn by `use 822`
--
-- Orders:  use 822 <gust>      bind the wind to the ship
--          use 828 <stale>     dissipate the rain
--          sail north          to Ocean [13250]
--
-- dissipate_storm() unbinds a storm from the ship its bind field names. The
-- stale rain's names itself, so the ship's list keeps the dead storm. When
-- the ship arrives, move_bound_storms() finds an entry that is no longer a
-- storm and deletes it. Before the fix it passed ilist_delete() the storm
-- number instead of the list index, and the turn aborted on ilist_delete's
-- range assert. With the fix the entry is dropped and the wind moves north
-- with the ship.
--
-- No binding writes the pre-#169 shape, so after oly.save() this script
-- edits the saved lib by hand: the ship's `bs` list in lib/ship and the
-- rain's `bs` field in lib/misc. Both are plain text.

local oly = require "oly"

local WEATHER = 820			-- the school
local BIND, DISSIPATE = 822, 828	-- skills
local SAILING = 601
local PEASANT, SAILOR = 10, 19		-- items

local GREYFELL = 57081			-- start city 0, a safe haven
local OCEAN = 13350			-- rain, wind and fog cookies
local NORTH = 13250			-- the ocean north of it

oly.load("./lib")
oly.extract_startlocs()

local f = oly.add_player{
	id = 300, faction = "Stale Storms",
	noble = "captain", noble_name = "Captain One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local cap = f.noble
assert(oly.loc(cap) == GREYFELL, "the captain must start in Greyfell")

oly.know(cap, WEATHER)
oly.know(cap, BIND)
oly.know(cap, DISSIPATE)
oly.know(cap, SAILING)
oly.subitem(cap, PEASANT, 25)
oly.additem(cap, SAILOR, 8)

oly.poof(cap, OCEAN)
local ship = oly.makeloc(cap, "roundship", "ship")
oly.poof(cap, ship)
assert(oly.loc(ship) == OCEAN, "the ship must be at sea")
assert(oly.loc(cap) == ship, "the captain must be aboard the ship")

local stale = oly.storm(OCEAN, "rain", 6, cap, "stale")
local gust = oly.storm(OCEAN, "wind", 6, cap, "gust")

oly.order(cap, "use " .. BIND .. " " .. gust)
oly.order(cap, "use " .. DISSIPATE .. " " .. stale)
oly.order(cap, "sail north")

oly.save("./lib")

-- Append `lines` to one entity's block in a lib file, just before the blank
-- line that ends it. The block must exist.
local function append_block(path, id, lines)
	local fh = assert(io.open(path, "r"))
	local text = fh:read("a")
	fh:close()

	local out, inside, found = {}, false, false
	for line in text:gmatch("(.-)\n") do
		if line:match("^" .. id .. " ") then
			inside, found = true, true
		elseif inside and line == "" then
			for _, l in ipairs(lines) do
				out[#out + 1] = l
			end
			inside = false
		end
		out[#out + 1] = line
	end
	assert(found and not inside, path .. ": no block for " .. id)

	fh = assert(io.open(path, "w"))
	fh:write(table.concat(out, "\n"), "\n")
	fh:close()
end

-- the ship lists the rain as bound to it (its SL section has nothing else
-- yet), and the rain's bind field names the rain itself, as bind storm wrote
-- it before #169; print_subloc() and print_misc() write these fields last
append_block("./lib/ship", ship, { "SL", " bs " .. stale .. " " })
append_block("./lib/misc", stale, { " bs " .. stale })

print(string.format("built sail-stale-storm: captain=%d ship=%d stale=%d "
	.. "gust=%d north=%d", cap, ship, stale, gust, NORTH))
