--=========================================================================--
--  Immersion -- garbling the game's own languages
--=========================================================================--
-- Normally the client decides what you can understand: it hands you plain
-- English for every language your character knows and pre-garbled nonsense for
-- the rest. Full immersion moves that decision to Glyphic, so a night elf who
-- has never studied Orcish cannot read Orcish even though the game would let
-- her, and a character who has studied it part-way reads part of it.
--
-- This can only ever take understanding away, never add it. Speech in a tongue
-- your character does not know is garbled by the client before any addon sees
-- it, and the original never reaches this machine -- so there is nothing here
-- to recover, at any fluency. Those lines are left exactly as they arrived.
--
-- The words are Blizzard's own, from LanguageWords in the client data, and the
-- hash is Blizzard's own (Storm's SStrHash). That is deliberate: the output is
-- not merely Orcish-shaped, it is the same text the game would have shown. The
-- check that this is really true is "lol" coming out "Kek", which is the pair
-- every player already knows by heart.
local _, ns = ...

local Immersion = {}
ns.Immersion = Immersion

local strbyte, strsub, strlen, strupper = string.byte, string.sub, string.len, string.upper
local tconcat = table.concat

-- Blizzard's skill scale. 300 is fluency; at or above it nothing is touched.
local FULL_SKILL = 300
Immersion.FULL_SKILL = FULL_SKILL

-- Same word shape the rest of the addon translates, so a line garbled here and
-- a line garbled by Language.lua break on the same boundaries.
local WORD_PATTERN = "[%a][%a'-]*"

-- A bucket this small cannot garble a sentence, it can only repeat itself.
-- Blizzard ships one word for Gilnean and two for Pandaren ("Om", "Nom"),
-- which is a joke in the data rather than a language; rendering a paragraph as
-- "E E E E E" is faithful and useless. Those fall through to Glyphic's own
-- generator, which has real entries for both.
local MIN_BUCKET = 3

--=========================================================================--
--  SStrHash
--=========================================================================--
-- Storm's string hash, as used by the client's chat translation. The table and
-- the two magic constants are hardcoded in the binary; see wowdev.wiki/SStrHash.
local HASH_TABLE = {
    0x486E26EE, 0xDCAA16B3, 0xE1918EEF, 0x202DAFDB,
    0x341C7DC7, 0x1C365303, 0x40EF2D37, 0x65FD5E49,
    0xD6057177, 0x904ECE93, 0x1C38024F, 0x98FD323B,
    0xE3061AE7, 0xA39B0FA1, 0x9797F25F, 0xE4444563,
}
local TWO32 = 4294967296

-- Arithmetic rather than bit.bxor. Nothing else in the addon depends on the
-- bit library and chat arrives slowly enough that the loop does not matter;
-- this keeps the module loadable anywhere the rest of Glyphic loads.
local function bxor32(a, b)
    local result, place = 0, 1
    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        if x ~= y then result = result + place end
        a, b, place = (a - x) / 2, (b - y) / 2, place * 2
    end
    return result
end

function Immersion.Hash(word)
    local seed, shift = 0x7FED7FED, 0xEEEEEEEE
    for i = 1, strlen(word) do
        local c = strbyte(word, i)
        -- upper_backslash: the hash is case-insensitive, and "/" is folded to
        -- "\" because this same function hashes file paths elsewhere.
        if c == 47 then
            c = 92
        elseif c >= 97 and c <= 122 then
            c = c - 32
        end
        local hi = HASH_TABLE[(c - c % 16) / 16 + 1]
        local lo = HASH_TABLE[c % 16 + 1]
        seed = bxor32((hi - lo) % TWO32, (shift + seed) % TWO32)
        shift = (c + seed + 33 * shift + 3) % TWO32
    end
    if seed == 0 then return 1 end
    return seed
end

--=========================================================================--
--  Word replacement
--=========================================================================--
-- Which bucket a word draws from, and whether the language has usable data at
-- all. Length decides the bucket, so a short word stays short; a length with
-- no entries of its own walks down to the next shorter one, the way the client
-- does, which is why an 18-character word still comes out as something.
local function bucketFor(langId, word)
    local byLength = ns.BlizzardWords and ns.BlizzardWords[langId]
    if not byLength then return nil end
    local n = strlen(word)
    local cap = ns.BLIZZARD_WORD_MAX or 18
    if n > cap then n = cap end
    while n >= 1 do
        local bucket = byLength[n]
        if bucket and #bucket > 0 then return bucket end
        n = n - 1
    end
    return nil
