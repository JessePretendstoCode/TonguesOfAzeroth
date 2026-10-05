local ADDON, ns = ...

--=========================================================================--
--  Names.lua -- player names that survive translation
--=========================================================================--
-- Proper nouns don't translate between real languages, and a listener who sees
-- their own name in a wall of Demonic knows they are being addressed. So a name
-- is protected exactly the way chat markup is: stashed behind a sentinel before
-- the word pass, and put back after it (see protectSegments in Language.lua).
--
-- There is no API that lists the players around you, and there never has been.
-- Addons that highlight names in chat are matching typed words against a list
-- they assembled from elsewhere, and so does this. The sources, in descending
-- order of how far they can be trusted:
--
--   1. People who spoke near you. SAY, EMOTE and YELL are proximity-filtered by
--      the server before they ever reach the client, carry the sender as a plain
--      string, and already pass through the addon's chat filter. That makes it
--      both the most accurate proximity list available and the cheapest one --
--      anyone you are actually roleplaying with has spoken.
--   2. Rosters: your group, your guild, your friends. Plain strings, no limits.
--   3. Whoever you target or mouse over, as you interact with them.
--   4. Nameplates, the only true proximity scan and also the weakest source:
--      friendly nameplates are off by default, so for most players it returns
--      nothing, and it is the one place Midnight's secret values can bite.
--
-- The hard part is not finding names, it is NOT protecting the wrong word. RP
-- names come from the same well as English: Grim, Light, Raven, Storm, Hope. If
-- someone named Well is standing nearby and "well" stops translating, the bug is
-- invisible -- the speech looks fine, it just has an English word sitting in the
-- middle of it. Every guard below exists for that failure rather than this one.

local Names = {}
ns.Names = Names

-- Matches Core.lua's probe. Names.lua loads first, so ns.IsSecret isn't defined
-- yet at this point; capture the global the same way instead of reaching for it.
local _issecretvalue = issecretvalue
local function isSecret(v)
    return _issecretvalue ~= nil and _issecretvalue(v) == true
end

local PERMANENT = math.huge

-- A name you saw once shouldn't protect that word forever: you pass hundreds of
-- players in a capital city, and every one of them is a word you have quietly
-- stopped being able to say. Sighted names age out; the people who are actually
-- yours (you, your pet, your group) don't.
local SEEN_TTL   = 20 * 60
local ROSTER_TTL = 60 * 60

-- Two letters is a legal character name and far too collision-prone to match on.
local MIN_LEN = 3

-- Above this many remembered names, prune the expired ones. Purely a ceiling on
-- table growth; matching is a hash lookup and doesn't care how full this is.
local MAX_KNOWN = 400

-- key (lower case) -> expiry timestamp, or PERMANENT
local known = {}
-- key -> the name as it is actually spelled, for `/glyphic names`
local display = {}
-- key -> class token ("MAGE"), when we happen to find out. Only ever used to
-- pick a color, so it is entirely optional: the best source of names is people
-- talking near you, and a chat line doesn't always say who is speaking beyond
-- the name. Names with no class fall back to a fixed color.
local classes = {}
local knownCount = 0

local function now()
    return (GetTime and GetTime()) or 0
end

-- Words that are common enough in ordinary speech that having one silently stop
-- translating is worse than failing to protect someone's name. A name only has
-- to survive a sentence; an English word that refuses to translate breaks the
-- illusion every time it is used.
local STOPLIST = {}
for word in ([[
a an and the but for nor or so yet if then than that this these those
i me my we us our you your he him his she her it its they them their
is are was were be been being am do does did done have has had
can could will would shall should may might must
all any both each few more most no none not one only other own same some such
two three ten first last next new old good great long little big small high low
here there when where why how what which who whom whose
up down in out on off over under again once very just now then still even
day night morning evening time year way thing man men woman women people
life death blood bone flesh heart soul mind hand head eye face voice word words
home house door gate road path city town land world realm north south east west
war peace blood battle blade sword shield armor armour arrow bow spear axe
light dark darkness shadow fire flame frost ice storm wind rain snow sun moon
star stars sky sea water earth stone iron steel gold silver ash dust smoke
hope fear love hate rage fury grace mercy faith doubt pain joy sorrow
king queen lord lady sir prince duke master mistress friend brother sister
father mother son daughter child children blood kin clan tribe house order
well will may art can go see say come take give know think look want need
]]):gmatch("%S+") do
    STOPLIST[word] = true
end

