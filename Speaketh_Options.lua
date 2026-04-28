-- Speaketh_Options.lua
-- Standalone options panel with a TRP3-style two-column layout:
-- a category list on the left, content area on the right.
--
-- Reachable via /sp options, the minimap button (shift+click or
-- middle-click), and the "Options" button on the Speak Window.

Speaketh_Options = {}

-- ============================================================
-- Confirm dialogs for destructive actions
-- ============================================================

-- Generic single-item delete confirm.
-- data = { name=string, onConfirm=function }
StaticPopupDialogs["SPEAKETH_CONFIRM_DELETE"] = {
    text = "Delete |cff88ccff%s|r?\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = CANCEL or "Cancel",
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnAccept = function(self, data)
        if data and data.onConfirm then data.onConfirm() end
    end,
}

-- Reset all learned fluency confirm.
-- data = { onConfirm=function }
StaticPopupDialogs["SPEAKETH_CONFIRM_RESET"] = {
    text = "Reset all language fluency to 0%%?",
    button1 = "Reset",
    button2 = CANCEL or "Cancel",
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnAccept = function(self, data)
        if data and data.onConfirm then data.onConfirm() end
    end,
}

-- Auto-learn all languages confirm.
-- data = { onConfirm=function }
StaticPopupDialogs["SPEAKETH_CONFIRM_AUTOLEARN"] = {
    text = "Set all language fluency to 100%%?\n\nEvery built-in and custom language will be fully learned.",
    button1 = "Learn All",
    button2 = CANCEL or "Cancel",
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnAccept = function(self, data)
        if data and data.onConfirm then data.onConfirm() end
    end,
}

-- ============================================================
-- Export / Import frames (custom Speaketh-styled, no StaticPopup)
--
-- StaticPopup's editbox is unreliable across WoW versions: text
-- color, maxLetters=0, highlighting, and the editBox accessor
-- all behave differently. These simple custom frames give us
-- full control and match the Speaketh visual style.
-- ============================================================

local _exportFrame, _importFrame  -- lazily created

-- Reusable builder for a small dialog with a title, description, editbox, and button(s).
local function MakeCodeDialog(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width, height)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 32, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.10, 0.97)
        f:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
    end

    -- Close X button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()

    -- Escape key closes this dialog (stacks correctly with other open panels).
    tinsert(UISpecialFrames, name)

    return f
end

-- ── EXPORT FRAME ──────────────────────────────────────────
local function GetExportFrame()
    if _exportFrame then return _exportFrame end

    local f = MakeCodeDialog("SpeakethExportFrame", 480, 170)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("Export Language")
    title:SetTextColor(1, 1, 1, 1)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Copy the code below and share it with other Speaketh users.")
    f._desc = desc

    -- Editbox with visible text on dark background
    local eb = CreateFrame("EditBox", "SpeakethExportEditBox", f, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    eb:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    eb:SetHeight(24)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetScript("OnEscapePressed", function(self) f:Hide() end)
    -- Make the text copyable but prevent editing the code
    eb:SetScript("OnChar", function(self)
        if f._code then self:SetText(f._code) end
    end)
    f._editBox = eb

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 24)
    okBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    okBtn:SetText(OKAY or "Okay")
    okBtn:SetScript("OnClick", function() f:Hide() end)

    _exportFrame = f
    return f
end

function Speaketh_Options:ShowExportCode(langKey, langName)
    local f = GetExportFrame()
    local code, err
    if Speaketh_Share and Speaketh_Share.ExportCode then
        code, err = Speaketh_Share:ExportCode(langKey)
    end
    if code then
        f._code = code
        f._editBox:SetText(code)
        f._desc:SetText("Copy the code below and share it with other Speaketh users.\nLanguage: |cff88ccff" .. (langName or "?") .. "|r")
    else
        f._code = ""
        f._editBox:SetText(err or "Export failed.")
        f._desc:SetText("Something went wrong generating the code.")
    end
    f:Show()
    f._editBox:SetFocus()
    f._editBox:HighlightText()
end

-- ── IMPORT FRAME ──────────────────────────────────────────
local function GetImportFrame()
    if _importFrame then return _importFrame end

    local f = MakeCodeDialog("SpeakethImportFrame", 480, 170)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("Import Language")
    title:SetTextColor(1, 1, 1, 1)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Paste a Speaketh import code below and click Import.")

    local eb = CreateFrame("EditBox", "SpeakethImportEditBox", f, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    eb:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    eb:SetHeight(24)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f._editBox = eb

    local statusLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLbl:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -4)
    statusLbl:SetText("")
    f._status = statusLbl

    local function DoImport()
        local code = strtrim(eb:GetText() or "")
        if code == "" then
            f._status:SetText("|cffff3333Paste a code first.|r")
            return
        end
        -- Dry-run to check for errors before committing
        if not Speaketh_Share or not Speaketh_Share.ImportCode then
            f._status:SetText("|cffff3333Share module not loaded.|r")
            return
        end
        local name, result = Speaketh_Share:ImportCode(code, false)
        if name then
            -- Success: import happened, show chat message, refresh panel, close
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffffcc00[Speaketh]|r Imported |cff88ccff%s|r (%d words). Fluency set to 100%%.",
                name, result))
            if _categoryPanels and _categoryPanels["newlanguage"]
               and _categoryPanels["newlanguage"].refresh then
                _categoryPanels["newlanguage"].refresh()
            end
            f:Hide()
        elseif result and result:sub(1, 10) == "COLLISION:" then
            -- Name collision: show overwrite confirm, close import frame
            local collidingName = result:sub(11)
            f:Hide()
            local dlg = StaticPopup_Show("SPEAKETH_IMPORT_OVERWRITE", collidingName)
            if dlg then
                dlg.data = { code = code, collidingName = collidingName }
            end
        else
            -- Error: show inline
            f._status:SetText("|cffff3333" .. (result or "Import failed.") .. "|r")
        end
    end

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(80, 24)
    importBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 12)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", DoImport)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 24)
    cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 12)
    cancelBtn:SetText(CANCEL or "Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    eb:SetScript("OnEnterPressed", DoImport)

    _importFrame = f
    return f
end

function Speaketh_Options:ShowImportCode()
    local f = GetImportFrame()
    f._editBox:SetText("")
    f._status:SetText("")
    f:Show()
    f._editBox:SetFocus()
end

-- Overwrite confirm after a collision is detected during import.
-- data = { code=string, collidingName=string, onRefresh=function }
StaticPopupDialogs["SPEAKETH_IMPORT_OVERWRITE"] = {
    text = "A language named |cff88ccff%s|r already exists.\n\nOverwrite it with the imported version?",
    button1 = "Overwrite",
    button2 = CANCEL or "Cancel",
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnAccept = function(self, data)
        if data and data.code then
            Speaketh_Options:HandleImport(data.code, true, data.onRefresh)
        end
    end,
    OnCancel = function(self, data) end,
}

-- ============================================================
-- Saved-var helpers
-- ============================================================
local function SV()
    return Speaketh_Char or {}
end

local function SetSV(key, value)
    if not Speaketh_Char then return end
    Speaketh_Char[key] = value
end

-- ============================================================
-- Shared widgets
-- ============================================================

-- Gold-styled button matching the Speaketh window aesthetic.
-- w, h are optional (defaults 62 x 20).
local function GoldBtn(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 62, h or 20)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(0.72, 0.58, 0.25, 0.12)
    local border = btn:CreateTexture(nil, "BORDER"); border:SetAllPoints()
    border:SetColorTexture(0.72, 0.58, 0.25, 0.35)
    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetAllPoints(); txt:SetText(string.upper(label)); txt:SetSpacing(1.0)
    txt:SetTextColor(0.85, 0.70, 0.35, 1)
    txt:SetJustifyH("CENTER"); txt:SetJustifyV("MIDDLE")
    btn.Text = txt; btn._bg = bg
    -- Route SetText/GetText to our custom fontstring so callers work normally
    btn.SetText = function(self, t) txt:SetText(t and string.upper(t) or "") end
    btn.GetText = function(self) return txt:GetText() end
    btn:SetScript("OnEnter", function() bg:SetColorTexture(0.72, 0.58, 0.25, 0.25) end)
    btn:SetScript("OnLeave", function() bg:SetColorTexture(0.72, 0.58, 0.25, 0.12) end)
    return btn
end

-- Create a checkbox with label + tooltip + saved-var bindings.
local function MakeCheck(parent, label, tooltip, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb.tooltipText = label
    cb.tooltipRequirement = tooltip
    cb:SetChecked(getVal() and true or false)
    cb:SetScript("OnClick", function(self)
        setVal(self:GetChecked() and true or false)
    end)
    cb.refresh = function()
        cb:SetChecked(getVal() and true or false)
    end
    return cb
end

-- ============================================================
-- Main window
-- ============================================================
-- Layout constants. SIDE_W is the total width of the left column (sidebar
-- buttons + their padding). SIDE_INSET is how far in from the sidebar's
-- left edge the buttons start, so they don't look cramped against the
-- outer border. The vertical divider between sidebar and content sits
-- at SIDE_W on the right.
local WIN_W, WIN_H  = 740, 620
local SIDE_W        = 150     -- total width of the sidebar column
local SIDE_INSET    = 18      -- left inset inside the sidebar (from window edge)
local SIDE_BTN_W    = SIDE_W - SIDE_INSET - 18  -- button width
local ROW_H         = 28
local ROW_GAP       = 4
local CONTENT_PAD_X = 24
local CONTENT_PAD_Y = 20

local _mainFrame
local _categoryButtons = {}   -- key -> button
local _categoryPanels  = {}   -- key -> panel frame
local _activeKey

local function SelectCategory(key)
    if not _categoryPanels[key] then return end
    _activeKey = key

    -- Button visuals: selected gets gold text + diamond + highlight bg
    for k, btn in pairs(_categoryButtons) do
        if k == key then
            if btn._bg then btn._bg:SetColorTexture(0.72, 0.58, 0.25, 0.15) end
            if btn.Text then btn.Text:SetTextColor(0.95, 0.82, 0.48, 1) end
            if btn._diamond then btn._diamond:SetTextColor(0.72, 0.58, 0.25, 1) end
        else
            if btn._bg then btn._bg:SetColorTexture(0, 0, 0, 0) end
            if btn.Text then
                -- top-level vs sub (sub buttons have a _dot marker)
                if btn._diamond then
                    btn.Text:SetTextColor(0.70, 0.58, 0.38, 1)
                    btn._diamond:SetTextColor(0.72, 0.58, 0.25, 0)
                else
                    btn.Text:SetTextColor(0.60, 0.50, 0.32, 1)
                end
            end
        end
    end

    -- Show the active panel, hide others
    for k, panel in pairs(_categoryPanels) do
        if k == key then
            panel:Show()
            if panel.refresh then panel.refresh() end
        else
            panel:Hide()
        end
    end
end

-- Register a category: a styled sidebar button and its content panel.
local function AddCategory(key, label, buildContent, yOffset)
    -- Custom flat sidebar button (no Blizzard chrome)
    local btn = CreateFrame("Button", nil, _mainFrame)
    btn:SetSize(SIDE_BTN_W, ROW_H)
    btn:SetPoint("TOPLEFT", _mainFrame, "TOPLEFT", SIDE_INSET, yOffset)
    btn:EnableMouse(true)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetColorTexture(0, 0, 0, 0)

    -- Diamond prefix + spaced label
    local btnDiamond = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnDiamond:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btnDiamond:SetText("|")
    btnDiamond:SetTextColor(0.72, 0.58, 0.25, 0)  -- hidden by default

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", btnDiamond, "RIGHT", 6, 0)
    btnText:SetText(string.upper(label))
    btnText:SetTextColor(0.70, 0.58, 0.38, 1)
    btnText:SetSpacing(1.5)
    btnText:SetJustifyH("LEFT")
    btn.Text = btnText
    btn._diamond = btnDiamond
    btn._bg = btnBg

    btn:SetScript("OnEnter", function(self)
        if _activeKey ~= key then
            btnBg:SetColorTexture(0.72, 0.58, 0.25, 0.08)
            btnText:SetTextColor(0.92, 0.78, 0.52, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if _activeKey ~= key then
            btnBg:SetColorTexture(0, 0, 0, 0)
            btnText:SetTextColor(0.70, 0.58, 0.38, 1)
        end
    end)
    btn:SetScript("OnClick", function() SelectCategory(key) end)
    _categoryButtons[key] = btn

    -- Thin separator below each button
    local sep = _mainFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, -1)
    sep:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, -1)
    sep:SetHeight(1)
    sep:SetColorTexture(0.72, 0.58, 0.25, 0.12)

    -- Content panel
    local panel = CreateFrame("Frame", nil, _mainFrame)
    panel:SetPoint("TOPLEFT",     _mainFrame, "TOPLEFT",     SIDE_W + 14, -50)
    panel:SetPoint("BOTTOMRIGHT", _mainFrame, "BOTTOMRIGHT", -14,          32)
    panel:Hide()
    _categoryPanels[key] = panel

    -- Panel title + italic tagline
    local ptitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ptitle:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_PAD_X, -6)
    ptitle:SetText(string.upper(label))
    ptitle:SetTextColor(0.92, 0.78, 0.42, 1)
    ptitle:SetSpacing(2)

    local div = panel:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT",  ptitle, "BOTTOMLEFT", 0, -8)
    div:SetPoint("RIGHT",    panel,  "RIGHT", -CONTENT_PAD_X, 0)
    div:SetHeight(1)
    div:SetColorTexture(0.72, 0.58, 0.25, 0.60)

    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetPoint("TOPLEFT",     div,   "BOTTOMLEFT",    0,   -CONTENT_PAD_Y)
    panel.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -CONTENT_PAD_X, CONTENT_PAD_Y)

    buildContent(panel)
    return panel
