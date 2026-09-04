# TriuneAutocombat — Project Rules for Antigravity

## Project Overview

**TriuneAutocombat** is a MacroQuest ImGui Lua autocombat engine for EverQuest
progression servers. It automates targeting, spell casting, pet management, and
navigation for a "trio" of three EverQuest classes played on one character. It is
written entirely in Lua 5.1 / LuaJIT and runs inside MacroQuest2. The repo
root holds a single `TAC/` folder (see File Map below), and `TAC/` IS the
folder you deploy: drop it directly into `<MacroQuest Root>/lua/` (giving you
`<MacroQuest Root>/lua/TAC/`), at which point it's run via `/lua run TAC`.

## Standalone File Rule

**Historical context**: this project previously shipped a family of standalone
satellite tool windows (map, spellbook, DPS parser, cursor manager, buffbot,
zone tracker, hot-button bar, updater) that each had to run independently via
their own `/lua run <file>` command, so each carried its own duplicated copy
of the ImGui theme helpers (`pushCol`/`pushVar`/`pushTheme`/`popTheme`) and
color constants. Those satellite tools have since been removed (fork decision:
this repo is no longer PR'd upstream and is trimmed down to the core engine).
`tac.lua` is now the only file with UI/theme code, so the
duplication-avoidance rule no longer has anything to apply to. If a second
UI-bearing Lua file is ever added back to this repo, decide then whether to
keep it standalone (duplicate the theme) or share a module — don't assume the
old "must stay standalone" rule automatically still applies.

## File Map

| File | Role |
|---|---|
| `TAC/init.lua` | Entry point. `require('tac')`s the engine so the addon can be run as a folder (`/lua run TAC`). |
| `TAC/tac.lua` | Main engine: UI with theme, loadout, combat loop, persistence. |
| `TAC/config/triune_data.lua` | Era-correct spell/disc/AA database (generated, not hand-edited). |
| `TAC/tests/test_pure_logic.lua` | Pure-logic unit tests (no MQ dependency); dev-only, run via `luajit TAC/tests/test_pure_logic.lua` from the repo root. |
| `TAC/util/.luacheckrc` | Luacheck config; dev-only. Run via `luacheck TAC --config TAC/util/.luacheckrc` from the repo root. |
| `TAC/util/.luarc.json` | Lua-language-server config; dev-only, for editor tooling. |
| `TAC/CHANGELOG.md` | Full history of changes, newest date first. |
| `TAC/README.md` | User-facing documentation including commands, features, file structure. |

> **Note:** the repo root holds only `TAC/`, and `TAC/` mixes runtime files with dev-only ones — only `TAC/init.lua`, `TAC/tac.lua`, and `TAC/config/` actually run in-game; `TAC/tests/` and `TAC/util/` never ship. `.github/workflows/release.yml` archives `TAC/` for the release zip while excluding `TAC/tests` and `TAC/util`, so a release download and a source checkout both give you `<MacroQuest Root>/lua/TAC/` by copying (or extracting) the `TAC/` folder as-is.
>
> **Note:** `triune_loadout.lua` is written to the MQ config directory at runtime — it is NOT in this repo.
>
> **Note:** a `kissedit/` folder is referenced by `.luacheckrc` overrides (as `TAC/kissedit/`) but does not currently exist in this repo — that appears to be stale/aspirational config predating this file map and is left as-is pending review.



---

## MANDATORY: CHANGELOG.md Update Rule

**After every meaningful code change, you MUST update `CHANGELOG.md`.**

"Meaningful" includes: bug fixes, new features, refactors, new helpers, UI changes,
performance improvements, new slash commands, new config fields, or any behavioral change.

### CHANGELOG Format

```markdown
## YYYY-MM-DD

- Short present-tense description of change.
  - Sub-bullet for implementation detail if needed.
- Another change on the same date.

> **TLDR:** One-sentence summary of the day's changes (optional, for large batches).

---
```

Rules:
- Dates are always `YYYY-MM-DD` format (current local date).
- Newest date goes at the **top** of the file, below the `# Triune AutoCombat Change Log` heading.
- Each bullet describes **what changed and why**, not just what the code does.
- Sub-bullets explain implementation choices when the top-level bullet alone is unclear.
- The `---` horizontal rule separates date sections.
- If the current date section already exists, **append new bullets to it** rather than creating a duplicate date section.

---

## MANDATORY: README.md Update Rule

**Update `README.md` whenever any of the following change:**

- A new combat mode is added (update the mode table in Features)
- A new slash command is added (update the Commands table)
- The file structure changes (update the File Structure block)
- A new major feature section is added (add a new `###` subsection)
- The version number changes (update the "Current version:" line at the bottom)

### Version Number Locations

The canonical version is defined in `TAC/tac.lua`:
```lua
local VERSION           = '1.6.12'
```

The README (`TAC/README.md`) must always reflect this value:
```markdown
Current version: **1.6.12**
```

When you bump the version, update `TAC/tac.lua` and `TAC/README.md`.
CI (`.github/workflows/ci.yml`) fails if these two drift apart.

### Binary Files Policy (Do NOT use Git LFS)

If any binary files are ever committed to this repo, they must stay as regular
git objects, not Git LFS: GitHub source archives and `git archive` emit LFS
*pointer files* instead of real content, which would corrupt any distribution
path built on them (release zips, repo ZIP downloads). As of the fork
standalone-copy cleanup, the repo carries no binaries (the bundled navmeshes
and `ItemDB.txt` were removed along with the rest of `TAC/resources/`).

---

## Lua Compatibility Rules

This project runs on **Lua 5.1 / LuaJIT** inside MacroQuest. Do NOT use:

- `//` (integer division — not valid in Lua 5.1; use `math.floor(a/b)`)
- `|`, `&`, `~` bitwise operators — use the `bit` library: `bit.bor()`, `bit.band()`, etc.
- `<< >>` shift operators — use `bit.lshift()`, `bit.rshift()`
- `goto` (not in LuaJIT by default)
- String methods not in 5.1 (`string.pack`, `utf8`, etc.)

Prefer:
- `pcall()` guards around all TLO (Top Level Object) accesses — they can return nil unexpectedly
- `local` for every variable; never rely on implicit globals
- Explicit `nil` checks before indexing any MQ TLO result

---

## MacroQuest API Conventions

### TLO Access Pattern
```lua
-- GOOD: pcall guard prevents crashes on nil/missing spawns
local ok, val = pcall(function() return mq.TLO.Me.Gem(slot).Name() end)
if ok and val then ... end

-- BAD: direct access crashes if TLO returns nil unexpectedly
local val = mq.TLO.Me.Gem(slot).Name()
```

### ImGui Thread Safety & Window Rules
- **Never call `mq.delay()` from an ImGui render callback** — it is a non-yieldable thread and will crash with "Cannot delay from non-yieldable thread".
- Queue actions via a `pending*` flag (e.g., `reDetectRequested`, `pendingAction`) and execute them in the main coroutine loop.
- Pattern used in `TAC/tac.lua` (e.g. `reDetectRequested`).
- **Unique Element & Table IDs across Windows**: Every ImGui table, child window, tab bar, or button rendered in the same frame MUST have unique string IDs (e.g. `InspectTable` vs `MainTable`). Duplicate IDs across separate windows cause ImGui ID collisions, freezing inputs and routing clicks to the wrong window.
- **No Nested `ImGui.Begin()` Window Callbacks**: Never call `ImGui.Begin()` for a secondary window inside the render callback of a primary window (between its `ImGui.Begin()` and `ImGui.End()`). Nested `ImGui.Begin()` calls corrupt ImGui's focus stack, causing buttons, tab bars, and titlebar `X` close buttons on the secondary window to freeze. Always register secondary top-level windows as independent callbacks via `mq.imgui.init('SecondaryWin', drawSecondaryFunc)`.
- **Secondary Window Focus & Inspectors**: Secondary top-level windows in MQ Lua do not automatically steal mouse focus from the main window, causing clicks on secondary window controls to freeze or fall through. To present detailed inspection UI, use **In-Tab Detail Views** (with a `< Back to List` button) or **ImGui Modal Popups** (`ImGui.BeginPopupModal` / `ImGui.OpenPopup`), which force 100% input focus and guarantee responsive clicks.
- **Window Close Tuple Handling & Safe Exit**: `ImGui.Begin(title, openFlag)` returns `open, draw`. When `open` returns false (titlebar `X` button clicked), update the open flag state, call `ImGui.End()`, and return cleanly. `ImGui.End()` MUST be called once for every `ImGui.Begin()` call. **NEVER call `mq.exit()` or `mq.imgui.destroy()` inside an ImGui draw callback or event handler** — destroying the Lua context mid-render triggers a Fatal C++ Access Violation Crash in MacroQuest/EverQuest. Set `isRunning = false`, return cleanly, and let the main script coroutine loop exit naturally outside the callback.
- **Window Corner Rounding & `ImGuiWindowFlags.NoCollapse`**: Do NOT pass `ImGuiWindowFlags.NoCollapse` to `ImGui.Begin()`. In MacroQuest ImGui, passing `NoCollapse` overrides the theme's `WindowRounding` style token and forces ImGui to render a square window frame with sharp 90-degree titlebar corners. Omit `NoCollapse` (or use `ImGuiWindowFlags.AlwaysUseWindowPadding`) so `ImGuiStyleVar.WindowRounding` (e.g. 6.0) applies rounded corners to top-level windows.
- **Sequential Toolbar Layout (No Hardcoded Offsets)**: Avoid hardcoded x-position offsets like `ImGui.SameLine(390)` for toolbars. Hardcoded offsets collide and overlap when window width or button labels change. Use sequential `ImGui.SameLine()` without arguments for toolbars.
- **ImGui Tooltip Format String Safety (`ImGui.SetTooltip`)**: `ImGui.SetTooltip(fmt, ...)` treats its first argument as a `printf`/`string.format` specifier. Any literal `%` symbol (such as `100%`, `%d%%`, or `HP %`) in single-argument tooltips triggers a fatal Lua runtime error (`invalid option '%. ' to 'format'`). ALWAYS pass tooltip strings using an explicit format specifier: `ImGui.SetTooltip('%s', text)` or escape all percent characters as `%%`.

### Command Execution
```lua
mq.cmd('/command arg')       -- fire and forget
mq.cmdf('/command %s', arg)  -- formatted string version
```

### Event Handling
- Register chat events with `mq.event('name', 'pattern', handler)`
- Must call `mq.doevents()` in the main loop to process queued events

---

## State Table Conventions

All runtime state is stored in **four structured tables** (not bare locals):

| Table | Purpose |
|---|---|
| `ctrl` | User-configurable control surface (mode, settings, thresholds). Persisted. |
| `runtime` | Transient combat/loop state (timestamps, pending flags, last-cast tracking). |
| `petState` | Pet management state (pet list, last command, manual hunter hold). |
| `pursuit` | Navigation/targeting state (target id, nav stalls, wander loc, unreachable set). |
| `stuckState` | Anti-stuck system state (position history, counters, recovery timestamps). |

When adding new state, always add it to the appropriate table — never add a bare top-level local (Lua 5.1 main chunk has a 200-local limit that was already hit once in this project).

---

## Code Style

- Section headers use `-- ====` / `-- ----` banner comments as present throughout the files.
- Color constants use descriptive names: `GOOD`, `WARN`, `ERR`, `ARC`, `GOLD`, `MUTED`.
- The unified dark theme helpers (`pushTheme` / `popTheme`) live in `TAC/tac.lua`, the
  only UI-bearing file in this repo now (see Standalone File Rule's historical context).
- Class abbreviations always use the mixed-case data-file format: `War`, `Clr`, `Pal`, `Rng`, `SK`, `Dru`, `Mnk`, `Brd`, `Rog`, `Shm`, `Nec`, `Wiz`, `Mag`, `Enc`, `Bst`, `Ber`.


## Macroquest Lua Definitions
Located here /home/gennro/Documents/github/mq-definitions/