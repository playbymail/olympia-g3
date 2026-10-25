-- use-stealth.lua -- build the use-stealth scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0);
-- each noble with orders knows the stealth school and the skills it uses:
--
--   thief      Greyfell              use 631 (petty thief), then
--                                    use 632, 633 and 634 on the yielder
--   yielder    Greyfell, 1500 gold   forms a hireling (contract-500), which
--                                    surrenders to the captor once it exists
--   captor     Greyfell              waits out the surrender, then
--                                    use 637 on its prisoner
--   gossip     an inn in Greyfell    use 636: rumor of the yielder's gold
--   shadow     alone in a tower      use 638 1 (hide), then use 639 (sneak
--                                    out of the tower)
--
-- Every start returns TRUE (ok). As in stealth-hide, the hireling's orders
-- are queued before it exists; they run once the yielder's 7-day form
-- makes it, on day 8.

local oly = require "oly"

local GOLD, PEASANT = 1, 10		-- items

local STEALTH, PETTY_THIEF = 630, 631	-- skills
local SPY_INV, SPY_SKILLS, SPY_LORD = 632, 633, 634
local FIND_RICH, TORTURE, HIDE_SELF, SNEAK_BUILD = 636, 637, 638, 639

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

local thief = faction(300, "Cutpurses", "thief", "Thief One").noble
local yielders = faction(301, "Yielders", "yielder", "Yielder One")
local captor = faction(302, "Captors", "captor", "Captor One").noble
local gossip = faction(303, "Gossips", "gossip", "Gossip One").noble
local shadow = faction(304, "Shadows", "shadow", "Shadow One").noble
local yielder = yielders.noble

-- the noble the yielder's form makes; its orders are queued here
local hireling = yielders.unformed[1]
assert(hireling, "the yielders need an unformed noble")

local function knows(who, skills)
	oly.know(who, STEALTH)
	for _, sk in ipairs(skills) do
		oly.know(who, sk)
	end
end

knows(thief, { PETTY_THIEF, SPY_INV, SPY_SKILLS, SPY_LORD })
knows(captor, { TORTURE })
knows(gossip, { FIND_RICH })
knows(shadow, { HIDE_SELF, SNEAK_BUILD })

-- the gossip hears of the richest noble within three provinces
oly.additem(yielder, GOLD, 1500)

local inn = oly.makeloc(gossip, "inn", "inn")
oly.poof(gossip, inn)

-- alone means no men either: a starting noble's 25 peasants count
oly.subitem(shadow, PEASANT, 25)
local tower = oly.makeloc(shadow, "tower", "tower")
oly.poof(shadow, tower)

assert(oly.loc(inn) == GREYFELL, "the inn must be in Greyfell")
assert(oly.loc(gossip) == inn, "the gossip must be in the inn")
assert(oly.loc(tower) == GREYFELL, "the tower must be in Greyfell")
assert(oly.loc(shadow) == tower, "the shadow must be in the tower")
assert(not oly.has_item(shadow, PEASANT), "the shadow must be alone")

oly.order(thief, "use " .. PETTY_THIEF)
for _, sk in ipairs{ SPY_INV, SPY_SKILLS, SPY_LORD } do
	oly.order(thief, "use " .. sk .. " " .. yielder)
end
oly.order(yielder, "form " .. hireling .. " Hireling")
oly.order(hireling, "surrender " .. captor)
oly.order(captor, "wait time 10")
oly.order(captor, "use " .. TORTURE .. " " .. hireling)
oly.order(gossip, "use " .. FIND_RICH)
oly.order(shadow, "use " .. HIDE_SELF .. " 1")
oly.order(shadow, "use " .. SNEAK_BUILD)

oly.save("./lib")

print(string.format("built use-stealth: thief=%d yielder=%d hireling=%d "
	.. "captor=%d gossip=%d shadow=%d inn=%d tower=%d", thief, yielder,
	hireling, captor, gossip, shadow, inn, tower))
