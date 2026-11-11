local ADDON, ns = ...
local Compat = ns.Compat

--[[---------------------------------------------------------------------------
    "A newer version is out", the way Total RP 3 says it.

    No addon can ask CurseForge anything. What it can do is tell other copies
    of itself which version it runs, over the same hidden addon channel the
    decode payloads use, and listen for theirs. Hearing a higher number than
    our own means a newer release exists; that is the whole mechanism.

    Who hears whom:
      * Each copy announces itself to its guild and group shortly after login,
        and to the group when someone joins it.
      * A copy that hears an older version answers on the same channel, so a
        player who logs in after everyone else still finds out. The answer
        waits a few random seconds and is dropped if someone else on that
        channel answered first: a guild of twenty up-to-date players greets
        one late arrival with one message, not twenty.

    The notice is a popup once per session, deferred out of combat, and can be
    switched off in Settings > General (`GlyphicDB.updateNotice`).
-----------------------------------------------------------------------------]]

local Update = {}
ns.Update = Update

Update.TAG = "TOAU1:"
Update.LOGIN_DELAY = 15     -- seconds after login before announcing
Update.CHANNEL_GAP = 60     -- at most one announcement per channel per minute
Update.REPLY_MIN, Update.REPLY_MAX = 1, 6

local state = {
    lastSent = {},      -- [distribution] = GetTime() of our last announcement
    pending = {},       -- [distribution] = true while a reply is waiting
    notified = nil,     -- the version we have already shown this session
    deferred = nil,     -- a version waiting for combat to end
    groupSize = 0,
}
Update._state = state

local function now() return (GetTime and GetTime()) or 0 end

