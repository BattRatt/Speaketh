-- Speaketh_UI.lua
-- Minimap button, floating language HUD and their combined language menu.
-- Windows and editors live in Speaketh_MatchedUI.lua.

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

    -- Theme-aware speaking Vulpera emblem.
    local logo = btn:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28)
    logo:SetPoint("CENTER", btn, "CENTER", 0, 0)
    Speaketh_Theme:Register(function()
        logo:SetTexture("Interface\\AddOns\\Speaketh\\Resources\\Brand\\" .. (Speaketh_Theme:Current() .. "32"))
    end)

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
-- Shared refresh
-- ============================================================
-- Refresh entry point retained for core and compatibility callers.
function Speaketh_UI:RefreshWindow()
    self:UpdateTooltip()
    if Speaketh_ReviewUI then Speaketh_ReviewUI:Refresh() end
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

local function ToggleDropDownSmart(frame, anchor)
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
            local langLabel = (curLang == "None") and "None" or Speaketh:GetLanguageDisplayName(curLang)
            info.text         = string.format("Language  |cffaaaaaa(%s)|r", langLabel)
            info.hasArrow     = true
            info.notCheckable = true
            info.value        = "LANG_SUBMENU"
            UIDropDownMenu_AddButton(info, level)

            -- ── Dialect arrow ─────────────────────────────────────
            info = UIDropDownMenu_CreateInfo()
            local activeDialect = Speaketh_Dialects:GetActive()
            local activeDialectData = activeDialect and Speaketh_Dialects:GetData(activeDialect)
            local dialectLabel  = activeDialect and ((activeDialectData and activeDialectData.name) or activeDialect) or "None"
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
                        info.text    = string.format("%s  |cffaaaaaa(%d%%)|r", Speaketh:GetLanguageDisplayName(key), math.floor(Speaketh_Fluency:Get(key)))
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
    ToggleDropDownSmart(menuFrame, anchor)
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
            Speaketh_UI:ToggleQuickSpeakWindow()
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
