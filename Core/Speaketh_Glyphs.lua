-- Speaketh_Glyphs.lua
-- Glyph system: renders spoken text as per-letter language glyph textures and
-- displays them in the overhead speech bubble.
--
-- Behaviour (when the glyph system is enabled):
--   * Speaketh users see the OVERHEAD chat bubble drawn as language glyphs
--     (one texture per A-Z letter of the ORIGINAL spoken text).
--   * The CHAT WINDOW keeps its normal behaviour: fully understood at 100%
--     fluency, blended/garbled below that (handled by Speaketh_ChatFilter).
--   * Players without the addon are unaffected: they never see glyphs, only
--     the normal scrambled text WoW already shows, exactly as before.
--
-- The textures shipped in Resources/Glyphs/<Language>/<Letter>.tga are
-- placeholders for a first test. WoW loads .blp and .tga textures only (never
-- .png). Paths below are written WITHOUT an extension so the game resolves
-- either format automatically: drop in .blp or .tga replacements with the same
-- names (A.tga / A.blp ...) and they are picked up with no code change.

Speaketh_Glyphs = {}

-- ============================================================
-- Texture location
-- ============================================================
local GLYPH_ROOT = "Interface\\AddOns\\Speaketh\\Resources\\Glyphs\\"

-- Some language keys contain characters that are not filesystem/texture-path
-- friendly (apostrophes, spaces). The texture folders were generated with
-- those stripped, so resolve to the same sanitised name here.
local function SanitiseLangFolder(langKey)
    if not langKey then return nil end
    return (langKey:gsub("'", ""):gsub("%s", ""))
end

-- Only languages in this table may render glyphs. More languages can be added
-- after their dedicated art folders ship.
local SHIPPED = {
    Common=true, Orcish=true, Furbolg=true, Pandaren=true,
    ["Shath'Yar"]=true, Taurahe=true, Vulpera=true, Zandali=true,
    Demonic=true, Thalassian=true, Darnassian=true,
    Draenei=true, Vrykul=true, ["Seth'rak"]=true, Dwarvish=true,
}

-- True only when a language ships a dedicated glyph folder. Used to decide
-- whether to override WoW-native scrambling for the overhead bubble.
function Speaketh_Glyphs:HasOwnGlyphs(langKey)
    if not langKey then return false end
    if SHIPPED[langKey] then return true end
    local data = Speaketh_Languages and Speaketh_Languages[langKey]
    if data and data.glyphSet and SHIPPED[data.glyphSet] then return true end
    return false
end

-- Resolve the glyph folder for a language key, honouring explicit aliases.
-- Unsupported languages return nil and keep their normal garbled bubble text.
function Speaketh_Glyphs:ResolveFolder(langKey)
    if not langKey or langKey == "None" then return nil end

    if SHIPPED[langKey] then
        return SanitiseLangFolder(langKey)
    end

    -- Alias resolution: a custom or aliased language may point at a built-in
    -- via its language-data table. If the data has a "glyphSet" hint, use it.
    local data = Speaketh_Languages and Speaketh_Languages[langKey]
    if data and data.glyphSet and SHIPPED[data.glyphSet] then
        return SanitiseLangFolder(data.glyphSet)
    end

    return nil
end

-- Returns the full texture path for a single letter in a language, or nil if
-- the character is not an A-Z letter (callers keep the raw char instead).
function Speaketh_Glyphs:GetTexturePath(langKey, char)
    local folder = self:ResolveFolder(langKey)
    if not folder then return nil end
    local upper = char:upper()
    if upper:match("^[A-Z]$") then
        return GLYPH_ROOT .. folder .. "\\" .. upper
    end
    return nil
end

