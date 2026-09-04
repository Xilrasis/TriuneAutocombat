-- .luacheckrc — Luacheck configuration for TriuneAutocombat
-- Lives in TAC/util/ (not TAC/'s top level) since it's a dev-only config
-- file, not part of what ships to a MacroQuest install. Runs on CI via
-- `luacheck TAC --config TAC/util/.luacheckrc` from the repo root, to catch
-- typos, unused vars, shadowed locals, and references to undefined globals.
-- All `files[...]` keys below are relative to the repo root (the luacheck
-- invocation's cwd), not to this config file's own location in TAC/util/.

std = "luajit"

-- Maximum line length (disabled — some UI lines are naturally long)
max_line_length = false

-- MacroQuest / ImGui globals that MQ injects at runtime
globals = {
    "mq",
    "ImGui",
    "ImGuiCond",
    "ImGuiCol",
    "ImGuiStyleVar",
    "ImGuiTableFlags",
    "ImGuiTableColumnFlags",
    "ImGuiSelectableFlags",
    "ImGuiWindowFlags",
    "ImGuiTreeNodeFlags",
    "ImGuiTabBarFlags",
    "ImGuiTabItemFlags",
    "ImGuiMod",
    "ImGuiKey",
    "ImVec2",
    "ImVec4",
    "IM_COL32",
    "bit",
    "DATA",
}

-- Read-only globals (can be read but not assigned)
read_globals = {
    "clearCursor",
    os = { fields = { "clock", "time", "date", "difftime" } },
    string = { fields = { "format", "find", "match", "gmatch", "gsub",
                          "sub", "upper", "lower", "len", "rep", "byte",
                          "char", "reverse" } },
    table  = { fields = { "insert", "remove", "sort", "concat", "maxn" } },
    math   = { fields = { "floor", "ceil", "abs", "min", "max", "sqrt",
                          "huge", "random", "randomseed", "pi", "fmod",
                          "sin", "cos", "atan2" } },
    io     = { fields = { "open", "read", "write", "close" } },
}

-- Per-file overrides
files["TAC/config/triune_data.lua"] = {
    -- Generated file; suppress all warnings
    ignore = { "" },
}

files["TAC/kissedit/*"] = {
    -- Legacy code with different conventions
    -- NOTE: this folder does not currently exist in the repo; left in place
    -- pending review (see .agents/AGENTS.md File Map note).
    ignore = { "" },
}
files["TAC/kissedit/**/*"] = {
    ignore = { "" },
}

files["TAC/tac.lua"] = {
    -- classPlausible is tested by test_pure_logic.lua test suite
    ignore = { "211/classPlausible" },
}

files["TAC/tests/**/*"] = {
    -- Dev-only test harness (never shipped). Test scaffolding routinely
    -- keeps unused helper functions, reserved lookup constants, and
    -- throwaway assignments in table-returning calls; none of that is a
    -- real defect here.
    ignore = {
        "211",   -- unused local variable / function (test helpers, reserved constants)
        "213",   -- unused loop variable (e.g. `for k, _unused in pairs(...)`)
        "311",   -- value assigned to a local variable is unused / overwritten before use
        "231",   -- local variable is set but never accessed
    },
}

-- Common suppressions for the MQ pcall-guard pattern, ImGui callbacks, and formatting
ignore = {
    "611",           -- line contains only whitespace
    "612",           -- line contains trailing whitespace
    "613",           -- trailing whitespace inside string
    "621",           -- inconsistent indentation
    "212",           -- unused argument (event handlers, ImGui callbacks)
    "212/_%w*",      -- unused loop variable starting with _
    "431",           -- shadowing upvalue (very common with pcall patterns)
    "432",           -- shadowing upvalue argument
}
