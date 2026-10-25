-- use-necro.lua -- build the use-necro scenario (issue #214).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Seven factions start in Greyfell (start city 0).
-- The raiser and the summoner are moved to Graveyard [59022], the renewer to
-- Graveyard [59095]; the rest to Plain [13450], since magic may not be used
-- in a safe haven. Each necromancer knows the Necromancy school and all its
-- skills; each skill known adds one aura. Each starts with 200 gold.
--
--   raiser      a blank scroll          use 901 5, use 903 908
--   summoner                            use 904 3
--   renewer     a demon lord U          use 905 U, use 906 U
--   eater       ratspider venom, the    use 907 B
--               departed's body B
--   blaster                             use 908 absorber 2
--   absorber    knows only Absorb       use 909 0
--               aura blast
--   departed    knows Shipcraft; killed before the turn, its dead body
--               is B
--
-- Every start returns TRUE (ok). The raiser raises five corpses in its
-- graveyard and scribes Aura blast. The summoner summons a demon lord from
-- the same graveyard. The renewer renews its demon lord's bond, then
-- banishes it. The eater eats the departed's body and learns Shipcraft from
-- it. The blaster blasts the absorber, who absorbs the blast. The demon
-- lord comes from oly.undead: one summoned in the turn has an id minted in
-- the turn.

local oly = require "oly"

local NECRO = 900					-- the school
local RAISE, SUMMON_GHOST, WRITE_NECRO = 901, 902, 903	-- skills
local UNDEAD_LORD, RENEW, BANISH = 904, 905, 906
local EAT_DEAD, AURA_BLAST, ABSORB_BLAST = 907, 908, 909
local TRANSCEND = 911

local SHIPCRAFT = 600			-- a school the departed knows

local VENOM = 63			-- item, eating the dead spends one
local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local GRAVEYARD1 = 59022		-- 15 corpses and an undead cookie
local GRAVEYARD2 = 59095		-- the same

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
	if skills then
		oly.know(f.noble, NECRO)
		for _, sk in ipairs(skills) do
			oly.know(f.noble, sk)
		end
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be moved")
	return f.noble
end

local ALL = { RAISE, SUMMON_GHOST, WRITE_NECRO, UNDEAD_LORD, RENEW, BANISH,
	EAT_DEAD, AURA_BLAST, ABSORB_BLAST, TRANSCEND }

local raiser = noble(300, "Raisers", "raiser", "Raiser One",
	GRAVEYARD1, ALL)
oly.additem(raiser, BLANK_SCROLL, 1)
local summoner = noble(301, "Summoners", "summoner", "Summoner One",
	GRAVEYARD1, ALL)
local renewer = noble(302, "Renewers", "renewer", "Renewer One",
	GRAVEYARD2, ALL)
local lord = oly.undead(renewer, "lord")
local eater = noble(303, "Eaters", "eater", "Eater One", PLAIN, ALL)
oly.additem(eater, VENOM, 1)
local blaster = noble(304, "Blasters", "blaster", "Blaster One", PLAIN, ALL)
local absorber = noble(305, "Absorbers", "absorber", "Absorber One", PLAIN,
	{ ABSORB_BLAST })
local departed = noble(306, "Departed", "departed", "Departed One", PLAIN)
oly.know(departed, SHIPCRAFT)
local body = oly.kill(departed, eater)

oly.order(raiser, "use " .. RAISE .. " 5")
oly.order(raiser, "use " .. WRITE_NECRO .. " " .. AURA_BLAST)
oly.order(summoner, "use " .. UNDEAD_LORD .. " 3")
oly.order(renewer, "use " .. RENEW .. " " .. lord)
oly.order(renewer, "use " .. BANISH .. " " .. lord)
oly.order(eater, "use " .. EAT_DEAD .. " " .. body)
oly.order(blaster, "use " .. AURA_BLAST .. " " .. absorber .. " 2")
oly.order(absorber, "use " .. ABSORB_BLAST .. " 0")

oly.save("./lib")

print(string.format("built use-necro: raiser=%d summoner=%d renewer=%d "
	.. "lord=%d eater=%d body=%d blaster=%d absorber=%d", raiser,
	summoner, renewer, lord, eater, body, blaster, absorber))
