--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Whispers.lua (hidden)
    While Old God is active at 100% strength, occasionally plays a random
    in-game Old God whisper (C'Thun / Yogg-Saron). No UI or slash command.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language

-- Built-in WotLK client sounds (no addon assets required).
local WHISPER_SOUNDS = {
    -- C'Thun (Ahn'Qiraj)
    "Sound\\Creature\\CThun\\CThunDeathIsClose.wav",
    "Sound\\Creature\\CThun\\CThunYouAreAlready.wav",
    "Sound\\Creature\\CThun\\CThunYouWillBetray.wav",
    "Sound\\Creature\\CThun\\CThunYouWillDie.wav",
    "Sound\\Creature\\CThun\\CThunYourCourage.wav",
    "Sound\\Creature\\CThun\\CThunYourFriends.wav",
    "Sound\\Creature\\CThun\\YouAreWeak.wav",
    "Sound\\Creature\\CThun\\YourHeartWill.wav",
    -- Yogg-Saron (Howling Fjord ambient whispers)
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper01.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper02.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper03.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper04.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper05.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper06.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper07.wav",
    "Sound\\Creature\\YoggSaron\\AK_YoggSaron_HowlingFjordWhisper08.wav",
}

local BASE_INTERVAL = 180 -- ~3 minutes
local INTERVAL_JITTER = 45 -- roughly 2m15s to 3m45s

local elapsed = 0
local nextInterval = BASE_INTERVAL + math.random(-INTERVAL_JITTER, INTERVAL_JITTER)

local function isOldGodMode()
    if not TonguesOfAzerothDB then return false end
    return TonguesOfAzerothDB.enabled
        and TonguesOfAzerothDB.language == Language.DEFAULT
        and TonguesOfAzerothDB.strength == 100
end

local function playRandomWhisper()
    if not isOldGodMode() then return end
    if UnitIsDead("player") then return end

    local path = WHISPER_SOUNDS[math.random(1, #WHISPER_SOUNDS)]
    PlaySoundFile(path, "Master")
end

local function scheduleNext()
    nextInterval = BASE_INTERVAL + math.random(-INTERVAL_JITTER, INTERVAL_JITTER)
    elapsed = 0
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == ADDON then
        scheduleNext()
    end
end)

frame:SetScript("OnUpdate", function(self, dt)
    if not isOldGodMode() then
        elapsed = 0
        return
    end

    elapsed = elapsed + dt
    if elapsed >= nextInterval then
        playRandomWhisper()
        scheduleNext()
    end
end)
