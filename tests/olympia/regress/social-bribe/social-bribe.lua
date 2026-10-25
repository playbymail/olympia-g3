-- social-bribe.lua -- build the social-bribe scenario (issue #146).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0);
-- three are poofed to Forest [13449], where oly.mob (#139) seeds a mob:
--
--   inciter     knows Incite mob: incites the mob against the mark, first
--               with the incite order (its cmd_tbl row has no finish, so it
--               only spends seven days), then with `use 675`, whose d_incite
--               draws on the social stream and sends the mob to attack
--   mark        the target of the bribe and of the incited mob
--   briber      knows Bribe noble: bribes the mark with 100 gold (the mark
--               is oath-2, under any threshold, so the gold is pocketed or
--               reported on a social-stream draw)
--   terrorizer  forms a hireling (contract-500, stacked beneath it), then
--               terrorizes it into fear loyalty (Greyfell)
--
-- Every start returns TRUE (ok). The social draws are keyed on (actor,
-- target) and the day; with the inciters first the ids make the incite
-- succeed (and the mark reports the bribe). The terrorizer's second order waits in its
-- queue until the 7-day form has made the hireling, on day 8.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local FOREST = 13449

local PERSUASION = 670			-- skills
local BRIBE_NOBLE, INCITE_MOB = 671, 675

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

local inciters = faction(300, "Inciters", "inciter", "Inciter One")
local marks = faction(301, "Marks", "mark", "Mark One")
local bribers = faction(302, "Bribers", "briber", "Briber One")
local terrorizers = faction(303, "Terrorizers", "terrorizer", "Terrorizer One")
local briber, mark = bribers.noble, marks.noble
local inciter, terrorizer = inciters.noble, terrorizers.noble

-- the noble the terrorizer's form makes
local hireling = terrorizers.unformed[1]
assert(hireling, "the terrorizers need an unformed noble")

oly.know(briber, BRIBE_NOBLE)
oly.know(inciter, PERSUASION)		-- use needs the parent skill
oly.know(inciter, INCITE_MOB)

for _, who in ipairs{ briber, mark, inciter } do
	oly.poof(who, FOREST)
	assert(oly.loc(who) == FOREST, "briber, mark and inciter must be in the forest")
end
local mob = oly.mob(FOREST, "mob")
assert(oly.loc(mob) == FOREST, "the mob must be in the forest")

oly.order(briber, "bribe " .. mark .. " 100")
oly.order(inciter, "incite " .. mob .. " " .. mark)
oly.order(inciter, "use " .. INCITE_MOB .. " " .. mob .. " " .. mark)
oly.order(terrorizer, "form " .. hireling .. " Hireling")
oly.order(terrorizer, "terrorize " .. hireling .. " 3")

oly.save("./lib")

print(string.format("built social-bribe: briber=%d mark=%d inciter=%d "
	.. "terrorizer=%d hireling=%d mob=%d", briber, mark, inciter,
	terrorizer, hireling, mob))
