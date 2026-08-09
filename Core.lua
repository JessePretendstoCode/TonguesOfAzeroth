--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Core.lua
    Wires the language engine into chat: auto-translate toggle, slash commands,
    per-channel filters, and learned-language decoding on incoming messages.

    Notes for 3.3.5a:
      * SendChatMessage is not a protected function, so wrapping it (as Tongues
        and similar RP addons do) is safe for say/yell/party/etc.
      * WoW chat has a 255 character limit; translations are longer than the
        source, so output is trimmed to fit.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language
local Compat = ns.Compat

local MAX_MESSAGE = 255

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

local CHANNEL_TYPES = {
    "SAY", "YELL", "WHISPER", "PARTY", "RAID", "RAID_WARNING",
    "INSTANCE_CHAT", "GUILD", "OFFICER", "CHANNEL",
}

local DEFAULT_CHANNELS = {
    SAY            = true,
    YELL           = true,
    EMOTE          = true,
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

local PREFIX = "|cff8000ff[ToA]|r "
local ADDON_PREFIX = "ToA2"
local MAX_ADDON_PAYLOAD = 240

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

    -- Say/Yell have no addon channel; mirror payload to party/raid so grouped friends can decode.
    local sayType = normalizeChatType(chatType)
    if sayType == "SAY" or sayType == "YELL" then
        if Compat.InRaid() then
            send("RAID")
        elseif Compat.InParty() then
            send("PARTY")
        end
    end
end

-- Resolve the chat window that decoded translations should print to. Players
-- can send the (often noisy) decode output to a dedicated tab -- e.g. "Chat 3"
-- -- via the "Show translations in" setting; 0 keeps it in the default window.
local function getDecodeFrame()
    local idx = TonguesOfAzerothDB and TonguesOfAzerothDB.outputFrame
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

local function migrateDB()
    if TonguesOfAzerothDB == nil and OldGodTonguesDB ~= nil then
        TonguesOfAzerothDB = OldGodTonguesDB
    end
    TonguesOfAzerothDB = TonguesOfAzerothDB or {}
    local db = TonguesOfAzerothDB

    if db.strength == nil and db.corruption ~= nil then
        db.strength = db.corruption
    end
    if db.strength == nil then
        db.strength = 100
    end

    if db.enabled == nil then
        db.enabled = false
    end
    if db.language == nil or not Language.IsValid(db.language) then
        db.language = Language.DEFAULT
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
    if db.decodeStyle == nil then
        db.decodeStyle = "emote"
    end
    -- Which chat window the addon's decoded translations are printed to.
    -- 0 = the default chat frame; 1..NUM_CHAT_WINDOWS = that ChatFrame index.
    if db.outputFrame == nil then
        db.outputFrame = 0
    end
    -- Prepend "[Language] " to translated messages so everyone can see the tongue.
    if db.tagLanguage == nil then
        db.tagLanguage = true
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

    if not db.accent then db.accent = {} end
    if db.accent.enabled == nil then db.accent.enabled = false end
    if db.accent.strength == nil then db.accent.strength = 100 end
    if db.accent.id == nil or not (ns.Accent and ns.Accent.IsValid(db.accent.id)) then
        db.accent.id = (ns.Accent and ns.Accent.DEFAULT) or "dwarf"
    end

    -- One-time: enable all channel toggles (older saves may have some off).
    if not db.channelDefaultsVersion or db.channelDefaultsVersion < 2 then
        for ch, enabled in pairs(DEFAULT_CHANNELS) do
            db.channels[ch] = enabled
        end
        db.channelDefaultsVersion = 2
    end
end

function ns.IsChannelEnabled(chatType)
    migrateDB()
    chatType = normalizeChatType(chatType)
    if not TonguesOfAzerothDB or not TonguesOfAzerothDB.channels then return false end
    return TonguesOfAzerothDB.channels[chatType] and true or false
end

local function getStrength()
    return TonguesOfAzerothDB and TonguesOfAzerothDB.strength or 100
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
local function languageTag(langId)
    return "[" .. Language.GetLanguageName(langId) .. "] "
end

-- Shared outgoing transform. Given a raw message and its chat type, return
-- (outgoingText, changed). Also fires the decode payload for grouped ToA users
-- when a translation actually changed the text.
--   * Language translation "wins" only when it's on AND doing something
--     (strength > 0). At 0% strength it's a no-op, so accents can take over --
--     letting you drop Language strength to 0 to speak with a pure accent.
local function transformOutgoing(msg, sendType, channel)
    if type(msg) ~= "string" or msg == "" then return msg, false end
    local channelKey = normalizeChatType(sendType)
    if not ns.IsChannelEnabled(channelKey) then return msg, false end

    local db = TonguesOfAzerothDB
    if not db then return msg, false end

    if db.enabled and getStrength() > 0 then
        local langId = db.language
        local strength = getStrength()
        local out = translateOutgoing(msg, langId, strength)
        if out ~= msg then
            -- Cache/sync the UNTAGGED mapping so decoding still matches.
            sendDecodePayload(msg, out, langId, strength, sendType, channel)
            if db.tagLanguage ~= false then
                out = fit(languageTag(langId) .. out)
            end
            return out, true
        end
        return out, false
    elseif ns.Accent and db.accent and db.accent.enabled then
        local a = db.accent
        local ok, res = pcall(ns.Accent.Apply, msg, a.id, a.strength or 100)
        if ok and type(res) == "string" then return res, res ~= msg end
    end
    return msg, false
end

-- The SendChatMessage wrapper. Taint-safe: SendChatMessage is never in the path
-- of protected commands (/target, /cast, /use...), so wrapping it never blocks
-- those. This is the intercept point on 3.3.5a / Classic and for our own
-- programmatic sends. On Retail 12.0+ (Midnight) typed chat bypasses this path
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

-- Installs our SendChatMessage wrapper exactly once. We deliberately do NOT
-- re-assert later: if another addon chain-wraps us afterwards, we still run as
-- part of that chain, and re-capturing their wrapper as our "original" would
-- create mutual recursion (them -> us -> them -> ...). Installing once is both
-- loop-safe and keeps our translation in the send path.
local function installSendHook()
    if hookInstalled then return end
    if type(SendChatMessage) ~= "function" then return end
    orig_SendChatMessage = SendChatMessage
    ourSendHook = sendHookBody
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
    if not TonguesOfAzerothDB then return end
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

local function speak(msg, chatType, channel)
    migrateDB()
    installSendHook()
    suppress = true
    local langId = TonguesOfAzerothDB and TonguesOfAzerothDB.language
    local strength = getStrength()
    local translated = translateOutgoing(msg, langId, strength)
    local out = translated
    if translated ~= msg then
        sendDecodePayload(msg, translated, langId, strength, chatType or "SAY", channel)
        if TonguesOfAzerothDB and TonguesOfAzerothDB.tagLanguage ~= false then
            out = fit(languageTag(langId) .. translated)
        end
    end
    if orig_SendChatMessage then
        orig_SendChatMessage(out, chatType or "SAY", nil, channel)
    end
    suppress = false
end

--=========================================================================--
--  Learned-language decode on incoming chat.
--=========================================================================--
local function tryDecodeMessage(message)
    migrateDB()
    local learned = TonguesOfAzerothDB.learned or {}
    local trainerWords = (TonguesOfAzerothDB.trainer and TonguesOfAzerothDB.trainer.words) or {}

    -- Checked in the Learned panel = you fully understand the language (its own
    -- or its parent's box, since sub-languages share a word set).
    local function isChecked(entry)
        return (learned[entry.id] or (entry.parent and learned[entry.parent])) and true or false
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

    -- 1) Fully-understood (checked) languages: exact cached mapping first...
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
    -- ...then approximate word-by-word decode for generated languages (their
    -- output is exotic enough not to false-positive on ordinary chat; authentic
    -- word-list languages stay cache/sync-based to avoid collision guesses).
    if not bestDecoded then
        for i = 1, #langs do
            if isChecked(langs[i]) and Language.IsGenerated(langs[i].id) then
                local decoded, count = Language.DecodeWordwise(message, langs[i].id)
                if decoded and (not bestScore or count > bestScore) then
                    bestDecoded, bestScore = decoded, count
                    bestLangId, bestLangName = langs[i].id, langs[i].name
                end
            end
        end
    end
    if bestDecoded then
        return bestDecoded, bestScore, bestLangId, bestLangName
    end

    -- 2) Unchecked languages: only reveal the specific words you've unlocked in
    --    the trainer. This works for every language (generated or word-list).
    local bestCount
    for i = 1, #langs do
        if not isChecked(langs[i]) then
            local allowed = unlockedSet(langs[i])
            if allowed then
                local decoded, count = Language.DecodePartial(message, langs[i].id, allowed)
                if decoded and (not bestCount or count > bestCount) then
                    bestDecoded, bestCount = decoded, count
                    bestLangId, bestLangName = langs[i].id, langs[i].name
                end
            end
        end
    end
    return bestDecoded, bestCount, bestLangId, bestLangName
