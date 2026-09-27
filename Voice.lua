--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Voice.lua
    Speaks the quoted part of a cast phrase out loud, in a voice matching the
    speaker's race and gender:  Corvin snarls "Feel that?"  -- and you hear it.

    Six things decide the shape of this file.

      * Only the words in quotes are ever voiced. Narration is the part
        onlookers are meant to read, and reading it aloud would turn a two-word
        bark into a paragraph. This is the same split Casts.lua already makes,
        so the audio and the text always agree about what was said.

      * Voice mode turns translation OFF for cast phrases, and that is a
        feature rather than a limitation. A voiced line has to match a recorded
        clip, and there is no way to record "Zaq'roth!" for every seed of every
        tongue -- the combinations are unbounded. Suppressing the tongue
        collapses that to one clip per line per voice, which is 314 clips.
        The accent goes with it for the same reason: "Feel dat?" is not a line
        anybody recorded, so leaving accents on would silently match nothing.

      * Playback is driven by CHAT_MSG_EMOTE, not by our own cast handler.
        The emote is what everyone in range actually receives, so listening to
        it means your line and a stranger's take the identical path, and a
        phrase somebody typed by hand is voiced too. The one case it misses is
        a line Blizzard refused to send at all (raid lockdown, or ToA standing
        down in an instance); Casts.showLocally cues those directly.

      * It must be a real event handler, never a chat filter. Chat filters run
        once per chat frame registered for the event -- usually two or three --
        so playing a sound inside one plays it two or three times. This is the
        single easiest way to get this wrong, and it sounds like an echo.

      * Audio ships in a SEPARATE addon folder. Addon updaters delete and
        recreate the folder they manage, so anything living inside
        TonguesOfAzeroth/ is destroyed by the next update -- and 300-odd clips
        per race would dwarf the addon besides. A missing pack is the normal
        case, not an error: PlaySoundFile simply reports that it won't play,
        and the line goes out as text exactly as it does today.

      * Files must exist before login. The client indexes addon audio at load,
        so a clip dropped in while you are standing in Orgrimmar will not
        play until you /reload. Worth knowing before concluding the addon is
        broken; /toa voice check says so.
---------------------------------------------------------------------------]]

local ADDON, ns = ...

local Voice = {}
ns.Voice = Voice

--=========================================================================--
--  Where a voice pack lives
--=========================================================================--
-- One folder per voice, named race-gender, holding one file per clip id. The
-- ids come from VoiceLines.lua, which is generated from the phrase library, so
-- a pack is just a directory listing and needs no manifest of its own.
--
--     Interface\AddOns\TonguesOfAzerothVoices\troll-male\feel-that-69075941.ogg
--
-- Both extensions are tried because the client accepts both and they arrive by
-- different routes: a batch render writes .ogg, while a clip downloaded by
-- hand from a text-to-speech site is nearly always .mp3. Supporting the second
-- is what makes a pack buildable without installing anything.
local PACK_ADDON = "TonguesOfAzerothVoices"
local EXTENSIONS = { ".ogg", ".mp3" }

Voice.PACK_ADDON = PACK_ADDON

-- "Master" rather than "Dialog" or "SFX": those are muted by the sliders most
-- people pull down to hear their music, and a voice line that vanishes with no
-- explanation reads as a broken addon. This is speech the player asked for.
local CHANNEL = "Master"

--=========================================================================--
--  Which voice a speaker uses
--=========================================================================--
-- Allied races fold onto the race they were built from. This is not a shortcut
-- taken to save effort -- a Void Elf *is* a Blood Elf who took a wrong turn,
-- and in the game's own voice work they share a voice set. Folding them here
-- takes a complete pack from 26 voices to 20, and means a new allied race in
-- some future patch inherits a sensible voice instead of falling silent.
local BASE_RACE = {
    voidelf            = "bloodelf",
    lightforgeddraenei = "draenei",
    highmountaintauren = "tauren",
    nightborne         = "nightelf",
    magharorc          = "orc",
    darkirondwarf      = "dwarf",
    zandalaritroll     = "troll",
    kultiran           = "human",
    mechagnome         = "gnome",
    earthen            = "dwarf",
}

-- The fallback when a race is unknown or its pack isn't installed. A neutral
-- pair is much better than silence: an unvoiced line among voiced ones reads
-- as a bug, where a plain voice just reads as a different person.
local NEUTRAL = "common"

