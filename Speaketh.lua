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
    autoChat       = true,
    passiveLearn   = true,    -- gain fluency passively from hearing speech
    showMinimap    = true,    -- show minimap button
    showLangHUD    = true,    -- show floating language HUD
    hudPos         = nil,     -- saved position of the HUD; nil = default
    customWords    = {},      -- user-defined words that pass through untranslated
    dialectSubstitutes = {}, -- user-defined per-dialect word replacements: [dialectKey] = {{from,to}, ...}
    dialectSubstitutesSeedVersion = 0, -- tracks whether built-in rules have been seeded
    customDialects = {},     -- user-created dialects: [key] = {name=string}
    customLanguages = {},    -- user-created languages: [key] = {name=string, words={...}}
    showSplash           = false,   -- show splash on every login (first login only when false)
    showLockdownNotify   = true,    -- print a chat message when combat lockdown disables translation
    enableOOB      = true,    -- join hidden cross-player channel so non-grouped Speaketh users can decode each other's SAY/YELL
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
            "|cffffcc00[Speaketh]|r Now speaking |cff88ccffNone|r  (no translation — dialects only)")
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
    Speaketh_Fluency:EnsureNative(key)

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
local _pendingOriginals = {} -- sender name -> {original, langKey, time}

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
            if Speaketh_Dialects and Speaketh_Dialects.Apply then
                processed = Speaketh_Dialects:Apply(quoted, langKey)
            end
            -- Apply language translation if not "None"
            if langKey ~= "None" and Speaketh_Languages[langKey] then
                processed = Speaketh_Translate:Message(processed, langKey)
            end
            if Speaketh_Dialects and Speaketh_Dialects.ApplyInterjections then
                processed = Speaketh_Dialects:ApplyInterjections(processed)
            end
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
    return table.concat(result)
end

-- Translates msg in langKey, prepending a [Language] tag when needed.
-- Returns CLEAN translated string — no payload.
-- If langKey is "None", only dialect transformations are applied.
local function BuildTranslatedMsg(msg, langKey)
    local originalMsg = msg
    -- Apply dialect substitutions + slurring before translation
    if Speaketh_Dialects and Speaketh_Dialects.Apply then
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
        if Speaketh_Dialects and Speaketh_Dialects.ApplyInterjections then
            result = Speaketh_Dialects:ApplyInterjections(result)
        end
        -- Final safety: never return empty
        if not result or result == "" or not result:match("%S") then
            result = originalMsg
        end
        return result, nil
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

    local translated = Speaketh_Translate:Message(msg, langKey)

    -- Apply the speaker's own fluency to the outgoing message.
    -- At 100% fluency the message is fully translated (scrambled).
    -- At lower fluency, some words slip through in their original form —
    -- mirroring what listeners at the same fluency level would see.
    local speakerFluency = Speaketh_Fluency:Get(langKey)
    if speakerFluency < 100 then
        translated = BlendMessages(msg, translated, speakerFluency)
    end

    -- Insert interjections AFTER translation so they stay as literal text
    if Speaketh_Dialects and Speaketh_Dialects.ApplyInterjections then
        translated = Speaketh_Dialects:ApplyInterjections(translated)
    end

    local finalMsg
    if isNativeBlizz then
        finalMsg = translated
    else
        finalMsg = "[" .. Speaketh:GetLanguageDisplayName(langKey) .. "] " .. translated
    end

    -- WoW silently drops chat messages longer than 255 bytes. Some languages
    -- (like Gilnean rhyming slang) expand short input into much longer output,
    -- which can push past the limit and cause the player's message to vanish
    -- entirely. If we'd exceed the safe limit, fall back to the original
    -- untranslated text — partial translation is better than no message at all.
    if #finalMsg > 250 then
        -- Too long. Return the original so the send still happens.
        -- Use the original with dialect applied but no language translation.
        return originalMsg, nil
    end

    if isNativeBlizz then
        return finalMsg, nil
    else
        return finalMsg, langKey
    end
