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

    -- Standard tracking border ring — offset (10,-10) is the standard
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

    -- Dark parchment background matching options panel
    if win.SetBackdrop then
        win:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        win:SetBackdropColor(0.09, 0.06, 0.02, 0.98)
        win:SetBackdropBorderColor(0.55, 0.42, 0.15, 1)
    end

    -- Corner ornaments (small version, arm 18px)
    local function DrawMiniCorner(parent, corner)
        local SIZE, THICK, r, g, b, a = 18, 1, 0.72, 0.58, 0.25, 0.85
        local ox, oy, sx, sy
        if corner == "TL" then ox,oy,sx,sy =  1,-1, 1,-1
        elseif corner == "TR" then ox,oy,sx,sy = -1,-1,-1,-1
        elseif corner == "BL" then ox,oy,sx,sy =  1, 1, 1, 1
        else                       ox,oy,sx,sy = -1, 1,-1, 1 end
        local h = parent:CreateTexture(nil,"OVERLAY"); h:SetHeight(THICK); h:SetWidth(SIZE)
        h:SetColorTexture(r,g,b,a)
        local v = parent:CreateTexture(nil,"OVERLAY"); v:SetWidth(THICK); v:SetHeight(SIZE)
        v:SetColorTexture(r,g,b,a)
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

    -- ── Title ──────────────────────────────────────────────────
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", win, "TOP", 0, -14)
    title:SetText("S P E A K E T H")
    title:SetTextColor(0.88, 0.74, 0.38, 1)
    title:SetSpacing(1.5)

    local titleDiv = win:CreateTexture(nil, "ARTWORK")
    titleDiv:SetPoint("TOPLEFT",  win, "TOPLEFT",  22, -30)
    titleDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -22, -30)
    titleDiv:SetHeight(1)
    titleDiv:SetColorTexture(0.72, 0.58, 0.25, 0.55)

    -- Custom close button (red circle style)
    local closeBtn = CreateFrame("Button", nil, win)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() win:Hide() end)
    local closeBg = closeBtn:CreateTexture(nil,"BACKGROUND")
    closeBg:SetAllPoints(); closeBg:SetColorTexture(0.55,0.10,0.08,0.90)
    local closeX = closeBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    closeX:SetAllPoints(); closeX:SetText("×"); closeX:SetTextColor(1,0.85,0.75,1)
    closeX:SetJustifyH("CENTER"); closeX:SetJustifyV("MIDDLE")
    closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.72,0.15,0.10,1) end)
    closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0.55,0.10,0.08,0.90) end)

    local optionsBtn = CreateFrame("Button", nil, win)
    optionsBtn:SetSize(60, 18)
    optionsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    optionsBtn:SetScript("OnClick", function()
        if Speaketh_Options and Speaketh_Options.Open then Speaketh_Options:Open() end
    end)
    local optBg = optionsBtn:CreateTexture(nil,"BACKGROUND"); optBg:SetAllPoints()
    optBg:SetColorTexture(0.72,0.58,0.25,0.12)
    local optBorder = optionsBtn:CreateTexture(nil,"BORDER"); optBorder:SetAllPoints()
    optBorder:SetColorTexture(0.72,0.58,0.25,0.35)
    local optText = optionsBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    optText:SetAllPoints(); optText:SetText("OPTIONS"); optText:SetSpacing(1.2)
    optText:SetTextColor(0.85,0.70,0.35,1); optText:SetJustifyH("CENTER"); optText:SetJustifyV("MIDDLE")
    optionsBtn:SetScript("OnEnter", function() optBg:SetColorTexture(0.72,0.58,0.25,0.22) end)
    optionsBtn:SetScript("OnLeave", function() optBg:SetColorTexture(0.72,0.58,0.25,0.12) end)
    optionsBtn:SetScript("OnEnter", function(self)
        optBg:SetColorTexture(0.72,0.58,0.25,0.22)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:AddLine("Speaketh Options"); GameTooltip:AddLine("|cffaaaaaaOpen the settings panel|r"); GameTooltip:Show()
    end)
    optionsBtn:SetScript("OnLeave", function() optBg:SetColorTexture(0.72,0.58,0.25,0.12); GameTooltip:Hide() end)

    -- ── Language section ───────────────────────────────────────
    local langHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    langHeader:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -40)
    langHeader:SetText("LANGUAGE")
    langHeader:SetTextColor(0.72, 0.58, 0.25, 0.80)
    langHeader:SetSpacing(1.5)

    local langRule = win:CreateTexture(nil,"ARTWORK"); langRule:SetHeight(1)
    langRule:SetPoint("LEFT", langHeader, "RIGHT", 6, 0)
    langRule:SetPoint("RIGHT", win, "RIGHT", -18, 0)
    langRule:SetColorTexture(0.72, 0.58, 0.25, 0.25)

    -- Small styled buttons
    local function MakeWinBtn(parent, label, w)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(w or 62, 18)
        local bg = btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints()
        bg:SetColorTexture(0.72,0.58,0.25,0.12)
        local border = btn:CreateTexture(nil,"BORDER"); border:SetAllPoints()
        border:SetColorTexture(0.72,0.58,0.25,0.35)
        local txt = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        txt:SetAllPoints(); txt:SetText(string.upper(label)); txt:SetSpacing(1.0)
        txt:SetTextColor(0.85,0.70,0.35,1); txt:SetJustifyH("CENTER"); txt:SetJustifyV("MIDDLE")
        btn.Text = txt; btn._bg = bg
        btn:SetScript("OnEnter", function() bg:SetColorTexture(0.72,0.58,0.25,0.25) end)
        btn:SetScript("OnLeave", function() bg:SetColorTexture(0.72,0.58,0.25,0.12) end)
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
    langBarBg:SetColorTexture(0, 0, 0, 0.35)
    local langBarBorder = langBar:CreateTexture(nil,"BORDER"); langBarBorder:SetAllPoints()
    langBarBorder:SetColorTexture(0.72, 0.58, 0.25, 0.20)

    local langLabel = langBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langLabel:SetPoint("LEFT", langBar, "LEFT", 8, 0)
    langLabel:SetJustifyH("LEFT")
    langLabel:SetTextColor(0.92, 0.82, 0.55, 1)

    local fluencyLabel = langBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fluencyLabel:SetPoint("LEFT", langLabel, "RIGHT", 6, 0)
    fluencyLabel:SetTextColor(0.55, 0.75, 1.0, 1)

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
    sectionDiv:SetColorTexture(0.72, 0.58, 0.25, 0.30)
    self.SectionDiv = sectionDiv

    -- ── Dialect section ────────────────────────────────────────
    local dialectHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dialectHeader:SetTextColor(0.72, 0.58, 0.25, 0.80)
    dialectHeader:SetText("DIALECT")
    dialectHeader:SetSpacing(1.5)
    self.DialectHeader = dialectHeader

    local dialectStatusLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialectStatusLabel:SetPoint("LEFT", dialectHeader, "RIGHT", 10, 0)
    dialectStatusLabel:SetTextColor(0.85, 0.72, 0.45, 1)
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

