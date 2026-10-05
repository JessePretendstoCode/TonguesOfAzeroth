--[[-------------------------------------------------------------------------
    Glyphic - Voice.lua
    Speaks a cast phrase out loud using a recording the game already ships:
    Corvin snarls "Feel that?"  -- and you hear Sylvanas, or a grunt, or
    whatever line was pinned to that phrase.

    Five things decide the shape of this file.

      * The audio is Blizzard's own, addressed by FileDataID. PlaySoundFile has
        taken a number as readily as a path since patch 8.2, so a pinned line
        is stored as "game:<fileDataId>" and played by handing that number
        over. Nothing is downloaded and nothing is redistributed: the file is
        already sitting in the player's client, which is also why it sounds
        like the actor who recorded it.

      * A phrase speaks only if something was pinned to it. There is no
        rendering step and no fallback -- an unpinned phrase goes out as text,
        exactly as it did before anyone turned sound on. Silence is the normal
        state, not a failure.

      * Only a phrase that quotes somebody is ever voiced. Narration is the
        part onlookers are meant to read, and the quotes are what mark a line
        as containing speech at all. This is the same split Casts.lua makes.

      * Playback is driven by CHAT_MSG_EMOTE, not by our own cast handler.
        The emote is what the server actually sent, so a line Blizzard refused
        to deliver stays silent instead of being heard by its author alone.
        Casts.showLocally cues the one case the event never carries. The same
        event is what makes a shared line safe to play: see "Other people's
        lines" below.

      * It must be a real event handler, never a chat filter. Chat filters run
        once per chat frame registered for the event -- usually two or three --
        so playing a sound inside one plays it two or three times. This is the
        single easiest way to get this wrong, and it sounds like an echo.

    Nothing here suppresses translation. The old synthesised voices read your
    words back to you, so a translated line would have said one thing and
    sounded another; a game recording says whatever Blizzard recorded it
    saying and never matched your words to begin with. Your tongue and your
    accent therefore stay on while sound is playing.
---------------------------------------------------------------------------]]

local ADDON, ns = ...

local Voice = {}
ns.Voice = Voice

local Compat = ns.Compat

-- "Master" rather than "Dialog" or "SFX": those are muted by the sliders most
-- people pull down to hear their music, and a voice line that vanishes with no
-- explanation reads as a broken addon. This is speech the player asked for.
local CHANNEL = "Master"

-- Every value off the client can be a secret on Midnight, and a secret throws
-- on any operation at all -- including the comparison that would screen it. So
-- it is asked about before it is used. See Names.lua for the same pattern and
-- why it can't be simplified.
local function isSecret(v)
    return ns.IsSecret and ns.IsSecret(v) or false
end

--=========================================================================--
--  Settings
--=========================================================================--
local function castDB()
    return TonguesOfAzerothDB and TonguesOfAzerothDB.casts
end

-- Gated on the in-character switch, so the mute reaches the sound and not only
-- the words. Audition is deliberately not: pressing Play on the phrase panel is
-- a direct request, and refusing it would leave somebody picking a line they are
-- not allowed to hear first.
--
-- There is no separate "speak out loud" switch any more. A phrase is silent
-- until a recording is pinned to it, so pinning already says yes and a second
-- switch only gave the same answer twice -- in the arrangement where it was
-- off by default, it was a switch whose job was to make the pinning not work.
function Voice.IsEnabled()
    local c = castDB()
    if ns.IsInCharacter and not ns.IsInCharacter() then return false end
    return (c and c.enabled) and true or false
end

--=========================================================================--
--  Lines the client already has
--=========================================================================--
-- A pinned line names a recording by id, as "game:<fileDataId>". That is the
-- whole address: there is no folder to look in and no alternative to fall back
-- to, because the client either carries that file or it does not.
local GAME_PREFIX = "game:"

