-- Speaketh_API.lua
-- Stable public API for external addons (chat splitters like EmoteScribe,
-- listener/snooper addons like Spyglass and Listener, chat-log addons, etc.).
--
-- See API.md at the root of the addon for the full developer guide and the
-- compatibility contract. In short:
--   - Speaketh.API.VERSION is bumped on breaking changes.
--   - Anything exposed on Speaketh.API is considered stable for that version.
--   - Everything on Speaketh.Internal is fair game to change between releases;
--     don't bind to it from other addons.

Speaketh       = Speaketh or {}
Speaketh.API   = Speaketh.API or {}

local API = Speaketh.API

-- Bump on breaking signature changes. Additive changes (new methods, new
-- event fields appended) do NOT bump. Consumers may gate on:
--     if Speaketh and Speaketh.API and Speaketh.API.VERSION >= N then ...
API.VERSION = 1

-- ============================================================
-- Embedded minimal callback dispatcher
--
-- Implemented inline instead of depending on Ace3's CallbackHandler-1.0
-- because Speaketh ships with no external library dependencies and we
-- want to keep it that way. The semantics below mirror the subset of
-- CallbackHandler-1.0 that consumers typically use:
--   API.RegisterCallback(owner, eventName, handler [, arg])
--   API.UnregisterCallback(owner, eventName)
--   API.UnregisterAllCallbacks(owner)
--
-- `handler` can be either:
--   - a function    f(eventName, ...)
--   - a method-name string "MyMethod"   -> calls owner:MyMethod(eventName, ...)
--
-- If a 4th `arg` is provided, it's passed as the first parameter BEFORE
-- eventName, matching CallbackHandler convention:
--     owner:MyMethod(arg, eventName, ...)
-- ============================================================
local _callbacks = {}  -- [eventName] = { [owner] = {handler=..., arg=...} }

local function resolveHandler(owner, handler)
    if type(handler) == "function" then
        return handler
    elseif type(handler) == "string" and type(owner) == "table" and type(owner[handler]) == "function" then
        return function(...) return owner[handler](owner, ...) end
    end
    return nil
end

function API.RegisterCallback(owner, eventName, handler, arg)
    if type(eventName) ~= "string" or eventName == "" then return end
    if owner == nil then return end
    -- handler defaults to a method on owner with the same name as the event
    if handler == nil then handler = eventName end
    local fn = resolveHandler(owner, handler)
    if not fn then return end
    _callbacks[eventName] = _callbacks[eventName] or {}
    _callbacks[eventName][owner] = { fn = fn, arg = arg }
end

function API.UnregisterCallback(owner, eventName)
    if _callbacks[eventName] then
        _callbacks[eventName][owner] = nil
    end
end

function API.UnregisterAllCallbacks(owner)
    for event, subs in pairs(_callbacks) do
        subs[owner] = nil
    end
end

-- Fire an event. Internal use only, but exposed on Speaketh.API so that
-- the rest of the addon can call Speaketh.API:Fire("...") without having
-- a reference to this file's locals. Consumers should NOT call Fire
-- themselves.
--
-- Any handler that throws is isolated via pcall so a single bad consumer
-- cannot break Speaketh's translation path or any other consumer.
function API:Fire(eventName, ...)
    local subs = _callbacks[eventName]
    if not subs then return end
    for owner, entry in pairs(subs) do
        if entry.arg ~= nil then
            pcall(entry.fn, entry.arg, eventName, ...)
        else
            pcall(entry.fn, eventName, ...)
        end
    end
end

-- ============================================================
-- Helpers
-- ============================================================
local function isLocked()
    return Speaketh.Internal and Speaketh.Internal.IsLocked
           and Speaketh.Internal:IsLocked()
end

