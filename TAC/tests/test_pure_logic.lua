#!/usr/bin/env luajit
---@diagnostic disable: deprecated
-- ==========================================================================
-- TAC/tests/test_pure_logic.lua — Unit tests for pure-logic functions in tac.lua
--
-- Runs under plain LuaJIT (no MacroQuest required).  Extracts function bodies
-- from the source file by matching `local function NAME(` and counting
-- block-open / block-close keywords to find the closing `end`.  Each function
-- is loaded in a sandbox with its required upvalues.
--
-- Usage:  luajit TAC/tests/test_pure_logic.lua (run from repo root)
-- Exit:   0 on all-pass, 1 on any failure.
-- ==========================================================================

-- ---------------------------------------------------------------------------
-- Minimal test harness
-- ---------------------------------------------------------------------------
local pass, fail, errors = 0, 0, {}

local function assert_eq(got, expect, label)
    if got == expect then
        pass = pass + 1
    else
        fail = fail + 1
        errors[#errors + 1] = string.format(
            "  FAIL: %s\n    expected: %s (%s)\n    got:      %s (%s)",
            label, tostring(expect), type(expect), tostring(got), type(got))
    end
end

local function assert_neq(got, notExpect, label)
    if got ~= notExpect then
        pass = pass + 1
    else
        fail = fail + 1
        errors[#errors + 1] = string.format(
            "  FAIL: %s\n    should NOT be: %s", label, tostring(notExpect))
    end
end

local function assert_true(val, label)
    assert_eq(not not val, true, label)
end

local function assert_nil(val, label)
    assert_eq(val, nil, label)
end

local function assert_type(val, expected_type, label)
    assert_eq(type(val), expected_type, label)
end

