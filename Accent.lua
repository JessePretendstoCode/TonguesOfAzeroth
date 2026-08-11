--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Accent.lua
    Dialect "accents" for chat: instead of replacing words with a constructed
    language (see Language.lua), this rewrites your ENGLISH into a spoken accent,
    e.g. Dwarven "I cannae do this, aye!" or Troll "Stay away from da voodoo, mon."

    An accent is data-driven and GRADED by strength:
      * swaps    : whole-word lexical/phonetic swaps, grouped by the strength at
                   which they switch on:  swaps = { [10] = { you = "ye" }, ... }.
                   The number is a 0-100 threshold; the lightest, most iconic
                   markers sit low (~10) and the heaviest respellings sit high
                   (~70+).
      * patterns : Lua gsub rules { pattern, repl, at } applied to a word
                   (lowercased), e.g. { "ing$", "in'", 20 }. `at` is the strength
                   threshold, same idea.
      * tails    : occasional sentence-end interjections (", aye!", ", mon.").

    Strength (0-100) controls HOW GARBLED the whole sentence is, not merely which
    words change: at strength S, every swap/pattern whose threshold <= S fires, so
    the accent thickens smoothly and deterministically as you raise the slider.
    At 100 the speech is heavily accented; at ~15 you just get the signature words.
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

