-- use-basic.lua -- build the use-basic scenario (issue #196).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0)
-- and are moved to Plain [13450], since magic may not be used in a safe
-- haven. Each noble knows the Magic school and the skills it uses; each
-- skill known adds one aura:
--
--   adept      7 aura, a       use 803 1, use 805 <patient>, use 804 1,
--              blank scroll    use 807 <patient> 800 1, use 806 801
--   patient    5 aura, sick    use 801, use 808 1, use 813, use 811
--   shrouder   5 aura          use 809 1, use 812 <adept>,
--                              use 814 <patient> 1, use 802
--
-- Every start returns TRUE (ok). The adept appears common, heals the sick
-- patient, views the aura of the mages here, reveals the patient's magic
-- and scribes Meditate onto a scroll. The patient meditates, taps its
-- health for aura, meditates again (advanced) and practices ability scry
-- detection. The shrouder shrouds its abilities, dispels the adept's
-- shroud (there is none), hinders the patient's meditation and works at
-- common magic for gold on the plain.

local oly = require "oly"

local MAGIC = 800					-- the school
local MEDITATE, MENIAL, APPEAR, VIEW_AURA = 801, 802, 803, 804	-- skills
local HEAL, WRITE, REVEAL, TAP = 805, 806, 807, 808
local SHROUD, DETECT, DISPEL, ADV_MED, HINDER = 809, 811, 812, 813, 814

local BLANK_SCROLL = 84			-- item, scribing needs one

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
	oly.know(f.noble, MAGIC)
	for _, sk in ipairs(skills) do
		oly.know(f.noble, sk)
	end
	oly.poof(f.noble, PLAIN)
	assert(oly.loc(f.noble) == PLAIN, name .. " must be on the plain")
	return f.noble
end

-- the adept scribes Meditate, so it knows it too, onto a blank scroll
local adept = noble(300, "Adepts", "adept", "Adept One",
	{ MEDITATE, APPEAR, VIEW_AURA, HEAL, WRITE, REVEAL })
oly.additem(adept, BLANK_SCROLL, 1)
local patient = noble(301, "Patients", "patient", "Patient One",
	{ MEDITATE, TAP, DETECT, ADV_MED })
local shrouder = noble(302, "Shrouders", "shrouder", "Shrouder One",
	{ MENIAL, SHROUD, DISPEL, HINDER })

-- heal works only on a sick character
oly.sick(patient)

oly.order(adept, "use " .. APPEAR .. " 1")
oly.order(adept, "use " .. HEAL .. " " .. patient)
oly.order(adept, "use " .. VIEW_AURA .. " 1")
oly.order(adept, "use " .. REVEAL .. " " .. patient .. " " .. MAGIC .. " 1")
oly.order(adept, "use " .. WRITE .. " " .. MEDITATE)
oly.order(patient, "use " .. MEDITATE)
oly.order(patient, "use " .. TAP .. " 1")
oly.order(patient, "use " .. ADV_MED)
oly.order(patient, "use " .. DETECT)
oly.order(shrouder, "use " .. SHROUD .. " 1")
oly.order(shrouder, "use " .. DISPEL .. " " .. adept)
oly.order(shrouder, "use " .. HINDER .. " " .. patient .. " 1")
oly.order(shrouder, "use " .. MENIAL)

oly.save("./lib")

print(string.format("built use-basic: adept=%d patient=%d shrouder=%d",
	adept, patient, shrouder))
