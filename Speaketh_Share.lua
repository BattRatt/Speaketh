-- Speaketh_Share.lua
-- Import/export codes for custom languages.
--
-- Format:  SPKTH:<base64 payload>:<4-hex checksum>
-- Payload: "LanguageName:word1,word2,word3,..."
--
-- Base64 uses A-Z a-z 0-9 - _ (URL-safe, WoW chat safe).
-- Implemented with integer division and modulo only — no bitwise
-- operators, fully compatible with WoW's Lua 5.1.
--
-- Typical sizes:
--   6  words ->  ~60 chars
--   30 words -> ~190 chars
--  150 words -> ~1620 chars (fits in a Discord message)

Speaketh_Share = {}

local MAX_WORDS   = 500
local CODE_PREFIX = "SPKTH:"

-- ============================================================
-- Base64 (URL-safe alphabet, Lua 5.1 compatible)
-- ============================================================
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function b64enc(data)
    local out = {}
    local pad = (3 - (#data % 3)) % 3
    data = data .. string.rep("\0", pad)
    for i = 1, #data, 3 do
        local b1, b2, b3 = string.byte(data, i, i + 2)
        local n = b1 * 65536 + b2 * 256 + b3
        out[#out+1] = B64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out+1] = B64:sub(math.floor(n / 4096)   % 64 + 1, math.floor(n / 4096)   % 64 + 1)
        out[#out+1] = B64:sub(math.floor(n / 64)     % 64 + 1, math.floor(n / 64)     % 64 + 1)
        out[#out+1] = B64:sub(n % 64 + 1,                      n % 64 + 1)
    end
    -- Store pad count in the final character so decode knows how many
    -- null bytes to strip.  "0" = no padding, never written.
    if pad > 0 then out[#out] = tostring(pad) end
    return table.concat(out)
end

local function b64dec(data)
    local rev = {}
    for i = 1, #B64 do rev[B64:sub(i, i)] = i - 1 end
    local pad = 0
    local last = data:sub(-1)
    if last == "1" or last == "2" then
        pad  = tonumber(last)
        data = data:sub(1, -2) .. B64:sub(1, 1)  -- replace pad marker with valid char
    end
    local out = {}
    for i = 1, #data, 4 do
        local c1 = rev[data:sub(i,   i  )] or 0
        local c2 = rev[data:sub(i+1, i+1)] or 0
        local c3 = rev[data:sub(i+2, i+2)] or 0
        local c4 = rev[data:sub(i+3, i+3)] or 0
        local n  = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
        out[#out+1] = string.char(math.floor(n / 65536) % 256)
        out[#out+1] = string.char(math.floor(n / 256)   % 256)
        out[#out+1] = string.char(n % 256)
    end
    local result = table.concat(out)
    if pad > 0 then result = result:sub(1, -pad - 1) end
    return result
end

-- 16-bit checksum as 4 uppercase hex chars
local function checksum(data)
    local s = 0
    for i = 1, #data do s = (s + string.byte(data, i)) % 65536 end
    return string.format("%04X", s)
end

-- ============================================================
-- Public: generate an import code from a custom language
-- Returns: code string       on success
--          nil, errString    on failure
-- ============================================================
function Speaketh_Share:ExportCode(langKey)
    local saved = Speaketh_Char
                  and Speaketh_Char.customLanguages
                  and Speaketh_Char.customLanguages[langKey]
    if not saved then return nil, "Language not found." end

    local lang = Speaketh_Languages and Speaketh_Languages[langKey]
    if not lang or not lang.isCustom then
        return nil, "Only custom languages can be exported."
    end

    local words = saved.words
    if type(words) ~= "table" or #words == 0 then
        return nil, "Language has no words."
    end
    if #words > MAX_WORDS then
        return nil, string.format("Too many words (%d); cap is %d.", #words, MAX_WORDS)
    end

    local name = saved.name
                 or (Speaketh and Speaketh:GetLanguageDisplayName(langKey))
                 or langKey
    local raw  = name .. ":" .. table.concat(words, ",")
    return CODE_PREFIX .. b64enc(raw) .. ":" .. checksum(raw), nil
end

-- ============================================================
-- Public: import a code and register the language
-- Returns: displayName, wordCount   on success
--          nil, "COLLISION:<name>"  when a same-named lang exists (no overwrite flag)
--          nil, errString           on any other failure
-- ============================================================

local function FindKeyByName(name)
    if not Speaketh_Char or not Speaketh_Char.customLanguages then return nil end
    local lower = name:lower()
    for key, data in pairs(Speaketh_Char.customLanguages) do
        if data.name and data.name:lower() == lower then return key end
    end
    return nil
end

local function MakeKey(displayName)
    local safe = displayName:gsub("[^%w]", ""):sub(1, 32)
    if safe == "" then safe = "Imported" end
    local base = "CustomLang_" .. safe
    local key, n = base, 1
    while Speaketh_Languages and Speaketh_Languages[key] do
        n = n + 1; key = base .. "_" .. n
    end
    return key
end

function Speaketh_Share:ImportCode(code, overwrite)
    code = code and (code:gsub("^%s+", ""):gsub("%s+$", "")) or ""
    if code == "" then return nil, "Paste an import code first." end

    local encoded, cs = code:match("^SPKTH:([A-Za-z0-9%-_]+):(%x%x%x%x)$")
    if not encoded or not cs then
        if code:sub(1, #CODE_PREFIX) ~= CODE_PREFIX then
            return nil, "Not a Speaketh import code (should start with SPKTH:)."
        end
        return nil, "Malformed code — it may be truncated. Copy the full code and try again."
    end

    local raw = b64dec(encoded)
    if checksum(raw) ~= cs:upper() then
        return nil, "Code is corrupted — checksum mismatch. Re-copy and try again."
    end

    local name, wordstr = raw:match("^([^:]+):(.+)$")
    if not name or not wordstr then
        return nil, "Malformed payload — unrecognized code structure."
    end
    if #name > 64 then return nil, "Language name is too long." end

    local words = {}
    for w in (wordstr .. ","):gmatch("([^,]+),") do
        local clean = w:gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("[^%w'%-]", "")
        if clean ~= "" and #words < MAX_WORDS then
            words[#words+1] = clean
        end
    end
    if #words == 0 then return nil, "No valid words found in code." end

    local existingKey = FindKeyByName(name)
    if existingKey and not overwrite then
        return nil, "COLLISION:" .. name
    end

    local key = (existingKey and overwrite) and existingKey or MakeKey(name)

    if not Speaketh_Char.customLanguages then Speaketh_Char.customLanguages = {} end
    Speaketh_Char.customLanguages[key] = { name = name, words = words }

    if Speaketh_RegisterCustomLanguage then
        Speaketh_RegisterCustomLanguage(key, name, words)
    end

    if Speaketh_Fluency and Speaketh_Fluency.Set then
        Speaketh_Fluency:Set(key, 100)
    end

    return name, #words
end