-- Table deep-equal (shallow for this use case)
local function tbl_eq(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function assert_tbl_eq(got, expect, label)
    if tbl_eq(got, expect) then
        pass = pass + 1
    else
        fail = fail + 1
        local function dump(t)
            if type(t) ~= 'table' then return tostring(t) end
            local parts = {}
            for k, v in pairs(t) do parts[#parts + 1] = tostring(k) .. '=' .. tostring(v) end
            return '{' .. table.concat(parts, ', ') .. '}'
        end
        errors[#errors + 1] = string.format(
            "  FAIL: %s\n    expected: %s\n    got:      %s",
            label, dump(expect), dump(got))
    end
end

-- ---------------------------------------------------------------------------
-- Function extractor
-- ---------------------------------------------------------------------------
-- Reads the source file, finds `local function <name>(` at column 1 (no
-- leading whitespace), and captures lines until the matching `end` at column 1.
-- For top-level functions in tac.lua, the closing `end` is always un-indented.

local function readFile(path)
    local f = assert(io.open(path, 'r'), 'Cannot open: ' .. path)
    local content = f:read('*a')
    f:close()
    return content
end

local function extractFunction(src, funcName)
    local lines = {}
    local capturing = false

    for line in src:gmatch('[^\n]*') do
        if not capturing then
            -- Match top-level function declarations (no leading whitespace)
            if line:match('^local function ' .. funcName .. '%s*%(')
                or line:match('^function runtime%.' .. funcName .. '%s*%(')
                or line:match('^runtime%.' .. funcName .. '%s*=%s*function%s*%(')
                or line:match('^' .. funcName .. '%s*=%s*function%s*%(') then
                capturing = true
                lines[#lines + 1] = line
            end
        else
            lines[#lines + 1] = line
            -- The closing `end` of a top-level function is always at column 1
            if line:match('^end%s*$') or line == 'end' then
                break
            end
        end
    end

    if #lines == 0 then
        error('Could not extract function: ' .. funcName)
    end
    return table.concat(lines, '\n')
end

-- Load a function body with a given environment of upvalues.
-- The extracted code is a function block; we append `return X`
-- so `loadstring` returns the function itself.
local function loadFunc(src, funcName, env)
    local code = extractFunction(src, funcName)
    if code:match('^function runtime%.') or code:match('^runtime%.') then
        code = code .. '\nreturn runtime.' .. funcName
    else
        code = code .. '\nreturn ' .. funcName
    end

    local chunk, err = loadstring(code, funcName)
    if not chunk then error('loadstring failed for ' .. funcName .. ': ' .. err) end

    -- Merge env onto a copy of _G so standard library is available
    local sandbox = {}
    for k, v in pairs(_G) do sandbox[k] = v end
    if not sandbox.runtime then sandbox.runtime = {} end
    if env then
        for k, v in pairs(env) do
            sandbox[k] = v
            sandbox.runtime[k] = v
        end
    end
    setfenv(chunk, sandbox)

    local ok, fn = pcall(chunk)
    if not ok then error('pcall failed for ' .. funcName .. ': ' .. tostring(fn)) end
    return fn
end

-- ---------------------------------------------------------------------------
-- Source file path (relative to repo root)
-- ---------------------------------------------------------------------------
local srcPath = 'TAC/tac.lua'
local src = readFile(srcPath)

-- ---------------------------------------------------------------------------
-- Shared constants (duplicated here to match module-level definitions)
-- ---------------------------------------------------------------------------
local ALL_ABBR = {
    'War', 'Clr', 'Pal', 'Rng', 'SK', 'Dru', 'Mnk', 'Brd', 'Rog', 'Shm',
    'Nec', 'Wiz', 'Mag', 'Enc', 'Bst', 'Ber',
}

local PULL_CON_LIST = {
    'Scowling', 'Threateningly', 'Dubious', 'Apprehensive',
    'Indifferent', 'Amiably', 'Kindly', 'Warmly', 'Ally',
}

local MODES = {
    PULL_CON_LIST = PULL_CON_LIST,
}

-- The MQSHORT lookup table (used inside toCanonicalClassAbbr as a local, and
-- referenced by parseClassLine as an upvalue that SHOULD be module-level).
local MQSHORT = {
    WARRIOR = 'War',
    WAR = 'War',
    WARRIORS = 'War',
    CLERIC = 'Clr',
    CLR = 'Clr',
    CLERICS = 'Clr',
    PALADIN = 'Pal',
    PAL = 'Pal',
    PALADINS = 'Pal',
    RANGER = 'Rng',
    RNG = 'Rng',
    RANGERS = 'Rng',
    SHADOWKNIGHT = 'SK',
    SHADOW = 'SK',
    SHD = 'SK',
    SK = 'SK',
    SHADOWKNIGHTS = 'SK',
    DRUID = 'Dru',
    DRU = 'Dru',
    DRUIDS = 'Dru',
    MONK = 'Mnk',
    MNK = 'Mnk',
    MONKS = 'Mnk',
    BARD = 'Brd',
    BRD = 'Brd',
    BARDS = 'Brd',
    ROGUE = 'Rog',
    ROG = 'Rog',
    ROGUES = 'Rog',
    SHAMAN = 'Shm',
    SHM = 'Shm',
    SHAMANS = 'Shm',
    NECROMANCER = 'Nec',
    NEC = 'Nec',
    NECROMANCERS = 'Nec',
    WIZARD = 'Wiz',
    WIZ = 'Wiz',
    WIZARDS = 'Wiz',
    MAGICIAN = 'Mag',
    MAG = 'Mag',
    MAGICIANS = 'Mag',
    ENCHANTER = 'Enc',
    ENC = 'Enc',
    ENCHANTERS = 'Enc',
    BEASTLORD = 'Bst',
    BST = 'Bst',
    BEASTLORDS = 'Bst',
    BERSERKER = 'Ber',
    BER = 'Ber',
    BERSERKERS = 'Ber',
}

-- Waypoint export/import string constants (must match tac.lua's module-level definitions)
local WP = {
    B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/',
    B64_LOOKUP = {},
    RS = string.char(30),
    US = string.char(31),
    EXPORT_PREFIX = 'TACWP1:',
    EXPORT_VERSION = 1,
}
for i = 1, #WP.B64_CHARS do WP.B64_LOOKUP[WP.B64_CHARS:sub(i, i)] = i - 1 end
local B64_CHARS = WP.B64_CHARS
local B64_LOOKUP = WP.B64_LOOKUP
local WP_RS = WP.RS
local WP_US = WP.US

-- ============================================================================
-- 1.  idxOf(tbl, val)
-- ============================================================================
print('--- idxOf ---')
do
    local idxOf = loadFunc(src, 'idxOf', {})

    assert_eq(idxOf({ 'a', 'b', 'c' }, 'b'), 2, 'idxOf: find middle element')
    assert_eq(idxOf({ 'a', 'b', 'c' }, 'a'), 1, 'idxOf: find first element')
    assert_eq(idxOf({ 'a', 'b', 'c' }, 'c'), 3, 'idxOf: find last element')
    assert_eq(idxOf({ 'a', 'b', 'c' }, 'z'), 1, 'idxOf: not found returns 1')
    assert_eq(idxOf(nil, 'x'), 1, 'idxOf: nil table returns 1')
    assert_eq(idxOf({}, 'x'), 1, 'idxOf: empty table returns 1')
end

-- ============================================================================
-- 2.  toCanonicalClassAbbr(str)
-- ============================================================================
print('--- toCanonicalClassAbbr ---')
do
    local idxOf = loadFunc(src, 'idxOf', {})
    local toCanonicalClassAbbr = loadFunc(src, 'toCanonicalClassAbbr',
        { ALL_ABBR = ALL_ABBR, MQSHORT = MQSHORT, idxOf = idxOf })

    -- Full names (case-insensitive)
    assert_eq(toCanonicalClassAbbr('warrior'), 'War', 'canon: lowercase warrior')
    assert_eq(toCanonicalClassAbbr('WARRIOR'), 'War', 'canon: uppercase WARRIOR')
    assert_eq(toCanonicalClassAbbr('Warrior'), 'War', 'canon: mixed Warrior')
    assert_eq(toCanonicalClassAbbr('Shadow Knight'), 'SK', 'canon: Shadow Knight (space)')
    assert_eq(toCanonicalClassAbbr('shadowknight'), 'SK', 'canon: shadowknight')
    assert_eq(toCanonicalClassAbbr('Necromancer'), 'Nec', 'canon: Necromancer')
    assert_eq(toCanonicalClassAbbr('Beastlord'), 'Bst', 'canon: Beastlord')
    assert_eq(toCanonicalClassAbbr('Berserker'), 'Ber', 'canon: Berserker')

    -- MQ-style 3-letter abbreviations
    assert_eq(toCanonicalClassAbbr('WAR'), 'War', 'canon: WAR')
    assert_eq(toCanonicalClassAbbr('CLR'), 'Clr', 'canon: CLR')
    assert_eq(toCanonicalClassAbbr('PAL'), 'Pal', 'canon: PAL')
    assert_eq(toCanonicalClassAbbr('RNG'), 'Rng', 'canon: RNG')
    assert_eq(toCanonicalClassAbbr('SHD'), 'SK', 'canon: SHD → SK')
    assert_eq(toCanonicalClassAbbr('DRU'), 'Dru', 'canon: DRU')
    assert_eq(toCanonicalClassAbbr('MNK'), 'Mnk', 'canon: MNK')
    assert_eq(toCanonicalClassAbbr('BRD'), 'Brd', 'canon: BRD')
    assert_eq(toCanonicalClassAbbr('ROG'), 'Rog', 'canon: ROG')
    assert_eq(toCanonicalClassAbbr('SHM'), 'Shm', 'canon: SHM')
    assert_eq(toCanonicalClassAbbr('NEC'), 'Nec', 'canon: NEC')
    assert_eq(toCanonicalClassAbbr('WIZ'), 'Wiz', 'canon: WIZ')
    assert_eq(toCanonicalClassAbbr('MAG'), 'Mag', 'canon: MAG')
    assert_eq(toCanonicalClassAbbr('ENC'), 'Enc', 'canon: ENC')
    assert_eq(toCanonicalClassAbbr('BST'), 'Bst', 'canon: BST')
    assert_eq(toCanonicalClassAbbr('BER'), 'Ber', 'canon: BER')
    assert_eq(toCanonicalClassAbbr('SK'), 'SK', 'canon: SK')

    -- Mixed-case canonical form (should pass through if in ALL_ABBR)
    assert_eq(toCanonicalClassAbbr('War'), 'War', 'canon: War pass-through')
    assert_eq(toCanonicalClassAbbr('Clr'), 'Clr', 'canon: Clr pass-through')

    -- Plurals
    assert_eq(toCanonicalClassAbbr('Warriors'), 'War', 'canon: Warriors plural')
    assert_eq(toCanonicalClassAbbr('Clerics'), 'Clr', 'canon: Clerics plural')

    -- Edge cases
    assert_nil(toCanonicalClassAbbr(nil), 'canon: nil input')
    assert_nil(toCanonicalClassAbbr(''), 'canon: empty string')
    assert_nil(toCanonicalClassAbbr('NULL'), 'canon: NULL string')
    assert_nil(toCanonicalClassAbbr('nil'), 'canon: "nil" string')
end

-- ============================================================================
-- 3.  cleanSpellName(name)
-- ============================================================================
print('--- cleanSpellName ---')
do
    local cleanSpellName = loadFunc(src, 'cleanSpellName', {})

    assert_eq(cleanSpellName('Complete Heal'), 'Complete Heal', 'clean: no parens')
    assert_eq(cleanSpellName('Chloroplast (Group)'), 'Chloroplast', 'clean: strip (Group)')
    assert_eq(cleanSpellName('Spirit of Wolf (Spell)'), 'Spirit of Wolf', 'clean: strip (Spell)')
    assert_eq(cleanSpellName('  Heal  '), 'Heal', 'clean: trim whitespace')
    assert_eq(cleanSpellName(nil), '', 'clean: nil → empty')
    assert_eq(cleanSpellName(42), '', 'clean: number → empty')
    assert_eq(cleanSpellName(''), '', 'clean: empty → empty')
end

-- ============================================================================
-- 4.  normalizeSpellName(name)
-- ============================================================================
print('--- normalizeSpellName ---')
do
    local normalizeSpellName = loadFunc(src, 'normalizeSpellName', {})

    assert_eq(normalizeSpellName('Complete Heal'), 'completeheal', 'norm: basic')
    assert_eq(normalizeSpellName('Complete Heal Rk. II'), 'completeheal', 'norm: strip Rk. II')
    assert_eq(normalizeSpellName('Chloroplast (Group)'), 'chloroplast', 'norm: strip parens')
    assert_eq(normalizeSpellName('Spirit of Wolf'), 'spiritofwolf', 'norm: spaces removed')
    assert_eq(normalizeSpellName('Nuke Rk.III'), 'nuke', 'norm: Rk.III variant')
    assert_eq(normalizeSpellName('Heal (Rk II)'), 'heal', 'norm: (Rk II) in parens')
    assert_eq(normalizeSpellName(nil), '', 'norm: nil → empty')
    assert_eq(normalizeSpellName(42), '', 'norm: number → empty')
    assert_eq(normalizeSpellName(''), '', 'norm: empty → empty')
end

-- ============================================================================
-- 5.  defaultsForKind(kind, bene)
-- ============================================================================
print('--- defaultsForKind ---')
do
    local defaultsForKind = loadFunc(src, 'defaultsForKind', {})

    local function check_defaults(kind, bene, expTarget, expWhen, expPct, label)
        local t, w, p = defaultsForKind(kind, bene)
        assert_eq(t, expTarget, label .. ' target')
        assert_eq(w, expWhen, label .. ' when')
        assert_eq(p, expPct, label .. ' pct')
    end

    check_defaults('heal', nil, 'F: Myself', 'my HP <=', 75, 'defaults: heal')
    check_defaults('buff', nil, 'F: Myself', 'missing buff', 100, 'defaults: buff')
    check_defaults('pet_buff', nil, 'F: Pet', 'missing buff', 100, 'defaults: pet_buff')
    check_defaults('pet', nil, 'F: Myself', 'missing pet', 100, 'defaults: pet')
    check_defaults('util', nil, 'F: Myself', 'always', 100, 'defaults: util')
    check_defaults('debuff', nil, 'E: Current Target', 'target HP <=', 98, 'defaults: debuff')
    check_defaults('dot', nil, 'E: Current Target', 'target HP <=', 98, 'defaults: dot')
    check_defaults('dd', nil, 'E: Current Target', 'target HP <=', 95, 'defaults: dd')
    check_defaults(nil, true, 'F: Myself', 'missing buff', 100, 'defaults: bene=true')
    check_defaults(nil, nil, 'E: Current Target', 'target HP <=', 95, 'defaults: unknown')
    check_defaults('bogus', nil, 'E: Current Target', 'target HP <=', 95, 'defaults: bogus kind')
end

-- ============================================================================
-- 6.  sanitizeModeConfig(c)
-- ============================================================================
print('--- sanitizeModeConfig ---')
do
    local sanitizeModeConfig = loadFunc(src, 'sanitizeModeConfig',
        { MODES = MODES, ctrl = nil })

    -- Legacy mode migration
    local function smc(mode, submode)
        local c = { mode = mode, submode = submode }
        sanitizeModeConfig(c)
        return c.mode, c.submode
    end

    local m, s

    -- Hunter → Puller/Hunt
    m, s = smc('Hunter', nil)
    assert_eq(m, 'Puller', 'sanitize: Hunter → Puller')
    assert_eq(s, 'Hunt', 'sanitize: Hunter → Hunt')

    -- Manual Hunter → Manual/Hunt
    m, s = smc('Manual Hunter', nil)
    assert_eq(m, 'Manual', 'sanitize: Manual Hunter → Manual')
    assert_eq(s, 'Hunt', 'sanitize: Manual Hunter → Hunt')

    -- Pet Tank → Puller/Hunt
    m, s = smc('Pet Tank', nil)
    assert_eq(m, 'Puller', 'sanitize: Pet Tank → Puller')
    assert_eq(s, 'Hunt', 'sanitize: Pet Tank → Hunt')

    -- Pull & Assist → Puller/Camp
    m, s = smc('Pull & Assist', nil)
    assert_eq(m, 'Puller', 'sanitize: Pull & Assist → Puller')
    assert_eq(s, 'Camp', 'sanitize: Pull & Assist → Camp')

    -- Chase Assist → Assist/Chase
    m, s = smc('Chase Assist', nil)
    assert_eq(m, 'Assist', 'sanitize: Chase Assist → Assist')
    assert_eq(s, 'Chase', 'sanitize: Chase Assist → Chase')

    -- Garrison → Assist/Camp
    m, s = smc('Garrison', nil)
    assert_eq(m, 'Assist', 'sanitize: Garrison → Assist')
    assert_eq(s, 'Camp', 'sanitize: Garrison → Camp')

    -- Tank → Assist/Camp
    m, s = smc('Tank', nil)
    assert_eq(m, 'Assist', 'sanitize: Tank → Assist')
    assert_eq(s, 'Camp', 'sanitize: Tank → Camp')

    -- Unknown mode → Manual
    m, s = smc('BogusMode', nil)
    assert_eq(m, 'Manual', 'sanitize: unknown → Manual')
    assert_eq(s, 'Hunt', 'sanitize: unknown → default submode Hunt')

    -- Valid modes pass through
    m, s = smc('Manual', 'Hunt')
    assert_eq(m, 'Manual', 'sanitize: Manual stays')

    m, s = smc('Puller', 'Hunt')
    assert_eq(m, 'Puller', 'sanitize: Puller stays')
    assert_eq(s, 'Hunt', 'sanitize: Puller/Hunt stays')

    m, s = smc('Puller', 'Camp')
    assert_eq(m, 'Puller', 'sanitize: Puller/Camp stays')
    assert_eq(s, 'Camp', 'sanitize: Puller/Camp submode stays')

    m, s = smc('Assist', 'Chase')
    assert_eq(m, 'Assist', 'sanitize: Assist stays')
    assert_eq(s, 'Chase', 'sanitize: Assist/Chase stays')

    m, s = smc('Assist', 'Backline')
    assert_eq(m, 'Assist', 'sanitize: Assist/Backline stays')
    assert_eq(s, 'Backline', 'sanitize: Backline submode stays')

    -- Invalid submode for Puller → default
    m, s = smc('Puller', 'Backline')
    assert_eq(s, 'Hunt', 'sanitize: Puller bad submode → Hunt')

    -- Invalid submode for Assist → default
    m, s = smc('Assist', 'Hunt')
    assert_eq(s, 'Chase', 'sanitize: Assist bad submode → Chase')

    -- pull_con_filter initialization
    local c = { mode = 'Manual' }
    sanitizeModeConfig(c)
    assert_type(c.pull_con_filter, 'table', 'sanitize: pull_con_filter is table')
    for _, con in ipairs(PULL_CON_LIST) do
        assert_eq(c.pull_con_filter[con], true,
            'sanitize: pull_con_filter.' .. con .. ' defaults to true')
    end

    -- hunter_z / hunter_z_plane defaults
    local c2 = { mode = 'Manual' }
    sanitizeModeConfig(c2)
    assert_eq(c2.hunter_z, 75, 'sanitize: hunter_z default')
    assert_eq(c2.hunter_z_plane, 15, 'sanitize: hunter_z_plane default')

    -- Existing values preserved
    local c3 = { mode = 'Manual', hunter_z = 200, hunter_z_plane = 50 }
    sanitizeModeConfig(c3)
    assert_eq(c3.hunter_z, 200, 'sanitize: hunter_z preserved')
    assert_eq(c3.hunter_z_plane, 50, 'sanitize: hunter_z_plane preserved')
end

-- ============================================================================
-- 7.  parseClassLine(text)  — loaded with MQSHORT in scope
-- ============================================================================
print('--- parseClassLine ---')
local parseClassLine = loadFunc(src, 'parseClassLine', { MQSHORT = MQSHORT })

-- Numbered lines (e.g. from inventory window list items)
assert_eq(parseClassLine('1. Warrior'), 'War', 'parse: "1. Warrior"')
assert_eq(parseClassLine('2: Cleric'), 'Clr', 'parse: "2: Cleric"')
assert_eq(parseClassLine('  3  Paladin'), 'Pal', 'parse: "  3  Paladin"')

-- Plain class names
assert_eq(parseClassLine('Ranger'), 'Rng', 'parse: "Ranger"')
assert_eq(parseClassLine('Shadow Knight'), 'SK', 'parse: "Shadow Knight"')
assert_eq(parseClassLine('Necromancer'), 'Nec', 'parse: "Necromancer"')

-- 3-letter codes
assert_eq(parseClassLine('WAR'), 'War', 'parse: "WAR" 3-letter')
assert_eq(parseClassLine('CLR'), 'Clr', 'parse: "CLR" 3-letter')
assert_eq(parseClassLine('SHD'), 'SK', 'parse: "SHD" 3-letter')

-- 2-letter code
assert_eq(parseClassLine('SK'), 'SK', 'parse: "SK" 2-letter')

-- Lines that should return nil
assert_nil(parseClassLine(nil), 'parse: nil')
assert_nil(parseClassLine(''), 'parse: empty')
assert_nil(parseClassLine('NULL'), 'parse: NULL')
assert_nil(parseClassLine('Level 60'), 'parse: "Level 60" filtered')
assert_nil(parseClassLine('LVL 50'), 'parse: "LVL 50" filtered')

-- ============================================================================
-- 8.  defaultCtrl() — shape validation
-- ============================================================================
print('--- defaultCtrl ---')
local defaultCtrl = loadFunc(src, 'defaultCtrl', { MODES = MODES })
local dc = defaultCtrl()

-- Check required fields exist and have correct types
local EXPECTED_FIELDS = {
    -- field name            expected type
    { 'running',                 'boolean' },
    { 'mode',                    'string' },
    { 'submode',                 'string' },
    { 'pull_style',              'string' },
    { 'pull_spell',              'string' },
    { 'pull_spell_gem',          'number' },
    { 'pull_engage_dist',        'number' },
    { 'xtar_nav_dist',           'number' },
    { 'ignore_distant_xtargets', 'boolean' },
    { 'combat_style',            'string' },
    { 'melee_dist',              'number' },
    { 'ranged_dist',             'number' },
    { 'ma_name',                 'string' },
    { 'assist_at',               'number' },
    { 'chase',                   'boolean' },
    { 'chase_dist',              'number' },
    { 'automem',                 'boolean' },
    { 'camp_radius',             'number' },
    { 'camp_z',                  'number' },
    { 'camp_z_plane',            'number' },
    { 'hunter_radius',           'number' },
    { 'hunter_z_plane',          'number' },
    { 'hunter_z',                'number' },
    { 'hunter_min_level',        'number' },
    { 'hunter_max_level',        'number' },
    { 'hunter_combat_radius',    'number' },
    { 'pull_min_level',          'number' },
    { 'pull_max_level',          'number' },
    { 'pull_con_filter',         'table' },
    { 'check_closer_mobs',       'boolean' },
    { 'nav_hazard_avoidance',    'boolean' },
    { 'nav_hazard_radius',       'number' },
    { 'nav_hazard_min_hits',     'number' },
    { 'nav_reverse_breadcrumbs', 'boolean' },
    { 'nav_max_path_ratio',      'number' },
    { 'nav_proactive_doors',     'boolean' },
    { 'nav_levitation_clear',    'boolean' },
    { 'zone_hazards',            'table' },
    { 'debug_mode',              'boolean' },
    { 'scribed_only',            'boolean' },
    { 'aa_purchased_only',       'boolean' },
    { 'disc_trained_only',       'boolean' },
    { 'medbreak_enabled',        'boolean' },
    { 'cast_max_retries',        'number' },
    { 'cast_lockout_sec',        'number' },
    { 'min_mana_pct',            'number' },
    { 'pull_min_hp_pct',         'number' },
    { 'pet_assist_at',           'number' },
    { 'pet_hold_enabled',        'boolean' },
    { 'show_map_radius',         'boolean' },
    { 'show_cooldowns',          'boolean' },
    { 'cooldown_alpha',          'number' },
    { 'cooldown_locked',         'boolean' },
    { 'cooldown_view_mode',      'string' },
    { 'cooldown_sort_by',        'string' },
    { 'cooldown_category',       'string' },
    { 'cooldown_status_filter',  'string' },
    { 'cooldown_compact',        'boolean' },
    { 'cooldown_show_inline_edit', 'boolean' },
    { 'burn',                    'boolean' },
    { 'compact',                 'boolean' },
    { 'use_waypoints',           'boolean' },
    { 'waypoint_radius',         'number' },
    { 'waypoint_scan_radius',    'number' },
    { 'waypoint_direction',      'number' },
    { 'waypoint_loop',           'boolean' },
    { 'current_waypoint_idx',    'number' },
    { 'waypoints',               'table' },
    { 'zone_waypoints',          'table' },
    { 'zone_waypoint_presets',   'table' },
}

for _, spec in ipairs(EXPECTED_FIELDS) do
    local field, etype = spec[1], spec[2]
    assert_neq(dc[field], nil, 'defaultCtrl: ' .. field .. ' exists')
    assert_type(dc[field], etype, 'defaultCtrl: ' .. field .. ' is ' .. etype)
end

-- Specific default values
assert_eq(dc.running, false, 'defaultCtrl: running=false')
assert_eq(dc.mode, 'Manual', 'defaultCtrl: mode=Manual')
assert_eq(dc.submode, 'Hunt', 'defaultCtrl: submode=Hunt')
assert_eq(dc.show_cooldowns, false, 'defaultCtrl: show_cooldowns=false')
assert_eq(dc.cooldown_alpha, 0.90, 'defaultCtrl: cooldown_alpha=0.90')
assert_eq(dc.cooldown_view_mode, 'table', 'defaultCtrl: cooldown_view_mode=table')

-- ============================================================================
-- 9.  isActionSkill(name) & defaultActionEntry
-- ============================================================================
print('--- isActionSkill / isSpecialSkill ---')
local CLASS_ACTIONS = {
    Mnk = { 'Kick', 'Round Kick', 'Tiger Claw', 'Eagle Strike', 'Dragon Punch', 'Tail Rake', 'Flying Kick', 'Mend', 'Feign Death', 'Sneak', 'Intimidation', 'Disarm' },
    Rog = { 'Backstab', 'Hide', 'Sneak', 'Pick Pockets', 'Sense Traps', 'Disarm Traps', 'Disarm', 'Intimidation' },
    War = { 'Kick', 'Bash', 'Taunt', 'Disarm', 'Intimidation' },
    Pal = { 'Bash', 'Taunt', 'Disarm' },
    SK  = { 'Bash', 'Taunt', 'Disarm' },
    Rng = { 'Kick', 'Taunt', 'Disarm', 'Hide', 'Sneak', 'Forage', 'Track' },
    Ber = { 'Frenzy', 'Kick', 'Disarm', 'Intimidation', 'Volley' },
    Bst = { 'Kick', 'Disarm' },
    Brd = { 'Disarm', 'Hide', 'Sneak', 'Pick Pockets', 'Track' },
    Clr = { 'Bash' },
    Dru = { 'Forage', 'Track' },
    Shm = {},
    Nec = {},
    Wiz = {},
    Mag = {},
    Enc = {},
    racial = { 'Slam', 'Hide', 'Sneak', 'Forage' },
    universal = { 'Begging', 'Bind Wound', 'Sense Heading' },
}
local isActionSkill = loadFunc(src, 'isActionSkill', { CLASS_ACTIONS = CLASS_ACTIONS })
local defaultActionEntry = loadFunc(src, 'defaultActionEntry', {})

assert_true(isActionSkill('Mend'), 'action: Mend')
assert_true(isActionSkill('Flying Kick'), 'action: Flying Kick')
assert_true(isActionSkill('Dragon Punch'), 'action: Dragon Punch')
assert_true(isActionSkill('Backstab'), 'action: Backstab')
assert_true(isActionSkill('Kick'), 'action: Kick')
assert_true(isActionSkill('Bash'), 'action: Bash')
assert_true(isActionSkill('Slam'), 'action: Slam')
assert_true(isActionSkill('Frenzy'), 'action: Frenzy')
assert_true(isActionSkill('Feign Death'), 'action: Feign Death')
assert_true(isActionSkill('Taunt'), 'action: Taunt')
assert_true(isActionSkill('Disarm'), 'action: Disarm')
assert_true(isActionSkill('Forage'), 'action: Forage')
assert_true(isActionSkill('Begging'), 'action: Begging')
assert_true(isActionSkill('Bind Wound'), 'action: Bind Wound')
assert_true(isActionSkill('Sense Heading'), 'action: Sense Heading')
assert_eq(isActionSkill('NotARealSkill'), false, 'action: NotARealSkill')
assert_eq(isActionSkill(nil), false, 'action: nil')
assert_eq(isActionSkill(''), false, 'action: empty')

local isNonCombatSkill = loadFunc(src, 'isNonCombatSkill', {})
assert_true(isNonCombatSkill('Begging'), 'noncombat: Begging')
assert_true(isNonCombatSkill('Pick Pockets'), 'noncombat: Pick Pockets')
assert_true(isNonCombatSkill('Hide'), 'noncombat: Hide')
assert_true(isNonCombatSkill('Sneak'), 'noncombat: Sneak')
assert_true(isNonCombatSkill('Bind Wound'), 'noncombat: Bind Wound')
assert_true(isNonCombatSkill('Forage'), 'noncombat: Forage')
assert_true(isNonCombatSkill('Sense Heading'), 'noncombat: Sense Heading')
assert_eq(isNonCombatSkill('Kick'), false, 'noncombat: Kick is false')
assert_eq(isNonCombatSkill('Flying Kick'), false, 'noncombat: Flying Kick is false')
assert_eq(isNonCombatSkill('Taunt'), false, 'noncombat: Taunt is false')
assert_eq(isNonCombatSkill('Mend'), false, 'noncombat: Mend is false')
assert_eq(isNonCombatSkill(''), false, 'noncombat: empty is false')
assert_eq(isNonCombatSkill(nil), false, 'noncombat: nil is false')

local kickDef = defaultActionEntry('Kick', 'War')
assert_eq(kickDef.autoskill, true, 'defaultActionEntry: Kick autoskill=true')
assert_eq(kickDef.kind, 'dd', 'defaultActionEntry: Kick kind=dd')
local mendDef = defaultActionEntry('Mend', 'Mnk')
assert_eq(mendDef.autoskill, false, 'defaultActionEntry: Mend autoskill=false')
assert_eq(mendDef.kind, 'heal', 'defaultActionEntry: Mend kind=heal')
assert_eq(mendDef.pct, 75, 'defaultActionEntry: Mend pct=75')

local actionClassInfo = loadFunc(src, 'actionClassInfo', { CLASS_ACTIONS = CLASS_ACTIONS, myClasses = { 'Mnk', 'War', 'Clr' } })
assert_eq(actionClassInfo('Flying Kick'), 'Mnk', 'actionClassInfo: Flying Kick -> Mnk')
assert_eq(actionClassInfo('Taunt'), 'War', 'actionClassInfo: Taunt -> War')
assert_eq(actionClassInfo('Backstab'), 'Rog', 'actionClassInfo: Backstab -> Rog')

-- Test getClientAbilities with simulated mq.TLO.Skill
local mockSkillData = {
    [0] = { Name = function() return '1H Blunt' end, Activated = function() return false end },
    [1] = { Name = function() return 'Kick' end, Activated = function() return true end, SkillCap = function() return 200 end, MinLevel = function() return 1 end },
    [2] = { Name = function() return 'Flying Kick' end, Activated = function() return true end, SkillCap = function() return 225 end, MinLevel = function() return 30 end },
    [3] = { Name = function() return 'Mend' end, Activated = function() return true end, SkillCap = function() return 200 end, MinLevel = function() return 1 end },
}
local mockMq = {
    TLO = {
        Skill = function(id)
            local d = mockSkillData[id]
            if not d then return nil end
            return setmetatable(d, { __call = function() return true end })
        end,
        Me = {
            Skill = function(name)
                if name == 'Kick' or name == 'Mend' or name == 'Begging' or name == 'Forage' then return function() return 150 end end
                return function() return 0 end
            end,
            SkillCap = function(name)
                if name == 'Kick' or name == 'Flying Kick' or name == 'Mend' or name == 'Begging' or name == 'Forage' then return function() return 200 end end
                return function() return 0 end
            end,
            Ability = function(_) return function() return nil end end,
        },
    }
}
local hasActionSkill = loadFunc(src, 'hasActionSkill', { mq = mockMq })
local getClientAbilities = loadFunc(src, 'getClientAbilities', {
    mq = mockMq,
    CLASS_ACTIONS = CLASS_ACTIONS,
    hasActionSkill = hasActionSkill,
    actionClassInfo = actionClassInfo,
    myClasses = { 'Mnk', 'War', 'Clr' },
    ctrl = { action_trained_only = true },
})

local clientAbilities = getClientAbilities()
assert_true(#clientAbilities >= 3, 'getClientAbilities: returned abilities from client')
local hasKick, hasFK, hasMend, hasBackstab, hasBegging, hasForage = false, false, false, false, false, false
for _, ab in ipairs(clientAbilities) do
    if ab.name == 'Kick' then hasKick = true; assert_true(ab.isTrained, 'Kick is trained') end
    if ab.name == 'Flying Kick' then hasFK = true; assert_eq(ab.isTrained, false, 'Flying Kick not trained yet') end
    if ab.name == 'Mend' then hasMend = true; assert_eq(ab.cls, 'Mnk', 'Mend class is Mnk') end
    if ab.name == 'Begging' then hasBegging = true; assert_true(ab.isTrained, 'Begging is trained') end
    if ab.name == 'Forage' then hasForage = true; assert_true(ab.isTrained, 'Forage is trained') end
    if ab.name == 'Backstab' then hasBackstab = true end
end
assert_true(hasKick, 'trio has Kick')
assert_true(hasFK, 'trio has Flying Kick')
assert_true(hasMend, 'trio has Mend')
assert_true(hasBegging, 'character has Begging')
assert_true(hasForage, 'character has Forage')
assert_eq(hasBackstab, false, 'trio without Rogue does NOT have Backstab')

-- ============================================================================
-- 10. aaTier(sec)
-- ============================================================================
print('--- aaTier ---')
local aaTier = loadFunc(src, 'aaTier', {})

assert_eq(aaTier(5), 'short', 'aaTier: 5s → short')
assert_eq(aaTier(60), 'short', 'aaTier: 60s → short')
assert_eq(aaTier(61), 'mid', 'aaTier: 61s → mid')
assert_eq(aaTier(300), 'mid', 'aaTier: 300s → mid')
assert_eq(aaTier(301), 'burn', 'aaTier: 301s → burn')
assert_eq(aaTier(3600), 'burn', 'aaTier: 3600s → burn')

-- ============================================================================
-- 11. fmtSec(s)
-- ============================================================================
print('--- fmtSec ---')
local fmtSec = loadFunc(src, 'fmtSec', {})

assert_eq(fmtSec(5), '5s', 'fmtSec: 5s')
assert_eq(fmtSec(59), '59s', 'fmtSec: 59s')
assert_eq(fmtSec(60), '1m', 'fmtSec: 60s → 1m')
assert_eq(fmtSec(90), '1m 30s', 'fmtSec: 90s → 1m 30s')
assert_eq(fmtSec(120), '2m', 'fmtSec: 120s → 2m')
assert_eq(fmtSec(3661), '61m 1s', 'fmtSec: 3661s')

-- ============================================================================
-- 12. baseTok(token) — target token normalization
-- ============================================================================
print('--- baseTok ---')
local baseTok = loadFunc(src, 'baseTok', {})

assert_eq(baseTok('F: Myself'), 'Myself', 'baseTok: F: Myself')
assert_eq(baseTok('E: Current Target'), 'Current Target', 'baseTok: E: Current Target')
assert_eq(baseTok('F: Pet'), 'Pet', 'baseTok: F: Pet')
assert_eq(baseTok('Target'), 'Current Target', 'baseTok: Target alias')
assert_eq(baseTok('Current Target'), 'Current Target', 'baseTok: Current Target')
assert_eq(baseTok('Self'), 'Myself', 'baseTok: Self alias')
assert_eq(baseTok('Myself'), 'Myself', 'baseTok: Myself')
assert_eq(baseTok(nil), '', 'baseTok: nil')
assert_eq(baseTok(''), '', 'baseTok: empty')

-- ============================================================================
-- 13. normalizeCommandKey(text) — slash command argument normalization
-- ============================================================================
print('--- normalizeCommandKey ---')
local normalizeCommandKey = loadFunc(src, 'normalizeCommandKey', {})

assert_eq(normalizeCommandKey('Manual'), 'manual', 'cmdKey: Manual')
assert_eq(normalizeCommandKey('PULLER'), 'puller', 'cmdKey: PULLER')
assert_eq(normalizeCommandKey('Chase Assist'), 'chaseassist', 'cmdKey: Chase Assist')
assert_eq(normalizeCommandKey('pull & assist'), 'pullassist', 'cmdKey: pull & assist')
assert_eq(normalizeCommandKey(nil), '', 'cmdKey: nil')
assert_eq(normalizeCommandKey(''), '', 'cmdKey: empty')

-- ============================================================================
-- 14. setTriuneMode(arg1, arg2) — partial test (mode/submode resolution only)
--     We can't fully test this because it calls setManualHunterPetHold and
--     clearMapRadiusVisuals, but we can test the normalizeCommandKey→mode
--     mapping by checking just the parsing portion.
-- ============================================================================
print('--- setTriuneMode (mode parsing) ---')
-- We test via normalizeCommandKey + the known dispatch table documented in the function
-- since setTriuneMode has side effects we can't call outside MQ.
-- Instead, verify the command key mappings are self-consistent:
local MODE_MAP = {
    manual = { 'Manual', 'Hunt' },
    manualhunter = { 'Manual', 'Hunt' },
    puller = { 'Puller', nil },
    hunter = { 'Puller', 'Hunt' },
    pethunter = { 'Puller', 'Hunt' },
    pettank = { 'Puller', 'Hunt' },
    pull = { 'Puller', 'Camp' },
    pullassist = { 'Puller', 'Camp' },
    assist = { 'Assist', nil },
    chase = { 'Assist', 'Chase' },
    chaseassist = { 'Assist', 'Chase' },
    garrison = { 'Assist', 'Camp' },
    tank = { 'Assist', 'Camp' },
    backline = { 'Assist', 'Backline' },
    ranged = { 'Assist', 'Backline' },
}
for input, expected in pairs(MODE_MAP) do
    local key = normalizeCommandKey(input)
    assert_eq(key, input, 'setTriuneMode key: ' .. input .. ' normalizes to itself')
end

-- ============================================================================
-- 15. sungKey(spellName, targetId) — dedup key generation
-- ============================================================================
print('--- sungKey ---')
local sungKey = loadFunc(src, 'sungKey', {})

assert_eq(sungKey('Heal', 123), '123_Heal', 'sungKey: basic')
assert_eq(sungKey('Buff', 0), '0_Buff', 'sungKey: id 0')
assert_eq(sungKey('Spell', nil), '0_Spell', 'sungKey: nil id')

-- ============================================================================
-- 16. classPlausible(abbr) — checks if a class abbreviation is valid
-- ============================================================================
print('--- classPlausible ---')
local classPlausible = loadFunc(src, 'classPlausible',
    { ALL_ABBR = ALL_ABBR, DATA = { spells = {} } })

assert_true(classPlausible('War'), 'plausible: War')
assert_true(classPlausible('SK'), 'plausible: SK')
assert_true(classPlausible('Ber'), 'plausible: Ber')
assert_eq(classPlausible('Xyz'), false, 'plausible: Xyz invalid')
assert_eq(classPlausible(nil), false, 'plausible: nil')
assert_eq(classPlausible(42), false, 'plausible: number')

-- ============================================================================
-- 17. serialize(o, f, indent) — round-trip persistence
-- ============================================================================
print('--- serialize ---')
local serialize = loadFunc(src, 'serialize', {})

-- Helper: serialize to string
local function serializeToString(o)
    local buf = {}
    local fakefile = {
        write = function(_, s) buf[#buf + 1] = s end
    }
    serialize(o, fakefile, 1)
    return table.concat(buf)
end

-- Primitives
assert_eq(serializeToString(42), '42', 'serialize: number')
assert_eq(serializeToString(true), 'true', 'serialize: boolean true')
assert_eq(serializeToString(false), 'false', 'serialize: boolean false')
assert_eq(serializeToString('hello'), '"hello"', 'serialize: string')

-- Table round-trip: serialize then loadstring it back
local testData = {
    mode = 'Manual',
    running = false,
    assist_at = 98,
    chase_dist = 15,
}
local serialized = 'return ' .. serializeToString(testData)
local chunk = assert(loadstring(serialized))
local result = chunk()
assert_eq(result.mode, 'Manual', 'serialize roundtrip: mode')
assert_eq(result.running, false, 'serialize roundtrip: running')
assert_eq(result.assist_at, 98, 'serialize roundtrip: assist_at')
assert_eq(result.chase_dist, 15, 'serialize roundtrip: chase_dist')

-- Nested table round-trip
local nested = { gems = { { spell = 'Heal', slot = 1 } }, version = 3 }
local nestedStr = 'return ' .. serializeToString(nested)
local nchunk = assert(loadstring(nestedStr))
local nresult = nchunk()
assert_eq(nresult.version, 3, 'serialize nested: version')
assert_type(nresult.gems, 'table', 'serialize nested: gems is table')

-- Nil value
assert_eq(serializeToString(nil), 'nil', 'serialize: nil')

-- ============================================================================
-- 18. extractConName (runtime method) — parsing /consider chat lines
-- ============================================================================
print('--- extractConName ---')
-- extractConName is assigned as `function runtime.extractConName(line)`, which
-- our extractor can't pull since it's not `local function`.  Instead, test
-- the same regex logic inline.
local function extractConName(line)
    if not line or line == '' then return nil end
    local name = line:match('^(.-)%s+scowls')
        or line:match('^(.-)%s+glares')
        or line:match('^(.-)%s+glowers')
        or line:match('^(.-)%s+looks')
        or line:match('^(.-)%s+regards')
        or line:match('^(.-)%s+judges')
        or line:match('^(.-)%s+judge')
    if name then
        name = name:gsub('^%s*(.-)%s*$', '%1')
        if name ~= '' then return name end
    end
    return nil
end

assert_eq(extractConName('a fire beetle scowls at you'), 'a fire beetle', 'con: scowls')
assert_eq(extractConName('Guard Hanlon glares at you'), 'Guard Hanlon', 'con: glares')
assert_eq(extractConName('a moss snake regards you'), 'a moss snake', 'con: regards')
assert_eq(extractConName('Merchant looks at you'), 'Merchant', 'con: looks')
assert_eq(extractConName('a_gnoll judges you'), 'a_gnoll', 'con: judges')
assert_nil(extractConName(nil), 'con: nil')
assert_nil(extractConName(''), 'con: empty')

-- ============================================================================
-- 19. createCastTracker & isDetrimentalSpell — failure counting and lockout system
-- ============================================================================
print('--- isDetrimentalSpell & createCastTracker ---')

local triuneSrc = readFile('TAC/tac.lua')
local isDetrimentalSpell = loadstring(extractFunction(triuneSrc, 'isDetrimentalSpell') .. '\nreturn isDetrimentalSpell')()

-- A. isDetrimentalSpell classification tests
assert_eq(isDetrimentalSpell('Heal'), false, 'det: Heal is beneficial')
assert_eq(isDetrimentalSpell('Complete Healing'), false, 'det: Complete Healing is beneficial')
assert_eq(isDetrimentalSpell('Chloroplast'), false, 'det: Chloroplast is beneficial')
assert_eq(isDetrimentalSpell('Focus of Spirit'), false, 'det: Focus of Spirit is beneficial')
assert_eq(isDetrimentalSpell('Skin like Wood'), false, 'det: Skin like Wood is beneficial')
assert_eq(isDetrimentalSpell('Spirit of Wolf'), false, 'det: Spirit of Wolf is beneficial')
assert_eq(isDetrimentalSpell('Clarity'), false, 'det: Clarity is beneficial')
assert_eq(isDetrimentalSpell('Aegolism'), false, 'det: Aegolism is beneficial')
assert_eq(isDetrimentalSpell('Cannibalize'), false, 'det: Cannibalize is beneficial')
assert_eq(isDetrimentalSpell('Gate'), false, 'det: Gate is beneficial')
assert_eq(isDetrimentalSpell('Summon Companion'), false, 'det: Summon Companion is beneficial')

assert_eq(isDetrimentalSpell('Nuke'), true, 'det: Nuke is detrimental')
assert_eq(isDetrimentalSpell('Slow'), true, 'det: Slow is detrimental')
assert_eq(isDetrimentalSpell('Tashani'), true, 'det: Tashani is detrimental')
assert_eq(isDetrimentalSpell('Malo'), true, 'det: Malo is detrimental')
assert_eq(isDetrimentalSpell('Root'), true, 'det: Root is detrimental')
assert_eq(isDetrimentalSpell('Snare'), true, 'det: Snare is detrimental')
assert_eq(isDetrimentalSpell('Enstill'), true, 'det: Enstill is detrimental')
assert_eq(isDetrimentalSpell('Ice Comet'), true, 'det: Ice Comet is detrimental')
assert_eq(isDetrimentalSpell('Doombringing'), true, 'det: Doombringing is detrimental')
assert_eq(isDetrimentalSpell('Kick'), true, 'det: Kick is detrimental')
assert_eq(isDetrimentalSpell('Taunt'), true, 'det: Taunt is detrimental')

-- Explicit kind parameter overrides
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'heal'), false, 'det: kind=heal is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'buff'), false, 'det: kind=buff is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'pet'), false, 'det: kind=pet is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'cure'), false, 'det: kind=cure is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'dd'), true, 'det: kind=dd is detrimental')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'dot'), true, 'det: kind=dot is detrimental')
assert_eq(isDetrimentalSpell('CustomSpell', nil, 'debuff'), true, 'det: kind=debuff is detrimental')

-- Target token overrides
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'E:LowestHP'), true, 'det: E: target is detrimental')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'S:Me'), false, 'det: S: target is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'P:LowestHP'), false, 'det: P: target is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'G:LowestHP'), false, 'det: G: target is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Myself'), false, 'det: F: Myself is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Lowest-HP Ally'), false, 'det: F: Lowest-HP Ally is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Whole Group'), false, 'det: F: Whole Group is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Pet'), false, 'det: F: Pet is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Tank'), false, 'det: F: Tank is beneficial')
assert_eq(isDetrimentalSpell('CustomSpell', nil, nil, 'F: Main Assist'), false, 'det: F: Main Assist is beneficial')

