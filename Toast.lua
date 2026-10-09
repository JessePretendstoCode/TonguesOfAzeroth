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
--  Where it sits
--=========================================================================--
-- Separate from the look, because dragging it somewhere is a decision about
-- your screen and picking a style is a decision about the addon. Changing
-- your mind about one should not undo the other.
local PLACEMENT = {
    point    = "TOP",
    relPoint = "TOP",
    x        = 0,
    y        = -190,          -- clears the quest window, ducks the error text
    strata   = "HIGH",
}

--=========================================================================--
--  The looks
--=========================================================================--
-- Six of them, different enough that choosing is a real choice rather than
-- picking a shade. Add one by adding a row: nothing below reads these by
-- name except the default, and the slash command lists whatever is here.
--
-- Colours are {r, g, b, a} in 0-1. A border alpha of 0 means no border, and
-- a background alpha of 0 means no panel -- both are real styles here, not
-- accidents.
local PRESETS = {}
local ORDER = {}

local function preset(id, label, def)
    def.id, def.label = id, label
    PRESETS[id] = def
    ORDER[#ORDER + 1] = id
end

preset("slate", "Slate -- dark panel, gold edge", {
    width = 290, height = 46,
    background = { 0.04, 0.04, 0.07, 0.88 },
    border     = { 0.55, 0.45, 0.20, 0.95 },
    layout = "stack", icon = false, iconSize = 0, tint = true, flair = false, fade = 0,
    wordHex    = "ffffff",
    titleFont  = "GameFontNormal",      titleColor = { 1, 0.82, 0.2 },   titleY = -8,
    bodyFont   = "GameFontHighlightSmall", bodyColor = { 0.85, 0.85, 0.85 }, bodyGap = -4,
    fadeIn = 0.25, hold = 4.0, fadeOut = 1.0,
})

preset("parchment", "Parchment -- a note from the quest giver", {
    width = 300, height = 50,
    background = { 0.83, 0.74, 0.55, 0.94 },
    border     = { 0.26, 0.18, 0.09, 1 },
    -- The one style that does not take the tongue's colour. Language colours
    -- are chosen to read on the dark chat frame, and every one of them sinks
    -- into tan -- Common is near-white and Taur-ahe is a browner tan still.
    layout = "stack", icon = false, iconSize = 0, tint = false, flair = false, fade = 0,
    wordHex    = "2b1a07",
    titleFont  = "GameFontNormal",      titleColor = { 0.20, 0.12, 0.04 }, titleY = -9,
    bodyFont   = "GameFontNormalSmall", bodyColor  = { 0.34, 0.24, 0.12 }, bodyGap = -4,
    fadeIn = 0.35, hold = 5.0, fadeOut = 1.2,
})

preset("banner", "Banner -- wide, no box, like zone text", {
    width = 460, height = 54,
    background = { 0, 0, 0, 0 },
    border     = { 0, 0, 0, 0 },
    layout = "stack", icon = false, iconSize = 0, tint = true, flair = false, fade = 0,
    wordHex    = "ffffff",
    titleFont  = "GameFontNormalLarge", titleColor = { 1, 0.82, 0.2 },    titleY = -4,
    bodyFont   = "GameFontNormal",      bodyColor  = { 0.95, 0.95, 0.95 }, bodyGap = -2,
    fadeIn = 0.4, hold = 4.0, fadeOut = 1.5,
})

preset("minimal", "Minimal -- one quiet line, no furniture", {
    width = 320, height = 26,
    background = { 0, 0, 0, 0 },
    border     = { 0, 0, 0, 0 },
    layout = "stack", icon = false, iconSize = 0, tint = true, flair = false, fade = 0,
    wordHex    = "ffe9a8",
    titleFont  = "GameFontHighlightSmall", titleColor = { 0.95, 0.85, 0.5 }, titleY = -4,
    bodyFont   = "GameFontDisableSmall",   bodyColor  = { 0.6, 0.6, 0.6 },   bodyGap = -1,
    fadeIn = 0.2, hold = 3.0, fadeOut = 0.8,
})

preset("achievement", "Achievement -- heavy gold frame", {
    width = 330, height = 62,
    background = { 0.02, 0.02, 0.02, 0.95 },
    border     = { 0.85, 0.68, 0.22, 1 },
    layout = "stack", icon = false, iconSize = 0, tint = true, flair = false, fade = 0,
    wordHex    = "ffffff",
    titleFont  = "GameFontNormalLarge", titleColor = { 1, 0.88, 0.35 },   titleY = -12,
    bodyFont   = "GameFontHighlight",   bodyColor  = { 0.80, 0.80, 0.80 }, bodyGap = -6,
    fadeIn = 0.3, hold = 5.0, fadeOut = 1.2,
})

preset("ember", "Ember -- near-black, warm edge", {
    width = 300, height = 48,
    background = { 0.07, 0.03, 0.02, 0.92 },
    border     = { 0.72, 0.28, 0.08, 1 },
    layout = "stack", icon = false, iconSize = 0, tint = true, flair = false, fade = 0,
    wordHex    = "ffd2a6",
    titleFont  = "GameFontNormal",         titleColor = { 1, 0.62, 0.30 },   titleY = -9,
    bodyFont   = "GameFontHighlightSmall", bodyColor  = { 0.78, 0.72, 0.68 }, bodyGap = -4,
    fadeIn = 0.25, hold = 4.0, fadeOut = 1.0,
})

-- The gold divider the level-up text and the boss banner are drawn between:
-- a hairline that is white-hot in the middle and fades to nothing at both
-- ends. Taken from the game's own art rather than drawn, so it ages with the
-- UI. The numbers are the content box of the line inside a 512x512 atlas
-- (x 11..407, y 7..17), measured off the file rather than remembered.
local FLAIR = {
    texture = "Interface\\LevelUp\\LevelUpTex",
    coords  = { 0.02148438, 0.796875, 0.01367188, 0.03515625 },
    height  = 7,
}

-- The odd one out, and the reason layout is a field rather than an assumption.
-- A loot row says what dropped and who got it; a learned word is the same two
-- facts in the same shape, so it borrows the shape -- icon, the word itself in
-- its tongue's colour where an item wears its quality's, and the tongue
-- underneath where the player's name goes. A gold line above and below sets
-- it off the way the loot feed is set off, which is what it is imitating.
preset("loot", "Loot -- icon and two lines, like an item drop", {
    width = 300, height = 52,
    background = { 0, 0, 0, 0.55 },
    border     = { 0, 0, 0, 0 },
    layout = "row", icon = "Interface\\Icons\\INV_Misc_Book_11", iconSize = 32,
    -- No hard edge. The panel bleeds away at both ends the way the loot feed
    -- and the level-up text do, so it sits on the world rather than on top of
    -- it. Only the borderless styles can do this: a fade inside a drawn frame
    -- just looks like a mistake.
    tint = true, flair = true, fade = 46,
    wordHex    = "ffffff",
    titleFont  = "GameFontNormal",         titleColor = { 1, 1, 1 },         titleY = -11,
    bodyFont   = "GameFontHighlightSmall", bodyColor  = { 0.65, 0.65, 0.65 }, bodyGap = -3,
    fadeIn = 0.2, hold = 4.5, fadeOut = 1.0,
})

local DEFAULT_PRESET = "loot"

-- The live one. Mutated in place rather than swapped, because the tests and
-- the frame both hold on to it and a style change should reach them without
-- either having to re-fetch.
local STYLE = {}
Toast.STYLE = STYLE
Toast.PRESETS = PRESETS

function Toast.StyleNames()
    local out = {}
    for i = 1, #ORDER do out[i] = ORDER[i] end
    return out
end

function Toast.StyleLabel(id)
    local p = PRESETS[id]
    return p and p.label or nil
end

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
    f:SetPoint(pos.point or PLACEMENT.point, UIParent,
        pos.relPoint or PLACEMENT.relPoint,
        pos.x or PLACEMENT.x, pos.y or PLACEMENT.y)
end

-- Which look is in force. Read from the save every time rather than cached,
-- so switching profiles or editing the variable by hand takes effect.
function Toast.CurrentStyle()
    local want = saved().style
    if type(want) == "string" and PRESETS[want] then return want end
    return DEFAULT_PRESET
end

-- Copy the chosen preset into the live table. In place, because the frame and
-- the tests both hold this table and neither should have to know a change
-- happened.
-- Not cleared first, which only works because every preset defines every
-- field the dresser reads -- otherwise a missing field would silently keep
-- the previous style's value. That is not left to trust: the tests walk every
-- preset against the list of fields and fail on a gap.
local function loadStyle()
    local p = PRESETS[Toast.CurrentStyle()] or PRESETS[DEFAULT_PRESET]
    for key, value in pairs(p) do STYLE[key] = value end
    for key, value in pairs(PLACEMENT) do
        if STYLE[key] == nil then STYLE[key] = value end
    end
end

loadStyle()

-- Everything the look touches, in one pass, so a style change is the same
-- code path as building the thing in the first place. Two paths here would
-- mean a preset that looks right on login and wrong after switching.
local function dress(f)
    f:SetSize(STYLE.width, STYLE.height)
    f:SetFrameStrata(STYLE.strata)

    local r, g, b, a = STYLE.background[1], STYLE.background[2],
        STYLE.background[3], STYLE.background[4]
    local fade = STYLE.fade or 0
    -- Clamped, because a fade wider than half the toast would leave the two
    -- tails overlapping and the middle inside out.
    if fade > STYLE.width / 2 then fade = math.floor(STYLE.width / 2) end
    Compat.SolidTexture(f.bg, r, g, b, a)
    f.bg:ClearAllPoints()
    f.bg:SetPoint("TOPLEFT", fade, 0)
    f.bg:SetPoint("BOTTOMRIGHT", -fade, 0)
    for _, side in ipairs({ "bgLeft", "bgRight" }) do
        local tex = f[side]
        tex:SetWidth(fade > 0 and fade or 1)
        if fade > 0 then
            -- Transparent at the outer edge, full where it meets the middle.
            local from, to = 0, a
            if side == "bgRight" then from, to = a, 0 end
            Compat.GradientTexture(tex, "HORIZONTAL", r, g, b, from, to)
            tex:Show()
        else
            tex:Hide()
        end
    end
    if f.border and f.border.SetColor then
        f.border:SetColor(STYLE.border[1], STYLE.border[2],
            STYLE.border[3], STYLE.border[4])
    end

    f.title:SetFontObject(STYLE.titleFont)
    f.title:SetTextColor(STYLE.titleColor[1], STYLE.titleColor[2], STYLE.titleColor[3])
    f.body:SetFontObject(STYLE.bodyFont)
    f.body:SetTextColor(STYLE.bodyColor[1], STYLE.bodyColor[2], STYLE.bodyColor[3])
    f.title:ClearAllPoints()
    f.body:ClearAllPoints()

    for i = 1, #f.flair do
        if STYLE.flair then f.flair[i]:Show() else f.flair[i]:Hide() end
    end

    if STYLE.layout == "row" then
        -- A loot row: square on the left, two lines of text beside it, both
        -- ragged-left. Lines are hung off the frame's own edges rather than
        -- off each other, because the gap between them is what makes it read
        -- as one entry and stacking them would let the fonts decide it.
        local pad = 5
        f.iconFrame:SetSize(STYLE.iconSize, STYLE.iconSize)
        f.iconFrame:ClearAllPoints()
        f.iconFrame:SetPoint("LEFT", pad, 0)
        f.icon:SetTexture(STYLE.icon)
        f.iconFrame:Show()

        local textLeft = pad + STYLE.iconSize + 7
        f.title:SetPoint("TOPLEFT", textLeft, STYLE.titleY)
        f.title:SetPoint("RIGHT", -pad, 0)
        f.title:SetJustifyH("LEFT")
        f.body:SetPoint("TOPLEFT", textLeft, STYLE.titleY + STYLE.bodyGap - 12)
        f.body:SetPoint("RIGHT", -pad, 0)
        f.body:SetJustifyH("LEFT")
    else
        f.iconFrame:Hide()
        f.title:SetPoint("TOP", 0, STYLE.titleY)
        f.title:SetJustifyH("CENTER")
        f.body:SetPoint("TOP", f.title, "BOTTOM", 0, STYLE.bodyGap)
        f.body:SetJustifyH("CENTER")
    end
end

-- Swap the look. Takes effect on the next toast, and on the one on screen now
-- if there is one, which is the whole point while you are choosing.
function Toast.SetStyle(id)
    if type(id) ~= "string" or not PRESETS[id] then return false end
    saved().style = id
    loadStyle()
    if frame then dress(frame) end
    return true
end

local function build()
    if frame or type(CreateFrame) ~= "function" then return frame end

    local f = CreateFrame("Frame", "GlyphicToast", UIParent)
    f:SetClampedToScreen(true)
    f:Hide()

    -- The panel is three pieces, not one: a solid middle and a fading tail at
    -- each end. A style with fade = 0 pins the middle to both edges and the
    -- tails have no width, which is the hard rectangle again -- so the plain
    -- styles go through the same three textures rather than a second path.
    local bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg = bg
    f.bgLeft = f:CreateTexture(nil, "BACKGROUND")
    f.bgRight = f:CreateTexture(nil, "BACKGROUND")
    f.bgLeft:SetPoint("TOPLEFT")
    f.bgLeft:SetPoint("BOTTOMLEFT")
    f.bgRight:SetPoint("TOPRIGHT")
    f.bgRight:SetPoint("BOTTOMRIGHT")
    -- Created at full strength and recoloured by dress(); a border is four
    -- textures and there is no removing them afterwards, so a style with no
    -- border gets one at zero alpha rather than a different frame.
    f.border = Compat.AddBorder(f, 1, 1, 1, 1)

    -- The loot-row square. Built always and hidden by the styles that do not
    -- want it, rather than created on demand -- a frame that only exists in
    -- one style is a frame only one style ever tests.
    local iconFrame = CreateFrame("Frame", nil, f)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    -- Inset by a pixel so the border underneath shows as an edge, and the
    -- texture trimmed because Blizzard's icon art has its own baked-in frame
    -- that looks like a smudge next to a real one.
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    Compat.AddBorder(iconFrame, 0, 0, 0, 1)
    f.iconFrame, f.icon = iconFrame, icon

    -- The gold hairlines. Same reasoning as the square: always built, hidden
    -- by the styles that do not want them. They are pinned to the frame's own
    -- top and bottom edges, so a style only has to say yes or no and never
    -- where.
    f.flair = {}
    for i, edge in ipairs({ "TOP", "BOTTOM" }) do
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetTexture(FLAIR.texture)
        line:SetTexCoord(FLAIR.coords[1], FLAIR.coords[2], FLAIR.coords[3], FLAIR.coords[4])
        line:SetHeight(FLAIR.height)
        line:SetPoint(edge .. "LEFT", 0, 0)
        line:SetPoint(edge .. "RIGHT", 0, 0)
        f.flair[i] = line
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body = body

    dress(f)

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

-- Drops the frame so the next toast builds a new one. Only the tests want
-- this: building and restyling are two routes to the same look, and without
-- it the second route is the only one anything ever exercises.
function Toast._Forget()
    Toast.Clear()
    frame = nil
end

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
    -- of the same addon rather than a notification from somewhere else -- and
    -- on the loot row it stands in for an item's quality colour. Only where
    -- the style says it can: these colours were picked to read against the
    -- dark chat frame, so a style with a pale panel has to keep its own ink.
    local color
    if STYLE.tint and ns.Colors and type(ns.Colors.Get) == "function" then
        local ok, r, g, b = pcall(ns.Colors.Get, got.glyphId)
        if ok and r and g and b then color = { r, g, b } end
    end

    local count = (got.learned and got.total)
        and string.format("%d of %d words", got.learned, got.total)
        or ((got.percent or 0) .. "%")

    local title, body
    if STYLE.layout == "row" then
        -- Loot's own arrangement: the thing you got on the first line, where
        -- it came from on the second. An item wears its quality's colour
        -- there; a word wears its tongue's.
        title = got.word or name
        body = name .. "   |cff909090" .. count .. "|r"
    else
        -- The word is picked out from the count beside it, which on a dark
        -- panel means white -- and on the parchment one meant white on tan,
        -- which is how that style shipped the first time it was looked at. So
        -- the highlight belongs to the style rather than to this line.
        title = "You pick up a word of " .. name
        body = got.word
            and string.format("|cff%s%s|r      %s",
                STYLE.wordHex or "ffffff", got.word, count)
            or count
    end

    return Toast.Show({ title = title, titleColor = color, body = body })
end

-- Seeing it without earning it. Choosing between six looks by finishing six
-- quests is not a thing anyone should have to do, and the only honest preview
-- is the real frame with real text in it.
function Toast.Preview(styleId)
    if styleId ~= nil and not Toast.SetStyle(styleId) then return false end
    -- Cleared first, or flipping quickly through the styles just builds a
    -- queue and you watch the one you picked four styles ago.
    Toast.Clear()

    local blizzId = 3                       -- Taur-ahe, a middling-length name
    local word, index, total
    if ns.QuestLearn and type(ns.QuestLearn.WordFor) == "function" then
        word, index, total = ns.QuestLearn.WordFor(blizzId, 0.41)
    end
    return Toast.Word({
        blizzId = blizzId,
        glyphId = (ns.NATIVE_LANG_IDS and ns.NATIVE_LANG_IDS[blizzId]) or "taurahe",
        word = word, learned = index, total = total, percent = 41,
    })
end

-- The next one along, wrapping. Flipping through six looks is the fastest way
-- to tell them apart, and it is one keystroke rather than six names.
function Toast.NextStyle()
    local current = Toast.CurrentStyle()
    for i = 1, #ORDER do
        if ORDER[i] == current then
            return ORDER[(i % #ORDER) + 1]
        end
    end
    return ORDER[1]
end
