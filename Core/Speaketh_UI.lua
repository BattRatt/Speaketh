-- Speaketh_UI.lua
-- Minimap button, Speak Window (compact status window),
-- language and dialect dropdown menus, splash/welcome screen.

Speaketh_UI = {}

-- ============================================================
-- Minimap Button
-- ============================================================
local BUTTON_RADIUS = 104
local BUTTON_ANGLE  = 200

local function AngleToPos(angle)
    local rad = math.rad(angle)
    return math.cos(rad) * BUTTON_RADIUS, math.sin(rad) * BUTTON_RADIUS
end

local function UpdateButtonPosition(btn, angle)
    local x, y = AngleToPos(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Speaketh_UI:CreateMinimapButton()
    local btn = CreateFrame("Button", "SpeakethMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    -- Circular minimap background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- Standard tracking border ring - offset (10,-10) is the standard
    -- correction for MiniMap-TrackingBorder's built-in visual offset
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- ── Speech bubble icon, centered in the button ──────────────
    -- Gold border layer
    local bubbleBorder = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    bubbleBorder:SetSize(20, 14)
    bubbleBorder:SetPoint("CENTER", btn, "CENTER", 0, 2)
    bubbleBorder:SetColorTexture(0.72, 0.58, 0.25, 1)

    -- Dark fill
    local bubbleFill = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    bubbleFill:SetSize(17, 11)
    bubbleFill:SetPoint("CENTER", btn, "CENTER", 0, 2)
    bubbleFill:SetColorTexture(0.08, 0.07, 0.06, 0.92)

    -- Three gold dots
    for i = -1, 1 do
        local dot = btn:CreateTexture(nil, "ARTWORK", nil, 2)
        dot:SetSize(3, 3)
        dot:SetPoint("CENTER", btn, "CENTER", i * 5, 2)
        dot:SetColorTexture(0.92, 0.78, 0.42, 1)
    end

    -- Tail: gold border
    local tailBorder = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    tailBorder:SetSize(6, 6)
    tailBorder:SetPoint("CENTER", btn, "CENTER", -5, -5)
    tailBorder:SetColorTexture(0.72, 0.58, 0.25, 1)
    tailBorder:SetRotation(math.rad(45))

    -- Tail: dark fill
    local tailFill = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    tailFill:SetSize(4, 4)
    tailFill:SetPoint("CENTER", btn, "CENTER", -5, -4)
    tailFill:SetColorTexture(0.08, 0.07, 0.06, 0.92)
    tailFill:SetRotation(math.rad(45))
    -- ─────────────────────────────────────────────────────────────

    local angle = (Speaketh_Char and Speaketh_Char.minimapAngle) or BUTTON_ANGLE
    UpdateButtonPosition(btn, angle)

    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)

    btn:SetScript("OnDragStart", function(self)
        self._dragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local newAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdateButtonPosition(self, newAngle)
            if Speaketh_Char then Speaketh_Char.minimapAngle = newAngle end
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self._dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    btn:SetScript("OnClick", function(self, mouseButton)
        if self._dragging then return end
        if mouseButton == "LeftButton" then
            if IsShiftKeyDown() then
                if Speaketh_Options and Speaketh_Options.Open then
                    Speaketh_Options:Open()
                end
            else
                Speaketh_UI:ToggleSpeakWindow()
            end
        elseif mouseButton == "RightButton" then
            Speaketh:CycleLanguage()
            if Speaketh_UI.Window and Speaketh_UI.Window:IsShown() then
                Speaketh_UI:RefreshWindow()
            end
        elseif mouseButton == "MiddleButton" then
            if Speaketh_Options and Speaketh_Options.Open then
                Speaketh_Options:Open()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        Speaketh_UI:UpdateTooltip()
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.Button = btn
end

-- Apply saved "show minimap button" preference. Safe to call anytime.
function Speaketh_UI:ApplyMinimapVisibility()
    if not self.Button then return end
    local show = not (Speaketh_Char and Speaketh_Char.showMinimap == false)
    if show then
        self.Button:Show()
    else
        self.Button:Hide()
    end
end

function Speaketh_UI:UpdateTooltip()
    if not self.Button then return end
    if not GameTooltip:IsOwned(self.Button) then return end
    local lang = Speaketh:GetLanguage()
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffffcc00Speaketh|r")
    if lang == "None" then
        GameTooltip:AddLine("Speaking: |cff88ccffNone|r  (no translation)")
    else
        local fluency = Speaketh_Fluency:Get(lang)
        GameTooltip:AddLine(string.format("Speaking: |cff88ccff%s|r  (%d%%)", Speaketh:GetLanguageDisplayName(lang), math.floor(fluency)))
    end
    local dialect = Speaketh_Dialects:GetActive()
    if dialect then
        GameTooltip:AddLine(string.format("Dialect: |cff88ccff%s|r", Speaketh_Dialects:GetDisplayLabel()))
    end
    local effect = Speaketh_Dialects.GetActiveEffect and Speaketh_Dialects:GetActiveEffect()
    if effect then
        local data = Speaketh_Dialects:GetData(effect)
        local label = data and data.name or effect
        if data and data.usesSlider then
            label = label .. ": " .. Speaketh_Dialects:GetSliderLabel(effect,
                Speaketh_Dialects:GetLevel(effect))
        end
        GameTooltip:AddLine(string.format("Effect: |cff88ccff%s|r", label))
    end
    GameTooltip:AddLine("|cffaaaaaaLeft-click: open speak window|r")
    GameTooltip:AddLine("|cffaaaaaaRight-click: cycle language|r")
    GameTooltip:AddLine("|cffaaaaaaShift+click or Middle: open options|r")
end

-- ============================================================
-- Speak Window
--
-- Compact status + control window. Shows the active language and its
-- fluency, with buttons to change language, change dialect, and open a
-- fluency slider. Uses a dark slate backdrop with thin gold edge to
-- match the rest of the native UI.
-- ============================================================
function Speaketh_UI:CreateSpeakWindow()
    local W, H = 360, 120

    local win = CreateFrame("Frame", "SpeakethWindow", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    win:SetSize(W, H)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop",  win.StopMovingOrSizing)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:Hide()

    -- Register with the game's escape-key handler so pressing Escape closes
    -- this window in the same stacking order as any native Blizzard panel.
    tinsert(UISpecialFrames, "SpeakethWindow")

    -- Dark parchment background matching options panel
    if win.SetBackdrop then
        win:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        Speaketh_Theme:Register(function(C)
            if not win.SetBackdropColor then return end
            local bg, bd = C.slateBg, C.slateBorder
            win:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
            win:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
        end)
    end

    -- Void-only atmospheric decoration (hidden in Classic)
    Speaketh_Theme:AddVoidVignette(win)
    Speaketh_Theme:AddVoidInkBleed(win)
    Speaketh_Theme:AddVoidGlowPulse(win)
    Speaketh_Theme:AddVoidRunes(win, 9, 20)

    -- Corner ornaments (small version, arm 18px)
    local _miniCornerTex = {}
    local function DrawMiniCorner(parent, corner)
        local SIZE, THICK = 18, 1
        local ox, oy, sx, sy
        if corner == "TL" then ox,oy,sx,sy =  1,-1, 1,-1
        elseif corner == "TR" then ox,oy,sx,sy = -1,-1,-1,-1
        elseif corner == "BL" then ox,oy,sx,sy =  1, 1, 1, 1
        else                       ox,oy,sx,sy = -1, 1,-1, 1 end
        local h = parent:CreateTexture(nil,"OVERLAY"); h:SetHeight(THICK); h:SetWidth(SIZE)
        local v = parent:CreateTexture(nil,"OVERLAY"); v:SetWidth(THICK); v:SetHeight(SIZE)
        table.insert(_miniCornerTex, h); table.insert(_miniCornerTex, v)
        if corner == "TL" then
            h:SetPoint("TOPLEFT",     parent, "TOPLEFT",     ox*8, oy*8)
            v:SetPoint("TOPLEFT",     parent, "TOPLEFT",     ox*8, oy*8)
        elseif corner == "TR" then
            h:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    ox*8, oy*8)
            v:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    ox*8, oy*8)
        elseif corner == "BL" then
            h:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  ox*8, oy*8)
            v:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  ox*8, oy*8)
        else
            h:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", ox*8, oy*8)
            v:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", ox*8, oy*8)
        end
    end
    DrawMiniCorner(win,"TL"); DrawMiniCorner(win,"TR")
    DrawMiniCorner(win,"BL"); DrawMiniCorner(win,"BR")
    Speaketh_Theme:Register(function(C)
        local a = C.accent
        local alpha = Speaketh_Theme:IsVoid() and 1.0 or 0.85
        for _, tex in ipairs(_miniCornerTex) do
            tex:SetColorTexture(a[1], a[2], a[3], alpha)
        end
    end)

    -- ── Title ──────────────────────────────────────────────────
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", win, "TOP", 0, -14)
    title:SetText("S P E A K E T H")
    title:SetSpacing(1.5)
    Speaketh_Theme:Register(function(C)
        local t = C.title; title:SetTextColor(t[1], t[2], t[3], 1)
    end)

    local titleDiv = win:CreateTexture(nil, "ARTWORK")
    titleDiv:SetPoint("TOPLEFT",  win, "TOPLEFT",  22, -30)
    titleDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -22, -30)
    titleDiv:SetHeight(1)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; titleDiv:SetColorTexture(a[1], a[2], a[3], 0.55)
    end)

    -- Custom close button (red circle style)
    local closeBtn = CreateFrame("Button", nil, win)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() win:Hide() end)
    local closeBg = closeBtn:CreateTexture(nil,"BACKGROUND")
    closeBg:SetAllPoints()
    local closeX = closeBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    closeX:SetAllPoints(); closeX:SetText("×")
    closeX:SetJustifyH("CENTER"); closeX:SetJustifyV("MIDDLE")
    Speaketh_Theme:Register(function(C)
        local bg, x = C.closeBg, C.closeX
        closeBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
        closeX:SetTextColor(x[1], x[2], x[3], x[4])
    end)
    closeBtn:SetScript("OnEnter", function()
        local h = Speaketh_Theme.C.closeBgHover
        closeBg:SetColorTexture(h[1], h[2], h[3], h[4])
    end)
    closeBtn:SetScript("OnLeave", function()
        local b = Speaketh_Theme.C.closeBg
        closeBg:SetColorTexture(b[1], b[2], b[3], b[4])
    end)

    local optionsBtn = CreateFrame("Button", nil, win)
    optionsBtn:SetSize(60, 18)
    optionsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    optionsBtn:SetScript("OnClick", function()
        if Speaketh_Options and Speaketh_Options.Open then Speaketh_Options:Open() end
    end)
    local optBg = optionsBtn:CreateTexture(nil,"BACKGROUND"); optBg:SetAllPoints()
    local optBorder = optionsBtn:CreateTexture(nil,"BORDER"); optBorder:SetAllPoints()
    local optText = optionsBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    optText:SetAllPoints(); optText:SetText("OPTIONS"); optText:SetSpacing(1.2)
    optText:SetJustifyH("CENTER"); optText:SetJustifyV("MIDDLE")
    Speaketh_Theme:Register(function(C)
        local a, t = C.accent, C.btnText
        optBg:SetColorTexture(a[1], a[2], a[3], 0.12)
        optBorder:SetColorTexture(a[1], a[2], a[3], 0.35)
        optText:SetTextColor(t[1], t[2], t[3], 1)
    end)
    optionsBtn:SetScript("OnEnter", function(self)
        local a = Speaketh_Theme.C.accent
        optBg:SetColorTexture(a[1], a[2], a[3], 0.22)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:AddLine("Speaketh Options"); GameTooltip:AddLine("|cffaaaaaaOpen the settings panel|r"); GameTooltip:Show()
    end)
    optionsBtn:SetScript("OnLeave", function()
        local a = Speaketh_Theme.C.accent
        optBg:SetColorTexture(a[1], a[2], a[3], 0.12); GameTooltip:Hide()
    end)

    -- ── Language section ───────────────────────────────────────
    local langHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    langHeader:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -40)
    langHeader:SetText("LANGUAGE")
    langHeader:SetSpacing(1.5)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; langHeader:SetTextColor(a[1], a[2], a[3], 0.85)
    end)

    local langRule = win:CreateTexture(nil,"ARTWORK"); langRule:SetHeight(1)
    langRule:SetPoint("LEFT", langHeader, "RIGHT", 6, 0)
    langRule:SetPoint("RIGHT", win, "RIGHT", -18, 0)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; langRule:SetColorTexture(a[1], a[2], a[3], 0.25)
    end)

    -- Small styled buttons
    local function MakeWinBtn(parent, label, w)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(w or 62, 18)
        local bg = btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints()
        local border = btn:CreateTexture(nil,"BORDER"); border:SetAllPoints()
        local txt = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        txt:SetAllPoints(); txt:SetText(string.upper(label)); txt:SetSpacing(1.0)
        txt:SetJustifyH("CENTER"); txt:SetJustifyV("MIDDLE")
        btn.Text = txt; btn._bg = bg
        Speaketh_Theme:Register(function(C)
            local a, t = C.accent, C.btnText
            bg:SetColorTexture(a[1], a[2], a[3], 0.12)
            border:SetColorTexture(a[1], a[2], a[3], 0.35)
            txt:SetTextColor(t[1], t[2], t[3], 1)
        end)
        btn:SetScript("OnEnter", function()
            local a = Speaketh_Theme.C.accent; bg:SetColorTexture(a[1], a[2], a[3], 0.25)
        end)
        btn:SetScript("OnLeave", function()
            local a = Speaketh_Theme.C.accent; bg:SetColorTexture(a[1], a[2], a[3], 0.12)
        end)
        return btn
    end

    local fluencyBtn = MakeWinBtn(win, "Fluency", 64)
    fluencyBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -18, -50)

    local changeBtn = MakeWinBtn(win, "Language", 74)
    changeBtn:SetPoint("RIGHT", fluencyBtn, "LEFT", -5, 0)
    changeBtn:SetScript("OnClick", function()
        Speaketh_UI:ShowLanguageMenu(changeBtn)
    end)

    -- Language display bar
    local langBar = CreateFrame("Frame", nil, win)
    langBar:SetPoint("TOPLEFT",  win,       "TOPLEFT",  16, -52)
    langBar:SetPoint("TOPRIGHT", changeBtn, "TOPLEFT",  -5,  0)
    langBar:SetHeight(18)

    local langBarBg = langBar:CreateTexture(nil,"BACKGROUND"); langBarBg:SetAllPoints()
    local langBarBorder = langBar:CreateTexture(nil,"BORDER"); langBarBorder:SetAllPoints()
    Speaketh_Theme:Register(function(C)
        local a = C.accent
        langBarBg:SetColorTexture(0, 0, 0, Speaketh_Theme:IsVoid() and 0.55 or 0.35)
        langBarBorder:SetColorTexture(a[1], a[2], a[3], 0.20)
    end)

    local langLabel = langBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langLabel:SetPoint("LEFT", langBar, "LEFT", 8, 0)
    langLabel:SetJustifyH("LEFT")
    Speaketh_Theme:Register(function(C)
        local t = C.bodyText; langLabel:SetTextColor(t[1], t[2], t[3], 1)
    end)

    local fluencyLabel = langBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fluencyLabel:SetPoint("LEFT", langLabel, "RIGHT", 6, 0)
    Speaketh_Theme:Register(function(C)
        local t = C.infoBlue; fluencyLabel:SetTextColor(t[1], t[2], t[3], 1)
    end)

    self.LangLabel    = langLabel
    self.FluencyLabel = fluencyLabel

    -- Fluency slider inline below language bar
    local sliderFrame = CreateFrame("Frame", "SpeakethFluencySlider", win)
    sliderFrame:SetPoint("TOPLEFT",  langBar, "BOTTOMLEFT",  -2, -4)
    sliderFrame:SetPoint("TOPRIGHT", win,     "TOPRIGHT",   -16, 0)
    sliderFrame:SetHeight(44)
    sliderFrame:Hide()

    local slider = CreateFrame("Slider", "SpeakethFluencySliderBar", sliderFrame,
        "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",  sliderFrame, "TOPLEFT",  16, -10)
    slider:SetPoint("TOPRIGHT", sliderFrame, "TOPRIGHT", -16, -10)
    slider:SetHeight(20)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("0%")
    slider.High:SetText("100%")
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.Text:SetText(value .. "%")
        local lang = Speaketh:GetLanguage()
        if lang ~= "None" and Speaketh_Fluency then
            Speaketh_Fluency:Set(lang, value)
            Speaketh_UI:RefreshWindow()
        end
    end)

    self.SliderFrame = sliderFrame
    self.Slider      = slider

    fluencyBtn:SetScript("OnClick", function()
        Speaketh_UI:ToggleFluencySlider()
    end)

    -- Section divider (repositioned dynamically)
    local sectionDiv = win:CreateTexture(nil, "ARTWORK")
    sectionDiv:SetHeight(1)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; sectionDiv:SetColorTexture(a[1], a[2], a[3], 0.30)
    end)
    self.SectionDiv = sectionDiv

    -- ── Dialect section ────────────────────────────────────────
    local dialectHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dialectHeader:SetText("DIALECT")
    dialectHeader:SetSpacing(1.5)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; dialectHeader:SetTextColor(a[1], a[2], a[3], 0.85)
    end)
    self.DialectHeader = dialectHeader

    local dialectStatusLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialectStatusLabel:SetPoint("LEFT", dialectHeader, "RIGHT", 10, 0)
    Speaketh_Theme:Register(function(C)
        local t = C.btnText; dialectStatusLabel:SetTextColor(t[1], t[2], t[3], 1)
    end)
    self.DialectStatusLabel = dialectStatusLabel

    local dialectBtn = MakeWinBtn(win, "Dialect")
    dialectBtn:SetPoint("RIGHT", win, "RIGHT", -18, 0)
    dialectBtn:SetScript("OnClick", function()
        Speaketh_UI:ShowDialectMenu(dialectBtn)
    end)
    self.DialectBtn = dialectBtn

    -- Dialect intensity slider
    local dialectSliderFrame = CreateFrame("Frame", nil, win)
    dialectSliderFrame:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, 0)
    dialectSliderFrame:SetHeight(36)
    dialectSliderFrame:Hide()

    local dialectSlider = CreateFrame("Slider", "SpeakethDialectSlider", dialectSliderFrame,
        "OptionsSliderTemplate")
    dialectSlider:SetPoint("TOPLEFT",  dialectSliderFrame, "TOPLEFT",  14, -8)
    dialectSlider:SetPoint("TOPRIGHT", dialectSliderFrame, "TOPRIGHT", -14, -8)
    dialectSlider:SetHeight(20)
    dialectSlider:SetMinMaxValues(0, 3)
    dialectSlider:SetValueStep(1)
    dialectSlider:SetObeyStepOnDrag(true)
    dialectSlider.Low:SetText("")
    dialectSlider.High:SetText("")
    if dialectSlider.Text then dialectSlider.Text:SetText("") end

    dialectSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        local activeKey = Speaketh_Dialects and Speaketh_Dialects.GetActive
            and Speaketh_Dialects:GetActive()
        if activeKey and Speaketh_Dialects.SetLevel then
            Speaketh_Dialects:SetLevel(activeKey, value)
        end
        Speaketh_UI:UpdateDialectDisplay()
    end)

    self.DialectSliderFrame = dialectSliderFrame
    self.DialectSlider      = dialectSlider

    -- Effects section. Drunk is the first effect and intentionally has state
    -- independent from the selected dialect.
    local effectDiv = win:CreateTexture(nil, "ARTWORK")
    effectDiv:SetHeight(1)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; effectDiv:SetColorTexture(a[1], a[2], a[3], 0.30)
    end)
    self.EffectDiv = effectDiv

    local effectHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    effectHeader:SetText("EFFECTS")
    effectHeader:SetSpacing(1.5)
    Speaketh_Theme:Register(function(C)
        local a = C.accent; effectHeader:SetTextColor(a[1], a[2], a[3], 0.85)
    end)
    self.EffectHeader = effectHeader

    local effectStatusLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    effectStatusLabel:SetPoint("LEFT", effectHeader, "RIGHT", 10, 0)
    self.EffectStatusLabel = effectStatusLabel

    local effectBtn = MakeWinBtn(win, "Effects")
    effectBtn:SetScript("OnClick", function()
        Speaketh_UI:ShowEffectMenu(effectBtn)
    end)
    self.EffectBtn = effectBtn

    local effectSliderFrame = CreateFrame("Frame", nil, win)
    effectSliderFrame:SetHeight(36)
    effectSliderFrame:Hide()
    local effectSlider = CreateFrame("Slider", "SpeakethEffectSlider", effectSliderFrame,
        "OptionsSliderTemplate")
    effectSlider:SetPoint("TOPLEFT", effectSliderFrame, "TOPLEFT", 14, -8)
    effectSlider:SetPoint("TOPRIGHT", effectSliderFrame, "TOPRIGHT", -14, -8)
    effectSlider:SetHeight(20)
    effectSlider:SetMinMaxValues(0, 3)
    effectSlider:SetValueStep(1)
    effectSlider:SetObeyStepOnDrag(true)
    effectSlider:SetScript("OnValueChanged", function(self, value)
        if Speaketh_UI._syncingEffectSlider then return end
        value = math.floor(value + 0.5)
        local active = Speaketh_Dialects:GetActiveEffect()
        if active then Speaketh_Dialects:SetLevel(active, value) end
        Speaketh_UI:UpdateEffectDisplay()
    end)
    self.EffectSliderFrame = effectSliderFrame
    self.EffectSlider = effectSlider

    self.Window = win
    self:RefreshWindow()
