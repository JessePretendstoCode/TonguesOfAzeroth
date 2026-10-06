--[[-------------------------------------------------------------------------
    Glyphic - Core.lua
    Wires the language engine into chat: auto-translate toggle, slash commands,
    per-channel filters, and learned-language decoding on incoming messages.

    Notes:
      * On the Classic flavors SendChatMessage is not a protected function, so
        wrapping it (as Tongues and similar RP addons do) is safe for
        say/yell/party/etc. Midnight and Forever need the pre-send event instead
        -- see usesPreSendPipeline below.
      * WoW chat has a 255 character limit; translations are longer than the
        source, so output is trimmed to fit.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language
local Compat = ns.Compat
local Colors = ns.Colors

local MAX_MESSAGE = 255

-- Retail 12.0 (Midnight) "secret values": chat text/sender from other players
-- (e.g. inside instances) can arrive as opaque values that tainted addon code
-- is forbidden to read, compare, gsub or even boolean-test -- doing so throws a
-- hard Lua error. issecretvalue() is the sanctioned way to detect them (nil on
-- older clients, where nothing is ever secret). We can't decode what we can't
-- read, so callers bail cleanly when a value is secret.
local _issecretvalue = issecretvalue
local function isSecret(v)
    return _issecretvalue ~= nil and _issecretvalue(v) == true
end
ns.IsSecret = isSecret

-- Set true while we're inside an instance and the "auto-disable in instances"
-- option is on. When set, Glyphic leaves chat completely alone (no translate/accent
-- outgoing, no decode incoming) and flips back off automatically on leaving.
local instanceSuppressed = false
function ns.IsInstanceSuppressed() return instanceSuppressed end

local CHAT_TYPE_ALIASES = {
    PARTY_LEADER = "PARTY",
    RAID_LEADER  = "RAID",
}

local function normalizeChatType(chatType)
    if not chatType then return "SAY" end
    chatType = string.upper(chatType)
    return CHAT_TYPE_ALIASES[chatType] or chatType
end

local function fit(text, maxLen)
    maxLen = maxLen or MAX_MESSAGE
    if not text then return "" end
    if #text > maxLen then
        return string.sub(text, 1, maxLen)
    end
    return text
end

local function translateOutgoing(msg, langId, strength)
    local ok, translated = pcall(Language.TranslateText, msg, strength, langId)
    if not ok or not translated or translated == "" then
        return fit(msg)
    end
    return fit(translated)
end

-- The order the Chat Channels tab draws its checkboxes in. EMOTE was missing from this
-- list while sitting in DEFAULT_CHANNELS below, which meant emotes were
-- translated and nothing anywhere could turn that off.
local CHANNEL_TYPES = {
    "SAY", "YELL", "EMOTE", "WHISPER", "PARTY", "RAID", "RAID_WARNING",
    "INSTANCE_CHAT", "GUILD", "OFFICER", "CHANNEL",
}

local DEFAULT_CHANNELS = {
    SAY            = true,
    YELL           = true,
    -- Off, unlike every other channel. An emote is narration, not speech --
    -- "/e straightens her cloak" is the story describing you in the third
    -- person -- so putting it through a tongue has the narrator speaking
    -- Darnassian about you. Accents reached this conclusion already
    -- (db.accent.emotes defaults false); the tongue never did.
    EMOTE          = false,
    PARTY          = true,
    RAID           = true,
    RAID_WARNING   = true,
    INSTANCE_CHAT  = true,
    GUILD          = true,
    OFFICER        = true,
    WHISPER        = true,
    CHANNEL        = true,
}

local CHAT_EVENTS = {
    CHAT_MSG_SAY             = "SAY",
    CHAT_MSG_YELL            = "YELL",
    -- Emotes are translated on the way out (a typed /e goes through the same
    -- transform as a /say), so they have to be decoded on the way in too --
    -- and cast phrases put spoken words inside an emote by design.
    CHAT_MSG_EMOTE           = "EMOTE",
    CHAT_MSG_WHISPER         = "WHISPER",
    CHAT_MSG_PARTY           = "PARTY",
    CHAT_MSG_PARTY_LEADER    = "PARTY",
    CHAT_MSG_RAID            = "RAID",
    CHAT_MSG_RAID_LEADER     = "RAID",
    CHAT_MSG_RAID_WARNING    = "RAID_WARNING",
    CHAT_MSG_GUILD           = "GUILD",
    CHAT_MSG_OFFICER         = "OFFICER",
    CHAT_MSG_CHANNEL         = "CHANNEL",
}

-- Chat types whose sender is someone you are talking to, and so a name you may
-- well type back at them. Deliberately excludes CHANNEL: Trade and General would
-- pour hundreds of strangers onto the protected list, and every name on it is a
-- word you can no longer say in character.
local CONVERSATIONAL = {
    SAY = true, YELL = true, EMOTE = true, WHISPER = true,
    PARTY = true, RAID = true, RAID_WARNING = true,
    GUILD = true, OFFICER = true,
}

local PREFIX = "|cff8000ff[Glyphic]|r "
local ADDON_PREFIX = "ToA2"
local MAX_ADDON_PAYLOAD = 240
-- Marker that distinguishes an in-game "here's a custom language" broadcast from
-- the ordinary decode-sync payloads that share the same addon prefix.
local LANG_SHARE_TAG = "TOAL1:"
-- ...and the recording pinned to a cast phrase, as "TOAV1:<fileDataId>". The
-- number addresses a file the receiving client already has, so this carries no
-- audio and nothing is redistributed. See Voice.lua.
local VOICE_TAG = "TOAV1:"

local function addonDistribution(chatType, channel)
    chatType = normalizeChatType(chatType)
    if chatType == "WHISPER" and channel and channel ~= "" then
        return "WHISPER", channel
    end
    if chatType == "PARTY" or chatType == "RAID" or chatType == "GUILD" or chatType == "OFFICER" then
        return chatType
    end
    return nil
end

local function sendDecodePayload(original, encoded, langId, strength, chatType, channel)
    if not Compat.canSendAddonMessage or original == encoded then return end
    local payload = langId .. "\001" .. tostring(strength or 100) .. "\001" .. original .. "\001" .. encoded
    if #payload > MAX_ADDON_PAYLOAD then return end

    local function send(dist, target)
        if dist == "WHISPER" and target then
            Compat.SendAddonMessage(ADDON_PREFIX, payload, dist, target)
        elseif dist then
            Compat.SendAddonMessage(ADDON_PREFIX, payload, dist)
        end
    end

    local dist, target = addonDistribution(chatType, channel)
    send(dist, target)

    -- Say/Yell/Emote have no addon channel; mirror payload to party/raid so
    -- grouped friends can decode. Emote is here for the cast phrases in
    -- Casts.lua, whose spoken parts ride inside an emote.
    local sayType = normalizeChatType(chatType)
    if sayType == "SAY" or sayType == "YELL" or sayType == "EMOTE" then
        if Compat.InRaid() then
            send("RAID")
        elseif Compat.InParty() then
            send("PARTY")
        end
    end
end

-- Tell anyone who might be reading this emote which recording goes with it.
--
-- Sent on every channel that applies rather than on the single best one: a
-- guildmate standing beside you need not be in your group, and the audience is
-- whoever is actually there. That means a guildmate in your raid gets it twice,
-- which only the receiver can sort out -- from here there is no way to know who
-- hears which channel. Voice.lua drops the repeat.
--
-- Say carries addon traffic on the Classic flavors alone. It is the only way to
-- reach a stranger standing next to you, and on Retail there is no way at all.
function ns.BroadcastVoicePin(id)
    if not Compat.canSendAddonMessage then return end
    if type(id) ~= "number" then return end
    local payload = VOICE_TAG .. tostring(id)
    if #payload > MAX_ADDON_PAYLOAD then return end

    if Compat.InRaid() then
        Compat.SendAddonMessage(ADDON_PREFIX, payload, "RAID")
    elseif Compat.InParty() then
        Compat.SendAddonMessage(ADDON_PREFIX, payload, "PARTY")
    end
    if type(IsInGuild) == "function" and IsInGuild() then
        Compat.SendAddonMessage(ADDON_PREFIX, payload, "GUILD")
    end
    if Compat.hasProximityAddonMessages then
        Compat.SendAddonMessage(ADDON_PREFIX, payload, "SAY")
    end
end

-- Resolve the chat window that decoded translations should print to. Players
-- can send the (often noisy) decode output to a dedicated tab -- e.g. "Chat 3"
-- -- via the "Show translations in" setting; 0 keeps it in the default window.
local function getDecodeFrame()
    local idx = GlyphicDB and GlyphicDB.outputFrame
    if idx and idx >= 1 then
        local f = _G["ChatFrame" .. idx]
        if f and f.AddMessage then
            return f
        end
    end
    return DEFAULT_CHAT_FRAME
end

-- Addon output. Command feedback goes to the default window; decoded
-- translations can be routed to a chosen window by passing `frame`.
local function addToChat(msg, style, frame)
    local r, g, b = 1, 1, 0.5
    if style == "whisper" then
        if ChatTypeInfo and ChatTypeInfo.WHISPER then
            local info = ChatTypeInfo.WHISPER
            r, g, b = info.r, info.g, info.b
        else
            r, g, b = 1, 0.5, 1
        end
    elseif ChatTypeInfo and ChatTypeInfo.EMOTE then
        local info = ChatTypeInfo.EMOTE
        r, g, b = info.r, info.g, info.b
    end

    frame = frame or DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage(msg, r, g, b)
    end
end

local function Print(msg)
    addToChat(PREFIX .. msg, "system")
end

-- Cast phrase pacing, in one place because four files need to agree on it: the
-- migration that seeds a new character, the sliders that display it, the slash
-- command that reports it, and the roll itself. Every one of those used to
-- carry its own `or 35`, so changing the default meant changing seven literals
-- and a disagreement between any two of them was invisible.
--
-- Deliberately rare. A cast phrase is text in other people's chat, and the
-- failure mode of a spammable spell is a wall of it -- so the pauses start at
-- the top of both sliders and the roll starts low. Somebody who wants their
-- character talking constantly can find the sliders; somebody who ticks a pack
-- to see what it does should not have to.
local CAST_DEFAULTS = {
    chance   = 5,     -- percent of casts that even roll a line
    gap      = 120,   -- quiet period after any line, seconds (slider maximum)
    spellGap = 300,   -- ...and before the same spell speaks again (slider maximum)
}
ns.CAST_DEFAULTS = CAST_DEFAULTS

-- The folder rename, 0.5.3. This one runs at FILE SCOPE rather than inside
-- migrateDB, and the difference matters: WoW names a saved variables file
-- after the addon FOLDER, so moving TonguesOfAzeroth/ to Glyphic/ left every
-- existing profile sitting in a file this addon no longer causes to be read.
-- The TonguesOfAzeroth shim shipped beside us exists for one purpose -- to
-- declare these two globals, which is what makes the client load that file --
-- and `## OptionalDeps: TonguesOfAzeroth` is what guarantees it has done so
-- before this line runs.
--
-- At file scope because the account-wide table is created lazily by the first
-- thing that writes a color, and migrateDB is not guaranteed to have run by
-- then. Adopting here, while Core.lua is still loading, means no module can
-- reach either table before the handover. Nothing above us in the TOC touches
-- them at file scope; that is checked, not assumed.
--
-- Each global is cleared only in the branch that took it, never unconditionally:
-- clearing one we did not adopt would discard real settings if the shim ever
-- loaded late. Cleared at all so the old file drains to nil on logout and the
-- shim can be dropped in a later release without stranding anything.
if GlyphicDB == nil and TonguesOfAzerothDB ~= nil then
    GlyphicDB = TonguesOfAzerothDB
    TonguesOfAzerothDB = nil
end
if GlyphicAccountDB == nil and TonguesOfAzerothAccountDB ~= nil then
    GlyphicAccountDB = TonguesOfAzerothAccountDB
    TonguesOfAzerothAccountDB = nil
end

-- Latches true once migration is fully done. migrateDB() is called on the hot
-- path (every incoming AND outgoing chat message), so after the one-time work is
-- complete we skip the whole body instead of re-checking ~40 fields per message.
-- We only latch once the *deferred* fluency migration has run (it needs the
-- Trainer module, which loads after this file), so nothing is missed.
local dbFullyMigrated = false

local function migrateDB()
    if dbFullyMigrated then return end
    if GlyphicDB == nil and OldGodTonguesDB ~= nil then
        GlyphicDB = OldGodTonguesDB
    end
    GlyphicDB = GlyphicDB or {}
    local db = GlyphicDB

    if db.strength == nil and db.corruption ~= nil then
        db.strength = db.corruption
    end
    if db.strength == nil then
        db.strength = 100
    end

    -- One switch for "am I speaking in character right now", covering the tongue
    -- AND the accent. It replaces two separate enables that each governed half
    -- your voice, which is what made the two read as unrelated addons.
    --
    -- Note this is NOT "is the addon on": with it off you still decode other
    -- players, still get the per-language colors, still run the Trainer. It is
    -- the switch you hit to answer your raid leader in plain English and then
    -- hit again, many times a session -- which is exactly why disabling the
    -- addon in Blizzard's list is not a substitute for it.
    if db.inCharacter == nil then
        -- Either old switch being on means this character had a voice, so the
        -- one switch inherits both. "Accents on, translation off" was a working
        -- and popular setup -- plain English in your own accent -- and reading
        -- only db.enabled here would silently strip the accent on upgrade.
        db.inCharacter = (db.enabled or (db.accent and db.accent.enabled)) and true or false
        -- That setup now has an honest spelling: in character, speaking no
        -- particular tongue. Without this the upgrade would hand them a
        -- language they had deliberately switched off and put them in Orcish
        -- mid-sentence.
        if db.enabled == false and db.accent and db.accent.enabled then
            db.language = "none"
        end
    end
    db.enabled = nil

    -- A short-lived "how much comes through" cap used to live here, separate
    -- from fluency. Two numbers for one question turned out to be worse than
    -- the problem it solved: nobody could say which one they were reading. How
    -- well you speak a tongue is just your fluency in it, set on its own row
    -- under Languages. Cleared rather than left behind so it can't quietly
    -- throttle anyone who ran a build that had it.
    db.speakLevel = nil
    -- The redundant generic "troll" language was merged into "zandali"; carry
    -- over anyone who was speaking/learning it so nothing silently resets.
    if db.language == "troll" then db.language = "zandali" end
    if db.learned and db.learned["troll"] then
        db.learned["zandali"] = true
        db.learned["troll"] = nil
    end
    -- Aliases that were only a second name for a tongue already in the list
    -- ("Eredun (Demonic)" beside "Demonic (Eredun)") are hidden now. They still
    -- resolve, but leaving someone parked on one would show a language absent
    -- from every list, so anything saved moves to the name that is shown.
    if db.language and Language.CanonicalId then
        db.language = Language.CanonicalId(db.language)
    end
    if db.learned and Language.CanonicalId then
        -- Collected before anything is written: adding a key to a table while
        -- pairs() is walking it is undefined in Lua.
        local moved
        for id in pairs(db.learned) do
            local canon = Language.CanonicalId(id)
            if canon ~= id then
                moved = moved or {}
                moved[id] = canon
            end
        end
        if moved then
            for id, canon in pairs(moved) do
                db.learned[canon] = true
                db.learned[id] = nil
            end
        end
    end
    if db.language == nil or not Language.IsValid(db.language) then
        db.language = Language.DEFAULT
    end

    -- Hand-curated shortlist of languages. An ordered array rather than a set,
    -- so it stays in the order you built it.
    if type(db.favorites) ~= "table" then db.favorites = {} end
    if Language.CanonicalId then
        local seen = {}
        for i = #db.favorites, 1, -1 do
            local canon = Language.CanonicalId(db.favorites[i])
            -- Canonicalising can collide two entries onto one; drop the dupe
            -- rather than leaving the same tongue starred twice.
            if seen[canon] then
                table.remove(db.favorites, i)
            else
                seen[canon] = true
                db.favorites[i] = canon
            end
        end
    end
    -- Whether cycling walks only the favorites. Toggled by the star on the
    -- floating bar, and inert until the list has something in it.
    if db.favOnly == nil then db.favOnly = true end

    -- The tongue your character grew up speaking, which words the one they are
    -- attempting does not cover fall back on. Off by default and left off on
    -- upgrade: it changes what every existing character sounds like, and a
    -- setting that rewrites your speech is one you should have to ask for.
    if db.motherTongue ~= nil then
        local canon = Language.CanonicalId and Language.CanonicalId(db.motherTongue)
            or db.motherTongue
        -- A custom language can be deleted while it is still named here, which
        -- would otherwise leave every line falling back to a tongue that no
        -- longer exists.
        if canon and Language.IsValid(canon) then
            db.motherTongue = canon
        else
            db.motherTongue = nil
        end
    end

    if not db.channels then
        db.channels = {}
    end
    for ch, default in pairs(DEFAULT_CHANNELS) do
        if db.channels[ch] == nil then
            db.channels[ch] = default
        end
    end

    if not db.learned then
        db.learned = {}
    end
    -- User-created languages: { [id] = { id, name, apostrophe, onsets, nuclei, codas } }
    if not db.customLanguages then
        db.customLanguages = {}
    end
    if db.decodeStyle == nil then
        db.decodeStyle = "inline"
    end
    -- One-time: move existing users onto the new in-line display (the chat line
    -- itself is rewritten, like retail). They can pick a legacy style again
    -- under Chat Channels -> When you listen if they prefer the old separate line.
    if not db.decodeStyleV2 then
        db.decodeStyle = "inline"
        db.decodeStyleV2 = true
    end
    -- Which chat window the addon's decoded translations are printed to.
    -- 0 = the default chat frame; 1..NUM_CHAT_WINDOWS = that ChatFrame index.
    if db.outputFrame == nil then
        db.outputFrame = 0
    end
    -- The "[Language] " tag is always on (non-configurable): it's the signal
    -- receivers rely on to decode without false-positiving on plain chat. Force it
    -- true so a saved-var that previously had it off still behaves consistently.
    db.tagLanguage = true
    -- Include a fluency adjective in that tag (Broken/Partial/Fluent) based on
    -- your Language Trainer progress for the spoken language. This prefix stays
    -- optional (see the "Show fluency in tag" checkbox).
    if db.tagFluency == nil then
        db.tagFluency = true
    end
    -- Hide the tongues your race already speaks in-game (Common for a Human,
    -- Orcish + Taur-ahe for a Tauren, ...) from the speak list. Display-only.
    if db.hideNativeLanguages == nil then
        db.hideNativeLanguages = true
    end
    -- Automatically switch Glyphic off while inside an instance (and back on when you
    -- leave). Blizzard's "secret" chat protection blocks addons from reading chat
    -- during boss fights, so translations can't be decoded there. On by default;
    -- toggle with /glyphic autodisable or the options checkbox.
    if db.autoDisableInInstances == nil then
        -- Carry over the old warn-only flag if the player had turned it off.
        if db.warnInstances == false then
            db.autoDisableInInstances = false
        else
            db.autoDisableInInstances = true
        end
    end
    if not db.minimap then
        db.minimap = {}
    end
    if db.minimap.hide == nil then
        db.minimap.hide = false
    end
    if db.minimap.angle == nil then
        db.minimap.angle = 200
    end

    -- Passive learning: overhearing a tongue slowly builds fluency in it. On by
    -- default -- players who prefer trainer-only learning can turn it off.
    if db.passiveLearning == nil then
        db.passiveLearning = true
    end

    -- One-time: "strength" used to be a single global slider; now speaking
    -- strength IS your per-language fluency. Seed the language you were actively
    -- speaking from that old strength (only if you have no fluency in it yet) so
    -- you don't suddenly speak plain English in it. Deferred until the trainer
    -- module is loaded so the fluency store exists.
    -- A plain tongue is never seeded. Fluency in "speak plainly" is not a thing
    -- you can have, and a fresh install arrives here with language = "none" and
    -- the default strength of 100 -- so without this guard, installing the addon
    -- would hand a brand-new character 100% fluency in something.
    if not db.fluencyMigrated and ns.Trainer and ns.Trainer.SetFluency and ns.Trainer.GetProgress then
        db.fluencyMigrated = true
        local s = db.strength
        if type(s) == "number" and s > 0 and db.language
            and not Language.IsPlain(db.language) then
            local _, _, cur = ns.Trainer.GetProgress(db.language)
            if (tonumber(cur) or 0) <= 0 then
                ns.Trainer.SetFluency(db.language, s / 100)
            end
        end
    end

    if not db.accent then db.accent = {} end
    if db.accent.strength == nil then db.accent.strength = 100 end
    -- Emotes describe an action ("/e waves"), so accenting them reads oddly.
    -- Off by default; players can opt in on the Accents tab.
    if db.accent.emotes == nil then db.accent.emotes = false end
    -- "No accent" is an entry in the accent list now, not a checkbox beside it,
    -- so the old accent.enabled flag folds into the selection itself.
    local NONE = (ns.Accent and ns.Accent.NONE) or "none"
    if db.accent.enabled == false then
        -- Switched off: land on "none", but remember what they had picked so
        -- "/glyphic accent on" hands their own accent back rather than Dwarven.
        if db.accent.id and db.accent.id ~= NONE then db.accent.lastId = db.accent.id end
        db.accent.id = NONE
    elseif db.accent.enabled == nil and db.accent.id == nil then
        -- Fresh profile. Accents stay off until asked for, exactly as they
        -- always did -- that used to be enabled=false with a default id sitting
        -- unused behind it, and is now simply a selection of "none".
        db.accent.id = NONE
    end
    db.accent.enabled = nil
    if not (ns.Accent and ns.Accent.IsValid(db.accent.id)) then
        db.accent.id = (ns.Accent and ns.Accent.DEFAULT) or "dwarf"
    end
    -- How often sentence-end interjections (", aye.", ", mon.") fire. 0 turns
    -- them off entirely; see Accent.SetTailFrequency for the scale.
    if db.accent.tails == nil then
        db.accent.tails = (ns.Accent and ns.Accent.TAIL_DIAL_DEFAULT) or 40
    end
    if ns.Accent and ns.Accent.SetTailFrequency then
        ns.Accent.SetTailFrequency(db.accent.tails)
    end
    -- Accents used to carry their own channel list beside the language one, so
    -- "where does my voice apply" had two answers that could disagree. There is
    -- one list now: the channels you are in character in, governing the tongue
    -- and the accent alike.
    --
    -- The language list wins the merge rather than the union of the two. Union
    -- would switch translation ON in a channel somebody had deliberately
    -- silenced, leaving them unintelligible where they had chosen to be clear;
    -- losing an accent somewhere is cosmetic and one click to restore.
    db.accent.channels = nil

    -- Leave player names readable inside translated speech. On by default: real
    -- languages don't translate proper nouns either, and a listener who catches
    -- their own name in a line of Demonic knows it was aimed at them. See
    -- Names.lua for where the list of names comes from and what stops it
    -- swallowing ordinary words.
    if db.protectNames == nil then db.protectNames = true end

    -- And paint them, so it is visible which words survived on purpose rather
    -- than because the fluency roll left them in English.
    if db.colorNames == nil then db.colorNames = true end

    -- Cast phrases: emote a line when one of your spells lands. Off until asked
    -- for -- it puts text in other people's chat, so it should never be a
    -- surprise. See Casts.lua for why phrases are keyed by spell *name*.
    if not db.casts then db.casts = {} end
    local casts = db.casts
    if casts.enabled == nil then casts.enabled = false end
    if casts.chance == nil then casts.chance = CAST_DEFAULTS.chance end
    if casts.gap == nil then casts.gap = CAST_DEFAULTS.gap end
    if casts.spellGap == nil then casts.spellGap = CAST_DEFAULTS.spellGap end
    if casts.pets == nil then casts.pets = true end

    -- Whose pinned recordings you are willing to hear. Pinning a line of your
    -- own is the whole of the consent to hear yourself; it says nothing about
    -- a stranger, so this is a separate answer and it is given per source.
    --
    -- On for the people you chose to be among and off for everyone else. That
    -- is the split that decides whether an unfamiliar sound is a bit of
    -- somebody's roleplay or a noise your game started making. Nearby does
    -- nothing at all on Retail, which carries no addon traffic to a player you
    -- are not grouped or guilded with.
    if type(casts.hear) ~= "table" then casts.hear = {} end
    if casts.hear.PARTY == nil then casts.hear.PARTY = true end
    if casts.hear.RAID == nil then casts.hear.RAID = true end
    if casts.hear.GUILD == nil then casts.hear.GUILD = true end
    if casts.hear.NEARBY == nil then casts.hear.NEARBY = false end

    -- Which library packs are switched off: { [packId] = false }. Absence means
    -- on, so this is normally empty and there is no longer any panel that fills
    -- it -- see Casts.IsPackEnabled.
    if type(casts.packs) ~= "table" then casts.packs = {} end
    -- Your own phrases: { [spellKey] = { { text = "...", weight = 3 }, ... } }.
    if type(casts.spells) ~= "table" then casts.spells = {} end
    -- Spells silenced even though an enabled pack covers them.
    if type(casts.muted) ~= "table" then casts.muted = {} end
    -- Pack lines removed from a spell: { [spellKey] = { [text] = true } }. Only
    -- pack lines are here -- one you wrote yourself is deleted outright, since
    -- nothing would offer it again. See Casts.RemovePhrase.
    if type(casts.hidden) ~= "table" then casts.hidden = {} end
    -- The character sheet is gone: a Bearing and Wording used to weight the
    -- library, but the weighting dropped every non-matching group entirely, so
    -- a character only ever reached one or two lines of the five-odd written per
    -- spell. The library now ships two or three lines that suit anyone, which is
    -- the same reach without the panel. Dropped rather than left in place so it
    -- does not sit in the saved file looking meaningful.
    casts.tone = nil
    if casts.filterSpellbook == nil then casts.filterSpellbook = true end

    -- Three settings that used to have panels and no longer do.
    --
    -- `voice` was a second yes for speaking a phrase aloud. A phrase is silent
    -- until a recording is pinned to it, so pinning was already the answer, and
    -- a switch that defaulted off existed mainly to stop the pinning working.
    -- `packsSeeded` guarded a one-time tick of the obvious packs, which is moot
    -- now that every pack is on unless refused. `showOtherPacks` revealed the
    -- other classes' tickboxes, and there are no tickboxes.
    --
    -- Cleared rather than left behind: a value nothing reads and nothing can
    -- set is just a thing in the saved file that looks like it means something.
    casts.voice = nil
    casts.voiceOthers = nil
    casts.packsSeeded = nil
    casts.showOtherPacks = nil

    -- Two settings from the synthesised-voice era, both now meaningless.
    -- `casts.voices` named a race and gender to render a line in; there is
    -- nothing left to render. `casts.spoken` could hold either a recording id
    -- or the literal words of a library phrase, and the words addressed a clip
    -- that no longer exists -- so anything that is not an id is dropped. Left
    -- in place it would sit in the panel looking chosen and play silence.
    casts.voices = nil
    if type(casts.spoken) == "table" then
        for _, byText in pairs(casts.spoken) do
            if type(byText) == "table" then
                for text, pinned in pairs(byText) do
                    if type(pinned) ~= "string" or not pinned:match("^game:%d+$") then
                        byText[text] = nil
                    end
                end
            end
        end
    end

    -- Weights used to run 0..5, which put the nudge buttons on twenty-point
    -- jumps and left no way to say "a bit less than that one". They run 0..20
    -- now, so a saved 3 means a fifth of what it used to unless it is carried
    -- across.
    --
    -- Multiplied in the save rather than scaled on every read: a weight is
    -- compared against the other weights in its own list, so a half-converted
    -- list is a wrong list, and doing it once at a known moment is the only way
    -- to be sure there isn't one. The old and new maxima are written out rather
    -- than read from Casts.MAX_WEIGHT, because this step converts 5 to 20 and
    -- must keep doing exactly that if the scale ever moves again.
    if not casts.weightScaleV2 then
        casts.weightScaleV2 = true
        if type(casts.weights) == "table" then
            for _, byText in pairs(casts.weights) do
                if type(byText) == "table" then
                    for text, w in pairs(byText) do
                        if type(w) == "number" then
                            byText[text] = math.max(0, math.min(20, math.floor(w * 4 + 0.5)))
                        end
                    end
                end
            end
        end
    end

    -- The creed packs are gone. What a character believes is exactly the sort
    -- of thing that wants writing rather than ticking, and eight tickboxes were
    -- never going to cover anybody properly -- so the lines they carried are
    -- now yours to write, and the audio for them stayed behind in the manifest.
    -- Their tickboxes no longer exist, so clear them rather than leave settings
    -- nobody can see or reach. Matched on the id prefix, because the point is
    -- to not carry a list of dead packs around forever.
    for id in pairs(casts.packs) do
        if type(id) == "string" and id:sub(1, 6) == "creed_" then
            casts.packs[id] = nil
        end
    end

    -- One-time: enable all channel toggles (older saves may have some off).
    if not db.channelDefaultsVersion or db.channelDefaultsVersion < 2 then
        for ch, enabled in pairs(DEFAULT_CHANNELS) do
            db.channels[ch] = enabled
        end
        db.channelDefaultsVersion = 2
    end

    -- One-time: stop translating emotes for everybody who already has a save.
    -- Flipping the default above only reaches new profiles, because the loop
    -- that fills in defaults skips anything already set -- and EMOTE has been
    -- sitting in every save as true since the first release.
    --
    -- Safe to overwrite rather than respect, which is normally the wrong thing
    -- to do to a saved setting: there was no checkbox for this until now, so a
    -- stored true is a default nobody chose, not a preference being thrown
    -- away. Anyone who wants it back has a control to do it with.
    if db.channelDefaultsVersion < 3 then
        db.channels.EMOTE = false
        db.channelDefaultsVersion = 3
    end

    -- Only stop re-running once the Trainer-dependent fluency migration is done;
    -- until then we keep re-entering so it can finish when Trainer is available.
    if db.fluencyMigrated then dbFullyMigrated = true end
end

function ns.IsChannelEnabled(chatType)
    migrateDB()
    chatType = normalizeChatType(chatType)
    if not GlyphicDB or not GlyphicDB.channels then return false end
    return GlyphicDB.channels[chatType] and true or false
end

-- Kept as a name other code and older saved macros may still reach for. There
-- is one channel list now, so the accent answers the same question the tongue
-- does: am I in character on this channel?
function ns.IsAccentChannelEnabled(chatType)
    return ns.IsChannelEnabled(chatType)
end

-- Speaking strength for the language you're speaking IS your fluency in it: a
-- 40%-fluent speaker renders ~40% of their words in the tongue (sounds broken),
-- a Perfect speaker speaks it fully. This ties how you *sound* to how well you
-- actually know the language. Falls back to the legacy manual strength only if
-- the trainer/fluency module isn't loaded yet.
local function fluencyPercent(langId)
    if not (ns.Trainer and ns.Trainer.GetProgress and langId) then return nil end
    local ok, _, _, frac = pcall(ns.Trainer.GetProgress, langId)
    if not ok or type(frac) ~= "number" then return nil end
    return math.floor(frac * 100 + 0.5)
end

local function getStrength()
    local db = GlyphicDB
    if not db then return 100 end
    local pct = fluencyPercent(db.language)
    if pct == nil then pct = db.strength or 100 end
    return pct
end

-- The strength your chat actually goes out at. Public so the config preview
-- asks for the real number rather than recomputing the rule beside it -- the
-- two drifting apart is exactly how the preview once came to disagree with the
-- control sitting above it.
function ns.GetSpeakingStrength()
    migrateDB()
    return getStrength()
end

-- The tongue your character grew up speaking, which words the language they are
-- attempting does not cover fall back on. nil when they have none, which is the
-- old behaviour: the remainder stays English.
--
-- "Mother tongue" rather than "native language" on purpose. ns.IsNativeLanguage
-- below already means something else entirely -- a tongue the player's *race*
-- speaks through WoW's own system, which this addon hides from the speak list --
-- and one word meaning both would be read wrongly by whoever touches this next.
--
-- Returned rather than read inline because four separate paths translate -- chat,
-- /glyphic say, cast phrases and the options preview -- and a mother tongue that
-- applied to three of them would read as the setting working intermittently.
local function motherTongue()
    local db = GlyphicDB
    if not db then return nil end
    local id = db.motherTongue
    if not id or id == "" then return nil end
    if id == db.language then return nil end
    if not Language.IsValid(id) then return nil end
    return id
end

function ns.GetMotherTongue()
    migrateDB()
    return motherTongue()
end

--=========================================================================--
--  Native languages (hide the tongues your race already speaks in-game)
--
--  WoW reports the languages a character actually speaks via
--  GetLanguageByIndex(), whose second return is a locale-independent numeric
--  languageID (from Languages.db2). We map those IDs to our own language ids and
--  hide them from the "speak" list -- speaking Common as a Human is just plain
--  text, so Glyphic can focus on the tongues you *can't* already speak. This is
--  display-only: /glyphic lang, the Learned tab, and the Trainer keep every language.
--=========================================================================--
-- Blizzard languageID -> Glyphic language id. Matching on the number (not the
-- localized name) means this works identically on every client locale.
local NATIVE_LANG_IDS = {
    [1]   = "orcish",     [2]   = "darnassian", [3]   = "taurahe",
    [6]   = "dwarven",    [7]   = "common",     [8]   = "demonic",
    [9]   = "titan",      [10]  = "thalassian", [11]  = "draconic",
    [12]  = "kalimag",    [13]  = "gnomish",    [14]  = "zandali",
    [33]  = "gutterspeak",[35]  = "draenei",    [39]  = "gilnean",
    [40]  = "goblin",     [42]  = "pandaren",   [43]  = "pandaren",
    [44]  = "pandaren",   [168] = "sprite",     [179] = "nerglish",
    [180] = "moonkin",    [181] = "thalassian", [182] = "thalassian",
    [303] = "furbolg",
}
-- Fallback for very old clients whose GetLanguageByIndex returns only a name
-- (English clients only; every modern client returns the ID above).
local NATIVE_LANG_NAMES = {
    orcish = "orcish", darnassian = "darnassian", taurahe = "taurahe",
    dwarvish = "dwarven", common = "common", demonic = "demonic",
    thalassian = "thalassian", gnomish = "gnomish", zandali = "zandali",
    forsaken = "gutterspeak", gutterspeak = "gutterspeak", draenei = "draenei",
    gilnean = "gilnean", goblin = "goblin", pandaren = "pandaren",
    draconic = "draconic", kalimag = "kalimag", titan = "titan",
}

-- { [toaId] = true } for the tongues this character natively speaks, or nil if
-- we couldn't determine any -- in which case nothing is ever hidden (fail open).
local nativeLangSet = nil
local didNativeInit = false

local function computeNativeLanguages()
    nativeLangSet = nil
    if type(GetNumLanguages) ~= "function" or type(GetLanguageByIndex) ~= "function" then
        return
    end
    local n = GetNumLanguages()
    if not n or n < 1 then return end
    local set = {}
    for i = 1, n do
        local name, id = GetLanguageByIndex(i)
        local toa = (type(id) == "number" and NATIVE_LANG_IDS[id])
            or (type(name) == "string" and NATIVE_LANG_NAMES[string.lower(name)])
        if toa then set[toa] = true end
    end
    if next(set) then nativeLangSet = set end
end

local function nativeHidingOn()
    local db = GlyphicDB
    return (db and db.hideNativeLanguages and nativeLangSet ~= nil) and true or false
end

-- True only when `id` is a tongue the player natively speaks AND hiding is on.
function ns.IsNativeLanguage(id)
    if not nativeHidingOn() then return false end
    return nativeLangSet[id] == true
end

-- GetLanguages() minus the native tongues (when the option is on). Never returns
-- an empty list: if the filter would hide everything, the full list is returned.
function ns.GetSpeakableLanguages()
    local all = Language.GetLanguages()
    if not nativeHidingOn() then return all end
    local out = {}
    for i = 1, #all do
        if not nativeLangSet[all[i].id] then out[#out + 1] = all[i] end
    end
    if #out == 0 then return all end
    return out
end

-- Primary languages minus the native tongues (when the option is on). Used by
-- the Learned tab and the Trainer so they, too, drop what your race already
-- speaks. Never returns an empty list (fail open, same as GetSpeakableLanguages).
function ns.GetSpeakablePrimaryLanguages()
    local all = (Language.GetPrimaryLanguages and Language.GetPrimaryLanguages()) or {}
    if not nativeHidingOn() then return all end
    local out = {}
    for i = 1, #all do
        if not nativeLangSet[all[i].id] then out[#out + 1] = all[i] end
    end
    if #out == 0 then return all end
    return out
end

-- If the language you're set to speak just got hidden, fall back to the first
-- visible one so the dropdown never shows a native/blank selection.
function ns.EnsureSpeakLanguageVisible()
    local db = GlyphicDB
    if not db then return end
    if ns.IsNativeLanguage(db.language) then
        local speak = ns.GetSpeakableLanguages()
        if speak[1] then db.language = speak[1].id end
    end
end

-- Refresh the native set (cheap) and, once only, drop off a hidden language.
-- Called at login and on world entry (in case faction/allied-race unlocks it).
ns.RefreshNativeLanguages = function()
    computeNativeLanguages()
    if not didNativeInit and nativeLangSet then
        didNativeInit = true
        ns.EnsureSpeakLanguageVisible()
    end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
end

--=========================================================================--
--  SendChatMessage wrapper for auto-translate mode.
--=========================================================================--
local orig_SendChatMessage
local ourSendHook
local suppress = false
local hookInstalled = false
local sendHookCount = 0
-- Set by the Retail 12.0+ pre-send callback when it has already rewritten the
-- outgoing text, so the SendChatMessage wrapper (if it also runs on that client)
-- doesn't translate a second time.
local preSendActive = false
local preSendRegistered = false

-- Prepend a "[Language] " flavor tag so listeners (even without the addon) can
-- see which tongue you're speaking, e.g. "[Orcish] <gibberish>". The tag is
-- purely cosmetic: it is NOT part of the decode mapping (see sendDecodePayload
-- below, which is called with the untagged text), and receivers strip it before
-- decoding, so learned-language decoding is unaffected.
-- Roleplay flavor: how well you actually speak the tongue, from your Language
-- Trainer (Wordle) fluency for that language. <25% Broken, <75% Partial,
-- <100% Fluent, 100% Perfect. Returns nil if the trainer module/data is absent.
local function fluencyAdjective(langId)
    if not (ns.Trainer and ns.Trainer.GetProgress) then return nil end
    local ok, _, _, frac = pcall(ns.Trainer.GetProgress, langId)
    if not ok or type(frac) ~= "number" then return nil end
    if frac >= 1 then return "Perfect"
    elseif frac >= 0.75 then return "Fluent"
    elseif frac >= 0.25 then return "Partial"
    else return "Broken" end
end

-- The tongue's name as the player would say it, fluency adjective and all:
-- "Broken Demonic (Eredun)". Split out from languageTag because cast phrases
-- name their language in prose rather than wearing a bracket (see Casts.Render).
local function languageName(langId)
    local name = Language.GetLanguageName(langId)
    local db = GlyphicDB
    if db and db.tagFluency ~= false then
        local adj = fluencyAdjective(langId)
        if adj then name = adj .. " " .. name end
    end
    return name
end

local function languageTag(langId)
    return "[" .. languageName(langId) .. "] "
end

-- Is an accent selected, and does it apply on this channel? Gated by the same
-- in-character switch and the same channel list as the tongue, because they are
-- two halves of one voice. Emotes (/e and inline *actions*) narrate an action
-- rather than speak, so they keep their own opt-in.
local function accentAppliesTo(channelKey)
    local db = GlyphicDB
    if not (ns.Accent and db and db.inCharacter and db.accent) then return false end
    if db.accent.id == ns.Accent.NONE then return false end
    if channelKey == "EMOTE" then return db.accent.emotes and true or false end
    return ns.IsChannelEnabled(channelKey) and true or false
end

-- `live` marks a real utterance; only those advance the accent's tail spacing,
-- so previewing never uses up the flourish your next real line would get.
local function applyAccent(text, live)
    local a = GlyphicDB.accent
    local ok, res = pcall(ns.Accent.Apply, text, a.id, a.strength or 100, a.emotes, live and true or false)
    if ok and type(res) == "string" then return res end
    return text
end

-- Shared outgoing transform. Given a raw message and its chat type, return
-- (outgoingText, changed). Also fires the decode payload for grouped Glyphic users
-- when a translation actually changed the text.
--
-- Language and accent COMPOSE rather than compete. Partial fluency leaves part
-- of the line in English by design, and English spoken by a dwarf should sound
-- dwarven -- so at 40% Orcish you get Orcish words with a Dwarven accent on the
-- rest. The foreign words sit behind sentinels while the accent runs, because
-- they must reach the receiver byte-identical for decoding to find them.
--
-- These two used to race, and the language branch always won: an accent was
-- only ever heard on lines translation had left alone (Common, 0% fluency, a
-- channel with translation off). That was invisible from the UI -- there was a
-- /glyphic debug line whose entire job was explaining why a configured accent
-- appeared to do nothing -- and it is why the two read as separate addons.
local function transformOutgoing(msg, sendType, channel)
    if type(msg) ~= "string" or msg == "" then return msg, false end

    local db = GlyphicDB
    if not db then return msg, false end
    local channelKey = normalizeChatType(sendType)
    local accentOn = accentAppliesTo(channelKey)

    -- Translation is paused inside instances: encoded text is only readable if
    -- the receiver's addon can read chat, which Blizzard blocks there. Accents
    -- are exempt -- they're plain English that needs no decoding -- so the
    -- accent-only branch below still runs.
    -- A native tongue keeps the line worth translating at zero fluency: not
    -- knowing a word of the language you are attempting is exactly when your
    -- own one does all the talking.
    local translating = not instanceSuppressed and db.inCharacter
        and (getStrength() > 0 or motherTongue() ~= nil)
        and ns.IsChannelEnabled(channelKey)

    if translating then
        local langId, strength = db.language, getStrength()
        local marked, marks = Language.TranslateMarked(msg, strength, langId, motherTongue())
        if marks then
            local body = marked
            if accentOn then body = applyAccent(body, true) end
            body = fit(Language.RestoreMarked(body, marks))

            -- Cache and sync the mapping against the text that actually goes
            -- out, accent and all: decoding is a lookup on the exact string the
            -- receiver sees, so remembering the pre-accent version would leave
            -- every composed line undecodable.
            Language.RememberEncodedMessage(langId, msg, body, strength)
            sendDecodePayload(msg, body, langId, strength, sendType, channel)

            -- The "[Language]" tag is always applied: it's the signal receivers use
            -- to know the line is encoded (and in which tongue) so they can decode
            -- it without false-positiving on ordinary chat. Deliberately not
            -- user-configurable; only the fluency adjective prefix is optional.
            return fit(languageTag(langId) .. body), true
        end
        -- Nothing translated: Common and Low Common read as plain speech, and a
        -- line can have no mapped words at low fluency. Fall through so the
        -- accent still gets the whole line.
    end

    if accentOn then
        local out = applyAccent(msg, true)
        return out, out ~= msg
    end
    return msg, false
end

-- The SendChatMessage wrapper. Taint-safe: SendChatMessage is never in the path
-- of protected commands (/target, /cast, /use...), so wrapping it never blocks
-- those. This is the intercept point on the Classic flavors and for our own
-- programmatic sends. On Midnight and Forever typed chat bypasses this path
-- entirely (see onEditBoxPreSend below); `preSendActive` guards the rare case
-- where both fire so we never translate/tag twice.
local function sendHookBody(msg, chatType, language, channel)
    migrateDB()
    sendHookCount = sendHookCount + 1
    local sendType = chatType or "SAY"
    if suppress or preSendActive then
        preSendActive = false
        return orig_SendChatMessage(msg, sendType, language, channel)
    end
    local outMsg = transformOutgoing(msg, sendType, channel)
    return orig_SendChatMessage(outMsg, sendType, language, channel)
end

-- Midnight folded SendChatMessage into the secure chat pipeline: OVERWRITING the
-- global now spreads taint into unrelated protected UI, so simply opening the
-- Character frame or Game Menu throws "attempt to compare a secret number value
-- (execution tainted by 'TonguesOfAzeroth')". Blizzard's sanctioned replacement is
-- the OnEditBoxPreSendText event (see onEditBoxPreSend), which we already register.
-- On those clients we must NEVER clobber the global.
--
-- Probed via issecretvalue rather than an interface number, because the secure chat
-- pipeline and "secrets" shipped as one change: WoW: Forever carries both yet reports
-- a 1.60.x interface (16001), so any ">= 120000" test would take the legacy path and
-- taint the UI. issecretvalue is absent on the Classic flavors, which do still need
-- the global hook.
local function usesPreSendPipeline()
    return _issecretvalue ~= nil
end

-- Installs our SendChatMessage wrapper exactly once. We deliberately do NOT
-- re-assert later: if another addon chain-wraps us afterwards, we still run as
-- part of that chain, and re-capturing their wrapper as our "original" would
-- create mutual recursion (them -> us -> them -> ...). Installing once is both
-- loop-safe and keeps our translation in the send path.
local function installSendHook()
    if type(SendChatMessage) ~= "function" then return end
    -- Always keep a plain reference to the real SendChatMessage for our own
    -- programmatic sends (/glyphic say|yell, speak()). Reading a global is taint-free;
    -- only *writing* it is the problem.
    if not orig_SendChatMessage then orig_SendChatMessage = SendChatMessage end
    ourSendHook = sendHookBody
    -- Retail 12.0+: rely solely on the taint-safe pre-send event; never overwrite.
    if usesPreSendPipeline() then return end
    if hookInstalled then return end
    SendChatMessage = ourSendHook
    hookInstalled = true
end

-- Retail 12.0+ (Midnight) rebuilt the chat send path: typed messages no longer
-- go through the global SendChatMessage, so our wrapper above never sees them.
-- Blizzard added the "ChatFrame.OnEditBoxPreSendText" event *for addons* to make
-- final edits to outgoing text. It fires AFTER slash-command parsing (so
-- protected commands like /target never reach it -> no taint) and BEFORE the
-- text is read for sending, so editBox:SetText() changes the outgoing message.
--
-- Caveat: SetText() during combat lockdown taints the follow-up (protected) send
-- on 12.0+, which Blizzard blocks. We skip translating in combat so the message
-- still goes out (untranslated) rather than erroring -- the same limitation that
-- affects every chat-modifying addon on Midnight.
-- Registered with ns as the callback owner, so this fires as
-- onEditBoxPreSend(owner, editBox). The message text is NOT passed as an
-- argument; it must be read back from the edit box via GetText().
local function onEditBoxPreSend(_, editBox)
    preSendActive = false
    if not GlyphicDB then return end
    if not editBox or not editBox.GetText or not editBox.SetText then return end
    if InCombatLockdown and InCombatLockdown() then return end
    migrateDB()

    local text = editBox:GetText()
    if type(text) ~= "string" or text == "" then return end

    local chatType = "SAY"
    if editBox.GetAttribute then
        chatType = editBox:GetAttribute("chatType") or editBox.chatType or "SAY"
    end
    local channel
    if chatType == "WHISPER" or chatType == "BN_WHISPER" then
        channel = editBox.GetAttribute and editBox:GetAttribute("tellTarget")
    elseif chatType == "CHANNEL" then
        channel = editBox.GetAttribute and editBox:GetAttribute("channelTarget")
    end

    local out, changed = transformOutgoing(text, chatType, channel)
    if changed and out ~= text then
        editBox:SetText(out)
        preSendActive = true
    end
end

local function registerPreSendHook()
    if preSendRegistered then return end
    if type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
        local ok = pcall(EventRegistry.RegisterCallback, EventRegistry,
            "ChatFrame.OnEditBoxPreSendText", onEditBoxPreSend, ns)
        if ok then preSendRegistered = true end
    end
end

-- Yapper (a popular chat addon) replaces Blizzard's edit box with its own overlay
-- and routes outgoing text through its own pipeline (Router / C_ChatInfo.*), so it
-- never touches the global SendChatMessage OR the ChatFrame.OnEditBoxPreSendText
-- event -- our two normal intercept points both miss it. Yapper exposes a public
-- API (_G.YapperAPI) with a "PRE_SEND" filter designed exactly for this: the
-- callback receives { text, chatType, language, target } and returns the (possibly
-- modified) payload, or false to cancel. This is taint-free (no Blizzard globals)
-- and Yapper-sanctioned, so it survives their internal refactors.
local yapperFilterHandle
local function registerYapperFilter()
    if yapperFilterHandle then return end
    local api = _G.YapperAPI
    if type(api) ~= "table" or type(api.RegisterFilter) ~= "function" then return end
    local ok, handle = pcall(api.RegisterFilter, api, "PRE_SEND", function(payload)
        if type(payload) ~= "table" or type(payload.text) ~= "string" then return end
        if not GlyphicDB then return end
        migrateDB()
        local out, changed = transformOutgoing(payload.text, payload.chatType, payload.target)
        if changed and out ~= payload.text then
            payload.text = out
            return payload
        end
        -- nil = "unchanged", Yapper keeps the original payload.
    end)
    if ok and handle then yapperFilterHandle = handle end
end

-- /glyphic say|yell (and the bare "/glyphic <text>" fallback). An explicit "say this in
-- my tongue" command, so unlike transformOutgoing it ignores the auto-translate
-- switch and the channel list -- you asked for it by name. The accent still
-- composes onto whatever English fluency left behind, same as ordinary chat.
local function speak(msg, chatType, channel)
    migrateDB()
    installSendHook()
    suppress = true
    local sendType = chatType or "SAY"
    local langId = GlyphicDB and GlyphicDB.language
    local strength = getStrength()

    local out = msg
    local marked, marks = Language.TranslateMarked(msg, strength, langId, motherTongue())
    if marks then
        local body = marked
        if accentAppliesTo(normalizeChatType(sendType)) then body = applyAccent(body, true) end
        body = fit(Language.RestoreMarked(body, marks))
        Language.RememberEncodedMessage(langId, msg, body, strength)
        sendDecodePayload(msg, body, langId, strength, sendType, channel)
        out = fit(languageTag(langId) .. body)
    elseif accentAppliesTo(normalizeChatType(sendType)) then
        out = applyAccent(msg, true)
    end

    if orig_SendChatMessage then
        orig_SendChatMessage(out, sendType, nil, channel)
    end
    suppress = false
end

--=========================================================================--
--  Speech pipeline for other modules.
--=========================================================================--
-- Casts.lua composes an emote out of narration plus quoted speech ('roars
-- "Burn!"'), so it needs the translate/accent steps applied to a *fragment* of
-- a line rather than to a whole outgoing message the way transformOutgoing
-- does. The steps are exposed separately and the caller assembles the result.

-- Run one span of spoken words through the current language and accent, the
-- same way chat does: the two compose, with the tongue taking the words fluency
-- covers and the accent taking the English that remains. Returns (out, langId,
-- encoded); `encoded` is true only when the tongue rewrote something, and so
-- only then does the line need a [Language] tag and a decode payload.
--
-- `live` false marks a preview, which must not advance the accent's
-- interjection spacing -- otherwise looking at the options panel would change
-- how your next real line reads.
function ns.EncodeSpeech(text, live)
    migrateDB()
    if type(text) ~= "string" or text == "" then return text, nil, false end
    local db = GlyphicDB
    local langId, strength = db.language, getStrength()
    -- Spoken words riding inside an emote are still speech, so they take the
    -- accent's own strength; the emote toggle governs narration, not this.
    local accentOn = ns.Accent and db.inCharacter and db.accent
        and db.accent.id ~= ns.Accent.NONE

    if db.inCharacter and (strength > 0 or motherTongue() ~= nil) then
        local marked, marks = Language.TranslateMarked(text, strength, langId, motherTongue())
        if marks then
            local out = marked
            if accentOn then
                local a = db.accent
                local ok, res = pcall(ns.Accent.Apply, out, a.id, a.strength or 100, false,
                    live and true or false)
                if ok and type(res) == "string" then out = res end
            end
            out = Language.RestoreMarked(out, marks)
            -- The caller (Casts.lua) broadcasts the mapping, so it has to be the
            -- composed string that will actually be spoken. Previews are skipped:
            -- nothing said in an options panel should end up in the decode cache.
            if live then Language.RememberEncodedMessage(langId, text, out, strength) end
            return out, langId, true
        end
    end

    if accentOn then
        local a = db.accent
        local ok, res = pcall(ns.Accent.Apply, text, a.id, a.strength or 100, false,
            live and true or false)
        if ok and type(res) == "string" then return res, langId, false end
    end
    return text, langId, false
end

-- Tell grouped Glyphic users what a garbled span means, so their decode can read
-- it. Same payload chat translation sends.
function ns.BroadcastSpeech(original, encoded, langId, chatType, channel)
    sendDecodePayload(original, encoded, langId, getStrength(), chatType, channel)
end

function ns.LanguageTag(langId) return languageTag(langId) end
function ns.LanguageName(langId) return languageName(langId) end
function ns.FitMessage(text, maxLen) return fit(text, maxLen) end
function ns.MaxMessageLength() return MAX_MESSAGE end
function ns.PrintToChat(msg, style) addToChat(msg, style, getDecodeFrame()) end
-- Addon feedback with the "[Glyphic]" prefix, for the modules that need to say
-- something in their own voice (PrintToChat is the unprefixed decode channel).
function ns.Print(msg) Print(msg) end

-- Send a line we generated ourselves, already through the pipeline above.
-- Prefers the C_ChatInfo call: the global was deprecated in 11.2.0, and on the
-- Classic flavors -- the ones where we really do wrap that global -- the
-- namespaced call keeps our own outgoing transform out of the path, so text
-- that has already been translated cannot be translated a second time.
function ns.RawSend(msg, chatType, channel)
    if type(msg) ~= "string" or msg == "" then return end
    local modern = C_ChatInfo and C_ChatInfo.SendChatMessage
    if modern then
        pcall(modern, msg, chatType or "SAY", nil, channel)
        return
    end
    installSendHook()
    if not orig_SendChatMessage then return end
    -- Belt and braces: if anything still routes back through our hook, this
    -- makes it a pass-through rather than a second translation.
    suppress = true
    pcall(orig_SendChatMessage, msg, chatType or "SAY", nil, channel)
    suppress = false
end

--=========================================================================--
--  Learned-language decode on incoming chat.
--=========================================================================--
-- Decode an incoming line. `taggedLangId` (optional) is the language resolved from
-- a recognized "[Language]" tag on the line; `force` (optional) is set by the
-- /glyphic decode command to try every language regardless.
--
-- IMPORTANT: speculative word-by-word decoding CAN false-positive on ordinary
-- English -- a plain word may coincidentally be a generated language's encoding of
-- some other word -- which would rewrite and tag the chat of players who don't even
-- run the addon. So the only thing we ever do to an untagged, uncached line is an
-- exact cache lookup (whose keys are the exact garbled strings Glyphic produces, which
-- plain English cannot hit). Word-by-word/partial decoding runs only when we have
-- proof the line is encoded: a matching tag, or an explicit /glyphic decode.
-- One rule for "does this character understand that tongue".
--
-- There were two, and they disagreed. The decoder below fell back to a
-- dialect's parent -- learning Zandali is learning Amani, since they share a
-- word set -- while /glyphic learned tested the id on its own. So chat quietly
-- decoded Amani for you while the list of what you understood said you did
-- not, which reads as the dialects being unlearnable rather than as two
-- functions having drifted apart.
-- There are two ways to come to know a tongue and only one of them used to
-- count. The tick in the Languages list sets `learned`; dragging that row's
-- fluency bar to 100% sets the trainer's fluency and nothing else. So a
-- character who was, by the addon's own reckoning, perfectly fluent -- the
-- tag on their speech said "Perfect" -- still could not read a word of it,
-- because the decoder only ever asked about the tick.
--
-- Fluency is stored per word set, which is what makes this fix reach the
-- dialects: Zandali's bar at 100% is Amani's bar at 100%, so learning the
-- parent really does mean reading the tribe.
function ns.UnderstandsLanguage(langId)
    if not langId then return false end
    migrateDB()
    local learned = GlyphicDB and GlyphicDB.learned
    if learned then
        if learned[langId] then return true end
        local parent = Language.ParentOf and Language.ParentOf(langId)
        if parent and learned[parent] then return true end
    end
    return (fluencyPercent(langId) or 0) >= 100
end

-- Every name the client might put on a line of yours.
--
-- There is no one call that answers "what name will my own speech come back
-- under", and the two ways it can differ compound. On a connected realm your
-- own line returns as "Jessae-MoonGuard" while UnitName answers the bare
-- "Jessae". WoW: Forever then added surnames, so the same character is
-- "Charlie" to one call and "Charlie Lightcairn" to another, and a player with
-- a surname matched nothing at all: every line they spoke was filed as a
-- stranger's.
--
-- So ask every call that has an opinion and keep all the answers, each with
-- its realm suffix stripped as well. A character name cannot contain a hyphen,
-- which is what makes that safe.
--
-- Deliberately a set of whole names and not a prefix test. Surnames exist so
-- that first names need not be unique, so accepting anything beginning
-- "Charlie " would hand one player's lines to another.
function ns.SelfNames()
    local out = {}
    local function add(name)
        if isSecret(name) or type(name) ~= "string" or name == "" then return end
        out[name] = true
        local bare = string.match(name, "^([^%-]+)")
        if bare and bare ~= "" then out[bare] = true end
    end
    add(UnitName and UnitName("player"))
    if GetUnitName then
        add(GetUnitName("player", false))
        add(GetUnitName("player", true))
    end
    return out
end

-- Is this line one of ours?
function ns.IsSelfName(sender)
    if isSecret(sender) or type(sender) ~= "string" or sender == "" then return false end
    local names = ns.SelfNames()
    if names[sender] then return true end
    local bare = string.match(sender, "^([^%-]+)")
    return (bare ~= nil and names[bare] == true)
end

local function isSelf(sender)
    return ns.IsSelfName(sender)
end

-- `yourOwnWords` lifts the comprehension gate entirely -- see isChecked.
local function tryDecodeMessage(message, taggedLangId, force, yourOwnWords)
    migrateDB()
    local learned = GlyphicDB.learned or {}
    local trainerWords = (GlyphicDB.trainer and GlyphicDB.trainer.words) or {}

    -- Checked in the Learned panel = you fully understand the language (its own
    -- or its parent's box, since sub-languages share a word set).
    local function isChecked(entry)
        -- You cannot fail to understand yourself. Fluency is how well you speak
        -- a tongue, and it was never meant to decide whether you remember what
        -- you just said: someone with a word of French knows perfectly well
        -- that the "Bonjour" they chose means hello. Asking the comprehension
        -- question about your own sentence handed it back to you as gibberish
        -- at anything under full fluency.
        --
        -- Nothing is hidden by this. How the line actually left your mouth --
        -- half in Amani at 50%, which is the whole point of the slider -- is
        -- already on screen in the chat bubble over your head, which is what
        -- everyone else is reading.
        if yourOwnWords then return true end
        return ns.UnderstandsLanguage(entry.id)
    end

    -- Words you've unlocked for a language in the trainer (shared per word set),
    -- as a { [englishLower] = true } set, or nil if none.
    local function unlockedSet(entry)
        local w = trainerWords[Language.GetWordsetId(entry.id)]
        if not w then return nil end
        local set, any = {}, false
        for word in pairs(w) do set[string.lower(word)] = true; any = true end
        return any and set or nil
    end

    local langs = Language.GetLanguages()

    -- 1) Exact cached mapping for fully-understood languages. This is the only
    --    path allowed to run on untagged text: its keys are the exact garbled
    --    strings Glyphic produces, so ordinary English never matches.
    local bestDecoded, bestScore, bestLangId, bestLangName
    for i = 1, #langs do
        if isChecked(langs[i]) then
            local decoded, score = Language.TryDecode(message, langs[i].id)
            if decoded and (not bestScore or score > bestScore) then
                bestDecoded, bestScore = decoded, score
                bestLangId, bestLangName = langs[i].id, langs[i].name
            end
        end
    end
    if bestDecoded then
        return bestDecoded, bestScore, bestLangId, bestLangName
    end

    -- No exact match. Everything below is a guess, so it needs proof (see above).
    if not (force or taggedLangId) then
        return nil
    end

    -- Approximate word-by-word decode for a fully-understood generated language.
    local function tryWordwise(entry)
        if isChecked(entry) and Language.IsGenerated(entry.id) then
            local decoded, count = Language.DecodeWordwise(message, entry.id)
            if decoded and (not bestScore or count > bestScore) then
                bestDecoded, bestScore = decoded, count
                bestLangId, bestLangName = entry.id, entry.name
            end
        end
    end

    -- Reveal only the specific words you've unlocked for it in the trainer.
    local function tryPartial(entry)
        if not isChecked(entry) then
            local allowed = unlockedSet(entry)
            if allowed then
                local decoded, count = Language.DecodePartial(message, entry.id, allowed)
                if decoded and (not bestScore or count > bestScore) then
                    bestDecoded, bestScore = decoded, count
                    bestLangId, bestLangName = entry.id, entry.name
                end
            end
        end
    end

    if force then
        for i = 1, #langs do tryWordwise(langs[i]) end
        if not bestDecoded then
            for i = 1, #langs do tryPartial(langs[i]) end
        end
    else -- taggedLangId: the tag tells us the tongue, so only try that one.
        for i = 1, #langs do
            if langs[i].id == taggedLangId then
                tryWordwise(langs[i])
                if not bestDecoded then tryPartial(langs[i]) end
                break
            end
        end
    end

    return bestDecoded, bestScore, bestLangId, bestLangName
end

local function showDecode(sender, original, decoded, langId, langName)
    local style = GlyphicDB.decodeStyle or "emote"
    local msg
    if style == "whisper" then
        msg = "|cffC79CFF[Glyphic: " .. langName .. "]|r "
            .. sender .. " spoke: |cffcccccc\"" .. original .. "\"|r "
            .. "-> |cffffffff\"" .. decoded .. "\"|r"
    else
        msg = "|cffFFFF00* " .. sender .. " (" .. langName .. "):|r "
            .. "|cffcccccc\"" .. original .. "\"|r "
            .. "|cff888888->|r |cffffffff\"" .. decoded .. "\"|r"
    end
    addToChat(msg, style, getDecodeFrame())
end

-- Passive learning: overhearing a tongue (identified by its "[Language]" tag)
-- slowly builds your fluency in it. ~0.25%/word -> roughly 100 words to climb a
-- quarter-tier, ~400 words to reach Perfect. Only OTHER players' tagged speech
-- counts, and only up to full fluency.
local PASSIVE_PER_WORD = 0.0025
local FLUENCY_ADJECTIVES = { broken = true, partial = true, fluent = true, perfect = true }
local passiveNameToId
local function passiveLangIdFromTag(tag)
    if not passiveNameToId then
        passiveNameToId = {}
        local langs = Language.GetLanguages()
        for i = 1, #langs do
            passiveNameToId[string.lower(langs[i].name)] = langs[i].id
        end
    end
    tag = string.lower(tag):gsub("^%s+", ""):gsub("%s+$", "")
    local first, rest = tag:match("^(%S+)%s+(.+)$")
    if first and FLUENCY_ADJECTIVES[first] then tag = rest end
    return passiveNameToId[tag]
end

-- WoW's own language system, for the optional tinting of genuine in-game speech
-- from players who don't run the addon. Its names are not ours: the client says
-- "Darnassian" where we say "Darnassian (Night Elf)", and spells the dwarven
-- tongue "Dwarvish". So this is an explicit map rather than a fuzzy match, and
-- every result is checked against the registry before use -- a name we guessed
-- wrong then simply doesn't tint instead of coloring the wrong language.
local REAL_LANGUAGE_IDS = {
    ["common"]      = "common",
    ["orcish"]      = "orcish",
    ["darnassian"]  = "darnassian",
    ["taurahe"]     = "taurahe",
    ["dwarvish"]    = "dwarven",
    ["dwarven"]     = "dwarven",
    ["gnomish"]     = "gnomish",
    ["thalassian"]  = "thalassian",
    ["gutterspeak"] = "gutterspeak",
    ["draenei"]     = "draenei",
    ["zandali"]     = "zandali",
    ["troll"]       = "zandali",
    ["demonic"]     = "demonic",
    ["eredun"]      = "demonic",
    ["goblin"]      = "goblin",
    ["pandaren"]    = "pandaren",
    ["draconic"]    = "draconic",
    ["kalimag"]     = "kalimag",
    ["titan"]       = "titan",
    ["vrykul"]      = "vrykul",
    ["shath'yar"]   = "oldgod",
    ["nerglish"]    = "nerglish",
}

local function realLanguageId(languageName)
    if type(languageName) ~= "string" or languageName == "" then return nil end
    local id = REAL_LANGUAGE_IDS[string.lower(languageName)]
        or passiveLangIdFromTag(languageName)
    if not id or not Language.IsValid(id) then return nil end
    return id
end
ns.InvalidatePassiveNames = function() passiveNameToId = nil end

-- Cast phrases name their tongue in prose after the speech -- `snarls "Aman!"
-- in Broken Demonic` -- instead of wearing a leading [tag], because a bracket
-- between your name and your verb wrecks the sentence (see Casts.Render).
-- Receivers still have to find it, or anyone part-way through learning the
-- tongue would lose the proof that unlocks speculative decoding.
--
-- Anchored on the closing quote rather than on a bare "in": the marker always
-- directly follows the speech it describes, so `" in ` is an exact and cheap
-- needle, and narration like "steps in front of %t" can't trip it. The name
-- itself is then matched against the known languages rather than pulled out
-- with a pattern, because a name may contain spaces, apostrophes and
-- parentheses -- "Broken Demonic (Eredun)" -- which no pattern separates from
-- the narration that follows it. Longest candidate wins, so the full
-- "Demonic (Eredun)" beats a bare "Demonic".
local function inlineLangIdFromProse(message)
    local pos = 1
    while true do
        local _, e = message:find('" in ', pos, true)
        if not e then return nil end
        local words = {}
        for word in message:sub(e + 1):gmatch("%S+") do
            words[#words + 1] = word
            if #words >= 5 then break end
        end
        for n = #words, 1, -1 do
            local candidate = table.concat(words, " ", 1, n):gsub("[%.,;:!%?]+$", "")
            local langId = passiveLangIdFromTag(candidate)
            if langId then return langId end
        end
        pos = e + 1
    end
end

local function notePassiveExposure(message)
    local db = GlyphicDB
    if not (db and db.passiveLearning) then return end
    if not (ns.Trainer and ns.Trainer.AddFluency and ns.Trainer.GetProgress) then return end

    local tag = message:match("^%[([^%]]+)%]")
    local langId = tag and passiveLangIdFromTag(tag) or nil
    -- A cast phrase carries its language in prose instead of a tag, and only
    -- the quoted span is in that tongue -- the rest is English narration. So
    -- credit the spoken words alone, or overhearing one emote would teach as
    -- much as a whole sentence of actual speech.
    local body
    if langId then
        body = message:gsub("^%[[^%]]+%]%s*", "")
    else
        langId = inlineLangIdFromProse(message)
        if not langId then return end
        local spoken = {}
        for speech in message:gmatch('"([^"]*)"') do spoken[#spoken + 1] = speech end
        body = table.concat(spoken, " ")
    end

    local _, _, frac = ns.Trainer.GetProgress(langId)
    if type(frac) == "number" and frac >= 1 then return end
    local words = 0
    for _ in body:gmatch("%S+") do words = words + 1 end
    if words <= 0 then return end
    ns.Trainer.AddFluency(langId, words * PASSIVE_PER_WORD)
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
end

local function onIncomingChat(event, message, sender)
    -- Secret (protected) chat text can't be read or decoded -- bail before we
    -- touch it. Must be the very first thing we do with `message`/`sender`.
    if isSecret(message) or isSecret(sender) then return end
    if instanceSuppressed then return end
    if not message or message == "" then return end
    migrateDB()
    local mine = isSelf(sender)

    local chatType = CHAT_EVENTS[event]
    if not chatType or not ns.IsChannelEnabled(chatType) then return end

    -- Overhearing a tongue slowly teaches it (before any decode/display logic).
    -- Your own voice teaches you nothing, or talking to yourself in a tongue you
    -- barely have would be the quickest way there is to learn it.
    if not mine then notePassiveExposure(message) end

    -- In-line mode rewrites the chat line itself via inlineChatFilter, so we must
    -- not also print a separate decode line here.
    if (GlyphicDB.decodeStyle or "inline") == "inline" then return end

    -- Strip a leading "[Language] " flavor tag (ours or another Glyphic user's) so
    -- decoding sees the raw encoded text that matches the cached mapping.
    -- A tag naming a language we know is proof the line is encoded, which unlocks
    -- speculative decoding for that language (see tryDecodeMessage).
    local tag = message:match("^%[([^%]]+)%]%s+")
    local stripped = message:gsub("^%[[^%]]+%]%s+", "")
    local taggedLangId = (tag and passiveLangIdFromTag(tag))
        or inlineLangIdFromProse(message)

    local bestDecoded, bestScore, bestLangId, bestLangName =
        tryDecodeMessage(stripped, taggedLangId, false, mine)
    if bestDecoded then
        showDecode(sender, stripped, bestDecoded, bestLangId, bestLangName)
    end
end

-- Someone sent us a custom language in-game. Confirm before adding it. Uses our
-- own dialog (Compat.ShowConfirm) rather than StaticPopupDialogs -- see the note
-- in Compat.lua: touching that global taints protected UI on Retail 12.0+.
local function handleLangShare(code, sender)
    local def = Language.ImportShareString(code)
    if not def then return end
    local who = (sender and sender:gsub("%-.*", "")) or "Someone"
    Compat.ShowConfirm({
        text = string.format("%s shared the language \"%s\" with you.\nAdd it to Glyphic?",
            who, def.name or def.id or "?"),
        acceptText = ACCEPT or "Accept",
        cancelText = CANCEL or "Decline",
        onAccept = function()
            local ok, idOrErr = ns.SaveCustomLanguage(def)
            if ok then
                Print("Imported language |cffffff00" .. (def.name or idOrErr) .. "|r. Find it in your language list.")
            else
                Print("Import failed: " .. tostring(idOrErr))
            end
        end,
    })
end

local chatFrame = CreateFrame("Frame")
for event in pairs(CHAT_EVENTS) do
    chatFrame:RegisterEvent(event)
end
chatFrame:RegisterEvent("CHAT_MSG_ADDON")
chatFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        -- The channel is kept rather than skipped: it is what says whether a
        -- voice pin came from your party, your guild or a stranger in earshot,
        -- and those are answered separately.
        local prefix, message, channel, sender = ...
        if isSecret(prefix) or isSecret(message) then return end
        if prefix == ADDON_PREFIX then
            if type(message) == "string" and message:sub(1, #LANG_SHARE_TAG) == LANG_SHARE_TAG then
                handleLangShare(message:sub(#LANG_SHARE_TAG + 1), sender)
            elseif type(message) == "string" and message:sub(1, #VOICE_TAG) == VOICE_TAG then
                if ns.Voice and ns.Voice.OnBroadcast then
                    ns.Voice.OnBroadcast(tonumber(message:sub(#VOICE_TAG + 1)), sender, channel)
                end
            elseif Language.ImportDecodePayload then
                Language.ImportDecodePayload(message)
            end
        end
        return
    end
    if CHAT_EVENTS[event] then
        local message, sender = ...
        onIncomingChat(event, message, sender)
    end
end)

-- In-line decode (retail-style). Registered as a chat message filter so it edits
-- the message the client is about to display: when you understand the tongue,
-- the actual chat line becomes the decoded text (with a small language marker)
-- instead of a separate posted line. Messages you don't understand are left as
-- their gibberish, preserving immersion for everyone. Partial (word-by-word)
-- understanding shows here too -- exactly the "learning" experience.
-- `languageName` is the client's own language for the line ("Orcish"); it is
-- pulled out of the varargs by name because the optional real-language tinting
-- reads it, and because every rewritten return has to put it back in place.
local function inlineChatFilter(_, event, msg, sender, languageName, ...)
    -- Never touch a secret message: we can't read/rewrite it, so let the client
    -- display it untouched (return false = don't filter).
    if isSecret(msg) or isSecret(sender) then return false end
    if instanceSuppressed then return false end
    if not msg or msg == "" then return false end
    migrateDB()

    local chatType = CHAT_EVENTS[event]
    if not chatType then return false end

    -- Harvest the speaker before the channel check, not after: this is the best
    -- proximity list the client can give us (the server already filtered SAY and
    -- friends by range), and it would be silly to miss the people standing next
    -- to you purely because you don't translate in the channel they used.
    if ns.Names and CONVERSATIONAL[chatType] then
        -- CHAT_MSG_* carries the sender's GUID as its twelfth argument, which
        -- is the ninth of the varargs left here. That GUID is the only thing a
        -- chat line says about the speaker beyond their name, so it is also the
        -- only way most names ever get a class color. Read positionally because
        -- that is the only way it is offered; Names screens it for the
        -- "Player-" prefix, so a layout that ever shifts costs a color and
        -- nothing more.
        local guid = select("#", ...) >= 9 and select(9, ...) or nil
        ns.Names.NoteSpeaker(sender, guid)
    end

    if not ns.IsChannelEnabled(chatType) then return false end

    -- Which tongue is this line in? A leading "[Language] " tag, or a cast
    -- phrase naming it in prose. This is resolved up front, ahead of any decode
    -- attempt, because the color depends only on the tongue and not on whether
    -- we can read it -- seeing at a glance that a line is Demonic while still
    -- understanding none of it is the entire point of the palette.
    local tag = msg:match("^%[([^%]]+)%]%s+")
    local stripped = msg:gsub("^%[[^%]]+%]%s+", "")
    local proseLangId = (not tag) and inlineLangIdFromProse(msg) or nil
    local langId = (tag and passiveLangIdFromTag(tag)) or proseLangId

    -- Failing that, WoW's own language system, for players who don't run the
    -- addon at all. Opt-in: nearly all chat is Common or your faction tongue,
    -- so tinting it by default would repaint the window rather than pick
    -- anything out of it.
    local isReal = false
    if not langId and Colors and Colors.RealLanguagesEnabled() then
        langId = realLanguageId(languageName)
        isReal = langId ~= nil
    end

    -- `decoded` lines are already readable end to end, so a name highlight has
    -- nothing left to tell you there and would just be noise. It only runs on
    -- speech you can't read, which no longer includes your own: that is now
    -- always handed back to you in the words you typed.
    --
    -- Names are painted before the language tint rather than after, so the
    -- tint wraps them: Colors.Wrap re-opens itself after every "|r" it finds
    -- inside a span, which is exactly what a nested name color leaves behind.
    local function paint(text, decoded)
        -- Only lines that are actually in a tongue get names painted. A plain
        -- Common sentence had nothing translated out of it, so a highlight
        -- there would be the addon coloring chat it had no hand in -- `langId`
        -- is exactly the "this line is in a language" test.
        if langId and not decoded and ns.Names then text = ns.Names.Highlight(text) end
        if not (Colors and langId) then return text end
        -- Genuine in-game speech carries no "[Language]" tag, so the words are
        -- the only thing there is to tint. Turning that option on is therefore
        -- opting into speech color for those lines specifically, whatever the
        -- general speech setting says.
        if isReal then return Colors.Apply(text, langId, { speech = true }) end
        return Colors.Apply(text, langId)
    end

    -- Genuine in-game speech was never ours to decode; it still gets painted
    -- below. Your own speech, on the other hand, is always decoded -- at any
    -- fluency, including none -- because it is the one line on screen whose
    -- meaning you cannot possibly be in doubt about. The bubble over your head
    -- is where you see how it actually came out.
    local mine = isSelf(sender)
    local inlineMode = (GlyphicDB.decodeStyle or "inline") == "inline"
    if inlineMode and not isReal then
        local decoded, _, decodedId, plainName = tryDecodeMessage(stripped, langId, false, mine)
        -- Named the same way the speech itself is tagged, fluency word and all.
        -- The decoder answers with the bare name, so a line you understood lost
        -- the "Perfect" that the same line wore on its way out -- which reads
        -- as the tag breaking at exactly the moment you learned the tongue.
        --
        -- Through ns.LanguageName rather than the local of the same job: this
        -- function's fifth parameter is called languageName -- it is the
        -- client's own language string for the line -- and inside this scope it
        -- shadows the module function completely. Calling it threw on every
        -- decoded line that reached a chat frame.
        local langName = plainName
        if decodedId then langName = ns.LanguageName(decodedId) end
        if decoded and decoded ~= stripped then
            -- When the line already says which tongue it was in, prefixing
            -- "[Demonic]" would both repeat that and drop a bracket between the
            -- emoter's name and their verb -- the very thing the prose form
            -- exists to avoid.
            if proseLangId then
                return false, paint(decoded, true), sender, languageName, ...
            end
            -- The marker is itself a "[Language] " tag, so it goes through the
            -- same painter as any other tagged line and picks up that tongue's
            -- color. The hardcoded purple remains the answer when the palette
            -- is switched off.
            if Colors and Colors.AnyEnabled() and langId then
                local line = "[" .. (langName or "?") .. "] " .. decoded
                return false, Colors.Apply(line, langId), sender, languageName, ...
            end
            local marker = "|cff9a7cff[" .. (langName or "?") .. "]|r "
            return false, marker .. decoded, sender, languageName, ...
        end
    end

    local painted = paint(msg)
    if painted ~= msg then
        return false, painted, sender, languageName, ...
    end
    return false
end

if ChatFrame_AddMessageEventFilter then
    for event in pairs(CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, inlineChatFilter)
    end
end

--=========================================================================--
--  Slash commands
--=========================================================================--
-- The in-character switch, shared by /glyphic on|off, the minimap button, the
-- floating bar and the keybinding.
--
-- Only the typed commands report, and then they report both halves of your
-- voice, since one switch now governs the tongue and the accent together. The
-- button, the bar and the keybind pass silent: they already say it better than
-- a chat line does, by going green or red the instant you use them, and they
-- are the ones you flip often enough for a line each to read as spam.
function ns.SetInCharacter(state, silent)
    migrateDB()
    GlyphicDB.inCharacter = state and true or false
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end

    if silent then return end
    if not state then
        Print("Speaking |cffff0000out of character|r -- chat goes out as typed, "
            .. "no accent, and cast phrases are quiet.")
        return
    end
    local a = GlyphicDB.accent
    local accentName = (a and ns.Accent and a.id ~= ns.Accent.NONE)
        and ns.Accent.GetAccentName(a.id) or nil
    Print("Speaking |cff00ff00in character|r: |cffffff00"
        .. Language.GetLanguageName(GlyphicDB.language) .. "|r"
        .. (accentName and (" with a |cffffff00" .. accentName .. "|r accent") or "")
        .. ".")
end

function ns.ToggleInCharacter(silent)
    migrateDB()
    ns.SetInCharacter(not GlyphicDB.inCharacter, silent)
end

-- One answer to "is the addon speaking for me right now", for every feature
-- that speaks. The switch reads as a mute: hit it to answer your raid leader
-- in plain English, and everything the addon would otherwise have said in your
-- name stops at once -- the tongue, the accent, the cast phrases, the voice
-- clips that ride on them.
--
-- Only what you send. You still read, decode and colour everybody else's
-- chat with it off, because the person who stepped out to answer a question
-- has not asked to stop seeing the roleplay going on around them.
--
-- A function rather than four files reading the flag, because four readings
-- are four chances for one of them to be missed when a feature is added --
-- which is exactly how cast phrases came to keep shouting through it.
function ns.IsInCharacter()
    local db = GlyphicDB
    return (db and db.inCharacter) and true or false
end

-- Globals for Bindings.xml: Blizzard runs binding bodies as bare chunks with no
-- access to the addon namespace, so the keybinds need a name on _G.
function TonguesOfAzeroth_ToggleInCharacter()
    ns.ToggleInCharacter(true)
end

function TonguesOfAzeroth_CycleLanguage(dir)
    if ns.CycleLanguage then ns.CycleLanguage(dir) end
end

BINDING_HEADER_TONGUESOFAZEROTH = "Glyphic"
BINDING_NAME_TONGUESOFAZEROTH_TOGGLE_IC = "Speak in character (toggle)"
BINDING_NAME_TONGUESOFAZEROTH_NEXT_LANG = "Next language"
BINDING_NAME_TONGUESOFAZEROTH_PREV_LANG = "Previous language"

local setEnabled = ns.SetInCharacter

local function listLanguages()
    Print("available languages (use |cffffff00/glyphic lang <id>|r):")
    local langs = Language.GetLanguages()
    local active = GlyphicDB and GlyphicDB.language

    -- Group each primary with the sub-languages that share its word set.
    local subsOf = {}
    for i = 1, #langs do
        local l = langs[i]
        if l.sub and l.parent then
            subsOf[l.parent] = subsOf[l.parent] or {}
            table.insert(subsOf[l.parent], l.id)
        end
    end

    for i = 1, #langs do
        local l = langs[i]
        if not l.sub then
            local marker = (l.id == active) and " |cff00ff00(active)|r" or ""
            Print("  |cffffff00" .. l.id .. "|r - " .. l.name .. marker)
            local subs = subsOf[l.id]
            if subs then
                Print("      subs: |cffaaaaaa" .. table.concat(subs, ", ") .. "|r")
            end
        end
    end
end

local function setLanguage(id, silent)
    id = string.lower(id or "")
    if Language.IsValid(id) then
        GlyphicDB.language = id
        if not silent then
            Print("Language set to |cffffff00" .. Language.GetLanguageName(id) .. "|r.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif not silent then
        Print("Unknown language '|cffff0000" .. id .. "|r'. Use |cffffff00/glyphic list|r.")
    end
end

--=========================================================================--
--  Favorites
--  A shortlist you curate yourself. It floats to the top of the language
--  dropdown and, once you've put anything in it, becomes what cycling walks
--  through. Seventy-odd tongues ship with the addon and most characters use a
--  handful, so this is the difference between the dropdown being a menu and
--  being a haystack.
--=========================================================================--

-- Favorites in the order you added them, minus any that no longer exist (a
-- custom language can be deleted while it is still in the list).
function ns.GetFavorites()
    migrateDB()
    local favs, out = GlyphicDB.favorites, {}
    for i = 1, #favs do
        if Language.IsValid(favs[i]) then out[#out + 1] = favs[i] end
    end
    return out
end

function ns.IsFavorite(id)
    migrateDB()
    local favs = GlyphicDB.favorites
    for i = 1, #favs do
        if favs[i] == id then return true end
    end
    return false
end

-- Returns the new state (true = now a favorite), or nil if `id` isn't a language.
function ns.ToggleFavorite(id)
    migrateDB()
    if not Language.IsValid(id) then return nil end
    local favs = GlyphicDB.favorites
    for i = 1, #favs do
        if favs[i] == id then
            table.remove(favs, i)
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
            return false
        end
    end
    favs[#favs + 1] = id
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true
end

function ns.ClearFavorites()
    migrateDB()
    local n = #GlyphicDB.favorites
    wipe(GlyphicDB.favorites)
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return n
end

-- The languages you can quickly cycle between, as an ordered list of ids, with
-- whatever you're speaking now guaranteed present. That's your favorites if you
-- have any; otherwise anything you've marked Learned or made trainer progress
-- in, in registration order.
function ns.GetKnownLanguages()
    migrateDB()
    local db = GlyphicDB
    local seen, list = {}, {}
    local function add(id)
        if id and not seen[id] and Language.IsValid(id) then
            seen[id] = true
            list[#list + 1] = id
        end
    end

    -- With the favorites-only toggle on (the star on the floating bar), a
    -- curated list takes cycling over completely, so favorites are not filtered
    -- by what you've learned the way the fallback below is. Tongues your race
    -- natively speaks are still skipped, since cycling onto one is never useful.
    local favs = ns.GetFavorites()
    if db.favOnly and #favs > 0 then
        for i = 1, #favs do
            if not ns.IsNativeLanguage(favs[i]) then add(favs[i]) end
        end
        add(db.language)
        return list
    end

    local langs = Language.GetLanguages()
    for i = 1, #langs do
        local id = langs[i].id
        local isLearned = db.learned and db.learned[id]
        local frac = 0
        if ns.Trainer and ns.Trainer.GetProgress then
            local ok, _, _, f = pcall(ns.Trainer.GetProgress, id)
            if ok and type(f) == "number" then frac = f end
        end
        -- Skip tongues your race natively speaks (when hiding is on) so cycling
        -- and the floating bar never land on one you'd never RP with Glyphic.
        if (isLearned or frac > 0) and not ns.IsNativeLanguage(id) then add(id) end
    end
    add(db.language) -- always include what you're currently speaking
    return list
end

--=========================================================================--
--  Custom languages
--=========================================================================--
-- Register every saved custom language into the engine. Called on load.
local function loadCustomLanguages()
    migrateDB()
    local defs = GlyphicDB.customLanguages or {}
    for id, def in pairs(defs) do
        if type(def) == "table" then
            def.id = def.id or id
            Language.RegisterCustom(def)
        end
    end
end

-- Ordered list of the player's custom languages, for the builder UI.
function ns.GetCustomLanguages()
    migrateDB()
    local out = {}
    for _, def in pairs(GlyphicDB.customLanguages or {}) do
        out[#out + 1] = { id = def.id, name = def.name or def.id }
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- Validate + register + persist a custom language. Returns ok, idOrError.
function ns.SaveCustomLanguage(def)
    migrateDB()
    local ok, idOrErr = Language.RegisterCustom(def)
    if not ok then return false, idOrErr end
    local id = idOrErr
    GlyphicDB.customLanguages[id] = {
        id = id,
        name = def.name,
        apostrophe = def.apostrophe,
        onsets = def.onsets,
        nuclei = def.nuclei,
        codas = def.codas,
    }
    if ns.InvalidatePassiveNames then ns.InvalidatePassiveNames() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true, id
end

-- Remove a custom language. Falls back to the default tongue if it was active.
function ns.DeleteCustomLanguage(id)
    migrateDB()
    if not id or not Language.IsCustom(id) then return false end
    Language.UnregisterCustom(id)
    GlyphicDB.customLanguages[id] = nil
    if GlyphicDB.language == id then
        GlyphicDB.language = Language.DEFAULT
    end
    if ns.InvalidatePassiveNames then ns.InvalidatePassiveNames() end
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return true
end

-- Public API for power users / external files (transient; not persisted):
--   TonguesOfAzeroth_RegisterLanguage{ name = "Sylvan", nuclei = {...}, ... }
function TonguesOfAzeroth_RegisterLanguage(def)
    local ok, idOrErr = Language.RegisterCustom(def)
    if ok and ns.OnSettingsChanged then ns.OnSettingsChanged() end
    return ok, idOrErr
end

--=========================================================================--
--  Fluency control (shared by the Fluency slider, Make Fluent, Reset)
--  Fluency == speaking strength, so these change how you SOUND in a tongue.
--=========================================================================--
-- Set fluency to a 0-1 fraction (used by the per-language slider). Fluency only;
-- comprehension (the "learned" flag) is managed separately.
function ns.SetLanguageFluency(langId, frac)
    if not (langId and ns.Trainer and ns.Trainer.SetFluency) then return 0 end
    migrateDB()
    local applied = ns.Trainer.SetFluency(langId, frac)
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
    return applied
end

-- Instantly become fully fluent: fluency 100% AND flag it fully understood, so
-- you both speak and read it. (The "Make Fluent" button, after confirmation.)
function ns.MakeLanguageFluent(langId)
    if not langId then return end
    migrateDB()
    if ns.Trainer and ns.Trainer.SetFluency then ns.Trainer.SetFluency(langId, 1) end
    GlyphicDB.learned = GlyphicDB.learned or {}
    GlyphicDB.learned[langId] = true
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
end

-- Reset a language to 0%: wipe fluency, unlocked trainer words and the learned
-- flag, so it's as if you never knew it. (The "Reset" button, after confirm.)
function ns.ResetLanguageFluency(langId)
    if not langId then return end
    migrateDB()
    if ns.Trainer and ns.Trainer.ResetFluency then ns.Trainer.ResetFluency(langId) end
    if GlyphicDB.learned then GlyphicDB.learned[langId] = nil end
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
end

-- Bulk versions for the Learned panel's "Learn all" / "Reset all" buttons. We loop
-- the primary languages (sub-languages share a parent's fluency) and refresh once.
function ns.MakeAllFluent()
    migrateDB()
    local langs = (ns.GetSpeakablePrimaryLanguages and ns.GetSpeakablePrimaryLanguages())
        or (Language.GetPrimaryLanguages and Language.GetPrimaryLanguages()) or {}
    GlyphicDB.learned = GlyphicDB.learned or {}
    for i = 1, #langs do
        local id = langs[i].id
        if ns.Trainer and ns.Trainer.SetFluency then ns.Trainer.SetFluency(id, 1) end
        GlyphicDB.learned[id] = true
    end
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
end

function ns.ResetAllFluency()
    migrateDB()
    local langs = (ns.GetSpeakablePrimaryLanguages and ns.GetSpeakablePrimaryLanguages())
        or (Language.GetPrimaryLanguages and Language.GetPrimaryLanguages()) or {}
    for i = 1, #langs do
        local id = langs[i].id
        if ns.Trainer and ns.Trainer.ResetFluency then ns.Trainer.ResetFluency(id) end
        if GlyphicDB.learned then GlyphicDB.learned[id] = nil end
    end
    if ns.RefreshFluencyIfShown then ns.RefreshFluencyIfShown() end
end

-- Build a copy-safe share code for a saved custom language.
function ns.ExportCustomLanguage(id)
    migrateDB()
    local def = GlyphicDB.customLanguages and GlyphicDB.customLanguages[id]
    if not def then return nil end
    return Language.ExportShareString(def)
end

-- Import a share code: validate, register and persist it. Returns ok, idOrError.
function ns.ImportCustomLanguage(code)
    local def, err = Language.ImportShareString(code)
    if not def then return false, err or "invalid code" end
    return ns.SaveCustomLanguage(def)
end

-- Send a custom language to another addon user over the hidden addon channel.
-- target nil => broadcast to your raid/party. Returns ok, message.
function ns.ShareCustomLanguage(id, target)
    migrateDB()
    if not Language.IsCustom(id) then return false, "Only your own custom languages can be shared." end
    local code = ns.ExportCustomLanguage(id)
    if not code then return false, "Could not build a share code." end
    if not Compat.canSendAddonMessage then return false, "Addon messaging isn't available on this client." end

    local msg = LANG_SHARE_TAG .. code
    if #msg > MAX_ADDON_PAYLOAD then
        return false, "This language is too big to send in-game -- share the copy/paste code instead."
    end

    if target and target ~= "" then
        Compat.SendAddonMessage(ADDON_PREFIX, msg, "WHISPER", target)
        return true, "Sent " .. Language.GetLanguageName(id) .. " to " .. target .. "."
    elseif Compat.InRaid() then
        Compat.SendAddonMessage(ADDON_PREFIX, msg, "RAID")
        return true, "Shared " .. Language.GetLanguageName(id) .. " with your raid."
    elseif Compat.InParty() then
        Compat.SendAddonMessage(ADDON_PREFIX, msg, "PARTY")
        return true, "Shared " .. Language.GetLanguageName(id) .. " with your party."
    end
    return false, "Target a player or join a group to share in-game (or use the copy/paste code)."
end

-- Cycle the spoken language among your known languages. dir = 1 (next) or -1.
-- Cycling is silent: it fires on the minimap scroll wheel, the floating widget,
-- and /glyphic next|prev, so printing every switch floods chat. The active language
-- is already reflected on the widget / minimap tooltip.
function ns.CycleLanguage(dir)
    local list = ns.GetKnownLanguages()
    if #list <= 1 then return end
    dir = dir or 1
    local cur = GlyphicDB.language
    local idx = 1
    for i = 1, #list do
        if list[i] == cur then idx = i break end
    end
    idx = idx + dir
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    setLanguage(list[idx], true)
end

local function listLearned()
    migrateDB()
    Print("learned languages:")
    local langs = Language.GetLanguages()
    local any = false
    for i = 1, #langs do
        if ns.UnderstandsLanguage(langs[i].id) then
            any = true
            -- A dialect you can read because you learned its parent is said to
            -- be exactly that, rather than appearing beside it as though it
            -- were ticked separately -- which would make the list look wrong
            -- to anyone who went looking for the box they never ticked.
            local via = ""
            if not GlyphicDB.learned[langs[i].id] then
                local parent = Language.ParentOf and Language.ParentOf(langs[i].id)
                if parent and GlyphicDB.learned[parent] then
                    via = " |cff808080(through " .. Language.GetLanguageName(parent) .. ")|r"
                else
                    via = " |cff808080(fluent)|r"
                end
            end
            Print("  |cff00ff00" .. langs[i].name .. "|r" .. via)
        end
    end
    if not any then
        Print("  |cffff0000(none)|r - check languages under Interface -> AddOns -> Languages")
    end
end

local function listFavorites()
    local favs = ns.GetFavorites()
    if #favs == 0 then
        Print("no favorites yet. |cffffff00/glyphic fav|r stars the language you're speaking,")
        Print("or right-click any row in the language dropdown.")
        return
    end
    Print("favorites (what |cffffff00/glyphic next|r cycles through):")
    for i = 1, #favs do
        Print("  |cffffd100*|r " .. Language.GetLanguageName(favs[i]) .. " |cff808080(" .. favs[i] .. ")|r")
    end
end

-- /glyphic fav            -> toggle the language you're currently speaking
-- /glyphic fav <id>       -> toggle that language
-- /glyphic fav list       -> show the list
-- /glyphic fav off|clear  -> empty the list
local function favoriteCommand(rest)
    migrateDB()
    rest = string.lower(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if rest == "list" then
        listFavorites()
        return
    end
    if rest == "off" or rest == "clear" or rest == "none" then
        local n = ns.ClearFavorites()
        Print("cleared " .. n .. " favorite" .. (n == 1 and "" or "s") ..
            ". |cffffff00/glyphic next|r is back to cycling your learned languages.")
        return
    end

    local id = (rest ~= "" and rest) or GlyphicDB.language
    local state = ns.ToggleFavorite(id)
    if state == nil then
        Print("Unknown language '|cffff0000" .. id .. "|r'. Use |cffffff00/glyphic list|r.")
    elseif state then
        Print("|cffffd100*|r " .. Language.GetLanguageName(id) .. " added to favorites.")
    else
        Print(Language.GetLanguageName(id) .. " removed from favorites.")
    end
end

-- /glyphic cast ...  The panel is where this feature is really driven from (and the
-- keybinding is the quickest route into it), so these cover the things worth
-- having without one: the on/off switch, a look at what a spell will say, and
-- an answer to "why did nothing happen just now".
local function castCommand(rest)
    local Casts = ns.Casts
    if not Casts then
        Print("cast phrases are unavailable (Casts.lua did not load).")
        return
    end
    migrateDB()
    local c = GlyphicDB.casts
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    sub = string.lower(sub or "")

    if sub == "on" or sub == "off" then
        c.enabled = (sub == "on")
        Print("cast phrases: " .. (c.enabled and "|cff00ff00on|r" or "|cffff0000off|r"))
    elseif sub == "" or sub == "config" or sub == "ui" then
        if ns.OpenCastConfig then ns.OpenCastConfig() end
    elseif sub == "pets" then
        c.pets = not c.pets
        Print("pet phrases: " .. (c.pets and "|cff00ff00on|r" or "|cffff0000off|r"))
    elseif sub == "chance" then
        local n = tonumber(arg)
        if n then
            c.chance = math.max(0, math.min(100, math.floor(n + 0.5)))
            Print("cast phrase chance: |cffffff00" .. c.chance .. "%|r")
        else
            Print("cast phrase chance is |cffffff00" .. (c.chance or CAST_DEFAULTS.chance) .. "%|r (usage: /glyphic cast chance 0-100)")
        end
    elseif sub == "list" then
        local keys = Casts.GetKeys()
        if #keys == 0 then
            Print("no spells have phrases yet -- pick a spell in Cast Phrases and write one.")
            return
        end
        Print("spells with phrases:")
        for _, key in ipairs(keys) do
            local n = #Casts.GetPhrases(key)
            Print(string.format("  |cffffff00%s|r - %d phrase%s%s",
                Casts.DisplayName(key), n, n == 1 and "" or "s",
                Casts.IsMuted(key) and " |cff808080(muted)|r" or ""))
        end
    elseif sub == "test" then
        -- Shows what a spell would say, without sending anything. Defaults to
        -- the spell under the cursor, so hovering a bar and typing this works.
        local name = arg
        if name == "" then
            name = Casts.SpellUnderMouse()
            if not name then
                Print("usage: /glyphic cast test <spell name>  (or hover it on your bars first)")
                return
            end
        end
        local key = Casts.Key(name)
        local phrases = key and Casts.GetPhrases(key) or {}
        if #phrases == 0 then
            Print("no phrases for |cffffff00" .. tostring(name) .. "|r.")
            return
        end
        Print("|cffffff00" .. Casts.DisplayName(key) .. "|r would say one of:")
        for _, phrase in ipairs(phrases) do
            local line = Casts.Preview(phrase.text, Casts.DisplayName(key))
            Print(string.format("  [%d] %s", phrase.weight, line or phrase.text))
        end
    elseif sub == "status" then
        Print("cast phrases: " .. (c.enabled and "|cff00ff00on|r" or "|cffff0000off|r")
            .. ", pets " .. (c.pets and "on" or "off")
            .. ", chance " .. (c.chance or CAST_DEFAULTS.chance) .. "%"
            .. ", pauses " .. (c.gap or CAST_DEFAULTS.gap) .. "s / "
            .. (c.spellGap or CAST_DEFAULTS.spellGap) .. "s")
        local blocked = Casts.BlockedReason()
        if blocked then
            Print("right now lines stay with you: " .. blocked .. ".")
        else
            Print("right now lines would go out as emotes.")
        end
        Print(string.format("%d spell(s) have phrases.", #Casts.GetKeys()))
    else
        Print("usage: /glyphic cast [on|off|pets|chance <0-100>|list|test [spell]|status]")
    end
end

-- /glyphic voice. There is nothing to install and nothing to assemble any more, and
-- no switch either: a phrase is silent until a recording is pinned to it, so
-- pinning is the only yes there has ever needed to be. What is left is a count
-- of what the catalogue holds against what this client could actually sound.
-- Those two numbers differ -- the catalogue is built from one build of the game
-- and a player on another may be missing files -- and that gap is the only
-- failure worth reporting.
local function voiceCommand(rest)
    local Voice = ns.Voice
    if not Voice then
        Print("voice is unavailable (Voice.lua did not load).")
        return
    end
    migrateDB()
    local sub, arg = (rest or ""):match("^(%S*)%s*(.-)$")
    sub = string.lower(sub or "")

    if sub == "test" then
        local id = tonumber(arg)
        if not id then
            Print("usage: /glyphic voice test <fileDataId>")
            Print("ids come from the Browse button on the Cast Phrases panel.")
            return
        end
        Print(Voice.PlayGame(id, "audition") and ("played |cffffff00" .. id .. "|r.")
            or ("|cffff0000" .. id .. "|r would not play -- this client may not carry that file."))
    else
        local d = Voice.Describe()
        Print("spoken cast phrases: " .. (d.enabled and "|cff00ff00on|r" or "|cffff0000off|r"))
        Print(string.format("%d line(s) from the game are catalogued.", d.catalogue))
        -- Counted apart rather than summed. A single "played" number cannot
        -- answer the only question anybody asks it, because the play button
        -- lands in it too.
        local s = d.stats
        Print(string.format("this session: |cffffff00%d|r from your own casts, %d from the play"
            .. " button, %d from other players.", s.played, s.auditioned, s.fromOthers))

        -- The ways to end up silent, in the order the chain breaks, each named
        -- separately. Printed only when it has something to say, so a working
        -- setup stops here.
        if s.emotes == 0 then
            Print("|cffff8000no emote has reached the addon at all this session.|r")
        end
        if s.secret > 0 then
            Print(string.format("|cffff0000%d emote(s) arrived in a form this client will not let"
                .. " addons read.|r", s.secret))
        end
        if s.nameless > 0 then
            Print(string.format("|cffff0000%d emote(s) arrived without a sender to match.|r",
                s.nameless))
        end
        if s.emotes > 0 and s.mine == 0 then
            Print(string.format("|cffff8000%d emote(s) arrived and none were recognised as"
                .. " yours.|r", s.emotes))
            if d.lastStranger then
                Print("  the last one came from |cffffff00"
                    .. tostring(d.lastStranger.sender) .. "|r.")
            end
            -- Every name the client answers to, so a sender that matches none
            -- of them can be seen rather than deduced.
            local names = {}
            for name in pairs(ns.SelfNames()) do names[#names + 1] = name end
            table.sort(names)
            Print("  this client knows you as |cffffff00"
                .. (table.concat(names, "|r, |cffffff00")) .. "|r.")
        end
        if s.heard > 0 and s.played == 0 then
            Print(string.format("|cffff8000%d of your own emote(s) arrived and none of them"
                .. " made a sound.|r", s.heard))
        end
        if s.unpinned > 0 then
            Print(string.format("%d of your emote(s) came from a phrase with nothing pinned to it.",
                s.unpinned))
        end
        if s.unmapped > 0 then
            Print(string.format("|cffff0000%d pin(s) did not name a recording at all.|r", s.unmapped))
        end
        if s.missing > 0 then
            Print(string.format("|cffff0000%d pinned line(s) named a recording this client does not"
                .. " carry.|r", s.missing))
        end
        if s.rewritten > 0 then
            Print(string.format("|cffff0000%d emote(s) came back worded differently than they went"
                .. " out,|r", s.rewritten))
            Print("|cffff0000so the pin could not be matched to them. Another chat addon is most|r")
            Print("|cffff0000likely rewriting the line. The last pair:|r")
            Print("  sent:    |cffffff00" .. tostring(d.lastRewrite and d.lastRewrite.sent) .. "|r")
            Print("  arrived: |cffffff00" .. tostring(d.lastRewrite and d.lastRewrite.arrived) .. "|r")
        end
        if #d.hearing == 0 then
            Print("you are not listening for |cffffff00anyone else's|r pinned lines.")
        else
            Print("you hear pinned lines from |cffffff00" .. table.concat(d.hearing, ", ")
                .. "|r -- and only when their emote reaches you.")
        end
        if not d.canHearNearby then
            Print("|cff808080this version of the game only lets addons reach players you are"
                .. " grouped or guilded with, so a stranger's line cannot arrive at all.|r")
        end
        Print("a phrase stays silent until you pin a line to it -- open the Cast")
        Print("Phrases panel and use |cffffff00Browse voice lines|r on the line you want.")
        Print("usage: /glyphic voice [test <fileDataId>]")
    end
end

local function parseLangStrengthText(input, defaultLang, defaultStrength)
    input = input or ""
    if input == "" then return defaultLang, defaultStrength, "" end

    local first, rest = input:match("^(%S+)%s+(.+)$")
    if first and Language.IsValid(string.lower(first)) then
        local langId = string.lower(first)
        local strength, text = rest:match("^(%d+)%s+(.+)$")
        if strength then
            return langId, math.max(0, math.min(100, tonumber(strength))), text
        end
        return langId, defaultStrength, rest
    end

    local strength, text = input:match("^(%d+)%s+(.+)$")
    if strength then
        return defaultLang, math.max(0, math.min(100, tonumber(strength))), text
    end

    return defaultLang, defaultStrength, input
end

local function showDecodeResult(original, decoded, langId, langName, inferredStrength)
    local reencoded = Language.TranslateText(decoded, inferredStrength or 100, langId, false)
    local ok = reencoded == original
    Print("decode (" .. langName .. ", strength |cffffff00" .. (inferredStrength or 0) .. "%|r, |cff00ff00cached|r):")
    Print("  translated: |cffcccccc\"" .. original .. "\"|r")
    Print("  decoded:    |cffffffff\"" .. decoded .. "\"|r")
    Print("  re-encode:  " .. (ok and "|cff00ff00OK|r" or "|cffff0000MISMATCH|r"))
    showDecode("Test", original, decoded, langId, langName)
end

local function testDecode(input)
    migrateDB()
    local langId, text = input:match("^(%S+)%s+(.+)$")
    if langId and Language.IsValid(string.lower(langId)) and text then
        langId = string.lower(langId)
        local decoded, inferredStrength = Language.TryDecode(text, langId)
        if decoded then
            showDecodeResult(text, decoded, langId, Language.GetLanguageName(langId), inferredStrength)
        else
            Print("could not decode as |cffffff00" .. Language.GetLanguageName(langId) .. "|r.")
            Print("No cached mapping for that line. Run |cffffff00/glyphic roundtrip " .. langId .. " <english>|r first,")
            Print("or hear it from another Glyphic user in party/raid/guild/whisper.")
        end
        return
    end

    text = input
    if text == "" then
        Print("usage: /glyphic decode [lang] <translated text>")
        Print("  example: /glyphic decode dwarven red hor gor loch")
        return
    end

    local decoded, inferredStrength, bestLangId, bestLangName = tryDecodeMessage(text, nil, true)
    if decoded then
        showDecodeResult(text, decoded, bestLangId, bestLangName, inferredStrength)
    else
        Print("could not decode. Specify a language: |cffffff00/glyphic decode dwarven <text>|r")
        Print("Decode needs a cached mapping from |cffffff00/glyphic roundtrip|r or another Glyphic user.")
        Print("Or check a learned language is enabled: |cffffff00/glyphic learned|r")
    end
end

local function testEncode(input)
    migrateDB()
    local langId, strength, text = parseLangStrengthText(input, GlyphicDB.language, getStrength())
    if text == "" then
        Print("usage: /glyphic encode [lang] [strength] <english text>")
        Print("  example: /glyphic encode dwarven 100 help us all friend")
        return
    end

    local encoded = Language.TranslateText(text, strength, langId)
    Print("encode (|cffffff00" .. Language.GetLanguageName(langId) .. "|r, strength |cffffff00" .. strength .. "%|r):")
    Print("  english:    |cffffffff\"" .. text .. "\"|r")
    Print("  translated: |cffcccccc\"" .. encoded .. "\"|r")
    Print("Try |cffffff00/glyphic decode " .. langId .. " " .. encoded .. "|r")
end

local function testRoundtrip(input)
    migrateDB()
    local langId, strength, text = parseLangStrengthText(input, GlyphicDB.language, getStrength())
    if text == "" then
        Print("usage: /glyphic roundtrip [lang] [strength] <english text>")
        Print("  example: /glyphic roundtrip dwarven 100 help us all friend")
        return
    end

    local encoded = Language.TranslateText(text, strength, langId)
    local decoded, inferredStrength = Language.TryDecode(encoded, langId, strength)
    local langName = Language.GetLanguageName(langId)

    Print("roundtrip (|cffffff00" .. langName .. "|r, strength |cffffff00" .. strength .. "%|r):")
    Print("  1. english:    |cffffffff\"" .. text .. "\"|r")
    Print("  2. translated: |cffcccccc\"" .. encoded .. "\"|r")

    if not decoded then
        Print("  3. |cffff0000decode failed|r")
        Print("Copy step 2 and run: |cffffff00/glyphic decode " .. langId .. " " .. encoded .. "|r")
        return
    end

    local reencoded = Language.TranslateText(decoded, inferredStrength or strength, langId)
    local encodeOk = reencoded == encoded
    local textOk = string.lower(decoded) == string.lower(text)

    Print("  3. decoded:    |cffffffff\"" .. decoded .. "\"|r (inferred strength |cffffff00" .. (inferredStrength or 0) .. "%|r)")
    Print("  4. re-encode:  " .. (encodeOk and "|cff00ff00OK|r" or "|cffff0000MISMATCH|r")
        .. "  english match: " .. (textOk and "|cff00ff00YES|r" or "|cffff0000NO|r"))
    if not textOk then
        Print("  |cffff0000unexpected: roundtrip should always match with cache|r")
    end
end

local function debugReport()
    migrateDB()
    local db = GlyphicDB
    local a = db.accent or {}
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ver = (getMeta and getMeta(ADDON, "Version")) or "?"

    Print("|cff8000ff--- diagnostics ---|r")
    Print(("version |cffffff00%s|r  modules: Language=%s Accent=%s Compat=%s")
        :format(ver, tostring(ns.Language ~= nil), tostring(ns.Accent ~= nil), tostring(ns.Compat ~= nil)))
    if usesPreSendPipeline() then
        -- On Midnight and Forever we intentionally do NOT overwrite the global (doing
        -- so taints protected UI); typed chat is handled by the pre-send event below.
        Print("send path=|cff00ff00pre-send event|r (global SendChatMessage left untouched -- taint-safe)")
    else
        Print(("hook installed=|cffffff00%s|r  global is ours=%s")
            :format(tostring(hookInstalled),
                (SendChatMessage == ourSendHook) and "|cff00ff00YES|r" or "|cffff0000NO (clobbered!)|r"))
    end
    Print(("SendChatMessage seen=|cffffff00%d|r time(s) this session")
        :format(sendHookCount))
    Print(("pre-send hook=%s  in combat=%s")
        :format(preSendRegistered and "|cff00ff00REGISTERED|r" or "|cffff8800n/a (older client)|r",
            (InCombatLockdown and InCombatLockdown()) and "|cffff0000YES (chat edits paused)|r" or "|cff00ff00no|r"))
    do
        local hasYapper = type(_G.YapperAPI) == "table"
        Print(("Yapper=%s  our filter=%s")
            :format(hasYapper and "|cff00ff00detected|r" or "|cff888888not present|r",
                yapperFilterHandle and "|cff00ff00REGISTERED|r" or (hasYapper and "|cffff0000NO|r" or "|cff888888n/a|r")))
    end
    Print(("in character=%s  fluency=|cffffff00%d%%|r  lang=|cffffff00%s|r")
        :format(db.inCharacter and "|cff00ff00YES|r" or "|cffff0000NO|r",
            getStrength(), tostring(db.language)))
    Print(("accent=|cffffff00%s|r  strength=|cffffff00%d%%|r")
        :format(tostring(a.id), a.strength or 0))
    Print("SAY channel enabled=" .. (ns.IsChannelEnabled("SAY") and "|cff00ff00YES|r" or "|cffff0000NO|r"))

    -- Live engine test (bypasses the send hook so we can tell whether the
    -- problem is the hook not firing vs. the translation/accent engine itself).
    local sample = "hello my friend we attack at dawn"
    Print("sample:    |cffffffff\"" .. sample .. "\"|r")
    local enc = Language.TranslateText(sample, getStrength(), db.language, false)
    Print("translate: |cffcccccc\"" .. enc .. "\"|r "
        .. ((enc ~= sample) and "|cff00ff00(changed)|r" or "|cffff0000(unchanged)|r"))
    if ns.Accent then
        local ok, acc = pcall(ns.Accent.Apply, sample, a.id, a.strength or 100, a.emotes)
        if ok then
            Print("accent:    |cffcccccc\"" .. tostring(acc) .. "\"|r "
                .. ((acc ~= sample) and "|cff00ff00(changed)|r" or "|cffff0000(unchanged)|r"))
        else
            Print("accent:    |cffff0000error: " .. tostring(acc) .. "|r")
        end
    end
    -- What a SAY line would actually come out as. The two transforms compose
    -- now, so this shows the composed result rather than which one won -- the
    -- old "path=language|accent" line existed only to explain why a configured
    -- accent silently did nothing, which can no longer happen.
    do
        local translating = db.inCharacter
            and (getStrength() > 0 or motherTongue() ~= nil)
            and ns.IsChannelEnabled("SAY")
        local accenting = accentAppliesTo("SAY")
        local composed = sample
        if translating then
            local marked, marks = Language.TranslateMarked(sample, getStrength(), db.language,
                motherTongue())
            if marks then
                local body = marked
                -- `false` = not a real utterance, so debugging never consumes
                -- the interjection your next real line would have got.
                if accenting then body = applyAccent(body, false) end
                composed = Language.RestoreMarked(body, marks)
            elseif accenting then
                composed = applyAccent(sample, false)
            end
        elseif accenting then
            composed = applyAccent(sample, false)
        end
        Print("SAY out:   |cffcccccc\"" .. composed .. "\"|r")
        Print("SAY using=" .. ((translating and "|cff00ff00language|r" or "|cff808080language:off|r"))
            .. " + " .. ((accenting and "|cff00ff00accent|r" or "|cff808080accent:off|r"))
            .. ((composed == sample) and "  |cffff0000(sent exactly as typed)|r" or ""))
    end
    Print("On Midnight and Forever, typed chat uses the pre-send hook (not")
    Print("SendChatMessage, so seen=0 is normal). Chat edits pause in combat by design.")
end

local function usage()
    Print("commands (also |cffffff00/tongues|r):")
    Print("  |cffffff00/glyphic|r  - open the config panel")
    Print("  |cffffff00/glyphic on|off|r  - speak in character / out of character")
    Print("  |cffffff00/glyphic ic|r  - toggle in character (same as the keybind and the bar)")
    Print("  |cffffff00/glyphic lang <id>|r  - set language (see /glyphic list)")
    Print("  |cffffff00/glyphic accent <id|off>|r  - set your accent (see /glyphic accent list)")
    Print("  |cffffff00/glyphic next|r / |cffffff00prev|r  - cycle your favorites (or learned languages)")
    Print("  |cffffff00/glyphic fav [id]|r  - favorite/unfavorite a language (no id = the current one)")
    Print("  |cffffff00/glyphic fav list|off|r  - show or clear your favorites")
    Print("  |cffffff00/glyphic favonly [on|off]|r  - cycle only favorites (the star on the bar)")
    Print("  |cffffff00/glyphic list|r  - list available languages")
    Print("  |cffffff00/glyphic learned|r  - list languages you understand")
    Print("  |cffffff00/glyphic custom|r  - create your own language")
    Print("  |cffffff00/glyphic import <code>|r  - add a shared language from a code")
    Print("  |cffffff00/glyphic export [name]|r  - get a shareable code for a custom language")
    Print("  |cffffff00/glyphic share [player]|r  - send your custom language to a target/group")
    Print("  |cffffff00/glyphic decode [lang] <text>|r  - decode translated text back to english")
    Print("  |cffffff00/glyphic encode [lang] [strength] <text>|r  - preview translation output")
    Print("  |cffffff00/glyphic roundtrip [lang] [strength] <text>|r  - encode then decode (self-test)")
    Print("  |cffffff00/glyphic fluency <0-100>|r  - set your fluency (= how you speak it) in the current language")
    Print("  |cffffff00/glyphic color [lang] [hex]|r  - per-language chat colors (|cffffff00/glyphic color|r for options)")
    Print("  |cffffff00/glyphic names [on|off|color|clear]|r  - leave player names readable in your speech")
    Print("  |cffffff00/glyphic minimap|r  - show/hide the minimap button")
    Print("  |cffffff00/glyphic output <1-N|default>|r  - send translations to a chat window")
    Print("  |cffffff00/glyphic mother <language>|r  - the tongue you fall back on (|cffffff00none|r to switch off)")
    Print("  |cffffff00/glyphic tag [on|off]|r  - show fluency in the [Language] tag (e.g. [Broken Orcish])")
    Print("  |cffffff00/glyphic game|r  - play the Decipher language trainer")
    Print("  |cffffff00/glyphic accent [on|off|<id>|list]|r  - speak in a dialect accent")
    Print("  |cffffff00/glyphic accentstrength <0-100>|r  - set accent thickness")
    Print("  |cffffff00/glyphic accenttails <0-100>|r  - how often lines end with a flourish (0 = never)")
    Print("  |cffffff00/glyphic cast|r  - phrases spoken when you cast (panel)")
    Print("  |cffffff00/glyphic cast on|off|r  - toggle cast phrases")
    Print("  |cffffff00/glyphic cast test [spell]|r  - show what a spell would say (sends nothing)")
    Print("  |cffffff00/glyphic cast status|r  - settings, plus whether chat is blocked right now")
    Print("  |cffffff00/glyphic say <text>|r  - say a translated line once")
    Print("  |cffffff00/glyphic yell <text>|r  - yell a translated line once")
    Print("  |cffffff00/glyphic p <text>|r  - preview a translation (only you see it)")
    Print("  |cffffff00/glyphic autodisable on|off|r  - pause translation in instances (accents keep working)")
    Print("  |cffffff00/glyphic debug|r  - diagnostics (hook status + live test)")
end

local function handleSlash(input)
    if not GlyphicDB then migrateDB() end
    input = input or ""
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "config" or cmd == "ui" or cmd == "options" then
        if ns.OpenConfig then ns.OpenConfig() end
    elseif cmd == "on" then
        setEnabled(true)
    elseif cmd == "off" then
        setEnabled(false)
    elseif cmd == "toggle" or cmd == "ic" or cmd == "ooc" then
        ns.ToggleInCharacter()
    elseif cmd == "lang" or cmd == "language" then
        setLanguage(rest)
    elseif cmd == "mother" or cmd == "fallback" then
        migrateDB()
        local arg = string.lower(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if arg == "" then
            local m = motherTongue()
            Print(m and ("Mother tongue is |cffffff00" .. Language.GetLanguageName(m)
                    .. "|r. Words your fluency doesn't cover come out in it.")
                or "No mother tongue. Words your fluency doesn't cover stay in English.")
            Print("  |cffffff00/glyphic mother <language>|r or |cffffff00/glyphic mother none|r")
        elseif arg == "none" or arg == "off" or arg == "clear" then
            GlyphicDB.motherTongue = nil
            Print("Mother tongue cleared. The rest of your speech stays in English.")
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        elseif not Language.IsValid(arg) then
            Print("Unknown language '|cffff0000" .. arg .. "|r'. Use |cffffff00/glyphic list|r.")
        elseif Language.IsPlain(arg) then
            -- Falling back to plain speech is what having no mother tongue
            -- already does, so accepting this would leave the setting reading
            -- as if it were on while changing nothing.
            Print("|cffffff00" .. Language.GetLanguageName(arg)
                .. "|r reads as ordinary speech, so there is nothing to fall back to."
                .. " Use |cffffff00/glyphic mother none|r for that.")
        else
            GlyphicDB.motherTongue = arg
            Print("Mother tongue set to |cffffff00" .. Language.GetLanguageName(arg)
                .. "|r. Words your fluency doesn't cover will come out in it.")
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        end
    elseif cmd == "next" or cmd == "cycle" then
        ns.CycleLanguage(1)
    elseif cmd == "prev" or cmd == "previous" then
        ns.CycleLanguage(-1)
    elseif cmd == "fav" or cmd == "favorite" or cmd == "favourite" then
        favoriteCommand(rest)
    elseif cmd == "cast" or cmd == "casts" or cmd == "phrases" then
        castCommand(rest)
    elseif cmd == "voice" or cmd == "voices" then
        voiceCommand(rest)
    elseif cmd == "favonly" then
        migrateDB()
        local db = GlyphicDB
        local arg = string.lower(rest or "")
        if arg == "on" then db.favOnly = true
        elseif arg == "off" then db.favOnly = false
        else db.favOnly = not db.favOnly end
        if db.favOnly then
            local n = #ns.GetFavorites()
            Print("cycling walks |cffffd100favorites only|r" ..
                (n == 0 and " |cff808080(none set yet, so it still walks learned languages)|r" or
                 " (" .. n .. ")") .. ".")
        else
            Print("cycling walks |cffffff00every language you've learned|r.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "timings" or cmd == "timing" then
        -- Undocumented on purpose: this is for answering "why did that take so
        -- long" with a number instead of a guess, not a setting anybody tunes.
        local rows = ns.Compat.Timings()
        if #rows == 0 then
            Print("nothing timed yet. Open the thing that felt slow, then run this again.")
        else
            Print("slowest run of each step, in milliseconds:")
            for _, r in ipairs(rows) do
                Print(string.format("  |cffffd100%7.0f|r  %s |cff808080(%d run%s)|r",
                    r.worst, r.label, r.count, r.count == 1 and "" or "s"))
            end
        end
    elseif cmd == "list" or cmd == "langs" then
        listLanguages()
    elseif cmd == "learned" then
        listLearned()
    elseif cmd == "custom" or cmd == "create" then
        if ns.OpenCustomConfig then ns.OpenCustomConfig() end
    elseif cmd == "import" then
        if rest == "" then
            Print("Usage: |cffffff00/glyphic import <share code>|r (or paste it in the Create Language panel).")
        else
            local ok, idOrErr = ns.ImportCustomLanguage(rest)
            if ok then
                Print("Imported language |cffffff00" .. Language.GetLanguageName(idOrErr) .. "|r.")
                if ns.OpenCustomConfig then ns.OpenCustomConfig() end
            else
                Print("Import failed: " .. tostring(idOrErr))
            end
        end
    elseif cmd == "export" then
        local id = (rest ~= "" and Language.MakeCustomId(rest)) or GlyphicDB.language
        if id and Language.IsCustom(id) then
            if ns.OpenCustomConfig then ns.OpenCustomConfig() end
            if ns.ShowExportCode then ns.ShowExportCode(id) end
            Print("Share code for |cffffff00" .. Language.GetLanguageName(id) .. "|r is in the Create Language panel -- select it and copy.")
        else
            Print("Set a custom language first, or use |cffffff00/glyphic export <name>|r.")
        end
    elseif cmd == "share" then
        local id = GlyphicDB.language
        if not (id and Language.IsCustom(id)) then
            Print("Select one of your custom languages first (it's the language you're currently speaking).")
        else
            local target = (rest ~= "" and rest) or (UnitName and UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") and UnitName("target")) or nil
            local ok, msg = ns.ShareCustomLanguage(id, target)
            Print(ok and ("|cff00ff00" .. msg .. "|r") or ("|cffff0000" .. msg .. "|r"))
        end
    elseif cmd == "profile" or cmd == "backup" then
        -- Deliberately NOT folded into the existing /glyphic export, which has
        -- meant "share one invented language" for several releases and is in
        -- people's notes that way. Two different things that both produce a
        -- long string are exactly the pair you do not want sharing a verb.
        local Profile = ns.Profile
        local arg, tail = rest:match("^(%S*)%s*(.*)$")
        arg = string.lower(arg or "")

        if arg == "" then
            if ns.OpenProfileConfig then ns.OpenProfileConfig() end
        elseif arg == "export" or arg == "save" then
            if ns.OpenProfileConfig then ns.OpenProfileConfig() end
            if ns.ShowProfileCode then ns.ShowProfileCode() end
            Print("Your profile code is in the Profiles panel -- it is already selected, so press Ctrl+C.")
        elseif arg == "import" or arg == "load" or arg == "restore" then
            if tail == "" then
                if ns.OpenProfileConfig then ns.OpenProfileConfig() end
                Print("Paste the code into the Profiles panel, or use |cffffff00/glyphic profile import <code>|r.")
            else
                local parsed, err = Profile.Parse(tail)
                if not parsed then
                    Print("|cffff0000That code was refused:|r " .. tostring(err))
                else
                    -- Confirmed even from the command line. This overwrites
                    -- every setting on the character, and a mistyped command
                    -- should not be able to do that silently.
                    ns.ConfirmProfileImport(parsed)
                end
            end
        else
            Print("Usage: |cffffff00/glyphic profile export|r or |cffffff00/glyphic profile import <code>|r.")
        end
    elseif cmd == "decode" or cmd == "testdecode" then
        testDecode(rest)
    elseif cmd == "encode" or cmd == "enc" then
        testEncode(rest)
    elseif cmd == "roundtrip" or cmd == "rt" then
        testRoundtrip(rest)
    elseif cmd == "strength" or cmd == "corruption" or cmd == "corrupt" or cmd == "fluency" then
        -- Speaking strength IS your fluency in the current language now, so this
        -- sets/reads the active language's fluency.
        local langId = GlyphicDB.language
        local n = tonumber(rest)
        if n then
            n = math.max(0, math.min(100, math.floor(n + 0.5)))
            ns.SetLanguageFluency(langId, n / 100)
            Print("Fluency in |cffffff00" .. Language.GetLanguageName(langId) .. "|r set to |cffffff00" .. n .. "%|r.")
        else
            Print("Your fluency in |cffffff00" .. Language.GetLanguageName(langId) .. "|r is |cffffff00" .. getStrength() .. "%|r. Use |cffffff00/glyphic fluency <0-100>|r.")
        end
    elseif cmd == "accent" then
        migrateDB()
        local a = GlyphicDB.accent
        local arg = string.lower(rest or "")
        if arg == "" then
            if ns.OpenAccentConfig then ns.OpenAccentConfig() end
        elseif arg == "on" then
            -- "on" with nothing selected has to pick something, or it would
            -- claim to enable an accent and leave you on "none". Prefer the one
            -- they last used over the generic default.
            if a.id == ns.Accent.NONE then
                a.id = (a.lastId and ns.Accent.IsValid(a.lastId) and a.lastId) or ns.Accent.DEFAULT
            end
            Print("Accent set to |cffffff00" .. ns.Accent.GetAccentName(a.id) .. "|r.")
        elseif arg == "off" or arg == "none" then
            if a.id ~= ns.Accent.NONE then a.lastId = a.id end
            a.id = ns.Accent.NONE
            Print("Speaking |cffffff00plainly|r (no accent).")
        elseif arg == "list" then
            if ns.Accent then
                Print("Accents:")
                local list = ns.Accent.GetAccents()
                for i = 1, #list do
                    Print("  |cffffff00" .. list[i].id .. "|r - " .. list[i].name)
                end
            end
        elseif ns.Accent and ns.Accent.IsValid(arg) then
            a.id = arg
            Print("Accent set to |cffffff00" .. ns.Accent.GetAccentName(arg) .. "|r.")
        else
            Print("Unknown accent. Use /glyphic accent list.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "accentstrength" then
        migrateDB()
        local n = tonumber(rest)
        if n then
            GlyphicDB.accent.strength = math.max(0, math.min(100, math.floor(n + 0.5)))
            Print("Accent strength set to |cffffff00" .. GlyphicDB.accent.strength .. "%|r.")
        else
            Print("Accent strength is |cffffff00" .. (GlyphicDB.accent.strength or 100) .. "%|r. Use /glyphic accentstrength <0-100>.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "accenttails" then
        migrateDB()
        local a = GlyphicDB.accent
        local n = tonumber(rest)
        if n then
            a.tails = math.max(0, math.min(100, math.floor(n + 0.5)))
            if ns.Accent then ns.Accent.SetTailFrequency(a.tails) end
            Print(("Accent interjections set to |cffffff00%d|r (%s).")
                :format(a.tails, ns.Accent and ns.Accent.DescribeTailFrequency(a.tails) or "?"))
        else
            local cur = a.tails or (ns.Accent and ns.Accent.TAIL_DIAL_DEFAULT) or 40
            Print(("Accent interjections are |cffffff00%d|r (%s). Use /glyphic accenttails <0-100>; 0 turns them off.")
                :format(cur, ns.Accent and ns.Accent.DescribeTailFrequency(cur) or "?"))
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "tag" or cmd == "langtag" or cmd == "fluencytag" then
        -- The [Language] tag itself is always on (not configurable); this only
        -- toggles the optional fluency adjective prefix, e.g. [Broken Orcish].
        migrateDB()
        local arg = string.lower(rest or "")
        if arg == "on" then
            GlyphicDB.tagFluency = true
        elseif arg == "off" then
            GlyphicDB.tagFluency = false
        else
            GlyphicDB.tagFluency = not GlyphicDB.tagFluency
        end
        Print("Messages always start with [Language]. Fluency prefix "
            .. (GlyphicDB.tagFluency
                and "|cff00ff00ON|r (e.g. [Broken Orcish])"
                or "|cffff0000OFF|r") .. ".")
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "names" then
        migrateDB()
        if not ns.Names then
            Print("Name protection is unavailable on this install.")
            return
        end
        local arg = string.lower(rest or "")
        if arg == "on" or arg == "off" then
            ns.Names.SetEnabled(arg == "on")
            Print("Player names in your speech: "
                .. (arg == "on" and "|cff00ff00left readable|r" or "|cffff0000translated with everything else|r") .. ".")
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
            return
        end
        if arg == "clear" then
            ns.Names.Clear()
            ns.Names.RefreshRoster()
            Print("Forgot every remembered name and rebuilt from your group.")
            return
        end
        if arg == "color" or arg == "colour" then
            ns.Names.SetHighlightEnabled(not ns.Names.HighlightEnabled())
            Print("Protected names are "
                .. (ns.Names.HighlightEnabled()
                    and "|cff00ff00colored|r in your chat window"
                    or "|cffff0000left in the line's own color|r") .. ".")
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
            return
        end
        local list = ns.Names.List()
        Print("Name protection is "
            .. (ns.Names.IsEnabled() and "|cff00ff00on|r" or "|cffff0000off|r")
            .. ", " .. #list .. " name(s) remembered.")
        if #list > 0 then
            -- Long enough lists are unreadable in chat and this is a debug aid,
            -- so show a window of it rather than paging the whole roster out.
            -- Painted the way chat would paint them, which makes this the
            -- quickest way to see which names picked up a class.
            local shown = {}
            for i = 1, math.min(#list, 25) do
                shown[i] = Colors and Colors.Wrap(list[i], ns.Names.ColorFor(list[i])) or list[i]
            end
            Print(table.concat(shown, ", ") .. (#list > 25 and (", and " .. (#list - 25) .. " more") or ""))
        end
        Print("Use |cffffff00/glyphic names on|off|r, |cffffff00/glyphic names color|r, or |cffffff00/glyphic names clear|r to reset the list.")
    elseif cmd == "color" or cmd == "colour" or cmd == "colors" or cmd == "colours" then
        migrateDB()
        if not Colors then
            Print("Colors are unavailable on this install.")
            return
        end
        -- "<id> <hex>" and "<id> reset" both start with a language, so the
        -- bare words are checked first and anything else is read as a language.
        local first, second = string.match(rest or "", "^(%S*)%s*(.*)$")
        local arg = string.lower(first or "")
        if arg == "" then
            local function state(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end
            Print("Tag color " .. state(Colors.TagsEnabled())
                .. ", speech tint " .. state(Colors.SpeechEnabled())
                .. ", in-game languages " .. state(Colors.RealLanguagesEnabled()) .. ".")
            Print("  |cffffff00/glyphic color <lang> <hex>|r  - e.g. /glyphic color demonic ff9e5e")
            Print("  |cffffff00/glyphic color <lang> reset|r  - back to the shipped color")
            Print("  |cffffff00/glyphic color list|r  - show every language's color")
            Print("  |cffffff00/glyphic color tags on|off|r  - color the [Language] tag")
            Print("  |cffffff00/glyphic color speech on|off|r  - tint the spoken words (independent of tags)")
            Print("  |cffffff00/glyphic color ingame on|off|r, |cffffff00/glyphic color off|r (all), |cffffff00resetall|r")
        elseif arg == "tags" then
            local v = string.lower(second or "")
            Colors.SetTagsEnabled(v == "on" or (v ~= "off" and not Colors.TagsEnabled()))
            Print("Tag color " .. (Colors.TagsEnabled()
                and "|cff00ff00on|r" or "|cffff0000off|r -- tags keep the channel's own color") .. ".")
        elseif arg == "on" or arg == "off" then
            -- The bare form is the convenience switch over both axes; "off"
            -- means "stop coloring anything", and "on" restores the shipped
            -- look rather than turning on a tint nobody asked for.
            local on = (arg == "on")
            Colors.SetTagsEnabled(on)
            if not on then Colors.SetSpeechEnabled(false) end
            Print("Language colors " .. (on
                and "|cff00ff00on|r (tags; add |cffffff00/glyphic color speech on|r for the words)"
                or "|cffff0000off|r") .. ".")
        elseif arg == "speech" then
            local v = string.lower(second or "")
            Colors.SetSpeechEnabled(v == "on" or (v ~= "off" and not Colors.SpeechEnabled()))
            Print("Speech tint " .. (Colors.SpeechEnabled()
                and "|cff00ff00on|r -- the whole line takes the language color"
                or "|cffff0000off|r -- only the [Language] tag is colored") .. ".")
        elseif arg == "ingame" or arg == "real" then
            local v = string.lower(second or "")
            Colors.SetRealLanguagesEnabled(v == "on" or (v ~= "off" and not Colors.RealLanguagesEnabled()))
            Print("In-game language tint " .. (Colors.RealLanguagesEnabled()
                and "|cff00ff00on|r -- real Orcish, Darnassian and friends are tinted too"
                or "|cffff0000off|r") .. ".")
        elseif arg == "resetall" then
            Colors.ResetAll()
            Print("All language colors reset to their shipped values.")
        elseif arg == "list" then
            Print("language colors (|cffffff00/glyphic color <lang> <hex>|r to change):")
            local langs = Language.GetLanguages()
            for i = 1, #langs do
                local id = langs[i].id
                local hex = Colors.Hex(id)
                Print(string.format("  |cff%s%s|r  |cffffff00%s|r%s", hex, langs[i].name, hex,
                    Colors.IsCustom(id) and " |cff888888(custom)|r" or ""))
            end
        elseif Language.IsValid(arg) then
            local value = string.lower(second or "")
            if value == "" then
                local hex = Colors.Hex(arg)
                Print(string.format("|cff%s%s|r is |cffffff00%s|r%s", hex,
                    Language.GetLanguageName(arg), hex,
                    Colors.IsCustom(arg) and " |cff888888(custom)|r" or " |cff888888(default)|r"))
            elseif value == "reset" or value == "default" then
                Colors.Reset(arg)
                Print(string.format("|cff%s%s|r reset to |cffffff00%s|r.",
                    Colors.Hex(arg), Language.GetLanguageName(arg), Colors.Hex(arg)))
            elseif Colors.Set(arg, value) then
                Print(string.format("|cff%s%s|r is now |cffffff00%s|r.",
                    Colors.Hex(arg), Language.GetLanguageName(arg), Colors.Hex(arg)))
            else
                Print("That isn't a color. Use six hex digits, e.g. |cffffff00ff9e5e|r.")
            end
        else
            Print("Unknown language '" .. arg .. "'. Use |cffffff00/glyphic color list|r.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "game" or cmd == "learn" or cmd == "trainer" or cmd == "wordle" then
        if ns.OpenTrainer then ns.OpenTrainer() end
    elseif cmd == "minimap" or cmd == "mm" then
        migrateDB()
        GlyphicDB.minimap = GlyphicDB.minimap or {}
        GlyphicDB.minimap.hide = not GlyphicDB.minimap.hide
        Print("Minimap button " .. (GlyphicDB.minimap.hide and "|cffff0000hidden|r" or "|cff00ff00shown|r") .. ".")
        if ns.ApplyMinimapShown then ns.ApplyMinimapShown() end
    elseif cmd == "output" or cmd == "window" or cmd == "out" then
        migrateDB()
        local maxWin = NUM_CHAT_WINDOWS or 10
        local arg = string.lower(rest or "")
        if arg == "" then
            local cur = GlyphicDB.outputFrame or 0
            if cur >= 1 then
                local name = GetChatWindowInfo and GetChatWindowInfo(cur)
                Print("Translations show in |cffffff00" .. (name and name ~= "" and name or ("Chat window " .. cur)) .. "|r.")
            else
                Print("Translations show in the |cffffff00default|r chat window.")
            end
            Print("Use |cffffff00/glyphic output <1-" .. maxWin .. ">|r or |cffffff00/glyphic output default|r.")
        elseif arg == "default" or arg == "0" or arg == "main" then
            GlyphicDB.outputFrame = 0
            Print("Translations will show in the |cffffff00default|r chat window.")
        else
            local n = tonumber(arg)
            if n and n >= 1 and n <= maxWin then
                GlyphicDB.outputFrame = n
                local name = GetChatWindowInfo and GetChatWindowInfo(n)
                Print("Translations will show in |cffffff00" .. (name and name ~= "" and name or ("Chat window " .. n)) .. "|r.")
            else
                Print("Usage: |cffffff00/glyphic output <1-" .. maxWin .. ">|r or |cffffff00/glyphic output default|r.")
            end
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "say" and rest ~= "" then
        speak(rest, "SAY")
    elseif cmd == "yell" and rest ~= "" then
        speak(rest, "YELL")
    elseif (cmd == "p" or cmd == "preview") and rest ~= "" then
        Print("|cffccccff" .. Language.TranslateText(rest, getStrength(), GlyphicDB.language) .. "|r")
    elseif cmd == "autodisable" or cmd == "instances" or cmd == "instancewarning" or cmd == "instwarn" then
        local arg = string.lower(rest)
        if arg == "on" then
            GlyphicDB.autoDisableInInstances = true
        elseif arg == "off" then
            GlyphicDB.autoDisableInInstances = false
        else
            GlyphicDB.autoDisableInInstances = not (GlyphicDB.autoDisableInInstances ~= false)
        end
        Print("Auto-disable in instances " ..
            (GlyphicDB.autoDisableInInstances ~= false and "|cff00ff00ON|r" or "|cffff0000OFF|r") .. ".")
        if ns.RefreshInstanceState then ns.RefreshInstanceState() end
    elseif cmd == "debug" or cmd == "diag" then
        installSendHook()
        registerPreSendHook()
        registerYapperFilter()
        debugReport()
    elseif cmd == "help" then
        usage()
    else
        speak(input, "SAY")
    end
end

-- /glyphic is the command; the rest are aliases. `/ogt` was retired in 0.3.1
-- -- it was short for Old God Tongues, the addon's name three renames ago,
-- and it no longer tells anyone what this addon is.
--
-- `/toa` is NOT going the same way. It is in people's macros and in every
-- post written about this addon under its old name, and an alias costs one
-- line; retiring it would break working setups to tidy up a list only the
-- author reads. The global keeps its name for the same reason the folder
-- does: SlashCmdList is keyed on it, and nobody sees it.
SLASH_TONGUESOFAZEROTH1 = "/glyphic"
SLASH_TONGUESOFAZEROTH2 = "/gly"
SLASH_TONGUESOFAZEROTH3 = "/toa"
SLASH_TONGUESOFAZEROTH4 = "/tongues"
SLASH_TONGUESOFAZEROTH5 = "/oldgod"
SlashCmdList["TONGUESOFAZEROTH"] = handleSlash

-- Export channel list for the UI.
ns.CHANNEL_TYPES = CHANNEL_TYPES
ns.DEFAULT_CHANNELS = DEFAULT_CHANNELS

--=========================================================================--
--  Init
--=========================================================================--
-- Inside instances (dungeons/raids/BGs/arenas) Blizzard delivers other players'
-- chat as protected "secret" values during boss fights, so Glyphic can't translate
-- or decode there. When "auto-disable in instances" is on we simply switch Glyphic
-- off on entry and back on when leaving -- clearly a game restriction, not a bug.
local function suppressionWanted()
    local inInstance = IsInInstance and IsInInstance() and true or false
    return inInstance
        and (GlyphicDB and GlyphicDB.autoDisableInInstances ~= false)
        and true or false
end

-- Turn suppression on/off, announcing the change. `left` distinguishes "you left
-- the instance" from "you toggled the option off while still inside".
local function applyInstanceSuppression(want, left)
    if want and not instanceSuppressed then
        instanceSuppressed = true
        Print("|cffffd200translation paused inside this instance. Blizzard blocks addons from reading chat during boss fights, so encoded speech can't be decoded here. Accents keep working -- they're plain speech. Translation resumes automatically once you leave.|r")
        local line = "Glyphic: translation paused in this instance (Blizzard chat restriction). Accents still work. Resumes when you leave."
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, line, { r = 1, g = 0.82, b = 0.2 })
        elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(line, 1, 0.82, 0.2, 1, 6)
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif (not want) and instanceSuppressed then
        instanceSuppressed = false
        Print(left and "|cff33ff33translation resumed|r now that you've left the instance."
            or "|cff33ff33translation resumed.|r")
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    end
end

-- Called on world-entry (loading screens) and when the option is toggled. Uses
-- desired state (not just transitions) so flipping the option mid-instance works.
local function checkInstanceRestriction(fromToggle)
    applyInstanceSuppression(suppressionWanted(), not fromToggle)
end
ns.RefreshInstanceState = function() checkInstanceRestriction(true) end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        migrateDB()
        loadCustomLanguages()
        installSendHook()
        registerPreSendHook()
        Compat.RegisterAddonMessagePrefix(ADDON_PREFIX)
        -- No login message on purpose: keep the addon silent and out of chat
        -- until the player actually uses it.
    elseif event == "PLAYER_LOGIN" then
        installSendHook()
        registerPreSendHook()
        -- Yapper (and other addons) finish loading by now, so _G.YapperAPI exists.
        registerYapperFilter()
        -- Known languages are available now: compute which tongues to hide.
        ns.RefreshNativeLanguages()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-check in case a faction choice / allied-race unlock changed them.
        ns.RefreshNativeLanguages()
        checkInstanceRestriction()
    end
end)
