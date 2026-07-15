-- Speaketh_Theme.lua
-- ============================================================
-- Central theming system for Speaketh.
--
-- Provides two selectable palettes:
--   "Classic" - the original dark-parchment + gold look.
--   "Void"    - a deep void-black/purple look with glow,
--               vignette, ink-bleed gradients, corner runes,
--               and a slow border pulse.
--
-- Every themeable element registers a small "apply" closure via
-- Speaketh_Theme:Register(fn). Calling Speaketh_Theme:Set(name)
-- stores the choice in Speaketh_Char.theme and re-runs every
-- registered closure so the UI re-skins live, without /reload.
--
-- Colors are exposed as semantic tokens (C.title, C.accent,
-- C.borderTex, ...) so call sites never hardcode raw RGB.
-- ============================================================

Speaketh_Theme = {}

-- ------------------------------------------------------------
-- Palette definitions
--
-- Each entry is { r, g, b, a }. Tokens are intentionally named by
-- ROLE, not color, so the same call site works in either theme.
-- ------------------------------------------------------------

local PALETTES = {
    -- ── Classic: original gold-on-parchment ──────────────────
    Classic = {
        -- Window backdrop (bg fill + border) for the big panels
        backdropBg     = { 0.09, 0.06, 0.02, 0.98 },
        backdropBorder = { 0.55, 0.42, 0.15, 1.00 },
        -- Slate backdrop used by Speak Window / HUD / splash
        slateBg        = { 0.08, 0.08, 0.10, 0.97 },
        slateBorder    = { 0.55, 0.45, 0.20, 1.00 },

        -- Primary accent (gold) used for borders, rules, button chrome
        accent         = { 0.72, 0.58, 0.25, 1.00 },
        -- Brighter accent for titles / panel headers
        title          = { 0.92, 0.78, 0.42, 1.00 },
        -- Strong header accent (pure gold) used for section labels
        headerGold     = { 1.00, 0.82, 0.00, 1.00 },

        -- Body / value text
        bodyText       = { 0.92, 0.82, 0.55, 1.00 },
        -- Secondary / muted text
        mutedText      = { 0.70, 0.58, 0.38, 1.00 },
        dimText        = { 0.60, 0.50, 0.32, 1.00 },
        -- "info blue" used for fluency / target language
        infoBlue       = { 0.55, 0.75, 1.00, 1.00 },

        -- Button text
        btnText        = { 0.85, 0.70, 0.35, 1.00 },
        btnTextHover   = { 0.95, 0.82, 0.48, 1.00 },

        -- Sidebar panel fill + active-button highlight tint
        sidebarBg      = { 0.04, 0.03, 0.01, 0.60 },

        -- Close button (red)
        closeBg        = { 0.55, 0.10, 0.08, 0.90 },
        closeBgHover   = { 0.72, 0.15, 0.10, 1.00 },
        closeBorder    = { 0.72, 0.38, 0.20, 0.80 },
        closeX         = { 1.00, 0.85, 0.75, 1.00 },

        -- Backdrop textures
        bgFile         = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        borderFile     = "Interface\\DialogFrame\\UI-DialogBox-Border",
        slateBorderFile= "Interface\\Tooltips\\UI-Tooltip-Border",

        -- Void-only decoration master switch
        voidDecor      = false,
    },

    -- ── Void: deep purple/black with arcane glow ─────────────
    Void = {
        backdropBg     = { 0.04, 0.02, 0.08, 0.98 },
        backdropBorder = { 0.24, 0.12, 0.50, 1.00 },
        slateBg        = { 0.04, 0.02, 0.07, 0.97 },
        slateBorder    = { 0.35, 0.18, 0.54, 1.00 },

        accent         = { 0.48, 0.24, 0.78, 1.00 },   -- void-border2 #5a2e8a-ish
        title          = { 0.66, 0.33, 0.97, 1.00 },   -- void-bright #a855f7
        headerGold     = { 0.66, 0.33, 0.97, 1.00 },   -- purple replaces gold

        bodyText       = { 0.91, 0.88, 1.00, 1.00 },   -- void-white #e8e0ff
        mutedText      = { 0.40, 0.30, 0.55, 1.00 },   -- void-dim
        dimText        = { 0.30, 0.22, 0.42, 1.00 },   -- void-dimmer
        infoBlue       = { 0.49, 0.83, 0.94, 1.00 },   -- void-teal #7dd4f0

        btnText        = { 0.66, 0.33, 0.97, 1.00 },
        btnTextHover   = { 0.78, 0.52, 0.99, 1.00 },

        sidebarBg      = { 0.02, 0.01, 0.05, 0.70 },

        closeBg        = { 0.16, 0.04, 0.23, 0.90 },   -- #2a0a3a
        closeBgHover   = { 0.29, 0.06, 0.38, 1.00 },   -- #4a1060
        closeBorder    = { 0.42, 0.13, 0.56, 0.90 },   -- #6a2090
        closeX         = { 0.82, 0.63, 1.00, 1.00 },   -- #d0a0ff

        bgFile         = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        borderFile     = "Interface\\DialogFrame\\UI-DialogBox-Border",
        slateBorderFile= "Interface\\Tooltips\\UI-Tooltip-Border",

        voidDecor      = true,
        -- Void glow color (for pulse / glow textures)
        glow           = { 0.48, 0.20, 0.86, 1.00 },   -- void-glow #7b3fc0
    },
}