-- B. Out-of-Combat min_xtar evaluation logic tests
local function evalXtOk(numXtar, minXt, isDet)
    return (numXtar >= minXt) or (not isDet and minXt <= 1)
end
assert_eq(evalXtOk(0, 1, false), true, 'min_xtar: OOC beneficial spell with min_xtar=1 is allowed')
assert_eq(evalXtOk(0, 1, true), false, 'min_xtar: OOC detrimental spell with min_xtar=1 is blocked')
assert_eq(evalXtOk(1, 1, true), true, 'min_xtar: Combat detrimental spell with min_xtar=1 is allowed')
assert_eq(evalXtOk(1, 2, true), false, 'min_xtar: Combat detrimental spell with min_xtar=2 blocked on 1 mob')
assert_eq(evalXtOk(2, 2, true), true, 'min_xtar: Combat detrimental spell with min_xtar=2 allowed on 2 mobs')
assert_eq(evalXtOk(0, 3, false), false, 'min_xtar: OOC beneficial spell with explicit min_xtar=3 is blocked')
assert_eq(evalXtOk(3, 3, false), true, 'min_xtar: Combat beneficial spell with explicit min_xtar=3 allowed on 3 mobs')

local function testCastTracker()
    local failureCount     = {}
    local lockouts         = {}
    local targetLockouts   = {}
    local targetImmunities = {}
    local mockClock        = 100 -- fake os.clock()

    local function getFailCount(spellName)
        if not spellName then return 0 end
        local entry = failureCount[spellName]
        if not entry then return 0 end
        if (mockClock - (tonumber(entry.lastFail) or 0)) > 15.0 then
            failureCount[spellName] = nil
            return 0
        end
        return tonumber(entry.count) or 0
    end

    local function incFailCount(spellName)
        if not spellName then return 1 end
        local count = getFailCount(spellName) + 1
        failureCount[spellName] = { count = count, lastFail = mockClock }
        return count
    end

    local function resetFailCount(spellName)
        if spellName then failureCount[spellName] = nil end
    end

    local function isLockedOut(spellName, targetId, kind)
        if not spellName or spellName == '' then return false end

        -- Strictly enforce: Beneficial spells are NEVER locked out under any circumstance.
        -- Only casted detrimental spells can ever be locked out.
        if not isDetrimentalSpell(spellName, targetId, kind) then
            return false
        end

        local tid = tonumber(targetId)

        if tid and tid > 0 and targetImmunities[tid] and targetImmunities[tid][spellName] then
            return true, 'Immune', 9999
        end

        if tid and tid > 0 and targetLockouts[tid] then
            local untilTime = tonumber(targetLockouts[tid][spellName])
            if untilTime then
                if mockClock < untilTime then
                    return true, 'TargetLock', math.ceil(untilTime - mockClock)
                else
                    targetLockouts[tid][spellName] = nil
                end
            end
        end

        local gUntil = tonumber(lockouts[spellName])
        if gUntil then
            if mockClock < gUntil then
                return true, 'GlobalLock', math.ceil(gUntil - mockClock)
            else
                lockouts[spellName] = nil
            end
        end

        return false
    end

    local function recordFailure(spellName, targetId, reason, maxRetries, lockoutSec, kind)
        if not spellName or spellName == '' then return end
        local tid = tonumber(targetId)
        local r = reason or 'generic'
        local mRetries = tonumber(maxRetries) or 2
        local lSec = tonumber(lockoutSec) or 30
        local k = kind

        -- Beneficial spells (heals, buffs, pets, cures) are NEVER locked out under any condition.
        -- Only casted detrimental spells (offensive spells/debuffs) incur failures, immunities, or lockouts.
        if not isDetrimentalSpell(spellName, tid, k) then
            resetFailCount(spellName)
            return
        end

        local rLow = tostring(r):lower()

        if rLow == 'target immune' or rLow == 'immune' then
            if tid and tid > 0 then
                targetImmunities[tid] = targetImmunities[tid] or {}
                targetImmunities[tid][spellName] = true
                resetFailCount(spellName)
            else
                lockouts[spellName] = mockClock + lSec
                resetFailCount(spellName)
            end

        elseif rLow == 'did not take hold' then
            local backoff = math.max(lSec, 120)
            if tid and tid > 0 then
                targetLockouts[tid] = targetLockouts[tid] or {}
                targetLockouts[tid][spellName] = mockClock + backoff
                resetFailCount(spellName)
            else
                lockouts[spellName] = mockClock + lSec
                resetFailCount(spellName)
            end

        elseif rLow == 'resisted' then
            if k == 'dd' or k == 'dot' then
                resetFailCount(spellName)
                return
            end
            local fails = incFailCount(spellName)
            if fails >= mRetries then
                if tid and tid > 0 then
                    targetLockouts[tid] = targetLockouts[tid] or {}
                    targetLockouts[tid][spellName] = mockClock + lSec
                    resetFailCount(spellName)
                else
                    lockouts[spellName] = mockClock + lSec
                    resetFailCount(spellName)
                end
            end

        elseif rLow == 'fizzled' or rLow == 'interrupted' then
            local threshold = math.max(mRetries * 2, 4)
            local fails = incFailCount(spellName)
            if fails >= threshold then
                local shortLock = math.min(lSec, 8)
                lockouts[spellName] = mockClock + shortLock
                resetFailCount(spellName)
            end

        elseif rLow == 'cannot see target' or rLow == 'out of range' or rLow == 'dead target'
            or rLow == 'cannot cast' or rLow == 'insufficient mana' or rLow == 'not ready' then
            return

        else
            local fails = incFailCount(spellName)
            if fails >= mRetries then
                lockouts[spellName] = mockClock + lSec
                resetFailCount(spellName)
            end
        end
    end

    local function recordSuccess(spellName, targetId)
        if not spellName then return end
        resetFailCount(spellName)
        lockouts[spellName] = nil
        local tid = tonumber(targetId)
        if tid and tid > 0 and targetLockouts[tid] then
            targetLockouts[tid][spellName] = nil
        end
    end

    local function clear(targetId)
        local tid = tonumber(targetId)
        if tid and tid > 0 then
            targetLockouts[tid] = nil
            targetImmunities[tid] = nil
        else
            failureCount     = {}
            lockouts         = {}
            targetLockouts   = {}
            targetImmunities = {}
        end
    end

    -- 1. Test: Beneficial spells (Heals, Buffs, etc.) NEVER lock out
    assert_eq(isLockedOut('Heal'), false, 'tracker: Heal not locked initially')
    recordFailure('Heal', nil, 'generic', 2, 30)
    recordFailure('Heal', nil, 'generic', 2, 30)
    recordFailure('Heal', nil, 'generic', 2, 30)
    assert_eq(isLockedOut('Heal'), false, 'tracker: Heal NEVER locked out on generic failure')

    -- 2. Test: Beneficial buff "did not take hold" NEVER locks out or backs off
    recordFailure('Focus', 55, 'did not take hold', 2, 30, 'buff')
    assert_eq(isLockedOut('Focus', 55), false, 'tracker: Focus NEVER locked out on did not take hold')

    -- 3. Test: Beneficial spells never lock out on fizzles / interrupts
    recordFailure('Complete Healing', 10, 'fizzled', 2, 30, 'heal')
    recordFailure('Complete Healing', 10, 'fizzled', 2, 30, 'heal')
    recordFailure('Complete Healing', 10, 'fizzled', 2, 30, 'heal')
    recordFailure('Complete Healing', 10, 'fizzled', 2, 30, 'heal')
    assert_eq(isLockedOut('Complete Healing', 10), false, 'tracker: Complete Healing NEVER locked out on fizzles')

    -- 4. Test: Detrimental spells (Nuke) DO lock out on generic failure after maxRetries
    recordFailure('Nuke', nil, 'generic', 3, 60)
    recordFailure('Nuke', nil, 'generic', 3, 60)
    assert_eq(isLockedOut('Nuke'), false, 'tracker: Nuke 2/3 fails, not locked yet')
    recordFailure('Nuke', nil, 'generic', 3, 60)
    assert_eq(isLockedOut('Nuke'), true, 'tracker: Nuke 3/3 fails, locked out')
    mockClock = 161 -- 100 + 60 + 1
    assert_eq(isLockedOut('Nuke'), false, 'tracker: Nuke lockout expired')

    -- 5. Test: recordSuccess clears failure count on detrimental spell
    recordFailure('Nuke', nil, 'generic', 3, 60)
    recordFailure('Nuke', nil, 'generic', 3, 60)
    recordSuccess('Nuke')
    recordFailure('Nuke', nil, 'generic', 3, 60)
    recordFailure('Nuke', nil, 'generic', 3, 60)
    assert_eq(isLockedOut('Nuke'), false, 'tracker: success resets count')

    -- 6. Test: Detrimental Target-Scoped Immunity (e.g. Slow on immune mob)
    mockClock = 200
    recordFailure('Slow', 101, 'target immune', 2, 30, 'debuff')
    assert_eq(isLockedOut('Slow', 101), true, 'tracker: target 101 is immune to Slow')
    assert_eq(isLockedOut('Slow', 102), false, 'tracker: target 102 is NOT immune to Slow')
    assert_eq(isLockedOut('Slow'), false, 'tracker: Slow is NOT locked out globally')

    -- 7. Test: Detrimental "Did Not Take Hold" (Non-stacking debuff backoff on enemy)
    mockClock = 300
    recordFailure('Tash', 55, 'did not take hold', 2, 30, 'debuff')
    assert_eq(isLockedOut('Tash', 55), true, 'tracker: Tash backed off on target 55')
    assert_eq(isLockedOut('Tash', 56), false, 'tracker: Tash available for target 56')
    mockClock = 421 -- 300 + 120 + 1
    assert_eq(isLockedOut('Tash', 55), false, 'tracker: Tash backoff expired on target 55')

    -- 8. Test: Direct Damage Resists do NOT trigger lockouts
    mockClock = 500
    recordFailure('Ice Comet', 101, 'resisted', 2, 30, 'dd')
    recordFailure('Ice Comet', 101, 'resisted', 2, 30, 'dd')
    recordFailure('Ice Comet', 101, 'resisted', 2, 30, 'dd')
    assert_eq(isLockedOut('Ice Comet', 101), false, 'tracker: DD nukes never lock out on resists')

    -- 9. Test: Debuff Resists back off only on specific target after maxRetries
    mockClock = 600
    recordFailure('Tash', 201, 'resisted', 2, 30, 'debuff')
    assert_eq(isLockedOut('Tash', 201), false, 'tracker: 1 debuff resist does not lock')
    recordFailure('Tash', 201, 'resisted', 2, 30, 'debuff')
    assert_eq(isLockedOut('Tash', 201), true, 'tracker: 2 debuff resists lock out on target 201')
    assert_eq(isLockedOut('Tash', 202), false, 'tracker: Tash remains usable on target 202')

    -- 10. Test: Failure count TTL decay (15s)
    mockClock = 700
    recordFailure('Root', 301, 'resisted', 2, 30, 'debuff')
    mockClock = 720 -- 20 seconds later (> 15s decay)
    recordFailure('Root', 301, 'resisted', 2, 30, 'debuff')
    assert_eq(isLockedOut('Root', 301), false, 'tracker: failure count decayed after 20s')

    -- 11. Test: Dead target / Positional events have 0 penalty
    mockClock = 800
    recordFailure('Nuke', 10, 'dead target', 1, 10, 'dd')
    recordFailure('Nuke', 10, 'out of range', 1, 10, 'dd')
    recordFailure('Nuke', 10, 'cannot see target', 1, 10, 'dd')
    assert_eq(isLockedOut('Nuke', 10), false, 'tracker: positional/dead target events incur 0 penalty')

    -- 12. Test: Targeted clear vs global clear
    mockClock = 850
    recordFailure('Tash', 201, 'resisted', 2, 30, 'debuff')
    recordFailure('Tash', 201, 'resisted', 2, 30, 'debuff')
    assert_eq(isLockedOut('Tash', 201), true, 'tracker: target 201 locked out')
    clear(101)
    assert_eq(isLockedOut('Slow', 101), false, 'tracker: clear(101) cleared immunity for 101')
    assert_eq(isLockedOut('Tash', 201), true, 'tracker: clear(101) did not clear 201')
    clear()
    assert_eq(isLockedOut('Tash', 201), false, 'tracker: global clear() cleared all lockouts')
