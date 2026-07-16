-- Speaketh.lua
-- Main addon file: initialisation, chat hook, event handling, slash commands.

-- ============================================================
-- Core object
-- ============================================================
Speaketh = {}

-- Default saved-variable structure
local DEFAULTS = {
    language       = "None",
    fluency        = {},
    minimapAngle   = 200,
    splashSeen     = false,
    drunkLevel     = 0,
    dialect        = nil,
    dialectLevels  = {},
    effect         = nil,
    effectLevels   = {},
    autoChat       = true,
    passiveLearn   = true,    -- gain fluency passively from hearing speech
    showMinimap    = true,    -- show minimap button
    showLangHUD    = true,    -- show floating language HUD
    showGlyphs     = false,   -- optional: render overhead speech bubbles as language glyphs
    glyphSize      = 18,      -- glyph edge size (pixels) in speech bubbles
    hudPos         = nil,     -- saved position of the HUD; nil = default
    customWords    = {},      -- user-defined words that pass through untranslated
    dialectSubstitutes = {}, -- user-defined per-dialect word replacements: [dialectKey] = {{from,to}, ...}
    dialectSubstitutesSeedVersion = 0, -- tracks whether built-in rules have been seeded
    customDialects = {},     -- user-created dialects: [key] = {name=string}
    customLanguages = {},    -- user-created languages: [key] = {name=string, words={...}}
    showSplash           = false,   -- show splash on every login (first login only when false)
    showLockdownNotify   = false,   -- print a chat message when combat lockdown disables translation
    theme                = "Classic",  -- UI theme: "Classic" (gold) or "Void" (purple)
    enableOOB      = true,    -- join hidden cross-player channel so non-grouped Speaketh users can decode each other's SAY/YELL
    -- Per-channel translation toggles (all on by default)
    chanSay          = true,
    chanYell         = true,
    chanParty        = true,
    chanRaid         = true,
    chanGuild        = true,
    chanOfficer      = true,
    chanInstance     = true,
    chanWhisper      = true,
    chanEmote        = true,
}

-- Chat types Speaketh will translate on send
local TRANSLATE_ON_SEND = {
    SAY=true, YELL=true, PARTY=true, PARTY_LEADER=true,
    GUILD=true, OFFICER=true, RAID=true, RAID_WARNING=true,
    INSTANCE_CHAT=true, WHISPER=true, EMOTE=true,
}

-- Chat types where dialect applies only to quoted text
local DIALECT_QUOTES_ONLY = {
    EMOTE=true,
}

-- In spoken chat, paired asterisks conventionally mark a physical action.
-- Protect those spans from both dialect and language processing.
local PROTECT_ASTERISK_ACTIONS = {
    SAY=true,
    YELL=true,
}

-- Maps chat types to their per-channel saved-variable toggle key.
-- Shared between Speaketh_ProcessOutgoing and the splitter API.
local CHAN_KEY_MAP = {
    SAY            = "chanSay",
    YELL           = "chanYell",
    PARTY          = "chanParty",
    PARTY_LEADER   = "chanParty",
    RAID           = "chanRaid",
    RAID_WARNING   = "chanRaid",
    GUILD          = "chanGuild",
    OFFICER        = "chanOfficer",
    INSTANCE_CHAT  = "chanInstance",
    WHISPER        = "chanWhisper",
    EMOTE          = "chanEmote",
}

-- Set true by an external chat-splitting addon (e.g. EmoteScribe) while it
-- is handling the outgoing send. Prevents Speaketh's own editbox hook from
-- double-translating text the splitter has already processed.
Speaketh.splitterBypassing = false

-- Public capability check for splitters that ship and own their Speaketh
-- integration. EmoteScribe 1.1.8 exposes Enscriber.GetVersion publicly and
-- includes a per-chunk Speaketh module. Do not depend on LibEnscriber.Internal:
-- that table is explicitly private and may change without notice.
function Speaketh:IsExternalSplitterOwner()
    if not C_AddOns or not C_AddOns.IsAddOnLoaded
       or not C_AddOns.IsAddOnLoaded("EmoteScribe") then
        return false
    end
    if not LibEnscriber or type(LibEnscriber.GetVersion) ~= "function" then
        return false
    end
    local ok, version = pcall(LibEnscriber.GetVersion)
    return ok and tonumber(version) and tonumber(version) >= 1
       and type(self.TranslateChunk) == "function"
end

-- ============================================================
-- OOC (out-of-character) bracket protection
-- ============================================================
-- Text inside parentheses ( ... ) is OOC by convention in WoW RP and must
-- never be touched by dialect slurring, accent substitutions, or language
-- translation.  We handle this with a strip/restore pair:
--
--   StripOOC(text)    -> stripped text, token table
--   RestoreOOC(text, tokens) -> original OOC spans put back in place
--
-- Each OOC span is replaced with a unique ASCII sentinel of the form
--   \1N\1   (SOH + decimal index + SOH)
-- which cannot appear in normal user text and is invisible to all the
-- regex patterns used by the translation and dialect engines.
--
-- Parentheses may be nested. If an opening parenthesis has no matching close,
-- the remainder of the message is treated as one OOC span (safe default).

local function StripOOC(text)
    local tokens = {}
    local result = {}
    local pos = 1
    local n = 0
    while pos <= #text do
        local oStart = text:find("%(", pos)
        if not oStart then
            table.insert(result, text:sub(pos))
            break
        end
        -- Append everything before the opening paren as-is
        if oStart > pos then
            table.insert(result, text:sub(pos, oStart - 1))
        end
        -- Find the matching closing parenthesis while respecting nesting.
        local depth = 1
        local cursor = oStart + 1
        local oEnd
        while cursor <= #text do
            local ch = text:sub(cursor, cursor)
            if ch == "(" then
                depth = depth + 1
            elseif ch == ")" then
                depth = depth - 1
                if depth == 0 then
                    oEnd = cursor
                    break
                end
            end
            cursor = cursor + 1
        end
        local span
        if oEnd then
            span = text:sub(oStart, oEnd)   -- includes both parens
            pos = oEnd + 1
        else
            -- Unclosed paren: protect to end of string
            span = text:sub(oStart)
            pos = #text + 1
        end
        n = n + 1
        tokens[n] = span
        table.insert(result, "\1" .. n .. "\1")
    end
    return table.concat(result), tokens
end

local function RestoreOOC(text, tokens)
    if not tokens or not next(tokens) then return text end
    -- Replace each sentinel with the original OOC span
    return (text:gsub("\1(%d+)\1", function(idx)
        return tokens[tonumber(idx)] or ""
    end))
end

-- Protect paired *action text* spans used inside SAY/YELL. A distinct sentinel
-- byte keeps these tokens independent from the parenthetical OOC tokens above.
-- An unmatched opening asterisk protects the remainder as a safe default.
local function StripAsteriskActions(text)
    local tokens = {}
    local result = {}
    local pos = 1
    local n = 0
    while pos <= #text do
        local aStart = text:find("*", pos, true)
        if not aStart then
            table.insert(result, text:sub(pos))
            break
        end
        if aStart > pos then
            table.insert(result, text:sub(pos, aStart - 1))
        end
        local aEnd = text:find("*", aStart + 1, true)
        local span
        if aEnd then
            span = text:sub(aStart, aEnd)
            pos = aEnd + 1
        else
            span = text:sub(aStart)
            pos = #text + 1
        end
        n = n + 1
        tokens[n] = span
        table.insert(result, "\2" .. n .. "\2")
    end
    return table.concat(result), tokens
end

local function RestoreAsteriskActions(text, tokens)
    if not tokens or not next(tokens) then return text end
    return (text:gsub("\2(%d+)\2", function(idx)
        return tokens[tonumber(idx)] or ""
    end))
end

local function RestoreProtectedText(text, actionTokens, oocTokens)
    text = RestoreAsteriskActions(text, actionTokens)
    return RestoreOOC(text, oocTokens)
end

-- Apply random dialect interjections only to unprotected speech segments.
-- Without this, a placeholder representing `(OOC text)` or `*an action*`
-- could be treated as a word and receive a hiccup or similar interjection.
local function ApplyInterjectionsToSpeech(text, langKey)
    if not Speaketh_Dialects or not Speaketh_Dialects.ApplyInterjections then
        return text
    end

    local result = {}
    local pos = 1
    while pos <= #text do
        local s, e = text:find("([\1\2])(%d+)%1", pos)
        local speechEnd = s and (s - 1) or #text
        local speech = text:sub(pos, speechEnd)
        if speech:match("%a") then
            speech = Speaketh_Dialects:ApplyInterjections(speech, langKey)
        end
        table.insert(result, speech)

        if not s then break end
        table.insert(result, text:sub(s, e))
        pos = e + 1
    end
    return table.concat(result)
end

-- ============================================================
-- Language management
-- ============================================================
function Speaketh:GetLanguage()
    return (Speaketh_Char and Speaketh_Char.language) or "None"
end

-- Returns a clean display name for a language key.
-- For custom languages this strips the internal key prefix and uses the
-- human-readable name stored in Speaketh_Languages[key].name instead.
function Speaketh:GetLanguageDisplayName(key)
    if not key or key == "None" then return "None" end
    local data = Speaketh_Languages and Speaketh_Languages[key]
    if data and data.name then return data.name end
    return key  -- built-in languages: key is already the display name
end

function Speaketh:SetLanguage(key)
    if key == "None" then
        Speaketh_Char.language = "None"
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Now speaking |cff88ccffNone|r  (no translation - dialects only)")
        if Speaketh_UI and Speaketh_UI.Button then
            Speaketh_UI:UpdateTooltip()
        end
        if Speaketh_UI and Speaketh_UI.RefreshLanguageHUD then
            Speaketh_UI:RefreshLanguageHUD()
        end
        return
    end
    if not Speaketh_Languages[key] then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Unknown language: " .. tostring(key))
        return
    end
    Speaketh_Char.language = key

    local fluency = Speaketh_Fluency:Get(key)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cffffcc00[Speaketh]|r Now speaking |cff88ccff%s|r  (fluency: %d%%)",
        Speaketh:GetLanguageDisplayName(key), math.floor(fluency)))

    -- Update minimap button tooltip if visible
    if Speaketh_UI and Speaketh_UI.Button then
        Speaketh_UI:UpdateTooltip()
    end
    -- Update the floating language HUD if present
    if Speaketh_UI and Speaketh_UI.RefreshLanguageHUD then
        Speaketh_UI:RefreshLanguageHUD()
    end