end

-- Sub-category button (indented, slightly smaller)
local function AddSubCategory(key, label, buildContent, yOffset)
    local SUB_INSET = SIDE_INSET + 14
    local SUB_W     = SIDE_BTN_W - 14
    local SUB_H     = 24

    local btn = CreateFrame("Button", nil, _mainFrame)
    btn:SetSize(SUB_W, SUB_H)
    btn:SetPoint("TOPLEFT", _mainFrame, "TOPLEFT", SUB_INSET, yOffset)
    btn:EnableMouse(true)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetColorTexture(0, 0, 0, 0)

    local btnDot = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnDot:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btnDot:SetText("+")
    btnDot:SetTextColor(0.72, 0.58, 0.25, 0.50)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", btnDot, "RIGHT", 5, 0)
    btnText:SetText(string.upper(label))
    btnText:SetTextColor(0.60, 0.50, 0.32, 1)
    btnText:SetSpacing(1.2)
    btnText:SetJustifyH("LEFT")
    btn.Text = btnText
    btn._bg  = btnBg

    btn:SetScript("OnEnter", function()
        if _activeKey ~= key then
            btnBg:SetColorTexture(0.72, 0.58, 0.25, 0.08)
            btnText:SetTextColor(0.92, 0.78, 0.52, 1)
        end
    end)
    btn:SetScript("OnLeave", function()
        if _activeKey ~= key then
            btnBg:SetColorTexture(0, 0, 0, 0)
            btnText:SetTextColor(0.60, 0.50, 0.32, 1)
        end
    end)
    btn:SetScript("OnClick", function() SelectCategory(key) end)
    _categoryButtons[key] = btn

    local panel = CreateFrame("Frame", nil, _mainFrame)
    panel:SetPoint("TOPLEFT",     _mainFrame, "TOPLEFT",     SIDE_W + 14, -50)
    panel:SetPoint("BOTTOMRIGHT", _mainFrame, "BOTTOMRIGHT", -14,          32)
    panel:Hide()
    _categoryPanels[key] = panel

    local ptitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ptitle:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_PAD_X, -6)
    ptitle:SetText(string.upper(label))
    ptitle:SetTextColor(0.92, 0.78, 0.42, 1)
    ptitle:SetSpacing(2)

    local div = panel:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT",  ptitle, "BOTTOMLEFT", 0, -8)
    div:SetPoint("RIGHT",    panel,  "RIGHT", -CONTENT_PAD_X, 0)
    div:SetHeight(1)
    div:SetColorTexture(0.72, 0.58, 0.25, 0.60)

    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetPoint("TOPLEFT",     div,   "BOTTOMLEFT",    0,   -CONTENT_PAD_Y)
    panel.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -CONTENT_PAD_X, CONTENT_PAD_Y)

    buildContent(panel)
    return panel
end