--=========================================================================--
--  Reading a name off a unit token, safely
--=========================================================================--
-- This is the only place a secret value can enter. Midnight restricts unit
-- identity for anything that isn't player-controlled or in your party/raid, and
-- since 12.1.0 for players in PvP as well. A secret string throws the instant it
-- is compared or concatenated, which is precisely what matching a name does, so
-- it has to be tested before it is touched at all.
--
-- The class comes back from the same call for the same reason: UnitClass is
-- marked conditionally secret on exactly the units UnitName is, so reading it
-- anywhere else would mean writing this guard twice.
local function unitIdentity(unit)
    if not (unit and UnitName) then return nil end
    local ok, name, class = pcall(function()
        if UnitExists and not UnitExists(unit) then return nil end
        if UnitIsPlayer and not UnitIsPlayer(unit) then return nil end
        local n = UnitName(unit)
        if not UnitClass then return n end
        return n, select(2, UnitClass(unit))
    end)
    if not ok or name == nil then return nil end
    if isSecret(name) then return nil end
    if type(name) ~= "string" then return nil end
    -- A secret class is simply no class: the name is still worth having, it
    -- just gets the fallback color.
    if isSecret(class) or type(class) ~= "string" then class = nil end
    return name, class
end

-- Rather than reason about identity restriction unit by unit, don't scan where
-- it applies. Nothing is lost by it: chat keeps feeding the list either way, and
-- combat and instances are where you are least likely to be addressing someone
-- by name in character.
local function unitScanAllowed()
    if InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance then
        local ok, inInstance = pcall(IsInInstance)
        if ok and inInstance then return false end
    end
    return true
end

--=========================================================================--
--  The list
--=========================================================================--
local function prune()
    local t = now()
    for key, expiry in pairs(known) do
        if expiry ~= PERMANENT and expiry < t then
            known[key] = nil
            display[key] = nil
            classes[key] = nil
            knownCount = knownCount - 1
        end
    end
end

-- Class tokens are upper-case ASCII ("MAGE", "DEATHKNIGHT"). Anything else is
-- either a localized label that hasn't been mapped back yet or a value from a
-- client that returns something unexpected, and both are better dropped than
-- stored: an unknown token just produces no color.
local function validClass(class)
    if isSecret(class) then return nil end
    if type(class) ~= "string" then return nil end
    return class:match("^%u[%u_]*$")
end

-- Remember a name. `ttl` nil means permanent (you, your pet, your group).
-- `class` is optional and only ever decides a color. Returns true if the name
-- is now on the list.
function Names.Note(name, ttl, class)
    -- Secrecy is tested before anything else, including `name == ""`: comparing
    -- a secret throws just as hard as concatenating one, so the check cannot sit
    -- behind even a cheap-looking guard. Callers already screen for this, and it
    -- is still checked here, because the cost is one call and the failure mode is
    -- a hard Lua error in the middle of someone's sentence.
    if isSecret(name) then return false end
    if type(name) ~= "string" or name == "" then return false end
    -- Cross-realm arrives as "Corvin-ArgentDawn"; the short form is what anyone
    -- actually types, so that is what has to match.
    name = name:match("^([^%-]+)") or name
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if #name < MIN_LEN then return false end

    local key = name:lower()
    if STOPLIST[key] then return false end

    local expiry = ttl and (now() + ttl) or PERMANENT
    local current = known[key]
    if current == nil then
        knownCount = knownCount + 1
        if knownCount > MAX_KNOWN then prune() end
        known[key] = expiry
        display[key] = name
    elseif current == PERMANENT then
        -- never demote a permanent entry
    elseif expiry == PERMANENT or current < expiry then
        known[key] = expiry
        display[key] = name
    end

    -- Set last, and outside those branches, because a name already on the list
    -- is exactly when a class turns up: you meet someone in chat, and learn
    -- what they are the day you group with them.
    class = validClass(class)
    if class then classes[key] = class end
    return true
end

function Names.NoteUnit(unit, ttl)
    local name, class = unitIdentity(unit)
    if not name then return false end
    return Names.Note(name, ttl or SEEN_TTL, class)
end

function Names.Forget(name)
    if type(name) ~= "string" then return false end
    local key = name:lower()
    if known[key] == nil then return false end
    known[key] = nil
    display[key] = nil
    classes[key] = nil
    knownCount = knownCount - 1
    return true
end

function Names.Clear()
    known, display, classes, knownCount = {}, {}, {}, 0
end

function Names.IsEnabled()
    local db = GlyphicDB
    return not (db and db.protectNames == false)
end

function Names.SetEnabled(on)
    local db = GlyphicDB
    if db then db.protectNames = on and true or false end
end

-- Is this token, exactly as it was typed, a name we should leave alone?
function Names.IsProtected(token)
    if type(token) ~= "string" or #token < MIN_LEN then return false end
    -- Capitalisation is the single most effective guard here. Lower-case "light"
    -- is the noun; "Light" might be the paladin standing next to you. It costs a
    -- name typed in lower case, which reads as a common noun anyway.
    if not token:sub(1, 1):match("%u") then return false end

    local key = token:lower()
    if STOPLIST[key] then return false end

    local expiry = known[key]
    if expiry == nil then return false end
    if expiry ~= PERMANENT and expiry < now() then
        known[key] = nil
        display[key] = nil
        classes[key] = nil
        knownCount = knownCount - 1
        return false
    end
    return true
