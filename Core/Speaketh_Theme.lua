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
-- Seasonal palette inherits every compatibility token from Classic.
PALETTES.HallowsEnd={}
for k,v in pairs(PALETTES.Classic)do PALETTES.HallowsEnd[k]=v end
for k,v in pairs({accent={1,.52,.16,1},title={1,.65,.28,1},headerGold={1,.60,.22,1},bodyText={.95,.90,.80,1},btnText={.92,.82,.67,1},slateBg={.065,.047,.067,.98},slateBorder={.43,.29,.19,1},backdropBg={.10,.073,.09,.98},backdropBorder={.43,.29,.19,1}})do PALETTES.HallowsEnd[k]=v end

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
function Speaketh_Theme:IsAvailable(name)
    if name~="HallowsEnd" then return PALETTES[name]~=nil end
    local calendar=date("*t")
    return calendar and calendar.month==10
end
function Speaketh_Theme:CheckSeason()
    if _currentName=="HallowsEnd" and not self:IsAvailable(_currentName)then self:Set("Classic")end
end
function Speaketh_Theme:Set(name)
    if not self:IsAvailable(name) then name = "Classic" end
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
    if not self:IsAvailable(saved) then saved = "Classic";if Speaketh_Char then Speaketh_Char.theme=saved end end
    _currentName = saved
    CopyPalette(saved)
end

-- Convenience: list of selectable themes (for the options dropdown).
function Speaketh_Theme:List()
    self:CheckSeason();local names={"Classic","Void"};if self:IsAvailable("HallowsEnd")then names[#names+1]="HallowsEnd"end;return names
end

-- Recheck the calendar during long sessions as well as login and menu opening.
local seasonClock=CreateFrame("Frame")
local seasonElapsed=0
seasonClock:SetScript("OnUpdate",function(_,elapsed)
    seasonElapsed=seasonElapsed+elapsed
    if seasonElapsed>=60 then seasonElapsed=0;Speaketh_Theme:CheckSeason()end
end)
