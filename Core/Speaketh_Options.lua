-- Settings launcher. The sidebar and editors live in Speaketh_MatchedUI.lua.
Speaketh_Options = {}

function Speaketh_Options:Register()
    -- The full panel is built lazily on :Open(). Register a small launcher
    -- page so Speaketh also appears under Esc > Options > AddOns, as the
    -- login code and documentation describe.
    if self._settingsCategory then return end
    if not Settings or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
       or type(Settings.RegisterAddOnCategory) ~= "function" then
        return
    end

    local page = CreateFrame("Frame")
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    title:SetText("Speaketh")

    local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    note:SetText("Speaketh uses its own settings window.")

    local openBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 24)
    openBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
    openBtn:SetText("Open Speaketh Options")
    openBtn:SetScript("OnClick", function()
        -- Blizzard's Settings panel is deliberately left alone (closing it
        -- from addon code would commit its settings in tainted execution).
        -- Both windows are top-level HIGH strata, so raise ours above it.
        Speaketh_Options:Open()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(page, "Speaketh")
    Settings.RegisterAddOnCategory(category)
    self._settingsCategory = category
end