end

-- The class token remembered for a name, or nil. Only a color depends on this.
function Names.ClassOf(name)
    if type(name) ~= "string" then return nil end
    return classes[name:lower()]
end

-- Letters plus the high bytes of a UTF-8 name, so an accented name matches whole
-- rather than being split into an unprotected head and a protected tail.
local NAME_TOKEN = "[%a\128-\255][%a\128-\255]*"

-- Replace every protected name with a sentinel from `stash`, the same callback
-- the markup protection uses. Called from Language.protectSegments.
function Names.Stash(text, stash)
    if not text or text == "" or type(stash) ~= "function" then return text end
    if not Names.IsEnabled() then return text end
    if knownCount == 0 then return text end
    -- Returning nil from a gsub callback leaves the match as it was, so only the
    -- names actually get replaced.
    local out = text:gsub(NAME_TOKEN, function(token)
        if Names.IsProtected(token) then return stash(token) end
        return nil
    end)
    return out
end

--=========================================================================--
--  Showing which words were left alone
--=========================================================================--
-- A protected name in a wall of Demonic is readable, but so is a word the
-- fluency roll happened to leave in English, and from the outside they look
-- identical. Coloring the names says which is which.
--
-- Like the rest of the palette this happens when a line is DISPLAYED, never
-- when it is sent (see the header of Colors.lua). Each client paints its own
-- chat from its own list, so the text on the wire stays clean, nobody is handed
-- markup they didn't ask for, and none of it eats into the 255-character
-- budget that the outgoing text is already being trimmed to fit.
function Names.HighlightEnabled()
    local db = GlyphicDB
    return not (db and db.colorNames == false)
end

function Names.SetHighlightEnabled(on)
    local db = GlyphicDB
    if db then db.colorNames = on and true or false end
end

-- Class color when the class is known, a fixed color when it isn't -- which is
-- the common case, so the fallback is the one that has to look deliberate.
function Names.ColorFor(name)
    local Colors = ns.Colors
    if not Colors then return nil end
    local class = Names.ClassOf(name)
    return (class and Colors.ClassHex(class)) or Colors.NameHex()
end

