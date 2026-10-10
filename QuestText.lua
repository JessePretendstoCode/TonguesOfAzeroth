--[[-------------------------------------------------------------------------
    Glyphic - QuestText.lua
    Full immersion for the quest and dialogue UI.

    Chat and quest text are the same idea in two very different situations.

    A chat line arrives stamped with a numeric language, and the client has
    already decided whether you understood it -- so immersion there can only
    take away what the game had granted, and the garbled text it produces is
    the text the game itself would have shown.

    Quest text, gossip and the objective tracker carry no language at all.
    Blizzard never garbles them: when a quest has somebody speaking Orcish,
    the nonsense is typed into the quest by hand. So there is nothing here
    that was hidden from you, which means two things this file has to own.

    Which tongue is this in? Nobody says, so we ask who is talking -- the
    NPC's race where the game knows it, their faction otherwise. A quest you
    already accepted has no NPC left to ask, so the tongue is remembered at
    the moment it was offered and read back from the journal afterwards.

    And if there is no record -- a quest taken before this was switched on, or
    shared to you by somebody in your party -- the journal and the tracker
    leave it in plain English. There is no API that will tell you who gave you
    a quest after the fact, and the obvious guess (your own faction's tongue)
    is the worst one available: it puts Orcish in front of a Horde player for
    every quest in their log, tauren ones included.

    Nobody talking means nothing hidden. A quest you start by right-clicking
    something in your bags, or by walking into a place, or off a bulletin
    board, has no speaker -- so it is left in plain English rather than being
    handed the accent of whoever you happened to talk to last.

    How far does it go? Everything the NPC says to you: the greeting, the
    offer, its title, the objectives, the progress and the thanks, and the
    gossip window. Not the buttons -- Accept still says Accept, and still
    works, because not understanding somebody has never stopped anyone
    agreeing to fetch ten boar livers.

    The journal and the clickable gossip list sit behind switches of their
    own, because they are not prose. Everything above is a story you can be
    shut out of and lose nothing but the story; those two are what you
    operate the game with, and hiding them stops being flavour and starts
    being a difficulty setting.

    The journal switch covers the whole page: the objectives, the checklist,
    the tracker, and the titles down the side. The titles were held back from
    it once, on the grounds that a title is your own shorthand for a job you
    already took rather than anything the giver said. That held while the
    prose was the only thing hidden. It stops holding once the page itself is
    the point, and a list of plain English titles sitting over garbled
    objectives reads as the feature half working rather than as a decision.
    Zone headers stay readable either way: a header is the client sorting
    your log, not a thing anybody wrote.
---------------------------------------------------------------------------]]

local _, ns = ...

local QuestText = {}
ns.QuestText = QuestText

--=========================================================================--
--  Who is talking, and in what
--=========================================================================--
-- UnitRace's second return is the locale-independent file name ("NightElf",
-- "Scourge"), which is why the match is on that and not on the display name.
-- Allied races speak their parent tongue: a Nightborne is listed under
-- Thalassian because Shalassian is a dialect of it and Blizzard gives them no
-- word table of their own.
local RACE_LANGUAGE = {
    human = 7, kultiran = 7,
    dwarf = 6, darkirondwarf = 6, earthen = 6, earthendwarf = 6,
    gnome = 13, mechagnome = 13,
    nightelf = 2,
    draenei = 35, lightforgeddraenei = 35,
    worgen = 39,
    orc = 1, magharorc = 1, vulpera = 1,
    tauren = 3, highmountaintauren = 3,
    troll = 14, zandalaritroll = 14,
    scourge = 33, undead = 33, forsaken = 33,
    bloodelf = 10, voidelf = 10, nightborne = 10,
    goblin = 40,
    pandaren = 42,
    dracthyr = 11,
}
QuestText.RACE_LANGUAGE = RACE_LANGUAGE

