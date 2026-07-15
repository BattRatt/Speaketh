-- Speaketh_Chattery.lua
-- Optional compatibility with Chattery's chunking pipeline.
--
-- Chattery owns final message splitting through LibChatFilter. LibChatFilter
-- v1 provides public pre-send context but no post-split chunk callback, so the
-- context path is public while a narrow, capability-gated Chunker adapter remains
-- necessary. Keeping source and translated chunks paired preserves Speaketh's
-- fluency cache, addon payloads, and overhead glyph matching.

local compatFrame = CreateFrame("Frame")
local installed = false
local contextMutatorRegistered = false
local currentContext = nil

-- Exposed for Speaketh's Modules status panel. This is deliberately a simple
-- capability flag, not a configuration switch. Chattery compatibility remains
-- automatic whenever the required public pieces are available.
if Speaketh then Speaketh.ChatteryCompatibilityActive = false end

local function MarkInstalled()
    installed = true
    if Speaketh then Speaketh.ChatteryCompatibilityActive = true end
end

local function GetWhisperTarget(chatType)
    if chatType ~= "WHISPER" then return nil end
    if currentContext and currentContext.target then
        return currentContext.target
    end
    if not ChatFrameUtil or not ChatFrameUtil.GetLastActiveWindow then return nil end
    local editBox = ChatFrameUtil.GetLastActiveWindow()
    if editBox and editBox.GetTellTarget then
        return editBox:GetTellTarget()
    end
    return nil
end

-- Estimate the largest vocabulary expansion for the active language. Chattery
-- subtracts its own marker/padding overhead after receiving this adjusted
-- limit. The reserve covers Speaketh's language tag and modest dialect growth.
local function GetExpansionRatio()
    local langKey = Speaketh and Speaketh.GetLanguage and Speaketh:GetLanguage()
    if not langKey or langKey == "None" then
        return 2.0  -- dialect-only speech can still expand substitutions
    end

    local data = Speaketh_Languages and Speaketh_Languages[langKey]
    if not data then return 1.25 end

    local ratio = 1.0
    if type(data.words) == "table" then
        local randomLongest = 0
        for sourceLen, entries in pairs(data.words) do
            if type(sourceLen) == "number" and sourceLen > 0 and type(entries) == "table" then
                for _, replacement in ipairs(entries) do
                    if type(replacement) == "string" then
                        if #replacement > randomLongest then randomLongest = #replacement end
                        if not data.useRandom then
                            ratio = math.max(ratio, #replacement / sourceLen)
                        end
                    end
                end
            end
        end
        -- Random languages may select any vocabulary entry for any source word.
        if data.useRandom and randomLongest > 0 then
            ratio = math.max(ratio, randomLongest)
        end
    end

    if type(data.substitute) == "table" then
        for original, replacement in pairs(data.substitute) do
            if type(original) == "string" and #original > 0 and type(replacement) == "string" then
                ratio = math.max(ratio, #replacement / #original)
            end
        end
    end

    -- Reserve for the active effect. The final byte guard remains authoritative,
    -- but conservative source chunks keep non-Speaketh readers from losing the
    -- tail of a chunk when an effect expands it.
    local effect = Speaketh_Dialects and Speaketh_Dialects.GetActiveEffect
        and Speaketh_Dialects:GetActiveEffect()
    local level = effect and Speaketh_Dialects:GetLevel(effect) or 0
    local effectGrowth = 1.15
    if effect == "Lisp" then
        effectGrowth = 2.0
    elseif effect == "Stutter" then
        effectGrowth = ({1.20, 1.40, 1.70})[level] or 1.20
    elseif effect == "Drunk" then
        effectGrowth = ({1.25, 1.55, 2.00})[level] or 1.25
    elseif effect == "Hiss" or effect == "Growl" then
        effectGrowth = ({1.20, 1.35, 1.55})[level] or 1.20
    end

    return math.max(1.0, ratio * effectGrowth)
end

local function HasEnscriberOwnership()
    return Speaketh and Speaketh.IsExternalSplitterOwner
       and Speaketh:IsExternalSplitterOwner()
end

local function RegisterContextMutator()
    if contextMutatorRegistered then return true end
    if not LibStub or type(LibStub.GetLibrary) ~= "function" then return false end
    local lib = LibStub:GetLibrary("LibChatFilter", true)
    if not lib or type(lib.RegisterTransform) ~= "function" then return false end

    local ok = lib.RegisterTransform(function(message, context)
        if installed and context and not HasEnscriberOwnership()
           and Speaketh:WouldTranslate(context.chatType) then
            currentContext = context
            C_Timer.After(0, function()
                currentContext = nil
            end)
        end
        return message
    end, lib.Track and lib.Track.SEND or nil)

    contextMutatorRegistered = ok ~= false
    return contextMutatorRegistered
end

local function InstallCompatibility()
    if installed then return true end
    if not Speaketh or not Speaketh.WouldTranslate or not Speaketh.TranslateChunk then return false end
    if not Chattery or not Chattery.Chunker then return false end
    if type(Chattery.Chunker.SplitMessage) ~= "function" then return false end
    if Chattery.Chunker._SpeakethOriginalSplitMessage then
        MarkInstalled()
        RegisterContextMutator()
        return true
    end

    local chunker = Chattery.Chunker
    local originalSplit = chunker.SplitMessage
    chunker._SpeakethOriginalSplitMessage = originalSplit

    chunker.SplitMessage = function(message, chunkSize, chatType)
        chunkSize = chunkSize or 255
        if HasEnscriberOwnership() or not Speaketh:WouldTranslate(chatType) then
            return originalSplit(message, chunkSize, chatType)
        end

        local tagOverhead = Speaketh.GetTagOverhead and Speaketh:GetTagOverhead(chatType) or 0
        local usable = math.max(24, chunkSize - tagOverhead - 12)
        local sourceLimit = math.max(8, math.floor(usable / GetExpansionRatio()))
        local sourceChunks = originalSplit(message, sourceLimit, chatType)
        local target = GetWhisperTarget(chatType)
        currentContext = nil
        local translatedChunks = {}
        local translatedAll = true

        for i, sourceChunk in ipairs(sourceChunks) do
            local ok, translated = pcall(Speaketh.TranslateChunk, Speaketh, sourceChunk, chatType, target)
            if ok and translated and translated ~= "" then
                translatedChunks[i] = translated
            else
                translatedAll = false
                translatedChunks[i] = sourceChunk
            end
        end

        -- Chattery owns this send only after every chunk was translated. If a
        -- compatibility error occurs, leave the flag clear so Speaketh's normal
        -- edit-box callback can translate the outgoing text instead of silently
        -- sending it unchanged.
        if translatedAll and #translatedChunks > 0 then
            Speaketh.splitterBypassing = true
            C_Timer.After(0, function()
                if Speaketh then Speaketh.splitterBypassing = false end
            end)
        end

        return translatedChunks
    end

    MarkInstalled()
    RegisterContextMutator()
    return true
end

compatFrame:RegisterEvent("ADDON_LOADED")
compatFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Speaketh" or addonName == "Chattery" then
        if InstallCompatibility() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)

-- OptionalDeps normally loads Chattery first, so install immediately when both
-- addons are already available. The event path above handles either load order.
if InstallCompatibility() then
    compatFrame:UnregisterEvent("ADDON_LOADED")
end
