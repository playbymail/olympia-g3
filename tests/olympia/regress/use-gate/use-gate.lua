-- use-gate.lua -- build the use-gate scenario (issue #202).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Four factions start in Greyfell (start city 0)
-- and are moved to the base world's gates, since magic may not be used in a
-- safe haven. Each noble knows the Gatecraft school and all its skills; each
-- skill known adds one aura:
--
--   jumper      13 aura, a gate     use 869 70456, use 862 70456,
--               crystal, no         use 872 70456, use 871 13450
--               peasants
--   sealer      12 aura, a blank    use 861, use 864 60605 123,
--               scroll              use 865 60605 123, use 863 861
--   keyfinder   12 aura             use 868 59070
--   watcher     13 aura             use 866 59070 237, use 867 59070
--
-- Every start returns TRUE (ok). The jumper, on Mountain [13344], has itself
-- told of jumps through the gate there, jumps it to Swamp [10896], jumps
-- back the wrong way and teleports to Plain [13450]. The sealer, on Forest
-- [13343], detects the gate there, seals it with key 123, unseals it and
-- scribes Detect gates. The keyfinder and the watcher stand in the hidden
-- ring of stones [64135] on Plain [12239], whose gates are sealed in the
-- base world: the keyfinder learns the key to gate 59070 (237), and the
-- watcher has itself told when it is unsealed and then breaks the seal.

local oly = require "oly"

local GATE = 860					-- the school
local DETECT, JUMP, WRITE, SEAL = 861, 862, 863, 864	-- skills
local UNSEAL, NOTIFY_UNSEAL, REM_SEAL = 865, 866, 867
local REVEAL_KEY, NOTIFY_JUMP, TELEPORT, REV_JUMP = 868, 869, 871, 872
local SCRY_REGION = 841			-- a magic skill, for one more aura

local PEASANT = 10			-- item, 100 weight each
local GATE_CRYSTAL = 83			-- item, teleporting spends one
local BLANK_SCROLL = 84			-- item, scribing needs one

local GREYFELL = 57081			-- start city 0, a safe haven
local PLAIN = 13450			-- west of Greyfell's forest, not safe
local MOUNTAIN = 13344			-- holds gate 70456, to Swamp [10896]
local FOREST = 13343			-- holds gate 60605, to Ocean [13353]
local RING = 64135			-- hidden ring of stones on Plain [12239]

local OPEN_GATE = 70456			-- the jumper's, unsealed
local SEAL_GATE = 60605			-- the sealer's, unsealed
local SEALED_GATE = 59070		-- in the ring, sealed with key 237
local SEALED_KEY = 237
local KEY = 123				-- the sealer's key

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
	oly.know(f.noble, GATE)
	for sk = DETECT, REV_JUMP do
		if sk % 10 ~= 0 then
			oly.know(f.noble, sk)
		end
	end
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, where)
	assert(oly.loc(f.noble) == where, name .. " must be at " .. where)
	return f.noble
end

-- jumping costs one aura per 250 weight, teleporting one per 50: the
-- jumper leaves its peasants behind, so its stack is the noble and the
-- crystal (101), and its uses cost 6 + 1 + 2 + 3
local jumper = noble(300, "Jumpers", "jumper", "Jumper One", MOUNTAIN,
	{ SCRY_REGION })
oly.subitem(jumper, PEASANT, 25)
oly.additem(jumper, GATE_CRYSTAL, 1)
-- the sealer scribes Detect gates onto a blank scroll
local sealer = noble(301, "Sealers", "sealer", "Sealer One", FOREST, {})
oly.additem(sealer, BLANK_SCROLL, 1)
local keyfinder = noble(302, "Keyfinders", "keyfinder", "Keyfinder One",
	RING, {})
-- notifying costs five aura and breaking the seal eight
local watcher = noble(303, "Watchers", "watcher", "Watcher One", RING,
	{ SCRY_REGION })

oly.order(jumper, "use " .. NOTIFY_JUMP .. " " .. OPEN_GATE)
oly.order(jumper, "use " .. JUMP .. " " .. OPEN_GATE)
oly.order(jumper, "use " .. REV_JUMP .. " " .. OPEN_GATE)
oly.order(jumper, "use " .. TELEPORT .. " " .. PLAIN)
oly.order(sealer, "use " .. DETECT)
oly.order(sealer, "use " .. SEAL .. " " .. SEAL_GATE .. " " .. KEY)
oly.order(sealer, "use " .. UNSEAL .. " " .. SEAL_GATE .. " " .. KEY)
oly.order(sealer, "use " .. WRITE .. " " .. DETECT)
oly.order(keyfinder, "use " .. REVEAL_KEY .. " " .. SEALED_GATE)
oly.order(watcher, "use " .. NOTIFY_UNSEAL .. " " .. SEALED_GATE .. " "
	.. SEALED_KEY)
oly.order(watcher, "use " .. REM_SEAL .. " " .. SEALED_GATE)

oly.save("./lib")

print(string.format("built use-gate: jumper=%d sealer=%d keyfinder=%d watcher=%d",
	jumper, sealer, keyfinder, watcher))