end

local function showDecode(sender, original, decoded, langId, langName)
    local style = TonguesOfAzerothDB.decodeStyle or "emote"
    local msg
    if style == "whisper" then
        msg = "|cffC79CFF[ToA: " .. langName .. "]|r "
            .. sender .. " spoke: |cffcccccc\"" .. original .. "\"|r "
            .. "-> |cffffffff\"" .. decoded .. "\"|r"
    else
        msg = "|cffFFFF00* " .. sender .. " (" .. langName .. "):|r "
            .. "|cffcccccc\"" .. original .. "\"|r "
            .. "|cff888888->|r |cffffffff\"" .. decoded .. "\"|r"
    end
    addToChat(msg, style, getDecodeFrame())
end

local function onIncomingChat(event, message, sender)
    if not message or message == "" then return end
    migrateDB()
    if sender == UnitName("player") then return end

    local chatType = CHAT_EVENTS[event]
    if not chatType or not ns.IsChannelEnabled(chatType) then return end

    -- Strip a leading "[Language] " flavor tag (ours or another ToA user's) so
    -- decoding sees the raw encoded text that matches the cached mapping.
    local stripped = message:gsub("^%[[^%]]+%]%s+", "")

    local bestDecoded, bestScore, bestLangId, bestLangName = tryDecodeMessage(stripped)
    if bestDecoded then
        showDecode(sender, stripped, bestDecoded, bestLangId, bestLangName)
    end
end

local chatFrame = CreateFrame("Frame")
for event in pairs(CHAT_EVENTS) do
    chatFrame:RegisterEvent(event)
end
chatFrame:RegisterEvent("CHAT_MSG_ADDON")
chatFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix == ADDON_PREFIX and Language.ImportDecodePayload then
            Language.ImportDecodePayload(message)
        end
        return
    end
    if CHAT_EVENTS[event] then
        local message, sender = ...
        onIncomingChat(event, message, sender)
    end
end)

