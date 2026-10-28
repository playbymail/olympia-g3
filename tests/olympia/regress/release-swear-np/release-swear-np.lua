-- release-swear-np.lua -- build the release-swear-np scenario (issue #352).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0):
--
--   captive  Captive One  taken prisoner by Captor One before the turn
--                         (oly.prisoner), sworn to swear to whoever frees
--                         it (swear_on_release).
--   captor   Captor One   frees the captive (wait time 1, unstack). Its faction has no
--                         noble points left (oly.noble_points).
--
-- Freed, the captive swears to the Captors (drop_stack -> set_lord), who
-- owe its 2 NPs and can't pay. set_lord's callers check the NPs first;
-- this one doesn't, and swear_on_release comes only from a loaded DB.
-- Before the fix for #352 set_lord logged "assert fail", moved the unit
-- anyway and reported "Paid 2 NPs". Now it fails its assertion.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

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

local captives = faction(300, "Captives", "captive", "Captive One")
local captors = faction(301, "Captors", "captor", "Captor One")

oly.prisoner(captors.noble, captives.noble, true)
oly.noble_points(captors.player, 0)

-- The release draw (ent_drop, keyed on the day) frees the captive
-- without a swear 1 time in 5, as it does on day 1; on day 2 it swears.
oly.order(captors.noble, "wait time 1")
oly.order(captors.noble, "unstack " .. captives.noble)

oly.save("./lib")

print(string.format("built release-swear-np: captives=%d captive=%d "
	.. "captors=%d captor=%d", captives.player, captives.noble,
	captors.player, captors.noble))
