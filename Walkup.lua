local ADDON, ns = ...
local Compat = ns.Compat

--[[---------------------------------------------------------------------------
    Walkups: your character thinking out loud, as a hook for anyone nearby.

    In RP a walkup is approaching someone with no OOC arrangement, and the
    advice is always the same -- "Hi" goes nowhere, a hook goes somewhere.
    So these lines are musings, not greetings: each should leave a passer-by
    something to ask about.

    One walkup is one thought, drawn from one of three lists: your race's,
    your class's, or the lines written for that exact pairing, where a dwarf
    shaman's clans argue and the spirits weigh in. Lines are never joined.
    That was tried, and two halves written apart read as two trains of
    thought smashed together. A pairing nobody has written for yet still
    has its race and class lines to draw on.

    It is only ever sent from a click, a keybind or a macro. SAY needs a
    hardware event on every client, so there is no timer here and must not
    be one; nor may a line wait for some later keypress to ride out on.
    The player picks the moment, so nothing here looks for who is nearby.
-----------------------------------------------------------------------------]]

local Walkup = {}
ns.Walkup = Walkup

Walkup.PAIR_CHANCE = 0.5    -- how often a pairing's own line is chosen, when it has any

-- Keyed by UnitRace's second return, the client's file string.
Walkup.RACES = {
    Dwarf = {
        "Haven't seen a proper mountain in weeks. These hills are just ambitious lumps.",
        "Ironforge ale spoils you. Everything else tastes like it was brewed in a boot.",
        "Every stone out here has a story. Most of them are about being stepped on.",
        "Somebody's forge is running too hot. I can smell it from here.",
        "My grandsire swore the Titans made us from stone. Some days I feel it in my knees.",
        "Bronzebeard, Wildhammer, Dark Iron. Three clans, and still one argument about who started it.",
        "Dun Morogh snow gets into your beard and stays there until summer.",
        "Too many days since I last slept under a good stone ceiling.",
        "Folk up here build with wood. Wood! It burns, it rots, and it creaks all night.",
        "There's an old dig site near here, I'd wager. The ground has that hollow sound to it.",
        "Hard to trust a sky with nothing holding it up.",
        "I'd trade my good boots for one more night at the Thunderbrew bar.",
    },
}

-- Keyed by UnitClass's second return, the upper-case class token.
Walkup.CLASSES = {
    SHAMAN = {
        "The earth's restless today. Something's stirring under our feet.",
        "Wind's carrying news from the east. I can't make all of it out yet.",
        "Fire keeps its own counsel. Ask it a question and it answers with heat.",
        "The spirits are quiet here. Too quiet, if you ask me.",
        "Water remembers every hand that's touched it. This place has seen a lot of hands.",
        "I left an offering at the last shrine. Something took it, and it wasn't an animal.",
        "The elements don't serve anyone. You ask, and sometimes they agree.",
        "My totems have been humming all morning. I wish I knew what about.",
        "There's a storm coming. Not today, but the air already knows.",
        "The ancestors walk close in places like this. Mind where you step.",
        "The Earthen Ring says the world's wounds are still healing. Some days I believe them.",
        "Even a pebble has a spirit, if you listen long enough. Most just want to be left alone.",
    },
}

-- PAIRS[race][class]: race and class in one thought.
Walkup.PAIRS = {
    Dwarf = {
        SHAMAN = {
            "Bronzebeard, Wildhammer, Dark Iron, still arguing over who started it. Ask the spirits and they'll tell you the mountain did.",
            "Ironforge was carved out of a living mountain. Some nights I swear I can still hear it grumbling about that.",
            "My grandsire swore the Titans made us from stone. The earth spirits have never once disagreed, and that worries me.",
            "It was the Wildhammer who taught us to listen to the elements. Took the rest of us a thousand years to admit the stone talks back.",
            "A forge fire and a fire spirit want the same thing, which is feeding. Only one of them ever says thank you.",
            "These hills are just ambitious lumps. The earth here agrees with me, it's only too polite to say so.",
            "I spent half my life digging ore out of the ground without asking. Now I ask first, and the ground is a good deal less cranky about it.",
            "There's an old dig site near here, I'd wager. The stone has that hollow sound, like it misses something that was taken.",
            "Ale is the only offering I've ever left the spirits that they sent back for seconds.",
            "Nothing holding the sky up out here. The wind spirits think that's very funny. I don't.",
            "Thaurissan called up a fire lord once and it swallowed half a mountain. I ask politely, these days.",
            "The water spirits in Loch Modan have been sulking since the dam broke. Can't say I blame them, half their loch ran off.",
        },
    },
}

local _issecret = _G.issecretvalue

-- nil for anything secret. Asked before any other look at the value,
-- including a comparison, since comparing a secret throws too.
local function readable(v)
    if _issecret and _issecret(v) then return nil end
    return v
end

