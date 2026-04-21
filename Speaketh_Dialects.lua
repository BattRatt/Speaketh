-- Speaketh_Dialects.lua
-- Dialect / accent system.  Every dialect uses a 0-3 intensity slider.
-- Level 0 = off, 1 = light, 2 = moderate, 3 = full.
-- Substitutions are tiered: each sub has a minimum level to activate.

Speaketh_Dialects = {}

-- ============================================================
-- Registry
-- ============================================================
local DIALECTS = {}
local DIALECT_ORDER = {}

local function RegisterDialect(key, data)
    DIALECTS[key] = data
    table.insert(DIALECT_ORDER, key)
end

-- ============================================================
-- Helpers
-- ============================================================
local function MatchCase(original, replacement)
    if original == original:upper() then
        return replacement:upper()
    elseif original:sub(1,1) == original:sub(1,1):upper() then
        return replacement:sub(1,1):upper() .. replacement:sub(2)
    else
        return replacement:lower()
    end
end

-- Apply word-boundary-aware substitutions.
-- Each entry in subs is {phrase, replacement, minLevel}.
-- Only entries with minLevel <= current level fire.
local function ApplySubstitutes(text, subs, level)
    if not subs then return text end

    -- Filter to active subs and sort longest-first
    local active = {}
    for _, entry in ipairs(subs) do
        if level >= entry[3] then
            table.insert(active, entry)
        end
    end
    table.sort(active, function(a, b) return #a[1] > #b[1] end)

    for _, entry in ipairs(active) do
        local lower = text:lower()
        local searchLower = entry[1]:lower()
        local out = {}
        local pos = 1
        while pos <= #text do
            local s, e = lower:find(searchLower, pos, true)
            if s then
                local before = (s == 1) or not text:sub(s-1, s-1):match("[%a']")
                local after  = (e == #text) or not text:sub(e+1, e+1):match("[%a']")
                if before and after then
                    table.insert(out, text:sub(pos, s - 1))
                    table.insert(out, MatchCase(text:sub(s, e), entry[2]))
                    pos = e + 1
                else
                    table.insert(out, text:sub(pos, s))
                    pos = s + 1
                end
            else
                table.insert(out, text:sub(pos))
                break
            end
        end
        text = table.concat(out)
    end
    return text
end

-- ============================================================
-- Drunk slur engine (letter-level mangling)
-- ============================================================
local function DrunkSlurLevel1(text)
    text = text:gsub("([%a])s([%a])", function(b, a)
        if math.random(1,100) <= 30 then return b.."sh"..a end
        return b.."s"..a
    end)
    text = text:gsub("([%a])", function(c)
        if math.random(1,100) <= 5 then return c..c end
        return c
    end)
    return text
end

local function DrunkSlurLevel2(text)
    text = text:gsub("([%a])s", function(b)
        if math.random(1,100) <= 50 then return b.."sh" end
        return b.."s"
    end)
    text = text:gsub("(%s)([Ss])", function(sp, s)
        if math.random(1,100) <= 40 then
            return sp..(s=="S" and "Sh" or "sh")
        end
        return sp..s
    end)
    text = text:gsub("[Tt]h", function(th)
        if math.random(1,100) <= 35 then
            return th:sub(1,1)=="T" and "D" or "d"
        end
        return th
    end)
    text = text:gsub("([aeiouAEIOU])", function(v)
        if math.random(1,100) <= 15 then return v..v end
        return v
    end)
    text = text:gsub("([%a])", function(c)
        if math.random(1,100) <= 8 then return c..c end
        return c
    end)
    return text
end

local function DrunkSlurLevel3(text)
    text = text:gsub("[Ss]", function(s)
        if math.random(1,100) <= 70 then return s=="S" and "Sh" or "sh" end
        return s
    end)
    text = text:gsub("[Tt]h", function(th)
        if math.random(1,100) <= 60 then return th:sub(1,1)=="T" and "D" or "d" end
        return th
    end)
    text = text:gsub("([aeiouAEIOU])", function(v)
        local r = math.random(1,100)
        if r <= 25 then return v..v..v
        elseif r <= 45 then return v..v end
        return v
    end)
    text = text:gsub("([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ])", function(c)
        if math.random(1,100) <= 15 then return c..c end
        return c
    end)
    -- R deletion: only delete if the word has other characters around it
    -- Process word-by-word to prevent entire words from being deleted
    text = text:gsub("(%S+)", function(word)
        local result = word:gsub("[Rr]", function(r)
            local roll = math.random(1,100)
            if roll <= 20 then return r..r
            elseif roll <= 30 then return "" end
            return r
        end)
        -- Never let a word become empty
        if result == "" or not result:match("%a") then
            return word
        end
        return result
    end)
    text = text:gsub("(%s)([aeiouAEIOU])", function(sp, v)
        if math.random(1,100) <= 20 then return sp.."w"..v end
        return sp..v
    end)
    return text
end

local function DrunkMessCaps(text, level)
    if level < 2 then return text end
    local chance = level==2 and 10 or 25
    return text:gsub("(%a)", function(c)
        if math.random(1,100) <= chance then
            return c==c:upper() and c:lower() or c:upper()
        end
        return c
    end)
end

local function DrunkSlur(text, level)
    if not text or text == "" then return text end
    local original = text
    if level==1 then text = DrunkSlurLevel1(text)
    elseif level==2 then text = DrunkSlurLevel2(text)
    elseif level>=3 then text = DrunkSlurLevel3(text) end
    text = DrunkMessCaps(text, level)
    -- Safety: never return empty or whitespace-only text
    if not text or text == "" or not text:match("%S") then
        return original
    end
    -- Cap length to prevent exceeding WoW's 255 char message limit
    if #text > 250 then
        text = text:sub(1, 250)
        -- Don't cut in the middle of a word; trim to last space
        local lastSpace = text:match(".*()%s")
        if lastSpace and lastSpace > 200 then
            text = text:sub(1, lastSpace - 1)
        end
    end
    return text
end

local function SlurName(name, level)
    if level <= 1 then return name end
    local result = name:gsub("([Ss])", function(s)
        if math.random(1,100) <= 30 then return s=="S" and "Sh" or "sh" end
        return s
    end)
    if level >= 3 then
        result = result:gsub("([aeiouAEIOU])", function(v)
            if math.random(1,100) <= 20 then return v..v end
            return v
        end, 1)
    end
    return result
end

-- ============================================================
-- DIALECT: Drunk
-- ============================================================
local HICCUPS_LIGHT  = {"*hic*"}
local HICCUPS_MEDIUM = {"*hic*", "..hic!", "..."}
local HICCUPS_FULL  = {
    "*hic*", "..HIC!", "*hic*",
    "...hic!", "*hic*", "...*hic*...",
    "*hiccup*", "..wha?", "...heh",
}

RegisterDialect("Drunk", {
    name = "Drunk",
    usesSlider = true,
    sliderLabels = {"Sober", "Tipsy", "Drunk", "Smashed"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.9, 0.85, 0.3},
        {1.0, 0.55, 0.2},
        {1.0, 0.25, 0.25},
    },
    substitutes = nil,
    slur = function(text, level) return DrunkSlur(text, level) end,
    slurName = function(name, level) return SlurName(name, level) end,
    interjections = {
        [1] = HICCUPS_LIGHT,
        [2] = HICCUPS_MEDIUM,
        [3] = HICCUPS_FULL,
    },
    interjectionChance  = {[1]=8,  [2]=18, [3]=30},
    interjectionEndChance = {[1]=0, [2]=30, [3]=45},
})

-- ============================================================
-- DIALECT: Gilnean (British / Cockney accent)
-- ============================================================
RegisterDialect("Gilnean", {
    name = "Gilnean",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.55, 0.75, 1.0},
        {0.4, 0.6, 1.0},
        {0.3, 0.45, 1.0},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Lordaeron (Formal / Archaic)
-- ============================================================
RegisterDialect("Lordaeron", {
    name = "Lordaeron",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.85, 0.75, 0.5},
        {0.75, 0.65, 0.35},
        {0.65, 0.55, 0.2},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Goblin
-- ============================================================
RegisterDialect("Goblin", {
    name = "Goblin",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.4, 0.85, 0.4},
        {0.3, 0.75, 0.3},
        {0.2, 0.65, 0.2},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- DIALECT: Troll (Darkspear / Zandalari accent)
-- ============================================================
RegisterDialect("Troll", {
    name = "Troll",
    usesSlider = true,
    sliderLabels = {"Off", "Light", "Moderate", "Full"},
    sliderColors = {
        {0.5, 0.8, 0.5},
        {0.3, 0.85, 0.65},
        {0.2, 0.75, 0.55},
        {0.1, 0.65, 0.45},
    },
    substitutes = nil,  -- rules live in Speaketh_Char.dialectSubstitutes
    slur = nil,
    interjections = nil,
})

-- ============================================================
-- Built-in substitution seed data
-- These are the factory defaults for each dialect's word rules.
-- They are written into Speaketh_Char.dialectSubstitutes once on
-- first load, after which users can freely edit, add, or remove them.
-- The {from, to, minLevel} format is preserved so the UI can show
-- which intensity tier each rule originally belonged to.
-- ============================================================
local BUILTIN_SUBSTITUTES = {
    Gilnean = {
        {"hi",          "oi",               1},
        {"hey",         "oi",               1},
        {"hello",       "'ello",            1},
        {"hiya",        "'eya",             1},
        {"yes",         "aye",              1},
        {"you",         "ya'",              1},
        {"your",        "yer",              1},
        {"my",          "me",               1},
        {"friend",      "mate",             1},
        {"friends",     "mates",            1},
        {"right",       "roight",           1},
        {"alright",     "a'roight",         1},
        {"good",        "proper",           1},
        {"isn't",       "ain't",            1},
        {"aren't",      "ain't",            1},
        {"talk",        "gab",              1},
        {"talking",     "gabbin'",          1},
        {"trash",       "rubbish",          1},
        {"what",        "wot",              2},
        {"whatever",    "wotever",          2},
        {"what's",      "wot's",            2},
        {"was",         "wus",              2},
        {"were",        "wus",              2},
        {"wasn't",      "wusn't",           2},
        {"never",       "niver",            2},
        {"not",         "no'",              2},
        {"nothing",     "nuffin",           2},
        {"something",   "sumfin",           2},
        {"anything",    "anyfing",          2},
        {"everything",  "everyfin",         2},
        {"think",       "fink",             2},
        {"thinking",    "finkin'",          2},
        {"thought",     "fought",           2},
        {"thing",       "fing",             2},
        {"things",      "fings",            2},
        {"with",        "wif",              2},
        {"without",     "wifout",           2},
        {"going",       "goin'",            2},
        {"coming",      "comin'",           2},
        {"doing",       "doin'",            2},
        {"looking",     "lookin'",          2},
        {"getting",     "gettin'",          2},
        {"fighting",    "fightin'",         2},
        {"running",     "runnin'",          2},
        {"little",      "li'l",             2},
        {"old",         "ol'",              2},
        {"about",       "'bout",            2},
        {"you'd",       "yah'd",            3},
        {"you'll",      "ya'll",            3},
        {"you're",      "ya're",            3},
        {"you've",      "ya've",            3},
        {"yourself",    "ya'self",          3},
        {"there",       "dere",             3},
        {"their",       "dere",             3},
        {"they're",     "dey're",           3},
        {"them",        "'em",              3},
        {"the",         "da",               3},
        {"this",        "dis",              3},
        {"that",        "dat",              3},
        {"those",       "dose",             3},
        {"these",       "dese",             3},
        {"have",        "'ave",             3},
        {"having",      "'avin'",           3},
        {"had",         "'ad",              3},
        {"has",         "'as",              3},
        {"where",       "wer",              3},
        {"man",         "bloke",            3},
        {"woman",       "bird",             3},
        {"money",       "quid",             3},
        {"drunk",       "pissed",           3},
        {"food",        "grub",             3},
        {"house",       "gaff",             3},
        {"stupid",      "daft",             3},
        {"crazy",       "barmy",            3},
        {"very",        "right",            3},
        {"really",      "proper",           3},
    },
    Lordaeron = {
        {"hi",          "well met",         1},
        {"hey",         "hail",             1},
        {"hello",       "well met",         1},
        {"bye",         "fare thee well",   1},
        {"goodbye",     "fare thee well",   1},
        {"yes",         "aye",              1},
        {"yeah",        "aye",              1},
        {"no",          "nay",              1},
        {"nope",        "nay",              1},
        {"please",      "prithee",          1},
        {"thanks",      "my thanks",        1},
        {"thank you",   "I am grateful",    1},
        {"ok",          "very well",        1},
        {"okay",        "very well",        1},
        {"sure",        "indeed",           1},
        {"you",         "thee",             2},
        {"your",        "thine",            2},
        {"you're",      "thou art",         2},
        {"you've",      "thou hast",        2},
        {"you'll",      "thou shalt",       2},
        {"yourself",    "thyself",          2},
        {"my",          "mine",             2},
        {"i'm",         "I am",             2},
        {"i'll",        "I shall",          2},
        {"i've",        "I have",           2},
        {"we'll",       "we shall",         2},
        {"don't",       "do not",           2},
        {"can't",       "cannot",           2},
        {"won't",       "shall not",        2},
        {"isn't",       "is not",           2},
        {"didn't",      "did not",          2},
        {"doesn't",     "does not",         2},
        {"friend",      "companion",        2},
        {"friends",     "companions",       2},
        {"enemy",       "foe",              2},
        {"enemies",     "foes",             2},
        {"sorry",       "forgive me",       2},
        {"maybe",       "mayhaps",          2},
        {"wasn't",      "was not",          3},
        {"aren't",      "are not",          3},
        {"wouldn't",    "would not",        3},
        {"couldn't",    "could not",        3},
        {"shouldn't",   "should not",       3},
        {"fight",       "do battle",        3},
        {"fighting",    "battling",         3},
        {"kill",        "slay",             3},
        {"killed",      "slain",            3},
        {"go",          "venture forth",    3},
        {"come",        "approach",         3},
        {"come here",   "approach",         3},
        {"look",        "behold",           3},
        {"help",        "aid",              3},
        {"give",        "bestow",           3},
        {"want",        "desire",           3},
        {"need",        "require",          3},
        {"probably",    "most assuredly",   3},
        {"awesome",     "most splendid",    3},
        {"cool",        "commendable",      3},
        {"great",       "most excellent",   3},
        {"stop",        "cease",            3},
        {"before",      "ere",              3},
    },
    Goblin = {
        {"you",         "youse",            1},
        {"your",        "ya",               1},
        {"yours",       "yas",              1},
        {"the",         "da",               1},
        {"this",        "dis",              1},
        {"that",        "dat",              1},
        {"with",        "wit",              1},
        {"yes",         "yeah",             1},
        {"hey",         "ay",               1},
        {"hi",          "ay",               1},
        {"hello",       "ay",               1},
        {"guys",        "youse guys",       1},
        {"because",     "'cause",           2},
        {"kind of",     "kinda",            2},
        {"sort of",     "sorta",            2},
        {"going to",    "gonna",            2},
        {"want to",     "wanna",            2},
        {"got to",      "gotta",            2},
        {"have to",     "gotta",            2},
        {"a lot",       "a buncha",         2},
        {"lots of",     "a buncha",         2},
        {"these",       "dese",             2},
        {"those",       "dose",             2},
        {"there",       "dere",             2},
        {"them",        "'em",              2},
        {"about",       "'bout",            2},
        {"alright",     "awright",          2},
        {"around",      "'round",           2},
        {"for",         "fer",              2},
        {"friend",      "pal",              2},
        {"buddy",       "pal",              2},
        {"look",        "lookit",           2},
        {"listen",      "lissen",           2},
        {"what are",    "whaddya",          2},
        {"what do you", "wha'chu",          2},
        {"what you",    "wha'chu",          2},
        {"don't you",   "dontcha",          2},
        {"idea",        "idear",            2},
        {"ideas",       "idears",           2},
        {"forget it",   "fuhgeddaboudit",   3},
        {"forget about it", "fuhgeddaboudit", 3},
        {"seriously",   "serious?",         3},
        {"you serious", "youse serious",    3},
        {"are you kidding", "youse kiddin'", 3},
        {"are you kidding me", "youse kiddin' me", 3},
        {"know what i mean", "know wadda mean", 3},
        {"you know",    "y'know",           3},
        {"over here",   "ovah heah",        3},
        {"over there",  "ovah dere",        3},
        {"coffee",      "cawfee",           3},
        {"water",       "watah",            3},
        {"talking",     "tawkin'",          3},
        {"talk",        "tawk",             3},
        {"walking",     "walkin'",          3},
        {"walk",        "wawk",             3},
    },
    Troll = {
        {"hi",          "ey mon",           1},
        {"hey",         "ey mon",           1},
        {"hello",       "ey mon",           1},
        {"yes",         "ya mon",           1},
        {"no",          "nah mon",          1},
        {"okay",        "aight mon",        1},
        {"ok",          "aight mon",        1},
        {"sure",        "ya mon",           1},
        {"friend",      "mon",              1},
        {"man",         "mon",              1},
        {"dude",        "mon",              1},
        {"the",         "da",               1},
        {"this",        "dis",              1},
        {"that",        "dat",              1},
        {"those",       "dose",             2},
        {"these",       "dese",             2},
        {"there",       "dere",             2},
        {"their",       "dere",             2},
        {"they",        "dey",              2},
        {"them",        "dem",              2},
        {"they're",     "dey be",           2},
        {"think",       "tink",             2},
        {"thinking",    "tinkin'",          2},
        {"thought",     "tought",           2},
        {"thing",       "ting",             2},
        {"things",      "tings",            2},
        {"with",        "wit'",             2},
        {"without",     "wit'out",          2},
        {"nothing",     "nuttin'",          2},
        {"something",   "sumtin'",          2},
        {"anything",    "anyting",          2},
        {"everything",  "everyting",        2},
        {"you",         "ya",               2},
        {"your",        "ya",               2},
        {"you're",      "ya be",            2},
        {"my",          "me",               2},
        {"three",       "tree",             2},
        {"through",     "tru",              2},
        {"throw",       "trow",             2},
        {"bye",         "later, mon",       3},
        {"goodbye",     "later, mon",       3},
        {"brother",     "brudda",           3},
        {"brothers",    "bruddas",          3},
        {"other",       "udda",             3},
        {"another",     "anudda",           3},
        {"mother",      "mudda",            3},
        {"father",      "fadda",            3},
        {"going",       "goin'",            3},
        {"coming",      "comin'",           3},
        {"doing",       "doin'",            3},
        {"having",      "havin'",           3},
        {"looking",     "lookin'",          3},
        {"getting",     "gettin'",          3},
        {"fighting",    "fightin'",         3},
        {"running",     "runnin'",          3},
        {"talking",     "talkin'",          3},
        {"is",          "be",               3},
        {"are",         "be",               3},
        {"am",          "be",               3},
        {"was",         "be",               3},
        {"were",        "be",               3},
        {"about",       "'bout",            3},
        {"little",      "likkle",           3},
        {"old",         "ol'",              3},
        {"over",        "ova",              3},
        {"ever",        "eva",              3},
        {"never",       "neva",             3},
        {"before",      "befo'",            3},
        {"you'll",      "ya gonna",         3},
        {"you've",      "ya",               3},
    },
}

-- Seed dialectSubstitutes from built-in tables on first load.
-- Only runs once per character (guarded by dialectSubstitutesSeedVersion).
-- After seeding, users own the data — they can remove, edit, or add rules freely.
local SEED_VERSION = 3  -- bump this to re-seed on future addon versions

function Speaketh_Dialects:SeedSubstitutes()
    if not Speaketh_Char then return end
    if (Speaketh_Char.dialectSubstitutesSeedVersion or 0) >= SEED_VERSION then return end

    if not Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes = {}
    end

    -- Always write all built-in entries for any dialect that has none yet,
    -- or whose table is empty (can happen if a prior seed run was interrupted).
    for dialectKey, entries in pairs(BUILTIN_SUBSTITUTES) do
        local existing = Speaketh_Char.dialectSubstitutes[dialectKey]
        if not existing or #existing == 0 then
            Speaketh_Char.dialectSubstitutes[dialectKey] = {}
            for _, e in ipairs(entries) do
                table.insert(Speaketh_Char.dialectSubstitutes[dialectKey], {e[1], e[2]})
            end
        end
    end

    Speaketh_Char.dialectSubstitutesSeedVersion = SEED_VERSION
end

-- ============================================================
-- Public API
-- ============================================================

function Speaketh_Dialects:GetAll()
    return DIALECTS, DIALECT_ORDER
end

function Speaketh_Dialects:GetActive()
    return Speaketh_Char and Speaketh_Char.dialect or nil
end

function Speaketh_Dialects:SetActive(key)
    if not Speaketh_Char then return end
    if key and not DIALECTS[key] then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Unknown dialect: " .. tostring(key))
        return
    end
    Speaketh_Char.dialect = key
    -- Initialize intensity level if not already stored.
    -- Drunk starts at 0 (sober); all others start at 3 (full).
    if key then
        if not Speaketh_Char.dialectLevels then
            Speaketh_Char.dialectLevels = {}
        end
        if not Speaketh_Char.dialectLevels[key] then
            Speaketh_Char.dialectLevels[key] = (key == "Drunk") and 0 or 3
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[Speaketh]|r Dialect set to |cff88ccff%s|r.", DIALECTS[key].name))
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Dialect cleared.")
    end
end

function Speaketh_Dialects:GetData(key)
    return DIALECTS[key or ""]
end

-- Per-dialect intensity level (0-3)
-- All dialects use a 0-3 slider. Stored level is used directly.
function Speaketh_Dialects:GetLevel(key)
    key = key or self:GetActive()
    if not key then return 0 end
    local d = DIALECTS[key]
    if d and d.usesSlider then
        -- Slider-driven: use stored level, default to 3 for non-Drunk, 0 for Drunk
        local stored = Speaketh_Char and Speaketh_Char.dialectLevels
                       and Speaketh_Char.dialectLevels[key]
        if stored then return stored end
        return (key == "Drunk") and 0 or 3
    else
        -- On/off dialects: always full intensity when active
        return 3
    end
end

function Speaketh_Dialects:SetLevel(key, level)
    if not Speaketh_Char then return end
    if not Speaketh_Char.dialectLevels then
        Speaketh_Char.dialectLevels = {}
    end
    Speaketh_Char.dialectLevels[key] = math.max(0, math.min(3, math.floor(level + 0.5)))
end

-- Back-compat for old drunkLevel
function Speaketh_Dialects:GetDrunkLevel()
    return self:GetLevel("Drunk")
end

function Speaketh_Dialects:SetDrunkLevel(level)
    self:SetLevel("Drunk", level)
end

-- Passthrough helper
local function GetPassthroughSet(langKey)
    if not langKey then return nil end
    local langData = Speaketh_Languages and Speaketh_Languages[langKey]
    if not langData or not langData.passthrough then return nil end
    return langData.passthrough
end

-- ============================================================
-- Apply dialect BEFORE translation
-- ============================================================
function Speaketh_Dialects:Apply(text, langKey)
    local key = self:GetActive()
    if not key then return text end
    local d = DIALECTS[key]
    if not d then return text end
    local original = text

    local level = self:GetLevel(key)
    if level == 0 then return text end

    -- Step 1: word substitutions (all rules live in Speaketh_Char.dialectSubstitutes)
    local custom = Speaketh_Dialects:GetCustomSubstitutes(key)
    if custom and #custom > 0 then
        local customSubs = {}
        for _, entry in ipairs(custom) do
            table.insert(customSubs, {entry[1], entry[2], 1})
        end
        text = ApplySubstitutes(text, customSubs, 1)
    end

    -- Step 2: slur/mangling
    if d.slur then
        local passthrough = GetPassthroughSet(langKey)
        if passthrough then
            local result = {}
            local pos = 1
            while pos <= #text do
                local ws, we = text:find("[%a'%-]+", pos)
                if ws then
                    if ws > pos then
                        table.insert(result, text:sub(pos, ws - 1))
                    end
                    local word = text:sub(ws, we)
                    if passthrough[word:lower()] then
                        if d.slurName then
                            table.insert(result, d.slurName(word, level))
                        else
                            table.insert(result, word)
                        end
                    else
                        table.insert(result, d.slur(word, level))
                    end
                    pos = we + 1
                else
                    table.insert(result, text:sub(pos))
                    break
                end
            end
            text = table.concat(result)
        else
            text = d.slur(text, level)
        end
    end

    -- Safety: never return empty text after dialect processing
    if not text or text == "" or not text:match("%S") then
        return original
    end

    return text
end

-- ============================================================
-- Apply post-translation interjections
-- ============================================================
function Speaketh_Dialects:ApplyInterjections(text)
    local key = self:GetActive()
    if not key then return text end
    local d = DIALECTS[key]
    if not d or not d.interjections then return text end

    local level = self:GetLevel(key)
    if level == 0 then return text end

    local intTable = d.interjections[level] or d.interjections[1]
    local chance   = (type(d.interjectionChance) == "table")
                     and (d.interjectionChance[level] or 10)
                     or (d.interjectionChance or 10)
    local endChance = (type(d.interjectionEndChance) == "table")
                      and (d.interjectionEndChance[level] or 0)
                      or (d.interjectionEndChance or 0)

    if not intTable or #intTable == 0 then return text end

    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local result = {}
    for i, word in ipairs(words) do
        table.insert(result, word)
        if i < #words and math.random(1,100) <= chance then
            table.insert(result, intTable[math.random(1, #intTable)])
        end
    end

    if endChance > 0 and math.random(1,100) <= endChance then
        table.insert(result, intTable[math.random(1, #intTable)])
    end

    return table.concat(result, " ")
end

-- ============================================================
-- Display helpers
-- ============================================================
function Speaketh_Dialects:GetDisplayLabel()
    local key = self:GetActive()
    if not key then return "None" end
    local d = DIALECTS[key]
    if not d then return "None" end
    -- Non-slider dialects (always full intensity): just show the name
    if not d.usesSlider then
        return d.name
    end
    local level = self:GetLevel(key)
    if d.sliderLabels and d.sliderLabels[level + 1] then
        return d.name .. ": " .. d.sliderLabels[level + 1]
    end
    return d.name .. ": " .. level
end

function Speaketh_Dialects:GetDisplayColor()
    local key = self:GetActive()
    if not key then return {0.5, 0.8, 0.5} end
    local d = DIALECTS[key]
    if not d then return {0.5, 0.8, 0.5} end
    -- Non-slider dialects: use their last color (full intensity)
    if not d.usesSlider then
        if d.sliderColors and d.sliderColors[4] then
            return d.sliderColors[4]
        end
        return {0.55, 0.75, 1.0}
    end
    local level = self:GetLevel(key)
    if d.sliderColors and d.sliderColors[level + 1] then
        return d.sliderColors[level + 1]
    end
    return {0.55, 0.75, 1.0}
end

function Speaketh_Dialects:GetSliderLabel(key, level)
    local d = DIALECTS[key]
    if d and d.sliderLabels and d.sliderLabels[level + 1] then
        return d.sliderLabels[level + 1]
    end
    return tostring(level)
end

-- ============================================================
-- Custom per-dialect word substitutions (user-defined, saved)
-- ============================================================

-- Return the list of custom substitutes for a dialect key.
-- Each entry is {from, to} (plain strings, case-insensitive matching).
function Speaketh_Dialects:GetCustomSubstitutes(dialectKey)
    if not dialectKey then return {} end
    local sv = Speaketh_Char and Speaketh_Char.dialectSubstitutes
    if not sv then return {} end
    return sv[dialectKey] or {}
end

-- Add a custom substitute. from/to are plain strings.
-- Returns true on success, or nil + errmsg on failure.
function Speaketh_Dialects:AddCustomSubstitute(dialectKey, from, to)
    if not dialectKey or not DIALECTS[dialectKey] then
        return nil, "Unknown dialect."
    end
    from = from and from:gsub("^%s+", ""):gsub("%s+$", "") or ""
    to   = to   and to:gsub("^%s+",  ""):gsub("%s+$",  "") or ""
    if from == "" then return nil, "Word/phrase cannot be empty." end
    if to   == "" then return nil, "Replacement cannot be empty." end
    if #from > 64 or #to > 64 then return nil, "Text too long (max 64 chars)." end

    if not Speaketh_Char then return nil, "Saved variables not ready." end
    if not Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes = {}
    end
    if not Speaketh_Char.dialectSubstitutes[dialectKey] then
        Speaketh_Char.dialectSubstitutes[dialectKey] = {}
    end

    -- Prevent duplicate 'from' entries (case-insensitive)
    local fromLower = from:lower()
    for _, entry in ipairs(Speaketh_Char.dialectSubstitutes[dialectKey]) do
        if entry[1]:lower() == fromLower then
            return nil, "A rule for \"" .. from .. "\" already exists. Remove it first."
        end
    end

    table.insert(Speaketh_Char.dialectSubstitutes[dialectKey], {from, to})
    return true
end

-- Remove a custom substitute by index within a dialect.
function Speaketh_Dialects:RemoveCustomSubstitute(dialectKey, index)
    local sv = Speaketh_Char and Speaketh_Char.dialectSubstitutes
    if not sv or not sv[dialectKey] then return end
    table.remove(sv[dialectKey], index)
end

-- ============================================================
-- Custom dialect management (user-created dialects)
-- ============================================================

-- Register a custom dialect into the live DIALECTS table.
-- Called both when the user creates one and on login to restore saved ones.
local function RegisterCustomDialect(key, name)
    if DIALECTS[key] then return end  -- already registered (built-in or duplicate)
    DIALECTS[key] = {
        name        = name,
        usesSlider  = false,
        substitutes = nil,
        slur        = nil,
        interjections = nil,
    }
    table.insert(DIALECT_ORDER, key)
end

-- Re-register all saved custom dialects from Speaketh_Char into the live table.
-- Called at PLAYER_LOGIN so they survive reloads.
function Speaketh_Dialects:SeedCustomDialects()
    if not Speaketh_Char or not Speaketh_Char.customDialects then return end
    for key, data in pairs(Speaketh_Char.customDialects) do
        RegisterCustomDialect(key, data.name)
    end
end

-- Create a brand new custom dialect. Returns true or nil+err.
function Speaketh_Dialects:AddCustomDialect(name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return nil, "Dialect name cannot be empty." end
    if #name > 32 then return nil, "Name too long (max 32 characters)." end

    -- Build a safe key from the name
    local key = "Custom_" .. name:gsub("%s+", "_"):gsub("[^%w_]", "")
    if key == "Custom_" then return nil, "Name must contain at least one letter or number." end

    if DIALECTS[key] then return nil, "A dialect named \"" .. name .. "\" already exists." end

    if not Speaketh_Char then return nil, "Saved variables not ready." end
    if not Speaketh_Char.customDialects then Speaketh_Char.customDialects = {} end
    if not Speaketh_Char.dialectSubstitutes then Speaketh_Char.dialectSubstitutes = {} end

    Speaketh_Char.customDialects[key] = { name = name }
    Speaketh_Char.dialectSubstitutes[key] = {}

    RegisterCustomDialect(key, name)
    return true, key
end

-- Remove a custom dialect entirely (data + live registration).
function Speaketh_Dialects:RemoveCustomDialect(key)
    if not Speaketh_Char then return end
    -- Can't remove built-in dialects
    if not (Speaketh_Char.customDialects and Speaketh_Char.customDialects[key]) then
        return nil, "Not a custom dialect."
    end
    -- If it's currently active, clear it
    if Speaketh_Char.dialect == key then
        Speaketh_Char.dialect = nil
    end
    Speaketh_Char.customDialects[key] = nil
    if Speaketh_Char.dialectSubstitutes then
        Speaketh_Char.dialectSubstitutes[key] = nil
    end
    DIALECTS[key] = nil
    for i, k in ipairs(DIALECT_ORDER) do
        if k == key then table.remove(DIALECT_ORDER, i); break end
    end
    return true
end

-- Returns true if a dialect key is user-created (not built-in).
function Speaketh_Dialects:IsCustomDialect(key)
    return Speaketh_Char
        and Speaketh_Char.customDialects
        and Speaketh_Char.customDialects[key] ~= nil
end