-- Live token table. Call sites read e.g. Speaketh_Theme.C.accent.
-- It is repopulated (in place, same table reference) on every Set().
Speaketh_Theme.C = {}

-- Registry of re-skin closures.
local _appliers = {}
local _currentName = "Classic"

-- Repopulate the live token table from the chosen palette.
local function CopyPalette(name)
    local p = PALETTES[name] or PALETTES.Classic
    local C = Speaketh_Theme.C
    for k, v in pairs(p) do
        C[k] = v
    end
    return C
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------

-- Current theme name ("Classic" / "Void").
function Speaketh_Theme:Current()
    return _currentName
end

function Speaketh_Theme:IsVoid()
    return _currentName == "Void"
end

-- Register a closure to be (re)run whenever the theme changes.
-- The closure receives the live token table C as its argument.
-- It is also invoked immediately so freshly built frames skin
-- themselves on creation.
function Speaketh_Theme:Register(fn)
    if type(fn) ~= "function" then return end
    table.insert(_appliers, fn)
    -- Apply immediately with current tokens.
    local ok, err = pcall(fn, self.C)
    if not ok and DEFAULT_CHAT_FRAME then
        -- Fail soft - a broken applier should never block the UI.
    end
end

-- Re-run every registered applier (used internally by Set).
function Speaketh_Theme:Reapply()
    for _, fn in ipairs(_appliers) do
        pcall(fn, self.C)
    end
end

-- Switch theme. Persists to Speaketh_Char.theme and re-skins live.
function Speaketh_Theme:Set(name)
    if not PALETTES[name] then name = "Classic" end
    _currentName = name
    CopyPalette(name)
    if Speaketh_Char then
        Speaketh_Char.theme = name
    end
    self:Reapply()
end

-- Initialize from saved variables. Called from PLAYER_LOGIN once
-- Speaketh_Char exists. Safe to call before any frames are built.
function Speaketh_Theme:Init()
    local saved = (Speaketh_Char and Speaketh_Char.theme) or "Classic"
    if not PALETTES[saved] then saved = "Classic" end
    _currentName = saved
    CopyPalette(saved)
end

-- Convenience: list of selectable themes (for the options dropdown).
function Speaketh_Theme:List()
    return { "Classic", "Void" }
end

-- ------------------------------------------------------------
-- Decoration helpers (Void-only visual flourishes)
--
-- These attach extra textures to a frame that are only shown in
-- the Void theme: an inner vignette, top/bottom ink-bleed
-- gradients, four corner runes, and a slow border-glow pulse.
-- Each helper registers its own applier so it toggles live.
-- ------------------------------------------------------------

-- Inner radial-ish vignette: darkens the panel edges. WoW textures
-- can't do true radial gradients cheaply, so we approximate with a
-- dark tinted full-panel texture that only shows in Void.
function Speaketh_Theme:AddVoidVignette(frame)
    local vig = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    vig:SetAllPoints(frame)
    vig:SetColorTexture(0.02, 0.01, 0.05, 0.55)
    self:Register(function()
        if Speaketh_Theme:IsVoid() then vig:Show() else vig:Hide() end
    end)
    return vig