local function slug(text)
    if type(text) ~= "string" then return nil end
    text = text:lower():gsub("[^%a%d]", "")
    if text == "" then return nil end
    return text
end

-- englishRace as the client spells it ("NightElf", "Scourge") to the folder
-- name a pack uses. Unknown races pass through rather than being rejected, so
-- a pack can support something this table has never heard of.
function Voice.RaceToken(englishRace)
    local s = slug(englishRace)
    if not s then return nil end
    return BASE_RACE[s] or s
end

-- 2 and 3 are male and female in every API that reports sex -- UnitSex,
-- GetPlayerInfoByGUID, the character-creation constants. 1 means "unknown",
-- which is what you get for a unit the client hasn't fully resolved, and is
-- deliberately not guessed at: a male voice on a female character is worse
-- than the neutral one.
function Voice.SexToken(sex)
    if sex == 3 then return "female" end
    if sex == 2 then return "male" end
    return nil
end

-- Every value below can be a secret on Midnight, and a secret throws on any
-- operation at all -- including the comparison that would screen it. So each
-- one is asked about before it is used, and the whole read sits in a pcall
-- besides, because an unreadable speaker should cost a voice line and nothing
-- more. See Names.lua for the same pattern and why it can't be simplified.
local function isSecret(v)
    return ns.IsSecret and ns.IsSecret(v) or false
end

local function safeString(v)
    if isSecret(v) then return nil end
    if type(v) ~= "string" or v == "" then return nil end
    return v
end

