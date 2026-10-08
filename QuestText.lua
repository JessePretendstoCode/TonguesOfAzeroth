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

    How far does it go? Everything the NPC shows you: the greeting, the
    offer, its title, the objectives, the progress and the thanks, the gossip
    window and the objective tracker. Not the buttons -- Accept still says
    Accept, and still works, because not understanding somebody has never
    stopped anyone agreeing to fetch ten boar livers. And not the titles in
    your own quest log, which are your shorthand for a job you already took
    rather than anything the quest giver said; garbling those costs you the
    ability to abandon the right quest and buys nothing you would read in
    character.
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
function QuestText.LanguageForUnit(unit)
    if type(UnitExists) ~= "function" or not UnitExists(unit) then return nil end
    if type(UnitRace) == "function" then
        local _, file = UnitRace(unit)
        if type(file) == "string" then
            local id = RACE_LANGUAGE[file:lower()]
            if id then return id end
        end
    end
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
    if known == false then return nil end
    if type(known) == "number" then return known end
    return QuestText.PlayerLanguage()
end

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
    if type(GetQuestLogTitle) == "function" then
        -- Every flavour that still has this returns the questID eighth, after
        -- title, level, suggestedGroup, isHeader, isCollapsed, isComplete and
        -- frequency. Trusting the slot beats scanning for "a number that looks
        -- like an id", which skips low-numbered classic quests and can pick up
        -- a level or a group size instead.
        local row = { GetQuestLogTitle(index) }
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
    -- reads the selected row, retail can be handed a quest directly. The title
    -- beside it is left alone on purpose: see the note at the top of this file.
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
            if type(options) == "table" and QuestText.Active() then
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
            if lang and type(objectives) == "table" and QuestText.Active() then
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
function QuestText.Report()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local db = GlyphicDB or {}
    add("full immersion: " .. (db.fullImmersion and "on" or "off"))
    add("NPC text: " .. (db.immersionNPCs and "on" or "off"))
    add("quest text: " .. (db.immersionQuests and "on" or "off"))
    add("wrappers installed: " .. (installed and "yes" or "no"))

    local id = selectedQuestID()
    add("selected quest: " .. (id and tostring(id)
        or "|cffff6060none -- this client is not telling Glyphic which quest is open|r"))

    local known, total = 0, 0
    for _ in pairs((GlyphicDB and GlyphicDB.questLangs) or {}) do total = total + 1 end
    if id then
        local lang = QuestText.LanguageForQuest(id)
        local function nameOf(blizzId)
            local glyphId = ns.NATIVE_LANG_IDS and ns.NATIVE_LANG_IDS[blizzId]
            local name = glyphId and ns.Language and ns.Language.GetLanguageName
                and ns.Language.GetLanguageName(glyphId)
            return name or glyphId or ("id " .. tostring(blizzId))
        end
        if type(lang) == "number" then
            known = 1
            add("its tongue: " .. nameOf(lang) .. " |cff808080(from its giver)|r")
        elseif lang == false then
            add("its tongue: none -- nobody handed you this one, so it is left "
                .. "in plain words")
        else
            add("its tongue: " .. nameOf(QuestText.PlayerLanguage())
                .. " |cffff6060(guessed -- you had this quest before quest text "
                .. "was switched on, so Glyphic never met the giver. Hand it in "
                .. "and the real one is recorded.)|r")
        end
    end
    add("quests with a recorded tongue: " .. total)

    return lines, known
end