end

-- Top + bottom ink-bleed gradient bars (simulate SetGradient VERTICAL).
function Speaketh_Theme:AddVoidInkBleed(frame)
    local top = frame:CreateTexture(nil, "BACKGROUND", nil, 4)
    top:SetPoint("TOPLEFT",  frame, "TOPLEFT",  6, -6)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    top:SetHeight(46)
    top:SetColorTexture(1, 1, 1, 1)
    if top.SetGradient then
        top:SetGradient("VERTICAL",
            CreateColor(0.10, 0.02, 0.18, 0.00),
            CreateColor(0.35, 0.08, 0.62, 0.22))
    end

    local bot = frame:CreateTexture(nil, "BACKGROUND", nil, 4)
    bot:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  6, 6)
    bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    bot:SetHeight(36)
    bot:SetColorTexture(1, 1, 1, 1)
    if bot.SetGradient then
        bot:SetGradient("VERTICAL",
            CreateColor(0.20, 0.04, 0.40, 0.24),
            CreateColor(0.10, 0.02, 0.20, 0.00))
    end

    self:Register(function()
        if Speaketh_Theme:IsVoid() then top:Show(); bot:Show()
        else top:Hide(); bot:Hide() end
    end)
    return top, bot
end

-- Four corner rune glyphs (simple arcane circle + cross), Void only.
function Speaketh_Theme:AddVoidRunes(frame, inset, size)
    inset = inset or 8
    size  = size or 22
    local runes = {}
    local corners = {
        { "TOPLEFT",     inset,  -inset },
        { "TOPRIGHT",    -inset, -inset },
        { "BOTTOMLEFT",  inset,   inset },
        { "BOTTOMRIGHT", -inset,  inset },
    }
    for _, c in ipairs(corners) do
        -- Use a soft glow texture as a stand-in rune; tint purple.
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetSize(size, size)
        t:SetPoint("CENTER", frame, c[1], c[2], c[3])
        t:SetTexture("Interface\\Common\\StreamCircle")
        t:SetVertexColor(0.66, 0.33, 0.97, 0.30)
        t:SetBlendMode("ADD")
        table.insert(runes, t)
    end

    -- Slow breathing pulse on rune alpha.
    local driver = frame.__voidRuneDriver
    if not driver then
        driver = CreateFrame("Frame", nil, frame)
        frame.__voidRuneDriver = driver
        driver._t = 0
    end
    driver:SetScript("OnUpdate", function(self, elapsed)
        if not Speaketh_Theme:IsVoid() then return end
        self._t = (self._t or 0) + elapsed
        local a = 0.18 + math.sin(self._t * 1.6) * 0.12
        for _, r in ipairs(runes) do
            r:SetAlpha(a)
        end
    end)

    self:Register(function()
        local v = Speaketh_Theme:IsVoid()
        for _, r in ipairs(runes) do
            if v then r:Show() else r:Hide() end
        end
    end)
    return runes
end

-- Slow border-glow pulse: drives a thin glow texture framing the
-- panel. Approximates the mockup's animated box-shadow.
function Speaketh_Theme:AddVoidGlowPulse(frame)
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetPoint("TOPLEFT",     frame, "TOPLEFT",     2, -2)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    -- Flat purple inner wash; alpha is animated for the breathing glow.
    glow:SetColorTexture(0.30, 0.12, 0.55, 0.12)
    glow:SetBlendMode("ADD")

    local driver = frame.__voidGlowDriver
    if not driver then
        driver = CreateFrame("Frame", nil, frame)
        frame.__voidGlowDriver = driver
        driver._t = 0
    end
    driver:SetScript("OnUpdate", function(self, elapsed)
        if not Speaketh_Theme:IsVoid() then return end
        self._t = (self._t or 0) + elapsed
        -- 4s ease-in-out-ish breath between ~0.06 and ~0.20 alpha.
        local a = 0.13 + math.sin(self._t * (math.pi / 2)) * 0.07
        glow:SetAlpha(a)
    end)

    self:Register(function()
        if Speaketh_Theme:IsVoid() then glow:Show() else glow:Hide() end
    end)
    return glow
end
