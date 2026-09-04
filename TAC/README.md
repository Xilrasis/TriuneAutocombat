# Triune AutoCombat

> A friendly, easy-to-use combat bot and multiclass automation tool built specifically for the **[Project Triune](https://nms.bestemu.com/)** EverQuest server (via [MacroQuest](https://macroquest.org/)).

---

## What is Triune AutoCombat?

On **[Project Triune](https://nms.bestemu.com/)**, every character is a multiclass combination of three EverQuest classes (a "trio" or "gestalt"). Juggling three full spellbooks, disciplines, and dozens of activated AAs on a single character can get overwhelming fast — that's where **Triune AutoCombat** comes in!

Triune gives you a clean visual in-game window to manage your 3-class combo and automate your combat loop without needing clunky macros or endless hotbars.

It handles all the busywork for you:
- **Multiclass Combat & Spellcasting**: Fires nukes, heals, buffs, DoTs, debuffs, disciplines, and AAs from all 3 of your classes based on simple rules you set.
- **Smart Pulling & Patrols**: Pulls mobs to your camp, roams zones to hunt, or walks custom waypoint routes.
- **Pet Control**: Commands pets from any of your pet classes (Mage, Necro, Beastlord, Shaman, Shadowknight, Enchanter) to attack, pull, or tank while you hang back.
- **Group Assists & Boxing**: Lets your box characters follow the tank, assist on targets, and cast safely from the backline.
- **Auto-Resting**: Sits to med and regenerate mana/endurance when it's safe, and stands up instantly if attacked.

Just type `/tac run` (or click **Start** in the UI) and let your character go to work!

---

## Quick Start Guide

> 📥 **Download the latest version here**: [**GitHub Releases (Latest)**](https://github.com/Xilrasis/TriuneAutocombat/releases/latest)

Getting started takes less than two minutes:

1. **Download & Extract**: Grab the latest release from the link above and extract it into a folder under your user directory (for example, `Documents\MacroQuest`).
2. **Start MacroQuest** and log into Everquest.
3. **Open Triune**: Triune starts automatically on login. If the window is closed, type `/tac` or `/lua run TAC`.
4. **Verify Your Classes**: In the **Character Classes & Loadout** section, verify your 3 classes (or click **Re-Detect** to let Triune detect them automatically).
5. **Set Up Your Spells**: Go to the **Spell Gems** tab and choose what each gem slot should do (e.g. *Heal when HP < 50%*, *Snare on incoming mobs*, *Nuke in combat*).
6. **Pick a Mode & Go**: On the **Control** tab, pick your mode (**Manual**, **Puller**, or **Assist**) and click **Start**!

---

## Combat Modes

Triune keeps things simple with **3 main combat modes**:

| Mode | Best For | How It Works |
|---|---|---|
| **Manual** | When you want to drive | You control movement and pick where to go. Triune handles attacking, casting your 3-class loadout spells, using AAs/discs, and healing allies. When the fight is over, it will walk back to your camp if you have one set. |
| **Puller** | The group leader / puller | Automates finding and engaging mobs. Comes in two flavors:<br>• **`Camp`**: Runs out, tags a mob (with a spell, bow, melee hit, or pet), brings it back to camp, and tanks it there.<br>• **`Hunt`**: Roams around the zone, finds mobs, and kills them right where they stand. |
| **Assist** | Box characters & helpers | Follows and assists your Main Assist (MA). Comes in three flavors:<br>• **`Chase`**: Runs right behind the MA and attacks whatever the MA targets.<br>• **`Camp`**: Holds position at camp and only hits mobs that get brought into camp.<br>• **`Backline`**: For healers and casters — stays safely at range and never charges into melee. |

---

## Key Features

### 🎯 Smart Pulling & Target Filters
- **Choose Your Pull Method**: Tag mobs using **Melee**, a **Spell** of your choice, a **Pet**, or **Ranged** (bow/throwing).
- **Stand Back Mode**: Great for pet classes and rangers! Lets your pet tank or keeps you at range without running into melee.
- **Pull Lists**:
  - **Include List (Whitelist)**: Only pull specific mobs you name.
  - **Ignore List (Blacklist)**: Skip unwanted mobs, dangerous roamers, or rares you aren't ready for.
- **Faction Filters**: Choose which mob factions to fight (`Scowling`, `Threatening`, `Indifferent`, etc.) with quick one-click presets like **Hostile Only**. Never accidentally pull a friendly guard or quest NPC again!

---

### 🚩 Waypoint Patrol Routes
- **Walk Custom Routes**: Create a list of waypoints and let your puller smoothly walk the path back and forth (1 ➔ 2 ➔ 3 ➔ 2 ➔ 1) while scanning for mobs.
- **Optional Looping**: Enable **Loop** to walk the route as a one-way circuit (1 ➔ 2 ➔ 3 ➔ 1) instead of bouncing back and forth.
- **Map Path Lines**: Your waypoint route and arrival circles are drawn directly on your in-game EverQuest map so you can see exactly where your character will walk.
- **Pause & Resume**: Whenever a mob is spotted, patrol pauses to fight. Once the mob dies, patrol picks right back up where it left off.
- **Easy Setup**: Click **Add Current Location** to drop waypoints as you walk, or use chat commands like `/tac wp add`.
- **Per-Zone Saving & Named Presets**: Your route and settings auto-save per zone and reload the next time you enter it. Save named presets (e.g. `<name> - <zone>`) from a dropdown to keep multiple routes per zone and switch between them with Load/Edit/Delete.
- **Export & Share Routes**: Export a named preset as a copy/paste string to share with guildmates; Import pastes one back in, filed under whichever zone it was made for.

---

### 🔮 Simple & Powerful Loadouts & Autoskill
- **12 Spell Gem Slots + Innate Abilities + AAs + Disciplines**: Set up spells, combat actions, activated AA abilities, and combat disciplines from all 3 of your classes in dedicated tabs.
- **Dedicated Abilities Tab & Autoskill**: Full automation for innate class combat actions (Kick, Bash, Slam, Mend, Backstab, Monk special strikes, Taunt, Disarm, Frenzy, Intimidation, Feign Death, etc.) with a continuous **Autoskill** toggle that automatically fires melee attacks on cooldown during combat without blocking spells.
- **Dedicated AAs Tab**: Manage Activated Alternate Advancements grouped by cooldown tiers (Short, Mid, Burn) with live purchased-rank filtering.
- **Combat Disciplines Tab**: Configure `/disc` disciplines with priority ordering, Boss Only Named mob gates, and Burn mode support.
- **Easy Trigger Rules**: Tell each ability, spell, or disc exactly when to fire (e.g. *Target HP < 90%*, *My HP < 40%*, *Missing Buff*, *Always*, *In Combat*).
- **No Wasted Mana**: Triune automatically checks if a DoT, snare, slow, or debuff is already on the mob before casting, so you never double-cast or waste mana.
- **Burn Mode**: Tag big cooldowns and nukes as **Burn Only**, then toggle Burn on when fighting named mobs or big pulls (`/tac burn`).
- **Min XTarget Gate**: Set heavy abilities or area-of-effect nukes to only fire when you have multiple enemies on you (e.g. *Only cast if 3+ mobs on XTarget*).
- **Auto-Memorize**: Triune remembers your setup in `triune_loadout.lua` and will automatically memorize missing spells when you're out of combat.

---

### 🎒 Automated Clickie Item Management
- **Dynamic Setup from Cursor**: Pick up any inventory, bag, or equipped item with a clickable spell effect onto your cursor and click **`+ Add Item on Cursor`** in the **Clickies** tab.
- **Context-Aware Trigger Rules**: Configure target condition (`F: Myself`, `F: Tank`, `E: Current Target`), trigger condition (`Missing Buff`, `HP <=`, `In Combat`, `Always`), health/mana threshold slider, and Min XTarget requirements.
- **Priority Reordering & Deletion**: Use `▲` and `▼` buttons to reorder clickie priority and `✕` to remove items from your loadout.
- **Smart Cooldown & Buff Detection**: Automatically checks item readiness (`ItemReady` / timer ready) and avoids re-clicking active duration buffs.

---

### 🧭 Intelligent Navigation & Hazard Avoidance
- **Stuck Memory & Autonomous Detours**: Remembers locations where characters get stuck in each zone, clusters them into hazard hotspots, and dynamically routes around them using perpendicular detour waypoints.
- **Reverse Breadcrumbs (Puller Mode)**: When pulling mobs in `Puller (Camp)` mode, Triune records the exact path walked to reach the mob and traverses it in reverse to guarantee a safe return to camp along cleared ground.
- **Closer-NPC Retargeting & Directional Arc Filtering**: Dynamically switches to closer mobs encountered during movement with configurable retarget limits (0–5), forward arc cone constraints ($\pm 75^\circ$) to prevent 180° turnarounds, scan throttling, and Line-of-Sight prioritization.
- **Path Ratio Sanity Gates**: Evaluates `NavMesh PathLength / 3D Distance` before engaging targets to prevent taking massive loops through distant corridors to reach mobs behind thin walls or on high balconies.
- **Proactive Door & Gate Automation**: Scans the path ahead while moving and opens doors predictively before colliding with them.
- **Levitation Duck-to-Clear**: Automatically ducks momentarily under low door headers and archways while floating with levitation to eliminate ceiling snags.
- **Hazard Management UI**: Inspect logged hazard counts and clear zone hotspots with a single click from the Settings tab.

---

### 🐾 Smart Pet Control
- **No Early Aggro**: Pets stay on hold until you actually start hitting the mob, keeping them from pulling accidental adds.
- **Pet Assist %**: Tell your pet to wait until the mob's HP drops to a certain percentage before engaging.
- **Pet Pulling**: Command your pet to tag distant mobs and bring them back to you.

---

### 📱 Compact Mini HUD
Want to clear up screen clutter while playing?
- Switch to the **Mini HUD** (`/tac compact` or click the **Compact** button).
- Gives you a tiny, clean floating window with Start/Pause, mode selection, Burn toggle, the **MA Name** field in Assist mode, and fast one-click buttons for extra tools.
- Shows your live **AA/hr** and **Plat/hr** session rates right on your screen.

> In the full window, the header, Start/Pause/Burn controls, and the tab bar stay pinned to the top — scrolling a long tab (like Settings) no longer pushes them off screen.

---

### ⏱️ Cooldown & Ability Monitor
Keep track of every enabled combat ability, activated AA, discipline, spell gem, and clickie item in real time:
- **Dedicated Tab & Popout Window**: Access directly via the **Cooldowns** tab in the main window (positioned right after AAs) or float as a standalone window using the `Popout Window` button, `/tac cd`, `/tac cooldowns`, the top toolbar, or the Mini HUD.
- **Active Duration Tracking**: Glowing cyan progress bars show remaining active buff/stance duration (e.g. *Defensive Discipline*, *Harmshield*, *Furious*) before transitioning to cooldown.
- **Smart Readiness Diagnostics**: Instant feedback on why abilities are gated: `[READY]`, `[LOW END]`, `[LOW MANA]`, `[NEED BURN]`, `[NEED BOSS]`, `[MIN XTAR]`, or `[LOCKED]`.
- **EverQuest Timer Groups**: Badges display EQ shared timer banks (`[T1]`, `[T2]`, `[T4]`) to clarify shared cooldown lockouts.
- **1-Click Execution**: Interactive **`[ Use ]`** buttons allow manual firing of any ready ability directly from the monitor.
- **Dual View Modes & HUD Overlay**: Switch between a detailed Table View and a sleek horizontal HUD Cards View with background transparency opacity slider and window position lock.
- **In-Place Loadout Tuning**: Optional inline editing controls enabling live adjustment of `Enabled`, threshold `HP %`, and `Burn Only` toggles directly from the monitor.

---

## Built-in Bonus Tools

Triune comes packed with handy standalone tools you can open right from the main window or via chat commands:

| Tool | Chat Command | What It Does |
|---|---|---|
| ⏱️ **Cooldown Monitor** | `/tac cd` | Standalone popout live ability, AA, and discipline cooldown monitor with active buff duration countdowns, smart diagnostics, timer groups, next-up forecast, and 1-click execution. |

---

## Slash Commands

You can control almost everything using simple in-game chat commands:

| Command | Aliases | What It Does |
|---|---|---|
| `/tac` | | Start or pause autocombat |
| `/tac run` | `/tac start` | Start autocombat |
| `/tac pause` | `/tac stop` | Pause autocombat and stop moving |
| `/tac burn [on\|off]` | `/tac burnon`, `/tac burnoff` | Toggle Burn mode on/off |
| `/tac debug` | `/tac diag`, `/tac debugmode` | Toggle live combat debug telemetry in chat |
| `/tac compact` | `/tac mini`, `/tac hud` | Toggle the compact Mini HUD |
| `/tac cd` | `/tac cooldowns`, `/tac cds` | Toggle the popout Cooldown & Ability Monitor window |
| `/tac status` | | Print current status and mode to chat |
| `/tac help` | `/tac ?` | Show command help in chat |
| `/tac <mode> [submode]` | | Switch mode (e.g. `/tac manual`, `/tac puller camp`, `/tac assist chase`, `/tac backline`) |
| `/tac pullhp [0-95]` | `/tac minhp` | Set minimum HP % threshold before pausing pulling to rest until 100% |
| `/tac pullcon [preset]` | `/tac con` | Set faction filters (e.g. `/tac pullcon preset hostile`) |
| `/tac wp [add\|clear\|del\|on\|off\|list]` | `/tac waypoint` | Manage waypoint patrol routes |
| `/tac clearcursor` | `/tac autoinv` | Dump cursor items to inventory |
| `/tac clear lockouts` | `/tac clearlockouts`, `/tac unlock` | Clear active spell lockouts, non-stacking buff backoffs, and mob immunities |
| `/tac preset [save\|load\|del\|list]` | `/tac loadout` | Save, load, list, or delete named spell gem loadout presets |
| `/tac style [melee\|ranged\|spell]` | | Set combat style |
| `/tac range [dist]` | `/tac meleerange` | Set melee (5-50) or ranged (5-200) distance |
| `/triunerun` | | Fast keybind command to toggle start/pause |

---

## File Structure

```
TriuneAutocombat/              # Repo root
└── TAC/                       # ← this IS the folder you deploy
    ├── init.lua                   # Entry point (delegates to tac.lua)
    ├── tac.lua                    # Main autocombat engine, UI, and Mini HUD
    ├── config/
    │   └── triune_data.lua        # Spell and ability database
    ├── tests/                     # Pure-logic unit tests (dev-only)
    │   └── test_pure_logic.lua
    ├── util/                      # Dev tooling config (dev-only)
    │   ├── .luacheckrc
    │   └── .luarc.json
    ├── README.md                  # This guide!
    └── CHANGELOG.md               # Detailed update and change history
```

> **Note:** The repo root just holds a single `TAC/` folder, and `TAC/` is exactly what gets deployed — drop it straight into your MacroQuest install's `lua/` folder (giving you `<MacroQuest Root>/lua/TAC/`), whether you got it from a release zip or a source checkout. Only `TAC/tests/` and `TAC/util/` are dev-only and never shipped in the release zip (see Quick Start above); everything else inside `TAC/` — including this README and the changelog — travels with it. Once deployed, `/lua run TAC` starts it (or `/lua run TAC/tac` to run the engine directly, bypassing `init.lua`).

> **Note:** Your personal character settings and loadouts are automatically saved to `triune_loadout.lua` in your MacroQuest config directory, so updates will never overwrite your setups.

---

## Helpful Links

- **GitHub Releases (Latest Downloads)**: [https://github.com/Xilrasis/TriuneAutocombat/releases/latest](https://github.com/Xilrasis/TriuneAutocombat/releases/latest)
- **Project Triune Website & Database (PTDex)**: [https://nms.bestemu.com/](https://nms.bestemu.com/)
- **MacroQuest**: [https://macroquest.org/](https://macroquest.org/)

---

## Version

Current version: **1.7.16**

See [CHANGELOG.md](CHANGELOG.md) for full release notes and update history.