--=========================================================================--
--  Slash commands
--=========================================================================--
local function setEnabled(state)
    TonguesOfAzerothDB.enabled = state
    if state then
        Print("Auto-translate |cff00ff00ON|r (|cffffff00" .. Language.GetLanguageName(TonguesOfAzerothDB.language) .. "|r).")
    else
        Print("Auto-translate |cffff0000OFF|r.")
    end
end

local function listLanguages()
    Print("available languages (use |cffffff00/toa lang <id>|r):")
    local langs = Language.GetLanguages()
    local active = TonguesOfAzerothDB and TonguesOfAzerothDB.language

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

local function setLanguage(id)
    id = string.lower(id or "")
    if Language.IsValid(id) then
        TonguesOfAzerothDB.language = id
        Print("Language set to |cffffff00" .. Language.GetLanguageName(id) .. "|r.")
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    else
        Print("Unknown language '|cffff0000" .. id .. "|r'. Use |cffffff00/ogt list|r.")
    end
end

local function listLearned()
    migrateDB()
    Print("learned languages:")
    local langs = Language.GetLanguages()
    local any = false
    for i = 1, #langs do
        if TonguesOfAzerothDB.learned[langs[i].id] then
            any = true
            Print("  |cff00ff00" .. langs[i].name .. "|r")
        end
    end
    if not any then
        Print("  |cffff0000(none)|r - check languages under Interface -> AddOns -> Learned Languages")
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
            Print("No cached mapping for that line. Run |cffffff00/ogt roundtrip " .. langId .. " <english>|r first,")
            Print("or hear it from another Tongues of Azeroth user in party/raid/guild/whisper.")
        end
        return
    end

    text = input
    if text == "" then
        Print("usage: /ogt decode [lang] <translated text>")
        Print("  example: /ogt decode dwarven red hor gor loch")
        return
    end

    local decoded, inferredStrength, bestLangId, bestLangName = tryDecodeMessage(text)
    if decoded then
        showDecodeResult(text, decoded, bestLangId, bestLangName, inferredStrength)
    else
        Print("could not decode. Specify a language: |cffffff00/ogt decode dwarven <text>|r")
        Print("Decode needs a cached mapping from |cffffff00/ogt roundtrip|r or another ToA user.")
        Print("Or check a learned language is enabled: |cffffff00/ogt learned|r")
    end