end

function Speaketh:CycleLanguage()
    local current = self:GetLanguage()
    local known   = {"None"}  -- None is always first in cycle
    for _, key in ipairs(Speaketh_LanguageOrder) do
        if Speaketh_Fluency:Get(key) > 0 then
            table.insert(known, key)
        end
    end
    if #known == 0 then return end

    local idx = 1
    for i, key in ipairs(known) do
        if key == current then idx = i; break end
    end
    self:SetLanguage(known[(idx % #known) + 1])
end

-- ============================================================
-- Outgoing translation
-- ============================================================

local SPEAKETH_PREFIX = "Speaketh"
-- sender name -> list of {original, langKey, time}
-- A list (queue) rather than a single slot so that multi-part sends from
-- addons like Emote Splitter (which fires PreSendText once per split post)
-- each get their own cache entry and can be decoded independently.
local _pendingOriginals = {}

-- ============================================================
-- Out-of-band (OOB) channel for decoding speech between Speaketh
-- users who share no party/raid/guild. Addon messages cannot be
-- sent on SAY/YELL, so we piggyback on a hidden custom chat
-- channel that every Speaketh user silently joins on login.
--
-- The channel name is scoped per realm + faction so users only
-- hear each other within their own server context. The channel
-- is hidden from chat frames and its join/leave noise is
-- suppressed so the user never sees it.
-- ============================================================
local SPEAKETH_OOB_CHANNEL = nil  -- resolved in PLAYER_LOGIN
local _oobJoined = false

local function Speaketh_GetOOBChannelName()
    if SPEAKETH_OOB_CHANNEL then return SPEAKETH_OOB_CHANNEL end
    local realm = GetRealmName and GetRealmName() or "Unknown"
    -- Strip spaces/punctuation; channel names have length + char restrictions
    realm = realm:gsub("[^%w]", "")
    if #realm > 16 then realm = realm:sub(1, 16) end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "N"
    local factionTag = (faction == "Alliance") and "A" or (faction == "Horde") and "H" or "N"
    SPEAKETH_OOB_CHANNEL = "SpkthOOB" .. factionTag .. realm
    return SPEAKETH_OOB_CHANNEL
end

-- Find the numeric index of our OOB channel, or nil if we're not in it.
local function Speaketh_GetOOBChannelIndex()
    local name = Speaketh_GetOOBChannelName()
    local idx = GetChannelName and GetChannelName(name) or 0
    if idx and idx > 0 then return idx end
    return nil
end

-- Join the OOB channel silently and hide it from all chat frames.
local function Speaketh_JoinOOBChannel()
    if _oobJoined then return end
    if not JoinTemporaryChannel then return end
    local name = Speaketh_GetOOBChannelName()
    -- JoinTemporaryChannel returns a type code; 0 = failure (rare)
    local ok = pcall(JoinTemporaryChannel, name)
    if not ok then return end

    -- Hide from every chat window so users never see traffic on it.
    -- ChatFrame_RemoveChannel works on the channel name, not the index.
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and ChatFrame_RemoveChannel then
            pcall(ChatFrame_RemoveChannel, cf, name)
        end
    end
    _oobJoined = true
end

-- Apply dialect (and optionally language translation) only to text inside quotes,
-- leaving the rest untouched. Uses double quotes ("...") which is the standard
-- for speech in WoW RP emotes. Single quotes are left alone to avoid matching
-- apostrophes in contractions (don't, I'm, Thrall's, etc.).
-- If langKey is not "None", also translates the quoted content into the language.
local function ApplyDialectToQuotes(text, langKey)
    -- Protect OOC spans before processing quoted speech
    local oocTokens
    text, oocTokens = StripOOC(text)

    local result = {}
    local pos = 1
    while pos <= #text do
        -- Find the next double-quote
        local qStart = text:find('"', pos, true)

        if not qStart then
            -- No more quotes; append the rest as-is
            table.insert(result, text:sub(pos))
            break
        end

        -- Find the closing double-quote
        local qEnd = text:find('"', qStart + 1, true)
        if not qEnd then
            -- Unclosed quote; append the rest as-is
            table.insert(result, text:sub(pos))
            break
        end

        -- Append everything before the opening quote as-is
        if qStart > pos then
            table.insert(result, text:sub(pos, qStart - 1))
        end

        -- Extract the quoted content (without the quotes themselves)
        local quoted = text:sub(qStart + 1, qEnd - 1)

        -- Apply dialect to the quoted content
        if quoted ~= "" then
            local processed = quoted
            -- Skip dialect word swaps/slur when a language is active (the
            -- translation pass would garble them); see BuildTranslatedMsg.
            if langKey == "None" and Speaketh_Dialects and Speaketh_Dialects.Apply then
                processed = Speaketh_Dialects:Apply(quoted, langKey)
            end
            -- Apply language translation if not "None"
            if langKey ~= "None" and Speaketh_Languages[langKey] then
                processed = Speaketh_Translate:Message(processed, langKey)
                if Speaketh_Dialects and Speaketh_Dialects.ApplyEffectWords then
                    processed = Speaketh_Dialects:ApplyEffectWords(processed, langKey)
                end
            end
            processed = ApplyInterjectionsToSpeech(processed, langKey)
            -- Safety: never empty
            if not processed or processed == "" or not processed:match("%S") then
                processed = quoted
            end
            table.insert(result, '"' .. processed .. '"')
        else
            table.insert(result, '""')
        end

        pos = qEnd + 1
    end
    return RestoreOOC(table.concat(result), oocTokens)
end

-- Translates msg in langKey, prepending a [Language] tag when needed.
-- Returns CLEAN translated string - no payload.
-- If langKey is "None", only dialect transformations are applied.
local function BuildTranslatedMsg(msg, langKey, skipLengthGuard, protectActions)
    -- Protect OOC spans (parentheses) from dialect and translation
    local oocTokens
    msg, oocTokens = StripOOC(msg)

    -- SAY/YELL may mix speech with *physical actions*. Protect those spans in
    -- the same way as OOC text, after OOC stripping so nested parentheses are
    -- restored correctly inside an action.
    local actionTokens
    if protectActions then
        msg, actionTokens = StripAsteriskActions(msg)
    end

    local originalMsg = msg
    -- Apply dialect substitutions + slurring before translation.
    -- Only when no language is active: a real language translates/hashes every
    -- word into its own output, so dialect word swaps (e.g. "hello"->"'ello")
    -- are either made invisible (foreign hashing) or partly re-garbled (Gilnean
    -- codespeak re-hashing the leftover). Skipping the swap/slur pass under a
    -- language avoids that mangling. Post-translation interjections (hiccups,
    -- stammers) are added later and survive, so they still apply in both cases.
    if langKey == "None" and Speaketh_Dialects and Speaketh_Dialects.Apply then
        msg = Speaketh_Dialects:Apply(msg, langKey)
    end
    -- Safety: if dialect processing wiped the message, fall back to original
    if not msg or msg == "" or not msg:match("%S") then
        msg = originalMsg
    end

    -- "None" = no language translation, just send with dialect applied
    if langKey == "None" then
        local result = msg
        -- Apply post-translation interjections (hiccups etc.)
        result = ApplyInterjectionsToSpeech(result, langKey)
        -- Final safety: never return empty
        if not result or result == "" or not result:match("%S") then
            result = originalMsg
        end
        local restored = RestoreProtectedText(result, actionTokens, oocTokens)
        return restored, nil, #restored > 250
    end

    local langData  = Speaketh_Languages[langKey]

    local isNativeBlizz = false
    if langData and langData.blizzard then
        local numLangs = GetNumLanguages()
        for i = 1, numLangs do
            if GetLanguageByIndex(i) == langData.blizzard then
                isNativeBlizz = true
                break
            end
        end
    end

    -- Glyph override: for a language that has its own glyph set, the overhead
    -- speech bubble must show Speaketh-controlled scrambled text (so the glyph
    -- driver can match and replace it). WoW's native scrambling for a Blizzard
    -- language (e.g. Orcish on a Horde character) is computed client-side and
    -- Speaketh never sees that string, so a native message can't be matched or
    -- decorated. When the glyph system is on and this language ships glyphs,
    -- treat it as non-native: Speaketh tags and scrambles it itself, exactly
    -- like the non-Blizzard languages, which makes the bubble glyphs work.
    if isNativeBlizz and Speaketh_Glyphs and Speaketh_Glyphs.IsEnabled
       and Speaketh_Glyphs:IsEnabled()
       and Speaketh_Glyphs.HasOwnGlyphs and Speaketh_Glyphs:HasOwnGlyphs(langKey) then
        isNativeBlizz = false
    end

    local translated = Speaketh_Translate:Message(msg, langKey)
    if Speaketh_Dialects and Speaketh_Dialects.ApplyEffectWords then
        translated = Speaketh_Dialects:ApplyEffectWords(translated, langKey)
    end

    -- Note: we do NOT blend the outgoing text by speaker fluency here.
    -- The message sent over the wire is always fully translated, so other
    -- players and our own overhead speech bubble see consistent garbled
    -- output regardless of our fluency level. The incoming chat filter in
    -- Speaketh_ChatFilter handles fluency blending for the chat window by
    -- popping the cached original and mixing it with the received body.

    -- Insert interjections AFTER translation so they stay as literal text
    translated = ApplyInterjectionsToSpeech(translated, langKey)

    local finalMsg
    if isNativeBlizz then
        finalMsg = translated
    else
        finalMsg = "[" .. Speaketh:GetLanguageDisplayName(langKey) .. "] " .. translated
    end

    -- WoW silently drops chat messages longer than 255 bytes. Some languages
    -- (Gilnean in particular) expand input words into longer phrases, so even
    -- a 255-byte input can translate to 400+ bytes. Without a splitter addon,
    -- we can't send multiple chunks - but we can fit as many words as possible
    -- rather than bailing to untranslated text.
    --
    -- Strategy: if the translated result is too long, binary-search on the
    -- input word count - retranslate progressively fewer words until the
    -- result fits. This guarantees the sent message is always in the target
    -- language and as complete as the byte budget allows.
    --
    -- Keep the final guard active even for splitter-provided chunks. Language
    -- and dialect expansion can exceed a splitters' estimate, and WoW drops an
    -- oversized chat message entirely.
    local exceededLengthLimit = #finalMsg > 250
    if exceededLengthLimit and not skipLengthGuard then
        -- Split the dialect-processed input into words (preserving separators)
        local words = {}
        local seps  = {}
        local s = msg
        -- tokenise: alternate sep / word
        local cur = 1
        while cur <= #s do
            local ws, we = s:find("[%a'%-]+", cur)
            if ws then
                table.insert(seps,  s:sub(cur, ws - 1))
                table.insert(words, s:sub(ws, we))
                cur = we + 1
            else
                table.insert(seps, s:sub(cur))
                break
            end
        end

        local tagPrefix = isNativeBlizz and "" or
            ("[" .. Speaketh:GetLanguageDisplayName(langKey) .. "] ")
        local LIMIT = 250 - #tagPrefix

        -- Binary search: find the largest word count whose translation fits.
        local lo, hi = 1, #words
        local bestMsg = ""
        while lo <= hi do
            local mid = math.floor((lo + hi) / 2)
            -- Reassemble the first `mid` words with their separators
            local parts = {}
            for i = 1, mid do
                table.insert(parts, (seps[i] or ""))
                table.insert(parts, words[i])
            end
            if seps[mid + 1] then table.insert(parts, seps[mid + 1]) end
            local candidate = table.concat(parts)
            local tCandidate = Speaketh_Translate:Message(candidate, langKey)
            if Speaketh_Dialects and Speaketh_Dialects.ApplyEffectWords then
                tCandidate = Speaketh_Dialects:ApplyEffectWords(tCandidate, langKey)
            end
            tCandidate = ApplyInterjectionsToSpeech(tCandidate, langKey)
            if #tCandidate <= LIMIT then
                bestMsg = tagPrefix .. tCandidate
                lo = mid + 1
            else
                hi = mid - 1
            end
        end

        if bestMsg ~= "" then
            finalMsg = bestMsg
        else
            -- Absolute fallback: single word still too long - hard truncate.
            local fallback = Speaketh_Translate:Message(words[1] or msg, langKey)
            if Speaketh_Dialects and Speaketh_Dialects.ApplyEffectWords then
                fallback = Speaketh_Dialects:ApplyEffectWords(fallback, langKey)
            end
            finalMsg = (tagPrefix .. fallback):sub(1, 250)
        end
    end

    if isNativeBlizz then
        return RestoreProtectedText(finalMsg, actionTokens, oocTokens), nil, exceededLengthLimit
    else
        return RestoreProtectedText(finalMsg, actionTokens, oocTokens), langKey, exceededLengthLimit
    end
end

-- Cache an original for later matching.
-- Uses a FIFO queue per sender so that multi-part sends (e.g. Emote Splitter
-- splitting a long message into several sequential SendChatMessage calls) each
-- get their own entry and can be decoded in order.
local function CachePending(name, original, langKey)
    if not _pendingOriginals[name] then
        _pendingOriginals[name] = {}
    end
    table.insert(_pendingOriginals[name], {
        original = original,
        langKey  = langKey,
        time     = GetTime(),
    })
end

-- Peek at (but do not remove) the first matching cache entry for a sender.
local function PeekPending(name, langTag)
    local queue = _pendingOriginals[name]
    if not queue then return nil end
    local now = GetTime()
    while queue[1] and now - queue[1].time > 10 do
        table.remove(queue, 1)
    end
    for _, entry in ipairs(queue) do
        if entry.langKey == langTag then return entry end
    end
    return nil
end

-- Pop (remove and return) the oldest matching cache entry for a sender.
local function PopPending(sender, langTag)
    local now = GetTime()
    local shortName = sender and (sender:match("^([^-]+)") or sender) or ""
    local playerName = UnitName("player")
    for _, name in ipairs({shortName, sender or "", playerName}) do
        local queue = _pendingOriginals[name]
        if queue then
            while queue[1] and now - queue[1].time > 10 do
                table.remove(queue, 1)
            end
            for i, entry in ipairs(queue) do
                if entry.langKey == langTag then
                    table.remove(queue, i)
                    return entry.original
                end
            end
        end
    end
    return nil
end

-- Blizzard invokes a chat message filter once for every chat frame that is
-- displaying the event. The pending-original queue, however, must advance only
-- once per actual message. Keep the result of the first frame's pop briefly so
-- the other frames can render the same decoded text. Tracking which frames have
-- already used a result also distinguishes two identical consecutive messages:
-- when the same frame sees the key again, that is a new event and the next FIFO
-- entry is consumed.
local _resolvedIncoming = {}
local _unknownChatFrame = {}
local RESOLVED_INCOMING_TTL = 1

local function ResolvePendingForChatFrame(frame, event, msg, sender, langTag)
    local now = GetTime()
    local key = table.concat({event or "", sender or "", msg or ""}, "\031")
    local frameKey = frame or _unknownChatFrame

    for cachedKey, cached in pairs(_resolvedIncoming) do
        if now - cached.time > RESOLVED_INCOMING_TTL then
            _resolvedIncoming[cachedKey] = nil
        end
    end

    local cached = _resolvedIncoming[key]
    if cached and (not langTag or cached.langKey == langTag) then
        if not cached.frames[frameKey] then
            cached.frames[frameKey] = true
            return cached.original, cached.langKey
        end

        -- The same frame has received an identical message again. Treat this as
        -- the next real event instead of replaying the previous FIFO entry.
        _resolvedIncoming[key] = nil
    elseif cached then
        _resolvedIncoming[key] = nil
    end

    -- An omitted language is useful for a later frame looking up an already
    -- resolved emote, but is not enough information to pop a new queue entry.
    if not langTag then return nil end

    local original = PopPending(sender, langTag)
    if not original then return nil end

    _resolvedIncoming[key] = {
        original = original,
        langKey = langTag,
        time = now,
        frames = {[frameKey] = true},
    }
    return original, langTag
end

-- Tracks whether our addon prefix has been registered this session.
-- Set from PLAYER_LOGIN. Messages without a registered prefix are dropped
-- by the server and, on some clients, spam errors.
local _prefixRegistered = false
function Speaketh_SetPrefixRegistered(v)
    _prefixRegistered = v and true or false
end

-- Safe wrapper around C_ChatInfo.SendAddonMessage. Any failure is swallowed
-- so a bad addon channel never breaks the player's ability to send chat.
-- This is critical inside instanced content, where certain chat types
-- (INSTANCE_CHAT) can throw errors if called at the wrong moment.
local function SafeSendAddonMessage(prefix, payload, chan, target)
    if not _prefixRegistered then return end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    if not prefix or not payload or not chan then return end
    pcall(C_ChatInfo.SendAddonMessage, prefix, payload, chan, target)
end

-- Send the original on the narrowest addon route that matches the visible
-- chat type, and cache it locally. Proximity chat has no matching addon
-- distribution on Retail, so SAY/YELL/EMOTE always use OOB, regardless of
-- whether the sender is currently grouped.
function Speaketh_SendOriginal(original, langKey, chatType, target)
    -- Always cache locally so own messages work, regardless of network state
    local playerName = UnitName("player") or ""
    CachePending(playerName, original, langKey)

    -- Never try to send before the client is fully in-world
    if not IsLoggedIn or not IsLoggedIn() then return end

    local payload = langKey .. "|" .. original

    -- If whispering, send on whisper channel and also cache under the target
    -- name. WoW echoes outgoing whispers back as CHAT_MSG_WHISPER_INFORM with
    -- sender = target, so the incoming chat filter needs to find the original
    -- keyed by the target's name rather than our own.
    if chatType == "WHISPER" and target and target ~= "" then
        local shortTarget = target:match("^([^-]+)") or target
        CachePending(shortTarget, original, langKey)
        if shortTarget ~= target then CachePending(target, original, langKey) end
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "WHISPER", target)
        return
    end

    -- Routed channels do not need a realm-wide OOB duplicate.
    if chatType == "PARTY" or chatType == "PARTY_LEADER" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "PARTY")
        return
    elseif chatType == "RAID" or chatType == "RAID_WARNING" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "RAID")
        return
    elseif chatType == "INSTANCE_CHAT" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "INSTANCE_CHAT")
        return
    elseif chatType == "GUILD" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "GUILD")
        return
    elseif chatType == "OFFICER" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "OFFICER")
        return
    end

    -- SAY/YELL/EMOTE have no proximity addon route on Retail. Always use OOB
    -- for these spatial channels so nearby non-grouped players can decode too.
    -- Receivers still require the corresponding visible chat event before
    -- displaying the cached original.
    local isLocalSpeech = chatType == "SAY" or chatType == "YELL" or chatType == "EMOTE"
    if not isLocalSpeech then return end

    -- Broadcast on the hidden out-of-band channel so nearby Speaketh users on
    -- the same realm+faction can decode local speech.
    -- CHAT_MSG_SAY/YELL only fire for players in audible/shout range, so the
    -- receiver only uses this cached original if the visible scrambled
    -- message actually arrives in their chat; out-of-range broadcasts expire
    -- harmlessly from the cache after 10 seconds.
    local oobIdx = Speaketh_GetOOBChannelIndex()
    if oobIdx then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "CHANNEL", tostring(oobIdx))
    end
