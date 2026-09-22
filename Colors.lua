local ADDON, ns = ...

--[[---------------------------------------------------------------------------
    Per-language chat colors.

    Every tongue can carry its own color, so Demonic reads as orange and Old God
    as deep purple at a glance -- whether or not you understand a word of either.
    That last part is the point: recognising a language you cannot yet read is
    exactly the cue a learner wants, so coloring runs independently of decoding.

    Colors are applied when a message is DISPLAYED, never sent. WoW sanitises
    color escapes out of player chat, and baking a palette into outgoing text
    would impose your taste on everyone else and eat into the 255-character
    budget besides. Each client paints its own chat, so two players can run
    completely different palettes over the same conversation.

    Stored account-wide (TonguesOfAzerothAccountDB): a palette is a cosmetic
    preference you want on every alt, not a per-character setting.
-----------------------------------------------------------------------------]]

local Colors = {}
ns.Colors = Colors

local Language = ns.Language

local strformat, strlower, strmatch = string.format, string.lower, string.match
local floor = math.floor

--=========================================================================--
--  Storage
--=========================================================================--
-- Account-wide, unlike everything else in the addon. Declared in every .toc as
-- "## SavedVariables: TonguesOfAzerothAccountDB".
-- Tag color and speech tint are INDEPENDENT axes, not a master switch and a
-- modifier. Turning tags off while speech is on has to leave the words tinted
-- and the tag in its normal channel color -- switching one off must never
-- silently switch the other off.
local DEFAULTS = {
    -- Tags are colored out of the box: the feature should announce itself.
    tags = true,
    -- Speech is left in its normal channel color unless asked for. Tinting every
    -- word of every line is a taste most people want to opt into, not out of.
    speech = false,
    -- WoW's own language system (a Horde player speaking real Orcish) is off by
    -- default for a blunter reason: nearly all chat is in Common or your own
    -- faction tongue, so tinting it repaints the whole window rather than
    -- highlighting anything.
    realLanguages = false,
    byLang = {},
}

local function store()
    local db = _G.TonguesOfAzerothAccountDB
    if type(db) ~= "table" then
        db = {}
        _G.TonguesOfAzerothAccountDB = db
    end
    local c = db.colors
    if type(c) ~= "table" then
        c = {}
        db.colors = c
    end
    -- "enabled" was this setting's name while it was still (wrongly) a master
    -- switch over both axes; it means the tag axis now.
    if c.enabled ~= nil and c.tags == nil then
        c.tags = c.enabled and true or false
        c.enabled = nil
    end
    for k, v in pairs(DEFAULTS) do
        if c[k] == nil then
            c[k] = (type(v) == "table") and {} or v
        end
    end
    if type(c.byLang) ~= "table" then c.byLang = {} end
    return c
end
Colors.Store = store

function Colors.TagsEnabled() return store().tags == true end
function Colors.SpeechEnabled() return store().speech == true end
function Colors.RealLanguagesEnabled() return store().realLanguages == true end

-- "Is any coloring happening at all?" -- for the callers that need to know
-- whether to bother, rather than which axis is on.
function Colors.AnyEnabled()
    local c = store()
    return c.tags == true or c.speech == true
end

function Colors.SetTagsEnabled(v) store().tags = v and true or false end
function Colors.SetSpeechEnabled(v) store().speech = v and true or false end
function Colors.SetRealLanguagesEnabled(v) store().realLanguages = v and true or false end

