-- use-alchemy.lua -- build the use-alchemy scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0);
-- each noble knows the alchemy school, the skills it uses, and has what
-- each skill needs:
--
--   brewer     an avinia leaf, ratspider venom,   use 691, use 694,
--              lana bark and a ratspider          use 696, use 693
--   scholar    a farrenstone, 5 lead and a        use 697 5, then
--              blank scroll                       use 692 697
--
-- Every start returns TRUE (ok). The three brews share v_brew and start
-- days 1, 8 and 15; extract_venom (693) has no start, so v_use hands it to
-- skill_produce, on day 25. The scholar turns its lead into gold, then
-- scribes lead_to_gold onto the scroll, a 28-day job begun on day 8.

local oly = require "oly"

local VENOM, LANA_BARK, AVINIA_LEAF = 63, 64, 65	-- items
local FARRENSTONE, RATSPIDER, BLANK_SCROLL, LEAD = 67, 81, 84, 102

local ALCHEMY, BREW_HEAL, RECORD_SKILL = 690, 691, 692	-- skills
local EXTRACT_VENOM, BREW_SLAVE, BREW_DEATH = 693, 694, 696
local LEAD_TO_GOLD = 697

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	return f.noble
end

local brewer = noble(300, "Brewers", "brewer", "Brewer One")
local scholar = noble(301, "Scholars", "scholar", "Scholar One")

for _, sk in ipairs{ ALCHEMY, BREW_HEAL, BREW_SLAVE, BREW_DEATH,
		EXTRACT_VENOM } do
	oly.know(brewer, sk)
end
for _, item in ipairs{ AVINIA_LEAF, VENOM, LANA_BARK, RATSPIDER } do
	oly.additem(brewer, item, 1)
end

for _, sk in ipairs{ ALCHEMY, RECORD_SKILL, LEAD_TO_GOLD } do
	oly.know(scholar, sk)
end
oly.additem(scholar, FARRENSTONE, 1)
oly.additem(scholar, LEAD, 5)
oly.additem(scholar, BLANK_SCROLL, 1)

for _, sk in ipairs{ BREW_HEAL, BREW_SLAVE, BREW_DEATH, EXTRACT_VENOM } do
	oly.order(brewer, "use " .. sk)
end
oly.order(scholar, "use " .. LEAD_TO_GOLD .. " 5")
oly.order(scholar, "use " .. RECORD_SKILL .. " " .. LEAD_TO_GOLD)

oly.save("./lib")

print(string.format("built use-alchemy: brewer=%d scholar=%d",
	brewer, scholar))