-- The FileDataID a pinned line names, or nil if it does not name one.
function Voice.GameId(spoken)
    if type(spoken) ~= "string" then return nil end
    if spoken:sub(1, #GAME_PREFIX) ~= GAME_PREFIX then return nil end
    return tonumber(spoken:sub(#GAME_PREFIX + 1))
end

function Voice.GameRef(id)
    if type(id) ~= "number" then return nil end
    return GAME_PREFIX .. tostring(id)
end

-- What a game recording says, so a pinned choice can be shown as words rather
-- than as the number it is stored as.
function Voice.GameText(spoken)
    local id = Voice.GameId(spoken)
    if not id then return nil end
    local gv = ns.GameVoices
    return gv and gv.ById and gv.ById[id] or nil
end

-- Whether this line can be voiced at all. Kept as its own name because several
-- callers ask that question and none of them care how it is answered.
function Voice.ClipId(spoken)
    if Voice.GameId(spoken) then return spoken end
    return nil
end

--=========================================================================--
--  Playing
--=========================================================================--
-- Diagnostics only; nothing branches on these.
--
-- The chain from a cast to a sound has four links and only the last one is
-- audible, so "no sound" is the same symptom for all four. These count each
-- link separately, which is the difference between a report anyone can act on
-- and "it doesn't work".
--
--   emotes     any emote at all reached the handler
--   secret     ...but arrived as a value this client will not let addons read
--   nameless   ...or without a sender that could be matched against your own
--   mine       it was yours, so playback was attempted
--   unpinned   the phrase that produced it had nothing pinned
--   rewritten  it arrived as a different string than the one that was sent, so
--              the pin could not be matched to it
--   unmapped   a pin was claimed but did not name a recording
--   played     a recording was started by one of your own casts
--   auditioned ...or by the play button, which is not the same evidence
--   fromOthers ...or by somebody else's line, which is not either
--   missing    a pin named a file this client does not carry
Voice.stats = {
    played = 0, auditioned = 0, fromOthers = 0,
    missing = 0, unmapped = 0, heard = 0, unpinned = 0, rewritten = 0,
    emotes = 0, secret = 0, nameless = 0, mine = 0,
}

-- The last line that came back different from the one that went out. Kept
-- whole rather than counted, because the useful question is what changed.
Voice.lastRewrite = nil

local playing = nil     -- handle of the clip currently sounding, when known

-- Cut off whatever is sounding rather than queueing behind it. Two people
-- casting at once is the common case in a group, and waiting three seconds to
-- hear the second is worse than not hearing the first finish. StopSound is
-- absent on the older flavors, where clips simply overlap.
local function stopCurrent()
    if playing and type(StopSound) == "function" then
        pcall(StopSound, playing)
    end
    playing = nil
end

-- Play a game recording by id. Returns whether it played, which is also the
-- only way to know whether this client carries the file -- there is no
-- directory listing in this API, so attempting playback *is* the existence
-- check.
-- Where a sound came from. The play button, your own cast and somebody else's
-- line all end at this same call, so counting them together makes the one
-- number anybody ever reports back useless: "it played sixty times" answers
-- nothing if the sixty were button presses.
local SOURCE_STAT = { audition = "auditioned", other = "fromOthers" }

function Voice.PlayGame(id, source)
    if type(id) ~= "number" then return false end
    if type(PlaySoundFile) ~= "function" then return false end
    stopCurrent()
    local ok, played, handle = pcall(PlaySoundFile, id, CHANNEL)
    if ok and played then
        playing = handle
        local stat = SOURCE_STAT[source] or "played"
        Voice.stats[stat] = Voice.stats[stat] + 1
        return true
    end
    -- This client does not carry the file. Counted, because a pin naming a
    -- recording that cannot be played sounds exactly like one that was never
    -- pinned, and the two want opposite answers.
    Voice.stats.missing = Voice.stats.missing + 1
    return false
end

-- Speak one pinned line.
function Voice.PlayLine(spoken, source)
    local id = Voice.GameId(spoken)
    if not id then
        -- Not a recording at all: a phrase with nothing pinned to it. Not an
        -- error, and by far the most common case.
        Voice.stats.unmapped = Voice.stats.unmapped + 1
        return false
    end
    return Voice.PlayGame(id, source)
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

--=========================================================================--
--  A line pointed at a recording
--=========================================================================--
-- The pin cannot ride on the emote, which is only ever a string, so Casts
-- hands it over just before sending and the body it belongs to claims it here.
-- Matched on that exact body rather than simply consumed, because the client
-- can refuse to send a line at all: a choice left waiting in a variable would
-- then attach itself to whatever spoke next, which is somebody else's phrase
-- wearing your sound. Matching means an unclaimed choice is replaced rather
-- than misapplied.
local pendingBody, pendingChoice = nil, nil

function Voice.NoteChoice(body, choice)
    pendingBody, pendingChoice = body, choice
end

local function claimChoice(body)
    if pendingBody ~= nil and pendingBody ~= body then
        -- A line went out and something else came back. Nothing here can fix
        -- that, but silently returning nil makes it indistinguishable from a
        -- phrase with no recording on it, and the two want opposite answers.
        Voice.stats.rewritten = Voice.stats.rewritten + 1
        Voice.lastRewrite = { sent = pendingBody, arrived = body }
        return nil, "rewritten"
    end
    if pendingBody == nil then return nil, "none" end
    local choice = pendingChoice
    pendingBody, pendingChoice = nil, nil
    return choice, "claimed"
end

-- Speak an emote body. `choice` is what the player pinned to this phrase.
--
-- One recording stands for the whole line, however many times the line quotes.
-- Splitting a pin across two spans would mean asking which of them it was for,
-- and the panel asks the question once.
--
-- Quotes have nothing to do with it. They still decide what the language
-- engine translates, because that part rewrites your words and only words in
-- quotes are being said -- but a recording is not your words. Pinning one to a
-- line that narrates is a deliberate act, and the sound is the point of it:
-- "lets a thread of shadow settle into Taelis" wants a hiss over the top as
-- much as any line with speech marks in it. Requiring quotes made a pin the
-- panel showed as set simply not fire, which is indistinguishable from broken.
function Voice.SpeakBody(body, choice)
    if not (choice and choice.line) then return 0 end
    return Voice.PlayLine(choice.line) and 1 or 0
end

--=========================================================================--
--  Other people's lines
--=========================================================================--
-- Sharing a pin ships an address, not a recording: the file is already sitting
-- in the listener's client, and if their build does not carry it they hear
-- nothing. Nothing is uploaded, downloaded or redistributed, which is the only
-- reason this can exist at all.
--
-- What crosses the wire is half a line. The other half is the emote, and the
-- emote is also the only honest proximity test the game offers: a guild message
-- travels a continent, but you see somebody's emote exactly when you are near
-- enough to read it. So an arriving pin is held until its emote shows up and
-- dropped if it never does. That one rule is what keeps a guildmate three zones
-- away from being a disembodied noise, and it costs nothing to enforce, because
-- the emote was always what playback was keyed to.
--
-- The two halves travel separately and can land in either order, so the
-- rendezvous is two-sided: a pin waits for an emote, and a recent emote is
-- remembered in case the pin is the one that arrives late.
local HEAR_WINDOW = 5   -- how long the two halves wait for each other, seconds
-- One cast is broadcast to raid and guild both, so a guildmate in your raid
-- receives it twice. The repeat has to be dropped rather than merely not
-- played: a spare pin left lying around would attach itself to the next thing
-- that player emotes, which is the same bug claimChoice exists to prevent.
local ECHO_WINDOW = 1

-- Which switch governs a pin, by the channel it arrived on. OFFICER is here
-- because nothing stops a guild from routing through it, and someone in your
-- officer chat is someone in your guild.
local HEAR_SOURCE = {
    PARTY = "PARTY",
    RAID = "RAID",
    GUILD = "GUILD",
    OFFICER = "GUILD",
    SAY = "NEARBY",
    YELL = "NEARBY",
    -- An instance group rewrites party and raid traffic into one chat type on
    -- the way out, so which switch it answers to has to be asked of the group
    -- rather than read off the message.
    INSTANCE_CHAT = "GROUP",
}

-- Deliberately not gated on Voice.IsEnabled. Speaking and listening are
-- separate halves: somebody who writes no phrases of their own still has every
-- reason to hear the ones going on around them, and tying the two together
-- would mean switching on a feature that puts text in other people's chat in
-- order to hear sound in your own. The in-character switch still applies --
-- it is the addon's mute, and a mute that let other people's audio through
-- would not be one.
function Voice.CanHear(channel)
    if ns.IsInCharacter and not ns.IsInCharacter() then return false end
    local c = castDB()
    if not (c and type(c.hear) == "table") then return false end
    local key = HEAR_SOURCE[channel]
    if key == "GROUP" then
        key = (Compat and Compat.InRaid and Compat.InRaid()) and "RAID" or "PARTY"
    end
    if not key then return false end
    return c.hear[key] and true or false
end

-- CHAT_MSG_ADDON names its sender with the realm attached and CHAT_MSG_EMOTE
-- usually does not, so the two halves are paired on the part they agree about.
local function shortName(name)
    if isSecret(name) or type(name) ~= "string" then return nil end
    return name:match("^[^-]+")
end

local function myName()
    return shortName(UnitName and UnitName("player"))
end

-- Whether an emote is your own.
--
-- Worth being careful about, because playback only ever runs on your own
-- emote: get this wrong and nothing you cast makes a sound, while the emote
-- itself goes out perfectly every time. There is no error anywhere to find.
--
-- The name alone cannot answer it. The client names you inconsistently -- a
-- realm suffix on one call and not the next, and on WoW: Forever a surname on
-- one and not the next -- so a name that does not match is not proof the line
-- belongs to somebody else. CHAT_MSG_EMOTE also carries the sender's GUID,
-- which is the server's own answer and admits of no variants, so that decides
-- whenever it is there. ns.IsSelfName is the fallback for the Classic flavors,
-- where the event does not carry one.
local function isMine(sender, guid)
    if type(guid) == "string" and guid ~= "" and not isSecret(guid) then
        local mine = UnitGUID and UnitGUID("player")
        if type(mine) == "string" and mine ~= "" and not isSecret(mine) then
            return guid == mine
        end
    end
    return ns.IsSelfName ~= nil and ns.IsSelfName(sender)
end

local heardPins = {}     -- [speaker] = { id = n, at = t, played = bool }
local heardEmotes = {}   -- [speaker] = t

local function clock()
    return (GetTime and GetTime()) or 0
end

local function forget(store, cutoff)
    for who, rec in pairs(store) do
        local at = type(rec) == "table" and rec.at or rec
        if at < cutoff then store[who] = nil end
    end
end

-- A pin off the wire. Everything that could make this somebody else's problem
-- is refused here rather than at playback, so by the time a clip is held there
-- is nothing left to decide.
function Voice.OnBroadcast(id, sender, channel)
    if isSecret(id) or isSecret(channel) then return end
    if type(id) ~= "number" then return end

    local who = shortName(sender)
    if not who then return end
    -- Your own broadcast, handed straight back by the server. You have already
    -- heard this one locally. Nothing observable depends on this today --
    -- your own emote is answered by the speaking half of onEmote and never
    -- reaches hearOther, so a pin filed under your own name is never claimed
    -- by anything. It is here so that stays true by intent rather than by
    -- accident, and test_voice says the same thing where the test would be.
    local me = myName()
    if me and who == me then return end

    if not Voice.CanHear(channel) then return end

    -- Only lines this build already offers. The catalogue is the list of
    -- recordings the panel will let anybody pin, so anything outside it did not
    -- come from a phrase somebody picked -- and an id is otherwise an open
    -- invitation to play whatever file in the game is loudest or longest.
    -- A sender on a newer catalogue is silently dropped, which is the right way
    -- round: a line you cannot hear beats a line you cannot refuse.
    local gv = ns.GameVoices
    if not (gv and gv.ById and gv.ById[id]) then return end

    local now = clock()
    forget(heardPins, now - HEAR_WINDOW)
    forget(heardEmotes, now - HEAR_WINDOW)

    local pin = heardPins[who]
    if pin and pin.id == id and (now - pin.at) <= ECHO_WINDOW then return end

    if heardEmotes[who] then
        heardEmotes[who] = nil
        heardPins[who] = { id = id, at = now, played = true }
        Voice.PlayGame(id, "other")
        return
    end
    heardPins[who] = { id = id, at = now, played = false }
end

-- The emote half, for somebody who is not you.
local function hearOther(who)
    if not who then return end
    local now = clock()
    forget(heardPins, now - HEAR_WINDOW)
    forget(heardEmotes, now - HEAR_WINDOW)

    local pin = heardPins[who]
    if pin and not pin.played then
        pin.played = true
        Voice.PlayGame(pin.id, "other")
        return
    end
    heardEmotes[who] = now
end

--=========================================================================--
--  Listening
--=========================================================================--
-- CHAT_MSG_EMOTE is the whole input. Its message is the emote body alone --
-- the client prepends the name when it draws the line -- which is exactly the
-- string Casts.Render produced, so the quoted spans in it are the spans that
-- were meant to be heard.
local function onEmote(msg, sender, guid)
    local st = Voice.stats
    st.emotes = st.emotes + 1

    -- Midnight can hand chat arguments over as secret values, which cannot be
    -- read or compared at all. Counted rather than merely refused, because the
    -- handler then does nothing and that looks identical to it never firing.
    if isSecret(msg) or isSecret(sender) then
        st.secret = st.secret + 1
        return
    end
    if type(msg) ~= "string" or msg == "" then return end

    local me = myName()
    local who = shortName(sender)
    if not (me and who) then
        st.nameless = st.nameless + 1
        return
    end

    -- Any emote, quoted or not. A pin belongs to the phrase, not to the speech
    -- marks inside it, and this is the only proximity test the game offers --
    -- so narrowing it to lines with quotes in them would drop the half of the
    -- rendezvous that somebody's narration pin was waiting on.
    if not isMine(sender, guid) then
        -- Kept so the report can show the pair when nothing is being
        -- recognised as yours, which otherwise looks like the event is simply
        -- not firing.
        Voice.lastStranger = { sender = sender, me = me }
        hearOther(who)
        return
    end

    st.mine = st.mine + 1
    if not Voice.IsEnabled() then return end
    Voice.stats.heard = Voice.stats.heard + 1
    local choice, why = claimChoice(msg)
    if why ~= "rewritten" and not (choice and choice.line) then
        Voice.stats.unpinned = Voice.stats.unpinned + 1
    end
    Voice.SpeakBody(msg, choice)

    -- Broadcast from here rather than from where the line was composed,
    -- because this event is the proof the server accepted the emote. A pin
    -- sent for a line that was never delivered would be a sound with nothing
    -- to belong to, and the listener would hold it against whatever that
    -- player said next.
    if choice and choice.line and ns.BroadcastVoicePin then
        ns.BroadcastVoicePin(Voice.GameId(choice.line))
    end
end

Voice.OnEmote = onEmote

-- A real event registration rather than a ChatFrame filter, because a filter
-- is invoked once per chat frame listening for the event and would play the
-- clip once per window. See the header.
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_EMOTE")
-- The sender's GUID is the twelfth argument of every CHAT_MSG_* event, after
-- the nine positions between the sender and it that this handler has no use
-- for. Spelled out rather than fetched with select() so the count is checkable
-- against Blizzard's list by reading it.
frame:SetScript("OnEvent", function(_, event, msg, sender, _, _, _, _, _, _, _, _, _, guid)
    if event ~= "CHAT_MSG_EMOTE" then return end
    onEmote(msg, sender, guid)
end)

-- The one line CHAT_MSG_EMOTE never delivers: a phrase Blizzard refused to
-- send, which Casts prints locally instead. Called from there so the RP beat
-- still has its sound even inside a raid encounter.
function Voice.SpeakLocal(body)
    if not Voice.IsEnabled() then return 0 end
    return Voice.SpeakBody(body, claimChoice(body))
end

-- Audition a pinned line for the play button on the phrase panel. Deliberately
-- not gated on IsEnabled: pressing play is a direct request, and refusing it
-- because the feature is switched off would leave somebody picking a line they
-- are not allowed to hear first.
function Voice.Audition(spoken)
    return Voice.PlayLine(spoken, "audition")
end

--=========================================================================--
--  Diagnostics
--=========================================================================--
function Voice.Describe()
    local gv = ns.GameVoices
    local c = castDB()
    -- Named by source rather than returned as the saved table, because the
    -- question anyone asks of this is "why can I not hear him", and the answer
    -- is a list of who you said yes to.
    local hearing = {}
    for _, key in ipairs({ "PARTY", "RAID", "GUILD", "NEARBY" }) do
        if c and type(c.hear) == "table" and c.hear[key] then
            hearing[#hearing + 1] = key:lower()
        end
    end
    return {
        enabled = Voice.IsEnabled(),
        catalogue = (gv and gv.COUNT) or 0,
        stats = Voice.stats,
        lastRewrite = Voice.lastRewrite,
        lastStranger = Voice.lastStranger,
        hearing = hearing,
        canHearNearby = (Compat and Compat.hasProximityAddonMessages) or false,
    }
end