-- ============================================================
-- Category: General
-- ============================================================
local function BuildGeneralPanel(panel)
    local body = panel.body

    local autoCB = MakeCheck(body,
        "Auto-translate normal chat",
        "When enabled, your active language and dialect apply automatically to /say, /yell, party, raid, guild, etc.",
        function() return SV().autoChat ~= false end,
        function(v) SetSV("autoChat", v) end)
    autoCB:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)

    local learnCB = MakeCheck(body,
        "Learn languages passively",
        "When enabled, you slowly gain fluency in languages you hear spoken by other characters.",
        function() return SV().passiveLearn ~= false end,
        function(v) SetSV("passiveLearn", v) end)
    learnCB:SetPoint("TOPLEFT", autoCB, "BOTTOMLEFT", 0, -4)

    local mmCB = MakeCheck(body,
        "Show minimap button",
        "Toggle the Speaketh minimap button.",
        function() return SV().showMinimap ~= false end,
        function(v)
            SetSV("showMinimap", v)
            if Speaketh_UI and Speaketh_UI.ApplyMinimapVisibility then
                Speaketh_UI:ApplyMinimapVisibility()
            end
        end)
    mmCB:SetPoint("TOPLEFT", learnCB, "BOTTOMLEFT", 0, -4)

    local hudCB = MakeCheck(body,
        "Show floating language HUD",
        "Toggle the draggable on-screen button showing your current language.\n\nLeft-click: change language.\nRight-click: open the Speak Window.",
        function() return SV().showLangHUD ~= false end,
        function(v)
            SetSV("showLangHUD", v)
            if Speaketh_UI and Speaketh_UI.ApplyLanguageHUDVisibility then
                Speaketh_UI:ApplyLanguageHUDVisibility()
            end
        end)
    hudCB:SetPoint("TOPLEFT", mmCB, "BOTTOMLEFT", 0, -4)

    local splashCB = MakeCheck(body,
        "Show splash on login",
        "Show the welcome splash screen each time you log in. Disable to only see it on first login.",
        function() return SV().showSplash == true end,
        function(v) SetSV("showSplash", v) end)
    splashCB:SetPoint("TOPLEFT", hudCB, "BOTTOMLEFT", 0, -4)

    local lockdownCB = MakeCheck(body,
        "Show Lockdown Notifications",
        "Print a message in chat when combat lockdown begins or ends, indicating whether translation is active.",
        function() return SV().showLockdownNotify == true end,
        function(v) SetSV("showLockdownNotify", v) end)
    lockdownCB:SetPoint("TOPLEFT", splashCB, "BOTTOMLEFT", 0, -4)

    -- ---- Channel enable/disable section ----
    local chanHeader = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanHeader:SetPoint("TOPLEFT", lockdownCB, "BOTTOMLEFT", 0, -16)
    chanHeader:SetText("Translate in channels:")
    chanHeader:SetTextColor(1.0, 0.82, 0.0, 1)

    local chanDefs = {
        { key="chanSay",      label="/say",           tip="Translate messages sent in /say." },
        { key="chanYell",     label="/yell",          tip="Translate messages sent in /yell." },
        { key="chanParty",    label="/party & /raid", tip="Translate messages sent in /party and /raid." },
        { key="chanGuild",    label="/guild & /officer", tip="Translate messages sent in /guild and /officer." },
        { key="chanInstance", label="/instance",      tip="Translate messages sent in instance chat." },
        { key="chanWhisper",  label="/whisper",       tip="Translate messages sent as whispers." },
        { key="chanEmote",    label="/emote",         tip="Translate quoted speech inside /emote messages." },
    }

    local chanCBs = {}
    local prevAnchor = chanHeader
    local prevAnchorPoint = "BOTTOMLEFT"
    -- Two-column layout: left col = entries 1-4, right col = entries 5-7
    for i, def in ipairs(chanDefs) do
        local d = def  -- upvalue capture
        local cb = MakeCheck(body,
            d.label,
            d.tip,
            function() return SV()[d.key] ~= false end,
            function(v) SetSV(d.key, v) end)
        if i == 1 then
            cb:SetPoint("TOPLEFT", chanHeader, "BOTTOMLEFT", 0, -4)
        elseif i == 5 then
            -- Start second column
            cb:SetPoint("TOPLEFT", chanHeader, "BOTTOMLEFT", 180, -4)
        elseif i < 5 then
            cb:SetPoint("TOPLEFT", chanCBs[i-1], "BOTTOMLEFT", 0, -2)
        else
            cb:SetPoint("TOPLEFT", chanCBs[i-1], "BOTTOMLEFT", 0, -2)
        end
        chanCBs[i] = cb
    end
    local lastChanCB = chanCBs[#chanDefs < 4 and #chanDefs or 4]  -- bottom of left column

    -- Auto learn all languages
    local autoLearnBtn = GoldBtn(body, "")
    autoLearnBtn:SetSize(180, 24)
    autoLearnBtn:SetPoint("TOPLEFT", lastChanCB, "BOTTOMLEFT", 0, -20)
    autoLearnBtn:SetText("Auto learn languages")
    autoLearnBtn:SetScript("OnClick", function()
        local dlg = StaticPopup_Show("SPEAKETH_CONFIRM_AUTOLEARN")
        if dlg then
            dlg.data = { onConfirm = function()
                if Speaketh_Fluency and Speaketh_LanguageOrder then
                    for _, key in ipairs(Speaketh_LanguageOrder) do
                        Speaketh_Fluency:Set(key, 100)
                    end
                    if Speaketh_UI and Speaketh_UI.RefreshWindow then
                        Speaketh_UI:RefreshWindow()
                    end
                    -- Refresh the options panel so language lists, fluency labels, etc. update immediately
                    if _categoryPanels and _activeKey and _categoryPanels[_activeKey]
                       and _categoryPanels[_activeKey].refresh then
                        _categoryPanels[_activeKey].refresh()
                    end
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cffffcc00[Speaketh]|r All languages set to 100%% fluency.")
                end
            end }
        end
    end)

    -- Reset learned languages
    local resetBtn = GoldBtn(body, "")
    resetBtn:SetSize(180, 24)
    resetBtn:SetPoint("TOPLEFT", autoLearnBtn, "BOTTOMLEFT", 0, -8)
    resetBtn:SetText("Reset learned languages")
    resetBtn:SetScript("OnClick", function()
        local dlg = StaticPopup_Show("SPEAKETH_CONFIRM_RESET")
        if dlg then
            dlg.data = { onConfirm = function()
                if Speaketh_Char and Speaketh_Fluency and Speaketh_LanguageOrder then
                    for _, key in ipairs(Speaketh_LanguageOrder) do
                        Speaketh_Fluency:Set(key, 0)
                    end
                    if Speaketh_UI and Speaketh_UI.RefreshWindow then
                        Speaketh_UI:RefreshWindow()
                    end
                    -- Refresh the options panel so language lists, fluency labels, etc. update immediately
                    if _categoryPanels and _activeKey and _categoryPanels[_activeKey]
                       and _categoryPanels[_activeKey].refresh then
                        _categoryPanels[_activeKey].refresh()
                    end
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cffffcc00[Speaketh]|r All language fluency reset to 0%%.")
                end
            end }
        end
    end)

    local openBtn = GoldBtn(body, "")
    openBtn:SetSize(180, 24)
    openBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -8)
    openBtn:SetText("Open Speak Window")
    openBtn:SetScript("OnClick", function()
        if Speaketh_UI and Speaketh_UI.ToggleSpeakWindow then
            Speaketh_UI:ToggleSpeakWindow()
        end
    end)

    panel.refresh = function()
        autoCB.refresh()
        learnCB.refresh()
        mmCB.refresh()
        hudCB.refresh()
        splashCB.refresh()
        lockdownCB.refresh()
        for _, cb in ipairs(chanCBs) do cb.refresh() end
    end
end

