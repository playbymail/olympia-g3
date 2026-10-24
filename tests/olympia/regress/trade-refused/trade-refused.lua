-- trade-refused.lua -- build the trade-refused scenario (issue #142).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction starts in Greyfell (start city 0).
-- The trader orders buy and sell so that each fails:
--
--   <noble> 1 1   not an item (the trader's own id)
--   1 1 1         can't buy or sell gold
--   77 5 14 0 1   a cloaked trade without Conceal identity of trader [731]
--   77 5          qty > 0 with no price
--
-- Rejected: buy, sell and fee are for nobles (c), so the player entity's
-- orders for all three are refused. fee has no fail: v_fee always starts.

local oly = require "oly"

local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local traders = oly.add_player{
	id = 300, faction = "Traders",
	noble = "trader", noble_name = "Trader One",
	start = "0", full_name = "P Word Here",
	email = "player300@example.com",
}
local trader = traders.noble
assert(oly.loc(trader) == GREYFELL, "Trader One must start in Greyfell")

for _, v in ipairs{ "buy", "sell" } do
	for _, args in ipairs{
			trader .. " 1 1", "1 1 1", "77 5 14 0 1", "77 5" } do
		oly.order(trader, v .. " " .. args)
	end
end
for _, o in ipairs{ "buy 77 1 14", "sell 77 1 7", "fee 1" } do
	oly.order(traders.player, o)
end

oly.save("./lib")

print(string.format("built trade-refused: player=%d trader=%d",
	traders.player, trader))