local function db()
    GlyphicDB = GlyphicDB or {}
    local w = GlyphicDB.walkup
    if type(w) ~= "table" then w = {}; GlyphicDB.walkup = w end
    if w.enabled == nil then w.enabled = false end
    if w.point == nil then w.point = "CENTER" end
    if w.x == nil then w.x = 0 end
    if w.y == nil then w.y = -200 end
    return w
end

local function playerToken(fn)
    if type(fn) ~= "function" then return nil end
    local ok, _, token = pcall(fn, "player")
    if not ok then return nil end
    return readable(token)
end

-- The race, class and pairing lists your character can draw on; any may be nil.
function Walkup.Pools()
    local race, class = playerToken(UnitRace) or "", playerToken(UnitClass) or ""
    local byClass = Walkup.PAIRS[race]
    return Walkup.RACES[race], Walkup.CLASSES[class], byClass and byClass[class]
end

local last = {}

-- A random line from `pool`, never the one it gave last time.
local function pick(pool, slot, rand)
    local n = #pool
    if n == 0 then return nil end
    local i = rand(n)
    if n > 1 and i == last[slot] then i = (i % n) + 1 end
    last[slot] = i
    return pool[i]
end

-- `rand` is math.random's shape: rand(n) is 1..n, rand() is [0, 1).
function Walkup.Compose(rand)
    rand = rand or math.random
    local race, class, pair = Walkup.Pools()
    if pair and (rand() < Walkup.PAIR_CHANCE or not (race or class)) then
        return pick(pair, "pair", rand)
    end
    if race and class then
        if rand(2) == 1 then return pick(race, "race", rand) end
        return pick(class, "class", rand)
    end
    if race then return pick(race, "race", rand) end
    if class then return pick(class, "class", rand) end
    return nil
end

function Walkup.Speak()
    if Compat.InChatLockdown() then
        ns.Print("chat is locked during this encounter, so your walkup stays unsaid.")
        return nil
    end
    local text = Walkup.Compose()
    if not text then
        ns.Print("there are no walkup lines for your race or class yet.")
        return nil
    end
    return ns.SayInCharacter(text)
end

--=========================================================================--
--  The floating button
--=========================================================================--
local button

local function savePosition()
    local point, _, relPoint, x, y = button:GetPoint()
    local w = db()
    w.point, w.relPoint = point or "CENTER", relPoint or point or "CENTER"
    w.x, w.y = x or 0, y or 0
end

local function showTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Walkup", 1, 1, 1)
    GameTooltip:AddLine("Your character thinks out loud in /say, shaped by their race, "
        .. "their class or both, through your tongue and accent like anything "
        .. "you type.", 0.8, 0.8, 0.8, true)
    local race, class, pair = Walkup.Pools()
    if not (pair or race or class) then
        GameTooltip:AddLine("No lines for your race or class yet.", 0.8, 0.5, 0.5, true)
    elseif not pair and not (race and class) then
        GameTooltip:AddLine("Only your " .. (race and "race" or "class")
            .. " has lines so far.", 0.8, 0.8, 0.5, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffffffClick|r  Say a walkup line", 1, 1, 1)
    local key = GetBindingKey and GetBindingKey("GLYPHIC_WALKUP")
    if key then GameTooltip:AddLine("|cffffffffKeybind|r  " .. key, 1, 1, 1) end
    GameTooltip:AddLine("|cffffffffDrag|r  Move (unlock the bar in options)", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function build()
    if button then return button end
    local b = CreateFrame("Button", "GlyphicWalkupButton", UIParent)
    Compat.PanelButton(b, "Walk up", 96, 22, "GameFontNormalSmall")
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function() Walkup.Speak() end)
    b:SetScript("OnDragStart", function(self)
        if GlyphicDB and GlyphicDB.widget and GlyphicDB.widget.locked then return end
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
    Walkup._button = b
    return b
end

function Walkup.Refresh()
    local w = db()
    if not w.enabled then
        if button then button:Hide() end
        return
    end
    build()
    button:ClearAllPoints()
    button:SetPoint(w.point or "CENTER", UIParent, w.relPoint or w.point or "CENTER",
        w.x or 0, w.y or -200)
    button:Show()
end

function Walkup.IsShown() return db().enabled and true or false end

function Walkup.SetShown(on)
    db().enabled = on and true or false
    Walkup.Refresh()
end

-- /glyphic walkup [show|hide]. Bare, it speaks: a macro is a keypress.
function Walkup.Command(rest)
    local arg = string.lower(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "show" or arg == "on" then
        Walkup.SetShown(true)
        ns.Print("walkup button shown.")
    elseif arg == "hide" or arg == "off" then
        Walkup.SetShown(false)
        ns.Print("walkup button hidden.")
    elseif arg == "toggle" then
        Walkup.SetShown(not Walkup.IsShown())
    else
        Walkup.Speak()
    end
    if ns.RefreshGeneralPanel then ns.RefreshGeneralPanel() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() Walkup.Refresh() end)