-- reg() flattens the tiered `swaps` table into fast lookup maps:
--   def._wordTo[en] = replacement,  def._wordAt[en] = strength threshold.
-- If the same word appears in several tiers, the lowest threshold wins.
local function reg(id, def)
    def.id = id
    def._wordTo = {}
    def._wordAt = {}
    if def.swaps then
        for threshold, map in pairs(def.swaps) do
            for en, repl in pairs(map) do
                if def._wordAt[en] == nil or threshold < def._wordAt[en] then
                    def._wordTo[en] = repl
                    def._wordAt[en] = threshold
                    -- An empty replacement DROPS the word (e.g. Russian/Chinese
                    -- English has no articles). Flagged so Apply() tidies the
                    -- leftover spaces only for accents that actually do this.
                    if repl == "" then def._hasDrops = true end
                end
            end
        end
    end
    def.patterns = def.patterns or {}
    ACCENTS[id] = def
    ORDER[#ORDER + 1] = id
end

--=========================================================================--
--  Accent definitions
--
--  swaps[threshold] = { english = replacement, ... }
--    threshold ~10  : iconic markers you'd hear even from a mild speaker
--    threshold ~25  : common function-word shifts
--    threshold ~45  : broad vowel/word respelling
--    threshold ~70+ : heavy dialect spelling (hard to read = very "garbled")
--  patterns = { { luaPattern, repl, threshold }, ... }   (applied after swaps)
--=========================================================================--

-- Dwarven == broad Scots. Real Scots writing: ye/yer, -in', cannae/dinnae,
-- tae/frae/o', oot/hoose/doon, and the classic -icht for -ight (nicht/licht).
reg("dwarf", {
    name = "Dwarven",
    swaps = {
        [10] = {
            i = "ah", ["i'm"] = "ah'm", you = "ye", ["you're"] = "ye're",
            your = "yer", yes = "aye", ["can't"] = "cannae", cannot = "cannae",
            ["don't"] = "dinnae", know = "ken", little = "wee", small = "wee",
            friend = "laddie", good = "braw", man = "lad", boy = "lad",
            woman = "lass", girl = "lass", child = "bairn",
        },
        [25] = {
            my = "ma", to = "tae", of = "o'", ["and"] = "an'", ["not"] = "nae",
            no = "nae", going = "gaun", doing = "daein", ["isn't"] = "isnae",
            ["wasn't"] = "wasnae", ["doesn't"] = "doesnae", ["won't"] = "willnae",
            ["couldn't"] = "couldnae", ["wouldn't"] = "wouldnae",
            ["shouldn't"] = "shouldnae", so = "sae", from = "frae", have = "hae",
            ["do"] = "dae", give = "gie", well = "weel", all = "aw", more = "mair",
            where = "whaur", what = "whit", who = "wha", when = "whan", how = "hoo",
            now = "noo",
        },
        [45] = {
            out = "oot", about = "aboot", down = "doon", town = "toon",
            house = "hoose", mouth = "mooth", our = "oor", round = "roond",
            found = "foond", sound = "soond", ground = "groond",
            without = "withoot", one = "yin", two = "twa", own = "ain",
            old = "auld", cold = "cauld", told = "tauld", gold = "gowd",
            hold = "haud", over = "ower", before = "afore", father = "faither",
            mother = "maither", brother = "brither", water = "watter",
            work = "wark", word = "wird", world = "warld", head = "heid",
            dead = "deid", both = "baith", stone = "stane", home = "hame",
            bone = "bane", most = "maist", ghost = "ghaist", with = "wi'",
        },
        [70] = {
            night = "nicht", light = "licht", right = "richt", might = "micht",
            fight = "ficht", sight = "sicht", bright = "bricht", tight = "ticht",
            enough = "eneuch", through = "throu", daughter = "dochter",
            laugh = "lauch",
        },
    },
    patterns = { { "ing$", "in'", 20 }, { "old$", "auld", 55 }, { "ight", "icht", 72 } },
    tails = { ", aye.", ", lad.", ", ye ken?", ", ah tell ye." },
})

-- Troll == Jamaican Patois. Voiced th->d (the->da), voiceless th->t
-- (think->tink), -er->-a (water->wata), likkle, mon, nuff.
reg("troll", {
    name = "Troll",
    swaps = {
        [10] = {
            the = "da", they = "dey", them = "dem", their = "dere",
            there = "dere", this = "dis", that = "dat", these = "dese",
            those = "dose", ["then"] = "den", with = "wit", little = "likkle",
            friend = "mon", man = "mon", you = "ya", ["you're"] = "ya",
            your = "ya", of = "o'",
        },
        [25] = {
            think = "tink", thing = "ting", things = "tings", three = "tree",
            through = "tru", nothing = "nuttin", something = "sumting",
            another = "anodda", other = "odda", mother = "mudda",
            father = "fadda", brother = "bruddah", together = "togedda",
            over = "ova", ever = "eva", never = "neva", better = "betta",
            going = "gwan", about = "bout",
        },
        [45] = {
            understand = "overstand", small = "likkle", good = "irie",
            happy = "irie", cool = "irie", ["okay"] = "irie", child = "pickney",
            children = "pickney", woman = "empress", talk = "reason",
            speak = "reason", is = "be", are = "be",
        },
        [70] = {
            more = "nuff", many = "nuff", very = "nuff", first = "fus",
            i = "I an' I", we = "I an' I", my = "me",
        },
    },
    patterns = { { "ing$", "in'", 25 }, { "er$", "a", 60 } },
    tails = { ", mon.", ", ya know?", ", I tell ya.", ", respect." },
})

-- Orcish == blunt, guttural strongman. Harsh consonants, clipped speech.
reg("orc", {
    name = "Orcish",
    swaps = {
        [10] = {
            hello = "lok'tar", hi = "lok'tar", yes = "zug zug", ["okay"] = "dabu",
            ok = "dabu", thanks = "dabu", friend = "brudda", brother = "brudda",
            human = "pinkskin", humans = "pinkskins", the = "da", they = "dey",
        },
        [30] = {
            strength = "strenkth", strong = "mighty", great = "mighty",
            good = "strong", enemy = "prey", kill = "crush", fight = "krush",
            die = "perish", coward = "weakling", weak = "weakling", is = "be",
            are = "be", am = "be",
        },
        [55] = {
            ["for"] = "fer", little = "runt", small = "runt", people = "ones",
            warrior = "grunt", afraid = "weak", run = "flee",
        },
    },
    patterns = { { "ing$", "in'", 35 }, { "th", "d", 60 } },
    tails = { ", zug zug.", " Lok'tar ogar!", ", dabu.", " Blood and thunder!" },
})

-- Draenei == Russian accent (matches their in-game voice). Signature written
-- Russian-English cues: no articles (the/a dropped), th->z/s (this->zis,
-- think->sink), w->v (we->ve), and -ing devoiced to -ink (going->goink).
reg("draenei", {
    name = "Draenei",
    swaps = {
        [10] = {
            yes = "da", no = "nyet", friend = "comrade", hello = "privyet",
            hi = "privyet",
        },
        [25] = {
            the = "ze", this = "zis", that = "zat", these = "zese",
            those = "zose", they = "zey", them = "zem", their = "zeir",
            there = "zere", ["then"] = "zen", think = "sink", thing = "sink",
            three = "sree", through = "srough", thanks = "spasibo",
            nothing = "nossink", something = "somesink", with = "vis",
        },
        [45] = {
            a = "", an = "", very = "wery", we = "ve", what = "vhat",
            will = "vill", want = "vant", was = "vas", why = "vhy",
            where = "vhere", when = "vhen", who = "vho", would = "vould",
        },
        [70] = {
            have = "hev", is = "iz", his = "hiz", good = "gud", too = "tú",
        },
    },
    patterns = { { "ing$", "ink", 40 }, { "w", "v", 60 }, { "^h", "kh", 85 } },
    tails = { ", da.", ", comrade.", ", is no problem.", ", of course." },
})

-- Goblin == fast-talking Brooklyn/Jersey. th->d (dese/dose/dem), -er->-a
-- (over->ova), dropped g's, dawg/tawk vowels, ya/da/'em, gonna/cuz.
reg("goblin", {
    name = "Goblin",
    swaps = {
        [10] = {
            friend = "pal", buddy = "pal", yes = "yeah", hello = "heya",
            hi = "heya", great = "terrific", money = "dough", gold = "dough",
            the = "da", this = "dis", that = "dat",
        },
        [30] = {
            you = "ya", your = "ya", ["you're"] = "ya", them = "'em",
            these = "dese", those = "dose", they = "dey", their = "dere",
            there = "dere", ["isn't"] = "ain't", ["aren't"] = "ain't",
            with = "wit", what = "whadda",
        },
        [55] = {
            going = "gonna", because = "cuz", about = "'bout", ["okay"] = "awright",
            ok = "awright", of = "a", to = "ta", talk = "tawk", dog = "dawg",
            all = "awl", small = "smawl", off = "awff", boss = "bawss",
            coffee = "cawfee",
        },
        [75] = {
            nothing = "nuttin", something = "sumthin", everything = "everythin",
            anything = "anythin", another = "anudda",
        },
    },
    patterns = { { "ing$", "in'", 40 }, { "th", "d", 45 }, { "er$", "a", 55 } },
    tails = { ", pal.", ", heh.", ", capiche?", ", fuhgeddaboudit." },
})

-- Gilnean == Cockney. h-dropping ('ello, 'ouse), voiced th->d (the->de),
-- voiceless th->f (think->fink, with->wif), ain't, roight.
reg("gilnean", {
    name = "Gilnean",
    swaps = {
        [10] = {
            friend = "guv'nor", hello = "'ello", hi = "'ello", my = "me",
            yes = "aye", ["isn't"] = "ain't", ["aren't"] = "ain't",
            ["haven't"] = "ain't", ["hasn't"] = "ain't",
        },
        [30] = {
            your = "yer", right = "roight", about = "abaht", now = "nah",
            nothing = "nuffink", something = "summat", going = "goin'",
            ["can't"] = "cahn't",
        },
        [55] = {
            the = "de", this = "dis", that = "dat", these = "dese",
            those = "dose", them = "'em", there = "dere", they = "dey",
            think = "fink", thing = "fing", three = "free", brother = "bruv",
            mother = "muvver", father = "farver", together = "togevver",
        },
    },
    patterns = {
        { "^h", "'", 40 },      -- h-dropping: 'ello, 'ouse, 'ave
        { "ing$", "in'", 30 },  -- droppin' the g
        { "er$", "a", 50 },     -- betta, geeza, propa
        { "igh", "oigh", 62 },  -- noight, roight, loight
        { "th", "f", 75 },      -- voiceless th: wif, bof, mouf
        { "tt", "'", 85 },      -- glottal stop: be'er, li'le, bo'le
    },
    tails = { ", guv'nor.", ", right proper.", ", innit.", ", mate." },
})

-- Vrykul == Norse/Viking. Scandinavian-English: w->v (we->ve), j for y
-- (yes->ja), th->d (the->de, this->dis), plus mead-hall gravitas.
reg("vrykul", {
    name = "Vrykul",
    swaps = {
        [10] = {
            yes = "ja", no = "nej", friend = "warrior", hello = "hail",
            hi = "hail", thanks = "skål", the = "de", this = "dis",
            that = "dat", they = "dey", them = "dem", ["then"] = "den",
        },
        [30] = {
            death = "glorious death", die = "fall in battle", drink = "mead",
            hall = "mead hall", warrior = "einherjar", god = "the All-Father",
            fight = "do battle", strong = "mighty", brave = "valorous",
            with = "vith", we = "ve", what = "vhat", will = "vill",
            want = "vant", why = "vhy", where = "vhere", when = "vhen",
        },
        [55] = {
            coward = "niðing", weak = "soft", afraid = "unworthy", enemy = "foe",
            over = "ova", of = "av", to = "til", is = "iss", your = "yer",
        },
    },
    patterns = { { "w", "v", 45 }, { "th", "d", 55 }, { "j", "y", 90 } },
    tails = { ", ja.", " Skål!", " For the All-Father!", " Odyn watches!" },
})

-- Pirate == high-seas Yarr. me/ye/yer, be for is/are, -in', th'/o'/t'.
reg("pirate", {
    name = "Pirate",
    swaps = {
        [10] = {
            my = "me", you = "ye", your = "yer", ["you're"] = "ye be",
            yes = "aye", hello = "ahoy", hi = "ahoy", friend = "matey",
            is = "be", are = "be", am = "be",
        },
        [25] = {
            the = "th'", of = "o'", to = "t'", ["for"] = "fer",
            ["isn't"] = "ain't", ["aren't"] = "ain't", man = "matey",
            money = "booty", gold = "doubloons", treasure = "booty",
            drink = "grog", ["it's"] = "'tis",
        },
        [55] = {
            hey = "arr", stop = "belay", down = "below decks", food = "grub",
            captain = "cap'n", between = "betwixt",
        },
    },
    patterns = { { "ing$", "in'", 25 }, { "^h", "'", 70 } },
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

    -- Strength is the "garble level": every swap/pattern whose threshold is at or
    -- below the current strength fires, on EVERY eligible word. Raising strength
    -- switches on more (and heavier) transforms, so the accent thickens smoothly.
    local out = text:gsub(WORD, function(word)
        local lower = strlower(word)

        -- Lexical/phonetic word swap (terminal: slang words aren't re-spelled).
        local to = acc._wordTo[lower]
        if to and strength >= acc._wordAt[lower] then
            return applyCase(word, to)
        end

        -- Cumulative phonetic respelling.
        local w = lower
        for i = 1, #acc.patterns do
            local p = acc.patterns[i]
            if strength >= (p[3] or 0) then
                w = w:gsub(p[1], p[2])
            end
        end
        if w ~= lower then return applyCase(word, w) end
        return word
    end)

    -- If this accent drops words, tidy the double spaces / space-before-comma
    -- it leaves behind (e.g. "go to  meeting ." -> "go to meeting.").
    if acc._hasDrops then
        out = out:gsub("  +", " ")
        out = out:gsub(" +([%.%,%!%?%;%:])", "%1")
        out = out:gsub("^ +", "")
    end

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
