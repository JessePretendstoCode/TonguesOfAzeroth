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

function QuestText.RememberQuest(questID, blizzId)
    if type(questID) ~= "number" or questID <= 0 then return end
    if type(blizzId) ~= "number" then return end
    questLangs()[questID] = blizzId
end

function QuestText.ForgetQuest(questID)
    if type(questID) ~= "number" then return end
    questLangs()[questID] = nil
end

function QuestText.LanguageForQuest(questID)
    if type(questID) == "number" and questID > 0 then
        local remembered = questLangs()[questID]
        if remembered then return remembered end
    end
    return currentLang or QuestText.PlayerLanguage()
end

-- Whichever quest the journal is currently showing, across the API rename.
local function selectedQuestID()
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local ok, id = pcall(C_QuestLog.GetSelectedQuest)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if type(GetQuestLogSelection) == "function" and type(GetQuestLogTitle) == "function" then
        local index = GetQuestLogSelection()
        if index and index > 0 then
            local info = { GetQuestLogTitle(index) }
            -- The questID moved around between flavours; take the first number
            -- in the row that looks like one rather than guessing at a slot.
            for i = 1, #info do
                if type(info[i]) == "number" and info[i] > 100 then return info[i] end
            end
        end
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
    blizzId = blizzId or currentLang or QuestText.PlayerLanguage()
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

-- Returns several strings, all of them prose (description and objectives).
local function wrapTexts(name)
    local original = _G[name]
    if type(original) ~= "function" then return end
    _G[name] = function(...)
        local a, b, c = original(...)
        return QuestText.Garble(a), QuestText.Garble(b), c
    end
end

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

    -- The journal's body text. The title beside it is left alone on purpose:
    -- see the note at the top of this file.
    wrapTexts("GetQuestLogQuestText")

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
    if type(GetQuestLogLeaderBoard) == "function" then
        local original = GetQuestLogLeaderBoard
        GetQuestLogLeaderBoard = function(...)
            local text, kind, done = original(...)
            return QuestText.Garble(text), kind, done
        end
    end
    if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
        local original = C_QuestLog.GetQuestObjectives
        C_QuestLog.GetQuestObjectives = function(questID, ...)
            local objectives = original(questID, ...)
            if type(objectives) == "table" and QuestText.Active() then
                local lang = QuestText.LanguageForQuest(questID)
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

local function noteSpeaker()
    local lang = QuestText.LanguageForUnit("npc")
    if lang then currentLang = lang end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "GOSSIP_SHOW" or event == "QUEST_GREETING"
        or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        noteSpeaker()
    elseif event == "QUEST_DETAIL" then
        noteSpeaker()
        -- Recorded at the offer rather than at acceptance: this is the only
        -- moment both the quest and the NPC are in front of us, and the
        -- accepted event does not agree across flavours about what it passes.
        if type(GetQuestID) == "function" and currentLang then
            local ok, id = pcall(GetQuestID)
            if ok then QuestText.RememberQuest(id, currentLang) end
        end
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
        -- Deliberately NOT cleared. The quest log is read after you walk away,
        -- and a tongue that evaporates when the window shuts would leave the
        -- journal reading in your own language a second later.
    elseif event == "QUEST_REMOVED" then
        QuestText.ForgetQuest(...)
    elseif event == "PLAYER_LOGIN" then
        QuestText.Refresh()
    end
end)

for _, event in ipairs({
    "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_COMPLETE", "QUEST_REMOVED", "PLAYER_LOGIN",
}) do
    pcall(frame.RegisterEvent, frame, event)
end

-- Test seam. The harness has no events and no NPC to look at.
function QuestText._SetSpeaker(blizzId) currentLang = blizzId end
function QuestText._Speaker() return currentLang end