local function secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- "0.6.4.2" (or "v0.6.4.2") -> { 0, 6, 4, 2 }. Anything else, including a
-- packager placeholder in a development copy, is nil, and a nil version never
-- announces or notifies.
function Update.Parse(v)
    if type(v) ~= "string" or #v > 24 then return nil end
    v = v:gsub("^v", "")
    if not v:find("^%d[%d%.]*$") or v:find("%.%.") or v:find("%.$") then return nil end
    local parts = {}
    for n in v:gmatch("%d+") do
        n = tonumber(n)
        if not n or n > 9999 or #parts >= 5 then return nil end
        parts[#parts + 1] = n
    end
    return parts
end

-- -1, 0 or 1. Missing parts count as zero, so 0.6.4 == 0.6.4.0 < 0.6.4.2.
function Update.Compare(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

function Update.OwnVersion()
    local v = Compat.GetAddOnMetadata and Compat.GetAddOnMetadata(ADDON, "Version")
    return Update.Parse(v) and v or nil
end

local function send(dist, target)
    local own = Update.OwnVersion()
    if not own or not Compat.canSendAddonMessage or not ns.ADDON_PREFIX then return false end
    if Compat.InChatLockdown and Compat.InChatLockdown() then return false end
    if dist ~= "WHISPER" then
        local last = state.lastSent[dist]
        if last and now() - last < Update.CHANNEL_GAP then return false end
        state.lastSent[dist] = now()
    end
    Compat.SendAddonMessage(ns.ADDON_PREFIX, Update.TAG .. own, dist, target)
    return true
end
Update._send = send

local function groupDistribution()
    if Compat.InRaid() then return "RAID" end
    if Compat.InParty() then return "PARTY" end
    return nil
end

-- Announce to the guild and the group; `groupOnly` for a roster change.
function Update.Announce(groupOnly)
    local g = groupDistribution()
    if g then send(g) end
    if not groupOnly and type(IsInGuild) == "function" and IsInGuild() then send("GUILD") end
end

local function isSelf(sender)
    local me = UnitName and UnitName("player")
    return me ~= nil and (sender == me or sender:gsub("%-.*", "") == me)
end

function Update.OnVersion(text, sender, channel)
    if secret(sender) or secret(channel) or type(sender) ~= "string" then return end
    if isSelf(sender) then return end
    local remote, own = Update.Parse(text), Update.Parse(Update.OwnVersion())
    if not remote or not own then return end
    local c = Update.Compare(remote, own)

    -- Someone on this channel is already as new as we are, so a reply we
    -- were holding would only repeat what the late arrival just heard.
    if c >= 0 and channel then state.pending[channel] = nil end

    if c > 0 then
        Update.Notify(text)
    elseif c < 0 and (channel == "GUILD" or channel == "PARTY" or channel == "RAID")
        and not state.pending[channel] then
        state.pending[channel] = true
        local delay = Update.REPLY_MIN + math.random() * (Update.REPLY_MAX - Update.REPLY_MIN)
        local function reply()
            if not state.pending[channel] then return end
            state.pending[channel] = nil
            send(channel)
        end
        if C_Timer and C_Timer.After then C_Timer.After(delay, reply) else reply() end
    end
end

function Update.Enabled()
    return not (GlyphicDB and GlyphicDB.updateNotice == false)
end

function Update.Notify(versionText)
    if not Update.Enabled() then return end
    local v = Update.Parse(versionText)
    if not v then return end
    -- Once a session, unless an even newer number turns up.
    if state.notified and Update.Compare(v, Update.Parse(state.notified)) <= 0 then return end
    if InCombatLockdown and InCombatLockdown() then
        if not state.deferred or Update.Compare(v, Update.Parse(state.deferred)) > 0 then
            state.deferred = versionText
        end
        return
    end
    state.notified, state.deferred = versionText, nil
    Update.ShowNotice(versionText)
end

--=========================================================================--
--  The notice. Our own frame in the game's dialog border, never a
--  StaticPopup (see Compat.ShowConfirm for why).
--=========================================================================--
local PAD, BUTTON, WIDTH = 24, 26, 440

local function build()
    local f = Compat.CreateBackdropFrame("Frame", "GlyphicUpdateNotice", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetSize(WIDTH, 200)
    f:SetPoint("CENTER", 0, 140)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    Compat.Backdrop(f, "dialog")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -PAD)
    title:SetText("New update available")
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOPLEFT", PAD, -(PAD + 34))
    body:SetPoint("TOPRIGHT", -PAD, -(PAD + 34))
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetWordWrap then body:SetWordWrap(true) end
    body:SetSpacing(2)
    f.body = body

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    local okay = CreateFrame("Button", nil, f)
    Compat.PanelButton(okay, OKAY or "Okay", 120, BUTTON)
    okay:SetPoint("BOTTOM", 0, PAD - 4)
    okay:SetScript("OnClick", function() f:Hide() end)
    f.okay = okay

    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "GlyphicUpdateNotice") end
    -- Measured again once drawn: GetStringHeight can answer for the previous
    -- text on a frame that has not been laid out yet.
    f:SetScript("OnShow", function(self) Update.Size(self) end)
    return f
end

function Update.Size(f)
    local h = PAD + 34 + (f.body:GetStringHeight() or 0) + 20 + BUTTON + PAD
    f:SetHeight(math.ceil(math.max(h, 150)))
end

function Update.NoticeText(versionText)
    local own = Update.OwnVersion() or "?"
    return "|cff33ff33A new version of Glyphic (" .. versionText .. ") is available.|r\n\n"
        .. "You have " .. own .. ". Update through CurseForge or your addon manager "
        .. "to get the latest |cff33ff33fixes and features|r.\n\n"
        .. "Older versions may not read everything |cffff5050newer versions send|r."
end

function Update.ShowNotice(versionText)
    state.frame = state.frame or build()
    local f = state.frame
    f.body:SetText(Update.NoticeText(versionText))
    Update.Size(f)
    f:Show()
    if f.Raise then f:Raise() end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8000ff[Glyphic]|r Version " .. versionText
            .. " is available. You have " .. (Update.OwnVersion() or "?") .. ".")
    end
    return f
end

-- `/glyphic update`: the notice as it would read for the next release, so it
-- can be seen without a second account running a newer copy.
function Update.Preview()
    local p = Update.Parse(Update.OwnVersion()) or { 0, 0, 0 }
    local nextV = {}
    for i = 1, #p do nextV[i] = p[i] end
    nextV[#nextV] = nextV[#nextV] + 1
    return Update.ShowNotice(table.concat(nextV, "."))
end

--=========================================================================--
--  Events
--=========================================================================--
local events = CreateFrame("Frame")
Update._events = events
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        state.groupSize = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        if C_Timer and C_Timer.After then
            C_Timer.After(Update.LOGIN_DELAY, function() Update.Announce(false) end)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Only when the group grew: someone new is there to hear it.
        local size = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        if size > state.groupSize then Update.Announce(true) end
        state.groupSize = size
    elseif event == "PLAYER_REGEN_ENABLED" and state.deferred then
        Update.Notify(state.deferred)
    end
end)