-- ============================================================
-- Shared inner-tab helper
-- ============================================================
local function MakeInnerTab(parent, label, x, y, w, onClick)
    local btn = GoldBtn(parent, "")
    btn:SetSize(w or 88, 22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ============================================================
-- ============================================================
-- Shared helpers for Word Rules sub-panels
-- ============================================================

-- Shared scroll list used by all Word Rules sub-panels.
-- Returns: scroll frame, content frame, rows table, SyncWidth fn, WipeRows fn.
local function MakeScrollList(parent, anchorTop, anchorBottom)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     anchorTop,    "BOTTOMLEFT",  0, -4)
    scroll:SetPoint("BOTTOMRIGHT", anchorBottom, "BOTTOMRIGHT", -24, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local function SyncWidth()
        local w = scroll:GetWidth()
        if w and w > 0 then content:SetWidth(w) end
    end
    scroll:SetScript("OnSizeChanged", SyncWidth)
    SyncWidth()

    local rows = {}
    local function WipeRows()
        for _, r in ipairs(rows) do r:Hide() end
        wipe(rows)
    end

    return scroll, content, rows, WipeRows
end

local function MakeStatusLabel(parent, anchor)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    lbl:SetText("")
    local function SetStatus(msg, isError)
        lbl:SetText(msg)
        lbl:SetTextColor(isError and 1 or 0.4, isError and 0.3 or 0.9, isError and 0.3 or 0.4, 1)
    end
    return lbl, SetStatus
end

local function MakeListHeader(parent, anchor, title)
    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    hdr:SetText(title)
    hdr:SetTextColor(1.0, 0.82, 0.0, 1)
    local cnt = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cnt:SetPoint("LEFT", hdr, "RIGHT", 8, 0)
    cnt:SetTextColor(0.6, 0.6, 0.6, 1)
    return hdr, cnt
end

-- ============================================================
-- Sub-panel: Dialect Rules
-- One tab per non-Drunk dialect. Shows word-swap rules for the
-- selected dialect with Edit, Remove, and Add support.
-- ============================================================
local function BuildDialectRulesPanel(panel)
    local body = panel.body

    local desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    desc:SetPoint("RIGHT",   body, "RIGHT",   0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Each dialect has a list of word swaps that fire when it is active.\nSelect a dialect below to view and edit its rules.")
    desc:SetHeight(30)

    local TAB_Y  = -36
    local TAB_H  = 22
    local TAB_W  = 76
    local TAB_GAP = 4

    local tabRow = CreateFrame("Frame", nil, body)
    tabRow:SetPoint("TOPLEFT",  body, "TOPLEFT",  0, TAB_Y)
    tabRow:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, TAB_Y)
    tabRow:SetHeight(TAB_H)

    local tabDiv = body:CreateTexture(nil, "ARTWORK")
    tabDiv:SetPoint("TOPLEFT",  body, "TOPLEFT",  0, TAB_Y - TAB_H - 2)
    tabDiv:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, TAB_Y - TAB_H - 2)
    tabDiv:SetHeight(2)
    tabDiv:SetColorTexture(0.60, 0.48, 0.22, 0.75)

    local selectedDialect = nil
    local tabBtns = {}
    local RebuildTabs
    local RebuildContent

    local function SelectTab(key)
        selectedDialect = key
        for k, btn in pairs(tabBtns) do
            if k == key then
                btn:LockHighlight()
                if btn.Text then btn.Text:SetTextColor(1.0, 0.82, 0.0, 1) end
            else
                btn:UnlockHighlight()
                if btn.Text then btn.Text:SetTextColor(0.9, 0.9, 0.9, 1) end
            end
        end
        if RebuildContent then RebuildContent() end
    end

    RebuildTabs = function()
        for _, btn in pairs(tabBtns) do btn:Hide() end
        wipe(tabBtns)
        local x = 0
        local _, order = Speaketh_Dialects:GetAll()
        for _, key in ipairs(order) do
            if key ~= "Drunk" then
                local d        = Speaketh_Dialects:GetData(key)
                local isCustom = Speaketh_Dialects:IsCustomDialect(key)
                local label    = isCustom and ("* " .. d.name) or d.name
                local btn      = GoldBtn(tabRow, "")
                btn:SetSize(TAB_W, TAB_H)
                btn:SetPoint("TOPLEFT", tabRow, "TOPLEFT", x, 0)
                btn:SetText(label)
                local capturedKey = key
                btn:SetScript("OnClick", function() SelectTab(capturedKey) end)
                tabBtns[key] = btn
                x = x + TAB_W + TAB_GAP
                if not selectedDialect then selectedDialect = key end
            end
        end
        for k, btn in pairs(tabBtns) do
            if k == selectedDialect then
                btn:LockHighlight()
                if btn.Text then btn.Text:SetTextColor(1.0, 0.82, 0.0, 1) end
            end
        end
    end

    local CONTENT_Y = TAB_Y - TAB_H - 10

    -- Input row
    local inputRow = CreateFrame("Frame", nil, body)
    inputRow:SetPoint("TOPLEFT",  body, "TOPLEFT",  0, CONTENT_Y)
    inputRow:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, CONTENT_Y)
    inputRow:SetHeight(22)

    local inputLabel = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("LEFT", inputRow, "LEFT", 0, 0)
    inputLabel:SetText("Replace:")
    inputLabel:SetTextColor(1.0, 0.82, 0.0, 1)

    local fromBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
    fromBox:SetSize(112, 22)
    fromBox:SetPoint("LEFT", inputLabel, "RIGHT", 8, 0)
    fromBox:SetAutoFocus(false)
    fromBox:SetMaxLetters(64)

    local arrowLbl = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowLbl:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
    arrowLbl:SetText("->")

    local toBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
    toBox:SetSize(112, 22)
    toBox:SetPoint("LEFT", arrowLbl, "RIGHT", 6, 0)
    toBox:SetAutoFocus(false)
    toBox:SetMaxLetters(64)

    local actionBtn = GoldBtn(inputRow, "")
    actionBtn:SetSize(52, 22)
    actionBtn:SetPoint("LEFT", toBox, "RIGHT", 8, 0)
    actionBtn:SetText("Add")

    local cancelBtn = GoldBtn(inputRow, "")
    cancelBtn:SetSize(56, 22)
    cancelBtn:SetPoint("LEFT", actionBtn, "RIGHT", 4, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:Hide()

    local statusLbl, SetStatus = MakeStatusLabel(body, inputRow)
    local listHdr, listCount   = MakeListHeader(body, statusLbl, "Rules")

    local _, content, rows, WipeRows = MakeScrollList(body, listHdr, body)

    local editingIndex = 0
    local function ClearEdit()
        editingIndex = 0
        fromBox:SetText(""); toBox:SetText("")
        fromBox:ClearFocus(); toBox:ClearFocus()
        actionBtn:SetText("Add"); cancelBtn:Hide()
        SetStatus("", false)
    end

    RebuildContent = function()
        WipeRows()
        if not selectedDialect then
            listCount:SetText("")
            local e = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            e:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
            e:SetText("(select a dialect tab above)")
            table.insert(rows, e); content:SetHeight(20); return
        end

        local subs = Speaketh_Dialects:GetCustomSubstitutes(selectedDialect)
        listCount:SetText("(" .. #subs .. " rule" .. (#subs == 1 and "" or "s") .. ")")

        local y = 0

        -- Delete-dialect button for custom dialects
        if Speaketh_Dialects:IsCustomDialect(selectedDialect) then
            local drow = CreateFrame("Frame", nil, content)
            drow:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
            drow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            drow:SetHeight(24)
            local delbtn = GoldBtn(drow, "")
            delbtn:SetSize(140, 20)
            delbtn:SetPoint("LEFT", drow, "LEFT", 4, 0)
            delbtn:SetText("Delete this dialect")
            delbtn:SetScript("OnClick", function()
                local capturedDialect = selectedDialect
                local capturedName = (Speaketh_Dialects:GetData(capturedDialect) or {}).name or capturedDialect
                local dlg = StaticPopup_Show("SPEAKETH_CONFIRM_DELETE", capturedName)
                if dlg then
                    dlg.data = { name = capturedName, onConfirm = function()
                        local ok, err = Speaketh_Dialects:RemoveCustomDialect(capturedDialect)
                        if ok then
                            selectedDialect = nil
                            ClearEdit(); RebuildTabs(); RebuildContent()
                        else SetStatus(err or "Could not delete.", true) end
                    end }
                end
            end)
            local note = drow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            note:SetPoint("LEFT", delbtn, "RIGHT", 8, 0)
            note:SetText("|cffaaaaaa(removes dialect and all its rules)|r")
            table.insert(rows, drow); y = y + 28
        end

        for i, entry in ipairs(subs) do
            local isEditing = (i == editingIndex)
            local row = CreateFrame("Frame", nil, content)
            row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            row:SetHeight(22)
            local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
            if isEditing then bg:SetColorTexture(0.55, 0.45, 0.20, 0.12)
            elseif i%2==0 then bg:SetColorTexture(1,1,1,0.03)
            else bg:SetColorTexture(0,0,0,0) end

            local ft = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ft:SetPoint("LEFT", row, "LEFT", 4, 0); ft:SetWidth(130); ft:SetJustifyH("LEFT")
            ft:SetText("|cffcccccc" .. entry[1] .. "|r")

            local at = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            at:SetPoint("LEFT", ft, "RIGHT", 2, 0); at:SetText("->"); at:SetTextColor(0.55,0.45,0.20,1)

            local tt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            tt:SetPoint("LEFT", at, "RIGHT", 2, 0); tt:SetWidth(130); tt:SetJustifyH("LEFT")
            tt:SetText("|cff88ccff" .. entry[2] .. "|r")

            local delBtn = GoldBtn(row, "")
            delBtn:SetSize(58, 18); delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0); delBtn:SetText("Remove")
            local ci = i
            delBtn:SetScript("OnClick", function()
                if editingIndex == ci then ClearEdit() end
                if editingIndex > ci then editingIndex = editingIndex - 1 end
                Speaketh_Dialects:RemoveCustomSubstitute(selectedDialect, ci)
                SetStatus("Rule removed.", false); RebuildContent()
            end)

            local editBtn = GoldBtn(row, "")
            editBtn:SetSize(40, 18); editBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0); editBtn:SetText("Edit")
            editBtn:SetScript("OnClick", function()
                editingIndex = ci
                fromBox:SetText(entry[1]); toBox:SetText(entry[2]); fromBox:SetFocus()
                actionBtn:SetText("Save"); cancelBtn:Show()
                SetStatus("Editing rule " .. ci .. " — change the fields and press Save.", false)
                RebuildContent()
            end)

            table.insert(rows, row); y = y + 24
        end

        if #subs == 0 then
            local e = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            e:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y-4)
            e:SetText("(no rules yet — use the Replace field above to add one)")
            table.insert(rows, e); content:SetHeight(y+20)
        else content:SetHeight(math.max(y,1)) end
    end

    actionBtn:SetScript("OnClick", function()
        local from = (fromBox:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        local to   = (toBox:GetText()   or ""):gsub("^%s+",""):gsub("%s+$","")
        if editingIndex > 0 then
            if from=="" then SetStatus("Word/phrase cannot be empty.",true) return end
            if to==""   then SetStatus("Replacement cannot be empty.",true) return end
            local subs = Speaketh_Dialects:GetCustomSubstitutes(selectedDialect)
            local fl = from:lower()
            for j,e in ipairs(subs) do
                if j~=editingIndex and e[1]:lower()==fl then
                    SetStatus('"'..from..'" already exists as a different rule.',true) return
                end
            end
            Speaketh_Dialects:RemoveCustomSubstitute(selectedDialect, editingIndex)
            table.insert(Speaketh_Char.dialectSubstitutes[selectedDialect], editingIndex, {from, to})
            SetStatus("Rule updated: \""..from.."\" -> \""..to.."\"", false)
            ClearEdit(); RebuildContent()
        else
            local ok, err = Speaketh_Dialects:AddCustomSubstitute(selectedDialect, from, to)
            if ok then
                SetStatus("Rule added: \""..from.."\" -> \""..to.."\"", false)
                fromBox:SetText(""); toBox:SetText(""); fromBox:SetFocus(); RebuildContent()
            else SetStatus(err or "Could not add rule.", true) end
        end
    end)
    cancelBtn:SetScript("OnClick", function() ClearEdit(); RebuildContent() end)
    fromBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); toBox:SetFocus() end)
    toBox:SetScript("OnEnterPressed",   function() actionBtn:GetScript("OnClick")(actionBtn) end)
    fromBox:SetScript("OnEscapePressed", function(self)
        if editingIndex>0 then ClearEdit(); RebuildContent() else self:ClearFocus() end end)
    toBox:SetScript("OnEscapePressed", function(self)
        if editingIndex>0 then ClearEdit(); RebuildContent() else self:ClearFocus() end end)

    panel.refresh = function()
        local active = Speaketh_Dialects:GetActive()
        if active and active ~= "Drunk" then selectedDialect = active end
        ClearEdit(); RebuildTabs(); RebuildContent()
    end
    RebuildTabs()
    if selectedDialect then SelectTab(selectedDialect) else RebuildContent() end