local function SpeakWindow_RecalcHeight(self)
    if not self.Window then return end

    local fluencyShown  = self.SliderFrame  and self.SliderFrame:IsShown()
    local dialectSldShown = self.DialectSliderFrame and self.DialectSliderFrame:IsShown()

    local h = SW_TITLE_H + SW_LANG_H
    if fluencyShown  then h = h + SW_FLUENCY_H  end
    h = h + SW_DIV_H + SW_DIALECT_ROW_H
    if dialectSldShown then h = h + SW_DIALECT_SLD_H end

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
end

function Speaketh_UI:UpdateDialectDisplay()
    if not self.DialectStatusLabel then return end
    local active = Speaketh_Dialects:GetActive()
    local data   = active and Speaketh_Dialects:GetData(active)

    if not active then
        self.DialectStatusLabel:SetText("None")
        self.DialectStatusLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    else
        -- Show "Drunk  ·  Sober" style — no redundant colon prefix
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
-- Language selection dropdown
-- ============================================================
local menuFrame = CreateFrame("Frame", "SpeakethMenuFrame", UIParent, "UIDropDownMenuTemplate")

function Speaketh_UI:ShowLanguageMenu(anchor)
    local function init(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Choose Language"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text    = "None  |cffaaaaaa(no translation)|r"
        info.value   = "None"
        info.checked = (Speaketh:GetLanguage() == "None")
        info.notCheckable = false
        info.func = function()
            Speaketh:SetLanguage("None")
            CloseDropDownMenus()
            Speaketh_UI:RefreshWindow()
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = " "
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        for _, key in ipairs(Speaketh_LanguageOrder) do
            local fluency = Speaketh_Fluency:Get(key)
            if fluency > 0 then
                info = UIDropDownMenu_CreateInfo()
                info.text    = string.format("%s  |cffaaaaaa(%d%%)|r", key, math.floor(fluency))
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

        info = UIDropDownMenu_CreateInfo()
        info.text = "— Not yet learned —"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        for _, key in ipairs(Speaketh_LanguageOrder) do
            if Speaketh_Fluency:Get(key) == 0 then
                info = UIDropDownMenu_CreateInfo()
                info.text = string.format("|cff555555%s|r", key)
                info.notCheckable = true
                info.disabled = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    UIDropDownMenu_Initialize(menuFrame, init, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, anchor or "cursor", 0, 0)
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

    UIDropDownMenu_Initialize(dialectMenuFrame, init, "MENU")
    ToggleDropDownMenu(1, nil, dialectMenuFrame, anchor or "cursor", 0, 0)
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
    hud:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hud:RegisterForDrag("LeftButton")
    hud:SetMovable(true)

    -- Restore saved position, or default to center-ish of the screen
    local pos = Speaketh_Char and Speaketh_Char.hudPos
    if pos and pos.point and pos.x and pos.y then
        hud:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end

    -- Dark slate backdrop with thin gold edge — matches Speak Window
    if hud.SetBackdrop then
        hud:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        hud:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
        hud:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
    end

    -- Language label in the center
    local label = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", hud, "CENTER", 0, 0)
    label:SetTextColor(1.0, 0.82, 0.0, 1)  -- gold
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
        if mouseButton == "LeftButton" then
            Speaketh_UI:ShowLanguageMenu(self)
        elseif mouseButton == "RightButton" then
            Speaketh_UI:ToggleSpeakWindow()
        end
    end)

    -- Tooltip
    hud:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffffcc00Speaketh|r")
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
