---@diagnostic disable: undefined-global
-- ============================================================================
-- Triune AutoCombat — Entry Point
-- This repo IS a `TAC/` folder — drop it into your <MacroQuest Root>/lua/
-- directory (giving <MacroQuest Root>/lua/TAC/) and launch it with:
--     /lua run TAC
-- MacroQuest runs this init.lua whenever /lua run targets a folder.
--
-- No engine/UI logic lives here. It require()s tac.lua as a module — which
-- now loads WITHOUT starting its blocking main loop — and then calls
-- tac.start() at top level. The loop must run in the script coroutine, not
-- inside require(): mq.delay() cannot yield while a module is still being
-- imported, which either throws ("Cannot delay while importing a module") or,
-- worse, hard-freezes the game client.
--
-- tac.lua stays independently runnable via  /lua run TAC/tac  — it starts
-- itself when it detects it is the main script.
-- ============================================================================
local here = debug.getinfo(1, 'S').source:match('^@?(.*[/\\])') or ''
package.path = here .. '?.lua;' .. package.path

_G.__TAC_LAUNCHED_VIA_INIT = true
local tac = require('tac')
if type(tac) == 'table' and type(tac.start) == 'function' then
    tac.start()
end