end

-- ============================================================
-- Outgoing chat hook
--
-- We modify chat editbox text before Blizzard's OnEnterPressed handler
-- reads it. This is the classic pattern used by older translation
-- addons and was confirmed working in Speaketh 1.2.5 and earlier.
--
-- The reason this sometimes fails in rated content is NOT the editbox
-- hook itself - it's that Speaketh_SendOriginal fires addon-channel
-- broadcasts, and some of those channels become restricted during
-- rated timers. If that errors mid-hook, the editbox text never gets
-- modified properly. Everything from that point is wrapped so that a
-- failing addon broadcast can't block the chat send.
-- ============================================================
local _inTranslation = false

-- ============================================================
-- Global enable / disable toggle
-- Persisted in Speaketh_Char.enabled (nil/true = on, false = off).
-- ============================================================
function Speaketh:IsEnabled()
    return not (Speaketh_Char and Speaketh_Char.enabled == false)
end

function Speaketh:SetEnabled(state)
    if not Speaketh_Char then return end
    Speaketh_Char.enabled = state
    -- Refresh any open UI so the indicator updates immediately
    if Speaketh_UI then
        if Speaketh_UI.RefreshWindow    then Speaketh_UI:RefreshWindow()    end
        if Speaketh_UI.RefreshLanguageHUD then Speaketh_UI:RefreshLanguageHUD() end
    end
    local msg = state
        and "|cffffcc00[Speaketh]|r |cff44ff44Enabled.|r"
        or  "|cffffcc00[Speaketh]|r |cffff4444Disabled.|r"
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function Speaketh:Toggle()
    self:SetEnabled(not self:IsEnabled())
