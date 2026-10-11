--[[-------------------------------------------------------------------------
    Glyphic - Challenge.lua
    A named run with the settings decided for you, and a record of how it went.

    Everything else in this addon is a preference. A challenge is the opposite:
    a fixed configuration you agree to, so that two people who say they did the
    same thing actually did. That only works if the settings stop being yours
    for the duration, which is the one and only reason this locks anything.

    It is additive. Nothing here is required to use immersion, and nothing
    here garbles anything the ordinary switches would not. Someone who just
    wants to tick the three immersion boxes and play is having the experience
    this addon was built for; a challenge only takes the same switches, sets
    them to a published arrangement, and writes down what happened.

    What difficulty changes is what you can read, not how fast you learn. That
    is a deliberate inversion of the obvious design. Slowing the learn rate
    looks like difficulty and is really just length: a run at a third of the
    rate is not harder minute to minute, it is the same minute three times, and
    for the first several hours the tiers are indistinguishable because every
    one of them reads as "I understand nothing". Hiding a different set of
    surfaces is felt on the first quest.

    Leaving the rate alone has a second effect worth stating, because it is
    what makes learning every tongue at once work rather than scatter. One
    word per quest, spread across whoever hands them to you, ends a levelling
    run somewhere around fluent in your faction's tongue, conversational in
    the one next door, and a scattering of two or three others. That is a
    better ending than a single bar reaching 100%: it reads like a record of
    where you went.

    The locking is an honour system with a tripwire, and is described that way
    rather than pretended about. Saved variables are a text file on the
    player's own disk; anyone determined to edit it can, and no amount of
    checking here would change that. What the audit catches is the ordinary
    case -- a switch flipped in the options panel, a profile imported over the
    top -- and when it catches one it says so and lets the run continue,
    marked, rather than silently failing or silently resetting it. A challenge
    nobody can fail honestly is not a challenge; one that deletes your run
    without telling you is worse.
---------------------------------------------------------------------------]]

local _, ns = ...

local Challenge = {}
ns.Challenge = Challenge

-- How far in a character can be and still count as never having played,
-- which is not the same number on every client.
--
-- Retail drops a new character into Exile's Reach and hands out levels for
-- finishing the tutorial, so ten is the first point at which you are out of
-- it and choosing where to go; anything lower would refuse people who have
-- not actually done anything yet. Classic, Classic Era and Forever have no
-- tutorial. A character who has not played is level one, and a level four
-- there is somebody who went and did the first few quests in English before
-- deciding to start over -- which is the thing this requirement exists to
-- turn away.
function Challenge.MaxStartLevel()
    return ns.Compat.IsMainline() and 10 or 1
end

-- The classes that are handed the levels the run is about. A death knight
-- arrives on Retail at level eight with nothing on the experience bar,
-- which is a fresh character by every other test here and has still skipped
-- the part of the game where you cannot read anybody.
--
-- Listed by class token rather than by the level they start at, because
-- that level has been changed twice already and will be again.
local HERO_CLASSES = {
    DEATHKNIGHT = "death knights",
    DEMONHUNTER = "demon hunters",
    -- The same case, and refused for the same reason. An evoker starts at
    -- fifty-eight and so would fail the level test anyway; naming it here
    -- is so the panel gives the real reason rather than a number.
    EVOKER      = "evokers",
}

local function playerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    if ok and type(level) == "number" and level > 0 then return level end
    return nil
end

-- Experience into the current level. Nil when the client cannot say, which
-- is treated as "cannot confirm you are fresh" rather than as zero: the
-- requirement it feeds is the one standing between a challenge and the
-- character who already played half of it.
local function playerXP()
    if type(UnitXP) ~= "function" then return nil end
    local ok, xp = pcall(UnitXP, "player")
    if ok and type(xp) == "number" then return xp end
    return nil
end

-- The class token (DEATHKNIGHT, not "Death Knight"), so the check below
-- reads the same on a German client.
local function playerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if ok and type(token) == "string" then return token end
    return nil
end

local function today()
    if type(date) ~= "function" then return "" end
    local ok, stamp = pcall(date, "%Y-%m-%d")
    return (ok and type(stamp) == "string") and stamp or ""
end

--=========================================================================--
--  The challenges
--=========================================================================--
-- Every tier of Stranger shares this. Written once rather than three times,
-- because three copies of the same four lines is three chances for one of
-- them to drift and for a tier to quietly stop being the thing it says it is.
-- Every tier hides speech. What is written down -- the journal, the
-- objective tracker -- is what separates Easy from the other two, so it is
-- named per tier rather than here.
local STRANGER_BASE = {
    fullImmersion   = true,
    immersionNPCs   = true,
    -- Not flavour: the only way out of the fog is quests teaching you, so a
    -- run with this off is unwinnable rather than hard.
    questLearning   = true,
}

local function tier(extra)
    local out = {}
    for key, value in pairs(STRANGER_BASE) do out[key] = value end
    for key, value in pairs(extra) do out[key] = value end
    return out
end

-- Client settings the harder tiers take away as well.
--
-- These are console variables rather than our own, which makes them a
-- different kind of lock: the switches above live in our saved variables and
-- our own panels can refuse to move them, while these live in Blizzard's
-- options where nothing we do can grey out a checkbox. So they are enforced
-- instead of refused -- set on start, put back on abandon, and set again if
-- something moves them. A player who really wants them back has the same
-- honour system every other lock here runs on.
--
-- Not in `settings`, and audited separately, because the tripwire compares
-- saved variables and a console variable is not one. Folding them together
-- would make every "I changed a graphics setting" into a voided run.
-- Hard's "all quest tracking is hidden", in console variables. Working out
-- the job is part of the job there, and a map that still draws a ring round
-- the answer gives it away without a word of text.
--
-- Four switches rather than one because they are four systems: the POI
-- machinery, the objectives drawn on the world map, the blue areas the
-- minimap shades in, and whether accepting a quest puts it on the tracker.
-- Turning the first two off and leaving the third is what a minimap still
-- full of quest blobs looks like.
--
-- The last one is half of how the tracker is emptied, and the reason it is a
-- console variable rather than something we do ourselves is that it is the
-- only half we can state up front. See "The objective tracker" below.
local TRACKING_HIDDEN = {
    questPOI = "0",
    showQuestObjectivesOnMap = "0",
    minimapShowQuestBlobs = "0",
    autoQuestWatch = "0",
}

-- Floating names over heads. On Hard you cannot read what anyone says, so
-- reading who they are off a label above them is the same hole in the
-- fiction. Nameplates are deliberately left alone: those are a combat tool
-- as much as a label, and taking them away would be a difficulty of a
-- different kind than the one this run is about.
local NAMES_HIDDEN = {
    UnitNameNPC = "0",
    UnitNameNonCombatCreatureName = "0",
    UnitNameFriendlyPlayerName = "0",
    UnitNameEnemyPlayerName = "0",
    UnitNameFriendlySpecialNPCName = "0",
    UnitNamePlayerGuild = "0",
    UnitNamePlayerPVPTitle = "0",
    -- Blizzard's own spelling. Not a typo here.
    UnitNameHostleNPC = "0",
    UnitNameInteractiveNPC = "0",
}

local function merge(...)
    local out = {}
    for i = 1, select("#", ...) do
        for key, value in pairs((select(i, ...))) do out[key] = value end
    end
    return out
