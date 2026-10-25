-- use-religion.lua -- build the use-religion scenario (issue #192).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Five factions start in Greyfell (start city 0).
-- The nobles of 303 and 304 are killed with oly.kill (#192), and their dead
-- bodies handed to the priests who need them. Each priest knows the
-- religion school and the skills it uses:
--
--   seer       Greyfell             use 751 (a vision of Greyfell), then
--                                   use 755 and use 756 on itself
--   healer     Greyfell, a body     use 753 (pray), then use 754 (resurrect)
--   mourner    Graveyard [59022],   use 752 (last rites)
--              a body
--
-- Every start returns TRUE (ok). The seer has no blessed soldiers, so the
-- blessing it removes is not there. The healer's prayer makes its next
-- religious act succeed, and the body's defense is above 50, so it raises
-- the dead noble.

local oly = require "oly"

local RELIGION, REVEAL_VISION, LAST_RITES = 750, 751, 752	-- skills
local PRAY, RESURRECT, REMOVE_BLESS, VISION_PROTECT = 753, 754, 755, 756

local GREYFELL = 57081			-- start city 0
local GRAVEYARD = 59022

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

local seer = noble(300, "Seers", "seer", "Seer One")
local healer = noble(301, "Healers", "healer", "Healer One")
local mourner = noble(302, "Mourners", "mourner", "Mourner One")
local lazarus = noble(303, "Risen", "lazarus", "Lazarus One")
local departed = noble(304, "Departed", "departed", "Departed One")

local function knows(who, skills)
	oly.know(who, RELIGION)
	for _, sk in ipairs(skills) do
		oly.know(who, sk)
	end
end

knows(seer, { REVEAL_VISION, REMOVE_BLESS, VISION_PROTECT })
knows(healer, { PRAY, RESURRECT })
knows(mourner, { LAST_RITES })

local body1 = oly.kill(lazarus, healer)
local body2 = oly.kill(departed, mourner)
oly.poof(mourner, GRAVEYARD)

assert(oly.has_item(healer, body1), "the healer must hold Lazarus's body")
assert(oly.has_item(mourner, body2), "the mourner must hold the body")
assert(oly.loc(mourner) == GRAVEYARD, "the mourner must be in the graveyard")

oly.order(seer, "use " .. REVEAL_VISION .. " " .. GREYFELL)
oly.order(seer, "use " .. REMOVE_BLESS)
oly.order(seer, "use " .. VISION_PROTECT)
oly.order(healer, "use " .. PRAY)
oly.order(healer, "use " .. RESURRECT .. " " .. body1)
oly.order(mourner, "use " .. LAST_RITES .. " " .. body2)

oly.save("./lib")

print(string.format("built use-religion: seer=%d healer=%d mourner=%d "
	.. "body1=%d body2=%d", seer, healer, mourner, body1, body2))
