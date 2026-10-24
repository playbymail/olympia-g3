-- trade-market.lua -- build the trade-market scenario (issue #142).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Two factions start in Greyfell (start city 0),
-- whose city market sells wood [77] at 14 and buys woven baskets [94] at 4.
--
--   buyer     buy 77 5 14: matches the city's wood at once, 70 gold for 5
--             buy 94 2 10: no seller yet, so it stays pending
--             buy 261 1 1 then buy 261 0: posts a buy for pitch below the
--             city's price, then clears it
--   seller    (5 woven baskets, added here) waits a day, then
--             sell 94 2 9: matches the buyer's pending buy, at the seller's
--             price, 18 gold for 2
--             sell 94 3 4: sells the rest to the city, 12 gold for 3
--
-- Every start returns TRUE (ok). Gold and items move on both sides of each
-- match; the reports and the state export pin them.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0
local WOOD, BASKET = 77, 94

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

local buyers = faction(300, "Buyers", "buyer", "Buyer One")
local sellers = faction(301, "Sellers", "seller", "Seller One")
local buyer, seller = buyers.noble, sellers.noble

oly.additem(seller, BASKET, 5)

for _, o in ipairs{
		"buy " .. WOOD .. " 5 14",
		"buy " .. BASKET .. " 2 10",
		"buy 261 1 1", "buy 261 0" } do
	oly.order(buyer, o)
end
for _, o in ipairs{
		"wait day 1",
		"sell " .. BASKET .. " 2 9",
		"sell " .. BASKET .. " 3 4" } do
	oly.order(seller, o)
end

oly.save("./lib")

print(string.format("built trade-market: player=%d buyer=%d seller=%d",
	buyers.player, buyer, seller))
