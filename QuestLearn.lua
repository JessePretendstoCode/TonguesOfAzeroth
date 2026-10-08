--[[-------------------------------------------------------------------------
    Glyphic - QuestLearn.lua
    Earning a tongue by working for the people who speak it.

    Fluency has two other sources and neither of them survives the way a lot
    of people actually play. The trainer is a minigame you have to go and sit
    down at. Overhearing only counts other players' tagged speech, so a solo
    character in a quiet zone can play for a week and learn nothing -- and
    under full immersion that is the character who most needs a way up, since
    every word around them is already hidden.

    Quests are the third source, and the one that happens while you are just
    playing. Finish a job for somebody and you come away with one word of the
    tongue they gave it to you in.

    One word is a literal quantity here, not a figure of speech. Fluency is
    already "what fraction of the words come through clear" -- the garbler
    lets a word past when its hash falls under your skill -- so one word out
    of a tongue's vocabulary is exactly 1/N fluency, and N is the size of
    that tongue's word table. Orcish has 100 words, so Orcish takes 100
    quests. Zandali has 77 and Gnomish 128, and those take 77 and 128. The
    answer to "how long is this going to take" is written in the word list
    rather than picked out of the air, which is why there is no tunable here.

    Which quests count is the game's own question about which quests are
    worth doing. Below the level cap a quest has to be green or better --
    the band that still pays experience -- so you cannot farm a starting zone
    at 40 for a hundred easy words. That band widens as you level, because
    GetQuestGreenRange widens, so the rule keeps meaning the same thing.

    At the cap it inverts: nothing pays experience up there, so the same rule
    would switch the feature off at exactly the level most roleplayers live
    at. So at the cap everything counts. You are not outlevelling anything
    any more, and a level 60 who wants Darnassian can go and earn it in
    Darnassian zones.

    A quest with no recorded tongue teaches nothing, and that is two cases
    rather than an oversight. One taken before any of this was switched on
    has no giver left to ask. One with nobody behind it -- off an item, a
    bulletin board, a walk into a valley -- had no speaker to learn from in
    the first place. Neither is a tongue, so neither is a word.
---------------------------------------------------------------------------]]

local _, ns = ...

local QuestLearn = {}
ns.QuestLearn = QuestLearn

--=========================================================================--
--  How big is a tongue
--=========================================================================--
-- Counted distinct, because the point of the number is "how many words are
-- there to know" and a word listed twice is still one word. Blizzard's table
-- is bucketed by length, so a tongue is the union of its buckets.
local sizes = {}

function QuestLearn.Vocabulary(blizzId)
    if type(blizzId) ~= "number" then return nil end
    if sizes[blizzId] ~= nil then return sizes[blizzId] or nil end

    local words = ns.BlizzardWords and ns.BlizzardWords[blizzId]
    if type(words) ~= "table" then
        sizes[blizzId] = false
        return nil
    end
    local seen, n = {}, 0
    for _, bucket in pairs(words) do
        if type(bucket) == "table" then
            for i = 1, #bucket do
                local word = bucket[i]
                if type(word) == "string" and not seen[word] then
                    seen[word] = true
                    n = n + 1
                end
            end
        end
    end
    sizes[blizzId] = (n > 0) and n or false
    return (n > 0) and n or nil
end

-- What one word is worth as fluency. The whole design is this line.
function QuestLearn.WordValue(blizzId)
    local n = QuestLearn.Vocabulary(blizzId)
    if not n then return 0 end
    return 1 / n
end

-- A stable arbitrary order over a tongue's words, so the toast can name the
-- one you just picked up. Sorted by a hash rather than by length, or you
-- would spend your first twenty quests learning single letters. Sorted at all
-- rather than shuffled, so the same character learns the same words in the
-- same order on every machine and a test can say which word is third.
local orders = {}

-- djb2 on its own is monotonic in length -- every one-letter word hashes to
-- about 5381*33, every two-letter one to about thirty times that -- so
-- sorting by it is sorting by length with extra steps, and Orcish's first
-- five words come out "A", "N", "G", "O", "L". The multiply-and-wrap
-- afterwards spreads the short ones through the rest. The multiplier is kept
-- under 2^21 so the product stays inside a double's exact integer range,
-- which is all Lua 5.1 has.
local function wordHash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 2147483648
    end
    return (h * 2097143 + 12345) % 2147483648