-- Kept, but read the warning: UnitRace answers for players and returns nil for
-- every creature in the game. Race is a character property; an NPC has a
-- display and a creature type instead. So in practice nothing below is reached
-- for a quest giver, and every one of them lands on their faction. Two rounds
-- of widening this table did nothing for exactly that reason.
--
-- Ordered, and the order is the point: the first needle that appears anywhere
-- in the race file wins, so compounds have to be checked before the family
-- word they contain. "Elf" on its own is deliberately absent, because it
-- cannot tell Darnassian from Thalassian and a wrong tongue is worse than the
-- faction's.
local RACE_PATTERNS = {
    { "nightelf", 2 },   { "bloodelf", 10 },  { "voidelf", 10 },
    { "highelf", 10 },   { "nightborne", 10 }, { "sanlayn", 10 },
    { "highmountain", 3 }, { "tauren", 3 },   { "yaungol", 3 },
    { "darkspear", 14 }, { "zandalari", 14 }, { "troll", 14 },
    { "draenei", 35 },   { "broken", 35 },    { "eredar", 8 },
    { "darkiron", 6 },   { "earthen", 6 },    { "dwarf", 6 },
    { "mechagnome", 13 }, { "gnome", 13 },
    { "maghar", 1 },     { "vulpera", 1 },    { "orc", 1 },
    { "forsaken", 33 },  { "scourge", 33 },   { "undead", 33 },
    { "kultiran", 7 },   { "human", 7 },
    { "worgen", 39 },    { "goblin", 40 },    { "pandaren", 42 },
    { "dracthyr", 11 },  { "dragonspawn", 11 }, { "drakonid", 11 },
    { "furbolg", 303 },
}
QuestText.RACE_PATTERNS = RACE_PATTERNS

--=========================================================================--
--  What an NPC *does* tell you
--=========================================================================--
-- Its reputation faction, on the third line of its tooltip: "Thunder Bluff"
-- under a tauren, "Darkspear Trolls" under a troll, "Bilgewater Cartel" under
-- a goblin. Not a race, but a far better proxy than anything else on offer --
-- a Thunder Bluff quest giver is a tauren essentially every time, and unlike
-- the zone it is still right for the lone tauren standing in the Barrens.
--
-- Keyed by faction id rather than by name so the matching survives a German
-- client: the id is fixed, and the client is asked for its own localized name
-- at runtime. Every one of these was checked against Blizzard's faction list
-- rather than recalled.
local FACTION_TONGUE = {
    [47]   = 6,    -- Ironforge
    [54]   = 13,   -- Gnomeregan Exiles
    [68]   = 33,   -- Undercity
    [69]   = 2,    -- Darnassus
    [72]   = 7,    -- Stormwind
    [76]   = 1,    -- Orgrimmar
    [81]   = 3,    -- Thunder Bluff
    [530]  = 14,   -- Darkspear Trolls
    [911]  = 10,   -- Silvermoon City
    [922]  = 10,   -- Tranquillien
    [930]  = 35,   -- Exodar
    [1133] = 40,   -- Bilgewater Cartel
    [1134] = 39,   -- Gilneas
    [21]   = 40,   -- Booty Bay (Steamwheedle, and goblins to a one)
    [59]   = 6,    -- Thorium Brotherhood
    [576]  = 303,  -- Timbermaw Hold
}

-- The same answers in English, for any client that will not hand over a
-- faction's localized name. Lowercased at build time.
local FACTION_TONGUE_BY_NAME = {
    ["ironforge"] = 6, ["gnomeregan"] = 13, ["gnomeregan exiles"] = 13,
    ["undercity"] = 33, ["darnassus"] = 2, ["stormwind"] = 7,
    ["orgrimmar"] = 1, ["thunder bluff"] = 3, ["darkspear trolls"] = 14,
    ["silvermoon city"] = 10, ["tranquillien"] = 10, ["exodar"] = 35,
    ["the exodar"] = 35, ["bilgewater cartel"] = 40, ["gilneas"] = 39,
    ["booty bay"] = 40, ["thorium brotherhood"] = 6, ["timbermaw hold"] = 303,
}

-- Where you are, for the NPCs with no reputation faction at all. Weaker than
-- the faction -- it cannot tell the goblin in the Barrens from the orc beside
-- him -- but in a racial homeland it is right about nearly everyone, and the
-- homelands are where this matters most.
--
-- The two id sets are not the same map numbered twice: Classic calls Durotar
-- 1411 and the modern client calls it 1, so both are listed and the flavour
-- decides which is consulted. Merging them would have the modern Orgrimmar
-- (85) collide with whatever Classic numbers 85.
local ZONE_TONGUE_CLASSIC = {
    [1411] = 1,  [1412] = 3,  [1420] = 33, [1421] = 33,
    [1426] = 6,  [1429] = 7,  [1438] = 2,  [1439] = 2,
    [1941] = 10, [1942] = 10, [1943] = 35, [1950] = 35,
    [1947] = 35, [1954] = 10,
}
local ZONE_TONGUE_MODERN = {
    [1]  = 1,  [7]  = 3,  [18] = 33, [21] = 33,
    [27] = 6,  [37] = 7,  [57] = 2,  [62] = 2,
    [94] = 10, [95] = 10, [97] = 35,
    [85] = 1,  [88] = 3,  [89] = 2,
}

local FACTION_LANGUAGE = { Horde = 1, Alliance = 7 }

