-- Speaketh_Fluency.lua
-- Handles per-character fluency tracking and language-learning on hearing foreign speech.

Speaketh_Fluency = {}

-- Returns fluency 0-100 for a language key
function Speaketh_Fluency:Get(langKey)
    return (Speaketh_Char and Speaketh_Char.fluency and Speaketh_Char.fluency[langKey]) or 0
end

-- Sets fluency, clamped to 0-100
function Speaketh_Fluency:Set(langKey, value)
    if not Speaketh_Char then return end
    Speaketh_Char.fluency[langKey] = math.max(0, math.min(100, value))
end

-- Grants fluency for a language the player just heard
-- gainRate: base points to add (modified by current fluency - harder to improve when fluent)
function Speaketh_Fluency:Learn(langKey, gainRate)
    local current = self:Get(langKey)
    if current >= 100 then return end

    -- Diminishing returns: gain slows as fluency rises
    local effective = gainRate * (1 - (current / 120))
    effective = math.max(0.5, effective)

    local new = math.min(100, current + effective)
    self:Set(langKey, new)

    -- Notify the player
    local shown = math.floor(new)
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff88ccff[Speaketh]|r You understand a little more %s. (%d%%)", langKey, shown),
        1, 1, 1)

    -- Refresh minimap tooltip if open
    if Speaketh_UI and Speaketh_UI.UpdateTooltip then
        Speaketh_UI:UpdateTooltip()
    end
end

-- Called when the player sends a message in a language - ensure they have 100% in their own tongue
function Speaketh_Fluency:EnsureNative(langKey)
    if self:Get(langKey) < 100 then
        self:Set(langKey, 100)
    end
end

-- Seed initial fluencies based on race/faction at first login
function Speaketh_Fluency:SeedDefaults()
    local raceName = UnitRace("player")
    local faction  = UnitFactionGroup("player")
    local factionLanguage = faction == "Alliance" and "Common"
        or (faction == "Horde" and "Orcish")

    -- Fresh characters get 100 only in languages assigned to their race and
    -- their faction's shared tongue (Common for Alliance, Orcish for Horde).
    -- A language's `faction` metadata describes where it belongs; it does not
    -- mean every member of that faction should automatically know it.
    for key, data in pairs(Speaketh_Languages) do
        local isRacial  = false
        local isFaction = key == factionLanguage

        if data.race then
            for _, r in ipairs(data.race) do
                if r == raceName then isRacial = true end
            end
        end

        if isRacial or isFaction then
            -- Only seed if the player has never explicitly set this language.
            -- Checking for nil (key absent) rather than < 100 ensures that an
            -- intentional reset to 0 (or any value) is never overwritten on reload.
            if Speaketh_Char.fluency[key] == nil then
                self:Set(key, 100)
            end
        end
    end

end
