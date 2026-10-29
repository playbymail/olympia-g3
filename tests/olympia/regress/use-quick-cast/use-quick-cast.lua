-- use-quick-cast.lua -- build the use-quick-cast scenario (issue #362).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each mage knows the Magic school and View aura (a 7-day cast), so
-- it is a magician, and drinks quick_cast potions before it casts:
--
--   hasty      potion of 2             speeded by 2 days: 7 -> 5
--   clamped    potion of 10            speeded by 6 days: the cast keeps
--                                      its last day
--   stacker    potions of 2 and 3      the speedups add up to 5
--   trancer    potion of 2; knows      Trance is never speeded; the 2 days
--              Trance                  carry over to the View aura after it
--   checker    no magic                use 997, use 998, use 999
--
-- add_ram (997), save_quick (998) and quick_cast (999) are in use_tbl but
-- have no skill box, and nothing in the engine makes one, so the checker's
-- uses fail as not a valid skill. A quick_cast potion is the only way a
-- noble gets a cast speedup. The potions come from oly.potion: one made in
-- the turn would have an id minted in the turn, which no order can name.

local oly = require "oly"

local MAGIC, VIEW_AURA = 800, 804	-- the Basic magic school, a skill
local ADV, TRANCE = 920, 921		-- the Advanced sorcery school, a skill

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
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

local hasty = noble(300, "Hasty Mages", "hasty", "Hasty One",
	{ MAGIC, VIEW_AURA })
local clamped = noble(301, "Clamped Mages", "clamped", "Clamped One",
	{ MAGIC, VIEW_AURA })
local stacker = noble(302, "Stacking Mages", "stacker", "Stacker One",
	{ MAGIC, VIEW_AURA })
local trancer = noble(303, "Trancers", "trancer", "Trancer One",
	{ MAGIC, VIEW_AURA, ADV, TRANCE })
local checker = noble(304, "Checkers", "checker", "Checker One", {})

local function drink_then(who, potions, casts)
	for _, q in ipairs(potions) do
		oly.order(who, "use " .. oly.potion(who, "quick_cast", q))
	end
	for _, sk in ipairs(casts) do
		oly.order(who, "use " .. sk)
	end
end

drink_then(hasty, { 2 }, { VIEW_AURA })
drink_then(clamped, { 10 }, { VIEW_AURA })
drink_then(stacker, { 2, 3 }, { VIEW_AURA })
drink_then(trancer, { 2 }, { TRANCE, VIEW_AURA })

for _, sk in ipairs{ 997, 998, 999 } do
	oly.order(checker, "use " .. sk)
end

oly.save("./lib")

print(string.format("built use-quick-cast: hasty=%d clamped=%d stacker=%d "
	.. "trancer=%d checker=%d", hasty, clamped, stacker, trancer, checker))