-- The tongue you are addressed in when nothing better is known. Neutral and
-- unidentifiable NPCs are talking *to you*, so they reach for yours.
function QuestText.PlayerLanguage()
    if type(UnitFactionGroup) == "function" then
        local faction = UnitFactionGroup("player")
        if FACTION_LANGUAGE[faction] then return FACTION_LANGUAGE[faction] end
    end
    return 7
end

-- Most quest givers are creatures rather than player races, and UnitRace has
-- nothing to say about a wisp or a talking crate. Faction answers for those,
-- and the player's own tongue answers for the rest -- a guess, but the only
-- honest one available, and stated as a guess rather than dressed up.
-- The race file the client reports for a unit, lowercased, or nil. Separate
-- from the lookup so the diagnostic can show what the client said even when
-- nothing was made of it.
function QuestText.RaceFile(unit)
    if type(UnitRace) ~= "function" then return nil end
    local ok, display, file = pcall(UnitRace, unit)
    if not ok then return nil end
    if type(file) ~= "string" or file == "" then
        -- Some NPCs answer with a display name and nothing else. It is
        -- localized, so it only helps on an English client -- but on one it
        -- is the difference between Zandali and a shrug.
        file = type(display) == "string" and display or nil
    end
    if type(file) ~= "string" or file == "" then return nil end
    return (file:lower():gsub("[^%a]", ""))
end

