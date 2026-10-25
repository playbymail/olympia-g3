-- use-beast.lua -- build the use-beast scenario (issue #194).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Three factions start in Greyfell (start city 0);
-- each noble knows the beastmastery school and the skills it uses:
--
--   wrangler    Plain [13450], 4 wild horses   use 651 13451, use 654 51 51,
--                                              use 655 2, use 656 1,
--                                              use 657 1
--   drummer     Plain [13450], 1 drum,         use 658, use 659 <savage>
--               a bonded savage band
--   kennel      Greyfell                       use 661
--
-- Every start returns TRUE (ok). The bird spies on the forest east of the
-- plain; the wrangler then breeds two wild horses, catches two more on the
-- plain and trains one each to a riding horse and a warmount. The drummer
-- sounds a call to arms, then keeps a band of savages that oly.savage left
-- bonded beside it, as an earlier call to arms would have. (The savage this
-- call brings arrives only on day 7.) breed_hound takes 28 days, so the
-- kennel does nothing else.

local oly = require "oly"

local WILD_HORSE, DRUM = 51, 98		-- items

local BEAST, BIRD_SPY, BREED, CATCH = 650, 651, 654, 655	-- skills
local TRAIN_WILD, TRAIN_WAR, SUMMON, KEEP = 656, 657, 658, 659
local BREED_HOUND = 661

local GREYFELL = 57081			-- start city 0
local PLAIN, FOREST = 13450, 13451

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

local wrangler = noble(300, "Wranglers", "wrangler", "Wrangler One")
local drummer = noble(301, "Drummers", "drummer", "Drummer One")
local kennel = noble(302, "Kennels", "kennel", "Kennel One")

-- breeding takes two wild horses and each training one more
for _, sk in ipairs{ BEAST, BIRD_SPY, BREED, CATCH, TRAIN_WILD,
		TRAIN_WAR } do
	oly.know(wrangler, sk)
end
oly.additem(wrangler, WILD_HORSE, 4)
oly.poof(wrangler, PLAIN)

-- keep_savage is listed under summon_savage
for _, sk in ipairs{ BEAST, SUMMON, KEEP } do
	oly.know(drummer, sk)
end
oly.additem(drummer, DRUM, 1)
oly.poof(drummer, PLAIN)
local savage = oly.savage(PLAIN, 6, "savage")

oly.know(kennel, BEAST)
oly.know(kennel, BREED_HOUND)

assert(oly.loc(wrangler) == PLAIN, "the wrangler must be on the plain")
assert(oly.loc(drummer) == PLAIN, "the drummer must be on the plain")
assert(oly.loc(savage) == PLAIN, "the savages must be on the plain")

oly.order(wrangler, "use " .. BIRD_SPY .. " " .. FOREST)
oly.order(wrangler, "use " .. BREED .. " " .. WILD_HORSE .. " " .. WILD_HORSE)
oly.order(wrangler, "use " .. CATCH .. " 2")
oly.order(wrangler, "use " .. TRAIN_WILD .. " 1")
oly.order(wrangler, "use " .. TRAIN_WAR .. " 1")
oly.order(drummer, "use " .. SUMMON)
oly.order(drummer, "use " .. KEEP .. " " .. savage)
oly.order(kennel, "use " .. BREED_HOUND)

oly.save("./lib")

print(string.format("built use-beast: wrangler=%d drummer=%d kennel=%d "
	.. "savage=%d", wrangler, drummer, kennel, savage))