end

-- ============================================================
-- Sub-panel: New Dialect
-- Create a custom dialect and manage existing ones.
-- ============================================================
local function BuildNewDialectPanel(panel)
    local body = panel.body

    local desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    desc:SetPoint("RIGHT",   body, "RIGHT",   0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("A dialect modifies how you speak — swapping specific words and phrases when active.\nGive it a name, create it, then add word rules from the Dialect Rules page.")
    desc:SetHeight(30)

    local nameLbl = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    nameLbl:SetText("Dialect name:")
    nameLbl:SetTextColor(1.0, 0.82, 0.0, 1)

    local nameBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    nameBox:SetSize(160, 22)
    nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)

    local createBtn = GoldBtn(body, "")
    createBtn:SetSize(120, 22)
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    createBtn:SetText("Create Dialect")

    local statusLbl, SetStatus = MakeStatusLabel(body, nameLbl)
    local listHdr, listCount   = MakeListHeader(body, statusLbl, "Your custom dialects")

    local _, content, rows, WipeRows = MakeScrollList(body, listHdr, body)

    local function Rebuild()
        WipeRows()
        local _, order = Speaketh_Dialects:GetAll()
        local hasCustom = false
        local y = 0
        for _, key in ipairs(order) do
            if Speaketh_Dialects:IsCustomDialect(key) then
                hasCustom = true
                local d    = Speaketh_Dialects:GetData(key)
                local subs = Speaketh_Dialects:GetCustomSubstitutes(key)

                local row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
                row:SetHeight(22)
                if (y/22)%2==0 then
                    local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,1,1,0.03)
                end

                local nt = row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
                nt:SetPoint("LEFT",row,"LEFT",4,0); nt:SetText(d.name); nt:SetWidth(160); nt:SetJustifyH("LEFT")

                local ct = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                ct:SetPoint("LEFT",nt,"RIGHT",8,0)
                ct:SetText(#subs.." rule"..(#subs==1 and "" or "s")); ct:SetTextColor(0.6,0.6,0.6,1)

                local delBtn = GoldBtn(row, "")
                delBtn:SetSize(52,18); delBtn:SetPoint("RIGHT",row,"RIGHT",-4,0); delBtn:SetText("Delete")
                local ck, cn = key, d.name
                delBtn:SetScript("OnClick", function()
                    local dlg = StaticPopup_Show("SPEAKETH_CONFIRM_DELETE", cn)
                    if dlg then
                        dlg.data = { name = cn, onConfirm = function()
                            Speaketh_Dialects:RemoveCustomDialect(ck)
                            SetStatus('"'..cn..'" deleted.', false); Rebuild()
                        end }
                    end
                end)

                table.insert(rows, row); y = y + 24
            end
        end
        listCount:SetText(hasCustom and "" or "")
        if not hasCustom then
            local e = content:CreateFontString(nil,"OVERLAY","GameFontDisable")
            e:SetPoint("TOPLEFT",content,"TOPLEFT",4,-4)
            e:SetText("(no custom dialects yet)")
            table.insert(rows,e); content:SetHeight(20)
        else content:SetHeight(math.max(y,1)) end
    end

    createBtn:SetScript("OnClick", function()
        local name = (nameBox:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        local ok, result = Speaketh_Dialects:AddCustomDialect(name)
        if ok then
            nameBox:SetText("")
            SetStatus('"'..name..'" created. Go to Dialect Rules to add word swaps.', false)
            Rebuild()
        else SetStatus(result or "Could not create dialect.", true) end
    end)
    nameBox:SetScript("OnEnterPressed", function() createBtn:GetScript("OnClick")(createBtn) end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    panel.refresh = function() SetStatus("",false); Rebuild() end
    Rebuild()
end

-- ============================================================
-- Sub-panel: New Language
-- Create a custom language (random word pool, learnable via fluency).
-- ============================================================
local function BuildNewLanguagePanel(panel)
    local body = panel.body

    local desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    desc:SetPoint("RIGHT",   body, "RIGHT",   0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("A language is a pool of words your text is scrambled into when speaking.\nIt starts at 0% fluency and can be learned. Enter at least 6 words, comma-separated.")
    desc:SetHeight(30)

    -- Row 1: Language name [ _________________ ]
    local nameLbl = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    nameLbl:SetText("Language name:")
    nameLbl:SetTextColor(1.0, 0.82, 0.0, 1)

    local nameBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    nameBox:SetSize(180, 22)
    nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)

    -- Row 2: Words: [ ______________________________________________ ]
    local wordRow = CreateFrame("Frame", nil, body)
    wordRow:SetPoint("TOPLEFT",  nameLbl, "BOTTOMLEFT", 0, -12)
    wordRow:SetPoint("TOPRIGHT", body,    "TOPRIGHT",   0,   0)
    wordRow:SetHeight(22)

    local wordLbl = wordRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wordLbl:SetPoint("LEFT", wordRow, "LEFT", 0, 0)
    wordLbl:SetText("Words:")
    wordLbl:SetTextColor(1.0, 0.82, 0.0, 1)

    local wordHint = wordRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wordHint:SetPoint("LEFT", wordLbl, "RIGHT", 6, 0)
    wordHint:SetText("|cffaaaaaa e.g.: lok, zul, mak, kaz, tor, ash|r")

    local wordBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    wordBox:SetPoint("TOPLEFT",  wordRow, "BOTTOMLEFT",  0, -4)
    wordBox:SetPoint("TOPRIGHT", body,    "TOPRIGHT",    0, -4)
    wordBox:SetHeight(22)
    wordBox:SetAutoFocus(false)
    wordBox:SetMaxLetters(2048)

    -- Add Language button + Import from Code button — same row, side by side
    local createBtn = GoldBtn(body, "")
    createBtn:SetSize(110, 22)
    createBtn:SetPoint("TOPLEFT", wordBox, "BOTTOMLEFT", 0, -8)
    createBtn:SetText("Add Language")

    local importBtn = GoldBtn(body, "")
    importBtn:SetSize(130, 22)
    importBtn:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)
    importBtn:SetText("Import from code")
    importBtn:SetScript("OnClick", function()
        Speaketh_Options:ShowImportCode()
    end)

    local statusLbl, SetStatus = MakeStatusLabel(body, createBtn)

    local listHdr = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHdr:SetPoint("TOPLEFT", statusLbl, "BOTTOMLEFT", 0, -8)
    listHdr:SetText("Your custom languages")
    listHdr:SetTextColor(1.0, 0.82, 0.0, 1)

    local _, content, rows, WipeRows = MakeScrollList(body, listHdr, body)

    -- Tracks whether we are editing an existing language
    local editingKey = nil

    local function Rebuild()
        WipeRows()
        local y = 0
        local hasLang = false
        if Speaketh_Char and Speaketh_Char.customLanguages then
            for key, data in pairs(Speaketh_Char.customLanguages) do
                hasLang = true
                local row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
                row:SetHeight(22)
                if (y/22)%2==0 then
                    local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,1,1,0.03)
                end

                local nt = row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
                nt:SetPoint("LEFT",row,"LEFT",4,0); nt:SetText(data.name); nt:SetWidth(140); nt:SetJustifyH("LEFT")

                local wc = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                wc:SetPoint("LEFT",nt,"RIGHT",8,0)
                wc:SetText(#data.words.." word"..(#data.words==1 and "" or "s")); wc:SetTextColor(0.6,0.6,0.6,1)

                local fl = Speaketh_Fluency and math.floor(Speaketh_Fluency:Get(key)) or 0
                local fc = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                fc:SetPoint("LEFT",wc,"RIGHT",8,0); fc:SetText(fl.."%% fluency"); fc:SetTextColor(0.55,0.75,1.0,1)

                local delBtn = GoldBtn(row, "")
                delBtn:SetSize(52,18); delBtn:SetPoint("RIGHT",row,"RIGHT",-4,0); delBtn:SetText("Delete")
                local ck, cn, cw = key, data.name, data.words
                delBtn:SetScript("OnClick", function()
                    local dlg = StaticPopup_Show("SPEAKETH_CONFIRM_DELETE", cn)
                    if dlg then
                        dlg.data = { name = cn, onConfirm = function()
                            Speaketh_Char.customLanguages[ck] = nil
                            if Speaketh_Char.fluency then Speaketh_Char.fluency[ck] = nil end
                            Speaketh_UnregisterCustomLanguage(ck)
                            if Speaketh_Char.language == ck then Speaketh_Char.language = "None" end
                            if editingKey == ck then editingKey = nil; createBtn:SetText("Add Language") end
                            SetStatus('"'..cn..'" deleted.', false); Rebuild()
                        end }
                    end
                end)

                local editBtn = GoldBtn(row, "")
                editBtn:SetSize(40,18); editBtn:SetPoint("RIGHT",delBtn,"LEFT",-4,0); editBtn:SetText("Edit")
                editBtn:SetScript("OnClick", function()
                    editingKey = ck
                    nameBox:SetText(cn)
                    nameBox:Disable()
                    nameBox:SetTextColor(0.5, 0.5, 0.5)
                    wordBox:SetText(table.concat(cw, ", "))
                    createBtn:SetText("Save Changes")
                    SetStatus('Editing "'..cn..'" — modify words above and click Save Changes.', false)
                    wordBox:SetFocus()
                end)

                local shareBtn = GoldBtn(row, "")
                shareBtn:SetSize(46,18); shareBtn:SetPoint("RIGHT",editBtn,"LEFT",-4,0); shareBtn:SetText("Share")
                shareBtn:SetScript("OnClick", function()
                    Speaketh_Options:ShowExportCode(ck, cn)
                end)

                table.insert(rows, row); y = y + 24
            end
        end
        if not hasLang then
            local e = content:CreateFontString(nil,"OVERLAY","GameFontDisable")
            e:SetPoint("TOPLEFT",content,"TOPLEFT",4,-4)
            e:SetText("(no custom languages yet)")
            table.insert(rows,e); content:SetHeight(20)
        else content:SetHeight(math.max(y,1)) end
    end

    createBtn:SetScript("OnClick", function()
        local wordStr = (wordBox:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        local wordList = {}
        for w in wordStr:gmatch("[^,]+") do
            local t = w:gsub("^%s+",""):gsub("%s+$",""):lower()
            if t~="" and t:match("^[%a]+$") then table.insert(wordList, t) end
        end
        if #wordList < 6 then SetStatus("Enter at least 6 words (comma-separated).", true) return end

        if editingKey then
            -- Editing existing language: update words in place, keep fluency
            local existingData = Speaketh_Char.customLanguages[editingKey]
            local displayName = existingData and existingData.name or editingKey
            Speaketh_Char.customLanguages[editingKey] = { name=displayName, words=wordList }
            Speaketh_RegisterCustomLanguage(editingKey, displayName, wordList)

            nameBox:SetText(""); nameBox:Enable(); nameBox:SetTextColor(1, 1, 1)
            wordBox:SetText("")
            createBtn:SetText("Add Language")
            SetStatus('"'..displayName..'" updated ('..#wordList..' words).', false)
            editingKey = nil
            Rebuild()
        else
            -- Creating new language
            local name = (nameBox:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
            if name=="" then SetStatus("Language name cannot be empty.", true) return end
            if #name>32 then SetStatus("Name too long (max 32 characters).", true) return end

            local key = "CustomLang_" .. name:gsub("%s+","_"):gsub("[^%w_]","")
            if key=="CustomLang_" then SetStatus("Name must contain letters or numbers.", true) return end
            if Speaketh_Languages[key] then SetStatus('"'..name..'" already exists.', true) return end

            if not Speaketh_Char.customLanguages then Speaketh_Char.customLanguages = {} end
            Speaketh_Char.customLanguages[key] = { name=name, words=wordList }
            Speaketh_RegisterCustomLanguage(key, name, wordList)
            if Speaketh_Fluency then Speaketh_Fluency:Set(key, 0) end

            nameBox:SetText(""); wordBox:SetText("")
            SetStatus('"'..name..'" added ('..#wordList..' words). Set its fluency in General to start speaking it.', false)
            Rebuild()
        end
    end)
    nameBox:SetScript("OnEnterPressed", function(self) wordBox:SetFocus() end)
    wordBox:SetScript("OnEnterPressed", function() createBtn:GetScript("OnClick")(createBtn) end)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if editingKey then
            editingKey = nil; nameBox:SetText(""); nameBox:Enable(); nameBox:SetTextColor(1,1,1)
            wordBox:SetText(""); createBtn:SetText("Add Language"); SetStatus("",false)
        end
    end)
    wordBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if editingKey then
            editingKey = nil; nameBox:SetText(""); nameBox:Enable(); nameBox:SetTextColor(1,1,1)
            wordBox:SetText(""); createBtn:SetText("Add Language"); SetStatus("",false)
        end
    end)

    panel.refresh = function()
        SetStatus("",false)
        if editingKey then
            editingKey = nil; nameBox:SetText(""); nameBox:Enable(); nameBox:SetTextColor(1,1,1)
            wordBox:SetText(""); createBtn:SetText("Add Language")
        end
        Rebuild()
    end

    -- Public hook so import can trigger a panel refresh from outside
    function Speaketh_Options:RefreshCustomLanguages()
        if _categoryPanels and _categoryPanels["newlanguage"]
           and _categoryPanels["newlanguage"].refresh then
            _categoryPanels["newlanguage"].refresh()
        end
    end

    Rebuild()
end

-- ============================================================
-- Sub-panel: Passthrough Words
-- Words that are never translated, regardless of active language.
-- ============================================================
local function BuildPassthroughPanel(panel)
    local body = panel.body

    local desc = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    desc:SetPoint("RIGHT",   body, "RIGHT",   0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Words in this list are never translated — they pass through every language unchanged.\nUseful for character names, in-game terms, or anything you always want readable.")
    desc:SetHeight(30)

    local wordLbl = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wordLbl:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    wordLbl:SetText("Word:")
    wordLbl:SetTextColor(1.0, 0.82, 0.0, 1)

    local wordBox = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    wordBox:SetSize(180, 22)
    wordBox:SetPoint("LEFT", wordLbl, "RIGHT", 8, 0)
    wordBox:SetAutoFocus(false)
    wordBox:SetMaxLetters(64)

    local addBtn = GoldBtn(body, "")
    addBtn:SetSize(52, 22)
    addBtn:SetPoint("LEFT", wordBox, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    local statusLbl, SetStatus = MakeStatusLabel(body, wordLbl)
    local listHdr, listCount   = MakeListHeader(body, statusLbl, "Passthrough words")

    local _, content, rows, WipeRows = MakeScrollList(body, listHdr, body)

    local function Rebuild()
        WipeRows()
        local words = {}
        if Speaketh_Char and Speaketh_Char.customWords then
            for w in pairs(Speaketh_Char.customWords) do table.insert(words, w) end
        end
        table.sort(words)
        listCount:SetText("("..#words.." word"..(#words==1 and "" or "s")..")")

        local y = 0
        for i, word in ipairs(words) do
            local row = CreateFrame("Frame", nil, content)
            row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            row:SetHeight(22)
            if i%2==0 then
                local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,1,1,0.03)
            end

            local wl = row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            wl:SetPoint("LEFT",row,"LEFT",4,0); wl:SetText(word)

            local delBtn = GoldBtn(row, "")
            delBtn:SetSize(58,18); delBtn:SetPoint("RIGHT",row,"RIGHT",-4,0); delBtn:SetText("Remove")
            local cw = word
            delBtn:SetScript("OnClick", function()
                if Speaketh_Char and Speaketh_Char.customWords then
                    Speaketh_Char.customWords[cw] = nil
                end
                SetStatus('"'..cw..'" removed.', false); Rebuild()
            end)
            table.insert(rows, row); y = y + 24
        end

        if #words==0 then
            local e = content:CreateFontString(nil,"OVERLAY","GameFontDisable")
            e:SetPoint("TOPLEFT",content,"TOPLEFT",4,-4)
            e:SetText("(no passthrough words yet)")
            table.insert(rows,e); content:SetHeight(20)
        else content:SetHeight(math.max(y,1)) end
    end

    local function DoAdd()
        local text = (wordBox:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
        if text=="" then return end
        if not text:match("^[%a'%-]+$") then
            SetStatus("Must be a single word (letters, apostrophes, hyphens only).", true); return
        end
        if not Speaketh_Char.customWords then Speaketh_Char.customWords = {} end
        Speaketh_Char.customWords[text:lower()] = true
        wordBox:SetText(""); wordBox:ClearFocus()
        SetStatus('"'..text..'" added.', false); Rebuild()
    end
    addBtn:SetScript("OnClick", DoAdd)
    wordBox:SetScript("OnEnterPressed", DoAdd)
    wordBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    panel.refresh = function() SetStatus("",false); Rebuild() end
    Rebuild()
end

-- Category: About
-- ============================================================
local function BuildAboutPanel(panel)
    local body = panel.body

    -- Scroll frame so content never clips if window is resized
    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     body, "TOPLEFT",     0,   0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -24, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 0 then content:SetWidth(w) end
    end)

    local ver = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    ver:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    local versionLocal = C_AddOns.GetAddOnMetadata("Speaketh", "Version")
    ver:SetText("Speaketh  |cffaaaaaa" .. versionLocal .. "|r")

    -- Features
    local featHead = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    featHead:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -14)
    featHead:SetTextColor(1.0, 0.82, 0.0, 1)
    featHead:SetText("Features")

    local featureList = {
        "20+ lore-accurate racial & exotic languages",
        "Custom languages — define your own word pools",
        "Language import/export — share codes between players",
        "Dialect word rules — built-in and fully editable",
        "Custom dialects — create your own accents",
        "Drunk dialect — four-level slurring engine",
        "Fluency system — 0–100% per language, passively learned",
        "Cross-player decoding — party, raid, guild, whisper & /say",
        "Passthrough words — names that always stay readable",
        "Minimap button & floating language HUD",
    }
    local prev = featHead
    for _, line in ipairs(featureList) do
        local ft = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ft:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", prev == featHead and 6 or 0, -4)
        ft:SetText("- " .. line)
        prev = ft
    end

    -- Commands
    local cmdHead = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdHead:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", -6, -14)
    cmdHead:SetTextColor(1.0, 0.82, 0.0, 1)
    cmdHead:SetText("Slash Commands")

    local commands = {
        {"/sp  or  /speaketh",   "Open this splash screen"},
        {"/sp options",          "Open the settings panel"},
        {"/sp window",           "Open the Speak Window"},
        {"/sp <language>",       "Switch language  (e.g. /sp orcish)"},
        {"/sp none",             "Disable translation"},
        {"/sp cycle",            "Cycle to next known language"},
        {"/sp dialect <n>",      "Set dialect  (gilnean, troll, drunk...)"},
        {"/sp drunk <0-3>",      "Set drunkenness level"},
        {"/sp share <language>", "Generate an import code"},
        {"/sp import <code>",    "Import a custom language"},
        {"/sp list",             "List all languages & fluency"},
    }

    for i, cmd in ipairs(commands) do
        local ct = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ct:SetPoint("TOPLEFT", cmdHead, "BOTTOMLEFT", 6, -6 - (i - 1) * 15)
        ct:SetText(cmd[1])
        local cd = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cd:SetPoint("LEFT", ct, "LEFT", 190, 0)
        cd:SetText("— " .. cmd[2])
        cd:SetTextColor(0.70, 0.70, 0.75, 1)
    end

    -- Total height: ver(16) + gap(14) + featHead(14) + 10 features*(12+4)
    --             + gap(14) + cmdHead(14) + 11 commands*15 + bottom pad(20)
    content:SetHeight(16 + 14 + 14 + 10*16 + 14 + 14 + 11*15 + 20)
end

-- ============================================================
-- Build the main frame (one-time)
-- ============================================================

-- Draws a single ornate corner accent using lines and a small diamond.
-- corner: "TL","TR","BL","BR"
local function DrawCorner(parent, corner)
    local SIZE  = 28   -- arm length
    local THICK = 2
    local DOT   = 5    -- diamond half-size
    local r, g, b, a = 0.72, 0.58, 0.25, 0.90

    local ox, oy, sx, sy
    if corner == "TL" then ox, oy, sx, sy = 1, -1,  1,  -1
    elseif corner == "TR" then ox, oy, sx, sy = -1, -1, -1, -1
    elseif corner == "BL" then ox, oy, sx, sy = 1,  1,  1,   1
    else                       ox, oy, sx, sy = -1,  1, -1,   1
    end

    -- Horizontal arm
    local h = parent:CreateTexture(nil, "OVERLAY")
    h:SetHeight(THICK)
    h:SetWidth(SIZE)
    h:SetColorTexture(r, g, b, a)
    if corner == "TL" then
        h:SetPoint("TOPLEFT",     parent, "TOPLEFT",     ox * 6, oy * 6)
    elseif corner == "TR" then
        h:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    ox * 6, oy * 6)
    elseif corner == "BL" then
        h:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  ox * 6, oy * 6)
    else
        h:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", ox * 6, oy * 6)
    end

    -- Vertical arm
    local v = parent:CreateTexture(nil, "OVERLAY")
    v:SetWidth(THICK)
    v:SetHeight(SIZE)
    v:SetColorTexture(r, g, b, a)
    if corner == "TL" then
        v:SetPoint("TOPLEFT",     parent, "TOPLEFT",     ox * 6, oy * 6)
    elseif corner == "TR" then
        v:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    ox * 6, oy * 6)
    elseif corner == "BL" then
        v:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  ox * 6, oy * 6)
    else
        v:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", ox * 6, oy * 6)
    end

    -- Diamond nib at the corner tip
    local d = parent:CreateTexture(nil, "OVERLAY")
    d:SetSize(DOT, DOT)
    d:SetColorTexture(r, g, b, a)
    d:SetRotation(math.rad(45))
    if corner == "TL" then
        d:SetPoint("CENTER", parent, "TOPLEFT",     ox * 6, oy * 6)
    elseif corner == "TR" then
        d:SetPoint("CENTER", parent, "TOPRIGHT",    ox * 6, oy * 6)
    elseif corner == "BL" then
        d:SetPoint("CENTER", parent, "BOTTOMLEFT",  ox * 6, oy * 6)
    else
        d:SetPoint("CENTER", parent, "BOTTOMRIGHT", ox * 6, oy * 6)
    end
end

-- Section header: small-caps label with gold rule extending right.
-- Returns the label fontstring (so callers can anchor body below it).
local function DrawSectionHeader(parent, anchorFrame, anchorPoint, xOff, yOff, text)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", anchorFrame, anchorPoint, xOff, yOff)
    lbl:SetText(string.upper(text))
    lbl:SetTextColor(0.72, 0.58, 0.25, 0.85)
    lbl:SetSpacing(1.5)

    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT",  lbl, "RIGHT", 6, 0)
    rule:SetPoint("RIGHT", parent, "RIGHT", -CONTENT_PAD_X, 0)
    rule:SetColorTexture(0.72, 0.58, 0.25, 0.35)

    return lbl
end

local function BuildFrame()
    if _mainFrame then return _mainFrame end

    local f = CreateFrame("Frame", "SpeakethOptionsFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    -- Rich dark parchment background
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropColor(0.09, 0.06, 0.02, 0.98)
        f:SetBackdropBorderColor(0.55, 0.42, 0.15, 1)
    end

    -- Subtle inner vignette overlay for warmth
    local vignette = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    vignette:SetAllPoints()
    vignette:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    vignette:SetVertexColor(0.14, 0.09, 0.03, 0.45)

    -- ── Corner ornaments ───────────────────────────────────────
    DrawCorner(f, "TL")
    DrawCorner(f, "TR")
    DrawCorner(f, "BL")
    DrawCorner(f, "BR")

    -- ── Title bar ──────────────────────────────────────────────
    -- Diamond · S P E A K E T H · Diamond centered at top
    local titleBar = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleBar:SetPoint("TOP", f, "TOP", 0, -18)
    titleBar:SetText("S P E A K E T H")
    titleBar:SetTextColor(0.92, 0.78, 0.42, 1)
    titleBar:SetSpacing(2)

    -- Gold rule under title
    local titleDiv = f:CreateTexture(nil, "ARTWORK")
    titleDiv:SetPoint("TOPLEFT",  f, "TOPLEFT",  34, -38)
    titleDiv:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -38)
    titleDiv:SetHeight(1)
    titleDiv:SetColorTexture(0.72, 0.58, 0.25, 0.80)

    -- Subtle second rule for depth
    local titleDiv2 = f:CreateTexture(nil, "ARTWORK")
    titleDiv2:SetPoint("TOPLEFT",  f, "TOPLEFT",  34, -41)
    titleDiv2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -41)
    titleDiv2:SetHeight(1)
    titleDiv2:SetColorTexture(0.72, 0.58, 0.25, 0.25)

    -- ── Custom close button ────────────────────────────────────
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetColorTexture(0.55, 0.10, 0.08, 0.90)

    local closeBorder = closeBtn:CreateTexture(nil, "BORDER")
    closeBorder:SetAllPoints()
    closeBorder:SetColorTexture(0.72, 0.38, 0.20, 0.80)

    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetAllPoints()
    closeX:SetText("×")
    closeX:SetTextColor(1, 0.85, 0.75, 1)
    closeX:SetJustifyH("CENTER")
    closeX:SetJustifyV("MIDDLE")

    closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.72, 0.15, 0.10, 1) end)
    closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0.55, 0.10, 0.08, 0.90) end)

    -- ── Sidebar ────────────────────────────────────────────────
    -- Sidebar dark panel background
    local sideBg = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    sideBg:SetPoint("TOPLEFT",    f, "TOPLEFT",    8,     -44)
    sideBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8,      20)
    sideBg:SetWidth(SIDE_W - 10)
    sideBg:SetColorTexture(0.04, 0.03, 0.01, 0.60)

    -- Vertical divider between sidebar and content
    local sideDiv = f:CreateTexture(nil, "ARTWORK")
    sideDiv:SetPoint("TOPLEFT",    f, "TOPLEFT",    SIDE_W,  -44)
    sideDiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", SIDE_W,   20)
    sideDiv:SetWidth(1)
    sideDiv:SetColorTexture(0.72, 0.58, 0.25, 0.50)

    -- Second subtle rule for depth
    local sideDiv2 = f:CreateTexture(nil, "ARTWORK")
    sideDiv2:SetPoint("TOPLEFT",    f, "TOPLEFT",    SIDE_W + 3, -44)
    sideDiv2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", SIDE_W + 3,  20)
    sideDiv2:SetWidth(1)
    sideDiv2:SetColorTexture(0.72, 0.58, 0.25, 0.15)

    _mainFrame = f

    -- Escape closes the options panel in the same stacking order as any
    -- native Blizzard UI panel.
    tinsert(UISpecialFrames, "SpeakethOptionsFrame")

    return f
