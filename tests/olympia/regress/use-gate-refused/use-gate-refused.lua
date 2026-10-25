-- use-gate-refused.lua -- build the use-gate-refused scenario (issue #202).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0)
-- and are moved to Mountain [13344], since magic may not be used in a safe
-- haven. The mountain holds gate 70456, unsealed, to Swamp [10896]. Each
-- noble knows the Gatecraft school and all its skills; each skill known
-- adds one aura:
--
--   drainer     12 aura             use 869 70456, use 869 70456, use 861
--   fumbler     13 aura, a blank    use 862 60605, use 863 841,
--               scroll              use 864 70456 0, use 865 70456 1,
--                                   use 866 70456 1, use 867 70456,
--                                   use 868 70456, use 869 60605,
--                                   use 871 13450, use 872 70456
--
-- Every use but the drainer's first two is refused (fail). The drainer
-- spends all its aura on two notifications and cannot detect gates. The
-- fumbler jumps and notifies at gate 60605, which is on Forest [13343];
-- scribes Scry location, not a Gatecraft spell; seals with no key;
-- unseals, notifies of unsealing, breaks the seal and reveals the key of a
-- gate that is not sealed; teleports with no gate crystal; and jumps
-- backwards through a gate that does not lead here.

local oly = require "oly"

local GATE = 860					-- the school
local DETECT, JUMP, WRITE, SEAL = 861, 862, 863, 864	-- skills
local UNSEAL, NOTIFY_UNSEAL, REM_SEAL = 865, 866, 867
local REVEAL_KEY, NOTIFY_JUMP, TELEPORT, REV_JUMP = 868, 869, 871, 872
local SCRY_REGION = 841			-- a magic skill of another school

local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local MOUNTAIN = 13344			-- holds gate 70456, to Swamp [10896]

local HERE_GATE = 70456			-- on the mountain, unsealed
local AWAY_GATE = 60605			-- on Forest [13343]

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
	oly.know(f.noble, GATE)
	for sk = DETECT, REV_JUMP do
		if sk % 10 ~= 0 then
			oly.know(f.noble, sk)
		end
	end
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, MOUNTAIN)
	assert(oly.loc(f.noble) == MOUNTAIN, name .. " must be on the mountain")
	return f.noble
end

-- two notifications cost six aura each
local drainer = noble(300, "Drainers", "drainer", "Drainer One", {})
-- the fumbler scribes a spell it knows from another school
local fumbler = noble(301, "Fumblers", "fumbler", "Fumbler One",
	{ SCRY_REGION })
oly.additem(fumbler, BLANK_SCROLL, 1)

oly.order(drainer, "use " .. NOTIFY_JUMP .. " " .. HERE_GATE)
oly.order(drainer, "use " .. NOTIFY_JUMP .. " " .. HERE_GATE)
oly.order(drainer, "use " .. DETECT)
oly.order(fumbler, "use " .. JUMP .. " " .. AWAY_GATE)
oly.order(fumbler, "use " .. WRITE .. " " .. SCRY_REGION)
oly.order(fumbler, "use " .. SEAL .. " " .. HERE_GATE .. " 0")
oly.order(fumbler, "use " .. UNSEAL .. " " .. HERE_GATE .. " 1")
oly.order(fumbler, "use " .. NOTIFY_UNSEAL .. " " .. HERE_GATE .. " 1")
oly.order(fumbler, "use " .. REM_SEAL .. " " .. HERE_GATE)
oly.order(fumbler, "use " .. REVEAL_KEY .. " " .. HERE_GATE)
oly.order(fumbler, "use " .. NOTIFY_JUMP .. " " .. AWAY_GATE)
oly.order(fumbler, "use " .. TELEPORT .. " " .. PLAIN)
oly.order(fumbler, "use " .. REV_JUMP .. " " .. HERE_GATE)

oly.save("./lib")

print(string.format("built use-gate-refused: drainer=%d fumbler=%d",
	drainer, fumbler))