end

-- Cache an original for later matching
local function CachePending(name, original, langKey)
    _pendingOriginals[name] = {
        original = original,
        langKey  = langKey,
        time     = GetTime(),
    }
end

-- Pop matching cached original for a sender
local function PopPending(sender, langTag)
    local now = GetTime()
    for k, v in pairs(_pendingOriginals) do
        if now - v.time > 10 then _pendingOriginals[k] = nil end
    end

    local shortName = sender and (sender:match("^([^-]+)") or sender) or ""
    local playerName = UnitName("player")
    for _, name in ipairs({shortName, sender or "", playerName}) do
        local entry = _pendingOriginals[name]
        if entry and entry.langKey == langTag then
            _pendingOriginals[name] = nil
            return entry.original
        end
    end
    return nil
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

-- Send original on hidden addon channel and cache locally.
-- For ANY chat type (including SAY/YELL), we broadcast on whatever
-- group channel is available so party/raid/guild members with the
-- addon can decode it even when the visible message is in /say.
function Speaketh_SendOriginal(original, langKey, chatType, target)
    -- Always cache locally so own messages work, regardless of network state
    local playerName = UnitName("player") or ""
    CachePending(playerName, original, langKey)

    -- Never try to send before the client is fully in-world
    if not IsLoggedIn or not IsLoggedIn() then return end

    local payload = langKey .. "|" .. original

    -- If whispering, send on whisper channel
    if chatType == "WHISPER" and target and target ~= "" then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "WHISPER", target)
        return
    end

    -- Broadcast on all available group channels so anyone in
    -- party/raid/guild/instance can decode regardless of chat type.
    -- Each call is independently guarded so one failing channel never
    -- prevents the others (or breaks chat).
    if IsInRaid and IsInRaid() then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "RAID")
    elseif IsInGroup and IsInGroup() then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "PARTY")
    end
    if IsInGuild and IsInGuild() then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "GUILD")
    end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SafeSendAddonMessage(SPEAKETH_PREFIX, payload, "INSTANCE_CHAT")
    end

    -- Broadcast on the hidden out-of-band channel so any Speaketh user on the
    -- same realm+faction can decode, even if we share no party/raid/guild.
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
-- hook itself — it's that Speaketh_SendOriginal fires addon-channel
-- broadcasts, and some of those channels become restricted during
-- rated timers. If that errors mid-hook, the editbox text never gets
-- modified properly. Everything from that point is wrapped so that a
-- failing addon broadcast can't block the chat send.
-- ============================================================
local _inTranslation = false

local function Speaketh_ProcessOutgoing(editBox)
    if _inTranslation then return end

    -- If auto-chat is off, don't process normal chat editboxes
    if Speaketh_Char and Speaketh_Char.autoChat == false then return end

    if not editBox or type(editBox.GetText) ~= "function" then return end

    local text = editBox:GetText()
    if not text or text == "" then return end

    -- Leave slash commands alone — they're WoW instructions, not chat.
    -- Check after stripping any leading whitespace so e.g. " /target" still
    -- passes through untouched.
    local firstNonSpace = text:match("^%s*(.)")
    if firstNonSpace == "/" then return end

    local chatType = (editBox.GetAttribute and editBox:GetAttribute("chatType")) or "SAY"
    if not TRANSLATE_ON_SEND[chatType] then return end

    local langKey = Speaketh:GetLanguage()
    local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
    local quotesOnly = DIALECT_QUOTES_ONLY[chatType]

    -- "None" = no language translation, but still apply active dialect
    if langKey == "None" then
        if not dialect then return end

        local finalMsg
        if quotesOnly then
            finalMsg = ApplyDialectToQuotes(text, langKey)
        else
            finalMsg = BuildTranslatedMsg(text, langKey)
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
    local finalMsg = BuildTranslatedMsg(text, langKey)
    if not finalMsg or finalMsg == "" then return end

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
    CachePending(shortName, original, langKey)
    if sender ~= shortName then
        CachePending(sender, original, langKey)
    end