end

-- Blizzard forces a capital where the source word has one and otherwise leaves
-- the table's own spelling alone. That asymmetry is why "lol" comes back "Kek"
-- with the capital intact rather than "kek".
local function copyCase(source, replacement)
    local out, n = {}, strlen(replacement)
    for i = 1, n do
        local ch = strsub(replacement, i, i)
        local src = strbyte(source, i)
        if src and src >= 65 and src <= 90 then ch = strupper(ch) end
        out[i] = ch
    end
    return tconcat(out)
end

-- True when this language has enough data to garble with. Callers use it to
-- decide whether to fall back to Glyphic's own generator.
function Immersion.HasWords(langId)
    local byLength = ns.BlizzardWords and ns.BlizzardWords[langId]
    if not byLength then return false end
    local total = 0
    for _, bucket in pairs(byLength) do
        total = total + #bucket
        if total >= MIN_BUCKET then return true end
    end
    return false
end

--=========================================================================--
--  Garbling a line
--=========================================================================--
-- `skill` is Blizzard's 0-300 scale. Returns nil when the language has no
-- usable word data, so the caller can fall back rather than hand back a line
-- that silently did nothing.
--
-- `tint` is an optional six-digit hex. Given one, the words that come through
-- in the clear are wrapped in it, so a paragraph shows you what you can read
-- rather than only what you cannot. Handed in rather than worked out here:
-- which colour, how strong and whether at all are display decisions, and this
-- module's job is deciding what is legible. It also means the quest window and
-- the chat frame can fade towards their own ink without this knowing either
-- exists.
function Immersion.Garble(text, langId, skill, tint)
    if type(text) ~= "string" or text == "" then return text end
    if not Immersion.HasWords(langId) then return nil end
    skill = tonumber(skill) or 0
    if type(tint) ~= "string" or not tint:match("^%x%x%x%x%x%x$") then tint = nil end
    -- A fast path, not a rule: at full skill every word passes the test below
    -- anyway (hash % 300 is always under 300), so the line comes back intact
    -- either way. It is here to skip the markup pass and the per-word hashing
    -- for the common case, and deleting it would change nothing you could
    -- observe -- which is why no test covers it, and why this says so.
    --
    -- Still a fast path with a tint asked for. At full skill every word is
    -- legible, so highlighting would paint the whole line one colour, which
    -- says nothing -- the highlight is a comparison and there is nothing left
    -- to compare it against.
    if skill >= FULL_SKILL then return text end

    -- Links, textures and color codes are bytes the client parses, not words.
    -- Same list Language.lua and Accent.lua protect, because a line that is
    -- safe to translate is exactly a line that is safe to garble.
    local saved, count = {}, 0
    local function stash(segment)
        count = count + 1
        saved[count] = segment
        return "\002" .. count .. "\002"
    end
    local body = ns.StashMarkup and ns.StashMarkup(text, stash) or text

    body = body:gsub(WORD_PATTERN, function(word)
        local hash = Immersion.Hash(word)
        -- Partial comprehension, exactly as the client does it: a word whose
        -- hash falls under your skill comes through in the clear. Deterministic
        -- per word, so the same sentence always breaks the same way and a
        -- speaker does not flicker in and out of legibility as you reread.
        if hash % FULL_SKILL < skill then
            -- Wrapped per word and closed immediately, so nothing nests: the
            -- markup pass above has already lifted every link and texture out
            -- of the way, and a caller that wraps the whole line in a colour of
            -- its own re-opens after each "|r" rather than being cut short.
            if tint then return "|cff" .. tint .. word .. "|r" end
            return word
        end
        local bucket = bucketFor(langId, word)
        if not bucket then return word end
        return copyCase(word, bucket[hash % #bucket + 1])
    end)

    if count > 0 then
        body = body:gsub("\002(%d+)\002", function(i) return saved[tonumber(i)] end)
    end
    return body
end

-- Glyphic's fluency is 0-100 and Blizzard's skill is 0-300. They mean the same
-- thing and even use the same rule (hash of the word against the scale), so
-- this is a straight conversion rather than a reinterpretation.
function Immersion.SkillFromFluency(percent)
    local n = tonumber(percent) or 0
    if n < 0 then n = 0 elseif n > 100 then n = 100 end
    return n * 3
end
