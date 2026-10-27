-- order-quoted-comment.lua -- build the order-quoted-comment scenario (issue #315).
--
-- Run by build-scenario.sh against the bare-map fixture; the lib it saves is
-- frozen as scenario.patch. Six factions start in Greyfell (start city 0),
-- and each noble renames itself with one order:
--
--   one      name "Joe #1"             quoted #: kept
--   two      name Joe's keep # note     apostrophe inside a word: comment cut
--   three    name 'Ann #2' # note       single-quoted #, then a comment
--   four     name "Bob # x              unterminated quote: runs to the end
--   five     name Cal "                 quote is the last character
--   six      name Dee # "hi"            quote inside the comment
--
-- remove_comment() (olympia/input.c) meant to skip quoted text, but its
-- inner loop started on the opening quote and never advanced: every # cut
-- the line, and a quote at the end of the line walked it past the NUL.
-- Now a quote counts at the start of a token, as in parse_line().

local oly = require "oly"

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
	return f.noble
end

local one = faction(300, "One", "one", "One Noble")
local two = faction(301, "Two", "two", "Two Noble")
local three = faction(302, "Three", "three", "Three Noble")
local four = faction(303, "Four", "four", "Four Noble")
local five = faction(304, "Five", "five", "Five Noble")
local six = faction(305, "Six", "six", "Six Noble")

oly.order(one, 'name "Joe #1"')
oly.order(two, "name Joe's keep # note")
oly.order(three, "name 'Ann #2' # note")
oly.order(four, 'name "Bob # x')
oly.order(five, 'name Cal "')
oly.order(six, 'name Dee # "hi"')

oly.save("./lib")

print(string.format("built order-quoted-comment: one=%d two=%d three=%d four=%d five=%d six=%d",
	one, two, three, four, five, six))