local function safeNumber(v)
    if isSecret(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-- The voice for the player themselves. Always readable: your own unit is never
-- secret, whatever is happening around you.
function Voice.PlayerVoice()
    if type(UnitRace) ~= "function" then return nil end
    local ok, race, sex = pcall(function()
        local _, englishRace = UnitRace("player")
        local s = type(UnitSex) == "function" and UnitSex("player") or nil
        return englishRace, s
    end)
    if not ok then return nil end
    return Voice.RaceToken(safeString(race)), Voice.SexToken(safeNumber(sex))
end

-- The voice for somebody else, from the GUID their chat line carried. This is
-- the only thing a CHAT_MSG_* event says about a speaker beyond their name,
-- and it is enough: GetPlayerInfoByGUID answers with race and sex for any
-- player, anywhere, with no unit token and no query. Hearing other people's
-- voices costs nothing extra because of it.
function Voice.VoiceForGUID(guid)
    if isSecret(guid) then return nil end
    if type(guid) ~= "string" or not guid:find("^Player%-") then return nil end
    if type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, _, _, englishRace, sex = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return nil end
    return Voice.RaceToken(safeString(englishRace)), Voice.SexToken(safeNumber(sex))
end

-- Folder name for a voice, with the neutral pair standing in for whatever we
-- couldn't work out. Sex has no neutral fallback of its own: a pack ships
-- common-male and common-female, and an unknown sex takes the male one purely
-- because something has to be picked and a coin flip would make the same
-- character sound different from line to line.
function Voice.FolderFor(race, sex)
    return (race or NEUTRAL) .. "-" .. (sex or "male")
end

--=========================================================================--
--  Settings
--=========================================================================--
local function castDB()
    return TonguesOfAzerothDB and TonguesOfAzerothDB.casts
end

function Voice.IsEnabled()
    local c = castDB()
    return (c and c.enabled and c.voice) and true or false
end

function Voice.HearsOthers()
    local c = castDB()
    return (c and c.enabled and c.voice and c.voiceOthers) and true or false
end

-- Casts.Render asks this before it translates anything. Kept as its own name
-- rather than a bare IsEnabled() call at the call site, because the reason a
-- voiced line stays in English is worth being able to read off the condition.
function Voice.SuppressesTranslation()
    return Voice.IsEnabled()
end


--=========================================================================--
--  Finding a clip
--=========================================================================--
function Voice.ClipId(spoken)
    local lines = ns.VoiceLines
    if not (lines and type(lines.ByText) == "table") then return nil end
    if type(spoken) ~= "string" then return nil end
    return lines.ByText[spoken]
end


-- Every path worth trying for one line in one voice, most specific first: the
-- speaker's own voice, then the neutral pair. Returned as a list rather than
-- played directly so /toa voice check can show exactly what was looked for --
-- "no audio" is otherwise indistinguishable from "wrong folder name", and that
-- is the one question anybody assembling a pack by hand needs answered.
function Voice.Candidates(spoken, race, sex)
    local clip = Voice.ClipId(spoken)
    if not clip then return {}, nil end

    local folders, seen = {}, {}
    local function add(folder)
        if folder and not seen[folder] then
            seen[folder] = true
            folders[#folders + 1] = folder
        end
    end
    add(Voice.FolderFor(race, sex))
    add(Voice.FolderFor(NEUTRAL, sex))

    local paths = {}
    for _, folder in ipairs(folders) do
        for _, ext in ipairs(EXTENSIONS) do
            paths[#paths + 1] = "Interface\\AddOns\\" .. PACK_ADDON .. "\\"
                .. folder .. "\\" .. clip .. ext
        end
    end
    return paths, clip
end

--=========================================================================--
--  Playing
--=========================================================================--
-- A cast phrase can quote more than once ("Down!" ... "Now."), and the client
-- has no way to tell us when a clip finishes, so the second would land on top
-- of the first. Lines are queued and spaced by an estimate instead.
--
-- The estimate is deliberately crude. Measuring real durations would mean
-- shipping a length table per voice, generated alongside the audio, and it
-- would still be wrong for any pack somebody assembled by hand. Overlapping
-- speech is the only genuinely bad outcome here, so the estimate is allowed
-- to run long: a beat of silence between two barks costs nothing.
-- Measured against a real rendered voice: 314 clips averaging 0.67s for lines
-- averaging 11.3 characters, so about 17 characters a second of speech. The
-- pad keeps the estimate slightly long, which is the direction that costs a
-- beat of silence rather than two clips talking over each other.
local CHARS_PER_SECOND = 17
local PAD = 0.35
local MIN_GAP, MAX_GAP = 0.7, 5

local function estimateSeconds(text)
    local n = #text / CHARS_PER_SECOND + PAD
    if n < MIN_GAP then return MIN_GAP end
    if n > MAX_GAP then return MAX_GAP end
    return n
end

-- Diagnostics only; nothing branches on these. Kept because the single most
-- common state for this feature is "no pack installed", and a player deserves
-- to be told that rather than left wondering.
Voice.stats = { played = 0, missing = 0, unmapped = 0 }

local playing = nil     -- handle of the clip currently sounding, when known

-- Try each candidate in turn and stop at the first that plays. PlaySoundFile
-- returns false for a file that isn't there, which is the only way to ask
-- whether a pack is installed -- there is no directory listing in this API, so
-- attempting playback *is* the existence check.
local function playFirst(paths)
    if type(PlaySoundFile) ~= "function" then return false end
    for _, path in ipairs(paths) do
        local ok, willPlay, handle = pcall(PlaySoundFile, path, CHANNEL)
        if ok and willPlay then
            playing = handle
            return true, path
        end
    end
    return false
end

-- Speak one already-extracted quoted span.
function Voice.PlayLine(spoken, race, sex)
    local paths, clip = Voice.Candidates(spoken, race, sex)
    if not clip then
        -- The line isn't in the manifest at all: a phrase the player reworded,
        -- or one added since the pack was rendered. Not an error.
        Voice.stats.unmapped = Voice.stats.unmapped + 1
        return false
    end
    local ok, path = playFirst(paths)
    if ok then
        Voice.stats.played = Voice.stats.played + 1
        return true, path
    end
    Voice.stats.missing = Voice.stats.missing + 1
    return false
end

-- Every quoted span in an emote body, in order. Mirrors the pattern Casts.lua
-- renders with, so the two can never disagree about what counts as speech.
function Voice.SpansOf(body)
    local out = {}
    if type(body) ~= "string" then return out end
    for span in body:gmatch('"([^"]*)"') do
        if span:gsub("%s", "") ~= "" then out[#out + 1] = span end
    end
    return out
end

-- Speak an emote body: find its quoted spans and play them in order.
function Voice.SpeakBody(body, race, sex)
    local spans = Voice.SpansOf(body)
    if #spans == 0 then return 0 end

    -- Anything already sounding is cut off rather than queued behind. Two
    -- people casting at once is the common case in a group, and waiting three
    -- seconds to hear the second is worse than not hearing the first finish.
    -- StopSound is absent on the older flavors, where clips simply overlap.
    if playing and type(StopSound) == "function" then
        pcall(StopSound, playing)
        playing = nil
    end

    local spoken = 0
    local delay = 0
    for _, span in ipairs(spans) do
        if Voice.ClipId(span) then
            if delay <= 0 then
                Voice.PlayLine(span, race, sex)
            elseif type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(delay, function() Voice.PlayLine(span, race, sex) end)
            else
                break   -- no timer to schedule with: first span only
            end
            spoken = spoken + 1
            delay = delay + estimateSeconds(span)
        end
    end
    return spoken
end

--=========================================================================--
--  Listening
--=========================================================================--
-- CHAT_MSG_EMOTE is the whole input. Its message is the emote body alone --
-- the client prepends the name when it draws the line -- which is exactly the
-- string Casts.Render produced, so the quoted spans in it are the spans that
-- were meant to be heard.
local function onEmote(msg, sender, guid)
    if not Voice.IsEnabled() then return end
    if isSecret(msg) or isSecret(sender) then return end
    if type(msg) ~= "string" or msg == "" then return end
    if not msg:find('"', 1, true) then return end

    local me = UnitName and UnitName("player")
    if isSecret(me) then me = nil end
    local mine = (type(me) == "string" and sender == me)

    if not mine and not Voice.HearsOthers() then return end

    local race, sex
    if mine then
        race, sex = Voice.PlayerVoice()
    else
        race, sex = Voice.VoiceForGUID(guid)
    end
    Voice.SpeakBody(msg, race, sex)
end

Voice.OnEmote = onEmote

-- A real event registration rather than a ChatFrame filter, because a filter
-- is invoked once per chat frame listening for the event and would play the
-- clip once per window. See the header.
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_EMOTE")
frame:SetScript("OnEvent", function(_, event, msg, sender, ...)
    if event ~= "CHAT_MSG_EMOTE" then return end
    -- The sender's GUID is the twelfth argument of CHAT_MSG_*; three are named
    -- above, so it is the tenth of what's left. Read positionally because that
    -- is the only way it is offered -- a layout that ever shifts costs the
    -- speaker their own voice and nothing worse, since VoiceForGUID screens
    -- what it gets for the "Player-" prefix.
    onEmote(msg, sender, select(10, ...))
end)

-- The one line CHAT_MSG_EMOTE never delivers: a phrase Blizzard refused to
-- send, which Casts prints locally instead. Called from there so the RP beat
-- still has its voice even inside a raid encounter.
function Voice.SpeakLocal(body)
    if not Voice.IsEnabled() then return 0 end
    local race, sex = Voice.PlayerVoice()
    return Voice.SpeakBody(body, race, sex)
end

--=========================================================================--
--  Diagnostics
--=========================================================================--
-- What /toa voice check reports. Everything here answers a question somebody
-- assembling a pack by hand will have: which folder am I meant to create, what
-- do I call the file, and did the addon find it.
function Voice.Describe()
    local race, sex = Voice.PlayerVoice()
    local lines = ns.VoiceLines
    return {
        enabled = Voice.IsEnabled(),
        others = Voice.HearsOthers(),
        race = race,
        sex = sex,
        folder = Voice.FolderFor(race, sex),
        root = "Interface\\AddOns\\" .. PACK_ADDON,
        count = lines and lines.COUNT or 0,
        stats = Voice.stats,
    }
end

-- A line that is definitely in the manifest, for "play me something" to use.
-- Picked by sorting rather than by taking whatever pairs() offers first, so
-- the same command demonstrates the same clip every time -- otherwise a player
-- comparing two runs has no idea whether the voice or the line changed.
function Voice.SampleLine()
    local lines = ns.VoiceLines
    if not (lines and type(lines.ByText) == "table") then return nil end
    local best
    for text in pairs(lines.ByText) do
        if best == nil or text < best then best = text end
    end
    return best
end

-- Try a specific line and report the path that worked, or every path that
-- didn't. The second half is the useful one: it turns "nothing happened" into
-- a filename to compare against what is actually on disk.
function Voice.Check(spoken)
    local race, sex = Voice.PlayerVoice()
    local paths, clip = Voice.Candidates(spoken, race, sex)
    if not clip then return nil, nil, {} end
    local ok, path = playFirst(paths)
    return ok, path, paths, clip
end