end

-- ============================================================
-- Public: HandleImport (overwrite=true path, called from overwrite dialog)
-- ============================================================
function Speaketh_Options:HandleImport(code, overwrite, onRefresh)
    if not Speaketh_Share or not Speaketh_Share.ImportCode then return end
    local name, result = Speaketh_Share:ImportCode(code, overwrite)
    if name then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cffffcc00[Speaketh]|r Imported |cff88ccff%s|r (%d words). Fluency set to 100%%.",
            name, result))
        if onRefresh then pcall(onRefresh) end
        if _categoryPanels and _categoryPanels["newlanguage"]
           and _categoryPanels["newlanguage"].refresh then
            _categoryPanels["newlanguage"].refresh()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffcc00[Speaketh]|r Import failed: " .. (result or "unknown error"))
    end
end

-- ============================================================
-- Public: Open / Close
-- ============================================================
function Speaketh_Options:Open()
    BuildFrame()
    if not _categoryButtons.general then
        local SUB_H   = 24
        local SUB_GAP = 3
        local SUB_BLOCK = (SUB_H + SUB_GAP) * 4  -- total height of the 4 sub-buttons

        local y = -48
        AddCategory("general", "General", BuildGeneralPanel, y)

        -- "Word Rules" toggle button — custom styled
        y = y - (ROW_H + ROW_GAP)
        local wrY = y

        local wrBtn = CreateFrame("Button", nil, _mainFrame)
        wrBtn:SetSize(SIDE_BTN_W, ROW_H)
        wrBtn:SetPoint("TOPLEFT", _mainFrame, "TOPLEFT", SIDE_INSET, wrY)
        wrBtn:EnableMouse(true)

        local wrBg = wrBtn:CreateTexture(nil, "BACKGROUND")
        wrBg:SetAllPoints()
        wrBg:SetColorTexture(0, 0, 0, 0)

        local wrDiamond = wrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        wrDiamond:SetPoint("LEFT", wrBtn, "LEFT", 4, 0)
        wrDiamond:SetText("|")
        wrDiamond:SetTextColor(0.72, 0.58, 0.25, 0)

        local wrText = wrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        wrText:SetPoint("LEFT", wrDiamond, "RIGHT", 6, 0)
        wrText:SetText("WORD RULES")
        wrText:SetTextColor(0.70, 0.58, 0.38, 1)
        wrText:SetSpacing(1.5)
        wrBtn.Text = wrText
        wrBtn._diamond = wrDiamond
        wrBtn._bg = wrBg

        local wrSep = _mainFrame:CreateTexture(nil, "ARTWORK")
        wrSep:SetPoint("BOTTOMLEFT",  wrBtn, "BOTTOMLEFT",  0, -1)
        wrSep:SetPoint("BOTTOMRIGHT", wrBtn, "BOTTOMRIGHT", 0, -1)
        wrSep:SetHeight(1)
        wrSep:SetColorTexture(0.72, 0.58, 0.25, 0.12)

        -- Sub-category buttons (start hidden)
        local subY = wrY - (ROW_H + SUB_GAP)
        local subBtns = {}
        AddSubCategory("dialectrules", "Dialect Rules", BuildDialectRulesPanel, subY)
        table.insert(subBtns, _categoryButtons["dialectrules"])
        subY = subY - (SUB_H + SUB_GAP)

        AddSubCategory("newdialect",   "New Dialect",   BuildNewDialectPanel,   subY)
        table.insert(subBtns, _categoryButtons["newdialect"])
        subY = subY - (SUB_H + SUB_GAP)

        AddSubCategory("newlanguage",  "New Language",  BuildNewLanguagePanel,  subY)
        table.insert(subBtns, _categoryButtons["newlanguage"])
        subY = subY - (SUB_H + SUB_GAP)

        AddSubCategory("passthrough",  "Passthrough",   BuildPassthroughPanel,  subY)
        table.insert(subBtns, _categoryButtons["passthrough"])

        -- Hide all sub-buttons initially
        for _, btn in ipairs(subBtns) do btn:Hide() end

        -- About button — repositioned when Word Rules expands/collapses
        local aboutCollapsedY = wrY - (ROW_H + ROW_GAP)
        local aboutExpandedY  = wrY - (ROW_H + SUB_GAP) - SUB_BLOCK - ROW_GAP
        local aboutBtn, aboutPanel  -- forward refs; AddCategory stores them

        local wrExpanded = false

        local function SetWordRulesExpanded(expanded)
            wrExpanded = expanded
            if expanded then
                wrBg:SetColorTexture(0.72, 0.58, 0.25, 0.15)
                wrText:SetTextColor(0.95, 0.82, 0.48, 1)
                wrDiamond:SetTextColor(0.72, 0.58, 0.25, 1)
                for _, btn in ipairs(subBtns) do btn:Show() end
                aboutBtn:ClearAllPoints()
                aboutBtn:SetPoint("TOPLEFT", _mainFrame, "TOPLEFT", SIDE_INSET, aboutExpandedY)
            else
                wrBg:SetColorTexture(0, 0, 0, 0)
                wrText:SetTextColor(0.70, 0.58, 0.38, 1)
                wrDiamond:SetTextColor(0.72, 0.58, 0.25, 0)
                for _, btn in ipairs(subBtns) do btn:Hide() end
                -- If a sub-panel is showing, hide it when collapsing
                local subKeys = {"dialectrules","newdialect","newlanguage","passthrough"}
                for _, k in ipairs(subKeys) do
                    if _categoryPanels[k] and _categoryPanels[k]:IsShown() then
                        _categoryPanels[k]:Hide()
                        _activeKey = nil
                    end
                end
                aboutBtn:ClearAllPoints()
                aboutBtn:SetPoint("TOPLEFT", _mainFrame, "TOPLEFT", SIDE_INSET, aboutCollapsedY)
            end
        end

        wrBtn:SetScript("OnClick", function()
            SetWordRulesExpanded(not wrExpanded)
        end)

        -- About — start collapsed position
        y = aboutCollapsedY
        AddCategory("about", "About", BuildAboutPanel, y)
        -- Grab the button AddCategory just created
        aboutBtn   = _categoryButtons["about"]
        aboutPanel = _categoryPanels["about"]

        -- Override SelectCategory highlight so wrBtn stays lit when a sub is active
        local origSelect = SelectCategory
        -- Patch: when a sub-category is selected, also highlight wrBtn
        for _, btn in ipairs(subBtns) do
            local orig = btn:GetScript("OnClick")
            btn:SetScript("OnClick", function(self)
                wrBg:SetColorTexture(0.72, 0.58, 0.25, 0.15)
                wrText:SetTextColor(0.95, 0.82, 0.48, 1)
                wrDiamond:SetTextColor(0.72, 0.58, 0.25, 1)
                orig(self)
            end)
        end
    end
    SelectCategory(_activeKey or "general")
    _mainFrame:Show()
end

function Speaketh_Options:Close()
    if _mainFrame then _mainFrame:Hide() end
end

-- ============================================================
-- Public: Register (called from Speaketh.lua on PLAYER_LOGIN)
-- ============================================================
function Speaketh_Options:Register()
    -- The frame is built lazily on :Open(). Nothing to pre-register.
end