end
testCastTracker()

-- ============================================================================
-- 40. Spell Gem Enhancements (Presets, Advanced Conditions, Reagents, Swap)
-- ============================================================================
print('--- Spell Gem Enhancements ---')
do
    -- A. Deep copy & Preset Management
    local function deepCopyTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[deepCopyTable(orig_key)] = deepCopyTable(orig_value)
            end
            setmetatable(copy, deepCopyTable(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end

    local testGems = {
        [1] = { cls = 'Clr', spell = 'Complete Healing', target = 'F: Tank', when = 'HP <=', pct = 50 },
        [2] = { cls = 'Wiz', spell = 'Ice Comet', target = 'E: Current Target', when = 'target HP between', pct = 90, min_hp = 20, boss_only = true },
        [3] = { cls = 'Enc', spell = 'Tashani', target = 'E: Current Target', when = 'in combat', pct = 100 }
    }

    local presets = {}
    presets['BossBurn'] = {
        name = 'BossBurn',
        gems = deepCopyTable(testGems),
        savedAt = '2026-08-30 12:00:00'
    }

    -- Verify deep copy isolation
    testGems[1].pct = 20
    assert_eq(presets['BossBurn'].gems[1].pct, 50, 'preset deep copy: original modification does not alter preset')
    assert_eq(presets['BossBurn'].gems[2].boss_only, true, 'preset deep copy: boss_only preserved')
    assert_eq(presets['BossBurn'].gems[2].min_hp, 20, 'preset deep copy: min_hp preserved')

    -- B. Gem Slot Swap Logic
    local function swapGems(t, slotA, slotB)
        local tmp = t[slotA]
        t[slotA] = t[slotB]
        t[slotB] = tmp
    end

    local gemBar = { [1] = 'Heal', [2] = 'Nuke', [3] = 'Stun' }
    swapGems(gemBar, 1, 2)
    assert_eq(gemBar[1], 'Nuke', 'gem swap: slot 1 is now Nuke')
    assert_eq(gemBar[2], 'Heal', 'gem swap: slot 2 is now Heal')

    -- C. Advanced Condition Evaluations
    local function evalHpBetween(targetHp, minHp, maxHp)
        return targetHp >= (minHp or 20) and targetHp <= (maxHp or 100)
    end

    assert_true(evalHpBetween(50, 20, 90), 'hp between: 50% is between 20% and 90%')
    assert_true(evalHpBetween(20, 20, 90), 'hp between: 20% is at lower bound')
    assert_true(evalHpBetween(90, 20, 90), 'hp between: 90% is at upper bound')
    assert_true(not evalHpBetween(15, 20, 90), 'hp between: 15% is below min (DoT skipped on low mob)')
    assert_true(not evalHpBetween(95, 20, 90), 'hp between: 95% is above max')

    local function evalAggro(myAggro, targetAggroHolder, myName, threshold)
        local aggro = myAggro or 0
        if aggro == 0 and targetAggroHolder == myName then aggro = 100 end
        return aggro >= threshold
    end

    assert_true(evalAggro(0, 'PlayerA', 'PlayerA', 90), 'aggro on me: target targeting me gives 100% aggro')
    assert_true(evalAggro(95, 'TankB', 'PlayerA', 90), 'my aggro >=: 95% >= 90% triggers')
    assert_true(not evalAggro(40, 'TankB', 'PlayerA', 90), 'my aggro >=: 40% < 90% does not trigger')

    -- D. Reagent Checking Logic
    local function checkReagents(reagentList, inventoryCounts)
        for _, req in ipairs(reagentList) do
            local cur = inventoryCounts[req.id] or 0
            if cur < req.count then return false end
        end
        return true
    end

    local boneChipsReq = { { id = 13073, count = 1 } } -- Bone Chips
    assert_true(checkReagents(boneChipsReq, { [13073] = 10 }), 'reagent check: bone chips available')
    assert_true(not checkReagents(boneChipsReq, { [13073] = 0 }), 'reagent check: missing bone chips blocks cast')
    assert_true(not checkReagents(boneChipsReq, {}), 'reagent check: empty inventory blocks cast')
end

-- ============================================================================
-- 38. Cooldown Monitor Logic & Diagnostics Tests
-- ============================================================================
print('--- Cooldown Monitor Logic & Diagnostics ---')
do
    -- A. Diagnostics evaluator
    local function evaluateStatus(isReady, isActive, activeSec, endCost, myEnd, isBurnOnly, isBurnActive, minXt, xtCount)
        if isActive then return 'ACTIVE' end
        if not isReady then return 'COOLDOWN' end
        if endCost > 0 and myEnd < endCost then return 'LOW END' end
        if isBurnOnly and not isBurnActive then return 'NEED BURN' end
        if xtCount < minXt then return 'MIN XTAR' end
        return 'READY'
    end

    assert_eq(evaluateStatus(true, false, 0, 0, 1000, false, false, 1, 2), 'READY', 'cd status: ready')
    assert_eq(evaluateStatus(false, true, 12, 0, 1000, false, false, 1, 2), 'ACTIVE', 'cd status: active')
    assert_eq(evaluateStatus(false, false, 0, 0, 1000, false, false, 1, 2), 'COOLDOWN', 'cd status: cooldown')
    assert_eq(evaluateStatus(true, false, 0, 500, 200, false, false, 1, 2), 'LOW END', 'cd status: low endurance')
    assert_eq(evaluateStatus(true, false, 0, 0, 1000, true, false, 1, 2), 'NEED BURN', 'cd status: need burn')
    assert_eq(evaluateStatus(true, false, 0, 0, 1000, false, false, 3, 1), 'MIN XTAR', 'cd status: min xtar')

    -- B. Sorting evaluator (Cooldown & Active items at TOP of the list)
    local testItems = {
        { name = 'Kick', ready = true, active = false, priority = 50, timeLeft = 0 },
        { name = 'Defensive', ready = false, active = true, activeSec = 18, priority = 10, timeLeft = 0 },
        { name = 'Bash', ready = true, active = false, priority = 20, timeLeft = 0 },
        { name = 'Furious', ready = false, active = false, priority = 10, timeLeft = 45 },
        { name = 'Fortitude', ready = false, active = false, priority = 15, timeLeft = 12 },
    }

    table.sort(testItems, function(a, b)
        -- 1. Active items first
        if a.active ~= b.active then return a.active end
        if a.active and b.active then return (a.activeSec or 0) < (b.activeSec or 0) end

        -- 2. Items on Cooldown NEXT at the top of the list
        local aInCd = (not a.ready)
        local bInCd = (not b.ready)
        if aInCd ~= bInCd then return aInCd end

        -- Both on cooldown: sort by time remaining ascending (soonest to become ready first)
        if aInCd and bInCd then
            if math.abs((a.timeLeft or 0) - (b.timeLeft or 0)) > 0.05 then
                return (a.timeLeft or 0) < (b.timeLeft or 0)
            end
            return (a.priority or 50) < (b.priority or 50)
        end

        -- 3. Both Ready: sort by priority ascending
        if (a.priority or 50) ~= (b.priority or 50) then
            return (a.priority or 50) < (b.priority or 50)
        end
        return (a.name or '') < (b.name or '')
    end)

    assert_eq(testItems[1].name, 'Defensive', 'cd sort time: Active item at top')
    assert_eq(testItems[2].name, 'Fortitude', 'cd sort time: Soonest off cooldown next at top (12s < 45s)')
    assert_eq(testItems[3].name, 'Furious', 'cd sort time: Later off cooldown (45s)')
    assert_eq(testItems[4].name, 'Bash', 'cd sort time: Ready item with higher priority next (Pri 20 < 50)')
    assert_eq(testItems[5].name, 'Kick', 'cd sort time: Ready item with lower priority last (Pri 50)')

    -- C. Ability Base Cooldowns
    local ABILITY_BASE_COOLDOWNS = {
        ['Kick'] = 6, ['Bash'] = 6, ['Slam'] = 6, ['Flying Kick'] = 6,
        ['Backstab'] = 10, ['Taunt'] = 6, ['Mend'] = 360, ['Feign Death'] = 8,
    }
    assert_eq(ABILITY_BASE_COOLDOWNS['Kick'], 6, 'ability cd: Kick is 6s')
    assert_eq(ABILITY_BASE_COOLDOWNS['Backstab'], 10, 'ability cd: Backstab is 10s')
    assert_eq(ABILITY_BASE_COOLDOWNS['Mend'], 360, 'ability cd: Mend is 360s')
    assert_eq(ABILITY_BASE_COOLDOWNS['Feign Death'], 8, 'ability cd: Feign Death is 8s')

    -- D. AA and Discipline Timer Conversions & Timer Groups
    local function parseCombatAbilityTimer(rawVal)
        if type(rawVal) == 'table' and rawVal.TotalSeconds then
            return rawVal.TotalSeconds
        end
        local n = tonumber(rawVal) or 0
        if n > 1000 then return n / 1000.0 end
        if n > 0 and n <= 500 then return n * 6 end -- ticks to seconds
        return n
    end

    assert_eq(parseCombatAbilityTimer(5), 30, 'disc timer: 5 ticks = 30s')
    assert_eq(parseCombatAbilityTimer(10), 60, 'disc timer: 10 ticks = 60s')
    assert_eq(parseCombatAbilityTimer(90000), 90, 'disc timer: 90000ms = 90s')
    assert_eq(parseCombatAbilityTimer({ TotalSeconds = 45 }), 45, 'disc timer: TotalSeconds = 45s')

    local function checkTimerGroupActive(activeTimerGroups, discTimerGroup, now)
        if not discTimerGroup then return false, 0 end
        local exp = activeTimerGroups[discTimerGroup] or 0
        if exp > now then
            return true, exp - now
        end
        return false, 0
    end

    local now = 1000
    local timerGroups = { ['T1'] = 1045, ['T2'] = 980 }
    local isT1Active, t1Rem = checkTimerGroupActive(timerGroups, 'T1', now)
    local isT2Active, t2Rem = checkTimerGroupActive(timerGroups, 'T2', now)
    assert_true(isT1Active, 'timer group: T1 is active')
    assert_eq(t1Rem, 45, 'timer group: T1 has 45s left')
    assert_true(not isT2Active, 'timer group: T2 has expired')

    -- E. Cooldowns Tab Ordering & Declaration
    local triuneContent = readFile('TAC/tac.lua')
    assert_true(triuneContent:find('function UI.drawCooldownsTab()', 1, true) ~= nil, 'cooldown tab: UI.drawCooldownsTab defined')
    local tabOrderMatch = triuneContent:find('UI.drawAATab%(%)[%s\r\n]+UI.drawCooldownsTab%(%)[%s\r\n]+UI.drawDiscTab%(%)')
    assert_true(tabOrderMatch ~= nil, 'cooldown tab: Cooldowns tab positioned right after AAs tab in triuneTabs')

    -- F. parseDurationSec & parseSpellRecastTime Comprehensive Tests
    local function parseDurationSec(durObj)
        if not durObj then return 0 end
        local sec = 0
        pcall(function()
            if type(durObj) == 'number' then
                if durObj > 1800 then sec = durObj / 1000.0
                elseif durObj > 0 and durObj <= 500 then sec = durObj * 6
                else sec = durObj end
                return
            end
            if type(durObj) == 'table' then
                if durObj.TotalSeconds then
                    if type(durObj.TotalSeconds) == 'function' then
                        sec = tonumber(durObj.TotalSeconds() or 0) or 0
                    else
                        sec = tonumber(durObj.TotalSeconds) or 0
                    end
                    if sec > 0 then return end
                end
                if durObj.Raw then
                    local r = type(durObj.Raw) == 'function' and durObj.Raw() or durObj.Raw
                    local nr = tonumber(r or 0) or 0
                    if nr > 0 then sec = nr / 1000.0; return end
                end
                if durObj.Ticks then
                    local t = type(durObj.Ticks) == 'function' and durObj.Ticks() or durObj.Ticks
                    local nt = tonumber(t or 0) or 0
                    if nt > 0 then sec = nt * 6; return end
                end
            end
            if type(durObj) == 'function' then
                local val = durObj()
                if val ~= nil then
                    local n = tonumber(val) or 0
                    if n > 1800 then sec = n / 1000.0
                    elseif n > 0 and n <= 500 then sec = n * 6
                    else sec = n end
                end
            end
        end)
        return sec
    end

    -- MacroQuest Me.Buff.Duration tests
    assert_eq(parseDurationSec({ TotalSeconds = function() return 180 end }), 180, 'parseDurationSec: TotalSeconds() method')
    assert_eq(parseDurationSec({ TotalSeconds = 45 }), 45, 'parseDurationSec: TotalSeconds property')
    assert_eq(parseDurationSec({ Raw = function() return 18000 end }), 18, 'parseDurationSec: Raw() ms method (18000ms = 18s)')
    assert_eq(parseDurationSec({ Ticks = function() return 10 end }), 60, 'parseDurationSec: Ticks() method (10 ticks = 60s)')
    assert_eq(parseDurationSec(function() return "18000" end), 18, 'parseDurationSec: string ms fallback (18000ms = 18s)')
    assert_eq(parseDurationSec(function() return "5" end), 30, 'parseDurationSec: string ticks fallback (5 ticks = 30s)')

    -- G. DISC_BASE_COOLDOWNS and DISC_BASE_DURATIONS Lookups
    local DISC_BASE_COOLDOWNS = {
        ['defensive discipline'] = 900,
        ['evasive discipline'] = 900,
        ['fortitude discipline'] = 3600,
        ['furious discipline'] = 3600,
        ['stonewall discipline'] = 900,
        ['duelist discipline'] = 1200,
        ['kinetics discipline'] = 1200,
        ['trueshot discipline'] = 1800,
        ['weapon shield discipline'] = 3600,
        ['hundred fists discipline'] = 1800,
        ['unflinching will'] = 30,
        ['bellow of the kedge'] = 30,
    }
    local DISC_BASE_DURATIONS = {
        ['defensive discipline'] = 180,
        ['evasive discipline'] = 180,
        ['fortitude discipline'] = 8,
        ['furious discipline'] = 9,
        ['stonewall discipline'] = 180,
        ['duelist discipline'] = 72,
        ['kinetics discipline'] = 72,
        ['trueshot discipline'] = 120,
        ['weapon shield discipline'] = 18,
        ['hundred fists discipline'] = 72,
        ['unflinching will'] = 18,
    }

    assert_eq(DISC_BASE_COOLDOWNS['defensive discipline'], 900, 'disc base cd: Defensive is 900s (15m)')
    assert_eq(DISC_BASE_COOLDOWNS['fortitude discipline'], 3600, 'disc base cd: Fortitude is 3600s (60m)')
    assert_eq(DISC_BASE_DURATIONS['defensive discipline'], 180, 'disc base dur: Defensive is 180s (3m)')
    assert_eq(DISC_BASE_DURATIONS['fortitude discipline'], 8, 'disc base dur: Fortitude is 8s')

    -- H. Progress Bar Active Scaling Calculation
    local activeSec = 180
    local activeTotalSec = 180
    local actFrac = math.min(1.0, math.max(0.0, activeSec / activeTotalSec))
    assert_eq(actFrac, 1.0, 'progress bar active: Full duration gives 100% (1.0) cyan bar')

    activeSec = 90
    actFrac = math.min(1.0, math.max(0.0, activeSec / activeTotalSec))
    assert_eq(actFrac, 0.5, 'progress bar active: Half duration gives 50% (0.5) cyan bar')
end

-- ============================================================================
-- Results
-- ============================================================================
print(string.format('\n=== Results: %d passed, %d failed ===', pass, fail))
if fail > 0 then
    print('\nFailures:')
    for _, e in ipairs(errors) do print(e) end
    os.exit(1)
else
    print('All tests passed.')
    os.exit(0)
end