-- The unit tooltip's text, which is the only place the reputation faction is
-- written down. Modern clients hand it over as data; the older ones have to be
-- asked for a tooltip and read back off it.
local scanner
function QuestText.TooltipLines(unit)
    local out = {}
    if C_TooltipInfo and type(C_TooltipInfo.GetUnit) == "function" then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for i = 1, #data.lines do
                local left = data.lines[i] and data.lines[i].leftText
                if type(left) == "string" then out[#out + 1] = left end
            end
            if #out > 0 then return out end
        end
    end
    if not scanner and type(CreateFrame) == "function" then
        local ok, frame = pcall(CreateFrame, "GameTooltip",
            "GlyphicUnitScanner", nil, "GameTooltipTemplate")
        if ok then scanner = frame end
    end
    if scanner and type(scanner.SetUnit) == "function" then
        pcall(scanner.SetOwner, scanner, UIParent, "ANCHOR_NONE")
        pcall(scanner.ClearLines, scanner)
        if pcall(scanner.SetUnit, scanner, unit) then
            local n = (scanner.NumLines and scanner:NumLines()) or 0
            for i = 1, n do
                local fs = _G["GlyphicUnitScannerTextLeft" .. i]
                local text = fs and fs.GetText and fs:GetText()
                if type(text) == "string" then out[#out + 1] = text end
            end
        end
        pcall(scanner.Hide, scanner)
    end
    return out
end

-- Built once, from ids, so a German client matches "Donnerfels" without this
-- file ever having heard the word.
local factionTongues
local function factionTongueByName()
    if factionTongues then return factionTongues end
    factionTongues = {}
    for id, tongue in pairs(FACTION_TONGUE) do
        local name
        if C_Reputation and type(C_Reputation.GetFactionDataByID) == "function" then
            local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
            if ok and type(data) == "table" then name = data.name end
        end
        if not name and type(GetFactionInfoByID) == "function" then
            local ok, n = pcall(GetFactionInfoByID, id)
            if ok then name = n end
        end
        if type(name) == "string" and name ~= "" then
            factionTongues[name:lower()] = tongue
        end
    end
    for name, tongue in pairs(FACTION_TONGUE_BY_NAME) do
        if factionTongues[name] == nil then factionTongues[name] = tongue end
    end
    return factionTongues
end

-- Dropped when the player logs in, so a faction whose name was not loaded yet
-- at file scope gets another chance.
function QuestText.ForgetFactionNames() factionTongues = nil end

function QuestText.FactionTongue(unit)
    local known = factionTongueByName()
    local lines = QuestText.TooltipLines(unit)
    for i = 1, #lines do
        local line = lines[i]:lower():gsub("^%s+", ""):gsub("%s+$", "")
        local tongue = known[line]
        if tongue then return tongue end
    end
    return nil
end

-- The racial homeland you are standing in, if it is one.
function QuestText.ZoneTongue()
    if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(id) ~= "number" then return nil end
    local Compat = ns.Compat
    local classic = Compat and Compat.hasProximityAddonMessages
    return (classic and ZONE_TONGUE_CLASSIC or ZONE_TONGUE_MODERN)[id]
end

function QuestText.LanguageForUnit(unit)
    if type(UnitExists) ~= "function" or not UnitExists(unit) then return nil end

    -- Who they answer to beats where they are standing, which beats which
    -- army they belong to. Each step is a weaker claim than the one above.
    local tongue = QuestText.FactionTongue(unit)
    if tongue then return tongue end

    local file = QuestText.RaceFile(unit)
    if file then
        local id = RACE_LANGUAGE[file]
        if id then return id end
        for i = 1, #RACE_PATTERNS do
            local needle, lang = RACE_PATTERNS[i][1], RACE_PATTERNS[i][2]
            if file:find(needle, 1, true) then return lang end
        end
    end
    tongue = QuestText.ZoneTongue()
    if tongue then return tongue end

    if type(UnitFactionGroup) == "function" then
        local faction = UnitFactionGroup(unit)
        if FACTION_LANGUAGE[faction] then return FACTION_LANGUAGE[faction] end
    end
    return QuestText.PlayerLanguage()
end

--=========================================================================--
--  Which tongue applies right now
--=========================================================================--
-- The NPC in front of you, while there is one. Quest and gossip frames are
-- open only while you are interacting, so this covers everything they show.
local currentLang = nil

-- { [questID] = blizzardLanguageID } for quests already accepted. The giver
-- is gone by the time the journal is read, and a quest that changes tongue
-- between the offer and the log reads as the feature misfiring rather than as
-- anything to do with who gave it to you.
local function questLangs()
    GlyphicDB = GlyphicDB or {}
    GlyphicDB.questLangs = GlyphicDB.questLangs or {}
    return GlyphicDB.questLangs
end

-- `false` is a real answer and not an absence: it means we watched this quest
-- being offered and there was nobody holding it out -- an item in your bags, a
-- bulletin board, walking into a place. That is different from never having
-- seen the quest at all, and the two are handled differently below.
function QuestText.RememberQuest(questID, blizzId)
    if type(questID) ~= "number" or questID <= 0 then return end
    if blizzId ~= false and type(blizzId) ~= "number" then return end
    questLangs()[questID] = blizzId
end

function QuestText.ForgetQuest(questID)
    if type(questID) ~= "number" then return end
    questLangs()[questID] = nil
end

-- For when the records are wrong rather than missing -- a tongue improved, a
-- race the table has only just learned about. Clearing them sends every quest
-- back to the faction guess, and the right one is written down again the next
-- time you stand in front of the giver.
function QuestText.ForgetAll()
    local n = 0
    for _ in pairs(questLangs()) do n = n + 1 end
    GlyphicDB.questLangs = {}
    QuestText.ClearCache()
    return n
end

-- Three answers, and the difference between the last two is the whole design:
--   a number -- we watched this quest being offered, in that tongue
--   false    -- we watched it being offered by nobody, so it has no tongue
--   nil      -- we never saw it offered and never will
function QuestText.LanguageForQuest(questID)
    if type(questID) ~= "number" or questID <= 0 then return nil end
    return questLangs()[questID]
end

-- What the journal and the tracker should read a quest in; nil to leave it be.
--
-- A quest nobody offered stays plain, because nobody said it. A quest we
-- simply never saw falls back to your own faction's tongue -- a guess, and
-- knowingly a wrong one for the tauren who actually handed it over, but the
-- alternative is a log that stays in English forever for everything you were
-- carrying the day you switched this on. Handing one in replaces the guess
-- with the truth, so the log corrects itself as you play.
function QuestText.JournalLanguage(questID)
    local known = QuestText.LanguageForQuest(questID)
    if type(known) == "number" then return known end
    if known == false then
        -- Nobody said it, so with only the prose hidden there is nothing to
        -- hide: a letter in your bags is a letter, and it is in whatever you
        -- read. But the journal switch means the written word itself is
        -- foreign, and a notice board in Darnassus is not written in English
        -- for your benefit. Without this, every quest off a board or an item
        -- stayed readable on Medium and Hard, beside garbled ones from the
        -- NPC standing next to it -- which reads as the feature misfiring.
        if not QuestText.TrackerActive() then return nil end
    end
    return QuestText.PlayerLanguage()
end

-- The untouched GetQuestLogTitle, kept from before the wrapper went on.
-- Garbling a title needs a quest id, and finding a quest id means reading the
-- title row -- so resolving the id through the global would call the wrapper
-- for every call, for ever. C_QuestLog.GetInfo needs no such care: it is
-- asked for the quest id, which its wrapper does not touch.
local rawQuestLogTitle

-- A row in the quest log is not a quest. The tracker and the journal both hand
-- out log indices, which shuffle whenever a quest is added or abandoned, so
-- nothing is remembered against one.
local function questIDForLogIndex(index)
    if type(index) ~= "number" or index <= 0 then return nil end
    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" and type(info.questID) == "number"
            and info.questID > 0 then
            return info.questID
        end
    end
    local getTitle = rawQuestLogTitle or GetQuestLogTitle
    if type(getTitle) == "function" then
        -- Every flavour that still has this returns the questID eighth, after
        -- title, level, suggestedGroup, isHeader, isCollapsed, isComplete and
        -- frequency. Trusting the slot beats scanning for "a number that looks
        -- like an id", which skips low-numbered classic quests and can pick up
        -- a level or a group size instead.
        local row = { getTitle(index) }
        if type(row[8]) == "number" and row[8] > 0 then return row[8] end
        for i = 1, #row do
            if type(row[i]) == "number" and row[i] > 100 then return row[i] end
        end
    end
    return nil
end

-- Whichever quest the journal is currently showing, across the API rename.
local function selectedQuestID()
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local ok, id = pcall(C_QuestLog.GetSelectedQuest)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if type(GetQuestLogSelection) == "function" then
        return questIDForLogIndex(GetQuestLogSelection())
    end
    return nil
end

--=========================================================================--
--  Garbling
--=========================================================================--
-- Three switches deep, and each one earns its place. Full immersion is the
-- decision to let this addon decide what you understand. The NPC switch widens
-- that from players to everything with a voice. This last one is separate
-- because it is the only part that hides text the game never hid -- a boss
-- callout in Orcish is a line the client would have garbled anyway, but a
-- quest never arrives with a tongue attached, so garbling one is this addon's
-- invention and nobody should get it without asking.
function QuestText.Active()
    local db = GlyphicDB
    return (db and db.fullImmersion and db.immersionNPCs and db.immersionQuests)
        and true or false
end

-- Two surfaces narrower than the rest, each behind its own switch.
--
-- They are split out because the three above are one decision -- "let the
-- addon decide what I understand" -- and these two are not. Everything under
-- Active() is prose: a story you can be shut out of and lose nothing but the
-- story. The tracker and the gossip list are the parts you operate the game
-- with, and hiding them stops being flavour and starts being a difficulty
-- setting. Something that changes how hard the game is to play should be
-- something you asked for by name.
--
-- Both narrow Active() rather than standing beside it, so neither can garble
-- anything while the parent switches are off. That also means the call sites
-- can lean on Garble's own Active() check, since these being true makes it
-- true.
function QuestText.TrackerActive()
    local db = GlyphicDB
    return (QuestText.Active() and db.immersionTracker) and true or false
end

function QuestText.OptionsActive()
    local db = GlyphicDB
    return (QuestText.Active() and db.immersionGossipOptions) and true or false
end

-- The tracker asks for the same objective text several times a second while
-- anything on screen is animating, and garbling is a hash per word. The answer
-- never changes for a given string and tongue, so it is worked out once.
local cache, cacheCount = {}, 0
local CACHE_LIMIT = 500

function QuestText.ClearCache()
    cache, cacheCount = {}, 0
end

function QuestText.Garble(text, blizzId)
    if type(text) ~= "string" or text == "" then return text end
    if not QuestText.Active() then return text end
    -- No tongue means no garbling. Reaching for the player's own faction here
    -- would make every unattributable line read as Orcish or Common, which is
    -- a confident wrong answer where silence was available.
    blizzId = blizzId or currentLang
    if type(blizzId) ~= "number" then return text end

    local key = blizzId .. "\001" .. text
    local hit = cache[key]
    if hit ~= nil then return hit end

    local out = ns.ImmersionGarbleText and ns.ImmersionGarbleText(text, blizzId)
    out = out or text
    if cacheCount >= CACHE_LIMIT then QuestText.ClearCache() end
    cache[key] = out
    cacheCount = cacheCount + 1
    return out
end

--=========================================================================--
--  Wrapping the text the game hands its own UI
--=========================================================================--
-- These are wrapped rather than the frames being rewritten, for one reason
-- that outweighs the rest: a replaced quest frame is the single most common
-- addon in roleplay (Immersion, Storyline and the rest), and a frame-level
-- rewrite does nothing for anyone running one. Every quest frame, Blizzard's
-- or otherwise, reads the text from these functions.
--
-- The wrappers go on once, the first time the feature is switched on, and stay
-- on. Installing at load would replace Blizzard functions in every session for
-- a setting almost nobody has enabled; uninstalling would mean restoring a
-- function some other addon may have wrapped in the meantime, which is how you
-- break the addon that wrapped it after you.
local installed = false

local function wrapText(name)
    local original = _G[name]
    if type(original) ~= "function" then return end
    _G[name] = function(...)
        return QuestText.Garble(original(...))
    end
end

-- The journal is read long after the giver is gone, so everything below asks
-- the quest rather than the room. The sticky "whoever I spoke to last" answer
-- these used to take is wrong in the ordinary case: open your log in a city
-- and every quest in it reads in the tongue of the innkeeper you just greeted.

function QuestText.Install()
    if installed then return end
    installed = true

    -- The quest giver's window: greeting, the offer and its title, what it
    -- wants, what you say when you come back, and the thanks at the end.
    wrapText("GetGreetingText")
    wrapText("GetTitleText")
    wrapText("GetQuestText")
    wrapText("GetObjectiveText")
    wrapText("GetProgressText")
    wrapText("GetRewardText")

    -- The journal's body text: description and objective paragraph. Classic
    -- reads the selected row, retail can be handed a quest directly.
    if type(GetQuestLogQuestText) == "function" then
        local original = GetQuestLogQuestText
        GetQuestLogQuestText = function(questID, ...)
            local a, b, c = original(questID, ...)
            local lang = QuestText.JournalLanguage(
                type(questID) == "number" and questID or selectedQuestID())
            if not lang then return a, b, c end
            return QuestText.Garble(a, lang), QuestText.Garble(b, lang), c
        end
    end

    -- Gossip, which is the chattiest thing an NPC does and the least likely to
    -- be load-bearing. Classic spells it as globals; retail moved it into
    -- C_GossipInfo and returns the options as a table of rows.
    wrapText("GetGossipText")
    if C_GossipInfo and type(C_GossipInfo.GetText) == "function" then
        local original = C_GossipInfo.GetText
        C_GossipInfo.GetText = function(...)
            return QuestText.Garble(original(...))
        end
    end
    if C_GossipInfo and type(C_GossipInfo.GetOptions) == "function" then
        local original = C_GossipInfo.GetOptions
        C_GossipInfo.GetOptions = function(...)
            local options = original(...)
            if type(options) == "table" and QuestText.OptionsActive() then
                for i = 1, #options do
                    local row = options[i]
                    if type(row) == "table" and type(row.name) == "string" then
                        row.name = QuestText.Garble(row.name)
                    end
                end
            end
            return options
        end
    end

    -- The objective tracker and the journal's checklist. Both read from here,
    -- so this is the one place that covers the panel on the right of the
    -- screen without going near its frames.
    -- GetQuestLogLeaderBoard(objectiveIndex, questLogIndex). The second
    -- argument is optional and names a row in the log rather than a quest, so
    -- it has to be turned into a questID before it can be asked anything.
    if type(GetQuestLogLeaderBoard) == "function" then
        local original = GetQuestLogLeaderBoard
        GetQuestLogLeaderBoard = function(objIndex, questIndex, ...)
            local text, kind, done = original(objIndex, questIndex, ...)
            if not QuestText.TrackerActive() then return text, kind, done end
            local lang = QuestText.JournalLanguage(
                questIDForLogIndex(questIndex) or selectedQuestID())
            if not lang then return text, kind, done end
            return QuestText.Garble(text, lang), kind, done
        end
    end
    if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
        local original = C_QuestLog.GetQuestObjectives
        C_QuestLog.GetQuestObjectives = function(questID, ...)
            local objectives = original(questID, ...)
            local lang = QuestText.JournalLanguage(questID)
            if lang and type(objectives) == "table" and QuestText.TrackerActive() then
                for i = 1, #objectives do
                    local row = objectives[i]
                    if type(row) == "table" and type(row.text) == "string" then
                        row.text = QuestText.Garble(row.text, lang)
                    end
                end
            end
            return objectives
        end
    end

    -- The third way to ask the same question. GetQuestObjectiveInfo answers
    -- one objective at a time and is a separate call into the client rather
    -- than a wrapper around the two above, so hooking those two leaves it
    -- untouched -- which is how a journal came out with one quest's
    -- objectives garbled and the next quest's in plain English.
    if type(GetQuestObjectiveInfo) == "function" then
        local original = GetQuestObjectiveInfo
        GetQuestObjectiveInfo = function(questID, objIndex, ...)
            local text, kind, finished, fulfilled, required =
                original(questID, objIndex, ...)
            if type(text) ~= "string" or not QuestText.TrackerActive() then
                return text, kind, finished, fulfilled, required
            end
            local lang = QuestText.JournalLanguage(questID)
            if not lang then return text, kind, finished, fulfilled, required end
            return QuestText.Garble(text, lang), kind, finished, fulfilled, required
        end
    end

    -- The titles down the side of the journal. These were left readable on
    -- the grounds that a title is your own shorthand for a job you already
    -- took rather than anything the giver said -- true while the rest of the
    -- page was the only thing hidden, and false once the page is the point.
    -- A list of plain English titles over garbled objectives reads as the
    -- feature half working rather than as a decision.
    --
    -- Behind the journal switch rather than the prose one, because that is
    -- the switch that means "the written word is foreign too": Easy leaves
    -- the log readable, Medium and Hard do not.
    --
    -- Headers are left alone either way. A header is the client sorting your
    -- log by zone, not a thing anybody wrote, and garbling them costs you the
    -- ability to find a quest without buying any more of the fiction.
    local function retitle(index, title, level, group, isHeader, ...)
        if type(title) == "string" and title ~= "" and not isHeader
            and QuestText.TrackerActive() then
            local lang = QuestText.JournalLanguage(questIDForLogIndex(index))
            if lang then title = QuestText.Garble(title, lang) end
        end
        return title, level, group, isHeader, ...
    end

    if type(GetQuestLogTitle) == "function" then
        local original = GetQuestLogTitle
        rawQuestLogTitle = original
        GetQuestLogTitle = function(index, ...)
            return retitle(index, original(index, ...))
        end
    end
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local original = C_QuestLog.GetTitleForQuestID
        C_QuestLog.GetTitleForQuestID = function(questID, ...)
            local title = original(questID, ...)
            if type(title) ~= "string" or not QuestText.TrackerActive() then
                return title
            end
            local lang = QuestText.JournalLanguage(questID)
            return lang and QuestText.Garble(title, lang) or title
        end
    end
    if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
        local original = C_QuestLog.GetInfo
        C_QuestLog.GetInfo = function(index, ...)
            local info = original(index, ...)
            if type(info) == "table" and type(info.title) == "string"
                and not info.isHeader and QuestText.TrackerActive() then
                local lang = QuestText.JournalLanguage(info.questID)
                if lang then info.title = QuestText.Garble(info.title, lang) end
            end
            return info
        end
    end
end

-- Called when the settings change. Putting the wrappers on is a one-way door,
-- so this only ever opens it -- switching the feature off is handled by
-- Active() answering false inside every wrapper.
function QuestText.Refresh()
    if QuestText.Active() then QuestText.Install() end
    QuestText.ClearCache()
end

--=========================================================================--
--  Events
--=========================================================================--
-- Everything here is about keeping `currentLang` honest: who is talking now,
-- and which tongue a quest was offered in.
local frame = CreateFrame("Frame")

-- Assigned either way, nil included. There is no API that says "this quest
-- came from an item", and there does not need to be: a quest opened from your
-- bags, from a bulletin board, from an area trigger or from the adventure map
-- has no unit behind it, and that absence is the whole signal. Keeping the
-- last NPC you spoke to would put a dwarf's accent on a letter you found in a
-- drawer ten minutes later.
local function noteSpeaker()
    currentLang = QuestText.LanguageForUnit("npc")
end

-- Write down whichever quest is on screen, in the tongue of whoever is holding
-- it out. Used at the offer and again at the turn-in: handing a quest back is
-- the second and last time the giver and the quest are in the same place, so
-- it is also the only chance to backfill one taken before any of this was on.
-- `currentLang or false` rather than `currentLang`: "there was nobody holding
-- this out" is worth writing down. Without it an item quest is indistinguish-
-- able from one taken before any of this existed, and the journal would hand
-- your own faction's tongue to a letter nobody spoke.
local function rememberCurrent()
    if type(GetQuestID) ~= "function" then return end
    local ok, id = pcall(GetQuestID)
    if ok then QuestText.RememberQuest(id, currentLang or false) end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        noteSpeaker()
    elseif event == "QUEST_DETAIL" then
        -- Recorded at the offer rather than at acceptance: this is the only
        -- moment both the quest and the NPC are reliably in front of us, and
        -- the accepted event does not agree across flavours about what it
        -- passes.
        noteSpeaker()
        rememberCurrent()
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        -- Coming back to hand it in. Nothing needs this for a quest we already
        -- know, but it is how a quest taken before the feature was switched on
        -- finally gets a tongue -- at the moment you meet its giver again.
        noteSpeaker()
        rememberCurrent()
    elseif event == "QUEST_ACCEPTED" then
        -- A second chance at the record. Auto-accept addons and quests picked
        -- up off an item never show the offer, so QUEST_DETAIL never fires;
        -- if there is still somebody in front of us, this catches it.
        --
        -- Classic passes (questLogIndex, questID) and retail passes (questID).
        -- Taking the first number either way would file a Classic quest under
        -- its row in the log, which is both wrong and a number that belongs to
        -- some other quest tomorrow.
        local first, second = ...
        local id = (type(second) == "number" and second > 0) and second or first
        local lang = QuestText.LanguageForUnit("npc") or currentLang
        if lang then QuestText.RememberQuest(id, lang) end
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        -- Cleared, now that nothing reads the journal through it. Leaving it
        -- set meant the last NPC you greeted lent their tongue to every quest
        -- in your log, which is how a tauren quest came out in Orcish.
        currentLang = nil
    elseif event == "QUEST_REMOVED" then
        QuestText.ForgetQuest(...)
    elseif event == "PLAYER_LOGIN" then
        -- Faction names are not all loaded at file scope, and a name that came
        -- back empty then would otherwise stay empty for the session.
        QuestText.ForgetFactionNames()
        QuestText.Refresh()
    end
end)

for _, event in ipairs({
    "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_COMPLETE", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "GOSSIP_CLOSED", "QUEST_FINISHED", "PLAYER_LOGIN",
}) do
    pcall(frame.RegisterEvent, frame, event)
end

-- Test seam. The harness has no events and no NPC to look at.
function QuestText._SetSpeaker(blizzId) currentLang = blizzId end
function QuestText._Speaker() return currentLang end

--=========================================================================--
--  Diagnosis
--=========================================================================--
-- "Nothing in my journal is garbled" has several completely different causes
-- -- the feature off, the wrappers not on, the quest predating the record, or
-- this client not answering which quest is selected -- and they are
-- indistinguishable from the outside. Rather than guess, say which one it is.
local function langName(blizzId)
    local glyphId = ns.NATIVE_LANG_IDS and ns.NATIVE_LANG_IDS[blizzId]
    local name = glyphId and ns.Language and ns.Language.GetLanguageName
        and ns.Language.GetLanguageName(glyphId)
    return name or glyphId or ("id " .. tostring(blizzId))
end

function QuestText.Report()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local db = GlyphicDB or {}
    add("full immersion: " .. (db.fullImmersion and "on" or "off"))
    add("NPC text: " .. (db.immersionNPCs and "on" or "off"))
    add("quest text: " .. (db.immersionQuests and "on" or "off"))
    add("wrappers installed: " .. (installed and "yes" or "no"))

    -- Whoever is in front of you, and what the client was willing to say about
    -- them. This is the block that answers "why is this troll speaking
    -- Orcish": either the race came back empty, or it came back as something
    -- the table has never heard of.
    if type(UnitExists) == "function" and UnitExists("npc") then
        local name = type(UnitName) == "function" and UnitName("npc") or "?"
        local file = QuestText.RaceFile("npc")
        add("talking to: " .. tostring(name))
        add("  its race, per the client: " .. (file
            or "|cff808080nothing, and there never will be -- the game does not "
            .. "tell addons an NPC's race|r"))
        local repLang = QuestText.FactionTongue("npc")
        add("  who it answers to: " .. (repLang and langName(repLang)
            or "|cff808080nothing its tooltip names|r"))
        local zoneLang = QuestText.ZoneTongue()
        add("  this zone's homeland tongue: " .. (zoneLang and langName(zoneLang)
            or "|cff808080not a racial homeland|r"))
        if type(UnitFactionGroup) == "function" then
            add("  its side: " .. tostring(UnitFactionGroup("npc")))
        end
        local lang = QuestText.LanguageForUnit("npc")
        add("  so Glyphic reads it as: " .. (lang and langName(lang) or "nothing"))
    else
        add("talking to: nobody")
    end

    local id = selectedQuestID()
    add("selected quest: " .. (id and tostring(id)
        or "|cffff6060none -- this client is not telling Glyphic which quest is open|r"))

    local known, total = 0, 0
    for _ in pairs((GlyphicDB and GlyphicDB.questLangs) or {}) do total = total + 1 end
    if id then
        local lang = QuestText.LanguageForQuest(id)
        if type(lang) == "number" then
            known = 1
            add("its tongue: " .. langName(lang) .. " |cff808080(from its giver)|r")
        elseif lang == false then
            add("its tongue: none -- nobody handed you this one, so it is left "
                .. "in plain words")
        else
            add("its tongue: " .. langName(QuestText.PlayerLanguage())
                .. " |cffff6060(guessed -- you had this quest before quest text "
                .. "was switched on, so Glyphic never met the giver. Hand it in "
                .. "and the real one is recorded.)|r")
        end
    end
    add("quests with a recorded tongue: " .. total)

    return lines, known
end