end

local function Speaketh_ProcessOutgoing(editBox)
    if _inTranslation then return end

    -- Globally disabled — pass through untouched
    if not Speaketh:IsEnabled() then return end

    -- A chat-splitting addon has already handled translation for this send.
    if Speaketh.splitterBypassing then return end

    -- An Enscriber-based splitter (e.g. EmoteScribe) owns the outgoing send and
    -- translates each chunk via TranslateChunk. Its editbox callback and ours
    -- both fire on ChatFrame.OnEditBoxPreSendText with no guaranteed dispatch
    -- order, so the per-send splitterBypassing flag above may not be set yet
    -- when we run. Stand down whenever such a splitter is loaded so we never do
    -- a premature translate + broadcast that the splitter would then double.
    if Speaketh:IsExternalSplitterOwner() then
        return
    end

    -- If auto-chat is off, don't process normal chat editboxes
    if Speaketh_Char and Speaketh_Char.autoChat == false then return end

    if not editBox or type(editBox.GetText) ~= "function" then return end

    local text = editBox:GetText()
    if not text or text == "" then return end

    -- Leave slash commands alone - they're WoW instructions, not chat.
    -- Check after stripping any leading whitespace so e.g. " /target" still
    -- passes through untouched.
    local firstNonSpace = text:match("^%s*(.)")
    if firstNonSpace == "/" then return end

    local chatType = (editBox.GetAttribute and editBox:GetAttribute("chatType")) or "SAY"
    if not TRANSLATE_ON_SEND[chatType] then return end

    -- Per-channel toggle: skip translation if the user has disabled this channel
    if Speaketh_Char then
        local chanKey = CHAN_KEY_MAP[chatType]
        if chanKey and Speaketh_Char[chanKey] == false then return end
    end

    local langKey = Speaketh:GetLanguage()
    local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local effect = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()
    local quotesOnly = DIALECT_QUOTES_ONLY[chatType]

    -- "None" = no language translation, but still apply active dialect
    if langKey == "None" then
        if not dialect and not effect then return end

        local finalMsg
        if quotesOnly then
            finalMsg = ApplyDialectToQuotes(text, langKey)
        else
            finalMsg = BuildTranslatedMsg(text, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
        end
        if not finalMsg or finalMsg == "" then return end

        _inTranslation = true
        editBox:SetText(finalMsg)
        _inTranslation = false
        return
    end

    if Speaketh_Fluency:Get(langKey) == 0 then return end

    -- Emote with language: only translate quoted portions
    if quotesOnly then
        -- Broadcast the original emote text so other Speaketh users can
        -- decode the translated quoted spans in their chat filter.
        local target = editBox.GetAttribute and editBox:GetAttribute("tellTarget") or nil
        pcall(Speaketh_SendOriginal, text, langKey, chatType, target)

        local finalMsg = ApplyDialectToQuotes(text, langKey)
        if not finalMsg or finalMsg == "" then return end
        _inTranslation = true
        editBox:SetText(finalMsg)
        _inTranslation = false
        return
    end

    -- Send original on hidden addon channel so other Speaketh users can
    -- decode. Wrapped in pcall so a restricted channel during rated
    -- content (or any other send error) can't block the editbox update.
    local target = editBox.GetAttribute and editBox:GetAttribute("tellTarget") or nil
    pcall(Speaketh_SendOriginal, text, langKey, chatType, target)

    -- Build final translated message and write it back to the editbox
    local finalMsg = BuildTranslatedMsg(text, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
    if not finalMsg or finalMsg == "" then return end

    -- Overhead speech bubble glyphs (SAY/YELL only produce bubbles). The bubble
    -- will contain finalMsg (the garbled, as-sent text); queue it so the glyph
    -- driver can swap it to language glyphs drawn from the original letters.
    if Speaketh_Glyphs and (chatType == "SAY" or chatType == "YELL") then
        Speaketh_Glyphs:QueueBubble(finalMsg, text, langKey)
    end

    _inTranslation = true
    editBox:SetText(finalMsg)
    _inTranslation = false
end

-- Returns true when any chat messaging lockdown is active (combat, boss,
-- M+, rated PvP). Mirrors the pattern used by EmoteScribe/Enscriber so
-- that both InCombatLockdown and the newer C_ChatInfo gate are covered.
local function Speaketh_IsLocked()
    if InCombatLockdown and InCombatLockdown() then return true end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        if C_ChatInfo.InChatMessagingLockdown() then return true end
    end
    return false
end

-- Hook via ChatFrame.OnEditBoxPreSendText, which fires inside the secure
-- hardware-event chain BEFORE Blizzard calls SendText/SendChatMessage.
-- This is the only approach that avoids tainting the protected send path
-- in Midnight 12.0.5+. SetScript("OnEnterPressed") spreads taint onto the
-- editbox and causes ADDON_ACTION_BLOCKED; the EventRegistry callback does not.
local _speaketh_presend_hooked = false
local function Speaketh_InstallSendHook()
    if _speaketh_presend_hooked then return end
    _speaketh_presend_hooked = true

    EventRegistry:RegisterCallback(
        "ChatFrame.OnEditBoxPreSendText",
        function(_, editBox)
            if Speaketh_IsLocked() then return end
            pcall(Speaketh_ProcessOutgoing, editBox)
        end
    )
end

-- ============================================================
-- Splitter addon API
--
-- Exposes the translation pipeline so that a chat-splitting addon (e.g.
-- EmoteScribe) can correctly translate each chunk independently, rather
-- than letting Speaketh's editbox hook see only the first chunk.
--
-- Intended usage pattern for a splitting addon:
--
--   if Speaketh and Speaketh:WouldTranslate(chatType) then
--       -- Reduce chunk size before splitting to leave room for the tag prefix.
--       local overhead = Speaketh:GetTagOverhead(chatType)
--       -- ... set your chunk size to (255 - overhead) for this send ...
--
--       -- After splitting, translate each chunk and handle its own cache entry:
--       --   local translated = Speaketh:TranslateChunk(chunk, chatType, target)
--       --   -- send `translated` instead of `chunk`
--
--       -- Suppress Speaketh's editbox hook so it doesn't double-translate chunk[1]:
--       Speaketh.splitterBypassing = true
--       -- ... dispatch your chunks ...
--       Speaketh.splitterBypassing = false  -- or clear next frame via C_Timer
--   end
-- ============================================================

-- Returns true if Speaketh would translate an outgoing message of chatType
-- under the current user configuration. Respects autoChat, active language
-- or dialect, fluency, and per-channel toggles.
-- A splitting addon should call this before deciding to take over translation.
function Speaketh:WouldTranslate(chatType)
    if not Speaketh_Char then return false end
    if not self:IsEnabled() then return false end
    if Speaketh_IsLocked() then return false end
    if Speaketh_Char.autoChat == false then return false end
    if not chatType or not TRANSLATE_ON_SEND[chatType] then return false end

    local chanKey = CHAN_KEY_MAP[chatType]
    if chanKey and Speaketh_Char[chanKey] == false then return false end

    local langKey = self:GetLanguage()
    local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local effect = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()

    if langKey == "None" then
        -- No language translation, but a dialect may still transform the text.
        return dialect ~= nil or effect ~= nil
    end

    if not Speaketh_Fluency then return false end
    return Speaketh_Fluency:Get(langKey) > 0
end

-- Returns the number of bytes that Speaketh's visible [Language] tag adds to a
-- translated chunk. Effect expansion is handled by the splitter preview path,
-- so normal source chunks do not need a worst-case effect reserve.
function Speaketh:GetTagOverhead(chatType)
    if not self:WouldTranslate(chatType) then return 0 end

    local langKey = self:GetLanguage()
    if langKey == "None" then return 0 end

    local langData = Speaketh_Languages and Speaketh_Languages[langKey]
    if not langData then return 0 end

    -- Native Blizzard languages do not get a tag unless glyphs make Speaketh
    -- perform the scrambling itself.
    if langData.blizzard then
        local glyphOverride = Speaketh_Glyphs and Speaketh_Glyphs.IsEnabled
            and Speaketh_Glyphs:IsEnabled()
            and Speaketh_Glyphs.HasOwnGlyphs
            and Speaketh_Glyphs:HasOwnGlyphs(langKey)
        if not glyphOverride then
            local numLangs = GetNumLanguages and GetNumLanguages() or 0
            for i = 1, numLangs do
                if GetLanguageByIndex(i) == langData.blizzard then
                    return 0
                end
            end
        end
    end

    return #self:GetLanguageDisplayName(langKey) + 3
end

-- Translate a single already-split chunk for sending on chatType, and handle
-- the full originals cache/broadcast contract for that chunk independently.
-- This is the correct call for a splitting addon to make once per chunk:
--   • translates the chunk via the full pipeline (dialect + language + fluency)
--   • caches the pre-translation chunk text locally under the player's name
--     so the player's own incoming filter can decode the echo
--   • broadcasts the original chunk text on group/guild/OOB addon channels
--     so other Speaketh users can decode their incoming copy
-- Returns the translated string (falls back to original on failure).
-- For EMOTE, only quoted spans are translated (quotesOnly path).
-- For dialect-only (language = "None"), no cache/broadcast is performed
-- since there is no [Language] tag for the incoming filter to key on.
-- target: whisper target name, or nil for non-whisper chat types.
function Speaketh:TranslateChunk(msg, chatType, target)
    if not msg or msg == "" then return msg end

    local langKey    = self:GetLanguage()
    local dialect    = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local effect     = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()
    local quotesOnly = DIALECT_QUOTES_ONLY[chatType]

    if langKey == "None" then
        -- Dialect-only: transform text but no cache/broadcast needed since
        -- there is no [Language] tag for the receiver's filter to match on.
        if not dialect and not effect then return msg end
        local result
        if quotesOnly then
            result = ApplyDialectToQuotes(msg, langKey)
        else
            result = BuildTranslatedMsg(msg, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
        end
        return (result and result ~= "") and result or msg
    end

    -- Language path: translate, then cache and broadcast the pre-translation
    -- chunk so each incoming [Language] message can be decoded independently.
    local translated
    if quotesOnly then
        translated = ApplyDialectToQuotes(msg, langKey)
    else
        -- Keep the final byte-limit guard for integrations that call
        -- TranslateChunk directly without previewing their source chunk.
        translated = BuildTranslatedMsg(msg, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
    end
    if not translated or translated == "" then return msg end

    -- Cache and broadcast this chunk's original text. Each chunk gets its own
    -- entry in the FIFO queue so the receiver's PopPending call for each
    -- arriving [Language] message pops the right original in order.
    pcall(Speaketh_SendOriginal, msg, langKey, chatType, target)

    return translated
end

-- Translate a single message line for sending on chatType.
-- Applies dialect, language encoding, speaker fluency blend, and the
-- [Language] tag prefix. For EMOTE, only quoted spans are translated.
-- Returns: translatedMsg, langKey
--   translatedMsg - the final string to send (never nil/empty; falls back
--                   to the original if translation would produce garbage)
--   langKey       - the active language key, or nil if language is "None"
--                   or a native Blizzard language (no [Tag] prefix needed)
-- The caller is responsible for calling BroadcastOriginal separately.
-- Note: for per-chunk translation, prefer TranslateChunk which handles
-- the cache/broadcast contract automatically.
function Speaketh:TranslateOutgoing(msg, chatType)
    if not msg or msg == "" then return msg, nil end

    local langKey    = self:GetLanguage()
    local dialect    = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local effect     = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()
    local quotesOnly = DIALECT_QUOTES_ONLY[chatType]

    if langKey == "None" then
        -- Dialect-only path: no language tag, no BroadcastOriginal needed.
        if not dialect and not effect then return msg, nil end
        local result
        if quotesOnly then
            result = ApplyDialectToQuotes(msg, langKey)
        else
            result = BuildTranslatedMsg(msg, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
        end
        if not result or result == "" then return msg, nil end
        return result, nil
    end

    -- Language translation path.
    local translated, outLangKey
    if quotesOnly then
        translated = ApplyDialectToQuotes(msg, langKey)
        outLangKey = langKey
    else
        translated, outLangKey = BuildTranslatedMsg(msg, langKey, false, PROTECT_ASTERISK_ACTIONS[chatType])
    end

    if not translated or translated == "" then return msg, nil end
    return translated, outLangKey
end

-- Broadcast the pre-translation original so other Speaketh users in the
-- group, guild, or OOB channel can decode the scrambled text.
-- Call once per original line, before it is split, with the raw unsplit text.
-- langKey: the value returned by TranslateOutgoing (may be nil for dialect-only).
-- target:  whisper target name, or nil for non-whisper chat types.
-- Note: for per-chunk translation, prefer TranslateChunk which handles
-- the cache/broadcast contract automatically.
function Speaketh:BroadcastOriginal(original, langKey, chatType, target)
    if not langKey then return end  -- dialect-only: no decode payload needed
    pcall(Speaketh_SendOriginal, original, langKey, chatType, target)
end

-- ============================================================
-- Incoming: addon message receiver (group/guild/whisper)
-- ============================================================
local addonMsgFrame = CreateFrame("Frame")
addonMsgFrame:RegisterEvent("CHAT_MSG_ADDON")
addonMsgFrame:SetScript("OnEvent", function(self, event, prefix, payload, dist, sender)
    if prefix ~= SPEAKETH_PREFIX then return end
    if not payload or payload == "" then return end
    if not sender or sender == "" then return end

    local langKey, original = payload:match("^([^|]+)|(.+)$")
    if not langKey or not original then return end

    local shortName = sender:match("^([^-]+)") or sender
    local playerName = UnitName("player") or ""
    -- Skip self-echoes. When we broadcast on GUILD/RAID/OOB/etc., WoW echoes
    -- each broadcast back to us as CHAT_MSG_ADDON. Speaketh_SendOriginal has
    -- already cached the message once under the player name; re-caching on
    -- every channel echo would stack multiple duplicate entries in the FIFO
    -- queue and cause stale or repeated chat output.
    if shortName == playerName or sender == playerName then return end

    CachePending(shortName, original, langKey)
    if sender ~= shortName then
        CachePending(sender, original, langKey)
    end
end)

-- ============================================================
-- Incoming: chat filter for fluency-based understanding
-- ============================================================

local function BlendMessages(original, translated, fluency, protectActions)
    if fluency >= 100 then return original end
    if fluency <= 0 then return translated end

    -- Partial-fluency blending must not count protected OOC/action words when
    -- aligning original and translated word positions.
    local originalOOC
    original, originalOOC = StripOOC(original)
    local translatedOOC
    translated, translatedOOC = StripOOC(translated)

    local originalActions
    local translatedActions
    if protectActions then
        original, originalActions = StripAsteriskActions(original)
        translated, translatedActions = StripAsteriskActions(translated)
    end

    local function tokenize(text)
        local tokens = {}
        local pos = 1
        while pos <= #text do
            local ws, we = text:find("[%a'%-]+", pos)
            if ws then
                if ws > pos then
                    table.insert(tokens, {type="sep", text=text:sub(pos, ws-1)})
                end
                table.insert(tokens, {type="word", text=text:sub(ws, we)})
                pos = we + 1
            else
                table.insert(tokens, {type="sep", text=text:sub(pos)})
                break
            end
        end
        return tokens
    end

    local origTokens = tokenize(original)
    local transTokens = tokenize(translated)

    local origWords = {}
    for _, t in ipairs(origTokens) do
        if t.type == "word" then table.insert(origWords, t.text) end
    end

    local wordCount = 0
    for _, t in ipairs(transTokens) do
        if t.type == "word" then wordCount = wordCount + 1 end
    end

    local total = math.max(wordCount, #origWords)

    -- Build a deterministic per-word reveal table. The old formula
    -- (i*7 + total*13) % 100 clustered seeds around ~20 for short messages,
    -- meaning nothing was ever revealed below ~20% fluency. Instead use a
    -- simple LCG seeded from the message content so seeds spread uniformly
    -- across 0-99 regardless of message length.
    local seed = 0
    for i = 1, #original do seed = (seed * 31 + original:byte(i)) % 100 end
    local revealed = {}
    for i = 1, total do
        -- LCG step: produces a different value in 0-99 for each word index
        seed = (seed * 1664525 + 1013904223) % 100
        revealed[i] = (seed < fluency)
    end

    local result = {}
    local wordIdx = 0
    for _, token in ipairs(transTokens) do
        if token.type == "word" then
            wordIdx = wordIdx + 1
            if revealed[wordIdx] and origWords[wordIdx] then
                table.insert(result, origWords[wordIdx])
            else
                table.insert(result, token.text)
            end
        else
            table.insert(result, token.text)
        end
    end

    return RestoreProtectedText(table.concat(result), translatedActions, translatedOOC)
end

-- Incoming chat filter for fluency-based understanding.
-- This is called by Blizzard's chat frame pipeline for each filter event
-- registered below. Kept simple - no pcall wrapping - because the original
-- (pre-1.2.6) version of this code worked correctly and the pcall wrapper
-- caused message-suppression bugs.
local function Speaketh_ChatFilter(self, event, msg, sender, ...)
    if not msg or type(msg) ~= "string" then return false end

    -- Check for [LanguageName] prefix
    local langTag, body = msg:match("^%[([^%]]+)%]%s(.+)$")
    if not langTag or not Speaketh_Languages then return false end

    -- Resolve the tag to an internal key. Built-in languages use the key
    -- as the display name, but custom languages use a display name that
    -- differs from the internal key (e.g. key="CustomLang_Foxy",
    -- display="Foxy"). Try direct lookup first, then reverse search.
    local langKey = langTag
    if not Speaketh_Languages[langKey] then
        langKey = nil
        for k, data in pairs(Speaketh_Languages) do
            if data.name and data.name == langTag then
                langKey = k
                break
            end
        end
    end
    if not langKey then return false end

    if not Speaketh_Fluency then return false end

    local fluency = Speaketh_Fluency:Get(langKey)

    -- Passive learning (respects user setting)
    local learnEnabled = not (Speaketh_Char and Speaketh_Char.passiveLearn == false)
    if learnEnabled and fluency < 100 then
        if math.random(1, 10) == 1 then
            Speaketh_Fluency:Learn(langKey, 1)
        end
    end

    -- Overhead speech-bubble glyphs. Only SAY/YELL create overhead bubbles.
    -- The bubble the game shows for the speaker contains the raw incoming msg
    -- ("[langTag] body"), independent of any chat-window rewrite we do below.
    -- Glyphs represent the spoken language for every Speaketh listener alike:
    -- decode the original letters when we have them (sender is a Speaketh user
    -- in range), otherwise fall back to the garbled body so unknown speech
    -- still renders as glyphs overhead.
    if Speaketh_Glyphs and (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") then
        local peek = PeekPending and PeekPending(sender, langKey)
        local glyphSource = (peek and peek.original) or body
        -- If the original payload has not arrived, tell the glyph system this
        -- is translated fallback text. It can then collapse vocabulary phrases
        -- back to their source bucket lengths instead of drawing every letter
        -- in expansions such as Pandaren's "om nom nom".
        Speaketh_Glyphs:QueueBubble(msg, glyphSource, langKey, not peek)
    end

    -- Look up original from cache (self-messages or addon messages from group)
    local original = ResolvePendingForChatFrame(self, event, msg, sender, langKey)
    if original then
        if fluency >= 100 then
            return false, "[" .. langTag .. "] " .. original, sender, ...
        elseif fluency > 0 then
            local protectActions = event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL"
            local blended = BlendMessages(original, body, fluency, protectActions)
            return false, "[" .. langTag .. "] " .. blended, sender, ...
        end
    end

    return false
end

local FILTER_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    -- Outgoing whisper echo: WoW sends this back to us so we see our own
    -- sent whisper in chat. Without filtering it the garbled text shows
    -- instead of the original even at 100% fluency.
    "CHAT_MSG_WHISPER_INFORM",
}

-- Incoming filter for CHAT_MSG_EMOTE. Emotes carry translated quoted spans
-- inline (e.g. |She says "[Lur mak zug]" quietly.|) rather than a top-level
-- [Language] prefix, so they need their own filter. For each quoted span we
-- check whether the cached original for this sender contains a corresponding
-- quoted span, and if so swap the translated text back to the original (or a
-- fluency-blended version). The surrounding non-quoted emote text is preserved.
local function Speaketh_EmoteChatFilter(self, event, msg, sender, ...)
    if not msg or type(msg) ~= "string" then return false end
    if not Speaketh_Languages or not Speaketh_Fluency then return false end

    -- Nothing to decode unless the emote contains speech.
    if not msg:find('"', 1, true) then return false end

    -- Later chat frames can reuse the first frame's resolved original even
    -- though the FIFO entry has already been consumed.
    local original, langKey = ResolvePendingForChatFrame(self, event, msg, sender, nil)
    if not original then
        -- The first frame still needs to discover the language from the queued
        -- emote because emotes do not carry a top-level [Language] tag.
        local shortSender = sender and (sender:match("^([^-]+)") or sender) or sender or ""
        local playerName = UnitName("player") or ""
        local senderQueue = _pendingOriginals[shortSender]
                         or _pendingOriginals[sender or ""]
                         or _pendingOriginals[playerName]
        if not senderQueue or not senderQueue[1] then return false end
        local now = GetTime()
        while senderQueue[1] and now - senderQueue[1].time > 10 do
            table.remove(senderQueue, 1)
        end
        local pending = senderQueue[1]
        if not pending then return false end

        langKey = pending.langKey
        if not langKey or langKey == "None" then return false end
        original = ResolvePendingForChatFrame(self, event, msg, sender, langKey)
        if not original then return false end
    end

    local fluency = Speaketh_Fluency:Get(langKey)
    if fluency == 0 then return false end

    -- Passive learning
    local learnEnabled = not (Speaketh_Char and Speaketh_Char.passiveLearn == false)
    if learnEnabled and fluency < 100 then
        if math.random(1, 10) == 1 then
            Speaketh_Fluency:Learn(langKey, 1)
        end
    end

    -- Build a list of original quoted spans from the cached original emote
    local origQuotes = {}
    local p = 1
    while p <= #original do
        local qs = original:find('"', p, true)
        if not qs then break end
        local qe = original:find('"', qs + 1, true)
        if not qe then break end
        table.insert(origQuotes, original:sub(qs + 1, qe - 1))
        p = qe + 1
    end
    if #origQuotes == 0 then return false end

    -- Replace each quoted span in the received (translated) emote with the
    -- original (or fluency-blended) text, preserving the surrounding emote.
    local quoteIdx = 0
    local modified = false
    local result = msg:gsub('"([^"]*)"', function(translated)
        quoteIdx = quoteIdx + 1
        local orig = origQuotes[quoteIdx]
        if not orig then return '"' .. translated .. '"' end
        modified = true
        if fluency >= 100 then
            return '"' .. orig .. '"'
        else
            return '"' .. BlendMessages(orig, translated, fluency) .. '"'
        end
    end)

    if not modified then return false end
    return false, result, sender, ...
end

local function Speaketh_RegisterChatFilters()
    for _, event in ipairs(FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, Speaketh_ChatFilter)
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", Speaketh_EmoteChatFilter)
end

-- ============================================================
-- Suppress all chat-UI noise from the hidden OOB channel.
-- If anything ever leaks through (e.g. a user manually re-adds
-- the channel to a chat frame, or a join/leave notice fires
-- before we can hide it), these filters drop it silently.
-- ============================================================
local function Speaketh_IsOOBChannelName(name)
    if not name or name == "" then return false end
    -- Match by prefix so we catch any realm/faction variant
    return name:sub(1, 8) == "SpkthOOB"
end

local function Speaketh_OOBChannelFilter(self, event, msg, sender, _, _, _, _, _, _, channelName, ...)
    if Speaketh_IsOOBChannelName(channelName) then
        return true  -- suppress
    end
    return false
end

-- Channel notice events (joined/left/etc.) pass the channel name in arg9
local function Speaketh_OOBChannelNoticeFilter(self, event, msg, _, _, _, _, _, _, _, channelName, ...)
    if Speaketh_IsOOBChannelName(channelName) or Speaketh_IsOOBChannelName(msg) then
        return true  -- suppress
    end
    return false
end

local function Speaketh_RegisterOOBSuppressors()
    if not ChatFrame_AddMessageEventFilter then return end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", Speaketh_OOBChannelFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_JOIN", Speaketh_OOBChannelNoticeFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_LEAVE", Speaketh_OOBChannelNoticeFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", Speaketh_OOBChannelNoticeFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", Speaketh_OOBChannelNoticeFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_LIST", Speaketh_OOBChannelNoticeFilter)
end

-- ============================================================
-- Event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ENCOUNTER_START")  -- combat / lockdown begins
eventFrame:RegisterEvent("ENCOUNTER_END")   -- combat / lockdown ends

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "Speaketh" then return end

        -- Initialise saved variables
        if not Speaketh_Char then
            Speaketh_Char = {}
        end
        -- Migrate / fill missing keys from defaults
        for k, v in pairs(DEFAULTS) do
            if Speaketh_Char[k] == nil then
                if type(v) == "table" then
                    Speaketh_Char[k] = {}
                else
                    Speaketh_Char[k] = v
                end
            end
        end

        -- Migrate legacy Drunk dialect state into the independent Effects state.
        if Speaketh_Char.drunkLevel and Speaketh_Char.drunkLevel > 0 then
            if not Speaketh_Char.effectLevels then
                Speaketh_Char.effectLevels = {}
            end
            if not Speaketh_Char.effectLevels["Drunk"] then
                Speaketh_Char.effectLevels["Drunk"] = Speaketh_Char.drunkLevel
            end
            Speaketh_Char.effect = "Drunk"
            Speaketh_Char.drunkLevel = 0
        end
        if Speaketh_Char.dialect == "Drunk" then
            Speaketh_Char.effectLevels = Speaketh_Char.effectLevels or {}
            local migratedLevel = Speaketh_Char.effectLevels["Drunk"]
                or (Speaketh_Char.dialectLevels and Speaketh_Char.dialectLevels["Drunk"])
                or 1
            Speaketh_Char.effectLevels["Drunk"] = migratedLevel
            Speaketh_Char.effect = migratedLevel > 0 and "Drunk" or nil
            Speaketh_Char.dialect = nil
        end

    elseif event == "PLAYER_LOGIN" then
        -- Initialize the theme system from saved variables before any UI
        -- is constructed, so newly built frames skin correctly on creation.
        if Speaketh_Theme and Speaketh_Theme.Init then
            Speaketh_Theme:Init()
        end

        -- Register addon prefix for group/guild/whisper fluency decoding.
        -- Guard so a very old client lacking C_ChatInfo doesn't error.
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            local ok = C_ChatInfo.RegisterAddonMessagePrefix(SPEAKETH_PREFIX)
            Speaketh_SetPrefixRegistered(ok ~= false)
        end

        -- Seed racial fluencies now that unit info is available
        if Speaketh_Fluency and Speaketh_Fluency.SeedDefaults then
            Speaketh_Fluency:SeedDefaults()
        end

        -- Seed built-in dialect word rules into saved variables (once per character)
        if Speaketh_Dialects and Speaketh_Dialects.SeedSubstitutes then
            Speaketh_Dialects:SeedSubstitutes()
        end

        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Thank you for using Speaketh (v 1.2.0)!")

        -- Re-register any user-created custom dialects from saved variables
        if Speaketh_Dialects and Speaketh_Dialects.SeedCustomDialects then
            Speaketh_Dialects:SeedCustomDialects()
        end

        -- Re-register any user-created custom languages from saved variables
        if Speaketh_Char.customLanguages then
            for key, data in pairs(Speaketh_Char.customLanguages) do
                if Speaketh_RegisterCustomLanguage and data.name and data.words then
                    Speaketh_RegisterCustomLanguage(key, data.name, data.words)
                end
            end
        end

        -- Validate saved language still exists
        if Speaketh_Char.language ~= "None" and not Speaketh_Languages[Speaketh_Char.language] then
            Speaketh_Char.language = DEFAULTS.language
        end

        -- Register the pre-send editbox callback so outgoing chat gets
        -- translated. Uses EventRegistry ChatFrame.OnEditBoxPreSendText
        -- which runs inside the secure hardware-event chain and does not
        -- taint SendChatMessage.
        Speaketh_InstallSendHook()

        -- Register incoming chat filters for partial understanding
        Speaketh_RegisterChatFilters()

        -- Suppress any chat-UI noise from the hidden OOB channel
        Speaketh_RegisterOOBSuppressors()

        -- Join the hidden out-of-band channel so we can decode speech from
        -- other Speaketh users on this realm+faction even when we share no
        -- party/raid/guild. Channel joins sometimes fail if called too
        -- early in the login sequence, so we retry a couple of times with
        -- C_Timer.After. If the player's channel slots are full, the join
        -- silently fails and the addon degrades gracefully to the existing
        -- party/raid/guild/whisper behavior.
        if Speaketh_Char.enableOOB ~= false then
            if C_Timer and C_Timer.After then
                C_Timer.After(2, function()
                    Speaketh_JoinOOBChannel()
                    if not _oobJoined then
                        C_Timer.After(5, Speaketh_JoinOOBChannel)
                    end
                end)
            else
                Speaketh_JoinOOBChannel()
            end
        end

        -- Build minimap button (respects Speaketh_Char.showMinimap)
        Speaketh_UI:CreateMinimapButton()
        if Speaketh_UI.ApplyMinimapVisibility then
            Speaketh_UI:ApplyMinimapVisibility()
        end

        -- Build the floating language HUD (respects Speaketh_Char.showLangHUD)
        if Speaketh_UI.CreateLanguageHUD then
            Speaketh_UI:CreateLanguageHUD()
        end

        -- Register the modern options panel (ESC > Options > AddOns > Speaketh)
        if Speaketh_Options and Speaketh_Options.Register then
            pcall(function() Speaketh_Options:Register() end)
        end

        -- Show splash:
        --   - always, if user opted into "showSplash"
        --   - otherwise, only on first login (splashSeen)
        if Speaketh_Char.showSplash then
            Speaketh_UI:ShowSplash()
        elseif not Speaketh_Char.splashSeen then
            Speaketh_UI:ShowSplash()
            Speaketh_Char.splashSeen = true
        end

    elseif event == "ENCOUNTER_END" then
        -- Combat / instance lockdown has begun. Translation is suspended to
        -- avoid tainting protected frames (ADDON_ACTION_BLOCKED on SendChatMessage).
        if Speaketh_Char and Speaketh_Char.showLockdownNotify == true then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Encounter Lockdown Ended: translation resumed.")
        end

    elseif event == "ENCOUNTER_START" then
        -- Combat / lockdown has ended; translation resumes automatically.
        if Speaketh_Char and Speaketh_Char.showLockdownNotify == true then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Encounter Lockdown Started: translation paused.")
        end
    end
end)

-- ============================================================
-- Splash screen - native-style, matches the Speak Window chrome
-- (dark slate backdrop, thin gold edge, gold-accent header).
-- ============================================================
function Speaketh_UI:ShowSplash()
    if self.SplashFrame and self.SplashFrame:IsShown() then
        self.SplashFrame:Hide()
        return
    end

    if not self.SplashFrame then
        local f = CreateFrame("Frame", "SpeakethSplash", UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        f:SetSize(460, 476)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop",  f.StopMovingOrSizing)
        f:SetClampedToScreen(true)

        -- Escape closes the splash like any native Blizzard dialog.
        tinsert(UISpecialFrames, "SpeakethSplash")

        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 32, edgeSize = 12,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            Speaketh_Theme:Register(function(C)
                if not f.SetBackdropColor then return end
                local bg, bd = C.slateBg, C.slateBorder
                f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
                f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
            end)
        end

        -- Void-only atmospheric decoration (hidden in Classic)
        Speaketh_Theme:AddVoidVignette(f)
        Speaketh_Theme:AddVoidInkBleed(f)
        Speaketh_Theme:AddVoidGlowPulse(f)
        Speaketh_Theme:AddVoidRunes(f, 12, 24)

        -- Title
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
        title:SetText("Speaketh")
        title:SetTextColor(1, 1, 1, 1)
	
	local versionLocal = C_AddOns.GetAddOnMetadata("Speaketh", "Version") or "?.?.?"
        local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
        ver:SetTextColor(0.55, 0.55, 0.60, 1)
        ver:SetText("v" .. versionLocal .. "  -  Roleplay Language Addon")

        local div1 = f:CreateTexture(nil, "ARTWORK")
        div1:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -36)
        div1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -36)
        div1:SetHeight(1)
        Speaketh_Theme:Register(function(C)
            local a = C.accent; div1:SetColorTexture(a[1], a[2], a[3], 0.9)
        end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- Features
        local featHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        featHead:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -48)
        featHead:SetText("Features")
        Speaketh_Theme:Register(function(C)
            local t = C.headerGold; featHead:SetTextColor(t[1], t[2], t[3], 1)
        end)

        local features = {
            "20+ lore-accurate racial & exotic languages",
            "Custom languages - define your own word pools",
            "Language sharing - export/import codes for custom languages",
            "Dialect system - Gilnean, Troll, and more",
            "Effects system - Drunk, Stutter, Hiss, Growl, and Lisp",
            "Custom dialects - build your own word-swap accents",
            "Fluency system - 0-100% per language, passive learning",
            "Cross-player decoding - groups, whispers, /say & /yell",
            "Passthrough words - names that never get translated",
            "Minimap button & floating language HUD",
        }

        local lastFeature
        for i, line in ipairs(features) do
            local ft = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ft:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -66 - (i - 1) * 15)
            ft:SetText("- " .. line)
            lastFeature = ft
        end

        local div2 = f:CreateTexture(nil, "ARTWORK")
        div2:SetPoint("TOPLEFT",  lastFeature, "BOTTOMLEFT", -14, -6)
        div2:SetWidth(432)
        div2:SetHeight(1)
        Speaketh_Theme:Register(function(C)
            local a = C.accent; div2:SetColorTexture(a[1], a[2], a[3], 0.5)
        end)

        -- Commands
        local cmdHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cmdHead:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 4, -11)
        cmdHead:SetText("Commands")
        Speaketh_Theme:Register(function(C)
            local t = C.headerGold; cmdHead:SetTextColor(t[1], t[2], t[3], 1)
        end)

        local commands = {
            {"/sp  or  /speaketh",   "Open this splash screen"},
            {"/sp options",          "Open the settings panel"},
            {"/sp window",           "Open the Speak Window"},
            {"/sp <language>",       "Switch language  (e.g. /sp orcish)"},
            {"/sp none",             "Disable translation"},
            {"/sp cycle",            "Cycle to next known language"},
            {"/sp dialect <name>",   "Set dialect  (gilnean, troll, etc.)"},
            {"/sp theme <mode>",     "Change theme  (classic or void)"},
            {"/sp drunk <0-3>",      "Set drunkenness level"},
            {"/sp share <language>", "Generate an import code"},
            {"/sp import <code>",    "Import a custom language"},
            {"/sp list",             "List all languages & fluency"},
        }

        local lastCommand
        for i, cmd in ipairs(commands) do
            local ct = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ct:SetPoint("TOPLEFT", cmdHead, "BOTTOMLEFT", 10, -6 - (i - 1) * 14)
            ct:SetText(cmd[1])
            local cd = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cd:SetPoint("LEFT", ct, "LEFT", 170, 0)
            cd:SetText("- " .. cmd[2])
            cd:SetTextColor(0.70, 0.70, 0.75, 1)
            lastCommand = ct
        end

        local div3 = f:CreateTexture(nil, "ARTWORK")
        div3:SetPoint("TOPLEFT",  lastCommand, "BOTTOMLEFT", -14, -7)
        div3:SetWidth(432)
        div3:SetHeight(1)
        Speaketh_Theme:Register(function(C)
            local a = C.accent; div3:SetColorTexture(a[1], a[2], a[3], 0.5)
        end)

        -- Footer
        local footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        footer:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 4, -11)
        self.SplashFooter = footer

        self.SplashFrame = f
    end

    -- Update footer with current language, dialect, and effect
    local lang = Speaketh:GetLanguage()
    local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local footerText
    if lang == "None" then
        footerText = "Language: |cffffd100None|r  (no translation)"
    else
        local fluency = Speaketh_Fluency:Get(lang)
        footerText = string.format(
            "Speaking |cffffd100%s|r  (%d%% fluency)", Speaketh:GetLanguageDisplayName(lang), math.floor(fluency))
    end
    if dialect then
        footerText = footerText .. "  -  Dialect: |cffffd100" ..
            Speaketh_Dialects:GetDisplayLabel() .. "|r"
    end
    local effect = Speaketh_Dialects.GetActiveEffect and Speaketh_Dialects:GetActiveEffect()
    if effect then
        local data = Speaketh_Dialects:GetData(effect)
        local label = data and data.name or effect
        if data and data.usesSlider then
            label = label .. ": " .. Speaketh_Dialects:GetSliderLabel(effect,
                Speaketh_Dialects:GetLevel(effect))
        end
        footerText = footerText .. "  -  Effect: |cffffd100" .. label .. "|r"
    end
    self.SplashFooter:SetText(footerText)

    self.SplashFrame:Show()
