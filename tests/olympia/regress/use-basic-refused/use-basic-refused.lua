-- use-basic-refused.lua -- build the use-basic-refused scenario (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0)
-- and are moved to Forest [13550], which is not a safe haven and has no
-- work at common magic. Each noble knows the Magic school and the skills it
-- uses; each skill known adds one aura:
--
--   bungler   5 aura, a blank   use 802, use 805 <pauper>, use 806 801,
--             scroll            use 807 <pauper> 0
--   pauper    6 aura            use 803 99, use 803 6, use 804 1, use 811,
--                               use 812 <bungler>, use 814 <bungler> 1
--
-- Every start but one fails. The bungler finds no work at common magic in
-- the forest, tries to heal the pauper, who is not sick, to scribe
-- Meditate, which it does not know, and to reveal the pauper's magic in
-- category 0, which is no skill. The pauper asks Appear common for more
-- aura than it has, then spends all six on it (that one starts), and
-- every spell after needs aura it no longer has. meditate, tap_health,
-- shroud_abil and adv_med always start, so they have no fail cell.

local oly = require "oly"

local MAGIC = 800					-- the school
local MEDITATE, MENIAL, APPEAR, VIEW_AURA = 801, 802, 803, 804	-- skills
local HEAL, WRITE, REVEAL = 805, 806, 807
local DETECT, DISPEL, HINDER = 811, 812, 814

local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local FOREST = 13550			-- south of Plain [13450], not safe

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, skills)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.know(f.noble, MAGIC)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, FOREST)
	assert(oly.loc(f.noble) == FOREST, name .. " must be in the forest")
	return f.noble
end

-- the scroll gets the scribe past meets_requirements, to its start
local bungler = noble(300, "Bunglers", "bungler", "Bungler One",
	{ MENIAL, HEAL, WRITE, REVEAL })
oly.additem(bungler, BLANK_SCROLL, 1)
local pauper = noble(301, "Paupers", "pauper", "Pauper One",
	{ APPEAR, VIEW_AURA, DETECT, DISPEL, HINDER })

oly.order(bungler, "use " .. MENIAL)
oly.order(bungler, "use " .. HEAL .. " " .. pauper)
oly.order(bungler, "use " .. WRITE .. " " .. MEDITATE)
oly.order(bungler, "use " .. REVEAL .. " " .. pauper .. " 0")
oly.order(pauper, "use " .. APPEAR .. " 99")
oly.order(pauper, "use " .. APPEAR .. " 6")
oly.order(pauper, "use " .. VIEW_AURA .. " 1")
oly.order(pauper, "use " .. DETECT)
oly.order(pauper, "use " .. DISPEL .. " " .. bungler)
oly.order(pauper, "use " .. HINDER .. " " .. bungler .. " 1")

oly.save("./lib")

print(string.format("built use-basic-refused: bungler=%d pauper=%d",
	bungler, pauper))