-- Run `fn` over the parts of a line that are ordinary text, handing hyperlinks
-- through untouched.
--
-- Color escapes don't need this and aren't given it: they are "|cffRRGGBB" and
-- "|r", so a name token starting inside one begins at the lower-case c or r,
-- and IsProtected wants an upper-case first letter. A hyperlink is a different
-- matter -- "|Hplayer:Corvin|h[Corvin]|h" carries the name in its target, and a
-- color inserted there breaks the link instead of painting it.
local function outsideLinks(text, fn)
    local out, pos = {}, 1
    while true do
        local s, e = text:find("|H.-|h.-|h", pos)
        if not s then break end
        out[#out + 1] = fn(text:sub(pos, s - 1))
        out[#out + 1] = text:sub(s, e)
        pos = e + 1
    end
    out[#out + 1] = fn(text:sub(pos))
    return table.concat(out)
end

function Names.Highlight(text)
    if type(text) ~= "string" or text == "" then return text end
    if not (Names.IsEnabled() and Names.HighlightEnabled()) then return text end
    if knownCount == 0 then return text end
    local Colors = ns.Colors
    if not Colors then return text end

    return outsideLinks(text, function(chunk)
        return (chunk:gsub(NAME_TOKEN, function(token)
            if not Names.IsProtected(token) then return nil end
            return Colors.Wrap(token, Names.ColorFor(token))
        end))
    end)
end

--=========================================================================--
--  Collecting names
--=========================================================================--
-- Chat is the good source, so it gets the whole sentence of explanation in the
-- header rather than here. Core's chat filter calls this for the types where the
-- sender is someone you are talking to, and not for public channels -- Trade and
-- General would pour hundreds of strangers into the list, every one of them a
-- word you might have wanted to say.
--
-- `guid` is optional and is the only thing a chat line offers beyond the name,
-- so it is also the only way a name learned from chat -- the majority of them --
-- can ever get a class color.
function Names.NoteSpeaker(sender, guid)
    local class
    -- The "Player-" test is doing double duty. It rejects creature and pet
    -- GUIDs, and it means that if the caller ever hands us the wrong vararg the
    -- cost is a missing color rather than a wrong one.
    if not isSecret(guid) and type(guid) == "string"
        and guid:find("^Player%-") and GetPlayerInfoByGUID then
        local ok, _, englishClass = pcall(GetPlayerInfoByGUID, guid)
        if ok then class = englishClass end
    end
    return Names.Note(sender, SEEN_TTL, class)
end

function Names.RefreshRoster()
    local me, myClass = unitIdentity("player")
    if me then Names.Note(me, nil, myClass) end
    local pet = unitIdentity("pet")
    if pet then Names.Note(pet) end
    -- Pets aren't players, so unitIdentity's UnitIsPlayer check rejects them. Ask
    -- directly; your own pet's name is never secret.
    if not pet and UnitName then
        local ok, petName = pcall(UnitName, "pet")
        if ok and type(petName) == "string" and not isSecret(petName) then
            Names.Note(petName)
        end
    end

    local Compat = ns.Compat
    local count = (GetNumGroupMembers and GetNumGroupMembers())
        or (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local inRaid = Compat and Compat.InRaid and Compat.InRaid()
    local prefix = inRaid and "raid" or "party"
    for i = 1, count do
        local name, class = unitIdentity(prefix .. i)
        if name then Names.Note(name, nil, class) end
    end
end

function Names.RefreshGuild()
    if not (IsInGuild and IsInGuild()) then return 0 end
    if not (GetNumGuildMembers and GetGuildRosterInfo) then return 0 end
    local ok, total = pcall(GetNumGuildMembers)
    if not ok or type(total) ~= "number" then return 0 end
    local added = 0
    for i = 1, total do
        -- The class token is GetGuildRosterInfo's eleventh return; the fifth is
        -- the localized label, which is not what the color tables are keyed by.
        local gotName, name, _, _, _, _, _, _, _, _, _, class = pcall(GetGuildRosterInfo, i)
        if gotName and type(name) == "string" and Names.Note(name, ROSTER_TTL, class) then
            added = added + 1
        end
    end
    return added
end

-- The friends list reports a class the way it shows it to you ("Mage"), not the
-- token the color tables use ("MAGE"). The client's own localisation tables are
-- the only way back, and they don't exist until it is up, so the reverse map is
-- built on first use instead of at load.
local localizedClass
local function classFromLocalized(label)
    if isSecret(label) then return nil end
    if type(label) ~= "string" or label == "" then return nil end
    if not localizedClass then
        localizedClass = {}
        local function absorb(t)
            if type(t) ~= "table" then return end
            for token, name in pairs(t) do
                if type(token) == "string" and type(name) == "string" then
                    localizedClass[name:lower()] = token
                end
            end
        end
        absorb(_G.LOCALIZED_CLASS_NAMES_MALE)
        absorb(_G.LOCALIZED_CLASS_NAMES_FEMALE)
    end
    return localizedClass[label:lower()]
end

function Names.RefreshFriends()
    local added = 0
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local ok, total = pcall(C_FriendList.GetNumFriends)
        if ok and type(total) == "number" then
            for i = 1, total do
                local gotInfo, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
                local class = gotInfo and type(info) == "table"
                    and classFromLocalized(info.className) or nil
                if gotInfo and type(info) == "table"
                    and Names.Note(info.name, ROSTER_TTL, class) then
                    added = added + 1
                end
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        local ok, total = pcall(GetNumFriends)
        if ok and type(total) == "number" then
            for i = 1, total do
                local gotName, name, _, class = pcall(GetFriendInfo, i)
                if gotName and Names.Note(name, ROSTER_TTL, classFromLocalized(class)) then
                    added = added + 1
                end
            end
        end
    end
    return added
end

function Names.ScanNameplates()
    if not unitScanAllowed() then return 0 end
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return 0 end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return 0 end
    local added = 0
    for _, plate in ipairs(plates) do
        local unit = type(plate) == "table" and plate.namePlateUnitToken or nil
        if unit and Names.NoteUnit(unit) then added = added + 1 end
    end
    return added
end

-- Sorted list of what is currently remembered, for `/glyphic names`.
function Names.List()
    prune()
    local out = {}
    for key in pairs(known) do out[#out + 1] = display[key] or key end
    table.sort(out)
    return out
end

function Names.Count()
    return knownCount
end

--=========================================================================--
--  Events
--=========================================================================--
-- Its own frame rather than a branch in Core's: everything here is bookkeeping
-- for one list, and none of it has anything to say about the chat pipeline.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("UNIT_PET")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        Names.RefreshRoster()
        Names.RefreshFriends()
        -- The guild roster is usually not loaded yet at login; the request comes
        -- back as GUILD_ROSTER_UPDATE, which is handled below.
        if C_GuildInfo and C_GuildInfo.GuildRoster then
            pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then
            pcall(GuildRoster)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if unitScanAllowed() then Names.NoteUnit("target") end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if unitScanAllowed() then Names.NoteUnit("mouseover") end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        Names.RefreshRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        Names.RefreshGuild()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if unitScanAllowed() then Names.NoteUnit(arg1) end
    end
end)
