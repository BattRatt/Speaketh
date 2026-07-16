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
    if not Speaketh or not Speaketh.WouldTranslate or not Speaketh.TranslateChunk
       or not Speaketh.Internal
       or type(Speaketh.Internal.PrepareSplitterChunk) ~= "function"
       or type(Speaketh.Internal.CommitSplitterChunk) ~= "function" then
        return false
    end
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

        local targetLimit = math.max(24, math.min(chunkSize, 250))
        local target = GetWhisperTarget(chatType)
        currentContext = nil
        local translatedChunks = {}
        local translatedAll = true
        local sourceLimit = targetLimit
        local finalSources, finalPreviews

        -- Reflow the complete line whenever a concrete transformation is too
        -- large. This keeps middle chunks balanced instead of emitting the
        -- short tail of one independently subdivided source chunk.
        for attempt = 1, 7 do
            local sources = originalSplit(message, sourceLimit, chatType)
            if type(sources) ~= "table" then
                return originalSplit(message, chunkSize, chatType)
            end

            local previews = {}
            local allSafe = true
            local nextLimit = math.max(24, sourceLimit - 1)

            for _, source in ipairs(sources) do
                local ok, translated, langKey, oversized = pcall(
                    Speaketh.Internal.PrepareSplitterChunk,
                    Speaketh.Internal, source, chatType)
                local tooLong = not ok or not translated or translated == ""
                    or oversized or #translated > targetLimit

                if tooLong then
                    allSafe = false
                    if ok and translated and translated ~= ""
                       and #source > 24 then
                        local fitRatio = targetLimit
                            / math.max(1, #translated)
                        local measuredLimit = math.floor(
                            #source * fitRatio * 0.97)
                        nextLimit = math.min(nextLimit,
                            math.max(24, measuredLimit))
                    end
                    table.insert(previews, { source = source })
                else
                    table.insert(previews, {
                        source = source,
                        translated = translated,
                        langKey = langKey,
                    })
                end
            end

            finalSources = sources
            finalPreviews = previews
            if allSafe or sourceLimit <= 24 then break end
            sourceLimit = math.max(24,
                math.min(sourceLimit - 1, nextLimit))
        end

        -- Commit only the final reflow. Earlier previews were measurements and
        -- must not create extra original-text payloads.
        for i, source in ipairs(finalSources or {}) do
            local preview = finalPreviews and finalPreviews[i]
            if preview and preview.translated then
                Speaketh.Internal:CommitSplitterChunk(
                    source, preview.langKey, chatType, target)
                table.insert(translatedChunks, preview.translated)
            else
                -- Indivisible long words and preview failures retain the core
                -- guarded fallback so Chattery's queue cannot become blocked.
                local guardedOK, guarded = pcall(
                    Speaketh.TranslateChunk,
                    Speaketh, source, chatType, target)
                if guardedOK and guarded and guarded ~= "" then
                    table.insert(translatedChunks, guarded)
                else
                    translatedAll = false
                    table.insert(translatedChunks, source)
                end
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
