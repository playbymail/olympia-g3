-- rng-repeat.lua -- build the rng-repeat scenario (issue #167).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Each faction repeats a random action within one
-- turn, so the report shows whether the repeats draw independently:
--
--   quester    on battlefield [59001]: quests four times (days 7, 14, 21,
--              28)
--   explorer   in Plain [13450]: explores three times (days 7, 14, 21)
--   raider1/2  in Plain [10113], 20 soldiers each: attack victim1/2 on day 1
--   victim1/2  in Plain [10113], 20 soldiers each
--
-- The two battles are identical apart from the ids, at the same place on the
-- same day. Before #167 the quest stream was keyed on the subloc alone, the
-- explore stream on the turn alone and the battle stream on the location
-- alone, so every repeat replayed the first draw.

local oly = require "oly"

local SOLDIERS = 12			-- items
local PLAIN = 13450			-- province next to Greyfell's forest
local BATTLEFIELD = 59001		-- a battlefield subloc, not a safe haven
local FIELD = 10113			-- plain province, as in guard-pillage

oly.load("./lib")
oly.extract_startlocs()

local function faction(id, name, handle, noble_name, where)
	local f = oly.add_player{
		id = id, faction = name,
		noble = handle, noble_name = noble_name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, noble_name .. " was not moved")
	return f.noble
end

local quester = faction(300, "Questers", "quester", "Quester One", BATTLEFIELD)
local explorer = faction(301, "Explorers", "explorer", "Explorer One", PLAIN)
local raider1 = faction(302, "Raiders A", "raider1", "Raider A", FIELD)
local raider2 = faction(303, "Raiders B", "raider2", "Raider B", FIELD)
local victim1 = faction(304, "Victims A", "victim1", "Victim A", FIELD)
local victim2 = faction(305, "Victims B", "victim2", "Victim B", FIELD)

for _, n in ipairs{raider1, raider2, victim1, victim2} do
	oly.additem(n, SOLDIERS, 20)
end

for _ = 1, 4 do oly.order(quester, "quest") end
for _ = 1, 3 do oly.order(explorer, "explore") end
oly.order(raider1, "attack " .. victim1)
oly.order(raider2, "attack " .. victim2)

oly.save("./lib")

print(string.format("built rng-repeat: quester=%d explorer=%d raider1=%d "
	.. "raider2=%d victim1=%d victim2=%d", quester, explorer, raider1,
	raider2, victim1, victim2))
