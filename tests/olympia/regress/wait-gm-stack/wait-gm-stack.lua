-- wait-gm-stack.lua -- build the wait-gm-stack scenario (issue #249).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. One faction in Greyfell (start city 0) with a
-- lone noble, the herald. `wait` is allowed to the GM player (The Fates,
-- 200), which has no units and waits as itself:
--
--   wait top                      we are the stack leader
--   wait not top time 1           one day has passed.
--   wait stack <herald> time 2    two days have passed.
--   wait not stack <herald>       Herald One [...] is not stacked with us.
--
-- Before the fix the `top` and `stack` conditions called stack_leader() on
-- the player, which asserts kind(who) == T_char, and the turn aborted. A
-- player is in no stack, so it is now its own stack leader. The herald
-- waits `top` too, as a control for a character.

local oly = require "oly"

local GM = 200				-- gm_player, The Fates
local GREYFELL = 57081			-- start city 0

oly.load("./lib")
oly.extract_startlocs()

local guild = oly.add_player{
	id = 300, faction = "Guild",
	noble = "herald", noble_name = "Herald One",
	start = "0", full_name = "P Word Here", email = "player300@example.com",
}
local herald = guild.noble

assert(oly.loc(herald) == GREYFELL, "the herald must start in Greyfell")

for _, o in ipairs{
		"wait top",
		"wait not top time 1",
		"wait stack " .. herald .. " time 2",
		"wait not stack " .. herald } do
	oly.order(GM, o)
end

oly.order(herald, "wait top")

oly.save("./lib")

print(string.format("built wait-gm-stack: player=%d herald=%d",
	guild.player, herald))
