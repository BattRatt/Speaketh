-- Speaketh_Listener.lua
-- Optional compatibility with Listener's per-character chat history.
--
-- Listener records the raw CHAT_MSG_* payload in ListenerAddon.AddChatHistory.
-- Wrap that single storage boundary and replace only messages for which
-- Speaketh has a matching, short-lived original-text payload. The public
-- decoder is non-destructive, so Speaketh's normal chat-frame filter can still
-- consume its own cache entry and render the same message in every chat tab.

if Speaketh then Speaketh.ListenerCompatibilityActive = false end

local function InstallListenerCompatibility()
    local listener = _G.ListenerAddon
    if not listener or type(listener.AddChatHistory) ~= "function" then
        return false
    end
    if listener._SpeakethOriginalAddChatHistory then
        if Speaketh then Speaketh.ListenerCompatibilityActive = true end
        return true
    end
    if not Speaketh or not Speaketh.API
       or type(Speaketh.API.Decode) ~= "function" then
        return false
    end

    local originalAddChatHistory = listener.AddChatHistory
    listener._SpeakethOriginalAddChatHistory = originalAddChatHistory

    listener.AddChatHistory = function(sender, event, message, ...)
        local storedMessage = message

        if type(sender) == "string" and sender ~= ""
           and type(message) == "string" and message ~= "" then
            local languageTag = message:match("^%[([^%]]+)%]%s.+$")
            if languageTag then
                local ok, decoded = pcall(
                    Speaketh.API.Decode,
                    Speaketh.API,
                    sender,
                    message,
                    nil,
                    event)

                if ok and type(decoded) == "string" then
                    -- Decode returns the fluency-adjusted body. Listener should
                    -- retain the visible language label just like chat does.
                    storedMessage = "[" .. languageTag .. "] " .. decoded
                end
            end
        end

        return originalAddChatHistory(sender, event, storedMessage, ...)
    end

    Speaketh.ListenerCompatibilityActive = true
    return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Speaketh" or addonName == "Listener" then
        if InstallListenerCompatibility() then
            loader:UnregisterEvent("ADDON_LOADED")
        end
    end
end)

-- OptionalDeps normally loads Listener first, so install immediately when both
-- addons are already available.
InstallListenerCompatibility()
