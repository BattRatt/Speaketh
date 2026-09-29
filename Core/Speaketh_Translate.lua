-- Speaketh_Translate.lua
-- Core translation engine. Uses djb2 hash for most languages,
-- and the authentic SStrHash algorithm for Shath'Yar.

Speaketh_Translate = {}

-- djb2-style hash (used by all non-Shath'Yar languages)
-- Uses modulo arithmetic at each step to prevent Lua 5.1 integer overflow,
-- which would produce negative hash values and nil bucket lookups.
local HASH_MOD = 0x7FFFFFFF  -- keep within positive 32-bit range
local function Hash(text)
    text = string.lower(text)
    local h = 5381
    local primes = {5347,5351,5381,5387,5393,5399,5407,5413,5417,5419,
                    5431,5437,5441,5443,5449}
    for i = 1, #text do
        local v = string.byte(text, i)
        local p = primes[(v % #primes) + 1]
        h = ((h * p) + v) % HASH_MOD
    end
    return h
end

-- Match capitalisation of original word onto translated word
local function MatchCase(original, translated)
    if original == string.upper(original) then
        return string.upper(translated)
    elseif string.sub(original, 1, 1) == string.upper(string.sub(original, 1, 1)) then
        return string.upper(string.sub(translated, 1, 1)) .. string.sub(translated, 2)
    else
        return string.lower(translated)
    end
end

-- Translate a single word using the correct hash for the language
local function TranslateWord(word, langKey)
    local langData = Speaketh_Languages[langKey]
    if not langData then return word end

    -- Check for user-defined custom passthrough words. These come from the
    -- "Custom Words" section of the options panel and apply to every
    -- language. A word here always passes through unchanged (no hashing,
    -- no substitution). This lets users keep character names, in-game
    -- terms, or inside-jokes like "Linkie" readable across any language.
    if Speaketh_Char and Speaketh_Char.customWords then
        if Speaketh_Char.customWords[string.lower(word)] then
            return word
        end
    end

    -- Check for language-defined passthrough words (names, proper nouns kept as-is)
    if langData.passthrough and langData.passthrough[string.lower(word)] then
        return word
    end

    -- Preserve well-known deterministic outputs from WoW's own language
    -- parser. These are explicit because Speaketh's portable hash is not the
    -- same implementation used by the game client.
    local fixed = langData.fixed and langData.fixed[string.lower(word)]
    if fixed then
        return MatchCase(word, fixed)
    end

    local wordTable = langData.words
    local len = #word

    -- useRandom: flatten all buckets into one pool and pick randomly,
    -- ignoring word length entirely. Every word gets a truly random
    -- replacement from the full vocabulary each time it is translated.
    if langData.useRandom then
        local pool = {}
        for _, bucket in pairs(wordTable) do
            for _, w in ipairs(bucket) do
                table.insert(pool, w)
            end
        end
        if #pool == 0 then return word end
        local result = pool[math.random(#pool)]
        -- Avoid returning the source word unchanged
        if result:lower() == word:lower() and #pool > 1 then
            result = pool[(math.random(#pool - 1) % #pool) + 1]
            if result:lower() == word:lower() then
                -- Fallback: linear scan for any non-matching word
                for _, w in ipairs(pool) do
                    if w:lower() ~= word:lower() then result = w; break end
                end
            end
        end
        return MatchCase(word, result)
    end

    -- Find closest available bucket
    local maxLen = 0
    for k in pairs(wordTable) do
        if k > maxLen then maxLen = k end
    end
    local bucket = math.min(len, maxLen)
    while bucket > 0 and not wordTable[bucket] do
        bucket = bucket - 1
    end
    if bucket == 0 then return word end

    local entries = wordTable[bucket]
    local h

    -- Shath'Yar uses the authentic Blizzard SStrHash
    if langData.useShathYarHash then
        h = Speaketh_SStrHash(word)
    else
        h = Hash(word)
    end

    local idx = (h % #entries) + 1
    local result = entries[idx]

    -- If the hash happens to pick the source word itself out of the bucket
    -- (e.g. Common bucket[1] contains vowels and "a" hashes back to "a"),
    -- advance one slot in the bucket so the word is never left untranslated.
    -- One step is always enough because no two consecutive entries in any
    -- bucket are the same word, and the bucket always has at least one entry
    -- that differs from the source word (verified across all built-in languages).
    if result:lower() == word:lower() then
        idx = (idx % #entries) + 1
        result = entries[idx]
    end

    return MatchCase(word, result)
end

-- ============================================================
-- Stutter-aware word translation
-- ============================================================
-- A stuttered word such as "Y-You", "H-H-Hello" or "Wh-What" is one token to
-- the word pattern, so it used to be hashed as a single unrelated word and the
-- stutter vanished from the translated speech. Split off the repeated
-- prefixes, translate the base word exactly as it would be translated on its
-- own, then rebuild the stutter from the translated word's first letters:
--     "Y-You"   -> "T-Turusal"
--     "H-H-Hi"  -> "K-K-Kek"
-- Only prefixes that really repeat the start of the word count, so ordinary
-- hyphenated words ("well-known", "half-elf") are unaffected.
local function SplitStutter(word)
    local prefixes = {}
    local rest = word
    while true do
        local p, r = rest:match("^(%a%a?%a?)%-(.+)$")
        if not p or r:sub(1, #p):lower() ~= p:lower() then break end
        prefixes[#prefixes + 1] = p
        rest = r
    end
    if #prefixes == 0 or not rest:match("^%a") then return nil end
    return prefixes, rest
end

local function TranslateWordWithStutter(word, langKey)
    local prefixes, base = SplitStutter(word)
    if not prefixes then
        return TranslateWord(word, langKey)
    end
    local translated = TranslateWord(base, langKey)
    local lead = translated:match("^%a+") or ""
    if lead == "" then return translated end
    local out = {}
    for _, p in ipairs(prefixes) do
        local n = math.min(#p, #lead)
        out[#out + 1] = MatchCase(p, lead:sub(1, n)) .. "-"
    end
    -- The first letter of the translated word follows the stutter's casing.
    local first = translated:sub(1, 1)
    local firstPrefix = prefixes[1]
    if firstPrefix:sub(1, 1) == firstPrefix:sub(1, 1):upper() then
        first = first:upper()
    else
        first = first:lower()
    end
    return table.concat(out) .. first .. translated:sub(2)
end

-- ============================================================
-- UI escape-sequence protection
-- ============================================================
-- Chat text can carry WoW UI escape sequences that must reach the server
-- byte-for-byte: hyperlinks (items, spells, quests, achievements...), color
-- codes, textures/atlases, Battle.net name tokens and raid-target markers.
-- The word patterns used by translation, dialects and effects would otherwise
-- treat the letters inside them ("cffff0000", "Hitem", "r", "skull") as words
-- and rewrite them, which corrupts or invalidates the link.
--
-- Since patch 11.1.5 item links use the "|cnIQ4:" quality-color form rather
-- than "|cffRRGGBB", so both color forms are recognised here.
--
-- Protected spans are replaced by a sentinel (sentinelByte .. N .. sentinelByte)
-- that contains no letters, so every word-based pass leaves it alone.
local ESCAPE_PATTERNS = {
    "^|c%x%x%x%x%x%x%x%x",   -- legacy color:  |cffRRGGBB
    "^|cn[^:|]*:",           -- modern color:  |cnIQ4:  |cnWHITE_FONT_COLOR:
    "^|r",                   -- color reset
    "^|H.-|h.-|h",           -- hyperlink:     |H<data>|h[<text>]|h
    "^|T.-|t",               -- texture
    "^|A.-|a",               -- atlas
    "^|K.-|k",               -- Battle.net protected name
    "^||",                   -- escaped pipe
}

local function MatchEscapeAt(text, pos)
    local ch = text:sub(pos, pos)
    if ch == "|" then
        for _, pat in ipairs(ESCAPE_PATTERNS) do
            local s, e = text:find(pat, pos)
            if s then return e end
        end
    elseif ch == "{" then
        -- Raid target markers such as {rt1}, {star}, {skull}. Only short,
        -- purely alphanumeric brace groups are protected.
        local s, e = text:find("^{%w+}", pos)
        if s and (e - s) <= 12 then return e end
    end
    return nil
end

-- Returns text with escape spans replaced by sentinels, plus the token list.
-- Adjacent escapes (e.g. color + link + reset) collapse into one token so a
-- whole colored link is always restored as a single unit.
function Speaketh_Translate:ProtectEscapes(text, sentinel)
    sentinel = sentinel or "\3"
    local tokens = {}
    if type(text) ~= "string" or (not text:find("|", 1, true) and not text:find("{", 1, true)) then
        return text, tokens
    end
    local out = {}
    local pos, n = 1, 0
    local lastWasToken = false
    local plainStart = 1
    while pos <= #text do
        local e = MatchEscapeAt(text, pos)
        if e then
            if plainStart < pos then
                out[#out + 1] = text:sub(plainStart, pos - 1)
                lastWasToken = false
            end
            local span = text:sub(pos, e)
            if lastWasToken then
                tokens[n] = tokens[n] .. span
            else
                n = n + 1
                tokens[n] = span
                out[#out + 1] = sentinel .. n .. sentinel
                lastWasToken = true
            end
            pos = e + 1
            plainStart = pos
        else
            pos = pos + 1
        end
    end
    if plainStart <= #text then
        out[#out + 1] = text:sub(plainStart)
    end
    return table.concat(out), tokens
end

function Speaketh_Translate:RestoreEscapes(text, tokens, sentinel)
    if not tokens or not next(tokens) or type(text) ~= "string" then return text end
    sentinel = sentinel or "\3"
    return (text:gsub(sentinel .. "(%d+)" .. sentinel, function(idx)
        return tokens[tonumber(idx)] or ""
    end))
end

-- Translate a full message, preserving links, color codes, textures and raid
-- markers untouched. Uses its own sentinel byte (\4) so it can be nested
-- safely inside callers that already protected escapes with \3.
function Speaketh_Translate:Message(msg, langKey)
    if not langKey or not Speaketh_Languages[langKey] then return msg end
    if type(msg) ~= "string" or msg == "" then return msg end

    local protected, tokens = self:ProtectEscapes(msg, "\4")
    local translated = self:Segment(protected, langKey)
    return self:RestoreEscapes(translated, tokens, "\4")
end

-- Translate a plain text segment word-by-word, preserving spaces and punctuation
function Speaketh_Translate:Segment(text, langKey)
    local langData = Speaketh_Languages[langKey]

    -- Gilnean CodeSpeak: substitute phrases first, then ignore/hash remaining words
    if langData and langData.useGilneanCodeSpeak then
        return self:GilneanSegment(text, langKey)
    end

    return (string.gsub(text, "([%a'%-]+)", function(word)
        return TranslateWordWithStutter(word, langKey)
    end))
end

-- Gilnean CodeSpeak translation: matches Tongues addon behavior
-- 1) Apply multi-word and single-word substitutes (longest first)
-- 2) Words on the ignore list pass through unchanged
-- 3) Remaining words get hashed into phrase buckets (which may be multi-word)
--
-- Substituted spans are tracked and excluded from step 2 hashing - otherwise
-- a substitute like "hello" -> "'ello" would immediately have its "ello"
-- re-hashed in step 2 and turn into gibberish.
function Speaketh_Translate:GilneanSegment(text, langKey)
    local langData = Speaketh_Languages[langKey]
    if not langData then return text end

    local subs   = langData.substitute or {}
    local ignore = langData.ignore or {}

    -- Build sorted substitutes list (longest original phrase first)
    local sortedSubs = {}
    for k, v in pairs(subs) do
        table.insert(sortedSubs, {orig = k, repl = v})
    end
    table.sort(sortedSubs, function(a, b) return #a.orig > #b.orig end)

    -- We represent the in-progress text as a sequence of segments:
    --   {text = "...",  literal = true}   -- don't touch this in step 2
    --   {text = "...",  literal = false}  -- open to further substitution / hashing
    -- Initially the whole input is one non-literal segment.
    local segments = { {text = text, literal = false} }

    -- Helper: apply one substitute to every non-literal segment. Each match
    -- splits that segment into: before (non-literal), replacement (literal),
    -- after (non-literal). Later subs only see the non-literal parts.
    local function applySub(entry)
        local searchLower = entry.orig:lower()
        local new = {}
        for _, seg in ipairs(segments) do
            if seg.literal or seg.text == "" then
                table.insert(new, seg)
            else
                local src = seg.text
                local lower = src:lower()
                local pos = 1
                while pos <= #src do
                    local s, e = lower:find(searchLower, pos, true)
                    if not s then
                        -- no more matches; push the remainder as non-literal
                        table.insert(new, {text = src:sub(pos), literal = false})
                        break
                    end
                    local before = (s == 1) or not src:sub(s - 1, s - 1):match("[%a']")
                    local after  = (e == #src) or not src:sub(e + 1, e + 1):match("[%a']")
                    if before and after then
                        if s > pos then
                            table.insert(new, {text = src:sub(pos, s - 1), literal = false})
                        end
                        table.insert(new, {
                            text    = MatchCase(src:sub(s, e), entry.repl),
                            literal = true,
                        })
                        pos = e + 1
                    else
                        -- partial word boundary mismatch; keep walking without
                        -- consuming more than one character at a time
                        table.insert(new, {text = src:sub(pos, s), literal = false})
                        pos = s + 1
                    end
                end
            end
        end
        segments = new
    end

    -- Step 1: apply substitutes (longest phrase first)
    for _, entry in ipairs(sortedSubs) do
        applySub(entry)
    end

    -- Step 2: for every non-literal segment, ignore-list words pass through
    -- and everything else gets hashed into phrase buckets.
    for i, seg in ipairs(segments) do
        if not seg.literal then
            seg.text = seg.text:gsub("([%a'%-]+)", function(word)
                if ignore[word:lower()] then
                    return word
                end
                return TranslateWordWithStutter(word, langKey)
            end)
        end
    end

    -- Concatenate everything back into a single string.
    local out = {}
    for _, seg in ipairs(segments) do
        table.insert(out, seg.text)
    end
    return table.concat(out)
end