--=========================================================================--
--  Hex helpers
--=========================================================================--
-- Accepts "ff9e5e", "#ff9e5e", "FF9E5E" or a full "|cffff9e5e" escape. Returns
-- nil on anything else, so a half-typed hex box simply doesn't apply rather
-- than erroring.
function Colors.ParseHex(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("^%s+", ""):gsub("%s+$", "")
    hex = hex:gsub("^|c", ""):gsub("^#", "")
    -- What's left of "|cffRRGGBB" is eight characters: drop the alpha pair.
    if #hex == 8 then hex = hex:sub(3) end
    hex = strmatch(hex, "^(%x%x%x%x%x%x)$")
    if not hex then return nil end
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

-- Components are 0-1 floats, matching both ParseHex and WoW's color picker.
function Colors.ToHex(r, g, b)
    local function byte(v)
        v = floor((tonumber(v) or 0) * 255 + 0.5)
        if v < 0 then v = 0 elseif v > 255 then v = 255 end
        return v
    end
    return strformat("%02x%02x%02x", byte(r), byte(g), byte(b))
end

--=========================================================================--
--  Default palette
--=========================================================================--
-- Hand-picked for the tongues that have a established feel. Everything else is
-- generated below, so all ~70 languages arrive distinguishable rather than
-- defaulting to one shared purple.
local DEFAULT_HEX = {
    oldgod      = "8e4ec6", -- Shath'yar: deep eldritch purple
    demonic     = "ff9e5e", -- Eredun: light fel orange
    orcish      = "cc5540",
    darnassian  = "7fd4c1",
    thalassian  = "e8c46a",
    dwarven     = "c79a5b",
    gnomish     = "6fd0e8",
    taurahe     = "b58a5a",
    zandali     = "6fbf6f",
    draenei     = "9db9e8",
    gutterspeak = "8a9a6b",
    skyborne    = "a8d8e8",
    common      = "d4d4d4",
    kalimag     = "e0844a",
    titan       = "ffd98a",
    draconic    = "d9553f",
    nerubian    = "9d86b8",
    nazja       = "5fc4b0",
    ethereal    = "c3b4e8",
    undead      = "8fa38a",
    goblin      = "bcd94a",
    darkiron    = "a06050",
    gilnean     = "b0a08c",
    ogre        = "b08040",
    furbolg     = "a8783f",
    vrykul      = "9fb6cc",
    pandaren    = "6fc8a8",
    tuskarr     = "88b4c8",
    nerglish    = "5fb0d4", -- Murloc
}

-- Every remaining tongue gets a stable color derived from its id, so a beast or
-- faction dialect is still visually distinct without anyone hand-picking 50 more
-- swatches. Hue comes from the id hash; saturation and value are pinned to a
-- band that stays legible on the dark chat background, which is why this is not
-- simply three random bytes.
local function hsvToRGB(h, s, v)
    local i = floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local m = i % 6
    if m == 0 then return v, t, p
    elseif m == 1 then return q, v, p
    elseif m == 2 then return p, v, t
    elseif m == 3 then return p, q, v
    elseif m == 4 then return t, p, v
    else return v, p, q end
end

local function hashId(id)
    local h = 5381
    for i = 1, #id do
        h = (h * 33 + string.byte(id, i)) % 2147483648
    end
    return h
end

local generatedCache = {}
local function generatedHex(langId)
    local cached = generatedCache[langId]
    if cached then return cached end
    local h = hashId(langId)
    -- Two independent slices of the hash: hue anywhere on the wheel, but only a
    -- narrow, readable range of saturation and brightness.
    local hue = (h % 360) / 360
    local sat = 0.42 + ((floor(h / 360) % 26) / 100)  -- 0.42 .. 0.67
    local val = 0.80 + ((floor(h / 9360) % 16) / 100) -- 0.80 .. 0.95
    local hex = Colors.ToHex(hsvToRGB(hue, sat, val))
    generatedCache[langId] = hex
    return hex
end

-- A sub-dialect inherits its parent's color: Amani, Gurubashi and Drakkari all
-- sound like Troll, so they should look like Troll too.
local parentOf
local function resolveParent(langId)
    if not parentOf then
        parentOf = {}
        if Language and Language.GetLanguages then
            local langs = Language.GetLanguages()
            for i = 1, #langs do
                local l = langs[i]
                if l.sub and l.parent then parentOf[l.id] = l.parent end
            end
        end
    end
    return parentOf[langId]
end

-- Rebuilt lazily; a custom language registered at runtime must not inherit a
-- stale parent map.
function Colors.InvalidateCache()
    parentOf = nil
end

function Colors.DefaultHex(langId)
    if type(langId) ~= "string" or langId == "" then return "ffffff" end
    langId = strlower(langId)
    -- A hidden alias is a second name for a tongue that is in the list, so it
    -- must paint the same color. It resolves to nothing via resolveParent (the
    -- parent map is built from the visible list), and would otherwise fall
    -- through to a generated color unrelated to the language it names.
    if Language and Language.CanonicalId then langId = Language.CanonicalId(langId) end
    local explicit = DEFAULT_HEX[langId]
    if explicit then return explicit end
    local parent = resolveParent(langId)
    if parent then
        local inherited = DEFAULT_HEX[parent]
        if inherited then return inherited end
        return generatedHex(parent)
    end
    return generatedHex(langId)
end

--=========================================================================--
--  Lookup / mutation
--=========================================================================--
function Colors.Hex(langId)
    if type(langId) ~= "string" or langId == "" then return "ffffff" end
    local custom = store().byLang[strlower(langId)]
    if type(custom) == "string" and Colors.ParseHex(custom) then return custom end
    return Colors.DefaultHex(langId)
end

function Colors.Get(langId)
    return Colors.ParseHex(Colors.Hex(langId))
end

function Colors.IsCustom(langId)
    if type(langId) ~= "string" then return false end
    return store().byLang[strlower(langId)] ~= nil
end

-- Accepts a hex string or three 0-1 components. Returns true on success.
function Colors.Set(langId, hexOrR, g, b)
    if type(langId) ~= "string" or langId == "" then return false end
    local hex
    if type(hexOrR) == "string" then
        if not Colors.ParseHex(hexOrR) then return false end
        hex = (Colors.ToHex(Colors.ParseHex(hexOrR)))
    elseif type(hexOrR) == "number" then
        hex = Colors.ToHex(hexOrR, g, b)
    else
        return false
    end
    store().byLang[strlower(langId)] = hex
    return true
end

function Colors.Reset(langId)
    if type(langId) ~= "string" then return end
    store().byLang[strlower(langId)] = nil
end

function Colors.ResetAll()
    store().byLang = {}
end

--=========================================================================--
--  Painting
--=========================================================================--
-- Wrap a span in a color, surviving any color codes already inside it.
--
-- This is the whole reason it isn't a bare concatenation: a chat line can carry
-- an item link, which ends in "|r". That "|r" would close OUR color early and
-- leave the rest of the sentence uncolored, so the color is re-opened after
-- every one of them.
function Colors.Wrap(text, hex)
    if type(text) ~= "string" or text == "" then return text end
    if not hex or not Colors.ParseHex(hex) then return text end
    local open = "|cff" .. strlower(hex)
    local inner = text:gsub("|r", "|r" .. open)
    return open .. inner .. "|r"
end

-- Paint one chat line for `langId`.
--
--   message : the text the client is about to display
--   langId  : which tongue it is in (nil = leave alone)
--   opts    : { tags = bool, speech = bool } -- override the saved settings,
--             for previews and for callers with their own rules
--
-- The tag and the speech are painted separately, on separate settings, so all
-- four combinations behave the way the checkboxes say they will -- including
-- speech-on/tags-off, which tints the words and leaves the tag in the channel's
-- own color.
function Colors.Apply(message, langId, opts)
    if type(message) ~= "string" or message == "" then return message end
    if not langId then return message end
    local c = store()

    -- Written out rather than folded into an `and/or` chain: `x ~= nil and x or
    -- y` silently falls through to y when x is false, which is exactly the case
    -- a caller passing speech=false is trying to express.
    local tagColor, speech = c.tags == true, c.speech == true
    if opts then
        if opts.tags ~= nil then tagColor = opts.tags and true or false end
        if opts.speech ~= nil then speech = opts.speech and true or false end
    end
    if not (tagColor or speech) then return message end

    local hex = Colors.Hex(langId)

    local tag, rest = strmatch(message, "^(%[[^%]]+%]%s*)(.*)$")
    if tag then
        if tagColor and speech then
            return Colors.Wrap(tag .. rest, hex)
        elseif tagColor then
            return Colors.Wrap(tag, hex) .. rest
        end
        return tag .. Colors.Wrap(rest, hex)
    end

    -- No tag: a cast phrase names its tongue in prose and puts the foreign words
    -- in quotes. That span is both the speech AND the only marker of which
    -- tongue the line is in, so either axis colors it -- otherwise turning
    -- speech off would leave cast phrases with nothing identifying them at all.
    -- (%b needs two distinct delimiters, so quotes are matched the plain way.)
    local painted, count = message:gsub('"[^"]*"', function(span)
        return Colors.Wrap(span, hex)
    end)
    if count > 0 then return painted end

    if speech then return Colors.Wrap(message, hex) end
    return message
end