end)

-- ============================================================
-- Incoming: chat filter for fluency-based understanding
-- ============================================================

local function BlendMessages(original, translated, fluency)
    if fluency >= 100 then return original end
    if fluency <= 0 then return translated end

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
    local revealed = {}
    for i = 1, total do
        local seed = (i * 7 + total * 13) % 100
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

    return table.concat(result)
end

-- Incoming chat filter for fluency-based understanding.
-- This is called by Blizzard's chat frame pipeline for each filter event
-- registered below. Kept simple — no pcall wrapping — because the original
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

    -- Look up original from cache (self-messages or addon messages from group)
    local original = PopPending(sender, langKey)
    if original then
        if fluency >= 100 then
            return false, "[" .. langTag .. "] " .. original, sender, ...
        elseif fluency > 0 then
            local blended = BlendMessages(original, body, fluency)
            return false, "[" .. langTag .. "] " .. blended, sender, ...
        end
    end

    return false
end

local FILTER_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
}

local function Speaketh_RegisterChatFilters()
    for _, event in ipairs(FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, Speaketh_ChatFilter)
    end
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- combat / lockdown begins
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- combat / lockdown ends

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

        -- Migrate old drunkLevel to new dialectLevels system
        if Speaketh_Char.drunkLevel and Speaketh_Char.drunkLevel > 0 then
            if not Speaketh_Char.dialectLevels then
                Speaketh_Char.dialectLevels = {}
            end
            if not Speaketh_Char.dialectLevels["Drunk"] then
                Speaketh_Char.dialectLevels["Drunk"] = Speaketh_Char.drunkLevel
            end
            if not Speaketh_Char.dialect then
                Speaketh_Char.dialect = "Drunk"
            end
        end

    elseif event == "PLAYER_LOGIN" then
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

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat / instance lockdown has begun. Translation is suspended to
        -- avoid tainting protected frames (ADDON_ACTION_BLOCKED on SendChatMessage).
        if Speaketh_Char and Speaketh_Char.showLockdownNotify ~= false then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Combat lockdown active -- translation temporarily disabled.")
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat / lockdown has ended; translation resumes automatically.
        if Speaketh_Char and Speaketh_Char.showLockdownNotify ~= false then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Lockdown lifted -- translation resumed.")
        end
    end
end)

