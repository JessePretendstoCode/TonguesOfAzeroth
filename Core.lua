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
    if not SendAddonMessage or original == encoded then return end
    local payload = langId .. "\001" .. tostring(strength or 100) .. "\001" .. original .. "\001" .. encoded
    if #payload > MAX_ADDON_PAYLOAD then return end

    local function send(dist, target)
        if dist == "WHISPER" and target then
            SendAddonMessage(ADDON_PREFIX, payload, dist, target)
        elseif dist then
            SendAddonMessage(ADDON_PREFIX, payload, dist)
        end
    end

    local dist, target = addonDistribution(chatType, channel)
    send(dist, target)

    -- Say/Yell have no addon channel; mirror payload to party/raid so grouped friends can decode.
    local sayType = normalizeChatType(chatType)
    if sayType == "SAY" or sayType == "YELL" then
        if GetNumRaidMembers and GetNumRaidMembers() > 0 then
            send("RAID")
        elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
            send("PARTY")
        end
    end
end

local function addToAllChatFrames(msg, style)
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

    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        local frame = _G["ChatFrame" .. i]
        if frame then
            frame:AddMessage(msg, r, g, b)
        end
    end
end

local function Print(msg)
    addToAllChatFrames(PREFIX .. msg, "system")
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
local suppress = false
local hookInstalled = false

local function installSendHook()
    if hookInstalled then return end
    if type(SendChatMessage) ~= "function" then return end
    orig_SendChatMessage = SendChatMessage
    SendChatMessage = function(msg, chatType, language, channel)
        migrateDB()
        local sendType = chatType or "SAY"
        local channelKey = normalizeChatType(sendType)
        local outMsg = msg

        if TonguesOfAzerothDB and TonguesOfAzerothDB.enabled and not suppress
            and ns.IsChannelEnabled(channelKey)
            and type(msg) == "string" and msg ~= "" then
            local langId = TonguesOfAzerothDB.language
            local strength = getStrength()
            outMsg = translateOutgoing(msg, langId, strength)
            if outMsg ~= msg then
                sendDecodePayload(msg, outMsg, langId, strength, sendType, channel)
            end
        end

        return orig_SendChatMessage(outMsg, sendType, language, channel)
    end
    hookInstalled = true
end

local function speak(msg, chatType, channel)
    migrateDB()
    installSendHook()
    suppress = true
    local langId = TonguesOfAzerothDB and TonguesOfAzerothDB.language
    local strength = getStrength()
    local translated = translateOutgoing(msg, langId, strength)
    if orig_SendChatMessage then
        orig_SendChatMessage(translated, chatType or "SAY", nil, channel)
    end
    if translated ~= msg then
        sendDecodePayload(msg, translated, langId, strength, chatType or "SAY", channel)
    end
    suppress = false
end

--=========================================================================--
--  Learned-language decode on incoming chat.
--=========================================================================--
local function tryDecodeMessage(message)
    migrateDB()
    local learned = TonguesOfAzerothDB.learned or {}

    local bestDecoded, bestScore, bestLangId, bestLangName
    local langs = Language.GetLanguages()
    for i = 1, #langs do
        local langId = langs[i].id
        if learned[langId] then
            local decoded, score = Language.TryDecode(message, langId)
            if decoded and (not bestScore or score > bestScore) then
                bestDecoded = decoded
                bestScore = score
                bestLangId = langId
                bestLangName = langs[i].name
            end
        end
    end
    return bestDecoded, bestScore, bestLangId, bestLangName
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
    addToAllChatFrames(msg, style)
end

local function onIncomingChat(event, message, sender)
    if not message or message == "" then return end
    migrateDB()
    if sender == UnitName("player") then return end

    local chatType = CHAT_EVENTS[event]
    if not chatType or not ns.IsChannelEnabled(chatType) then return end

    local bestDecoded, bestScore, bestLangId, bestLangName = tryDecodeMessage(message)
    if bestDecoded then
        showDecode(sender, message, bestDecoded, bestLangId, bestLangName)
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
    Print("available languages:")
    local langs = Language.GetLanguages()
    for i = 1, #langs do
        local marker = (langs[i].id == TonguesOfAzerothDB.language) and " |cff00ff00(active)|r" or ""
        Print("  |cffffff00" .. langs[i].id .. "|r - " .. langs[i].name .. marker)
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

local function usage()
    Print("commands:")
    Print("  |cffffff00/ogt|r  - open the config panel")
    Print("  |cffffff00/ogt on|off|r  - toggle auto-translate")
    Print("  |cffffff00/ogt lang <id>|r  - set language (see /ogt list)")
    Print("  |cffffff00/ogt list|r  - list available languages")
    Print("  |cffffff00/ogt learned|r  - list languages you understand")
    Print("  |cffffff00/ogt decode [lang] <text>|r  - decode translated text back to english")
    Print("  |cffffff00/ogt encode [lang] [strength] <text>|r  - preview translation output")
    Print("  |cffffff00/ogt roundtrip [lang] [strength] <text>|r  - encode then decode (self-test)")
    Print("  |cffffff00/ogt strength <0-100>|r  - set translation strength")
    Print("  |cffffff00/ogt say <text>|r  - say a translated line once")
    Print("  |cffffff00/ogt yell <text>|r  - yell a translated line once")
    Print("  |cffffff00/ogt p <text>|r  - preview a translation (only you see it)")
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
    elseif cmd == "say" and rest ~= "" then
        speak(rest, "SAY")
    elseif cmd == "yell" and rest ~= "" then
        speak(rest, "YELL")
    elseif (cmd == "p" or cmd == "preview") and rest ~= "" then
        Print("|cffccccff" .. Language.TranslateText(rest, getStrength(), TonguesOfAzerothDB.language) .. "|r")
    elseif cmd == "help" then
        usage()
    else
        speak(input, "SAY")
    end
end

SLASH_TONGUESOFAZEROTH1 = "/ogt"
SLASH_TONGUESOFAZEROTH2 = "/oldgod"
SLASH_TONGUESOFAZEROTH3 = "/tongues"
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
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(ADDON_PREFIX)
        end
        Print("loaded. Type |cffffff00/ogt|r for the panel.")
    elseif event == "PLAYER_LOGIN" then
        installSendHook()
    end
end)
