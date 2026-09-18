--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Casts.lua
    Speaks a line of your own when one of your spells goes off, in whatever
    tongue you're currently speaking:  Corvin roars "Nuk'luk!"

    Four things shape this file, and all four are worth reading before changing
    it:

      * Phrases are keyed by spell NAME, never by spell id. Classic gives every
        rank of a spell its own id -- Immolate alone has nine -- so an id-keyed
        library would need a separate table per flavor and would still miss
        whichever rank the player actually has. Names are stable across ranks
        and across flavors. The cost is that the shipped library only matches an
        English client; phrases you write yourself are captured from your own
        client, so those work on any locale.

      * Delivery is EMOTE, and only EMOTE. SAY, YELL and numbered channels have
        required a hardware event since 8.2.5: they must come from a keypress,
        which a cast handler is not, so the client refuses them on every flavor
        we ship for -- this is not a Midnight rule. Emote carries no such
        requirement, and that is the whole reason automatic RP is possible.

      * Midnight (and Forever) additionally refuse *all* addon chat during raid
        encounters, Mythic+ and rated PvP -- see Compat.InChatLockdown. Nothing
        gets around that, so there the line is printed for your eyes only.

      * The client renders an emote as "Name " + your text, with that space
        baked into CHAT_EMOTE_GET. So no template can produce "Corvin's
        Felhunter snarls" -- it would come out "Corvin 's Felhunter snarls".
        Pet lines are phrased around the space instead ("watches Felhunter
        lunge for the throat").
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Compat = ns.Compat

local Casts = {}
ns.Casts = Casts

-- Weights run 0..5 rather than 0..100: the only thing a weight has to express
-- is "more often than that one", and a short scale keeps the UI to a row of
-- steps. 0 is meaningful -- it retires a line you don't like without deleting
-- it, which matters for library phrases you can't delete.
local DEFAULT_WEIGHT = 3
Casts.MAX_WEIGHT = 5

local function castDB()
    return TonguesOfAzerothDB and TonguesOfAzerothDB.casts
end

--=========================================================================--
--  Spell keys
--=========================================================================--
-- The lookup key for a spell: its name, folded to lower case. Ranks ("Immolate
-- (Rank 4)") never reach us -- UNIT_SPELLCAST_SUCCEEDED hands over an id and
-- the name we resolve from it carries no rank suffix -- but trailing rank text
-- is stripped anyway so a key typed by hand or captured on an old client still
-- matches.
function Casts.Key(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("%s*%b()%s*$", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:lower()
end

-- Display name for a key. Prefers the exact spell name we last saw from the
-- client, so the UI shows "Chaos Bolt" rather than "chaos bolt".
local seenNames = {}
function Casts.DisplayName(key)
    if not key then return "" end
    if seenNames[key] then return seenNames[key] end
    local lib = ns.CastLibrary and ns.CastLibrary.DisplayName
    if lib then
        local name = lib(key)
        if name then return name end
    end
    -- Last resort: title-case the key so it at least reads like a spell.
    return (key:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function Casts.NoteSpellName(name)
    local key = Casts.Key(name)
    if key then seenNames[key] = name end
    return key
end

--=========================================================================--
--  Phrase storage
--=========================================================================--
-- A phrase's identity is its text. That keeps the three places a phrase can
-- come from -- your own list, an opted-in library pack, and a weight override
-- -- addressable by the same value, with no ids to keep in sync when a pack
-- gains or loses lines between versions.

local function userList(key, create)
    local c = castDB()
    if not (c and key) then return nil end
    if not c.spells[key] and create then c.spells[key] = {} end
    return c.spells[key]
end

-- The weight you set by hand, or nil if you never touched this line. Kept
-- separate from GetWeight because an explicit weight means something stronger
-- than a number: it opts the line out of tone weighting entirely, so a line you
-- asked for plays even when it cuts against your character's Bearing.
function Casts.GetExplicitWeight(key, text)
    local c = castDB()
    local byKey = c and c.weights and c.weights[key]
    local w = byKey and byKey[text]
    if type(w) == "number" then return w end
    return nil
end

function Casts.GetWeight(key, text)
    return Casts.GetExplicitWeight(key, text) or DEFAULT_WEIGHT
end

function Casts.SetWeight(key, text, weight)
    local c = castDB()
    if not (c and key and text) then return end
    weight = math.max(0, math.min(Casts.MAX_WEIGHT, math.floor(tonumber(weight) or DEFAULT_WEIGHT)))
    if type(c.weights) ~= "table" then c.weights = {} end
    -- Stored even when it equals the default: see GetExplicitWeight for why the
    -- difference between "set to 3" and "never set" has to survive a reload.
    c.weights[key] = c.weights[key] or {}
    c.weights[key][text] = weight
end

function Casts.ClearWeight(key, text)
    local c = castDB()
    if not (c and key and text) then return end
    if c.weights and c.weights[key] then c.weights[key][text] = nil end
end

function Casts.IsUserPhrase(key, text)
    local list = userList(key)
    if not list then return false end
    for _, t in ipairs(list) do
        if t == text then return true end
    end
    return false
end

function Casts.AddPhrase(key, text)
    if not key or type(text) ~= "string" then return false, "no phrase" end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return false, "no phrase" end
    if Casts.IsUserPhrase(key, text) then return false, "already there" end
    local list = userList(key, true)
    if not list then return false, "not loaded" end
    list[#list + 1] = text
    return true
end

function Casts.RemovePhrase(key, text)
    local list = userList(key)
    if not list then return false end
    for i, t in ipairs(list) do
        if t == text then
            table.remove(list, i)
            if #list == 0 then castDB().spells[key] = nil end
            return true
        end
    end
    return false
end

function Casts.IsMuted(key)
    local c = castDB()
    return (c and key and c.muted[key]) and true or false
end

function Casts.SetMuted(key, muted)
    local c = castDB()
    if not (c and key) then return end
    c.muted[key] = muted and true or nil
end

--=========================================================================--
--  Library packs
--=========================================================================--
function Casts.IsPackEnabled(packId)
    local c = castDB()
    return (c and c.packs[packId]) and true or false
end

function Casts.SetPackEnabled(packId, enabled)
    local c = castDB()
    if not c then return end
    c.packs[packId] = enabled and true or nil
end

-- First time the feature is turned on, tick the obvious packs so something
-- actually speaks. Once only -- re-enabling must not undo deliberate unticks.
function Casts.SeedDefaultPacks()
    local c = castDB()
    if not c or c.packsSeeded then return end
    c.packsSeeded = true
    local lib = ns.CastLibrary
    if not lib then return end
    local mine = lib.PackForPlayer and lib.PackForPlayer()
    if mine then c.packs[mine] = true end
    if lib.PlayerHasPetClass and lib.PlayerHasPetClass() then
        c.packs.pets = true
    end
end

--=========================================================================--
--  The character sheet
--=========================================================================--
-- Tone is described the way a tabletop character is: a Bearing for how they
-- carry themselves, an optional second Bearing for a streak that cuts against
-- the first, a Wording for diction, and how much they talk. The four combine
-- into a weighting over the whole library rather than selecting one pre-written
-- voice, which is what lets "Fierce with a Dry streak" genuinely draw on both
-- without anyone having to write a Fierce-Dry variant of every line.
--
-- Talkativeness costs no content at all: whether a line speaks is visible in
-- the line itself, since spoken words are the bit in quotes. So that dial just
-- reweights what is already there.

Casts.BEARINGS = {
    { id = "plain",  name = "Plain",  desc = "States what is happening, without flourish." },
    { id = "dry",    name = "Dry",    desc = "Understated, faintly amused." },
    { id = "fierce", name = "Fierce", desc = "Loud, forward, spoiling for it." },
    { id = "solemn", name = "Solemn", desc = "Grave, with weight behind the words." },
    { id = "warm",   name = "Warm",   desc = "Looks after people, even mid-fight." },
}

Casts.WORDINGS = {
    { id = "common",  name = "Common",  desc = "Plain, modern speech." },
    { id = "courtly", name = "Courtly", desc = "Formal and archaic: oaths, vows, thee and thou." },
    { id = "blunt",   name = "Blunt",   desc = "Clipped. A soldier's mouth." },
}

Casts.TALK = {
    { id = "quiet",    name = "Quiet",    desc = "Narration only; hardly ever speaks aloud." },
    { id = "measured", name = "Measured", desc = "Speaks about half the time." },
    { id = "loud",     name = "Loud",     desc = "Speaks whenever there is anything to say." },
}

local TONE_DEFAULT = { bearing = "plain", second = "", wording = "common", talk = "measured" }

local function optionName(list, id)
    for _, opt in ipairs(list) do
        if opt.id == id then return opt.name end
    end
    return nil
end

local function validId(list, value, fallback)
    for _, opt in ipairs(list) do
        if opt.id == value then return value end
    end
    return fallback
end

function Casts.GetTone()
    local c = castDB()
    local t = (c and type(c.tone) == "table") and c.tone or TONE_DEFAULT
    return {
        bearing = validId(Casts.BEARINGS, t.bearing, TONE_DEFAULT.bearing),
        -- "" is a real answer: plenty of characters are only the one thing.
        second = validId(Casts.BEARINGS, t.second, ""),
        wording = validId(Casts.WORDINGS, t.wording, TONE_DEFAULT.wording),
        talk = validId(Casts.TALK, t.talk, TONE_DEFAULT.talk),
    }
end

function Casts.SetTone(field, value)
    local c = castDB()
    if not c then return end
    if type(c.tone) ~= "table" then c.tone = {} end
    if field == "bearing" then
        c.tone.bearing = validId(Casts.BEARINGS, value, TONE_DEFAULT.bearing)
        -- A streak that matches the main Bearing says nothing, so drop it.
        if c.tone.second == c.tone.bearing then c.tone.second = "" end
    elseif field == "second" then
        local v = validId(Casts.BEARINGS, value, "")
        c.tone.second = (v == Casts.GetTone().bearing) and "" or v
    elseif field == "wording" then
        c.tone.wording = validId(Casts.WORDINGS, value, TONE_DEFAULT.wording)
    elseif field == "talk" then
        c.tone.talk = validId(Casts.TALK, value, TONE_DEFAULT.talk)
    end
end

function Casts.DescribeTone()
    local t = Casts.GetTone()
    local lead = optionName(Casts.BEARINGS, t.bearing) or "Plain"
    local streak = optionName(Casts.BEARINGS, t.second)
    if streak then lead = lead .. " with a " .. streak .. " streak" end
    return lead .. ", " .. (optionName(Casts.WORDINGS, t.wording) or "Common")
        .. ", " .. (optionName(Casts.TALK, t.talk) or "Measured")
end

-- What a library line is worth to this character. Zero means "not this
-- character's voice", which drops the line from the roll -- it stays visible in
-- the panel, greyed, and setting a weight by hand overrides this.
local BEARING_MATCH, BEARING_SECOND = 3, 2
local WORDING_MATCH, WORDING_CLASH = 2, 0.5

function Casts.ToneWeight(entry, tone)
    tone = tone or Casts.GetTone()
    local m = 1

    local bearing = entry.bearing
    if bearing and bearing ~= "plain" then
        if bearing == tone.bearing then
            m = m * BEARING_MATCH
        elseif tone.second ~= "" and bearing == tone.second then
            m = m * BEARING_SECOND
        else
            return 0
        end
    elseif tone.bearing == "plain" then
        -- Plain is a Bearing you can pick as well as the neutral backbone, so
        -- picking it promotes those lines rather than merely leaving them in.
        m = m * BEARING_MATCH
    end

    if entry.wording then
        m = m * ((entry.wording == tone.wording) and WORDING_MATCH or WORDING_CLASH)
    end

    local speaks = entry.text:find('"', 1, true) ~= nil
    if tone.talk == "quiet" then
        m = m * (speaks and 0.15 or 1.5)
    elseif tone.talk == "loud" then
        m = m * (speaks and 3 or 0.35)
    end
    return m
end

--=========================================================================--
--  Assembling a spell's phrases
--=========================================================================--
-- Every phrase available for a spell, your own first and then each opted-in
-- pack, de-duplicated by text so a line you happened to write yourself doesn't
-- also arrive from a pack and get double the share of the roll.
--
-- Your own phrases are never tone-weighted. You wrote them; they are by
-- definition your character's voice, and second-guessing them against a dial
-- would be obnoxious. The library is what the sheet filters.
local WILDCARD_WEIGHT = 1

function Casts.GetPhrases(key)
    local out, seen = {}, {}
    if not key then return out end

    local list = userList(key)
    if list then
        for _, text in ipairs(list) do
            if not seen[text] then
                seen[text] = true
                out[#out + 1] = {
                    text = text, weight = Casts.GetWeight(key, text),
                    step = Casts.GetWeight(key, text), user = true,
                }
            end
        end
    end

    local tone = Casts.GetTone()
    local function addLibraryLine(entry, base)
        if seen[entry.text] then return end
        seen[entry.text] = true
        local override = Casts.GetExplicitWeight(key, entry.text)
        local weight, offTone
        if override then
            weight = override
        else
            local m = Casts.ToneWeight(entry, tone)
            weight = base * m
            offTone = (m == 0)
        end
        out[#out + 1] = {
            text = entry.text, weight = weight, step = override or base,
            pack = entry.pack, bearing = entry.bearing, wording = entry.wording,
            wildcard = entry.wildcard, offTone = offTone,
        }
    end

    local lib = ns.CastLibrary
    if lib and lib.GetPhrases then
        for _, entry in ipairs(lib.GetPhrases(key)) do
            addLibraryLine(entry, DEFAULT_WEIGHT)
        end
    end

    -- Creed lines ride along on spells that already say something. Gating on a
    -- non-empty list matters: a wildcard pack must not make every spell in the
    -- book start talking just because it was ticked.
    if #out > 0 and lib and lib.GetWildcards then
        for _, entry in ipairs(lib.GetWildcards()) do
            addLibraryLine(entry, WILDCARD_WEIGHT)
        end
    end
    return out
end

-- Keys with at least one phrase behind them, sorted by display name, for the
-- spell list in the options panel.
function Casts.GetKeys()
    local set = {}
    local c = castDB()
    if c then
        for key in pairs(c.spells) do set[key] = true end
    end
    local lib = ns.CastLibrary
    if lib and lib.EachEnabledKey then
        for key in lib.EachEnabledKey() do set[key] = true end
    end

    local keys = {}
    for key in pairs(set) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        return Casts.DisplayName(a):lower() < Casts.DisplayName(b):lower()
    end)
    return keys
end

--=========================================================================--
--  Rendering
--=========================================================================--
-- A phrase is the body of an emote -- what follows your name -- with two extra
-- conventions:
--
--   * Anything in double quotes is spoken aloud, so it goes through the
--     language and accent exactly as chat would. Everything outside the quotes
--     is narration and is left in plain English, because that is the part
--     onlookers are meant to understand.
--   * %s, %p, %f and %t stand in for the spell, your pet's name, its family
--     and your target.
--
-- So  roars "Nuk'luk!" and hurls fire at %t  becomes
--     Corvin roars "Zaq'roth!" and hurls fire at Hogger
local TOKENS = { s = "spell", p = "pet", f = "family", t = "target" }

Casts.TOKEN_HELP = {
    { token = "%s", desc = "the spell's name" },
    { token = "%p", desc = "your pet's name" },
    { token = "%f", desc = "your pet's family (Felhunter, Wolf, ...)" },
    { token = "%t", desc = "your target's name" },
    { token = "\"...\"", desc = "spoken aloud -- translated into your language" },
}

-- Fill in the %-tokens. Returns nil when the phrase needs something this cast
-- can't supply (a pet line with no pet out, %t with nothing targeted), so the
-- caller can fall back to a different phrase rather than emote "lunges at ".
local function substitute(template, ctx)
    local missing = false
    local out = template:gsub("%%(%a)", function(letter)
        local field = TOKENS[letter:lower()]
        if not field then return "%" .. letter end
        local value = ctx[field]
        if type(value) ~= "string" or value == "" then
            missing = true
            return ""
        end
        return value
    end)
    if missing then return nil end
    return out
end

-- Render a phrase into a finished emote body. `live` is false for previews, so
-- the accent's spacing state isn't advanced by looking at the options panel.
-- Returns line, langId, spoken -- where `spoken` lists { original, encoded }
-- pairs for the decode broadcast, and is empty when nothing was translated.
-- Ordinary chat wears the tongue as a leading "[Broken Demonic] " tag, but an
-- emote cannot: the client renders it as "Name " + body, so a leading tag lands
-- between the name and the verb and the sentence falls apart --
--
--     Corvin [Broken Demonic (Eredun)] snarls "Aman!" and the fire takes hold.
--
-- So a cast phrase names its tongue in prose, immediately after the speech it
-- applies to, which is where a reader expects it:
--
--     Corvin snarls "Aman!" in Broken Demonic and the fire takes hold.
--
-- Named once, after the FIRST encoded span: every span in a line is the same
-- tongue, so repeating it would only pad a message that already shares its 255
-- characters with a translation. Receivers find it by name rather than by
-- position -- see inlineLangIdFromProse in Core.lua.
function Casts.Render(template, ctx, live)
    local body = substitute(template, ctx or {})
    if not body then return nil end

    local spoken, langId = {}, nil
    local named = false
    body = body:gsub('"([^"]*)"', function(speech)
        if speech:gsub("%s", "") == "" then return '"' .. speech .. '"' end
        local out, lid, wasEncoded = ns.EncodeSpeech(speech, live)
        langId = lid or langId
        if not wasEncoded then
            -- An accent is plain English and needs no decoding, so it gets no
            -- attribution either.
            return '"' .. out .. '"'
        end
        spoken[#spoken + 1] = { original = speech, encoded = out }
        if named or not lid then return '"' .. out .. '"' end
        named = true
        return '"' .. out .. '" in ' .. ns.LanguageName(lid)
    end)

    if named then
        -- "roars \"Lok'tar!\" in Orcish" has lost the closing punctuation that
        -- used to sit on the quote, so give the sentence its full stop back.
        if not body:find("[%.%?!,;:]%s*$") then body = body .. "." end
    end
    return ns.FitMessage(body), langId, spoken
end

--=========================================================================--
--  Choosing and speaking
--=========================================================================--
local lastSpoken = 0
local lastByKey = {}

local function weightedPick(phrases)
    local total = 0
    for _, p in ipairs(phrases) do
        if p.weight > 0 then total = total + p.weight end
    end
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, p in ipairs(phrases) do
        if p.weight > 0 then
            roll = roll - p.weight
            if roll <= 0 then return p end
        end
    end
    return nil
end

local function petContext()
    local ctx = {}
    if UnitExists and UnitExists("pet") then
        local name = UnitName("pet")
        if type(name) == "string" and not ns.IsSecret(name) then ctx.pet = name end
        if type(UnitCreatureFamily) == "function" then
            local family = UnitCreatureFamily("pet")
            if type(family) == "string" and not ns.IsSecret(family) then ctx.family = family end
        end
    end
    return ctx
end

local function buildContext(spellName)
    local ctx = petContext()
    ctx.spell = spellName
    -- A hostile unit's name is a secret value on instanced maps, and reading one
    -- is a hard error rather than a nil, so this has to be asked about before
    -- it's used. Phrases with %t simply don't fire there; see substitute().
    if UnitExists and UnitExists("target") then
        local name = UnitName("target")
        if type(name) == "string" and not ns.IsSecret(name) then ctx.target = name end
    end
    return ctx
end

-- Print a line only you can see, formatted the way the emote would have looked.
-- Used when the client refuses addon chat outright (Midnight's lockdown in
-- raids, M+ and rated PvP) and when you've asked ToA to stand down in
-- instances: the RP beat still lands for you, it just doesn't reach anyone else.
local function showLocally(body)
    local me = UnitName("player")
    if type(me) ~= "string" then me = "" end
    local format = CHAT_EMOTE_GET or "%s "
    local ok, line = pcall(string.format, format, me)
    if not ok then line = me .. " " end
    ns.PrintToChat(line .. body, "emote")
end

-- Why a line would be kept to yourself rather than sent, or nil when it goes
-- out normally. Also drives /ogt cast status, so it returns a reason rather
-- than a bare boolean.
function Casts.BlockedReason()
    if Compat.InChatLockdown() then
        return "Blizzard blocks addon chat during raid encounters, Mythic+ and rated PvP"
    end
    if ns.IsInstanceSuppressed() then
        return "ToA is standing down in this instance (\"Disable inside instances\")"
    end
    return nil
end

local function deliver(body)
    if Casts.BlockedReason() then
        showLocally(body)
        return false
    end
    ns.RawSend(body, "EMOTE")
    return true
end

-- Roll for, render and speak a phrase for one cast. Returns the line if
-- something was said.
function Casts.Speak(spellName, opts)
    opts = opts or {}
    local c = castDB()
    if not c then return nil end
    local key = Casts.NoteSpellName(spellName)
    if not key then return nil end

    local phrases = Casts.GetPhrases(key)
    if #phrases == 0 then return nil end

    local ctx = buildContext(spellName)
    -- Drop phrases this cast can't fill in before rolling, so a pet line in the
    -- list doesn't eat the roll while your pet is dismissed.
    local usable = {}
    for _, p in ipairs(phrases) do
        if p.weight > 0 and substitute(p.text, ctx) then usable[#usable + 1] = p end
    end
    if #usable == 0 then return nil end

    local chosen = weightedPick(usable)
    if not chosen then return nil end

    local body, langId, spoken = Casts.Render(chosen.text, ctx, true)
    if not body then return nil end

    local now = GetTime and GetTime() or 0
    lastSpoken = now
    lastByKey[key] = now

    if deliver(body) and langId and spoken then
        -- Let grouped ToA users in on what the spoken part means, the same way
        -- translated chat does. Nothing to send when only an accent touched it.
        for _, pair in ipairs(spoken) do
            ns.BroadcastSpeech(pair.original, pair.encoded, langId, "EMOTE")
        end
    end
    return body
end

-- The gate in front of Casts.Speak: enabled, not muted, past both throttles,
-- and then the dice. Ordered so a failed roll doesn't start a cooldown -- only
-- a line that actually gets spoken does.
local function shouldSpeak(key)
    local c = castDB()
    if not (c and c.enabled) then return false end
    if not key or Casts.IsMuted(key) then return false end

    local now = GetTime and GetTime() or 0
    if lastSpoken > 0 and (now - lastSpoken) < (c.gap or 20) then return false end
    local seen = lastByKey[key]
    if seen and (now - seen) < (c.spellGap or 60) then return false end

    local chance = tonumber(c.chance) or 35
    if chance <= 0 then return false end
    if chance < 100 and math.random(100) > chance then return false end
    return true
end

--=========================================================================--
--  Cast events
--=========================================================================--
-- Your own casts and your pet's are explicitly exempt from Midnight's secret
-- values -- Blizzard relaxed UNIT_SPELLCAST for player-controlled units -- so
-- the spell id here is a plain number we can look up. Every other unit's may be
-- secret, which is why the handler refuses anything that isn't player or pet
-- before it touches the id.
local function onCast(unit, spellID)
    if unit ~= "player" and unit ~= "pet" then return end
    if ns.IsSecret(spellID) then return end
    if type(spellID) ~= "number" then return end

    local c = castDB()
    if not (c and c.enabled) then return end
    if unit == "pet" and not c.pets then return end

    local name = Compat.GetSpellInfo(spellID)
    if not name then return end
    local key = Casts.NoteSpellName(name)
    if not shouldSpeak(key) then return end
    Casts.Speak(name)
end

local frame = CreateFrame("Frame")
-- RegisterUnitEvent keeps every other unit's casts out of our handler entirely,
-- which on Midnight means we never even receive a secret spell id. Absent on
-- the oldest clients, where we filter on the unit argument instead.
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
else
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
    onCast(unit, spellID)
end)

--=========================================================================--
--  Preview (options panel)
--=========================================================================--
-- Shows what a phrase would look like, using your real pet and target when
-- they're there and stand-ins when they aren't, so a phrase can be written and
-- checked while standing in a city with nothing selected.
function Casts.Preview(template, spellName)
    local ctx = buildContext(spellName or "Immolate")
    ctx.spell = ctx.spell or "Immolate"
    ctx.pet = ctx.pet or "Felhunter"
    ctx.family = ctx.family or "Felhunter"
    ctx.target = ctx.target or "Hogger"

    local body = Casts.Render(template, ctx, false)
    if not body then return nil end
    local me = UnitName("player")
    if type(me) ~= "string" then me = "You" end
    local ok, line = pcall(string.format, CHAT_EMOTE_GET or "%s ", me)
    if not ok then line = me .. " " end
    return line .. body
end

--=========================================================================--
--  Resolving the spell under the mouse (keybinding)
--=========================================================================--
-- The binding in Bindings.xml opens a spell's phrase list straight from the
-- action bar or spellbook. Action buttons are found by asking for their action
-- slot (GetPagedID accounts for bar paging; ActionButton_CalculateAction is the
-- older equivalent) and spellbook buttons by the spell id they carry. Addon
-- bars that copy Blizzard's button layout fall out of this for free; ones that
-- don't simply won't resolve, and the binding then just opens the panel.
local function spellFromButton(btn)
    if type(btn) ~= "table" then return nil end

    -- Action slot -> whatever is in it. Macros are followed to the spell they
    -- cast, which is how a /cast macro on your bar still resolves.
    local slot
    if type(btn.GetPagedID) == "function" then
        local ok, id = pcall(btn.GetPagedID, btn)
        if ok then slot = id end
    end
    if not slot and type(btn.action) == "number" then
        slot = btn.action
    end
    if not slot and type(ActionButton_CalculateAction) == "function" then
        local ok, id = pcall(ActionButton_CalculateAction, btn)
        if ok then slot = id end
    end
    if type(slot) == "number" and slot > 0 and type(GetActionInfo) == "function" then
        local ok, actionType, id = pcall(GetActionInfo, slot)
        if ok and actionType == "spell" and type(id) == "number" and id > 0 then
            return id
        end
        if ok and actionType == "macro" and type(GetMacroSpell) == "function" then
            local ok2, spellID = pcall(GetMacroSpell, id)
            if ok2 and type(spellID) == "number" and spellID > 0 then return spellID end
        end
    end

    -- Spellbook and flyout buttons hang the id off the button itself; the
    -- attribute is the secure-template spelling of the same thing.
    for _, field in ipairs({ "spellID", "spellId" }) do
        if type(btn[field]) == "number" and btn[field] > 0 then return btn[field] end
    end
    if type(btn.GetAttribute) == "function" then
        local ok, value = pcall(btn.GetAttribute, btn, "spell")
        if ok then
            local id = tonumber(value)
            if id and id > 0 then return id end
            -- Some templates carry a name rather than an id.
            if type(value) == "string" and value ~= "" then return nil, value end
        end
    end
    return nil
end

-- The spell name under the cursor, or nil. Walks the mouse focus stack and then
-- up each region's parents, because the thing actually under the pointer is
-- usually a texture or the cooldown frame rather than the button.
function Casts.SpellUnderMouse()
    local foci
    if type(GetMouseFoci) == "function" then
        foci = GetMouseFoci()
    elseif type(GetMouseFocus) == "function" then
        foci = { GetMouseFocus() }
    end
    if type(foci) ~= "table" then return nil end

    for _, region in ipairs(foci) do
        local node, depth = region, 0
        while node and depth < 6 do
            local id, name = spellFromButton(node)
            if id then
                local spellName = Compat.GetSpellInfo(id)
                if spellName then return spellName, id end
            elseif name then
                return name, nil
            end
            node = type(node.GetParent) == "function" and node:GetParent() or nil
            depth = depth + 1
        end
    end
    return nil
end

-- Bound in Bindings.xml. Opens the phrase list for whatever is under the
-- cursor, or the panel itself if that's nothing recognizable.
function Casts.OpenUnderMouse()
    local name = Casts.SpellUnderMouse()
    if name then
        Casts.NoteSpellName(name)
        if ns.OpenCastConfig then ns.OpenCastConfig(Casts.Key(name)) end
        return name
    end
    if ns.OpenCastConfig then ns.OpenCastConfig() end
    return nil
end

-- The Key Bindings window reads these three globals: two for the labels it
-- shows, one for the binding body in Bindings.xml to call. New globals of our
-- own, not replacements for Blizzard's, so none of this can taint anything.
_G.BINDING_HEADER_TONGUESOFAZEROTH = "Tongues of Azeroth"
_G.BINDING_NAME_TONGUESOFAZEROTH_CASTPHRASES = "Cast phrases for the spell under the cursor"

function _G.TonguesOfAzeroth_OpenCastPhrases()
    Casts.OpenUnderMouse()
end
