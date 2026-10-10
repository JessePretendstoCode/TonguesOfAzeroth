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

-- ...and what one hand-in is worth, which is the same thing outside a
-- challenge and a fraction of it inside a hard one. Kept apart from
-- WordValue because that answers "how big is a word" and is read by the
-- counting below, where this answers "how much of one did that quest buy".
function QuestLearn.QuestValue(blizzId)
    local value = QuestLearn.WordValue(blizzId)
    if value <= 0 then return 0 end
    local cost = 1
    if ns.Challenge and type(ns.Challenge.WordCost) == "function" then
        local ok, n = pcall(ns.Challenge.WordCost)
        if ok and type(n) == "number" and n >= 1 then cost = n end
    end
    return value / cost
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

--=========================================================================--
--  What the word means
--=========================================================================--
-- Blizzard's word lists have no meanings. "Mog" is not the Orcish for
-- anything -- the tables are a bag of tokens the client swaps in, and
-- nothing in the game data says what any of them stands for. So a toast
-- that simply announced "Mog" was naming a token, and one that claimed
-- "Mog = tree" out of nowhere would be inventing a dictionary.
--
-- There is a true answer, though, because the substitution runs the other
-- way and is deterministic. Immersion.Garble hashes the ENGLISH word, and
-- feeds that same hash back to pick the replacement, so "tree" renders as
-- exactly one Taur-ahe token every time. Start from the English side and
-- the pair is a fact rather than a guess.
--
-- Better still, the same hash decides legibility: a word comes through
-- clear once Hash(word) % 300 is under your skill, and skill is fluency x 3.
-- So the English words have a fixed unlock order, and "the word you just
-- learned" is a thing the system can actually answer -- the next one over
-- that line. The toast is not describing the mechanic, it is reading it.
--
-- Note the pair is many-to-one: other English words hash into the same
-- token, so "Mog" is how "tree" looks, not a word that uniquely means tree.
-- The toast says it in that direction for exactly this reason.
local lexicons = {}

-- Short words make a poor trophy -- "Mog = at" is technically a lesson and
-- reads like a glitch. This only decides which of the legible words gets
-- named, never which ones are legible, so filtering here cannot make the
-- toast untrue.
local MIN_WORD = 4

function QuestLearn.Lexicon(blizzId)
    if lexicons[blizzId] then return lexicons[blizzId] end

    local Immersion = ns.Immersion
    local words = ns.CommonWords
    if type(words) ~= "table" or not Immersion
        or type(Immersion.Hash) ~= "function"
        or type(Immersion.Garble) ~= "function" then
        return nil
    end
    if type(Immersion.HasWords) == "function" and not Immersion.HasWords(blizzId) then
        return nil
    end

    local full = Immersion.FULL_SKILL or 300
    local seen, list = {}, {}
    for i = 1, #words do
        local plain = words[i]
        if type(plain) == "string" and #plain >= MIN_WORD and not seen[plain] then
            seen[plain] = true
            -- Skill 0 forces the substitution, which is how the word looks to
            -- someone who knows none of the tongue.
            local ok, garbled = pcall(Immersion.Garble, plain, blizzId, 0)
            -- A word the tongue has no bucket for comes back unchanged. That
            -- is not a translation and must not be shown as one.
            if ok and type(garbled) == "string" and garbled ~= plain then
                list[#list + 1] = {
                    plain = plain,
                    garbled = garbled,
                    gate = Immersion.Hash(plain) % full,
                }
            end
        end
    end
    if #list == 0 then return nil end

    -- Unlock order. Ties broken by the word, because table.sort is not
    -- stable and two words sharing a gate would otherwise swap places
    -- between clients.
    table.sort(list, function(a, b)
        if a.gate ~= b.gate then return a.gate < b.gate end
        return a.plain < b.plain
    end)
    lexicons[blizzId] = list
    return list
end

-- The word that goes with a given amount of fluency: the last one your skill
-- has carried over the line. Derived from the fluency rather than stored
-- alongside it, so there is one number to be wrong rather than two that can
-- disagree -- and so a tongue you raised in the trainer carries on from
-- where that left it.
--
-- Returns the English word and the token it appears as. Nil when the tongue
-- has no lexicon, and nil when your skill has not reached the first word
-- yet, which is honest: at that point you have not learned one.
function QuestLearn.WordFor(blizzId, frac)
    local list = QuestLearn.Lexicon(blizzId)
    if not list then return nil end

    local full = (ns.Immersion and ns.Immersion.FULL_SKILL) or 300
    local skill = (tonumber(frac) or 0) * full

    -- Walk rather than binary-search: a few hundred entries once per quest.
    local found
    for i = 1, #list do
        if list[i].gate < skill then found = list[i] else break end
    end
    if not found then return nil end
    return found.plain, found.garbled
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

    local value = QuestLearn.QuestValue(blizzId)
    if value <= 0 then return nil end

    if not QuestLearn.Teaches(questLevel) then return nil end

    local _, _, before = ns.Trainer.GetProgress(glyphId)
    before = tonumber(before) or 0
    if before >= 1 then return nil end

    ns.Trainer.AddFluency(glyphId, value)
    local _, _, after = ns.Trainer.GetProgress(glyphId)
    after = tonumber(after) or before

    -- The count is the tongue's own size, not the lexicon's: it answers "how
    -- many quests until this is fluent", which is what the bar underneath is
    -- measuring. The word named above it comes from the English lexicon and
    -- is a separate question.
    local total = QuestLearn.Vocabulary(blizzId) or 0
    local learned = math.floor(after * total + 0.5)

    -- On a tier where a word costs several hand-ins, most hand-ins buy part
    -- of one. Naming a word anyway would name the same word four times over
    -- and then name the next one, which reads as the addon repeating itself
    -- rather than as progress. So the toast gets the count and no lesson,
    -- which is the true thing to say: you are closer.
    --
    -- Compared before the clamp below, which exists so the toast never says
    -- "0 of 100" and would otherwise report the first hand-in of five as a
    -- whole word earned.
    local partial = learned == math.floor(before * total + 0.5)

    -- The floor is for a whole word only. Rounding a part-word up would
    -- show "1 of 100" on each of the first four hand-ins and then show it
    -- again on the fifth, so the one that actually earned the word is the
    -- one that looks like nothing happened.
    if learned < 1 and not partial then learned = 1
    elseif learned > total then learned = total end

    local plain, garbled
    if not partial then plain, garbled = QuestLearn.WordFor(blizzId, after) end

    -- Counted here rather than on the event, so the run's tally is quests
    -- that actually taught something. Everything above this line is a reason
    -- a hand-in teaches nothing -- wrong level, no tongue recorded, already
    -- fluent -- and none of those is progress worth writing down.
    if ns.Challenge and type(ns.Challenge.NoteQuest) == "function" then
        ns.Challenge.NoteQuest()
    end

    return {
        blizzId = blizzId,
        glyphId = glyphId,
        word = garbled,
        plain = plain,
        partial = partial,
        learned = learned,
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