end

local function testEncode(input)
    migrateDB()
    local langId, strength, text = parseLangStrengthText(input, TonguesOfAzerothDB.language, getStrength())
    if text == "" then
        Print("usage: /ogt encode [lang] [strength] <english text>")
        Print("  example: /ogt encode dwarven 100 help us all friend")
        return
    end

    local encoded = Language.TranslateText(text, strength, langId)
    Print("encode (|cffffff00" .. Language.GetLanguageName(langId) .. "|r, strength |cffffff00" .. strength .. "%|r):")
    Print("  english:    |cffffffff\"" .. text .. "\"|r")
    Print("  translated: |cffcccccc\"" .. encoded .. "\"|r")
    Print("Try |cffffff00/ogt decode " .. langId .. " " .. encoded .. "|r")
end

local function testRoundtrip(input)
    migrateDB()
    local langId, strength, text = parseLangStrengthText(input, TonguesOfAzerothDB.language, getStrength())
    if text == "" then
        Print("usage: /ogt roundtrip [lang] [strength] <english text>")
        Print("  example: /ogt roundtrip dwarven 100 help us all friend")
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
        Print("Copy step 2 and run: |cffffff00/ogt decode " .. langId .. " " .. encoded .. "|r")
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
    local db = TonguesOfAzerothDB
    local a = db.accent or {}
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ver = (getMeta and getMeta(ADDON, "Version")) or "?"

    Print("|cff8000ff--- diagnostics ---|r")
    Print(("version |cffffff00%s|r  modules: Language=%s Accent=%s Compat=%s")
        :format(ver, tostring(ns.Language ~= nil), tostring(ns.Accent ~= nil), tostring(ns.Compat ~= nil)))
    Print(("hook installed=|cffffff00%s|r  global is ours=%s")
        :format(tostring(hookInstalled),
            (SendChatMessage == ourSendHook) and "|cff00ff00YES|r" or "|cffff0000NO (clobbered!)|r"))
    Print(("SendChatMessage seen=|cffffff00%d|r time(s) this session")
        :format(sendHookCount))
    Print(("Retail pre-send hook=%s  in combat=%s")
        :format(preSendRegistered and "|cff00ff00REGISTERED|r" or "|cffff8800n/a (older client)|r",
            (InCombatLockdown and InCombatLockdown()) and "|cffff0000YES (chat edits paused)|r" or "|cff00ff00no|r"))
    Print(("enabled=%s  strength=|cffffff00%d%%|r  lang=|cffffff00%s|r")
        :format(db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r", getStrength(), tostring(db.language)))
    Print(("accent enabled=%s  id=|cffffff00%s|r  strength=|cffffff00%d%%|r")
        :format(a.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r", tostring(a.id), a.strength or 0))
    Print("SAY channel enabled=" .. (ns.IsChannelEnabled("SAY") and "|cff00ff00YES|r" or "|cffff0000NO|r"))

    -- Live engine test (bypasses the send hook so we can tell whether the
    -- problem is the hook not firing vs. the translation/accent engine itself).
    local sample = "hello my friend we attack at dawn"
    Print("sample:    |cffffffff\"" .. sample .. "\"|r")
    local enc = translateOutgoing(sample, db.language, getStrength())
    Print("translate: |cffcccccc\"" .. enc .. "\"|r "
        .. ((enc ~= sample) and "|cff00ff00(changed)|r" or "|cffff0000(unchanged)|r"))
    if ns.Accent then
        local ok, acc = pcall(ns.Accent.Apply, sample, a.id, a.strength or 100)
        if ok then
            Print("accent:    |cffcccccc\"" .. tostring(acc) .. "\"|r "
                .. ((acc ~= sample) and "|cff00ff00(changed)|r" or "|cffff0000(unchanged)|r"))
        else
            Print("accent:    |cffff0000error: " .. tostring(acc) .. "|r")
        end
    end
    Print("On Retail 12.0+, typed chat uses the pre-send hook (not SendChatMessage,")
    Print("so seen=0 is normal there). Chat edits pause in combat by design.")
end

local function usage()
    Print("commands (also |cffffff00/ogt|r, |cffffff00/tongues|r):")
    Print("  |cffffff00/toa|r  - open the config panel")
    Print("  |cffffff00/ogt on|off|r  - toggle auto-translate")
    Print("  |cffffff00/ogt lang <id>|r  - set language (see /ogt list)")
    Print("  |cffffff00/ogt list|r  - list available languages")
    Print("  |cffffff00/ogt learned|r  - list languages you understand")
    Print("  |cffffff00/ogt decode [lang] <text>|r  - decode translated text back to english")
    Print("  |cffffff00/ogt encode [lang] [strength] <text>|r  - preview translation output")
    Print("  |cffffff00/ogt roundtrip [lang] [strength] <text>|r  - encode then decode (self-test)")
    Print("  |cffffff00/ogt strength <0-100>|r  - set translation strength")
    Print("  |cffffff00/ogt minimap|r  - show/hide the minimap button")
    Print("  |cffffff00/ogt output <1-N|default>|r  - send translations to a chat window")
    Print("  |cffffff00/ogt tag [on|off]|r  - prefix messages with [Language]")
    Print("  |cffffff00/ogt game|r  - play the Decipher language trainer")
    Print("  |cffffff00/ogt accent [on|off|<id>|list]|r  - speak in a dialect accent")
    Print("  |cffffff00/ogt accentstrength <0-100>|r  - set accent thickness")
    Print("  |cffffff00/ogt say <text>|r  - say a translated line once")
    Print("  |cffffff00/ogt yell <text>|r  - yell a translated line once")
    Print("  |cffffff00/ogt p <text>|r  - preview a translation (only you see it)")
    Print("  |cffffff00/ogt debug|r  - diagnostics (hook status + live test)")
end

local function handleSlash(input)
    if not TonguesOfAzerothDB then migrateDB() end
    input = input or ""
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "config" or cmd == "ui" or cmd == "options" then
        if ns.OpenConfig then ns.OpenConfig() end
    elseif cmd == "on" then
        setEnabled(true)
    elseif cmd == "off" then
        setEnabled(false)
    elseif cmd == "toggle" then
        setEnabled(not TonguesOfAzerothDB.enabled)
    elseif cmd == "lang" or cmd == "language" then
        setLanguage(rest)
    elseif cmd == "list" or cmd == "langs" then
        listLanguages()
    elseif cmd == "learned" then
        listLearned()
    elseif cmd == "decode" or cmd == "testdecode" then
        testDecode(rest)
    elseif cmd == "encode" or cmd == "enc" then
        testEncode(rest)
    elseif cmd == "roundtrip" or cmd == "rt" then
        testRoundtrip(rest)
    elseif cmd == "strength" or cmd == "corruption" or cmd == "corrupt" then
        local n = tonumber(rest)
        if n then
            TonguesOfAzerothDB.strength = math.max(0, math.min(100, math.floor(n + 0.5)))
            Print("Strength set to |cffffff00" .. TonguesOfAzerothDB.strength .. "%|r.")
        else
            Print("Strength is currently |cffffff00" .. getStrength() .. "%|r. Use /ogt strength <0-100>.")
        end
    elseif cmd == "accent" then
        migrateDB()
        local a = TonguesOfAzerothDB.accent
        local arg = string.lower(rest or "")
        if arg == "" then
            if ns.OpenAccentConfig then ns.OpenAccentConfig() end
        elseif arg == "on" then
            a.enabled = true
            Print("Accent |cff00ff00enabled|r (" .. (ns.Accent and ns.Accent.GetAccentName(a.id) or a.id) .. ").")
        elseif arg == "off" then
            a.enabled = false
            Print("Accent |cffff0000disabled|r.")
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
            a.enabled = true
            Print("Accent set to |cffffff00" .. ns.Accent.GetAccentName(arg) .. "|r.")
        else
            Print("Unknown accent. Use /ogt accent list.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "accentstrength" then
        migrateDB()
        local n = tonumber(rest)
        if n then
            TonguesOfAzerothDB.accent.strength = math.max(0, math.min(100, math.floor(n + 0.5)))
            Print("Accent strength set to |cffffff00" .. TonguesOfAzerothDB.accent.strength .. "%|r.")
        else
            Print("Accent strength is |cffffff00" .. (TonguesOfAzerothDB.accent.strength or 100) .. "%|r. Use /ogt accentstrength <0-100>.")
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "tag" or cmd == "langtag" then
        migrateDB()
        local arg = string.lower(rest or "")
        if arg == "on" then
            TonguesOfAzerothDB.tagLanguage = true
        elseif arg == "off" then
            TonguesOfAzerothDB.tagLanguage = false
        else
            TonguesOfAzerothDB.tagLanguage = not TonguesOfAzerothDB.tagLanguage
        end
        Print("Language tag " .. (TonguesOfAzerothDB.tagLanguage
            and "|cff00ff00ON|r (messages start with [Language])"
            or "|cffff0000OFF|r") .. ".")
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "game" or cmd == "learn" or cmd == "trainer" or cmd == "wordle" then
        if ns.OpenTrainer then ns.OpenTrainer() end
    elseif cmd == "minimap" or cmd == "mm" then
        migrateDB()
        TonguesOfAzerothDB.minimap = TonguesOfAzerothDB.minimap or {}
        TonguesOfAzerothDB.minimap.hide = not TonguesOfAzerothDB.minimap.hide
        Print("Minimap button " .. (TonguesOfAzerothDB.minimap.hide and "|cffff0000hidden|r" or "|cff00ff00shown|r") .. ".")
        if ns.ApplyMinimapShown then ns.ApplyMinimapShown() end
    elseif cmd == "output" or cmd == "window" or cmd == "out" then
        migrateDB()
        local maxWin = NUM_CHAT_WINDOWS or 10
        local arg = string.lower(rest or "")
        if arg == "" then
            local cur = TonguesOfAzerothDB.outputFrame or 0
            if cur >= 1 then
                local name = GetChatWindowInfo and GetChatWindowInfo(cur)
                Print("Translations show in |cffffff00" .. (name and name ~= "" and name or ("Chat window " .. cur)) .. "|r.")
            else
                Print("Translations show in the |cffffff00default|r chat window.")
            end
            Print("Use |cffffff00/ogt output <1-" .. maxWin .. ">|r or |cffffff00/ogt output default|r.")
        elseif arg == "default" or arg == "0" or arg == "main" then
            TonguesOfAzerothDB.outputFrame = 0
            Print("Translations will show in the |cffffff00default|r chat window.")
        else
            local n = tonumber(arg)
            if n and n >= 1 and n <= maxWin then
                TonguesOfAzerothDB.outputFrame = n
                local name = GetChatWindowInfo and GetChatWindowInfo(n)
                Print("Translations will show in |cffffff00" .. (name and name ~= "" and name or ("Chat window " .. n)) .. "|r.")
            else
                Print("Usage: |cffffff00/ogt output <1-" .. maxWin .. ">|r or |cffffff00/ogt output default|r.")
            end
        end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    elseif cmd == "say" and rest ~= "" then
        speak(rest, "SAY")
    elseif cmd == "yell" and rest ~= "" then
        speak(rest, "YELL")
    elseif (cmd == "p" or cmd == "preview") and rest ~= "" then
        Print("|cffccccff" .. Language.TranslateText(rest, getStrength(), TonguesOfAzerothDB.language) .. "|r")
    elseif cmd == "debug" or cmd == "diag" then
        installSendHook()
        registerPreSendHook()
        debugReport()
    elseif cmd == "help" then
        usage()
    else
        speak(input, "SAY")
    end
end

SLASH_TONGUESOFAZEROTH1 = "/toa"
SLASH_TONGUESOFAZEROTH2 = "/ogt"
SLASH_TONGUESOFAZEROTH3 = "/oldgod"
SLASH_TONGUESOFAZEROTH4 = "/tongues"
SlashCmdList["TONGUESOFAZEROTH"] = handleSlash

-- Export channel list for the UI.
ns.CHANNEL_TYPES = CHANNEL_TYPES
ns.DEFAULT_CHANNELS = DEFAULT_CHANNELS

--=========================================================================--
--  Init
--=========================================================================--
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        migrateDB()
        installSendHook()
        registerPreSendHook()
        Compat.RegisterAddonMessagePrefix(ADDON_PREFIX)
        -- No login message on purpose: keep the addon silent and out of chat
        -- until the player actually uses it.
    elseif event == "PLAYER_LOGIN" then
        installSendHook()
        registerPreSendHook()
    end
end)