-- ============================================================
-- Text -> glyph string
-- ============================================================
-- Converts plain text into an inline-texture string. Each A-Z letter becomes a
-- |T...|t glyph texture; every other character (spaces, punctuation, digits)
-- is preserved verbatim so word spacing and sentence shape are readable.
--
-- size: glyph edge length in pixels. Defaults to a chat-bubble-friendly value.
function Speaketh_Glyphs:BuildGlyphString(text, langKey, size)
    if not text or text == "" then return text end
    local folder = self:ResolveFolder(langKey)
    if not folder then return text end

    size = size or (Speaketh_Char and Speaketh_Char.glyphSize) or 18
    -- Slight per-glyph padding so adjacent runes don't collide.
    local edge = size

    local out = {}
    -- Iterate by UTF-8-agnostic bytes is fine here: we only special-case ASCII
    -- A-Z; multibyte characters simply pass through as their raw bytes, which
    -- is acceptable for placeholder rendering.
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch:match("[A-Za-z]") then
            local path = GLYPH_ROOT .. folder .. "\\" .. ch:upper()
            -- |Tpath:height:width|t  (0 width = square from height)
            out[#out + 1] = string.format("|T%s:%d:%d|t", path, edge, edge)
        else
            out[#out + 1] = ch
        end
    end
    return table.concat(out)
end

-- Some language vocabularies deliberately expand one source word into a
-- multi-word phrase. Pandaren is the clearest example: a two-letter word can
-- become "om nom", which contains five letters. If the hidden original-text
-- payload is unavailable, the incoming chat path only has that expanded
-- translation. Rendering it directly creates far more glyphs than the speaker
-- typed.
--
-- Recover the intended source length from the language's word-bucket key. A
-- bucket numbered N represents an N-letter source word. This is generic and
-- therefore also covers Gilnean and any future expanding vocabulary. We keep
-- the first N letters of the translated phrase only as a deterministic glyph
-- choice; the important invariant is one glyph per original source letter.
local function CollapseExpandedTranslations(text, langKey)
    local data = Speaketh_Languages and Speaketh_Languages[langKey]
    if not data or not text or text == "" then return text end

    local expansions = {}
    local function AddExpansion(phrase, sourceLen)
        if type(phrase) ~= "string" or type(sourceLen) ~= "number" then return end
        local _, letterCount = phrase:gsub("[%a]", "")
        if letterCount > sourceLen then
            expansions[#expansions + 1] = {
                lower = phrase:lower(),
                bytes = #phrase,
                sourceLen = sourceLen,
            }
        end
    end
    if type(data.words) == "table" then
        for sourceLen, entries in pairs(data.words) do
            if type(sourceLen) == "number" and type(entries) == "table" then
                for _, phrase in ipairs(entries) do
                    AddExpansion(phrase, sourceLen)
                end
            end
        end
    end
    -- Gilnean-style direct substitutions can expand phrases before the normal
    -- word hashing pass, so include those reverse-length mappings as well.
    if type(data.substitute) == "table" then
        for original, replacement in pairs(data.substitute) do
            if type(original) == "string" then
                local _, sourceLen = original:gsub("[%a]", "")
                AddExpansion(replacement, sourceLen)
            end
        end
    end
    if #expansions == 0 then return text end

    -- Prefer the longest phrase when vocabulary entries overlap.
    table.sort(expansions, function(a, b) return a.bytes > b.bytes end)

    local lower = text:lower()
    local out = {}
    local pos = 1
    while pos <= #text do
        local matched
        local previous = pos > 1 and text:sub(pos - 1, pos - 1) or ""
        local startsAtBoundary = previous == "" or not previous:match("[%a'%-]")
        if startsAtBoundary then
            for _, entry in ipairs(expansions) do
                local last = pos + entry.bytes - 1
                local following = last < #text and text:sub(last + 1, last + 1) or ""
                if lower:sub(pos, last) == entry.lower
                   and (following == "" or not following:match("[%a'%-]")) then
                    matched = entry
                    break
                end
            end
        end

        if matched then
            local phrase = text:sub(pos, pos + matched.bytes - 1)
            local letters = {}
            for ch in phrase:gmatch("[%a]") do
                letters[#letters + 1] = ch
                if #letters == matched.sourceLen then break end
            end
            while #letters < matched.sourceLen do
                letters[#letters + 1] = "a"
            end
            out[#out + 1] = table.concat(letters)
            pos = pos + matched.bytes
        else
            out[#out + 1] = text:sub(pos, pos)
            pos = pos + 1
        end
    end
    return table.concat(out)
end

-- True only when the user has explicitly switched on the optional glyph system.
function Speaketh_Glyphs:IsEnabled()
    if not (Speaketh and Speaketh.IsEnabled and Speaketh:IsEnabled()) then
        return false
    end
    return Speaketh_Char and Speaketh_Char.showGlyphs == true or false
end

-- ============================================================
-- Overhead speech bubble integration
-- ============================================================
-- WoW renders overhead speech as chat bubbles parented under WorldFrame. The
-- modern, taint-safe way to reach them is C_ChatBubbles.GetAllChatBubbles(),
-- which returns the active bubble frames. Each bubble contains a FontString we
-- can rewrite. We only ever change the *display* text of a bubble that matches
-- a message a Speaketh user just spoke, so non-addon chat is never touched.
--
-- Chat bubbles are unavailable inside instanced content (Blizzard restriction),
-- mirroring the reference Languages addon; there we simply do nothing and the
-- normal scrambled text shows.

local _pendingBubbles = {}  -- FIFO of {plain=, glyph=, expires=}

-- Find the FontString inside a chat-bubble frame.
local function GetBubbleFontString(bubble)
    if not bubble then return nil end
    -- Retail wraps the text in bubble.String; older/other paths expose it via
    -- regions. Try the documented field first, then scan regions.
    if bubble.String and bubble.String.GetText then
        return bubble.String
    end
    local ok, regions = pcall(function() return { bubble:GetRegions() } end)
    if ok and regions then
        for _, r in ipairs(regions) do
            if r and r.GetText and r.SetText then
                return r
            end
        end
    end
    -- Some skins nest the fontstring one child deep.
    local ok2, children = pcall(function() return { bubble:GetChildren() } end)
    if ok2 and children then
        for _, c in ipairs(children) do
            local fs = GetBubbleFontString(c)
            if fs then return fs end
        end
    end
    return nil
end

-- Scan currently-visible bubbles for one whose text matches a queued message
-- and swap it to glyphs. Called for a few frames after a message is seen,
-- because the bubble appears one or more frames after the CHAT_MSG event.
local function TryDecorateBubbles()
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    if #_pendingBubbles == 0 then return end

    local now = GetTime()
    -- Drop expired requests.
    for i = #_pendingBubbles, 1, -1 do
        if now > _pendingBubbles[i].expires then
            table.remove(_pendingBubbles, i)
        end
    end
    if #_pendingBubbles == 0 then return end

    local bubbles = C_ChatBubbles.GetAllChatBubbles()
    if not bubbles then return end

    for _, bubble in ipairs(bubbles) do
        local fs = GetBubbleFontString(bubble)
        if fs then
            local current = fs:GetText()
            if current and current ~= "" then
                for i = #_pendingBubbles, 1, -1 do
                    local req = _pendingBubbles[i]
                    -- Match on the plain (as-sent, garbled) text that WoW put
                    -- in the bubble, and only if we haven't already converted
                    -- it (glyph strings contain the |T escape).
                    if current == req.plain and not current:find("|T", 1, true) then
                        fs:SetText(req.glyph)
                        -- Widen the bubble a touch so square glyphs fit; WoW
                        -- auto-sizes to the fontstring, so just nudge width.
                        table.remove(_pendingBubbles, i)
                        break
                    end
                end
            end
        end
    end
end

-- Driver frame: polls for a short window after each queued message.
local _driver = CreateFrame("Frame")
local _pollUntil = 0
_driver:Hide()
_driver:SetScript("OnUpdate", function(self, elapsed)
    self._acc = (self._acc or 0) + elapsed
    if self._acc < 0.05 then return end   -- ~20 checks/sec is plenty
    self._acc = 0
    TryDecorateBubbles()
    if GetTime() > _pollUntil or #_pendingBubbles == 0 then
        self:Hide()
    end
end)

-- Public: queue a spoken message for bubble glyph conversion.
--   plainText : the exact text WoW will show in the bubble (garbled, as sent)
--   glyphSource: the text whose LETTERS drive the glyphs (the original words)
--   langKey    : language whose glyph set to use
--   sourceIsTranslated: true only when glyphSource is a translated fallback
function Speaketh_Glyphs:QueueBubble(plainText, glyphSource, langKey, sourceIsTranslated)
    if not self:IsEnabled() then return end
    if not plainText or plainText == "" then return end
    if not langKey or langKey == "None" then return end
    -- The global checkbox never opts unsupported languages into Common art.
    -- They must keep the garbled text until a dedicated set is shipped.
    if not self:ResolveFolder(langKey) then return end

    local source = glyphSource or plainText
    if sourceIsTranslated then
        source = CollapseExpandedTranslations(source, langKey)
    end
    local glyph = self:BuildGlyphString(source, langKey)
    if not glyph or glyph == plainText then return end

    _pendingBubbles[#_pendingBubbles + 1] = {
        plain   = plainText,
        glyph   = glyph,
        expires = GetTime() + 3,   -- bubbles usually appear within a frame or two
    }
    _pollUntil = GetTime() + 3
    _driver:Show()
end
