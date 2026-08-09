--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Accent.lua
    Dialect "accents" for chat: instead of replacing words with a constructed
    language (see Language.lua), this rewrites your ENGLISH into a spoken accent,
    e.g. Dwarven "I cannae do this, aye!" or Troll "Stay away from da voodoo, mon."

    An accent is data-driven:
      * words    : whole-word slang/lexical swaps ({ [englishLower] = replacement }).
      * patterns : Lua gsub {pattern, repl} pairs applied to a word (lowercased),
                   e.g. { "ing$", "in'" }, { "^th", "d" }.
      * tails    : occasional sentence-end interjections (", aye!", ", mon.").

    Strength (0-100) controls how thick the accent is: each word is transformed
    only if hash(word) % 100 < strength, so it's deterministic and consistent.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
ns = ns or {}

local Accent = {}
ns.Accent = Accent

local strbyte, strlen, strsub, strupper = string.byte, string.len, string.sub, string.upper
local strlower = string.lower

local function hashString(s)
    local h = 5381
    for i = 1, strlen(s) do
        h = (h * 33 + strbyte(s, i)) % 2147483648
    end
    return h
end

local function isUpper(ch) return ch >= "A" and ch <= "Z" end

local function applyCase(original, out)
    if strlen(original) == 0 or strlen(out) == 0 then return out end
    if strlen(original) > 1 and strupper(original) == original then
        return strupper(out)
    end
    if isUpper(strsub(original, 1, 1)) then
        return strupper(strsub(out, 1, 1)) .. strsub(out, 2)
    end
    return out
end

Accent.DEFAULT = "dwarf"