end

-- The same operation under the name of what each call site is merging. A
-- console-variable table and a settings table are both flat maps and are not
-- the same kind of thing, and the tier definitions below read better for
-- saying which one they mean.
local cvars = merge

--=========================================================================--
--  Addressing a setting
--=========================================================================--
-- Most settings a tier takes are top-level keys in the saved variables, and
-- for most of this file's history all of them were. Mythic needs three that
-- are not: every entry in `db.channels`, and `db.accent.id`.
--
-- So a setting is named by a path -- "channels.SAY", "accent.id" -- and these
-- three functions are the only places that know it. One level of nesting,
-- because that is all the saved variables have anywhere a challenge reaches,
-- and a general path resolver would be more machinery than the problem.
--
-- Addressing the leaf rather than the table matters for three separate
-- reasons, each of which bit in testing. The audit compares values with ~=,
-- and two tables are never equal unless they are the same table -- so a lock
-- on `channels` either never fires or, worse, holds the tier definition's own
-- table and can never fire. Writing a leaf leaves the table itself alone,
-- which is what Profile.Apply learned the hard way: modules capture
-- `GlyphicDB.channels` and replacing the global would leave them writing to an
-- orphan. And a per-leaf lock can say *which* channel somebody changed.
local function splitPath(key)
    local dot = (key or ""):find(".", 1, true)
    if not dot then return key, nil end
    return key:sub(1, dot - 1), key:sub(dot + 1)
end

local function readSetting(key)
    local db = GlyphicDB
    if not db then return nil end
    local head, tail = splitPath(key)
    if not tail then return db[head] end
    local inner = db[head]
    if type(inner) ~= "table" then return nil end
    return inner[tail]
end

local function writeSetting(key, value)
    GlyphicDB = GlyphicDB or {}
    local head, tail = splitPath(key)
    if not tail then
        GlyphicDB[head] = value
        return
    end
    if type(GlyphicDB[head]) ~= "table" then GlyphicDB[head] = {} end
    GlyphicDB[head][tail] = value
end

--=========================================================================--
--  Mythic's own tongue
--=========================================================================--
-- The tier above Hard does not hide more of the game. Every other tier is
-- about what you cannot read; this one is about what nobody can read of you.
--
-- Easy through Hard all share a hole that is only visible once you notice it:
-- a fresh run has nothing learned, so the speaker's own fluency is zero, so
-- their chat goes out as plain English. Everyone around them is unintelligible
-- and they are perfectly intelligible to everyone -- which is the opposite of
-- arriving somewhere nobody speaks your language.
--
-- Mythic closes it by giving the character a native dialect nobody on the
-- continent speaks, and then draining it. See Challenge.MotherStrength: the
-- better you know the tongues you were born speaking, the less of Legendspeech
-- is left, and the words it stops covering come out as ordinary English. So
-- the run is won by becoming legible, and a stranger reading your /say can
-- watch it happen.
local NATIVE_TONGUE = "legendspeech"
local NATIVE_ACCENT = "legend"

-- Every channel, because a locked voice with one unlocked channel is not
-- locked. Built from Core's list rather than copied, so a channel added later
-- is covered by the tier that was written before it existed.
--
-- EMOTE is the one that stays off, and it is off for the reason it is off
-- everywhere else rather than as a way out: an emote is narration, not speech,
-- so running "/e straightens her cloak" through a tongue has the narrator
-- speaking Legendspeech about you in the third person. Pinning it rather than
-- leaving it alone is the point -- it is locked *off*, so a run cannot quietly
-- turn its own narration foreign either.
local function allChannels()
    local out = {}
    local types = ns.CHANNEL_TYPES or {}
    for i = 1, #types do
        out["channels." .. types[i]] = (types[i] ~= "EMOTE")
    end
    return out
end

local CHALLENGES = {
    stranger = {
        id    = "stranger",
        name  = "Stranger",
        blurb = "You arrive understanding nobody. Every quest and every NPC "
             .. "is in a tongue you do not speak, and the only way out is to "
             .. "work for the people who speak it.",
        order = { "easy", "medium", "hard", "mythic" },
        difficulties = {
            easy = {
                id    = "easy",
                label = "Easy",
                blurb = "All players and NPCs speak a language you don't "
                     .. "understand. Complete a quest to learn a word's "
                     .. "meaning and become more fluent.",
                settings = tier({
                    -- Speech only. Everything written down stays readable,
                    -- so you always know what to do -- just never why.
                    immersionQuests         = false,
                    immersionTracker        = false,
                    immersionGossipOptions  = false,
                }),
                cvars = cvars(),
                wordCost = 1,
            },
            medium = {
                id    = "medium",
                label = "Medium",
                blurb = "All players and NPCs speak a language you don't "
                     .. "understand. Complete quests to learn a word's "
                     .. "meaning and become more fluent. Journal and Quest "
                     .. "objectives tracker are also in a written language "
                     .. "you do not understand.",
                settings = tier({
                    immersionQuests         = true,
                    immersionTracker        = true,
                    immersionGossipOptions  = false,
                }),
                -- The map still marks where to go. Reading the tracker is
                -- the problem on this tier, not finding the place.
                cvars = cvars(),
                wordCost = 2,
            },
            hard = {
                id    = "hard",
                label = "Hard",
                blurb = "All players and NPCs speak a language you don't "
                     .. "understand. Complete a handful of quests to learn a "
                     .. "word's meaning and become more fluent. Journal and "
                     .. "Quest objectives tracker are also in a written "
                     .. "language you do not understand. All quest tracking "
                     .. "is hidden. All NPC and player names are hidden. Who "
                     .. "are these people?",
                settings = tier({
                    immersionQuests         = true,
                    immersionTracker        = true,
                    -- The replies you click to answer an NPC, so the menus
                    -- are navigated by shape. Not named in the description
                    -- above because it is part of not understanding what is
                    -- said to you rather than a fourth thing.
                    immersionGossipOptions  = true,
                }),
                cvars = cvars(TRACKING_HIDDEN, NAMES_HIDDEN),
                -- Three rather than a bigger number, because the cost is
                -- multiplied by the tongue's own size: Orcish has a hundred
                -- words, so five would be five hundred quests in Orcish
                -- alone and the run stops being hard and starts being one
                -- you do not finish. Three is three hundred, which is a
                -- levelling run.
                wordCost = 3,
                hideTracker = true,
            },
            mythic = {
                id    = "mythic",
                label = "Mythic",
                blurb = "Everything Hard hides, and you are a foreigner on top "
                     .. "of it. You speak Legendspeech -- a tongue nobody here "
                     .. "knows -- so nobody can read a word you say, with or "
                     .. "without this addon. Learning the languages you were "
                     .. "born speaking is what slowly turns your speech back "
                     .. "into plain English. You are in character on every "
                     .. "channel for the whole run, and you cannot switch it "
                     .. "off. Reach max level and Legendspeech is yours for "
                     .. "good, on every character.",
                settings = tier(merge({
                    immersionQuests         = true,
                    immersionTracker        = true,
                    immersionGossipOptions  = true,
                    -- The switch that mutes the addon, held down. Every other
                    -- tier leaves it alone, because with nothing learned their
                    -- speaker is speaking English anyway and the switch
                    -- changes nothing worth locking. Here it is the run.
                    inCharacter             = true,
                    motherTongue            = NATIVE_TONGUE,
                    -- Forced on, and the reason it is a locked setting rather
                    -- than a hidden behaviour is that finishing the run turns
                    -- it into an ordinary choice. The lock lifting *is* the
                    -- option to switch it off.
                    ["accent.id"]           = NATIVE_ACCENT,
                }, allChannels())),
                cvars = cvars(TRACKING_HIDDEN, NAMES_HIDDEN),
                -- Hard's number. Mythic is not a longer Hard, and a tier that
                -- also tripled the grind would be exactly the "same minute
                -- three times" this file argues against at the top.
                wordCost = 3,
                hideTracker = true,
                -- Which native dialect drains, rather than a flag saying one
                -- does: the thing worth writing onto the run is the tongue, so
                -- a run keeps speaking what it started speaking even if the
                -- tier is retuned underneath it.
                drainsTongue = NATIVE_TONGUE,
                rewards = { language = NATIVE_TONGUE, accent = NATIVE_ACCENT },
            },
        },
    },
}

