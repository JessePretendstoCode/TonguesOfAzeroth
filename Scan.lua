local ADDON, ns = ...

--[[---------------------------------------------------------------------------
    "Scan for Glyphic speakers" on Total RP 3's world map scan button.

    TRP3 publishes a MapScanner class and its broadcast channel for other
    addons (TRP3 Extended's stash scans use both), so this adds one more
    entry to its menu and lets TRP3 do the rest: the request on its
    broadcast channel, the timer, and the pins. The pins are TRP3's own
    player pins, so right-clicking one still opens a profile; the tooltip
    adds the tongue that player is speaking.

    It only finds players who run both addons, and it is inert without
    TRP3. Whether you answer is TRP3's location setting, including its
    "not while out of character" and War Mode options, so turning your
    location off in TRP3 hides you from this scan too.
-----------------------------------------------------------------------------]]

local Scan = {}
ns.Scan = Scan

Scan.ID = "glyphicScan"
Scan.COMMAND = "GLY_SCAN"
Scan.MAX_TONGUE = 48
Scan.ICON = "Interface\\AddOns\\Glyphic\\Media\\Glyphic-On"

-- TRP3's own location setting keys, read through its configuration.
local CFG = {
    enabled = "register_map_location",
    ooc = "register_map_location_ooc",
    warMode = "register_map_location_disable_war_mode",
    showWarModes = "register_map_location_show_war_modes",
    showOOC = "register_map_location_status_visibility",
}

-- What you are speaking, as a pin should say it; "" when you are not
-- speaking in character. TRP3 joins message parts with "~", so none survive.
function Scan.Tongue()
    local db = GlyphicDB
    if type(db) ~= "table" or not db.inCharacter then return "" end
    if ns.IsMuted and ns.IsMuted() then return "" end
    local L = ns.Language
    if not L then return "" end
    local name
    if L.IsNoTongue(db.language) then
        local m = ns.GetMotherTongue and ns.GetMotherTongue()
        name = m and L.GetLanguageName(m)
    else
        name = L.GetLanguageName(db.language)
    end
    name = tostring(name or ""):gsub("~", "")
    return name:sub(1, Scan.MAX_TONGUE)
end

function Scan.PinLine(name, tongue)
    if type(tongue) == "string" and tongue ~= "" then
        return name .. " |cffb69cff- speaking " .. tongue .. "|r"
    end
    return name .. " |cff9a9a9a- Glyphic, speaking plainly|r"
end

local installed

function Scan.IsInstalled() return installed == true end

function Scan.Install()
    if installed then return true end
    local T, API = _G.AddOn_TotalRP3, _G.TRP3_API
    if type(T) ~= "table" or type(API) ~= "table" then return false end
    local comm = T.Communications and T.Communications.broadcast
    local Map = T.Map
    local getValue = API.configuration and API.configuration.getValue
    local pinMixin = _G.TRP3_PlayerMapPinMixin
    if type(T.MapScanner) ~= "table" and type(T.MapScanner) ~= "function" then return false end
    if not (comm and comm.registerCommand and comm.registerP2PCommand and comm.sendP2PMessage
        and comm.broadcast and Map and API.BroadcastMethod and type(getValue) == "function"
        and pinMixin and pinMixin.TEMPLATE_NAME) then
        return false
    end
    local OOC = T.Enums and T.Enums.ROLEPLAY_STATUS and T.Enums.ROLEPLAY_STATUS.OUT_OF_CHARACTER
    local IC = T.Enums and T.Enums.ROLEPLAY_STATUS and T.Enums.ROLEPLAY_STATUS.IN_CHARACTER

    local function warModeOn()
        local u = API.utils
        return (u and u.IsWarModeFeatureEnabled and u.IsWarModeFeatureEnabled()
            and C_PvP and C_PvP.IsWarModeActive and C_PvP.IsWarModeActive()) and true or false
    end

    local function currentUser()
        return T.Player and T.Player.GetCurrentUser and T.Player.GetCurrentUser()
    end

    -- The same answer TRP3's own player scan would give.
    local function shouldAnswer()
        if not getValue(CFG.enabled) then return false end
        local me = currentUser()
        if getValue(CFG.ooc) and me and not me:IsInCharacter() then return false end
        if getValue(CFG.warMode) and not UnitIsPVPSanctuary("player") then
            if UnitIsPVPFreeForAll("player") or UnitIsPVP("player") or warModeOn() then
                return false
            end
        end
        return true
    end

    -- Open-world only: TRP3 answers from inside houses too, which needs its
    -- housing plot tables, and Glyphic's scan is not offered on those maps.
    local function coordinates(mapID)
        if IsInInstance and IsInInstance() then return nil end
        if tonumber(mapID) ~= Map.getPlayerMapID() then return nil end
        local x, y = Map.getPlayerCoordinates()
        if not (x and y) then return nil end
        return string.format("%.3f", x), string.format("%.3f", y)
    end

    local scanner = T.MapScanner(Scan.ID)
    scanner.scanIcon = API.Ellyb and API.Ellyb.Icon and API.Ellyb.Icon(Scan.ICON) or scanner.scanIcon
    scanner.scanOptionText = "Scan for Glyphic speakers"
    scanner.scanTitle = "Glyphic speakers"
    scanner.scanSortIndex = 60
    scanner.dataProviderTemplate = pinMixin.TEMPLATE_NAME

    function scanner:Scan()
        comm.broadcast(Scan.COMMAND, API.BroadcastMethod.World, Map.getDisplayedMapID())
    end

    -- Offered where TRP3 offers its own player scan.
    function scanner:CanScan()
        if not getValue(CFG.enabled) then return false end
        if Map.IsHousingMap and Map.IsHousingMap() then return false end
        if Map.getDisplayedMapID() == Map.getPlayerMapID() then
            local x, y = Map.getPlayerCoordinates()
            if not (x and y) then return false end
        elseif not (TRP3_ClientFeatures and TRP3_ClientFeatures.ChannelBroadcasts) then
            return false
        end
        return true
    end

    comm.registerCommand(Scan.COMMAND, function(sender, mapID)
        if not Map.playerCanSeeTarget(sender) or not shouldAnswer() then return end
        local x, y = coordinates(mapID)
        if not x then return end
        local me = currentUser()
        local status = me and me.GetRoleplayStatus and me:GetRoleplayStatus() or IC
        comm.sendP2PMessage(sender, Scan.COMMAND, x, y, tostring(warModeOn()),
            tostring(status or ""), Scan.Tongue())
    end)

    comm.registerP2PCommand(Scan.COMMAND, function(sender, x, y, war, status, tongue)
        war = (war == "true")
        status = tonumber(status) or IC
        local checkWar
        if API.utils and API.utils.IsWarModeFeatureEnabled
            and API.utils.IsWarModeFeatureEnabled() and not getValue(CFG.showWarModes) then
            checkWar = war
        end
        if not Map.playerCanSeeTarget(sender, checkWar, Map.getDisplayedMapID()) then return end
        -- TRP3's "show out-of-character players" option: false means in character only.
        if status == OOC and getValue(CFG.showOOC) == false then return end
        scanner:OnScanDataReceived(sender, x, y, {
            hasWarModeActive = war,
            roleplayStatus = status,
            glyphicTongue = type(tongue) == "string" and tongue or "",
        })
    end)

    -- Only pins from this scan carry glyphicTongue; TRP3's own are untouched.
    local base = pinMixin.GetDisplayDataFromPoiInfo
    if type(base) == "function" then
        pinMixin.GetDisplayDataFromPoiInfo = function(self, poiInfo)
            local data = base(self, poiInfo)
            if type(data) == "table" and type(poiInfo) == "table" and poiInfo.glyphicTongue ~= nil then
                data.playerNameFancy = Scan.PinLine(data.playerNameFancy or data.playerName or "",
                    poiInfo.glyphicTongue)
            end
            return data
        end
    end

    installed = true
    Scan._scanner = scanner
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local ok = pcall(Scan.Install)
    if not ok then installed = false end
end)