-- ============================================================
-- Splash screen — native-style, matches the Speak Window chrome
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
        f:SetSize(460, 460)
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
            f:SetBackdropColor(0.08, 0.08, 0.10, 0.97)
            f:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
        end

        -- Title
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
        title:SetText("Speaketh")
        title:SetTextColor(1, 1, 1, 1)

        local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
        ver:SetTextColor(0.55, 0.55, 0.60, 1)
        ver:SetText("v1.0  —  Roleplay Language Addon")

        local div1 = f:CreateTexture(nil, "ARTWORK")
        div1:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -36)
        div1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -36)
        div1:SetHeight(1)
        div1:SetColorTexture(0.55, 0.45, 0.20, 0.9)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- Features
        local featHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        featHead:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -48)
        featHead:SetTextColor(1.0, 0.82, 0.0, 1)
        featHead:SetText("Features")

        local features = {
            "20+ lore-accurate racial & exotic languages",
            "Custom languages — define your own word pools",
            "Language sharing — export/import codes for custom languages",
            "Dialect system — Gilnean, Troll, Drunk, and more",
            "Custom dialects — build your own word-swap accents",
            "Fluency system — 0-100% per language, passive learning",
            "Cross-player decoding — party, raid, guild, whisper & /say",
            "Passthrough words — names that never get translated",
            "Minimap button & floating language HUD",
        }

        for i, line in ipairs(features) do
            local ft = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ft:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -66 - (i - 1) * 15)
            ft:SetText("- " .. line)
        end

        local div2 = f:CreateTexture(nil, "ARTWORK")
        div2:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -210)
        div2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -210)
        div2:SetHeight(1)
        div2:SetColorTexture(0.55, 0.45, 0.20, 0.5)

        -- Commands
        local cmdHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cmdHead:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -222)
        cmdHead:SetTextColor(1.0, 0.82, 0.0, 1)
        cmdHead:SetText("Commands")

        local commands = {
            {"/sp  or  /speaketh",   "Open this splash screen"},
            {"/sp options",          "Open the settings panel"},
            {"/sp window",           "Open the Speak Window"},
            {"/sp <language>",       "Switch language  (e.g. /sp orcish)"},
            {"/sp none",             "Disable translation"},
            {"/sp cycle",            "Cycle to next known language"},
            {"/sp dialect <name>",   "Set dialect  (gilnean, troll, drunk...)"},
            {"/sp drunk <0-3>",      "Set drunkenness level"},
            {"/sp share <language>", "Generate an import code"},
            {"/sp import <code>",    "Import a custom language"},
            {"/sp list",             "List all languages & fluency"},
        }

        for i, cmd in ipairs(commands) do
            local ct = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ct:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -240 - (i - 1) * 14)
            ct:SetText(cmd[1])
            local cd = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cd:SetPoint("LEFT", ct, "LEFT", 170, 0)
            cd:SetText("- " .. cmd[2])
            cd:SetTextColor(0.70, 0.70, 0.75, 1)
        end

        local div3 = f:CreateTexture(nil, "ARTWORK")
        div3:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -400)
        div3:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -400)
        div3:SetHeight(1)
        div3:SetColorTexture(0.55, 0.45, 0.20, 0.5)

        -- Footer
        local footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        footer:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -412)
        self.SplashFooter = footer

        self.SplashFrame = f
    end

    -- Update footer with current language and dialect
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

    elseif cmd == "cycle" then
        Speaketh:CycleLanguage()

    elseif cmd == "list" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh] Known languages:|r")
        for _, key in ipairs(Speaketh_LanguageOrder) do
            local f = Speaketh_Fluency:Get(key)
            local cur = (Speaketh:GetLanguage() == key) and " |cff00ff00<speaking>|r" or ""
            if f > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "  |cff88ccff%s|r — %d%%%s", Speaketh:GetLanguageDisplayName(key), math.floor(f), cur))
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh] Unknown languages:|r")
        for _, key in ipairs(Speaketh_LanguageOrder) do
            local f = Speaketh_Fluency:Get(key)
            if f == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "  |cff666666%s|r — unknown", Speaketh:GetLanguageDisplayName(key)))
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
                if dk:lower():find(rest:lower(), 1, true) then
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

    elseif cmd == "drunk" then
        local level = tonumber(rest) or 0
        level = math.max(0, math.min(3, level))
        Speaketh_Dialects:SetDrunkLevel(level)
        -- Auto-activate Drunk dialect if setting level > 0
        if level > 0 then
            Speaketh_Dialects:SetActive("Drunk")
        end
        local labels = {[0]="Sober", [1]="Tipsy", [2]="Drunk", [3]="Smashed"}
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[Speaketh]|r Drunkenness set to %d (%s).", level, labels[level]))
        if Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
            Speaketh_UI:RefreshWindow()
        end

    elseif cmd == "share" then
        -- /sp share <language>  — prints an import code to chat for copy-paste sharing
        local input = strtrim(rest):lower()
        if input == "" then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffcc00[Speaketh]|r Usage: /sp share <language>  — generates an import code")
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
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r Import code — copy everything below:")
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff" .. code .. "|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[Speaketh]|r " .. (err or "Export failed."))
            end
        end

    elseif cmd == "import" then
        -- /sp import <code>  — import a language from a code string
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