end

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_SPEAKETH1 = "/speaketh"
SLASH_SPEAKETH2 = "/sp"

SlashCmdList["SPEAKETH"] = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "help" then
        Speaketh_UI:ShowSplash()

    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        if Speaketh_Options and Speaketh_Options.Open then
            Speaketh_Options:Open()
        end

    elseif cmd == "window" or cmd == "speak" or cmd == "open" then
        if Speaketh_UI and Speaketh_UI.ToggleSpeakWindow then
            Speaketh_UI:ToggleSpeakWindow()
        end

    elseif cmd == "theme" then
        local choice = (rest or ""):lower()
        if choice == "void" then
            Speaketh_Theme:Set("Void")
        elseif choice == "classic" then
            Speaketh_Theme:Set("Classic")
        elseif choice == "" or choice == "toggle" then
            Speaketh_Theme:Set(Speaketh_Theme:IsVoid() and "Classic" or "Void")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r Usage: /sp theme [classic|void|toggle]")
            return
        end
        if Speaketh_UI and Speaketh_UI.RefreshWindow then pcall(function() Speaketh_UI:RefreshWindow() end) end
        if Speaketh_UI and Speaketh_UI.RefreshLanguageHUD then pcall(function() Speaketh_UI:RefreshLanguageHUD() end) end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r Theme set to |cff88ccff" .. Speaketh_Theme:Current() .. "|r.")

    elseif cmd == "cycle" then
        Speaketh:CycleLanguage()

    elseif cmd == "list" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh] Known languages:|r")
        for _, key in ipairs(Speaketh_LanguageOrder) do
            local f = Speaketh_Fluency:Get(key)
            local cur = (Speaketh:GetLanguage() == key) and " |cff00ff00<speaking>|r" or ""
            if f > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "  |cff88ccff%s|r - %d%%%s", Speaketh:GetLanguageDisplayName(key), math.floor(f), cur))
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh] Unknown languages:|r")
        for _, key in ipairs(Speaketh_LanguageOrder) do
            local f = Speaketh_Fluency:Get(key)
            if f == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "  |cff666666%s|r - unknown", Speaketh:GetLanguageDisplayName(key)))
            end
        end

    elseif cmd == "dialect" then
        rest = strtrim(rest)
        if rest == "" or rest:lower() == "none" or rest:lower() == "off" then
            Speaketh_Dialects:SetActive(nil)
        else
            -- Try partial match
            local _, dialectOrder = Speaketh_Dialects:GetAll()
            local matched = nil
            for _, dk in ipairs(dialectOrder) do
                if dk ~= "Drunk" and dk:lower():find(rest:lower(), 1, true) then
                    matched = dk; break
                end
            end
            if matched then
                Speaketh_Dialects:SetActive(matched)
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffcc00[Speaketh]|r Unknown dialect: " .. rest)
            end
        end
        if Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
            Speaketh_UI:RefreshWindow()
        end

    elseif cmd == "resetdialects" or cmd == "resetdialect" then
        -- Hard reset of all built-in dialect word rules to factory defaults.
        -- Clears corrupted/duplicated saved data. Custom dialects are kept.
        if Speaketh_Dialects and Speaketh_Dialects.ResetBuiltinSubstitutes then
            local n = Speaketh_Dialects:ResetBuiltinSubstitutes()
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffffcc00[Speaketh]|r Built-in dialect rules reset to defaults (%d rules). "
                .. "Custom dialects were left untouched.", n or 0))
            if Speaketh_UI and Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
                Speaketh_UI:RefreshWindow()
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Reset function unavailable - is the addon up to date?")
        end

    elseif cmd == "drunk" then
        local level = tonumber(rest) or 0
        level = math.max(0, math.min(3, level))
        Speaketh_Dialects:SetDrunkLevel(level)
        local labels = {[0]="Off", [1]="Tipsy", [2]="Drunk", [3]="Smashed"}
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[Speaketh]|r Drunkenness set to %d (%s).", level, labels[level]))
        if Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
            Speaketh_UI:RefreshWindow()
        end

    elseif cmd == "share" then
        -- /sp share <language>  - prints an import code to chat for copy-paste sharing
        local input = strtrim(rest):lower()
        if input == "" then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Usage: /sp share <language>  - generates an import code")
            return
        end
        local matchedKey = nil
        if Speaketh_Char and Speaketh_Char.customLanguages then
            for key, data in pairs(Speaketh_Char.customLanguages) do
                local dispLower = (data.name or ""):lower()
                if dispLower == input or dispLower:find(input, 1, true)
                   or key:lower():find(input, 1, true) then
                    matchedKey = key; break
                end
            end
        end
        if not matchedKey then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r No custom language matching: " .. rest)
            return
        end
        if Speaketh_Share and Speaketh_Share.ExportCode then
            local code, err = Speaketh_Share:ExportCode(matchedKey)
            if code then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r Import code - copy everything below:")
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff" .. code .. "|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r " .. (err or "Export failed."))
            end
        end

    elseif cmd == "import" then
        -- /sp import <code>  - import a language from a code string
        local code = strtrim(rest)
        if code == "" then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Usage: /sp import <code>")
            return
        end
        if Speaketh_Share and Speaketh_Share.ImportCode then
            local name, wc = Speaketh_Share:ImportCode(code, false)
            if name then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cffffcc00[Speaketh]|r Imported |cff88ccff%s|r (%d words). Fluency set to 100%%.",
                    name, wc))
                if Speaketh_Options and Speaketh_Options.RefreshCustomLanguages then
                    pcall(function() Speaketh_Options:RefreshCustomLanguages() end)
                end
            elseif wc and wc:sub(1, 10) == "COLLISION:" then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffcc00[Speaketh]|r A language with that name already exists. "
                    .. "Use |cff88ccff/sp import-overwrite <code>|r to replace it.")
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffcc00[Speaketh]|r Import failed: " .. (wc or "unknown error"))
            end
        end

    elseif cmd == "import-overwrite" then
        local code = strtrim(rest)
        if code == "" then return end
        if Speaketh_Share and Speaketh_Share.ImportCode then
            local name, wc = Speaketh_Share:ImportCode(code, true)
            if name then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cffffcc00[Speaketh]|r Imported (overwrite) |cff88ccff%s|r (%d words). Fluency set to 100%%.",
                    name, wc))
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffcc00[Speaketh]|r Import failed: " .. (wc or "unknown error"))
            end
        end

    elseif cmd == "learn" then
        -- Debug: /sp learn Shath'Yar 50
        local lang, amount = rest:match("^(.-)%s+(%d+)%s*$")
        if not lang then lang = rest; amount = "100" end
        amount = tonumber(amount) or 100

        -- Find matching language key (case-insensitive partial match)
        local matched = nil
        for _, key in ipairs(Speaketh_LanguageOrder) do
            if key:lower():find(lang:lower(), 1, true) then
                matched = key; break
            end
        end

        if matched then
            Speaketh_Fluency:Set(matched, amount)
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffffcc00[Speaketh]|r Set %s fluency to %d%%.", Speaketh:GetLanguageDisplayName(matched), amount))
        else
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Unknown language: " .. lang)
        end

    else
        -- Treat the whole command as a language name (partial match)
        local input = msg:lower()

        -- Check for "none" / "default" / "off" to disable translation
        if input == "none" or input == "default" or input == "off" then
            Speaketh:SetLanguage("None")
            if Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
                Speaketh_UI:RefreshWindow()
            end
            return
        end

        local matched = nil
        for _, key in ipairs(Speaketh_LanguageOrder) do
            if key:lower():find(input, 1, true) then
                matched = key; break
            end
        end

        if matched then
            if Speaketh_Fluency:Get(matched) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cffffcc00[Speaketh]|r You don't know |cff88ccff%s|r yet. " ..
                    "Hear it spoken to learn it.", Speaketh:GetLanguageDisplayName(matched)))
            else
                Speaketh:SetLanguage(matched)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r No language found matching: " .. msg)
        end
    end