end

-- Heights for window sections
local SW_TITLE_H       = 38   -- title + gold divider
local SW_LANG_H        = 42   -- "Language" label + langbar row + padding
local SW_FLUENCY_H     = 48   -- inline fluency slider height
local SW_DIV_H         = 10   -- section divider gap
local SW_DIALECT_ROW_H = 34   -- "Dialect" header + status row + bottom pad
local SW_DIALECT_SLD_H = 40   -- dialect intensity slider
local SW_EFFECT_ROW_H  = 34
local SW_EFFECT_SLD_H  = 40

local function SpeakWindow_RecalcHeight(self)
    if not self.Window then return end

    local fluencyShown  = self.SliderFrame  and self.SliderFrame:IsShown()
    local dialectSldShown = self.DialectSliderFrame and self.DialectSliderFrame:IsShown()
    local effectSldShown = self.EffectSliderFrame and self.EffectSliderFrame:IsShown()

    local h = SW_TITLE_H + SW_LANG_H
    if fluencyShown  then h = h + SW_FLUENCY_H  end
    h = h + SW_DIV_H + SW_DIALECT_ROW_H
    if dialectSldShown then h = h + SW_DIALECT_SLD_H end
    h = h + SW_DIV_H + SW_EFFECT_ROW_H
    if effectSldShown then h = h + SW_EFFECT_SLD_H end

    self.Window:SetHeight(h)

    -- Re-anchor the section divider below the language block
    if self.SectionDiv then
        self.SectionDiv:ClearAllPoints()
        local divY = -(SW_TITLE_H + SW_LANG_H + (fluencyShown and SW_FLUENCY_H or 0))
        self.SectionDiv:SetPoint("TOPLEFT",  self.Window, "TOPLEFT",  14, divY)
        self.SectionDiv:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -14, divY)
    end

    -- Re-anchor the dialect header + button below the divider
    local dialectTopY = -(SW_TITLE_H + SW_LANG_H + (fluencyShown and SW_FLUENCY_H or 0) + SW_DIV_H)
    if self.DialectHeader then
        self.DialectHeader:ClearAllPoints()
        self.DialectHeader:SetPoint("TOPLEFT", self.Window, "TOPLEFT", 14, dialectTopY)
    end
    if self.DialectBtn then
        self.DialectBtn:ClearAllPoints()
        self.DialectBtn:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -12, dialectTopY - 2)
    end

    -- Re-anchor dialect intensity slider below the dialect row
    if self.DialectSliderFrame then
        self.DialectSliderFrame:ClearAllPoints()
        local sldY = dialectTopY - 22
        self.DialectSliderFrame:SetPoint("TOPLEFT",  self.Window, "TOPLEFT",  12, sldY)
        self.DialectSliderFrame:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -12, sldY)
    end

    local effectTopY = dialectTopY - SW_DIALECT_ROW_H
        - (dialectSldShown and SW_DIALECT_SLD_H or 0) - SW_DIV_H
    if self.EffectDiv then
        self.EffectDiv:ClearAllPoints()
        self.EffectDiv:SetPoint("TOPLEFT", self.Window, "TOPLEFT", 14, effectTopY + SW_DIV_H)
        self.EffectDiv:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -14, effectTopY + SW_DIV_H)
    end
    if self.EffectHeader then
        self.EffectHeader:ClearAllPoints()
        self.EffectHeader:SetPoint("TOPLEFT", self.Window, "TOPLEFT", 14, effectTopY)
    end
    if self.EffectBtn then
        self.EffectBtn:ClearAllPoints()
        self.EffectBtn:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -12, effectTopY - 2)
    end
    if self.EffectSliderFrame then
        self.EffectSliderFrame:ClearAllPoints()
        self.EffectSliderFrame:SetPoint("TOPLEFT", self.Window, "TOPLEFT", 12, effectTopY - 22)
        self.EffectSliderFrame:SetPoint("TOPRIGHT", self.Window, "TOPRIGHT", -12, effectTopY - 22)
    end