Challenge.DEFAULT = "stranger"
Challenge.DEFAULT_DIFFICULTY = "medium"

function Challenge.Definition(id)
    return CHALLENGES[id or ""]
end

function Challenge.All()
    local out = {}
    for _, def in pairs(CHALLENGES) do out[#out + 1] = def end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Challenge.Difficulty(id, difficultyId)
    local def = Challenge.Definition(id)
    if not def then return nil end
    return def.difficulties[difficultyId or ""]
end

-- The settings a tier demands, as a fresh table every time. Fresh because the
-- caller stores one of these in the saved variables as the thing to audit
-- against, and handing out the module's own table would let a later edit to
-- the run rewrite the definition for everybody.
function Challenge.Settings(id, difficultyId)
    local diff = Challenge.Difficulty(id, difficultyId)
    if not diff then return nil end
    local out = {}
    for key, value in pairs(diff.settings) do out[key] = value end
    return out
end

-- The console variables a tier takes away, as a fresh table, for the same
-- reason Settings hands out a copy.
function Challenge.CVars(id, difficultyId)
    local diff = Challenge.Difficulty(id, difficultyId)
    if not diff then return nil end
    local out = {}
    for key, value in pairs(diff.cvars or {}) do out[key] = value end
    return out
end

--=========================================================================--
--  Console variables
--=========================================================================--
-- Every one of these is wrapped. The set differs by flavour -- the map pins
-- are two variables on retail and one on Classic Era, and the name list has
-- grown over the years -- and asking for one the client has never heard of
-- is an error rather than a nil. A tier that names a variable this client
-- does not have simply does not take that one away.
--
-- `reentry` is because SetCVar fires CVAR_UPDATE, which is the event that
-- calls back into here. It does not run away without the flag -- the write
-- below is conditional, so each nested pass finds one more variable already
-- where it wants it and the whole thing bottoms out -- but it does mean
-- enforcing three variables costs six passes instead of one, every time any
-- of them moves. The flag is the difference between a loop and a cascade.
local reentry = false

local function readCVar(key)
    if type(GetCVar) ~= "function" then return nil end
    local ok, value = pcall(GetCVar, key)
    return ok and value or nil
end

local function writeCVar(key, value)
    if type(SetCVar) ~= "function" or value == nil then return end
    pcall(SetCVar, key, value)
end

-- Puts the tier's variables back the way the run wants them. Called on
-- login, after starting, and whenever anything moves one.
function Challenge.EnforceCVars()
    local run = Challenge.Current()
    if not run or reentry then return end
    local wanted = run.cvars
    if type(wanted) ~= "table" then return end
    reentry = true
    for key, value in pairs(wanted) do
        if readCVar(key) ~= value then writeCVar(key, value) end
    end
    reentry = false
end

local function restoreCVars(run)
    local before = run and run.cvarsBefore
    if type(before) ~= "table" then return end
    reentry = true
    for key, value in pairs(before) do writeCVar(key, value) end
    reentry = false
end

--=========================================================================--
--  The objective tracker
--=========================================================================--
-- Hard hides the tracker outright rather than garbling it. Garbled, it is
-- still a list of how many of what you have killed -- the numbers are
-- numbers in every language -- so you can play the whole run off the
-- counters without reading a word. Hidden, the quest is the thing you were
-- told and have to remember.
--
-- It is emptied rather than hidden, and no frame is touched anywhere in this
-- section -- not read, not written, not asked whether it is on screen. That
-- restraint is the whole of this section's history, so it is written down
-- rather than left to be rediscovered.
--
-- There is no console variable for the tracker and no setting, so the first
-- two attempts went at the frame. One hooked its Show with hooksecurefunc;
-- the next called Hide on a half-second timer. Both ended in the same crash.
-- The objective tracker is an Edit Mode system and Edit Mode remembers what
-- it learns about its systems, so a run would die with "Auras cannot be
-- accessed when secret while tainted by 'Glyphic'" from inside Blizzard's own
-- event handler, long after we had touched anything.
--
-- The second attempt is the one worth the warning. Hooking a method writes
-- `frame.Show = ours` onto a Blizzard table and the taint is no surprise;
-- calling Hide writes nothing at all and taints the frame anyway. "We only
-- called a C method and left no footprint" is precisely the reasoning that
-- shipped it, and it is wrong.
--
-- So the run stops having anything to track instead. Every quest comes off
-- the watch list and autoQuestWatch stops new ones going on, and an empty
-- tracker hides itself through Blizzard's own secure code -- which is a thing
-- no addon is able to taint. It also means there is no frame to put back at
-- the end of a run, only a watch list to hand over.
--
-- Retail and the Classic flavours both answer this through C_QuestLog, and a
-- client that cannot name the quests on its tracker does not get the feature
-- at all: removing a watch we are unable to name is taking away a list we
-- cannot give back. Challenge.TrackerRoad() says which case the client is in,
-- because "the tracker is still there" otherwise has two causes that look
-- identical.
local function watchAPI()
    local C = _G.C_QuestLog
    if type(C) ~= "table" then return nil end
    local needed = {
        "GetNumQuestWatches", "GetQuestIDForQuestWatchIndex",
        "RemoveQuestWatch", "AddQuestWatch",
    }
    for i = 1, #needed do
        if type(C[needed[i]]) ~= "function" then return nil end
    end
    return C
end

-- World quests are tracked through a second list of their own, so a tracker
-- emptied of quests can still be showing three of them. Detected apart from
-- the list above because the Classic flavours have the one and not the other.
local function worldWatchAPI()
    local C = _G.C_QuestLog
    if type(C) ~= "table" then return nil end
    if type(C.GetNumWorldQuestWatches) ~= "function" then return nil end
    if type(C.GetQuestIDForWorldQuestWatchIndex) ~= "function" then return nil end
    if type(C.RemoveWorldQuestWatch) ~= "function" then return nil end
    return C
end

function Challenge.TrackerRoad()
    return watchAPI() and "watchlist" or "none"
end

-- Whether the run wants it gone. Read live rather than latched, so nothing
-- needs undoing when the run ends: it simply stops saying yes.
function Challenge.HidesTracker()
    local run = Challenge.Current()
    return (run and run.hideTracker) and true or false
end

-- Which quests are on the tracker, by ID. IDs rather than the row they sit on,
-- because a row is a number that belongs to some other quest tomorrow and this
-- list has to survive a logout.
--
-- The world quest list is deliberately not in here even though it is emptied
-- below. A world quest expires in a day and a run is sixty levels, so every ID
-- written down here would be dead by the time it was offered back -- and they
-- go back on through an API of their own, so a list that mixed the two would
-- hand a world quest to AddQuestWatch and quietly do nothing.
local function watchedQuests()
    local C = watchAPI()
    if not C then return {} end
    local out = {}
    local ok, n = pcall(C.GetNumQuestWatches)
    if ok and type(n) == "number" then
        for i = 1, n do
            local got, id = pcall(C.GetQuestIDForQuestWatchIndex, i)
            if got and type(id) == "number" and id > 0 then out[#out + 1] = id end
        end
    end
    return out
end

-- Take everything off the tracker.
--
-- Counted down rather than up, because removing a watch renumbers every one
-- after it and counting up skips every second quest. The IDs are read first
-- and removed afterwards for the same reason, one list at a time.
local function emptyTracker()
    local C = watchAPI()
    if not C then return end
    local W = worldWatchAPI()
    if W then
        local ok, n = pcall(W.GetNumWorldQuestWatches)
        if ok and type(n) == "number" then
            for i = n, 1, -1 do
                local got, id = pcall(W.GetQuestIDForWorldQuestWatchIndex, i)
                if got and type(id) == "number" and id > 0 then
                    pcall(W.RemoveWorldQuestWatch, id)
                end
            end
        end
    end
    local ok, n = pcall(C.GetNumQuestWatches)
    if not ok or type(n) ~= "number" then return end
    for i = n, 1, -1 do
        local got, id = pcall(C.GetQuestIDForQuestWatchIndex, i)
        if got and type(id) == "number" and id > 0 then
            pcall(C.RemoveQuestWatch, id)
        end
    end
end

-- Emptying it once is not enough: a quest put back on the tracker puts the
-- tracker back on screen, and during a levelling run that happens constantly.
--
-- Nothing watches for it, though, because nothing has to. The version of this
-- that hid the frame needed a half-second timer, for the honest reason that no
-- event exists for "a frame showed itself" -- the journal re-showed it as part
-- of its own update, after the event we had hidden on. A watch list is not a
-- frame: the game fires QUEST_WATCH_UPDATE when it changes, that event is in
-- TRACKER_EVENTS already, and so the enforcement is simply the handler.
function Challenge.EnforceTracker()
    local run = Challenge.Current()
    if not (run and run.hideTracker) then return end
    -- Written down the first time a run empties the tracker rather than when it
    -- starts, so that one place owns it. It also means a run already under way
    -- gets its list back: the versions of this that hid the frame recorded
    -- which frames were on screen and never looked at the watch list at all.
    if type(run.watchBefore) ~= "table" then
        run.watchBefore = watchedQuests()
    end
    emptyTracker()
end

local function restoreTracker(run)
    local before = run and run.watchBefore
    local C = watchAPI()
    if not C or type(before) ~= "table" then return end
    for i = 1, #before do
        -- pcall and no complaint on failure: half of these are quests handed in
        -- forty levels ago, and a quest no longer in the log cannot be tracked.
        pcall(C.AddQuestWatch, before[i])
    end
end

--=========================================================================--
--  The run
--=========================================================================--
function Challenge.Current()
    local db = GlyphicDB
    local run = db and db.challenge
    if type(run) ~= "table" or not run.id then return nil end
    return run
end

function Challenge.Active()
    return Challenge.Current() ~= nil
end

--=========================================================================--
--  Getting in
--=========================================================================--
-- Returned as a list rather than a yes/no so the panel can show every line
-- with a tick or a cross beside it. Somebody refused entry should be able to
-- see which requirement refused them without reading the changelog.
--
-- `note` marks the two that cannot fail: they are consequences of starting
-- rather than tests of whether you may, and leaving them off the list would
-- mean the wipe is first mentioned in a confirmation dialog.
function Challenge.Requirements(id)
    local level = playerLevel()
    local xp = playerXP()
    local cap = Challenge.MaxStartLevel()
    local class = playerClass()
    local hero = class and HERO_CLASSES[class]
    return {
        {
            key  = "level",
            -- "Level 1 or below" is not a sentence anybody says.
            text = (cap > 1) and ("Level " .. cap .. " or below") or "Level 1",
            met  = (level ~= nil) and (level <= cap),
            detail = level and ("you are level " .. level) or nil,
        },
        -- Separate from the level, because the two refuse different people.
        -- The level turns away a character who is too far along to start; the
        -- experience turns away one who is still at the right level and has
        -- already played the part of the game this run is about -- the level
        -- nine who ran Exile's Reach in English first, or, where the cap is
        -- one, the level one who has been grinding boars without dinging.
        -- An allied race arrives above level one with nothing earned, and
        -- this lets them in.
        {
            key  = "fresh",
            text = "No experience earned yet",
            met  = (xp ~= nil) and (xp == 0),
            detail = (xp and xp > 0) and (xp .. " earned already") or nil,
        },
        -- Neither of the two above catches a hero class on Retail: a death
        -- knight is level eight with an empty bar, which is every other
        -- definition of fresh.
        {
            key  = "class",
            text = "Not a hero class",
            met  = (class ~= nil) and (hero == nil),
            detail = hero and (hero .. " start part-way in") or nil,
        },
        {
            key  = "none",
            text = "No challenge already running on this character",
            met  = not Challenge.Active(),
        },
        {
            key  = "wipe",
            note = true,
            text = "Starting wipes every language you have learned",
        },
        {
            key  = "character",
            note = true,
            text = "The run belongs to this character alone",
        },
    }
end

-- Set only for the length of one debug call. Two tests stand between a
-- developer and a Mythic run -- a character nobody has played, and sixty
-- levels of playing it -- and neither can be satisfied twice in an afternoon.
-- See the debug section at the foot of this file.
local debugBypass = false

function Challenge.CanStart(id)
    if not Challenge.Definition(id) then return false, "no such challenge" end
    if debugBypass then return true end
    local reqs = Challenge.Requirements(id)
    for i = 1, #reqs do
        if not reqs[i].note and not reqs[i].met then
            return false, reqs[i].text
        end
    end
    return true
end

function Challenge.Start(id, difficultyId)
    local def = Challenge.Definition(id)
    if not def then return false, "no such challenge" end
    if not Challenge.Difficulty(id, difficultyId) then
        return false, "no such difficulty"
    end
    local ok, why = Challenge.CanStart(id)
    if not ok then return false, why end

    local settings = Challenge.Settings(id, difficultyId)
    GlyphicDB = GlyphicDB or {}

    -- Taken before anything is written, so abandoning puts back what was
    -- actually there rather than what the defaults would have said. A key
    -- that was never set reads nil here and is restored to nil, which is the
    -- honest answer: it lets migrateDB decide again next login.
    local before = {}
    for key in pairs(settings) do before[key] = readSetting(key) end

    -- The wipe. A challenge that started on top of an existing character's
    -- fluency would be measuring somebody else's run.
    if ns.ResetAllFluency then ns.ResetAllFluency() end
    GlyphicDB.learned = {}
    -- Which tongue each quest was offered in. Cleared because the entries
    -- belong to quests taken before the run, and a journal half in English is
    -- not the thing being attempted.
    GlyphicDB.questLangs = {}

    for key, value in pairs(settings) do writeSetting(key, value) end

    -- Your own tongue, understood. Written after the wipe above rather than
    -- with the settings, because the wipe would take it straight back off
    -- again -- and it is comprehension, not a setting, so it is not a lock and
    -- the audit never looks at it. Only another Mythic runner will ever send a
    -- word of it, which is the point; this is so that if one does, the two of
    -- them can read each other.
    local diffDef = Challenge.Difficulty(id, difficultyId)
    local tongue = diffDef and diffDef.drainsTongue
    if tongue then
        GlyphicDB.learned = GlyphicDB.learned or {}
        GlyphicDB.learned[tongue] = true
        if ns.Trainer and ns.Trainer.SetFluency then
            pcall(ns.Trainer.SetFluency, tongue, 1)
        end
    end

    -- Read before anything is written, and only for the variables this tier
    -- actually takes, so abandoning puts back what was there rather than
    -- what the client ships with. A variable this client does not have reads
    -- nil and is skipped on the way back out too.
    local wanted = Challenge.CVars(id, difficultyId) or {}
    local cvarsBefore = {}
    for key in pairs(wanted) do cvarsBefore[key] = readCVar(key) end

    local diff = Challenge.Difficulty(id, difficultyId)
    local level = playerLevel()
    GlyphicDB.challenge = {
        id          = id,
        difficulty  = difficultyId,
        startedAt   = today(),
        startLevel  = level,
        level       = level,
        quests      = 0,
        before      = before,
        locks       = settings,
        cvars       = wanted,
        cvarsBefore = cvarsBefore,
        -- How many hand-ins one word costs on this tier, and whether the
        -- tracker goes entirely. Copied onto the run rather than looked up
        -- from the tier each time, so a run keeps the rules it was started
        -- under if the tiers are ever retuned underneath it.
        wordCost    = diff and diff.wordCost or 1,
        hideTracker = (diff and diff.hideTracker) and true or false,
        -- The player's own tracker list, to be handed back when the run ends,
        -- is not recorded here. Challenge.EnforceTracker does it, on the way to
        -- emptying the tracker for the first time -- see there for why.
        -- Copied onto the run for the same reason as wordCost: these are the
        -- rules it agreed to, and a tier retuned mid-run must not change what
        -- somebody's half-finished character sounds like or what they were
        -- promised for finishing.
        drainsTongue = diff and diff.drainsTongue or nil,
        rewards     = (diff and diff.rewards) and merge(diff.rewards) or nil,
        broken      = false,
    }
    Challenge.EnforceCVars()
    Challenge.EnforceTracker()

    if ns.QuestText and ns.QuestText.Refresh then ns.QuestText.Refresh() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true
end

--=========================================================================--
--  Getting out
--=========================================================================--
-- The fluency earned is kept. You did learn it, whatever became of the run.
function Challenge.Abandon()
    local run = Challenge.Current()
    if not run then return false, "no challenge is running" end

    Challenge.Touch()
    GlyphicDB.challengeLast = Challenge.Record()

    local before = run.before or {}
    -- Keyed off the locks rather than off `before`, because a key that was
    -- nil before the run is absent from `before` and still has to be put
    -- back to nil. Iterating the other table would leave it forced on.
    for key in pairs(run.locks or {}) do
        writeSetting(key, before[key])
    end
    -- Cleared before the restores, which both read off the local reference
    -- rather than the field. Nothing depends on the order any more -- the
    -- CVar restore holds its own re-entry guard, and the tracker is no
    -- longer held down by a hook that would ask whether a run still wanted
    -- it hidden -- but a run that is over should stop existing before
    -- anything starts undoing it, not halfway through.
    GlyphicDB.challenge = nil
    restoreCVars(run)
    restoreTracker(run)

    if ns.QuestText and ns.QuestText.Refresh then ns.QuestText.Refresh() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true
end

--=========================================================================--
--  Finishing
--=========================================================================--
-- A levelling run ends when there is no more levelling to do, and until now
-- nothing in this file knew that. Easy through Hard could only be abandoned,
-- which meant the one honest outcome a run had was the one that reads as
-- giving up -- and a player at max level either kept a locked configuration
-- forever or pressed "Stop the run" on a run they had finished.
--
-- Asked of the client rather than written down, through the helper QuestLearn
-- already needed for the same question. Hardcoding 60 would be wrong on five
-- of the six flavours we ship, and wrong on retail twice a year.
--
-- `level` overrides what the client would say, and exists because
-- PLAYER_LEVEL_UP carries the new level as an argument while UnitLevel can
-- still be answering with the old one when the event fires. Without it the
-- ding that finishes a run reads as level 59 of 60 and the run ends on the
-- next zone change instead, with the record naming the wrong level.
function Challenge.AtMaxLevel(level)
    if debugBypass then return true end
    local QL = ns.QuestLearn
    if not (QL and QL.MaxLevel) then return false end
    local ok, cap = pcall(QL.MaxLevel)
    if not ok or type(cap) ~= "number" or cap <= 0 then return false end
    level = tonumber(level) or playerLevel()
    if type(level) ~= "number" or level <= 0 then return false end
    return level >= cap
end

-- Nothing is put back, and that is the decision rather than an omission.
--
-- A run is sixty levels long. Somebody who has spent it with quest text
-- foreign and the tracker gone has been playing that game for days, and
-- handing their old settings back at the finish line would take the game away
-- from them as a reward for completing it. So completing lifts the locks and
-- changes nothing else: everything stays exactly where the run left it, and
-- every switch is theirs again to move at will.
--
-- The tracker is the one exception, and only because it is not a setting. It
-- was being pushed off screen on every quest event by code that asks the run
-- whether to; with the run over that code stops asking, so a tracker left
-- hidden here would be hidden by nothing and would reappear at the next
-- unrelated event anyway. Putting it back is the deterministic version of
-- what happens regardless.
function Challenge.Complete(level)
    local run = Challenge.Current()
    if not run then return false, "no challenge is running" end
    -- A voided run does not pay out. Reaching the level cap with a lock broken
    -- is not finishing the thing that was broken, and if this granted the
    -- reward anyway then switching immersion off at level 12 and levelling
    -- normally would be the fastest route to it.
    if run.broken then return false, "this run is voided" end
    if not Challenge.AtMaxLevel(level) then return false, "not at max level" end

    Challenge.Touch()
    -- Touch reads the client, which may not have caught up with the ding yet.
    -- The event's own number wins when it is ahead, so the record says the
    -- level that finished the run.
    level = tonumber(level)
    if level and (type(run.level) ~= "number" or level > run.level) then
        run.level = level
    end
    local record = Challenge.Record()
    record.completed = true
    record.finishedAt = today()
    GlyphicDB.challengeLast = record

    -- Cleared before the reward is granted, so the grant is not refused by the
    -- run's own locks. `fluency` is locked for the length of a run and the
    -- payout writes a fluency.
    GlyphicDB.challenge = nil
    restoreTracker(run)

    local rewards = run.rewards
    if type(rewards) == "table" then
        if rewards.language then
            if ns.GrantUnlock then ns.GrantUnlock("languages", rewards.language) end
            -- Spoken and understood, not merely selectable. A reward you have
            -- to go and grind in the trainer is not a reward.
            if ns.Trainer and ns.Trainer.SetFluency then
                pcall(ns.Trainer.SetFluency, rewards.language, 1)
            end
            GlyphicDB.learned = GlyphicDB.learned or {}
            GlyphicDB.learned[rewards.language] = true
        end
        if rewards.accent and ns.GrantUnlock then
            ns.GrantUnlock("accents", rewards.accent)
        end
    end

    if ns.QuestText and ns.QuestText.Refresh then ns.QuestText.Refresh() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true, record
end

-- Said here rather than at the call site because two events can reach it and
-- the line a player waited sixty levels for should not depend on which.
local function announceCompletion(record)
    if not ns.Print then return end
    ns.Print("|cffffd200" .. tostring(record.name) .. "|r complete on |cffffff00"
        .. tostring(record.difficulty) .. "|r at level "
        .. tostring(record.level or "?") .. ", after " .. tostring(record.quests)
        .. " quest" .. (record.quests == 1 and "" or "s") .. ".")
    if record.rewardText then
        ns.Print(record.rewardText)
    end
    ns.Print("Your settings are yours again. Nothing has been changed back -- "
        .. "the run is simply over.")
end

-- Checked on dinging and on entering the world. The second is not redundant:
-- a character can reach the cap with the addon disabled, or on a session where
-- this file errored, and a run that silently refused to end would look exactly
-- like a reward that does not work.
function Challenge.CheckCompletion(level)
    local run = Challenge.Current()
    if not run or run.broken then return false end
    if not Challenge.AtMaxLevel(level) then return false end
    local ok, record = Challenge.Complete(level)
    if not ok or type(record) ~= "table" then return false end

    if record.completed and run.rewards then
        local parts = {}
        local Language, Accent = ns.Language, ns.Accent
        if run.rewards.language and Language and Language.GetLanguageName then
            parts[#parts + 1] = "|cff00ff00"
                .. Language.GetLanguageName(run.rewards.language) .. "|r"
        end
        if run.rewards.accent and Accent and Accent.GetAccentName then
            parts[#parts + 1] = "the |cff00ff00"
                .. Accent.GetAccentName(run.rewards.accent) .. "|r accent"
        end
        if #parts > 0 then
            record.rewardText = "Unlocked on every character: "
                .. table.concat(parts, " and ")
                .. ". Both are yours to switch off now, which is the other half "
                .. "of earning them."
        end
    end
    announceCompletion(record)
    return true
end

--=========================================================================--
--  Locks
--=========================================================================--
-- Only what changes the difficulty. Toast style, colours, accents, the
-- minimap button, cast phrases and the rest stay live, because locking them
-- costs the player something and buys the challenge nothing -- nobody ever
-- made a run easier by picking a different toast.
--
-- These stay locked on a voided run. Unlocking on void would make breaking
-- the run the fastest way to get your settings back, which is a strange thing
-- to reward; abandoning is right there and gives everything back at once.
local LOCKED = {
    fullImmersion          = true,
    immersionNPCs          = true,
    immersionQuests        = true,
    immersionTracker       = true,
    immersionGossipOptions = true,
    passiveLearning        = true,
    questLearning          = true,
    motherTongue           = true,
    -- Not settings but actions, locked for the same reason: each one is a
    -- direct write to the number the whole run is measuring.
    fluency                = true,
    learned                = true,
    profile                = true,
}

-- Locked if every tier locks it, or if this run's own tier pinned it.
--
-- The second half is what keeps Mythic's extra locks off the other three. The
-- static list above is shared by every tier and adding `inCharacter` to it
-- would take the mute switch away from somebody on Easy, who has no use for a
-- lock on it -- their speech is English either way. Reading the run's own
-- locks instead means a tier locks exactly what its settings pin, and a tier
-- added later locks its own without touching this function.
--
-- Compared against nil rather than tested for truth, because a pinned setting
-- may legitimately be `false` -- Mythic pins `channels.EMOTE` off -- and
-- `LOCKED[key]` style truthiness would report the one deliberately-off lock as
-- unlocked.
function Challenge.IsLocked(key)
    local run = Challenge.Current()
    if not run then return false end
    if LOCKED[key or ""] then return true end
    local locks = run.locks
    return (type(locks) == "table" and locks[key or ""] ~= nil) and true or false
end

-- One line, used by every panel and slash command that refuses something, so
-- the reason reads the same everywhere.
function Challenge.LockReason()
    local run = Challenge.Current()
    if not run then return nil end
    local def = Challenge.Definition(run.id)
    return "Locked by the " .. ((def and def.name) or run.id) .. " challenge."
end

--=========================================================================--
--  The tripwire
--=========================================================================--
local BROKEN_WHY = {
    fullImmersion          = "full immersion was switched off",
    immersionNPCs          = "NPC speech was switched off",
    immersionQuests        = "quest text was switched off",
    immersionTracker       = "the objective tracker was changed",
    immersionGossipOptions = "the gossip list was changed",
    questLearning          = "learning from quests was switched off",
    passiveLearning        = "passive learning was changed",
    inCharacter            = "speaking in character was switched off",
    motherTongue           = "the native dialect was changed",
    ["accent.id"]          = "the accent was changed",
}

-- Eleven channels would be eleven near-identical lines in the table above, and
-- the fallback ("channels.RAID_WARNING was changed") names a saved-variable
-- path at somebody who was looking at a checkbox. Matched rather than listed
-- so a channel added to Core later reads properly here without being added
-- twice.
local function brokenWhy(key)
    if BROKEN_WHY[key] then return BROKEN_WHY[key] end
    local channel = key and key:match("^channels%.(.+)$")
    if channel then return "the " .. channel .. " channel was changed" end
    return tostring(key) .. " was changed"
end

-- Keeps the record's level honest without needing an event for it. Called
-- from the audit, which runs often enough.
function Challenge.Touch()
    local run = Challenge.Current()
    if not run then return end
    local level = playerLevel()
    if level then run.level = level end
end

function Challenge.Audit()
    local run = Challenge.Current()
    if not run then return true end
    Challenge.Touch()
    if run.broken then return false, run.brokenKey end

    -- Sorted rather than pairs(), so two keys moved at once always name the
    -- same one. An audit that reports a different culprit each time it runs
    -- is worse than one that reports none.
    local keys = {}
    for key in pairs(run.locks or {}) do keys[#keys + 1] = key end
    table.sort(keys)

    for i = 1, #keys do
        local key = keys[i]
        if readSetting(key) ~= run.locks[key] then
            run.broken      = true
            run.brokenKey   = key
            run.brokenWhy   = brokenWhy(key)
            run.brokenLevel = run.level
            return false, key
        end
    end
    return true
end

-- Said in full so the panel and the chat message cannot disagree.
function Challenge.BrokenText()
    local run = Challenge.Current()
    if not run or not run.broken then return nil end
    local at = run.brokenLevel and (" at level " .. run.brokenLevel) or ""
    return "Voided" .. at .. ": " .. (run.brokenWhy or "a locked setting changed")
end

--=========================================================================--
--  Counting
--=========================================================================--
-- Called by QuestLearn when a hand-in actually taught something. Counting
-- quests finished rather than quests accepted, because the first is the thing
-- the run is made of and the second is a number you can inflate by walking
-- around a quest hub.
-- How many hand-ins one word costs on the run in progress. One outside a
-- run, which is the whole of how this reaches anybody who is not in one.
--
-- The tiers differ here because their descriptions say they do: a quest on
-- Easy, quests on Medium, a handful of quests on Hard. It is the only dial
-- that changes how long a run takes rather than how much of it you can
-- read, and it is deliberately the last thing in the list -- a tier that
-- merely took longer would not be a harder tier, it would be a slower one.
function Challenge.WordCost()
    local run = Challenge.Current()
    local cost = run and run.wordCost
    if type(cost) ~= "number" or cost < 1 then return 1 end
    return cost
end

function Challenge.NoteQuest()
    local run = Challenge.Current()
    if not run then return end
    run.quests = (tonumber(run.quests) or 0) + 1
    Challenge.Touch()
end

--=========================================================================--
--  Becoming intelligible
--=========================================================================--
-- How much of Legendspeech a Mythic runner has left, 0-100, for the engine to
-- gate their native dialect by. Nil on every other tier and outside a run,
-- which is read as "spoken perfectly" -- an unlocked Legendspeech is an
-- ordinary tongue and does not drain.
--
-- Squared, which is the whole of the tuning and the one number worth arguing
-- about. Linear made the first words legible almost immediately: a dozen
-- hand-ins is a few percent of a tongue, and a few percent of your words
-- arriving in English reads as the feature being broken rather than as
-- progress. Squaring holds the line nearly opaque through the early zones --
-- a quarter of the way to fluent still leaves 94% of the sentence foreign --
-- and then opens quickly over the back half, which is where "they could not
-- understand me until I had nearly finished" actually lives.
--
-- A client that cannot yet say which tongues it speaks returns full strength.
-- Erring toward opaque is the safe direction: an hour of being harder to read
-- than intended is a worse run, while an hour of being legible by accident is
-- the run not happening.
function Challenge.MotherStrength()
    local run = Challenge.Current()
    if not (run and run.drainsTongue) then return nil end

    local progress = ns.FactionProgress and ns.FactionProgress() or nil
    if type(progress) ~= "number" then return 100 end
    if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

    local strength = 100 * (1 - progress * progress)
    if strength < 0 then strength = 0 elseif strength > 100 then strength = 100 end
    return strength
end

-- The same thing from the reader's side, which is what the panel shows: the
-- share of your words that now leave as plain English. Two numbers rather than
-- one because they answer different questions -- how well you know the locals,
-- and how much of that has reached your mouth -- and a panel showing only the
-- second makes the first look like it is doing nothing for the first few hours.
--
-- Returns nil, nil when no run is draining anything, so a caller can tell
-- "nothing to report" from "nothing learned yet".
function Challenge.Intelligibility()
    local run = Challenge.Current()
    if not (run and run.drainsTongue) then return nil, nil end
    local progress = ns.FactionProgress and ns.FactionProgress() or nil
    if type(progress) ~= "number" then progress = 0 end
    if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
    return progress, progress * progress
end

--=========================================================================--
--  The record
--=========================================================================--
-- The part worth a screenshot. Returns a plain table so the panel, the slash
-- command and the tests all read the same numbers.
function Challenge.Record(run)
    run = run or Challenge.Current()
    if not run then return nil end
    local def  = Challenge.Definition(run.id)
    local diff = Challenge.Difficulty(run.id, run.difficulty)

    local record = {
        id         = run.id,
        name       = (def and def.name) or run.id,
        difficulty = (diff and diff.label) or run.difficulty,
        startedAt  = run.startedAt,
        startLevel = run.startLevel,
        level      = run.level,
        quests     = tonumber(run.quests) or 0,
        broken     = run.broken and true or false,
        brokenWhy  = run.brokenWhy,
        brokenLevel = run.brokenLevel,
        -- Rides onto the record so the status line can say so. A debug run is
        -- allowed to be unimpressive; it is not allowed to be indistinguishable
        -- from one somebody actually played, which is the same courtesy the
        -- tripwire extends to a voided run.
        debug      = run.debug and true or false,
        tongues    = {},
    }

    -- The spread, which is the interesting half. A run does not end with one
    -- bar full, it ends with a shape -- fluent in one tongue, halfway through
    -- another, a dozen words of a third -- and that shape is where you went.
    local Language = ns.Language
    local trainer  = ns.Trainer
    if Language and Language.GetPrimaryLanguages and trainer and trainer.GetProgress then
        local langs = Language.GetPrimaryLanguages() or {}
        for i = 1, #langs do
            local id = langs[i].id
            local ok, _, _, frac = pcall(trainer.GetProgress, id)
            frac = ok and tonumber(frac) or nil
            if frac and frac > 0 then
                record.tongues[#record.tongues + 1] = {
                    id      = id,
                    name    = (Language.GetLanguageName and Language.GetLanguageName(id))
                              or langs[i].name or id,
                    percent = math.floor(frac * 100 + 0.5),
                }
            end
        end
        table.sort(record.tongues, function(a, b)
            if a.percent ~= b.percent then return a.percent > b.percent end
            return a.name < b.name
        end)
    end

    return record
end

function Challenge.LastRecord()
    local db = GlyphicDB
    local last = db and db.challengeLast
    return (type(last) == "table" and last.id) and last or nil
end

--=========================================================================--
--  Events
--=========================================================================--
-- One event, because the audit is cheap and the other call site is
-- OnSettingsChanged, which fires on every write a panel makes. Between them
-- they cover a switch flipped in the options and a saved-variable file edited
-- between sessions.
--
-- CVAR_UPDATE is the second, and it is the whole of the console-variable
-- lock: those live in Blizzard's options where nothing here can grey out a
-- checkbox, so the only way to hold one is to notice it moved and move it
-- back. Cheap enough -- it fires on a settings change, not on a timer.
-- The quest events are the third, and they are the whole of the tracker
-- lock. The tracker puts itself back on screen whenever your quests change,
-- and the alternative to listening for that is writing a hook onto the
-- frame -- which is what tainted it. These fire often and cost nothing when
-- no run wants the tracker gone, since the first thing the handler does is
-- ask.
local TRACKER_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED",
    "QUEST_REMOVED", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA",
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "CVAR_UPDATE")
-- The whole of how a run ends by being finished. One event, fired once per
-- level, and the only one that can tell us the run is over.
pcall(frame.RegisterEvent, frame, "PLAYER_LEVEL_UP")
for i = 1, #TRACKER_EVENTS do
    pcall(frame.RegisterEvent, frame, TRACKER_EVENTS[i])
end

local TRACKER_ONLY = {}
for i = 1, #TRACKER_EVENTS do TRACKER_ONLY[TRACKER_EVENTS[i]] = true end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "CVAR_UPDATE" then
        Challenge.EnforceCVars()
        return
    end
    if event == "PLAYER_LEVEL_UP" then
        -- arg1 is the new level, which UnitLevel may not be reporting yet.
        Challenge.CheckCompletion(tonumber(arg1))
        return
    end
    if TRACKER_ONLY[event] then
        -- Quests changing is not a settings change. Auditing here would run
        -- the whole lock check several times a quest for nothing.
        Challenge.EnforceTracker()
        return
    end
    Challenge.Audit()
    -- After the audit, so a run whose locks were broken between sessions is
    -- marked voided before this asks whether to pay it out.
    Challenge.CheckCompletion()
    Challenge.EnforceCVars()
    -- Done here rather than at load: the tracker belongs to Blizzard's own
    -- addon, which on some flavours has not loaded yet when this file runs.
    Challenge.EnforceTracker()
end)

function Challenge._Frame() return frame end

--=========================================================================--
--  Debug
--=========================================================================--
-- Undocumented on purpose: absent from `usage()`, reached only through
-- `/glyphic challenge debug ...`. Not hidden for integrity's sake, because
-- there is none to protect -- the locking is an honour system over a text file
-- on the player's own disk, as the header says, and anyone who wants
-- Legendspeech without earning it has an easier route than this through a text
-- editor. They are undocumented because they are meaningless to a player: the
-- only thing they are good for is seeing in minutes what a run reveals over
-- sixty levels.
--
-- What they exist to defeat is that this feature is almost impossible to
-- observe honestly. Entry demands a character nobody has played, the payout
-- demands the level cap, and the interesting part -- the reveal curve -- is
-- three hundred quest hand-ins wide. Every one of those is a day of play per
-- data point.
--
-- A run finished this way is marked. `run.debug` rides onto the record and the
-- status line says so, which is the same courtesy the tripwire extends to a
-- voided run: the record is allowed to be unimpressive but not to be untrue.

-- Start a tier on a character that would be refused. Abandons a run in
-- progress first, properly, rather than writing over it: `before` is how
-- abandoning puts settings back, and a second Start on top of a live run
-- would capture the first run's forced values as the originals and strand
-- them permanently.
function Challenge.DebugStart(difficultyId)
    if Challenge.Current() then Challenge.Abandon() end
    debugBypass = true
    local ok, why = Challenge.Start(Challenge.DEFAULT, difficultyId)
    debugBypass = false
    if ok then
        local run = Challenge.Current()
        if run then run.debug = true end
    end
    return ok, why
end

-- Put the character at a given faction fluency, 0-1, which is the dial the
-- whole tier turns on.
--
-- Writes through the trainer rather than ns.SetLanguageFluency, which would
-- refuse: fluency is locked for the length of a run, and that lock is exactly
-- what makes this unobservable in play. Setting every native tongue to the
-- same fraction lands the weighted aggregate on that fraction, because a
-- weighted mean of one repeated value is that value whatever the weights.
function Challenge.DebugSetProgress(frac)
    frac = tonumber(frac) or 0
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    local natives = ns.NativeLanguageIds and ns.NativeLanguageIds() or {}
    if #natives == 0 then return nil, "the client has not said which tongues this character speaks" end
    if not (ns.Trainer and ns.Trainer.SetFluency) then
        return nil, "the trainer is not loaded"
    end
    for i = 1, #natives do
        pcall(ns.Trainer.SetFluency, natives[i].id, frac)
        if frac >= 1 then
            GlyphicDB.learned = GlyphicDB.learned or {}
            GlyphicDB.learned[natives[i].id] = true
        elseif GlyphicDB.learned then
            GlyphicDB.learned[natives[i].id] = nil
        end
    end
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return ns.FactionProgress and ns.FactionProgress() or nil
end

-- Finish the run here, at whatever level this character happens to be.
function Challenge.DebugFinish()
    local run = Challenge.Current()
    if not run then return false, "no challenge is running" end
    run.debug = true
    debugBypass = true
    local ok = Challenge.CheckCompletion()
    debugBypass = false
    return ok
end

-- Hand the rewards back, so the hidden state can be tested again without a
-- reload. Both halves: the account flags and the registry visibility.
function Challenge.DebugRelock()
    local given = {}
    local diff = Challenge.Difficulty(Challenge.DEFAULT, "mythic")
    local rewards = diff and diff.rewards or {}
    if rewards.language and ns.RevokeUnlock then
        ns.RevokeUnlock("languages", rewards.language)
        given[#given + 1] = rewards.language
    end
    if rewards.accent and ns.RevokeUnlock then
        ns.RevokeUnlock("accents", rewards.accent)
        given[#given + 1] = rewards.accent
    end
    -- The accent and native dialect may still be selected, and a hidden one
    -- stays selected quite happily -- which would leave somebody speaking a
    -- tongue that is no longer in any list and look like the relock failed.
    if GlyphicDB then
        if GlyphicDB.motherTongue == rewards.language then GlyphicDB.motherTongue = nil end
        if GlyphicDB.accent and GlyphicDB.accent.id == rewards.accent then
            GlyphicDB.accent.id = (ns.Accent and ns.Accent.NONE) or "none"
        end
        if GlyphicDB.language == rewards.language then
            GlyphicDB.language = (ns.Language and ns.Language.DEFAULT) or "none"
        end
        if GlyphicDB.learned then GlyphicDB.learned[rewards.language] = nil end
        if ns.Trainer and ns.Trainer.ResetFluency then
            pcall(ns.Trainer.ResetFluency, rewards.language)
        end
    end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return given
end

-- Every number the tier turns on, in one place, with the sentence they
-- produce. The last line is the point of the whole report: the numbers are
-- only interesting as a prediction of what somebody else reads.
function Challenge.DebugReport()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local run = Challenge.Current()
    if run then
        add("run: " .. tostring(run.id) .. " / " .. tostring(run.difficulty)
            .. ", level " .. tostring(run.level) .. ", " .. tostring(run.quests)
            .. " quests" .. (run.debug and "  |cffff8080(debug)|r" or "")
            .. (run.broken and ("  |cffff4040voided: " .. tostring(run.brokenWhy) .. "|r") or ""))
        add("native dialect: " .. tostring(run.drainsTongue or "none")
            .. ", drains: " .. tostring(run.drainsTongue ~= nil))
    else
        local last = Challenge.LastRecord()
        add("run: none" .. (last and (last.completed
            and ("  (last: completed " .. tostring(last.difficulty)
                 .. " at " .. tostring(last.level) .. ")")
            or ("  (last: gave up on " .. tostring(last.difficulty) .. ")")) or ""))
    end

    local natives = ns.NativeLanguageIds and ns.NativeLanguageIds() or {}
    if #natives == 0 then
        add("native tongues: |cffff4040none reported by the client|r")
    else
        local QL, trainer = ns.QuestLearn, ns.Trainer
        for i = 1, #natives do
            local vocab = QL and QL.Vocabulary and select(2, pcall(QL.Vocabulary, natives[i].blizzId))
            local frac = trainer and trainer.GetProgress
                and select(4, pcall(trainer.GetProgress, natives[i].id))
            add(string.format("  %s: %d%% of %s words", natives[i].id,
                math.floor((tonumber(frac) or 0) * 100 + 0.5),
                tostring(tonumber(vocab) or "?")))
        end
    end

    local progress = ns.FactionProgress and ns.FactionProgress()
    add("faction progress: " .. (progress
        and (math.floor(progress * 100 + 0.5) .. "%") or "nil"))
    local strength = Challenge.MotherStrength()
    add("native dialect strength: " .. (strength
        and (math.floor(strength + 0.5) .. "%") or "nil (spoken perfectly)"))
    local _, english = Challenge.Intelligibility()
    add("read as English: " .. (english
        and (math.floor(english * 100 + 0.5) .. "%") or "n/a"))

    if ns.EncodeSpeech then
        local sample = "I am looking for the road to the mountain pass, and I can pay well for a guide."
        local ok, out = pcall(ns.EncodeSpeech, sample, false)
        if ok and type(out) == "string" then add("sample: " .. out) end
    end
    return lines
end