end

-- Stable API delegates. Speaketh_API.lua loads after this file and uses these
-- narrow wrappers instead of reaching into file-local implementation details.
-- They are intentionally not part of the public compatibility contract.
Speaketh.Internal = Speaketh.Internal or {}

function Speaketh.Internal:IsLocked()
    return Speaketh_IsLocked()
end

function Speaketh.Internal:ApplyDialectToQuotes(text, langKey)
    return ApplyDialectToQuotes(text, langKey)
end

function Speaketh.Internal:BuildTranslatedMsg(text, langKey, skipLengthGuard, protectActions)
    return BuildTranslatedMsg(text, langKey, skipLengthGuard, protectActions)
end

-- Side-effect-free splitter preview. The returned text is the exact text a
-- compatibility module may send, while `oversized` tells it to subdivide the
-- source before committing the matching original-text payload.
function Speaketh.Internal:PrepareSplitterChunk(text, chatType)
    if not text or text == "" then return text, nil, false end

    local langKey = Speaketh:GetLanguage()
    local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local effect = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()
    local quotesOnly = DIALECT_QUOTES_ONLY[chatType]

    if langKey == "None" then
        if not dialect and not effect then return text, nil, #text > 250 end
        local translated
        local oversized
        if quotesOnly then
            translated = ApplyDialectToQuotes(text, langKey)
            oversized = translated and #translated > 250 or false
        else
            translated, _, oversized = BuildTranslatedMsg(
                text, langKey, true, PROTECT_ASTERISK_ACTIONS[chatType])
        end
        return (translated and translated ~= "") and translated or text, nil, oversized
    end

    local translated, outLangKey, oversized
    if quotesOnly then
        translated = ApplyDialectToQuotes(text, langKey)
        outLangKey = langKey
        oversized = translated and #translated > 250 or false
    else
        translated, outLangKey, oversized = BuildTranslatedMsg(
            text, langKey, true, PROTECT_ASTERISK_ACTIONS[chatType])
    end
    return (translated and translated ~= "") and translated or text,
        outLangKey, oversized
end

function Speaketh.Internal:CommitSplitterChunk(original, langKey, chatType, target)
    if not langKey then return end
    pcall(Speaketh_SendOriginal, original, langKey, chatType, target)
end

function Speaketh.Internal:BlendMessages(original, translated, fluency, protectActions)
    return BlendMessages(original, translated, fluency, protectActions)
end

function Speaketh.Internal:PeekPending(sender, langKey)
    local entry = PeekPending(sender, langKey)
    return entry and entry.original or nil
end