-- Per-channel toggle lookup: returns false only if the user has explicitly
-- disabled translation for this chat type. Anything not in the table (or
-- unknown) defaults to true.
local CHAN_KEY = {
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
local function channelEnabled(chatType)
    if not Speaketh_Char or not chatType then return true end
    local key = CHAN_KEY[chatType]
    if not key then return true end
    return Speaketh_Char[key] ~= false
end

-- Resolve a user-supplied language identifier to a canonical key.
-- Accepts either an internal key ("Orcish", "CustomLang_Foxy") or a
-- display name ("Foxy"). Returns nil if nothing matches.
local function resolveLangKey(input)
    if not input or input == "" then return nil end
    if input == "None" then return "None" end
    if not Speaketh_Languages then return nil end
    if Speaketh_Languages[input] then return input end
    for k, data in pairs(Speaketh_Languages) do
        if data.name == input then return k end
    end
    return nil
end

-- ============================================================
-- Translation -- for chat splitters (EmoteScribe, Emote Splitter, etc.)
-- ============================================================

-- API:Translate(text, opts) -> translatedText, tagLangKey, status
--
--   text     (string)   required; the message as the user typed it.
--   opts     (table)    optional; any of:
--       langKey    override the active language (accepts display name too)
--       chatType   "SAY" | "YELL" | "PARTY" | ... | "EMOTE"
--                  Affects quotes-only behaviour for EMOTE. Defaults to "SAY".
--       ignoreChannelToggle  set true to bypass the user's per-channel
--                            disable (rarely what you want).
--       ignoreLockdown       set true to translate even during combat /
--                            rated lockdown. NOT RECOMMENDED: if you
--                            write the translated text anywhere into the
--                            secure send path you will taint it.
--
-- Returns:
--   translatedText (string)   the string you should put on the wire.
--   tagLangKey     (string?)  non-nil if a "[LanguageName] " prefix was
--                             prepended. When non-nil, the caller MUST
--                             also call API:BroadcastOriginal() so other
--                             Speaketh users on the channel can decode it.
--                             When nil, no broadcast is needed (native
--                             Blizzard language, "None", or a skip).
--   status         (string)   diagnostic:
--                    "ok"         translation applied
--                    "passthrough" no translation needed (None + no dialect,
--                                  channel disabled, lockdown, etc.)
--                    "unknown-language"
--                    "not-fluent" fluency is 0; nothing translated
--
-- Does NOT send anything. Does NOT broadcast. Caller is responsible for
-- calling SendChatMessage (or equivalent) with translatedText, and then
-- calling API:BroadcastOriginal(...) if tagLangKey is non-nil.
function API:Translate(text, opts)
    if type(text) ~= "string" or text == "" then
        return text or "", nil, "passthrough"
    end
    opts = opts or {}

    local chatType = opts.chatType

    -- Respect user's per-channel toggle unless caller explicitly overrides.
    if not opts.ignoreChannelToggle and not channelEnabled(chatType) then
        return text, nil, "passthrough"
    end

    -- Respect lockdown unless caller explicitly overrides.
    if not opts.ignoreLockdown and isLocked() then
        return text, nil, "passthrough"
    end

    -- Resolve language
    local langKey
    if opts.langKey then
        langKey = resolveLangKey(opts.langKey)
        if not langKey then return text, nil, "unknown-language" end
    else
        langKey = Speaketh:GetLanguage() or "None"
    end

    -- Fluency gate for non-None languages (matches built-in chat hook)
    if langKey ~= "None" then
        if not Speaketh_Fluency or Speaketh_Fluency:Get(langKey) == 0 then
            return text, nil, "not-fluent"
        end
    end

    -- Emote with language: quotes-only path (matches built-in hook behaviour).
    local DIALECT_QUOTES_ONLY = { EMOTE = true }
    if DIALECT_QUOTES_ONLY[chatType] and langKey ~= "None" then
        local final = Speaketh.Internal:ApplyDialectToQuotes(text, langKey)
        if not final or final == "" then return text, nil, "passthrough" end
        -- Emote quotes carry their translation inline; caller should still
        -- broadcast so the receiving emote filter can decode. Report langKey
        -- as the broadcast tag so the caller knows to broadcast.
        return final, langKey, "ok"
    end

    -- "None" with no active dialect is a full passthrough.
    if langKey == "None" then
        local dialect = Speaketh_Dialects and Speaketh_Dialects:GetActive()
        if not dialect then
            return text, nil, "passthrough"
        end
    end

    local final, tagLangKey = Speaketh.Internal:BuildTranslatedMsg(text, langKey)
    if not final or final == "" then
        return text, nil, "passthrough"
    end
    -- BuildTranslatedMsg silently returns the original text (not the
    -- translated text, and with tagLangKey = nil) when the translated
    -- form would exceed WoW's ~255-byte chat limit. We need to surface
    -- that case to the caller so chat splitters (e.g. EmoteScribe) know
    -- to shrink their chunk size and retry instead of sending raw.
    if tagLangKey == nil and langKey ~= "None" and final == text then
        -- langKey is set and non-None, but BuildTranslatedMsg returned a
        -- nil tag AND unchanged text. That only happens on the length
        -- fallback path. (A native Blizzard language also returns nil
        -- tag, but it returns translated -- not equal to text -- so it
        -- doesn't match this branch.)
        -- Double-check we're not in the native-Blizz case:
        local langData = Speaketh_Languages and Speaketh_Languages[langKey]
        local isNativeBlizz = false
        if langData and langData.blizzard and GetNumLanguages then
            for i = 1, GetNumLanguages() do
                if GetLanguageByIndex(i) == langData.blizzard then
                    isNativeBlizz = true
                    break
                end
            end
        end
        if not isNativeBlizz then
            return text, nil, "too-long"
        end
    end
    return final, tagLangKey, "ok"
end

-- API:BroadcastOriginal(original, langKey, chatType, target)
--
-- Broadcasts the original (pre-translation) text on Speaketh's hidden
-- addon-message channels (party/raid/guild/instance/whisper + the OOB
-- channel for /say and /yell out-of-group decoding).
--
-- Call this AFTER SendChatMessage so other Speaketh users can decode
-- what they receive. You only need to call this when API:Translate
-- returned a non-nil tagLangKey.
--
-- original  (string)   the pre-translation text exactly as you'd have
--                      broadcast if you were sending the whole message
--                      in one piece. For split chunks, pass the chunk's
--                      original (pre-translation) text.
-- langKey   (string)   the key returned as tagLangKey from API:Translate.
-- chatType  (string)   matches the chatType you passed to Translate.
-- target    (string?)  for WHISPER only: recipient name.
function API:BroadcastOriginal(original, langKey, chatType, target)
    if type(original) ~= "string" or original == "" then return end
    if not langKey or langKey == "None" then return end
    if Speaketh_SendOriginal then
        pcall(Speaketh_SendOriginal, original, langKey, chatType or "SAY", target)
    end
end

-- API:Decode(sender, msg, langTag) -> decoded, langKey, fluency, original
--
-- Given a message as it arrives from a CHAT_MSG_* event, return the
-- fluency-adjusted decoded form that the local player would see, plus
-- metadata. Non-destructive: does NOT consume the pending-originals
-- cache, so Speaketh's own chat filter still runs normally on this
-- message afterwards.
--
-- Intended for listener/snooper/log addons that want to store a decoded
-- copy of the message for their own UI. Note that in most cases you
-- should subscribe to the OnMessageDecoded event instead -- it's the
-- canonical hook and it fires exactly once per decoded message, with
-- the same information this function returns. Use API:Decode only if
-- you genuinely need a pull-style interface (e.g. replaying history).
--
-- sender   (string)   full sender name including realm (as WoW provides).
-- msg      (string)   the message body as received. If it has a
--                     "[LanguageName] " prefix, pass the whole thing and
--                     leave langTag nil -- we'll parse.
-- langTag  (string?)  optional; the bracketed language display name if
--                     you've already parsed it out. Saves one gmatch.
--
-- Returns nil if Speaketh has no cached original for this sender
-- (message came from a non-Speaketh user, or the cache expired, or the
-- sender is simply not sending through Speaketh right now).
function API:Decode(sender, msg, langTag)
    if type(msg) ~= "string" or msg == "" then return nil end
    if not sender or sender == "" then return nil end
    if not Speaketh_Languages or not Speaketh_Fluency then return nil end

    local body = msg
    if not langTag then
        langTag, body = msg:match("^%[([^%]]+)%]%s(.+)$")
        if not langTag then return nil end
    end

    -- Resolve display name or key
    local langKey = resolveLangKey(langTag)
    if not langKey or langKey == "None" then return nil end

    -- Non-destructive peek into the pending cache. We intentionally use
    -- the Internal peek path (same algorithm as PopPending, without the
    -- removal) so the built-in chat filter still finds the entry.
    if not Speaketh.Internal or not Speaketh.Internal.PeekPending then
        return nil
    end
    local original = Speaketh.Internal:PeekPending(sender, langKey)
    if not original then return nil end

    local fluency = Speaketh_Fluency:Get(langKey)
    local decoded
    if fluency >= 100 then
        decoded = original
    elseif fluency > 0 then
        decoded = Speaketh.Internal:BlendMessages(original, body, fluency)
    else
        decoded = body
    end
    return decoded, langKey, fluency, original
end

-- ============================================================
-- Introspection
-- ============================================================

-- Returns the current active language key, or "None".
function API:GetCurrentLanguage()
    return (Speaketh and Speaketh.GetLanguage and Speaketh:GetLanguage()) or "None"
end

-- Returns the human-readable display name for a language key.
-- Built-in languages: key == display name.
-- Custom languages:   key is "CustomLang_X", display name is user-chosen.
function API:GetLanguageDisplayName(langKey)
    if Speaketh and Speaketh.GetLanguageDisplayName then
        return Speaketh:GetLanguageDisplayName(langKey)
    end
    return langKey
end

-- Fluency in langKey, 0-100.
function API:GetFluency(langKey)
    if not Speaketh_Fluency then return 0 end
    langKey = resolveLangKey(langKey) or langKey
    return Speaketh_Fluency:Get(langKey) or 0
end

-- Array of language keys the player has any fluency in (fluency > 0).
-- Returned in the same order as Speaketh_LanguageOrder so built-ins
-- come first in their canonical order, followed by custom languages
-- in the order they were registered.
function API:GetKnownLanguages()
    local out = {}
    if not Speaketh_LanguageOrder or not Speaketh_Fluency then return out end
    for _, key in ipairs(Speaketh_LanguageOrder) do
        if Speaketh_Fluency:Get(key) > 0 then
            table.insert(out, key)
        end
    end
    return out
end

-- Array of every language key Speaketh knows about, known or not.
function API:GetAllLanguages()
    local out = {}
    if not Speaketh_LanguageOrder then return out end
    for _, key in ipairs(Speaketh_LanguageOrder) do
        table.insert(out, key)
    end
    return out
end

-- True if langKey is a user-created custom language.
function API:IsCustomLanguage(langKey)
    if not Speaketh_Languages or not langKey then return false end
    local data = Speaketh_Languages[langKey]
    return data and data.isCustom == true or false
end

-- True when Speaketh is currently suspending translation because of
-- combat/rated/instanced lockdown. Splitters can check this to decide
-- whether to take the translation path at all.
function API:IsLocked()
    return isLocked() and true or false
end

-- ============================================================
-- Internal: PeekPending helper
--
-- Defined here (rather than in Speaketh.lua) because the pending cache
-- (_pendingOriginals) is file-local to Speaketh.lua. We install a small
-- peek function onto Speaketh.Internal from that file via the accessor
-- below. This file just declares the contract.
-- ============================================================
Speaketh.Internal = Speaketh.Internal or {}
