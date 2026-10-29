-- stop-running-stop.lua -- queue turn 2 of the stop-running scenario (#361).
--
-- Run by build-scenario.sh after turn 1, on the lib that turn saved; the
-- lib it saves is frozen as scenario.patch. The nine units that
-- stop-running.lua set going are still running, and each gets a STOP and
-- then one more order, which runs once the STOP has interrupted it:
--
--   quarrier, fisher        collect             STOP, then the quarrier
--                                               collects 2 more stone
--   trainer, wrangler       make (1-day row,    STOP
--                           multi-day row)
--   mender, waller,         repair (both, the   STOP
--   patcher                 defense, the
--                           damage)
--   sailor, pilot           sail, use 601,      STOP, then sail north
--                           on a 3-day leg      again from where they were
--
-- The idler and the loafer start a collect and a repair here (oly.start,
-- as an earlier turn would leave them), so the STOP finds them running
-- with nothing done yet.

local oly = require "oly"

local WOOD, STONE = 77, 78		-- items
local SAILING = 601			-- skill

local id = dofile("ids.lua")

oly.load("./lib")

local function stop(who, after)
	oly.order(who, "stop")
	if after then
		oly.order(who, after)
	end
end

stop(id.quarrier, "collect " .. STONE .. " 2")
stop(id.fisher, "wait time 1")
stop(id.trainer, "wait time 1")
stop(id.wrangler, "wait time 1")
stop(id.mender, "wait time 1")
stop(id.waller, "wait time 1")
stop(id.patcher, "wait time 1")
stop(id.sailor, "sail north")
stop(id.pilot, "use " .. SAILING .. " north")

oly.order(id.idler, "collect " .. WOOD .. " 0 0")
oly.start(id.idler)
stop(id.idler, "wait time 1")

oly.order(id.loafer, "repair")
oly.start(id.loafer)
stop(id.loafer, "wait time 1")

oly.save("./lib")

print(string.format("built stop-running: quarrier=%d fisher=%d trainer=%d "
	.. "wrangler=%d mender=%d waller=%d patcher=%d sailor=%d pilot=%d "
	.. "idler=%d loafer=%d", id.quarrier, id.fisher, id.trainer,
	id.wrangler, id.mender, id.waller, id.patcher, id.sailor, id.pilot,
	id.idler, id.loafer))
