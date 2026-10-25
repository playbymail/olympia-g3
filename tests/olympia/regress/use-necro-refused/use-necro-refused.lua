-- use-necro-refused.lua -- build the use-necro-refused scenario (issue #214).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0).
-- The fumbler is moved to Plain [13450] and the novice to Graveyard
-- [59022], since magic may not be used in a safe haven. Each knows the
-- Necromancy school; each skill known adds one aura. Each starts with 200
-- gold.
--
--   fumbler     a blank scroll, knows   use 901 5, use 903 841, use 904 3,
--               Scry location           use 905 F, use 907 10,
--                                       use 908 novice 2
--   novice      2 aura                  use 906 F
--
-- Every use is refused (fail). The fumbler knows every skill of the school
-- and Scry location. It raises corpses on a plain, which has none; scribes
-- Scry location, not a Necromancy spell; summons a demon lord away from a
-- graveyard; renews the bond of itself, which is not a demon lord; eats
-- peasants, which are not a dead body; and blasts the novice, who is not
-- on the plain. The novice knows only Banish demon lord and has too little
-- aura for it. The fumbler's scroll is what Runes of Evil requires.

local oly = require "oly"

local NECRO = 900					-- the school
local RAISE, SUMMON_GHOST, WRITE_NECRO = 901, 902, 903	-- skills
local UNDEAD_LORD, RENEW, BANISH = 904, 905, 906
local EAT_DEAD, AURA_BLAST, ABSORB_BLAST = 907, 908, 909
local TRANSCEND = 911
local SCRY_REGION = 841			-- a magic skill of another school

local PEASANT = 10			-- item, not a dead body
local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local GRAVEYARD = 59022			-- 15 corpses and an undead cookie

oly.load("./lib")
oly.extract_startlocs()

local function noble(id, faction, handle, name, where, skills)
	local f = oly.add_player{
		id = id, faction = faction,
		noble = handle, noble_name = name,
		start = "0", full_name = "P Word Here",
		email = string.format("player%d@example.com", id),
	}
	assert(oly.loc(f.noble) == GREYFELL, name .. " must start in Greyfell")
	oly.know(f.noble, NECRO)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be moved")
	return f.noble
end

local fumbler = noble(300, "Fumblers", "fumbler", "Fumbler One", PLAIN, {
	RAISE, SUMMON_GHOST, WRITE_NECRO, UNDEAD_LORD, RENEW, BANISH,
	EAT_DEAD, AURA_BLAST, ABSORB_BLAST, TRANSCEND, SCRY_REGION,
})
oly.additem(fumbler, BLANK_SCROLL, 1)
local novice = noble(301, "Novices", "novice", "Novice One", GRAVEYARD,
	{ BANISH })

oly.order(fumbler, "use " .. RAISE .. " 5")
oly.order(fumbler, "use " .. WRITE_NECRO .. " " .. SCRY_REGION)
oly.order(fumbler, "use " .. UNDEAD_LORD .. " 3")
oly.order(fumbler, "use " .. RENEW .. " " .. fumbler)
oly.order(fumbler, "use " .. EAT_DEAD .. " " .. PEASANT)
oly.order(fumbler, "use " .. AURA_BLAST .. " " .. novice .. " 2")
oly.order(novice, "use " .. BANISH .. " " .. fumbler)

oly.save("./lib")

print(string.format("built use-necro-refused: fumbler=%d novice=%d",
	fumbler, novice))
