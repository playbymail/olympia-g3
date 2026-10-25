-- use-art-refused.lua -- build the use-art-refused scenario (issue #204).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each knows the Artifact construction school; each skill known adds
-- one aura. Each starts with 200 gold.
--
--   fumbler     15 aura, 5 mithril,     use 881, use 882 841, use 883 1,
--               a blank scroll          use 884 20, use 885 1, use 886 10,
--                                       use 887 83, use 888 82 99,
--                                       use 889 10, use 891 83, use 892 83,
--                                       use 893 83
--   novice      2 aura, a mithril, a    use 894
--               gate crystal
--
-- Every use is refused (fail). The fumbler knows every skill of the school
-- and Scry location. It forges an auraculum with no aura level; scribes
-- Scry location, not an Artifact construction spell; forges a sword and a
-- bow without the 500 gold and armor with more aura than it has; curses
-- and destroys peasants, which are not artifacts; asks with 99 aura where
-- its mithril was made; and learns the maker of, cloaks and dispels a gate
-- crystal it does not have. The novice knows only Forge palantir and has
-- too little aura for it. The fumbler's mithril and scroll, and the
-- novice's mithril and crystal, are what the skills' requirements ask.

local oly = require "oly"

local ART = 880						-- the school
local FORGE_AURA, WRITE_ART = 881, 882			-- skills
local FORGE_WEAPON, FORGE_ARMOR, FORGE_BOW = 883, 884, 885
local CURSE, SHOW_CREAT, SHOW_REG, DESTROY = 886, 887, 888, 889
local CLOAK_CREAT, CLOAK_REG, REM_CLOAK = 891, 892, 893
local FORGE_PALANTIR = 894
local SCRY_REGION = 841			-- a magic skill of another school

local PEASANT = 10			-- item, not an artifact
local MITHRIL = 82			-- item, cloaking the creator needs 5
local GATE_CRYSTAL = 83			-- item, a palantir needs one
local BLANK_SCROLL = 84			-- item, scribing and destroying need one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe

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
	oly.know(f.noble, ART)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

local fumbler = noble(300, "Fumblers", "fumbler", "Fumbler One", {
	FORGE_AURA, WRITE_ART, FORGE_WEAPON, FORGE_ARMOR, FORGE_BOW,
	CURSE, SHOW_CREAT, SHOW_REG, DESTROY,
	CLOAK_CREAT, CLOAK_REG, REM_CLOAK, FORGE_PALANTIR, SCRY_REGION,
})
oly.additem(fumbler, MITHRIL, 5)
oly.additem(fumbler, BLANK_SCROLL, 1)
local novice = noble(301, "Novices", "novice", "Novice One",
	{ FORGE_PALANTIR })
oly.additem(novice, MITHRIL, 1)
oly.additem(novice, GATE_CRYSTAL, 1)

oly.order(fumbler, "use " .. FORGE_AURA)
oly.order(fumbler, "use " .. WRITE_ART .. " " .. SCRY_REGION)
oly.order(fumbler, "use " .. FORGE_WEAPON .. " 1")
oly.order(fumbler, "use " .. FORGE_ARMOR .. " 20")
oly.order(fumbler, "use " .. FORGE_BOW .. " 1")
oly.order(fumbler, "use " .. CURSE .. " " .. PEASANT)
oly.order(fumbler, "use " .. SHOW_CREAT .. " " .. GATE_CRYSTAL)
oly.order(fumbler, "use " .. SHOW_REG .. " " .. MITHRIL .. " 99")
oly.order(fumbler, "use " .. DESTROY .. " " .. PEASANT)
oly.order(fumbler, "use " .. CLOAK_CREAT .. " " .. GATE_CRYSTAL)
oly.order(fumbler, "use " .. CLOAK_REG .. " " .. GATE_CRYSTAL)
oly.order(fumbler, "use " .. REM_CLOAK .. " " .. GATE_CRYSTAL)
oly.order(novice, "use " .. FORGE_PALANTIR)

oly.save("./lib")

print(string.format("built use-art-refused: fumbler=%d novice=%d",
	fumbler, novice))
