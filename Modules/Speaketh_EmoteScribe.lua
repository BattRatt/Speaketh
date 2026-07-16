-- Speaketh_EmoteScribe.lua
-- Exact-size compatibility for EmoteScribe/Enscriber's splitting pipeline.
--
-- EmoteScribe splits source text before Speaketh applies expanding effects.
-- This adapter previews the actual transformed result, recursively subdivides
-- only a chunk that is genuinely oversized, and reuses that exact preview for
-- sending. Reusing it matters for randomized effects such as Lisp and Stutter:
-- a second transformation pass could otherwise produce a different length.

local compatFrame = CreateFrame("Frame")
local installed = false

if Speaketh then Speaketh.EmoteScribeCompatibilityActive = false end

local function MarkInstalled()
    installed = true
    if Speaketh then Speaketh.EmoteScribeCompatibilityActive = true end
end

local function InstallCompatibility()
    if installed then return true end
    if not Speaketh or type(Speaketh.WouldTranslate) ~= "function"
       or not Speaketh.Internal
       or type(Speaketh.Internal.PrepareSplitterChunk) ~= "function"
       or type(Speaketh.Internal.CommitSplitterChunk) ~= "function" then
        return false
    end
    if not C_AddOns or not C_AddOns.IsAddOnLoaded
       or not C_AddOns.IsAddOnLoaded("EmoteScribe") then
        return false
    end

    -- Enscriber does not currently expose pre-split transforms. Keep this
    -- private adapter narrow and capability-gated until its public API does.
    local internal = LibEnscriber and LibEnscriber.Internal
    if not internal or type(internal.AddChat) ~= "function"
       or type(internal.SplitMessage) ~= "function" then
        return false
    end

    if internal._SpeakethDynamicSplitOriginalAddChat then
        MarkInstalled()
        return true
    end

    local originalAddChat = internal.AddChat
    internal._SpeakethDynamicSplitOriginalAddChat = originalAddChat

    internal.AddChat = function(msg, chatType, arg3, target)
        local normalizedType = tostring(chatType or "SAY"):upper()
        if not Speaketh:WouldTranslate(normalizedType) then
            return originalAddChat(msg, chatType, arg3, target)
        end

        local originalSplit = internal.SplitMessage
        local originalTranslateChunk = Speaketh.TranslateChunk
        local prepared = {}

        -- Use EmoteScribe's own word/link/RP-aware splitter for every pass.
        -- If a preview is oversized, reflow the whole line at the measured
        -- safe source size. This avoids creating a tiny middle chunk from the
        -- tail of one independently subdivided 250-byte chunk.
        internal.SplitMessage = function(text, chunkSize, splitmarkStart, splitmarkEnd)
            local targetLimit = math.max(24, math.min(chunkSize or 255, 250))
            local sourceLimit = targetLimit
            local final, finalPrepared

            for attempt = 1, 7 do
                local chunks = originalSplit(
                    text, sourceLimit, splitmarkStart, splitmarkEnd)
                if type(chunks) ~= "table" then return chunks end

                local attemptPrepared = {}
                local allSafe = true
                local nextLimit = math.max(24, sourceLimit - 1)

                for _, source in ipairs(chunks) do
                    local ok, translated, langKey, oversized = pcall(
                        Speaketh.Internal.PrepareSplitterChunk,
                        Speaketh.Internal, source, normalizedType)
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
                        table.insert(attemptPrepared, { source = source })
                    else
                        table.insert(attemptPrepared, {
                            source = source,
                            translated = translated,
                            langKey = langKey,
                        })
                    end
                end

                final = chunks
                finalPrepared = attemptPrepared
                if allSafe or sourceLimit <= 24 then break end
                sourceLimit = math.max(24,
                    math.min(sourceLimit - 1, nextLimit))
            end

            -- Only the final reflow's previews correspond to the chunks that
            -- will actually be queued. Failed/indivisible previews deliberately
            -- fall through to TranslateChunk's guarded result.
            for _, entry in ipairs(finalPrepared or {}) do
                table.insert(prepared, entry)
            end

            -- Enscriber calculated this flag before AddChat. Correct it before
            -- QueueChat sees chunk one so chunk two waits for its server echo.
            if internal.capturing_first_chunk and #final > 1 then
                internal.editbox_needs_split = true
            end

            return final
        end

        Speaketh.TranslateChunk = function(self, source, queuedType, queuedTarget)
            local entry = prepared[1]
            local queuedNormalized = tostring(queuedType or "SAY"):upper()
            if entry and entry.source == source
               and queuedNormalized == normalizedType then
                table.remove(prepared, 1)
                if entry.translated then
                    Speaketh.Internal:CommitSplitterChunk(
                        source, entry.langKey, queuedNormalized, queuedTarget)
                    return entry.translated
                end
            end
            return originalTranslateChunk(self, source, queuedType, queuedTarget)
        end

        local ok, a, b, c, d = pcall(
            originalAddChat, msg, chatType, arg3, target)
        internal.SplitMessage = originalSplit
        Speaketh.TranslateChunk = originalTranslateChunk

        if not ok then error(a, 0) end
        return a, b, c, d
    end

    MarkInstalled()
    return true
end

compatFrame:RegisterEvent("ADDON_LOADED")
compatFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Speaketh" or addonName == "EmoteScribe" then
        if InstallCompatibility() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)

if InstallCompatibility() then
    compatFrame:UnregisterEvent("ADDON_LOADED")
end
