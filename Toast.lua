--[[-------------------------------------------------------------------------
    Glyphic - Toast.lua
    A line of text that appears, waits, and goes away again.

    Learning a word from a quest is a small thing that happens at a busy
    moment. The quest reward window is closing, the experience bar is
    sliding, three other addons are saying something. A chat line lands in
    that and is gone. So it gets its own place on the screen instead.

    Everything about how it looks lives in STYLE at the top of this file, in
    one block, so changing the design is editing numbers rather than reading
    code. Everything about how it behaves is below that and does not care
    what the numbers say.

    No animation groups and no C_Timer: an OnUpdate that counts seconds works
    identically on every client this addon loads on, which the other two do
    not, and the whole motion here is one alpha ramp.

    Toasts queue rather than overwrite. Handing in three quests in a row at a
    hub is normal, and the second and third words are not less earned than
    the first.
---------------------------------------------------------------------------]]

local _, ns = ...
local Compat = ns.Compat

local Toast = {}
ns.Toast = Toast

--=========================================================================--
--  Everything you would want to change
--=========================================================================--
local STYLE = {
    width       = 290,
    height      = 46,

    -- Where it sits when nobody has dragged it. High enough to clear the
    -- quest reward window, low enough not to fight the error text.
    point       = "TOP",
    relPoint    = "TOP",
    x           = 0,
    y           = -190,

    background  = { 0.04, 0.04, 0.07, 0.88 },
    border      = { 0.55, 0.45, 0.20, 0.95 },

    titleFont   = "GameFontNormal",
    titleColor  = { 1, 0.82, 0.2 },
    bodyFont    = "GameFontHighlightSmall",
    bodyColor   = { 0.85, 0.85, 0.85 },

    fadeIn      = 0.25,   -- seconds
    hold        = 4.0,
    fadeOut     = 1.0,

    strata      = "HIGH",
}

Toast.STYLE = STYLE

--=========================================================================--
--  The frame
--=========================================================================--
local frame
local queue = {}
local phase, elapsed = nil, 0

local function saved()
    GlyphicDB = GlyphicDB or {}
    GlyphicDB.toast = GlyphicDB.toast or {}
    return GlyphicDB.toast
end

local function place(f)
    local pos = saved()
    f:ClearAllPoints()
    f:SetPoint(pos.point or STYLE.point, UIParent,
        pos.relPoint or STYLE.relPoint,
        pos.x or STYLE.x, pos.y or STYLE.y)
end

local function build()
    if frame or type(CreateFrame) ~= "function" then return frame end

    local f = CreateFrame("Frame", "GlyphicToast", UIParent)
    f:SetSize(STYLE.width, STYLE.height)
    f:SetFrameStrata(STYLE.strata)
    f:SetClampedToScreen(true)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, STYLE.background[1], STYLE.background[2],
        STYLE.background[3], STYLE.background[4])
    f.bg = bg
    f.border = Compat.AddBorder(f, STYLE.border[1], STYLE.border[2],
        STYLE.border[3], STYLE.border[4])

    local title = f:CreateFontString(nil, "OVERLAY", STYLE.titleFont)
    title:SetPoint("TOP", 0, -8)
    title:SetTextColor(STYLE.titleColor[1], STYLE.titleColor[2], STYLE.titleColor[3])
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", STYLE.bodyFont)
    body:SetPoint("TOP", title, "BOTTOM", 0, -4)
    body:SetTextColor(STYLE.bodyColor[1], STYLE.bodyColor[2], STYLE.bodyColor[3])
    f.body = body

    -- Draggable, because "high enough to clear the quest window" is only true
    -- for people running Blizzard's quest window.
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local pos = saved()
        pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
    end)

    f:SetScript("OnUpdate", function(_, delta) Toast._Update(delta) end)

    place(f)
    frame = f
    return f
end

--=========================================================================--
--  Showing
--=========================================================================--
local function present(entry)
    local f = build()
    if not f then return end
    place(f)
    f.title:SetText(entry.title or "")
    f.body:SetText(entry.body or "")
    if entry.titleColor then
        f.title:SetTextColor(entry.titleColor[1], entry.titleColor[2], entry.titleColor[3])
    else
        f.title:SetTextColor(STYLE.titleColor[1], STYLE.titleColor[2], STYLE.titleColor[3])
    end
    f:SetAlpha(0)
    f:Show()
    phase, elapsed = "in", 0
end

-- Driven by OnUpdate in the game and called directly by the tests, which have
-- no frames running. Split out so the motion is testable without a client.
function Toast._Update(delta)
    if not phase then return end
    elapsed = elapsed + (tonumber(delta) or 0)
    local f = frame
    if not f then return end

    if phase == "in" then
        if STYLE.fadeIn <= 0 or elapsed >= STYLE.fadeIn then
            f:SetAlpha(1)
            phase, elapsed = "hold", 0
        else
            f:SetAlpha(elapsed / STYLE.fadeIn)
        end
    elseif phase == "hold" then
        if elapsed >= STYLE.hold then
            phase, elapsed = "out", 0
        end
    elseif phase == "out" then
        if STYLE.fadeOut <= 0 or elapsed >= STYLE.fadeOut then
            f:SetAlpha(0)
            f:Hide()
            phase, elapsed = nil, 0
            -- Next in line, if a hand-in came in while this one was up.
            local nextUp = table.remove(queue, 1)
            if nextUp then present(nextUp) end
        else
            f:SetAlpha(1 - (elapsed / STYLE.fadeOut))
        end
    end
end

function Toast.Show(entry)
    if type(entry) ~= "table" then return false end
    if phase then
        queue[#queue + 1] = entry
        return true
    end
    present(entry)
    return true
end

-- Cuts everything short. Used by the tests, and by the preview button so a
-- second click doesn't sit behind the first one's four seconds.
function Toast.Clear()
    for i = #queue, 1, -1 do queue[i] = nil end
    phase, elapsed = nil, 0
    if frame then
        frame:SetAlpha(0)
        frame:Hide()
    end
end

function Toast._State() return phase, elapsed, #queue end
function Toast._Frame() return frame end

--=========================================================================--
--  The one thing it currently says
--=========================================================================--
-- Kept here rather than in QuestLearn so that file stays about the rule and
-- this one stays about the screen.
function Toast.Word(got)
    if type(got) ~= "table" then return false end

    local name = got.glyphId or "?"
    if ns.Language and type(ns.Language.GetLanguageName) == "function" then
        local ok, pretty = pcall(ns.Language.GetLanguageName, got.glyphId)
        if ok and type(pretty) == "string" and pretty ~= "" then name = pretty end
    end

    -- The colour the tongue already wears in chat, so the toast reads as part
    -- of the same addon rather than a notification from somewhere else.
    local color
    if ns.Colors and type(ns.Colors.Get) == "function" then
        local ok, r, g, b = pcall(ns.Colors.Get, got.glyphId)
        if ok and r and g and b then color = { r, g, b } end
    end

    local body
    if got.word and got.learned and got.total then
        body = string.format("|cffffffff%s|r      %d of %d words",
            got.word, got.learned, got.total)
    else
        body = (got.percent or 0) .. "%"
    end

    return Toast.Show({
        title = "You pick up a word of " .. name,
        titleColor = color,
        body = body,
    })
end
