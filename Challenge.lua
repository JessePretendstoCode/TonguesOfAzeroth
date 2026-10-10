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

-- Low enough that the hard part cannot be skipped, high enough to admit a
-- retail character who starts at 10 off the back of Exile's Reach.
Challenge.MAX_START_LEVEL = 10

local function playerLevel()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    if ok and type(level) == "number" and level > 0 then return level end
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
local STRANGER_BASE = {
    fullImmersion   = true,
    immersionNPCs   = true,
    immersionQuests = true,
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

local CHALLENGES = {
    stranger = {
        id    = "stranger",
        name  = "Stranger",
        blurb = "You arrive understanding nobody. Every quest and every NPC "
             .. "is in a tongue you do not speak, and the only way out is to "
             .. "work for the people who speak it.",
        order = { "easy", "medium", "hard" },
        difficulties = {
            easy = {
                id    = "easy",
                label = "Easy",
                blurb = "Quest text, gossip and NPC speech are hidden. Your "
                     .. "objectives stay readable, so you always know what to "
                     .. "do -- just never why.",
                settings = tier({
                    immersionTracker        = false,
                    immersionGossipOptions  = false,
                }),
            },
            medium = {
                id    = "medium",
                label = "Medium",
                blurb = "Your objective tracker and quest log go with it. "
                     .. "Working out the job is now part of the job.",
                settings = tier({
                    immersionTracker        = true,
                    immersionGossipOptions  = false,
                }),
            },
            hard = {
                id    = "hard",
                label = "Hard",
                blurb = "Everything, including what you click to answer an "
                     .. "NPC. Finding the class trainer's menu is on you.",
                settings = tier({
                    immersionTracker        = true,
                    immersionGossipOptions  = true,
                }),
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
    return {
        {
            key  = "level",
            text = "Level " .. Challenge.MAX_START_LEVEL .. " or below",
            met  = (level ~= nil) and (level <= Challenge.MAX_START_LEVEL),
            detail = level and ("you are level " .. level) or nil,
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

function Challenge.CanStart(id)
    if not Challenge.Definition(id) then return false, "no such challenge" end
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
    for key in pairs(settings) do before[key] = GlyphicDB[key] end

    -- The wipe. A challenge that started on top of an existing character's
    -- fluency would be measuring somebody else's run.
    if ns.ResetAllFluency then ns.ResetAllFluency() end
    GlyphicDB.learned = {}
    -- Which tongue each quest was offered in. Cleared because the entries
    -- belong to quests taken before the run, and a journal half in English is
    -- not the thing being attempted.
    GlyphicDB.questLangs = {}

    for key, value in pairs(settings) do GlyphicDB[key] = value end

    local level = playerLevel()
    GlyphicDB.challenge = {
        id         = id,
        difficulty = difficultyId,
        startedAt  = today(),
        startLevel = level,
        level      = level,
        quests     = 0,
        before     = before,
        locks      = settings,
        broken     = false,
    }

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
        GlyphicDB[key] = before[key]
    end
    GlyphicDB.challenge = nil

    if ns.QuestText and ns.QuestText.Refresh then ns.QuestText.Refresh() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
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

function Challenge.IsLocked(key)
    if not Challenge.Active() then return false end
    return LOCKED[key or ""] and true or false
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
}

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
        if GlyphicDB[key] ~= run.locks[key] then
            run.broken      = true
            run.brokenKey   = key
            run.brokenWhy   = BROKEN_WHY[key] or (key .. " was changed")
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
function Challenge.NoteQuest()
    local run = Challenge.Current()
    if not run then return end
    run.quests = (tonumber(run.quests) or 0) + 1
    Challenge.Touch()
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
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    Challenge.Audit()
end)

function Challenge._Frame() return frame end