end

function QuestLearn.WordOrder(blizzId)
    if orders[blizzId] then return orders[blizzId] end
    local words = ns.BlizzardWords and ns.BlizzardWords[blizzId]
    if type(words) ~= "table" then return nil end

    local seen, flat = {}, {}
    for _, bucket in pairs(words) do
        if type(bucket) == "table" then
            for i = 1, #bucket do
                local word = bucket[i]
                if type(word) == "string" and not seen[word] then
                    seen[word] = true
                    flat[#flat + 1] = word
                end
            end
        end
    end
    if #flat == 0 then return nil end
    -- Ties broken by the word itself. Nothing in Blizzard's tables collides,
    -- so this branch does not currently run -- but table.sort is not stable,
    -- and if a future word ever did collide the pair's order would fall back
    -- to however pairs() happened to walk the buckets, which differs between
    -- clients. Cheaper to break the tie than to find out that way.
    table.sort(flat, function(a, b)
        local ha, hb = wordHash(a), wordHash(b)
        if ha ~= hb then return ha < hb end
        return a < b
    end)
    orders[blizzId] = flat
    return flat
end

-- The word that goes with a given amount of fluency. Derived from the
-- fluency rather than stored alongside it, so there is one number to be
-- wrong rather than two that can disagree -- and so a tongue you raised in
-- the trainer carries on from where that left it.
function QuestLearn.WordFor(blizzId, frac)
    local flat = QuestLearn.WordOrder(blizzId)
    if not flat then return nil end
    local n = math.floor((tonumber(frac) or 0) * #flat + 0.5)
    if n < 1 then n = 1 elseif n > #flat then n = #flat end
    return flat[n], n, #flat
end

--=========================================================================--
--  Which quests count
--=========================================================================--
-- The cap, asked of the client rather than written down here. Hardcoding 60
-- and 90 would be two numbers to come back and edit, and they would be wrong
-- on exactly the flavour nobody tested.
function QuestLearn.MaxLevel()
    -- What this account can actually reach first, what the game has released
    -- second. They differ for anyone who hasn't bought the newest expansion,
    -- and their own ceiling is the one that should end their levelling.
    local sources = { GetMaxLevelForPlayerExpansion, GetMaxPlayerLevel }
    for i = 1, #sources do
        if type(sources[i]) == "function" then
            local ok, n = pcall(sources[i])
            if ok and type(n) == "number" and n > 0 then return n end
        end
    end
    return nil
end

function QuestLearn.AtMaxLevel()
    local cap = QuestLearn.MaxLevel()
    if not cap then return false end
    local level = (type(UnitLevel) == "function") and UnitLevel("player") or nil
    if type(level) ~= "number" or level <= 0 then return false end
    return level >= cap
end

-- Green or better. GetQuestGreenRange is the client's own answer to how far
-- below you a quest can be and still pay out, and it widens as you level --
-- five levels at 9, ten at 50 -- so this says "still worth doing" at every
-- level rather than freezing one gap in place.
function QuestLearn.Teaches(questLevel)
    if QuestLearn.AtMaxLevel() then return true end

    -- A quest whose level we could not read. Auto-completing quests and the
    -- odd scripted one never appear in the log to be measured, and refusing
    -- those would quietly drop real quests; letting them through at worst
    -- credits a word somebody was going to earn a minute later anyway.
    if type(questLevel) ~= "number" or questLevel <= 0 then return true end

    local level = (type(UnitLevel) == "function") and UnitLevel("player") or nil
    if type(level) ~= "number" or level <= 0 then return true end

    local green = 0
    if type(GetQuestGreenRange) == "function" then
        local ok, n = pcall(GetQuestGreenRange)
        if ok and type(n) == "number" and n >= 0 then green = n end
    end
    return questLevel >= (level - green)
end

-- A quest's level, while it is still in the log to have one. Read before the
-- turn-in, because by the time the server confirms it the row is gone.
function QuestLearn.QuestLevel(questID)
    if type(questID) ~= "number" or questID <= 0 then return nil end

    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function"
        and type(C_QuestLog.GetInfo) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            local gotInfo, info = pcall(C_QuestLog.GetInfo, index)
            if gotInfo and type(info) == "table" and type(info.level) == "number" then
                return info.level
            end
        end
    end

    if type(GetNumQuestLogEntries) == "function"
        and type(GetQuestLogTitle) == "function" then
        local ok, entries = pcall(GetNumQuestLogEntries)
        if ok and type(entries) == "number" then
            for i = 1, entries do
                -- title, level, ... and the id eighth. Hunting for "the first
                -- number that looks like an id" finds the level instead.
                local got, _, level, _, _, _, _, _, id = pcall(GetQuestLogTitle, i)
                if got and id == questID and type(level) == "number" then
                    return level
                end
            end
        end
    end
    return nil
end

--=========================================================================--
--  Earning it
--=========================================================================--
function QuestLearn.Enabled()
    local db = GlyphicDB
    return (db and db.questLearning) and true or false
end

-- Hands back what was learned so the caller can say so, and nil when nothing
-- was: no tongue on the quest, no vocabulary to draw on, or already fluent.
function QuestLearn.Learn(questID, questLevel)
    if not QuestLearn.Enabled() then return nil end
    if not (ns.QuestText and ns.Trainer
        and type(ns.Trainer.AddFluency) == "function"
        and type(ns.Trainer.GetProgress) == "function") then
        return nil
    end

    -- false (nobody was holding it out) and nil (no record at all) are both
    -- "no tongue to learn", and LanguageForQuest keeps them apart for the
    -- journal's sake rather than ours.
    local blizzId = ns.QuestText.LanguageForQuest(questID)
    if type(blizzId) ~= "number" then return nil end

    local glyphId = ns.NATIVE_LANG_IDS and ns.NATIVE_LANG_IDS[blizzId]
    if not glyphId then return nil end

    local value = QuestLearn.WordValue(blizzId)
    if value <= 0 then return nil end

    if not QuestLearn.Teaches(questLevel) then return nil end

    local _, _, before = ns.Trainer.GetProgress(glyphId)
    before = tonumber(before) or 0
    if before >= 1 then return nil end

    ns.Trainer.AddFluency(glyphId, value)
    local _, _, after = ns.Trainer.GetProgress(glyphId)
    after = tonumber(after) or before

    local word, index, total = QuestLearn.WordFor(blizzId, after)
    return {
        blizzId = blizzId,
        glyphId = glyphId,
        word = word,
        learned = index,
        total = total,
        percent = math.floor(after * 100 + 0.5),
    }
end

--=========================================================================--
--  Events
--=========================================================================--
-- Two events for one moment, because neither has all of it. QUEST_COMPLETE
-- fires with the reward window open, while the quest is still in the log and
-- can be asked its level -- but you have not accepted anything yet and might
-- walk away. QUEST_TURNED_IN is the server confirming you did, and by then
-- the row is gone. So measure at the first and pay out at the second.
local pendingID, pendingLevel

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "QUEST_COMPLETE" then
        pendingID, pendingLevel = nil, nil
        if type(GetQuestID) == "function" then
            local ok, id = pcall(GetQuestID)
            if ok and type(id) == "number" and id > 0 then
                pendingID, pendingLevel = id, QuestLearn.QuestLevel(id)
            end
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        -- The measurement only counts for the quest it was taken from. Two
        -- turn-ins in a row through an auto-complete addon would otherwise
        -- have the second one wearing the first one's level.
        local level = (questID == pendingID) and pendingLevel or nil
        pendingID, pendingLevel = nil, nil

        -- Handed over whatever came back, nil included. Deciding there whether
        -- there is anything to show keeps the decision in one place; checking
        -- it here as well would mean two guards for one question and no way to
        -- tell from outside which of them was doing the work.
        if ns.Toast and type(ns.Toast.Word) == "function" then
            ns.Toast.Word(QuestLearn.Learn(questID, level))
        end
    end
end)

for _, event in ipairs({ "QUEST_COMPLETE", "QUEST_TURNED_IN" }) do
    pcall(frame.RegisterEvent, frame, event)
end

-- Test seams. The harness has no events and no quest log.
function QuestLearn._Frame() return frame end
function QuestLearn._SetPending(id, level) pendingID, pendingLevel = id, level end
