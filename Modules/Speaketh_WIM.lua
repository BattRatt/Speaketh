-- WIM bypasses Blizzard's edit-box pre-send event. Adapt its own send entry
-- point, never replace the global/protected SendChatMessage function.
-- Verified against WIM Modules/WhisperEngine.lua, SendSplitMessage.
Speaketh.WIMCompatibilityActive = false
local installed, wrapper

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function Speaketh:GetWIMCompatibilityStatus()
    if not WIM then return "Not detected" end
    if not installed or WIM.SendSplitMessage ~= wrapper then return "Unavailable" end
    if not WIM.db or WIM.db.enabled == false then return "Disabled" end
    return "Active"
end

local function IsBattleNet(wim, target)
    local key = target:lower()
    local name, realm = key:match("^(.-)%-(.*)$")
    if realm and wim.env and wim.env.realm and realm == wim.env.realm:lower() then key = name end
    local windows = wim.windows and wim.windows.active and wim.windows.active.whisper
    local window = windows and windows[key]
    -- WIM passes WHISPER even for Battle.net windows; its window flag chooses
    -- the actual transport. Do not send a character-language payload for those.
    return window and window.isBN
end

-- Find boundaries without cutting a hyperlink, texture, color span or OOC
-- parentheses. Ordinary long words may split on a UTF-8 character boundary.
local function SplitSource(text)
    local middle, best, charCut = math.floor(#text / 2), nil, nil
    local depth, colored, action, i = 0, false, false, 1
    local later
    while i <= #text do
        local pair = text:sub(i, i + 1)
        local stop
        if pair == "|H" then
            local label = text:find("|h", i + 2, true)
            stop = label and text:find("|h", label + 2, true)
        elseif pair == "|T" then stop = text:find("|t", i + 2, true)
        elseif pair == "|A" then stop = text:find("|a", i + 2, true)
        elseif pair == "|K" then stop = text:find("|k", i + 2, true) end
        if stop then i = stop + 2
        elseif text:sub(i,i+2) == "|cn" then
            local ending=text:find(":",i+3,true)
            if not ending then return end
            colored=true;i=ending+1
        elseif pair == "|c" then colored = true; i = i + 10
        elseif pair == "||" then i = i + 2
        elseif text:sub(i,i)=="{" and text:find("^{%w+}",i) then
            local _,ending=text:find("^{%w+}",i);i=ending+1
        elseif pair == "|r" then colored = false; i = i + 2
        else
            local c = text:sub(i,i)
            if c == "(" then depth = depth + 1 elseif c == ")" then depth = math.max(0,depth - 1) end
            if c == "*" then action = not action end
            local byte = text:byte(i)
            if depth == 0 and not colored and not action and i > 1 and c ~= ")" and c ~= "*" then
                if i <= middle then
                    if c:match("%s") then best = i end
                    if byte < 128 or byte >= 192 then charCut = i end
                elseif not later and (byte < 128 or byte >= 192) then later = i end
            end
            i = i + 1
        end
    end
    local cut = best or charCut or later
    if not cut then return end
    return text:sub(1,cut-1), text:sub(cut)
end

local function Prepare(text, output, depth)
    local translated, language, oversized = Speaketh.Internal:PrepareSplitterChunk(text, "WHISPER")
    if translated and translated ~= "" and not oversized and #translated <= 250 then
        output[#output+1] = {source=text, text=translated, language=language}
        return true
    end
    if depth >= 20 then return false end
    local left, right = SplitSource(text)
    if not left or left == "" or right == "" then return false end
    return Prepare(left,output,depth+1) and Prepare(right,output,depth+1)
end

local function Install()
    if installed then return true end
    local wim = WIM
    if not wim or type(wim.SendSplitMessage) ~= "function"
       or not Speaketh.Internal or type(Speaketh.Internal.PrepareSplitterChunk) ~= "function"
       or type(Speaketh.Internal.CommitSplitterChunk) ~= "function" then return false end
    local original = wim.SendSplitMessage
    wrapper = function(priority, header, message, channel, languageID, target, ...)
        if IsSecret(message) or IsSecret(channel) or IsSecret(target)
           or channel ~= "WHISPER" or type(message) ~= "string" or message == ""
           or type(target) ~= "string" or target == "" or not wim.db or wim.db.enabled == false
           or IsBattleNet(wim,target) or not Speaketh:WouldTranslate("WHISPER") then
            return original(priority,header,message,channel,languageID,target,...)
        end
        local chunks = {}
        -- Apply WIM's separators before measuring, so its subsequent pass
        -- cannot expand a prepared chunk beyond the transport byte limit.
        local normalized = message:gsub("|r|c", "|r |c"):gsub("|t|T", "|t |T"):gsub("|h|H", "|h |H")
        local ok, complete = pcall(Prepare,normalized,chunks,0)
        if not ok or not complete then
            -- Never fall back to sending the original speech or send a partial
            -- translation after a preparation failure.
            DEFAULT_CHAT_FRAME:AddMessage("Speaketh: whisper not sent. Shorten the message or its links and try again.")
            return
        end
        local _, outgoingID = Speaketh:GetOutgoingGameLanguage()
        for _, chunk in ipairs(chunks) do
            Speaketh.Internal:CommitSplitterChunk(chunk.source,chunk.language,"WHISPER",target)
            original(priority,header,chunk.text,channel,outgoingID,target,...)
        end
    end
    wim.SendSplitMessage = wrapper
    installed = true
    Speaketh.WIMCompatibilityActive = true
    return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self,event,name)
    if event == "PLAYER_LOGIN" or name == "WIM" or name == "Speaketh" then
        if Install() then self:UnregisterEvent("ADDON_LOADED");self:UnregisterEvent("PLAYER_LOGIN") end
    end
end)
if Install() then loader:UnregisterEvent("ADDON_LOADED");loader:UnregisterEvent("PLAYER_LOGIN") end