local ACCENTS = {}
local ORDER = {}
local function reg(id, def)
    def.id = id
    ACCENTS[id] = def
    ORDER[#ORDER + 1] = id
end

--=========================================================================--
--  Accent definitions
--=========================================================================--
reg("dwarf", {
    name = "Dwarven (Scottish)",
    words = {
        you = "ye", your = "yer", my = "me", i = "ah", ["i'm"] = "ah'm",
        ["can't"] = "cannae", cannot = "cannae", ["don't"] = "dinnae",
        ["isn't"] = "isnae", ["wasn't"] = "wasnae", ["doesn't"] = "doesnae",
        of = "o'", ["and"] = "an'", to = "tae", the = "th'", ["not"] = "nae",
        yes = "aye", no = "nae", know = "ken", going = "goin'", doing = "doin'",
        little = "wee", small = "wee", child = "bairn", friend = "laddie",
        good = "braw", man = "lad", woman = "lass", girl = "lass", boy = "lad",
    },
    patterns = { { "ing$", "in'" } },
    tails = { ", aye.", ", lad.", ", ye ken?", ", ah tell ye." },
})

reg("troll", {
    name = "Troll (Patois)",
    words = {
        the = "da", they = "dey", them = "dem", their = "dere", there = "dere",
        this = "dis", that = "dat", those = "dose", these = "dese", ["then"] = "den",
        you = "ya", ["you're"] = "ya", your = "ya", man = "mon", friend = "mon",
        with = "wit", brother = "bruddah", little = "likkle", of = "o'",
    },
    patterns = { { "^th", "d" }, { "ing$", "in'" } },
    tails = { ", mon.", ", ya know?", ", I tell ya.", ", respect." },
})

reg("orc", {
    name = "Orcish (Guttural)",
    words = {
        yes = "zug zug", hello = "lok'tar", friend = "brudda", brother = "brudda",
        strength = "strength", weak = "weakling", human = "pinkskin",
        ["okay"] = "dabu", ok = "dabu", the = "da",
    },
    patterns = {},
    tails = { ", zug zug.", " Lok'tar ogar!", ", dabu.", " Blood and thunder!" },
})

reg("nightelf", {
    name = "Darnassian (Kaldorei)",
    words = {
        you = "thou", your = "thy", ["you're"] = "thou art", are = "art",
        yes = "indeed", hello = "well met", friend = "kaldorei",
        goodbye = "ande'thoras-ethil", night = "night", moon = "Elune's grace",
    },
    patterns = {},
    tails = { ", by Elune.", ", ishnu-alah.", ", child of the stars.", " Elune be with you." },
})

reg("draenei", {
    name = "Draenei (Reverent)",
    words = {
        hello = "the light be with you", yes = "indeed", friend = "brother",
        goodbye = "may the light guide you", thanks = "the naaru bless you",
        good = "radiant", evil = "corrupted",
    },
    patterns = {},
    tails = { ", by the Light.", ", so it is foretold.", " Naaru guide you.", " Peace be upon you." },
})

reg("tauren", {
    name = "Tauren (Earthmother)",
    words = {
        yes = "the earthmother wills it", friend = "little one", hello = "well met",
        earth = "the earthmother", nature = "the wilds", peace = "harmony",
    },
    patterns = {},
    tails = { ", by the Earthmother.", ", little one.", ", walk in harmony.", " An'she guide you." },
})

reg("forsaken", {
    name = "Forsaken (Morbid)",
    words = {
        alive = "breathing", life = "unlife", living = "breathers",
        death = "release", friend = "fellow dead", yes = "of course",
        happy = "content", warm = "cold",
    },
    patterns = {},
    tails = { ", in undeath.", " *groan*", " The Dark Lady watches.", ", heh." },
})

reg("pandaren", {
    name = "Pandaren (Serene)",
    words = {
        yes = "mm, yes", hurry = "patience", fast = "slow and steady",
        angry = "unbalanced", friend = "friend", war = "conflict",
    },
    patterns = {},
    tails = { ", slow down.", ", my friend.", " *sips tea*", " Balance in all things." },
})

reg("goblin", {
    name = "Goblin (Salesman)",
    words = {
        friend = "pal", yes = "yeah yeah", money = "profit", gold = "profit",
        deal = "bargain", buddy = "pal", hello = "heya", great = "profitable",
    },
    patterns = {},
    tails = { ", pal.", ", time is money.", ", heh.", ", trust me." },
})

reg("gilnean", {
    name = "Gilnean (Cockney)",
    words = {
        friend = "guv'nor", hello = "'ello", ["isn't"] = "ain't",
        ["aren't"] = "ain't", the = "th'", my = "me",
        mate = "mate", right = "roight",
    },
    patterns = { { "^h", "'" } },
    tails = { ", guv'nor.", ", right proper.", ", innit.", ", mate." },
})

reg("vrykul", {
    name = "Vrykul (Norse)",
    words = {
        yes = "ja", no = "nej", friend = "warrior", death = "glorious death",
        drink = "mead", hall = "great hall", warrior = "einherjar",
    },
    patterns = {},
    tails = { ", ja.", " Skål!", " For the All-Father!", " Odyn watches!" },
})

reg("pirate", {
    name = "Pirate (Yarr)",
    words = {
        my = "me", you = "ye", your = "yer", is = "be", are = "be",
        yes = "aye", hello = "ahoy", friend = "matey", money = "booty",
        the = "th'", of = "o'", ["you're"] = "ye be",
    },
    patterns = { { "ing$", "in'" } },
    tails = { ", arr.", ", matey.", ", ye scurvy dog!", " Yarr harr!" },
})

--=========================================================================--
--  Public API
--=========================================================================--
local WORD = "[%a][%a']*"

-- At full strength, only about this share of eligible messages get a tail, so
-- interjections stay flavorful instead of tagging every single sentence. The
-- actual chance scales with the accent strength (strength% * this / 100).
local TAIL_MAX_RATE = 30
-- Messages shorter than this many words never get a tail (avoids bolting a
-- flourish onto a one-word reply like "Aye" or "No").
local TAIL_MIN_WORDS = 3

local function wordCount(s)
    local n = 0
    for _ in s:gmatch("%S+") do n = n + 1 end
    return n
end

local function endsWithTerminator(s)
    local last = strsub(s, -1)
    return last == "." or last == "!" or last == "?"
end

-- Attach a tail so it reads naturally. Tails are authored in two styles,
-- auto-detected from their text:
--   * interjection (starts with ",")  -> woven into the last clause:
--         "we attack at dawn"       -> "we attack at dawn, aye."
--         "the gods whisper mad."   -> "the gods whisper mad, aye."
--   * emote        (contains "*")     -> appended verbatim: "... *groan*".
--   * phrase       (anything else)    -> added as its own capitalized sentence:
--         "the gods whisper mad."   -> "the gods whisper mad. Lok'tar ogar!"
local function appendTail(out, tail)
    out = out:gsub("%s+$", "")
    if out == "" then return (tail:gsub("^[%s,%.]+", "")) end

    if tail:find("%*") then
        local emote = tail:gsub("^[%.%s]+", "")
        return out .. " " .. emote
    end

    local trimmed = tail:gsub("^%s+", "")
    if strsub(trimmed, 1, 1) == "," then
        -- Interjection: reduce to its words (+ trailing punctuation).
        local core = trimmed:gsub("^[%s,]+", "")
        local word = core:gsub("[%s%p]+$", "")
        if word == "" then return out end
        if endsWithTerminator(out) then
            local term = strsub(out, -1)
            local body = out:gsub("[%.%!%?]+$", "")
            return body .. ", " .. word .. term
        end
        local endPunct = core:match("([%.%!%?]+)%s*$") or "."
        return out .. ", " .. word .. endPunct
    end

    -- Standalone phrase.
    local phrase = trimmed:gsub("^%a", strupper)
    if not endsWithTerminator(out) then out = out .. "." end
    return out .. " " .. phrase
end

function Accent.Apply(text, id, strength)
    if not text or text == "" then return text end
    strength = strength or 100
    if strength <= 0 then return text end
    local acc = ACCENTS[id or Accent.DEFAULT] or ACCENTS[Accent.DEFAULT]

    local out = text:gsub(WORD, function(word)
        local lower = strlower(word)
        if (hashString(lower) % 100) >= strength then return word end

        local repl = acc.words and acc.words[lower]
        if repl then return applyCase(word, repl) end

        if acc.patterns then
            local w = lower
            for i = 1, #acc.patterns do
                w = w:gsub(acc.patterns[i][1], acc.patterns[i][2])
            end
            if w ~= lower then return applyCase(word, w) end
        end
        return word
    end)

    -- Tails are occasional flourishes, not a stamp on every message: gate them
    -- on a strength-scaled chance and skip very short lines. Deterministic, so a
    -- given message always reads the same way.
    if acc.tails and #acc.tails > 0 and wordCount(text) >= TAIL_MIN_WORDS then
        local chance = math.floor(strength * TAIL_MAX_RATE / 100)
        if (hashString("toa-tail:" .. text) % 100) < chance then
            local idx = (hashString("toa-pick:" .. text) % #acc.tails) + 1
            out = appendTail(out, acc.tails[idx])
        end
    end
    return out
end

function Accent.GetAccents()
    local list = {}
    for i = 1, #ORDER do
        local id = ORDER[i]
        list[i] = { id = id, name = ACCENTS[id].name }
    end
    return list
end

function Accent.GetAccentName(id)
    return ACCENTS[id] and ACCENTS[id].name or "?"
end

function Accent.IsValid(id)
    return ACCENTS[id] ~= nil
end

return Accent
