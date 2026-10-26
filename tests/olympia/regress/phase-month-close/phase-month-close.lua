-- phase-month-close.lua -- build the phase-month-close scenario (issue #234).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. The clock is set so that the turn run is turn
-- 7, which ends month 6, when Uldim pass and Summerbridge close. The
-- shipped map has neither, so four provinces around Greyfell are marked
-- with oly.pass, one for each of the four routes, and a noble of its own
-- faction stands in each:
--
--   north      Forest [13449]      Summerbridge, passage north (flag 1)
--   south      Plain [13450]       Summerbridge, passage south (flag 2)
--   pass_s     Forest [13550]      Uldim pass, to the south (flag 3)
--   pass_n     Plain [13551]       Uldim pass, to the north (flag 4)

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

local MARKS = {
	{ 300, "Northers", "north", 13449, "summerbridge", 1 },
	{ 301, "Southers", "south", 13450, "summerbridge", 2 },
	{ 302, "Southpassers", "pass_s", 13550, "uldim", 3 },
	{ 303, "Northpassers", "pass_n", 13551, "uldim", 4 },
}

oly.load("./lib")
oly.extract_startlocs()
oly.clock(6)

local ids = {}
for _, m in ipairs(MARKS) do
	local id, name, handle, where, kind, flag = table.unpack(m)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = name .. " One",
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.pass(where, kind, flag)
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must stand in its province")
	ids[#ids + 1] = string.format("%s=%d", handle, f.noble)
end

oly.save("./lib")

print("built phase-month-close: " .. table.concat(ids, " "))