end

function Speaketh_UI:UpdateDialectDisplay()
    if not self.DialectStatusLabel then return end
    local active = Speaketh_Dialects:GetActive()
    local data   = active and Speaketh_Dialects:GetData(active)

    if not active then
        self.DialectStatusLabel:SetText("None")
        self.DialectStatusLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    else
        -- Show "Drunk  ·  Tipsy" style - no redundant colon prefix
        local label
        if data and data.sliderLabels then
            local level  = Speaketh_Dialects:GetLevel(active)
            local intensity = data.sliderLabels[level + 1] or ""
            label = (data.name or active) .. "  ·  " .. intensity
        else
            label = data and data.name or active
        end
        local color = Speaketh_Dialects:GetDisplayColor()
        self.DialectStatusLabel:SetText(label)
        self.DialectStatusLabel:SetTextColor(color[1], color[2], color[3], 1)
    end

    if self.DialectSliderFrame then
        if data and data.usesSlider then
            local level = Speaketh_Dialects:GetLevel(active)
            self.DialectSlider:SetValue(level)
            local labels = data.sliderLabels or {"Off", "Light", "Moderate", "Full"}
            self.DialectSlider.Low:SetText(labels[1]        or "Off")
            self.DialectSlider.High:SetText(labels[#labels] or "Full")
            self.DialectSliderFrame:Show()
        else
            self.DialectSliderFrame:Hide()
        end
    end
    SpeakWindow_RecalcHeight(self)
end

function Speaketh_UI:UpdateEffectDisplay()
    if not self.EffectStatusLabel then return end
    local active = Speaketh_Dialects.GetActiveEffect and Speaketh_Dialects:GetActiveEffect()
    if not active then
        self.EffectStatusLabel:SetText("None")
        self.EffectStatusLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        self.EffectSliderFrame:Hide()
    else
        local data = Speaketh_Dialects:GetData(active)
        local level = Speaketh_Dialects:GetLevel(active)
        local label = data and data.name or active
        if data and data.usesSlider then
            label = label .. "  ·  " .. Speaketh_Dialects:GetSliderLabel(active, level)
        end
        self.EffectStatusLabel:SetText(label)
        local color = data and data.sliderColors and data.sliderColors[level + 1]
            or {0.75, 0.65, 0.9}
        self.EffectStatusLabel:SetTextColor(color[1], color[2], color[3], 1)
        if data and data.usesSlider then
            self._syncingEffectSlider = true
            self.EffectSlider:SetValue(level)
            self._syncingEffectSlider = false
            local labels = data.sliderLabels or {"Off", "Light", "Moderate", "Strong"}
            self.EffectSlider.Low:SetText(labels[1] or "Off")
            self.EffectSlider.High:SetText(labels[#labels] or "Strong")
            self.EffectSliderFrame:Show()
        else
            self.EffectSliderFrame:Hide()
        end
    end
    SpeakWindow_RecalcHeight(self)
end

function Speaketh_UI:RefreshWindow()
    if not self.Window then return end
    local lang = Speaketh:GetLanguage()
    if lang == "None" then
        self.LangLabel:SetText("None (no translation)")
        self.FluencyLabel:SetText("")
    else
        local fluency = Speaketh_Fluency:Get(lang)
        self.LangLabel:SetText(Speaketh:GetLanguageDisplayName(lang))
        self.FluencyLabel:SetText(string.format("(%d%%)", math.floor(fluency)))
    end
    -- Sync fluency slider to current language
    if self.Slider and lang ~= "None" then
        self.Slider:SetValue(math.floor(Speaketh_Fluency:Get(lang)))
    end
    self:UpdateDialectDisplay()
    self:UpdateEffectDisplay()
    self:UpdateTooltip()
end

function Speaketh_UI:ToggleFluencySlider()
    if not self.SliderFrame then return end
    if self.SliderFrame:IsShown() then
        self.SliderFrame:Hide()
    else
        local lang = Speaketh:GetLanguage()
        if lang ~= "None" then
            self.Slider:SetValue(math.floor(Speaketh_Fluency:Get(lang)))
        end
        self.SliderFrame:Show()
    end
    SpeakWindow_RecalcHeight(self)
end

function Speaketh_UI:ToggleSpeakWindow()
    if not self.Window then
        self:CreateSpeakWindow()
    end
    if self.Window:IsShown() then
        self.Window:Hide()
    else
        self.Window:Show()
        self:RefreshWindow()
    end
end

-- ============================================================
-- Dropdown anchor helper
--
-- UIDropDownMenu submenus always fly out to the right. When the HUD is
-- near a screen edge the submenu would clip or wrap back over the parent.
-- This helper applies an inward offset when near the right edge, an
-- outward offset when near the left edge, and no offset in the center
-- third where there is room on both sides.
--
-- DROPDOWN_EDGE_OFFSET  px shift applied when near an edge. Tune if the
--                       menu sits too far from or overlaps the button.
-- DROPDOWN_EDGE_ZONE    fraction of screen width that counts as "near
--                       an edge" (0.25 = outer 25% on each side).
-- ============================================================
local DROPDOWN_EDGE_OFFSET = 100
local DROPDOWN_EDGE_ZONE   = 0.15

local function ToggleDropDownSmart(frame, anchor, hasSubmenus)
    local xOff = 0

    if anchor and anchor.GetCenter then
        local anchorX = anchor:GetCenter() or 0
        local screenW = GetScreenWidth()
        local zone    = screenW * DROPDOWN_EDGE_ZONE

        if anchorX > (screenW - zone) then
            -- Near the right edge: shift menu leftward so submenus open inward
            xOff = -DROPDOWN_EDGE_OFFSET
        elseif anchorX < zone then
            -- Near the left edge: shift menu rightward so submenus open inward
            xOff = DROPDOWN_EDGE_OFFSET
        end
        -- Center zone: no offset, default rightward open
    end

    ToggleDropDownMenu(1, nil, frame, anchor or "cursor", xOff, 0)
end

-- ============================================================
-- Language selection dropdown
-- ============================================================
local menuFrame = CreateFrame("Frame", "SpeakethMenuFrame", UIParent, "UIDropDownMenuTemplate")

function Speaketh_UI:ShowLanguageMenu(anchor)
    local function init(frame, level)
        local info = UIDropDownMenu_CreateInfo()

        if level == 1 then
            -- ── Language arrow ────────────────────────────────────
            local curLang = Speaketh:GetLanguage()
            local langLabel = (curLang == "None") and "None" or curLang
            info.text         = string.format("Language  |cffaaaaaa(%s)|r", langLabel)
            info.hasArrow     = true
            info.notCheckable = true
            info.value        = "LANG_SUBMENU"
            UIDropDownMenu_AddButton(info, level)

            -- ── Dialect arrow ─────────────────────────────────────
            info = UIDropDownMenu_CreateInfo()
            local activeDialect = Speaketh_Dialects:GetActive()
            local dialectLabel  = activeDialect and Speaketh_Dialects:GetData(activeDialect).name or "None"
            info.text         = string.format("Dialect  |cffaaaaaa(%s)|r", dialectLabel)
            info.hasArrow     = true
            info.notCheckable = true
            info.value        = "DIALECT_SUBMENU"
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            local activeEffect = Speaketh_Dialects:GetActiveEffect()
            local effectData = activeEffect and Speaketh_Dialects:GetData(activeEffect)
            local effectLabel = effectData and effectData.name or "None"
            info.text         = string.format("Effect  |cffaaaaaa(%s)|r", effectLabel)
            info.hasArrow     = true
            info.notCheckable = true
            info.value        = "EFFECT_SUBMENU"
            UIDropDownMenu_AddButton(info, level)

        elseif level == 2 then
            if UIDROPDOWNMENU_MENU_VALUE == "LANG_SUBMENU" then
                -- ── Language submenu ──────────────────────────────
                info.text = "Language"
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)

                info = UIDropDownMenu_CreateInfo()
                info.text    = "None  |cffaaaaaa(no translation)|r"
                info.checked = (Speaketh:GetLanguage() == "None")
                info.notCheckable = false
                info.func = function()
                    Speaketh:SetLanguage("None")
                    CloseDropDownMenus()
                    Speaketh_UI:RefreshWindow()
                end
                UIDropDownMenu_AddButton(info, level)

                for _, key in ipairs(Speaketh_LanguageOrder) do
                    if Speaketh_Fluency:Get(key) > 0 then
                        info = UIDropDownMenu_CreateInfo()
                        info.text    = string.format("%s  |cffaaaaaa(%d%%)|r", key, math.floor(Speaketh_Fluency:Get(key)))
                        info.value   = key
                        info.checked = (Speaketh:GetLanguage() == key)
                        info.notCheckable = false
                        info.func = function(btn)
                            Speaketh:SetLanguage(btn.value)
                            CloseDropDownMenus()
                            Speaketh_UI:RefreshWindow()
                        end
                        UIDropDownMenu_AddButton(info, level)
                    end
                end

            elseif UIDROPDOWNMENU_MENU_VALUE == "DIALECT_SUBMENU" then
                -- ── Dialect submenu ───────────────────────────────
                info.text = "Dialect"
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)

                info = UIDropDownMenu_CreateInfo()
                info.text    = "None  |cffaaaaaa(no accent)|r"
                info.checked = (Speaketh_Dialects:GetActive() == nil)
                info.notCheckable = false
                info.func = function()
                    Speaketh_Dialects:SetActive(nil)
                    CloseDropDownMenus()
                    Speaketh_UI:RefreshWindow()
                end
                UIDropDownMenu_AddButton(info, level)

                local _, dialectOrder = Speaketh_Dialects:GetAll()
                for _, key in ipairs(dialectOrder) do
                    if key ~= "Drunk" then
                    local d = Speaketh_Dialects:GetData(key)
                    info = UIDropDownMenu_CreateInfo()
                    info.text    = d.name
                    info.value   = key
                    info.checked = (Speaketh_Dialects:GetActive() == key)
                    info.notCheckable = false
                    info.func = function(btn)
                        Speaketh_Dialects:SetActive(btn.value)
                        CloseDropDownMenus()
                        Speaketh_UI:RefreshWindow()
                    end
                    UIDropDownMenu_AddButton(info, level)
                    end
                end
            elseif UIDROPDOWNMENU_MENU_VALUE == "EFFECT_SUBMENU" then
                info.text = "Effect"
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)

                info = UIDropDownMenu_CreateInfo()
                info.text = "None  |cffaaaaaa(no effect)|r"
                info.checked = (Speaketh_Dialects:GetActiveEffect() == nil)
                info.notCheckable = false
                info.func = function()
                    Speaketh_Dialects:SetActiveEffect(nil)
                    CloseDropDownMenus()
                    Speaketh_UI:RefreshWindow()
                end
                UIDropDownMenu_AddButton(info, level)

                local _, effectOrder = Speaketh_Dialects:GetEffects()
                for _, key in ipairs(effectOrder) do
                    local effect = Speaketh_Dialects:GetData(key)
                    info = UIDropDownMenu_CreateInfo()
                    info.text = effect and effect.name or key
                    info.value = key
                    info.checked = (Speaketh_Dialects:GetActiveEffect() == key)
                    info.notCheckable = false
                    info.func = function(btn)
                        Speaketh_Dialects:SetActiveEffect(btn.value)
                        CloseDropDownMenus()
                        Speaketh_UI:RefreshWindow()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end

    UIDropDownMenu_Initialize(menuFrame, init, "MENU")
    ToggleDropDownSmart(menuFrame, anchor, true)
end

-- ============================================================
-- Dialect selection dropdown
-- ============================================================
local dialectMenuFrame = CreateFrame("Frame", "SpeakethDialectMenuFrame", UIParent,
    "UIDropDownMenuTemplate")

function Speaketh_UI:ShowDialectMenu(anchor)
    local function init(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Choose Dialect"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text    = "None  |cffaaaaaa(no accent)|r"
        info.value   = nil
        info.checked = (Speaketh_Dialects:GetActive() == nil)
        info.notCheckable = false
        info.func = function()
            Speaketh_Dialects:SetActive(nil)
            CloseDropDownMenus()
            Speaketh_UI:RefreshWindow()
        end
        UIDropDownMenu_AddButton(info, level)

        local _, dialectOrder = Speaketh_Dialects:GetAll()
        for _, key in ipairs(dialectOrder) do
            if key ~= "Drunk" then
            local d = Speaketh_Dialects:GetData(key)
            info = UIDropDownMenu_CreateInfo()
            info.text    = d.name
            info.value   = key
            info.checked = (Speaketh_Dialects:GetActive() == key)
            info.notCheckable = false
            info.func = function(btn)
                Speaketh_Dialects:SetActive(btn.value)
                CloseDropDownMenus()
                Speaketh_UI:RefreshWindow()
            end
            UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    UIDropDownMenu_Initialize(dialectMenuFrame, init, "MENU")
    ToggleDropDownSmart(dialectMenuFrame, anchor, false)
end

local effectMenuFrame = CreateFrame("Frame", "SpeakethEffectMenuFrame", UIParent,
    "UIDropDownMenuTemplate")

function Speaketh_UI:ShowEffectMenu(anchor)
    local function init(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Choose Effect"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "None"
        info.checked = Speaketh_Dialects:GetActiveEffect() == nil
        info.func = function()
            Speaketh_Dialects:SetActiveEffect(nil)
            Speaketh_UI:UpdateEffectDisplay()
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)

        local _, effectOrder = Speaketh_Dialects:GetEffects()
        for _, key in ipairs(effectOrder) do
            local effectKey = key
            local data = Speaketh_Dialects:GetData(effectKey)
            info = UIDropDownMenu_CreateInfo()
            info.text = data and data.name or effectKey
            info.checked = Speaketh_Dialects:GetActiveEffect() == effectKey
            info.func = function()
                Speaketh_Dialects:SetActiveEffect(effectKey)
                Speaketh_UI:UpdateEffectDisplay()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(effectMenuFrame, init, "MENU")
    ToggleDropDownSmart(effectMenuFrame, anchor, false)
end

-- ============================================================
-- Floating Language HUD button
--
-- A small draggable frame that shows the currently active language.
-- Left-click: open the Language selection menu.
-- Right-click: open the Speak Window (main menu).
-- Position is saved across sessions via Speaketh_Char.hudPos.
-- Visibility is controlled by Speaketh_Char.showLangHUD.
-- ============================================================
function Speaketh_UI:CreateLanguageHUD()
    if self.LangHUD then return end

    local hud = CreateFrame("Button", "SpeakethLanguageHUD", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    hud:SetSize(110, 26)
    hud:SetFrameStrata("MEDIUM")
    hud:SetClampedToScreen(true)
    hud:EnableMouse(true)
    hud:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    hud:RegisterForDrag("LeftButton")
    hud:SetMovable(true)

    -- Restore saved position, or default to center-ish of the screen
    local pos = Speaketh_Char and Speaketh_Char.hudPos
    if pos and pos.point and pos.x and pos.y then
        hud:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end

    -- Dark slate backdrop with thin gold edge - matches Speak Window
    if hud.SetBackdrop then
        hud:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        Speaketh_Theme:Register(function(C)
            if not hud.SetBackdropColor then return end
            if Speaketh_Theme:IsVoid() then
                hud:SetBackdropColor(0.04, 0.02, 0.10, 0.92)
                local b = C.slateBorder
                hud:SetBackdropBorderColor(b[1], b[2], b[3], 1)
            else
                hud:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
                hud:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
            end
        end)
    end

    -- Language label in the center
    local label = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", hud, "CENTER", 0, 0)
    hud.Label = label

    -- Drag handlers: save position on drop
    hud:SetScript("OnDragStart", function(self)
        self._dragging = true
        self:StartMoving()
    end)
    hud:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._dragging = false
        if Speaketh_Char then
            local point, _, relPoint, x, y = self:GetPoint(1)
            Speaketh_Char.hudPos = {
                point    = point,
                relPoint = relPoint,
                x        = x,
                y        = y,
            }
        end
    end)

    -- Click handlers
    hud:SetScript("OnClick", function(self, mouseButton)
        if self._dragging then return end
        if mouseButton == "MiddleButton" then
            if Speaketh and Speaketh.Toggle then Speaketh:Toggle() end
        elseif mouseButton == "LeftButton" then
            Speaketh_UI:ShowLanguageMenu(self)
        elseif mouseButton == "RightButton" then
            Speaketh_UI:ToggleSpeakWindow()
        end
    end)

    -- Tooltip
    hud:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffcc00Speaketh|r")
        local enabled = Speaketh and Speaketh.IsEnabled and Speaketh:IsEnabled()
        if enabled == false then
            GameTooltip:AddLine("|cffff4444DISABLED|r")
        end
        local lang = Speaketh:GetLanguage()
        if lang == "None" then
            GameTooltip:AddLine("Speaking: |cff88ccffNone|r")
        else
            local fluency = Speaketh_Fluency:Get(lang)
            GameTooltip:AddLine(string.format(
                "Speaking: |cff88ccff%s|r  (%d%%)", Speaketh:GetLanguageDisplayName(lang), math.floor(fluency)))
        end
        GameTooltip:AddLine("|cffaaaaaaLeft-click: change language|r")
        GameTooltip:AddLine("|cffaaaaaaRight-click: open Speak Window|r")
        GameTooltip:AddLine("|cffaaaaaaMiddle-click: toggle enable/disable|r")
        GameTooltip:AddLine("|cffaaaaaaDrag to move|r")
        GameTooltip:Show()
    end)
    hud:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.LangHUD = hud
    self:RefreshLanguageHUD()
    self:ApplyLanguageHUDVisibility()
end

-- Update the HUD's displayed language label. Safe to call anytime.
function Speaketh_UI:RefreshLanguageHUD()
    if not self.LangHUD or not self.LangHUD.Label then return end
    local lang = Speaketh:GetLanguage()
    local enabled = Speaketh and Speaketh.IsEnabled and Speaketh:IsEnabled()
    if enabled == false then
        self.LangHUD.Label:SetTextColor(0.55, 0.55, 0.55, 1)  -- greyed out
    else
        local t = Speaketh_Theme.C.headerGold
        self.LangHUD.Label:SetTextColor(t[1], t[2], t[3], 1)
    end
    if lang == "None" then
        self.LangHUD.Label:SetText("None")
    else
        self.LangHUD.Label:SetText(Speaketh:GetLanguageDisplayName(lang))
    end
end

-- Apply the showLangHUD saved setting. Defaults to visible.
function Speaketh_UI:ApplyLanguageHUDVisibility()
    if not self.LangHUD then return end
    local show = not (Speaketh_Char and Speaketh_Char.showLangHUD == false)
    if show then
        self.LangHUD:Show()
    else
        self.LangHUD:Hide()
    end
end
