--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Compat.lua
    Cross-client compatibility shim. Loaded FIRST (before every other file).

    One addon, many clients: this file smooths over the API differences across
    the modern engine -- Retail "Midnight", Forever, and the Classic flavors
    (Cata / Mists / Vanilla).

    Everything here is *feature-detected*, never version-hardcoded, so it keeps
    working on future patches. The rest of the addon only ever talks to
    ns.Compat, never to the raw client APIs that move around.

    What it abstracts:
      * addon metadata            (GetAddOnMetadata vs C_AddOns.GetAddOnMetadata)
      * addon messaging           (SendAddonMessage vs C_ChatInfo.*)
      * group checks              (GetNumRaidMembers vs IsInRaid, etc.)
      * options panel register/open (Settings.*, plus our standalone window)
      * widgets                   (portable checkbox / slider / dropdown that
                                    avoid the removed UIDropDownMenu + template
                                    churn on retail)
---------------------------------------------------------------------------]]

local ADDON, ns = ...

local Compat = {}
ns.Compat = Compat

--=========================================================================--
--  A stopwatch, for waits that only happen in the game.
--=========================================================================--
-- Opening the line browser takes a reported fifteen seconds in play and four
-- milliseconds under the test harness, frames and all. That gap is the whole
-- problem: whatever costs the seconds is something the client does for real
-- and a stub does for free, so reading the code cannot find it and timing it
-- outside the game cannot either. This records what the client's own clock
-- says, and `/toa timings` reads it back.
--
-- Left in rather than torn out once the cause is found: a catalogue that is
-- about to grow from ninety-three speakers to several thousand will get slow
-- again, and the next time it does, the measurement should already be there.
local marks, markOrder = {}, {}

function Compat.Mark(label, ms)
    local m = marks[label]
    if not m then
        m = { n = 0, total = 0, worst = 0 }
        marks[label] = m
        markOrder[#markOrder + 1] = label
    end
    m.n = m.n + 1
    m.total = m.total + ms
    if ms > m.worst then m.worst = ms end
end

-- debugprofilestop is the client's millisecond clock. Outside the game there
-- is no such thing, so the call is passed straight through rather than timed
-- against a substitute that would measure the wrong machine.
function Compat.Timed(label, fn, ...)
    if type(debugprofilestop) ~= "function" then return fn(...) end
    local t0 = debugprofilestop()
    local a, b, c = fn(...)
    Compat.Mark(label, debugprofilestop() - t0)
    return a, b, c
end

-- Worst, not mean: a fifteen-second wait that happens once is invisible in an
-- average taken over a dozen fast reopens, and the once is the complaint.
function Compat.Timings()
    local out = {}
    for _, label in ipairs(markOrder) do
        local m = marks[label]
        out[#out + 1] = { label = label, count = m.n, total = m.total, worst = m.worst }
    end
    return out
end

--=========================================================================--
--  Client tier detection (feature-detected).
--=========================================================================--
-- The Settings API exists on Retail, Forever and all current Classic flavors.
-- Still probed rather than assumed, so a client that lacks it degrades to the
-- standalone window instead of erroring.
Compat.hasSettingsAPI = (type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function")

-- Interface build number, e.g. 120100 (Midnight) or 16001 (Forever).
do
    local _, _, _, iface = GetBuildInfo()
    Compat.interface = tonumber(iface) or 0
end

--=========================================================================--
--  Addon metadata.
--=========================================================================--
local rawGetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
function Compat.GetAddOnMetadata(name, field)
    if rawGetMeta then return rawGetMeta(name, field) end
    return nil
end

--=========================================================================--
--  Spell info.
--=========================================================================--
-- GetSpellInfo moved into C_Spell in 11.0 (returning a table instead of a
-- tuple) and the bare global is gone on Midnight, while the Classic flavors
-- still only have the global. Returns name, icon -- or nil for an unknown id.
local rawSpellInfo = C_Spell and C_Spell.GetSpellInfo
function Compat.GetSpellInfo(spellID)
    if not spellID then return nil end
    if rawSpellInfo then
        local ok, info = pcall(rawSpellInfo, spellID)
        if ok and type(info) == "table" and info.name then
            return info.name, info.iconID
        end
        return nil
    end
    if type(GetSpellInfo) == "function" then
        local ok, name, _, icon = pcall(GetSpellInfo, spellID)
        if ok and name then return name, icon end
    end
    return nil
end

--=========================================================================--
--  Spellbook enumeration (castable spell names for the player + pet).
--=========================================================================--
-- Modern clients (11.0+) expose C_SpellBook.*; Classic flavors still use the
-- GetNumSpellTabs / GetSpellBookItem* globals. Feature-detected, never gated on
-- interface number (Forever reports 16001 but needs the modern path).

local modernNumSkillLines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
local modernSkillLineInfo = C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo
local modernItemInfo = C_SpellBook and C_SpellBook.GetSpellBookItemInfo
local modernHasPetSpells = C_SpellBook and C_SpellBook.HasPetSpells

local classicNumTabs = type(GetNumSpellTabs) == "function" and GetNumSpellTabs
local classicTabInfo = type(GetSpellTabInfo) == "function" and GetSpellTabInfo
local classicItemInfo = type(GetSpellBookItemInfo) == "function" and GetSpellBookItemInfo
local classicItemName = type(GetSpellBookItemName) == "function" and GetSpellBookItemName
local classicHasPetSpells = type(HasPetSpells) == "function" and HasPetSpells

local hasModernSpellbook = (
    type(modernNumSkillLines) == "function"
    and type(modernSkillLineInfo) == "function"
    and type(modernItemInfo) == "function"
)
local hasClassicSpellbook = (
    type(classicNumTabs) == "function"
    and type(classicTabInfo) == "function"
    and type(classicItemInfo) == "function"
    and type(classicItemName) == "function"
)

function Compat.HasSpellbookAPI()
    return hasModernSpellbook or hasClassicSpellbook
end

local function trimSpellName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if not name or name == "" then return nil end
    return name
end

local function collectModernSpellNames(seen, out)
    local bankPlayer, bankPet
    local typeFuture, typeFlyout
    if type(Enum) == "table" then
        if type(Enum.SpellBookSpellBank) == "table" then
            bankPlayer = Enum.SpellBookSpellBank.Player
            bankPet = Enum.SpellBookSpellBank.Pet
        end
        if type(Enum.SpellBookItemType) == "table" then
            typeFuture = Enum.SpellBookItemType.FutureSpell
            typeFlyout = Enum.SpellBookItemType.Flyout
        end
    end
    if bankPlayer == nil then return false end

    local okNum, numLines = pcall(modernNumSkillLines)
    if not okNum or type(numLines) ~= "number" or numLines < 1 then return false end

    local counted = 0
    for i = 1, numLines do
        local okLine, info = pcall(modernSkillLineInfo, i)
        if okLine and type(info) == "table" then
            local offset = info.itemIndexOffset
            local count = info.numSpellBookItems
            if type(offset) == "number" and type(count) == "number" and count > 0 then
                for j = offset + 1, offset + count do
                    local okItem, item = pcall(modernItemInfo, j, bankPlayer)
                    if okItem and type(item) == "table" and type(item.name) == "string" then
                        if item.isPassive then
                            -- passive; never fires a cast event
                        elseif item.isOffSpec then
                            -- off-spec placeholder
                        elseif typeFuture and item.itemType == typeFuture then
                            -- unlearned future rank
                        elseif typeFlyout and item.itemType == typeFlyout then
                            -- flyout names are truncated ("Call " for Call Pet) -- useless
                        else
                            local name = trimSpellName(item.name)
                            if name and not seen[name] then
                                seen[name] = true
                                out[#out + 1] = name
                                counted = counted + 1
                            end
                        end
                    end
                end
            end
        end
    end

    if bankPet and type(modernHasPetSpells) == "function" then
        local okPet, numPet = pcall(modernHasPetSpells)
        if okPet and type(numPet) == "number" and numPet > 0 then
            for j = 1, numPet do
                local okItem, item = pcall(modernItemInfo, j, bankPet)
                if okItem and type(item) == "table" and type(item.name) == "string" then
                    if item.isPassive then
                    elseif typeFuture and item.itemType == typeFuture then
                    elseif typeFlyout and item.itemType == typeFlyout then
                    else
                        local name = trimSpellName(item.name)
                        if name and not seen[name] then
                            seen[name] = true
                            out[#out + 1] = name
                            counted = counted + 1
                        end
                    end
                end
            end
        end
    end

    return true, counted
end

local function collectClassicSpellNames(seen, out)
    local okTabs, numTabs = pcall(classicNumTabs)
    if not okTabs or type(numTabs) ~= "number" or numTabs < 1 then return false end

    local counted = 0
    for i = 1, numTabs do
        local okTab, _, _, offset, numSlots = pcall(classicTabInfo, i)
        if okTab and type(offset) == "number" and type(numSlots) == "number" and numSlots > 0 then
            for j = offset + 1, offset + numSlots do
                local okInfo, spellType = pcall(classicItemInfo, j, "spell")
                if okInfo and spellType ~= "FUTURESPELL" and spellType ~= "FLYOUT" then
                    local okName, name = pcall(classicItemName, j, "spell")
                    if okName then
                        name = trimSpellName(name)
                        if name and not seen[name] then
                            seen[name] = true
                            out[#out + 1] = name
                            counted = counted + 1
                        end
                    end
                end
            end
        end
    end

    if type(classicHasPetSpells) == "function" then
        local okPet, numPet = pcall(classicHasPetSpells)
        if okPet and type(numPet) == "number" and numPet > 0 then
            for j = 1, numPet do
                local okInfo, spellType = pcall(classicItemInfo, j, "pet")
                if okInfo and spellType ~= "FUTURESPELL" and spellType ~= "FLYOUT" then
                    local okName, name = pcall(classicItemName, j, "pet")
                    if okName then
                        name = trimSpellName(name)
                        if name and not seen[name] then
                            seen[name] = true
                            out[#out + 1] = name
                            counted = counted + 1
                        end
                    end
                end
            end
        end
    end

    return true, counted
end

function Compat.GetSpellbookNames()
    if not Compat.HasSpellbookAPI() then return nil end

    local seen = {}
    local names = {}

    if hasModernSpellbook then
        local ok = collectModernSpellNames(seen, names)
        if not ok then return nil end
        if #names > 0 then
            table.sort(names)
            return names
        end
        -- Modern scan succeeded but found nothing; without a classic fallback the
        -- caller cannot tell "no spells" from "API mismatch", so return nil.
        if not hasClassicSpellbook then return nil end
    end

    if hasClassicSpellbook then
        local ok = collectClassicSpellNames(seen, names)
        if not ok then return nil end
        table.sort(names)
        return names
    end

    return nil
end

--=========================================================================--
--  Addon messaging (whisper/party/raid decode payloads).
--=========================================================================--
local rawSendAddon = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local rawRegPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

Compat.canSendAddonMessage = (type(rawSendAddon) == "function")

function Compat.SendAddonMessage(prefix, message, channel, target)
    if type(rawSendAddon) ~= "function" then return end
    if channel == "WHISPER" and target then
        rawSendAddon(prefix, message, channel, target)
    else
        rawSendAddon(prefix, message, channel)
    end
end

function Compat.RegisterAddonMessagePrefix(prefix)
    if type(rawRegPrefix) == "function" then
        pcall(rawRegPrefix, prefix)
    end
end

-- Whether an addon message can be sent to whoever happens to be standing
-- nearby. SAY and YELL carry addon traffic on the Classic flavors only: they
-- were granted there in 1.13.3 in the same change that took CHANNEL away, and
-- never came to Retail, where nothing an addon sends reaches a player it is
-- not grouped or guilded with.
--
-- Asked by project rather than by interface number. Every flavor's build
-- number climbs, so there is no threshold that keeps telling them apart.
-- Unknown counts as "cannot", which costs a feature rather than spraying a
-- chat type the server may object to.
Compat.hasProximityAddonMessages =
    (type(WOW_PROJECT_ID) == "number" and type(WOW_PROJECT_MAINLINE) == "number"
        and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) or false

--=========================================================================--
--  Chat messaging lockdown (Midnight).
--=========================================================================--
-- Midnight refuses chat sent from addon code during raid encounters, Mythic+
-- and rated PvP -- the point being that a keypress may talk but a script may
-- not. Anything we generate ourselves (cast phrases, /toa say) has to ask first
-- and fall back to a local-only print, or the send is simply swallowed.
-- Absent on the older Classic flavors, where no such lockdown exists.
local rawChatLockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown

function Compat.InChatLockdown()
    if type(rawChatLockdown) ~= "function" then return false end
    local ok, restricted = pcall(rawChatLockdown)
    return ok and restricted == true
end

--=========================================================================--
--  Group state.
--=========================================================================--
function Compat.InRaid()
    if type(IsInRaid) == "function" then return IsInRaid() end
    if type(GetNumRaidMembers) == "function" then return GetNumRaidMembers() > 0 end
    return false
end

function Compat.InParty()
    -- "In a (non-raid) party" — used to decide where to mirror decode payloads.
    if type(IsInGroup) == "function" then
        return IsInGroup() and not Compat.InRaid()
    end
    if type(GetNumPartyMembers) == "function" then return GetNumPartyMembers() > 0 end
    return false
end

--=========================================================================--
--  Solid-color textures.
--=========================================================================--
function Compat.SolidTexture(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture(r, g, b, a or 1)
    end
end

-- 1px edge border drawn on a frame's own BORDER layer (never covers content).
-- Avoids SetBackdrop / BackdropTemplate, so it is immune to template churn.
function Compat.AddBorder(frame, r, g, b, a)
    local function edge()
        local t = frame:CreateTexture(nil, "BORDER")
        Compat.SolidTexture(t, r, g, b, a)
        return t
    end
    local top = edge();    top:SetPoint("TOPLEFT");       top:SetPoint("TOPRIGHT");       top:SetHeight(1)
    local bottom = edge(); bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    local left = edge();   left:SetPoint("TOPLEFT");      left:SetPoint("BOTTOMLEFT");    left:SetWidth(1)
    local right = edge();  right:SetPoint("TOPRIGHT");    right:SetPoint("BOTTOMRIGHT");   right:SetWidth(1)

    -- Handed back so a border can be recolored later to signal state (the
    -- floating bar goes green/red for in/out of character). Callers that just
    -- want a static frame can ignore the return, as most do.
    local edges = { top, bottom, left, right }
    return {
        edges = edges,
        SetColor = function(self, nr, ng, nb, na)
            for i = 1, #self.edges do
                Compat.SolidTexture(self.edges[i], nr, ng, nb, na)
            end
        end,
    }
end

--=========================================================================--
--  Options panel: create / register / open.
--  Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory /
--  RegisterCanvasLayoutSubcategory + Settings.OpenToCategory.
--=========================================================================--
ns._optionCategories = ns._optionCategories or {}

function Compat.CreateOptionsPanel(globalName)
    -- The Settings canvas reparents the frame anyway, so UIParent is fine.
    local f = CreateFrame("Frame", globalName, UIParent)
    f:Hide()
    return f
end

-- Wrap a panel's contents in a vertical scroll region so a tall layout never
-- spills outside the options window. Returns a `content` frame to parent/anchor
-- everything to (instead of the panel itself). The content frame gets a
-- :SetContentHeight(px) method; call it once the layout's total height is known.
-- A slim scrollbar appears only when the content is taller than the viewport.
function Compat.CreateScrollContent(panel, contentHeight)
    local BARW = 16

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(BARW + 6), 0)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, contentHeight or 600)
    scroll:SetScrollChild(content)

    -- Vertical scrollbar: a plain slider with a solid thumb (no template needed,
    -- so it is immune to retail's template churn).
    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BARW)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    bar:SetMinMaxValues(0, 1)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    Compat.SolidTexture(track, 1, 1, 1, 0.06)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(BARW, 48)
    Compat.SolidTexture(thumb, 0.55, 0.5, 0.72, 0.9)
    bar:SetThumbTexture(thumb)

    local syncing = false
    local function updateRange()
        local vh = scroll:GetHeight() or 0
        local ch = content:GetHeight() or 0
        local range = ch - vh
        if range < 1 then range = 0 end
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        local v = scroll:GetVerticalScroll()
        if v > range then
            syncing = true
            scroll:SetVerticalScroll(range)
            bar:SetValue(range)
            syncing = false
        end
    end

    bar:SetScript("OnValueChanged", function(self, value)
        if syncing then return end
        syncing = true
        scroll:SetVerticalScroll(value)
        syncing = false
    end)
    scroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then content:SetWidth(w) end
        updateRange()
    end)
    scroll:SetScript("OnScrollRangeChanged", function() updateRange() end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local _, maxv = bar:GetMinMaxValues()
        local v = self:GetVerticalScroll() - delta * 32
        if v < 0 then v = 0 elseif v > maxv then v = maxv end
        syncing = true
        self:SetVerticalScroll(v)
        bar:SetValue(v)
        syncing = false
    end)

    panel._scroll, panel._content, panel._scrollbar = scroll, content, bar
    function content:SetContentHeight(h)
        self:SetHeight(h)
        updateRange()
    end
    return content
end

function Compat.RegisterOptionsPanel(frame, name, parentName)
    frame.name = name
    if parentName then frame.parent = parentName end

    if Compat.hasSettingsAPI then
        local category
        local parentCategory = parentName and ns._optionCategories[parentName]
        if parentCategory and Settings.RegisterCanvasLayoutSubcategory then
            category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, name)
        else
            category = Settings.RegisterCanvasLayoutCategory(frame, name)
            if category and Settings.RegisterAddOnCategory then
                Settings.RegisterAddOnCategory(category)
            end
        end
        ns._optionCategories[name] = category
        frame._settingsCategory = category
    end
end

-- A single, shared, draggable window that hosts ONE options panel at a time
-- (main panel, learned, trainer, ...). The Language Trainer always uses this, and
-- it also backs any panel we can't hand to the Settings tree. Navigation model:
--   * A panel with no frame._backAction is the "home" and shows a close (X).
--   * A panel that defines frame._backAction (a function) shows a Back button
--     that runs it (returning to the home panel) instead of closing.
-- The hosted panel is returned to its original parent when swapped out or closed.
local sharedWindow

local function detachCurrent(win)
    local cur = win._current
    if not cur then return end
    cur:SetParent(cur._originalParent or UIParent)
    cur:ClearAllPoints()
    cur:Hide()
    win._current = nil
end

local function ensureStandaloneWindow()
    if sharedWindow then return sharedWindow end

    local win = CreateFrame("Frame", "TonguesOfAzerothWindow", UIParent)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetSize(600, 600)
    win:SetPoint("CENTER")
    win:EnableMouse(true)
    win:SetMovable(true)
    if win.SetClampedToScreen then win:SetClampedToScreen(true) end

    local bg = win:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0, 0, 0, 0.92)
    Compat.AddBorder(win, 0.5, 0.5, 0.5, 0.9)

    local titlebar = CreateFrame("Frame", nil, win)
    titlebar:SetPoint("TOPLEFT", 0, 0)
    titlebar:SetPoint("TOPRIGHT", -100, 0)   -- room for the back + close buttons
    titlebar:SetHeight(26)
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function() win:StartMoving() end)
    titlebar:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local tbg = titlebar:CreateTexture(nil, "ARTWORK")
    tbg:SetAllPoints()
    Compat.SolidTexture(tbg, 0.12, 0.10, 0.16, 1)
    local ttext = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ttext:SetPoint("LEFT", 10, 0)
    win.titleText = ttext

    -- Close (X) button - shown on the home/main panel.
    local close = CreateFrame("Button", nil, win)
    close:SetSize(28, 26)
    close:SetPoint("TOPRIGHT", -2, -1)
    close:SetFrameLevel(win:GetFrameLevel() + 5)   -- above the drag title bar
    close:RegisterForClicks("LeftButtonUp")
    local cx = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cx:SetPoint("CENTER", 0, 0)
    cx:SetText("X")
    cx:SetTextColor(1, 0.82, 0)
    local chl = close:CreateTexture(nil, "HIGHLIGHT")
    chl:SetAllPoints()
    Compat.SolidTexture(chl, 1, 1, 1, 0.22)
    close:SetScript("OnEnter", function() cx:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(1, 0.82, 0) end)
    close:SetScript("OnClick", function() win:Hide() end)
    win.closeBtn = close

    -- Back button - shown on sub-panels (in addition to the close X); runs the
    -- current panel's _backAction. Sits just left of the close button.
    local back = CreateFrame("Button", nil, win)
    back:SetSize(64, 22)
    back:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, -1)
    back:SetFrameLevel(win:GetFrameLevel() + 5)
    back:RegisterForClicks("LeftButtonUp")
    local bbg = back:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    Compat.SolidTexture(bbg, 0.18, 0.16, 0.24, 1)
    Compat.AddBorder(back, 0.5, 0.45, 0.7, 0.9)
    local btext = back:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btext:SetPoint("CENTER", 0, 0)
    btext:SetText("< Back")
    local bhl = back:CreateTexture(nil, "HIGHLIGHT")
    bhl:SetAllPoints()
    Compat.SolidTexture(bhl, 1, 1, 1, 0.15)
    back:SetScript("OnClick", function()
        local cur = win._current
        local action = cur and cur._backAction
        if action then action() end
        -- If the action didn't swap the hosted panel (e.g. modern clients open
        -- the native Settings panel instead of reusing this window), close this
        -- window so it doesn't linger behind the settings UI.
        if win._current == cur then win:Hide() end
    end)
    win.backBtn = back

    -- Escape closes the window, like other WoW dialogs.
    local wname = win:GetName()
    if wname then tinsert(UISpecialFrames, wname) end

    win:SetScript("OnHide", function() detachCurrent(win) end)

    sharedWindow = win
    return win
end

function Compat.ShowStandalone(frame)
    if not frame then return end
    local win = ensureStandaloneWindow()

    if win._current and win._current ~= frame then
        detachCurrent(win)
    end

    frame._originalParent = frame._originalParent or frame:GetParent()
    frame:SetParent(win)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 10, -30)
    frame:SetPoint("BOTTOMRIGHT", -10, 10)
    frame:Show()
    win._current = frame

    win.titleText:SetText(frame.name or "Options")
    -- The close (X) is always available so any panel can be dismissed. Sub-panels
    -- (those with a _backAction) additionally get a Back button beside it.
    win.closeBtn:Show()
    if frame._backAction then win.backBtn:Show() else win.backBtn:Hide() end

    win:Show()
    if win.Raise then win:Raise() end
    if type(frame.refresh) == "function" then frame.refresh() end
end

function Compat.OpenOptionsPanel(frame)
    if not frame then return end
    if Compat.hasSettingsAPI and frame._settingsCategory then
        Settings.OpenToCategory(frame._settingsCategory:GetID())
        return
    end
    -- No Settings category to open to (an unregistered panel, or a client without
    -- the Settings API): fall back to our own guaranteed standalone window.
    Compat.ShowStandalone(frame)
end

--=========================================================================--
--  Widgets. Built from base frame types + universally-available textures so
--  they render identically on every client (no template churn, no removed
--  UIDropDownMenu).
--=========================================================================--

-- Checkbox with a label to its right. Returns the CheckButton; read/write via
-- native :GetChecked() / :SetChecked(). The label FontString is at .labelText.
function Compat.CreateCheckbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    fs:SetText(label or "")
    cb.labelText = fs
    return cb
end

-- Horizontal slider with a title, min/max captions, and a live value caption.
-- Returns the Slider; the value caption FontString is at .valueText.
function Compat.CreateSlider(parent, minV, maxV, step, titleText, lowText, highText)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetHeight(16)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(6)
    Compat.SolidTexture(track, 1, 1, 1, 0.18)

    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(20, 20) end

    if titleText then
        local title = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("BOTTOM", s, "TOP", 0, 3)
        title:SetText(titleText)
        s.titleText = title
    end
    if lowText then
        local low = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
        low:SetText(lowText)
    end
    if highText then
        local high = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
        high:SetText(highText)
    end

    local val = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOP", s, "BOTTOM", 0, -2)
    s.valueText = val

    -- NOTE for callers: the frame itself is only 16px tall, but the title sits
    -- above it and the low/value/high labels hang ~16px BELOW it, outside the
    -- frame's bounds. Anything anchored to the slider's BOTTOM needs roughly
    -- -30 or more of clearance or it will render on top of those labels.
    return s
end

--=========================================================================--
--  Favorite star art
--  Blizzard's own favorite star -- the one on Auction House searches and
--  profession recipes -- is a texture atlas, and atlases both require an API
--  that older clients lack and have been renamed between expansions. So probe
--  for whichever the running client actually has rather than hardcoding a name,
--  the same way everything else in this file is feature-detected. The last
--  resort is the cooldown starburst, which has shipped since Vanilla.
--=========================================================================--
local STAR_ATLAS_ON = {
    "auctionhouse-icon-favorite",   -- AH search favorites (8.3+)
    "professions-icon-favorites",   -- profession recipe list (10.0+)
    "collections-icon-favorites",
    "PetJournal-FavoritesIcon",
    "friendslist-favorite",
}
local STAR_ATLAS_OFF = {
    "auctionhouse-icon-favorite-empty",
    "professions-icon-favorites-off",
}
local STAR_FALLBACK = "Interface\\Cooldown\\star4"

local starOn, starOff, starResolved

local function firstAtlas(list)
    local info = (C_Texture and C_Texture.GetAtlasInfo) or _G.GetAtlasInfo
    if not info then return nil end
    for i = 1, #list do
        local ok, res = pcall(info, list[i])
        if ok and res then return list[i] end
    end
    return nil
end

local function resolveStars()
    if starResolved then return end
    starResolved = true
    starOn = firstAtlas(STAR_ATLAS_ON)
    starOff = firstAtlas(STAR_ATLAS_OFF)
end

-- Paint `tex` as a favorite star, filled or empty. With no hollow atlas to hand
-- we dim and desaturate the filled one, which reads the same at 16px.
function Compat.SetStar(tex, filled)
    resolveStars()
    local canAtlas = tex.SetAtlas ~= nil
    local function desaturate(on)
        if tex.SetDesaturated then tex:SetDesaturated(on) end
    end

    if filled then
        if canAtlas and starOn then
            tex:SetAtlas(starOn)
            tex:SetVertexColor(1, 1, 1) -- Blizzard's star is already gold
        else
            tex:SetTexture(STAR_FALLBACK)
            tex:SetVertexColor(1, 0.82, 0)
        end
        desaturate(false)
        tex:SetAlpha(1)
    elseif canAtlas and starOff then
        tex:SetAtlas(starOff)
        tex:SetVertexColor(1, 1, 1)
        desaturate(false)
        tex:SetAlpha(0.9)
    elseif canAtlas and starOn then
        tex:SetAtlas(starOn)
        tex:SetVertexColor(1, 1, 1)
        desaturate(true)
        tex:SetAlpha(0.35)
    else
        tex:SetTexture(STAR_FALLBACK)
        tex:SetVertexColor(0.65, 0.65, 0.65)
        desaturate(false)
        tex:SetAlpha(0.4)
    end
end

-- Portable dropdown. API:
--   dd:SetItems({ {text=, value=}, ... })   (an item with header=true is an
--                                            inert section label)
--   dd:SetSelected(value, text)
--   dd:GetValue()
--   dd:Reopen()                             (redraw an open menu in place)
--   dd.onSelect  = function(value) ... end  (called on left-click)
--   dd.onAltClick = function(value) ... end (right-click; leaves the menu open
--                                            and the selection alone)
--   dd.onToggle  = function(value) ... end  (clicking a row's star; set this and
--                                            give items a boolean `toggle` to
--                                            draw one)
-- One click-catcher shared by every dropdown menu.
--
-- A menu you can only dismiss by clicking the dropdown again is a menu you get
-- stuck in -- every other instinct (click the panel, click another control,
-- click the world) leaves it hanging over the UI. The menus are parented to
-- UIParent so they survive being opened inside a ScrollFrame, which also means
-- nothing is positioned to notice the click that ought to close them.
--
-- Full-screen, one strata below the menus themselves: a click inside the menu
-- still reaches the menu, and a click anywhere else lands here. That click is
-- consumed rather than passed through, which is how Blizzard's own dropdowns
-- behave -- the first click outside dismisses, and only then does the UI take
-- clicks again.
local dropdownCatcher, openDropdownMenu

local function hideDropdownCatcher()
    openDropdownMenu = nil
    if dropdownCatcher then dropdownCatcher:Hide() end
end

local function showDropdownCatcher(menu)
    if not dropdownCatcher then
        dropdownCatcher = CreateFrame("Button", nil, UIParent)
        dropdownCatcher:SetAllPoints(UIParent)
        dropdownCatcher:SetFrameStrata("FULLSCREEN")
        dropdownCatcher:EnableMouse(true)
        dropdownCatcher:RegisterForClicks("AnyUp")
        dropdownCatcher:SetScript("OnClick", function()
            if openDropdownMenu then openDropdownMenu:Hide() end
            hideDropdownCatcher()
        end)
        dropdownCatcher:Hide()
    end
    -- Opening a second menu closes the first, so only one is ever live.
    if openDropdownMenu and openDropdownMenu ~= menu then openDropdownMenu:Hide() end
    openDropdownMenu = menu
    dropdownCatcher:Show()
end

-- Fitting a menu to its entries means measuring text, and measuring text is a
-- layout the client performs there and then. That is cheap across a dozen
-- entries and ruinous across thousands, so the number of measurements is held
-- fixed instead of growing with the list: only the longest entries can be the
-- widest one, and length is free to read.
--
-- A handful are kept rather than just one because length and width disagree at
-- the margin -- "WWW" is wider than "iiiiii" and shorter -- and a dozen covers
-- that with room to spare. The cost of guessing low is a menu a few pixels
-- narrower than ideal, not a wrong answer.
local FIT_CANDIDATES = 12
local fitIdx, fitLen = {}, {}

local function longestEntries(items, total)
    local n = 0
    for i = 1, total do
        local len = #(items[i].text or "")
        if n < FIT_CANDIDATES or len > fitLen[n] then
            local pos = (n < FIT_CANDIDATES) and (n + 1) or FIT_CANDIDATES
            while pos > 1 and fitLen[pos - 1] < len do
                fitLen[pos], fitIdx[pos] = fitLen[pos - 1], fitIdx[pos - 1]
                pos = pos - 1
            end
            fitLen[pos], fitIdx[pos] = len, i
            if n < FIT_CANDIDATES then n = n + 1 end
        end
    end
    return n
end

function Compat.CreateDropdown(parent, width)
    local dd = CreateFrame("Button", nil, parent)
    dd:SetSize(width or 200, 26)

    local bg = dd:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0, 0, 0, 0.55)

    -- 1px edge border drawn on the frame's own BORDER layer (never covers content).
    local function addBorder(frame, r, g, b, a)
        local function edge()
            local t = frame:CreateTexture(nil, "BORDER")
            Compat.SolidTexture(t, r, g, b, a)
            return t
        end
        local top = edge();    top:SetPoint("TOPLEFT");       top:SetPoint("TOPRIGHT");       top:SetHeight(1)
        local bottom = edge(); bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
        local left = edge();   left:SetPoint("TOPLEFT");      left:SetPoint("BOTTOMLEFT");    left:SetWidth(1)
        local right = edge();  right:SetPoint("TOPRIGHT");    right:SetPoint("BOTTOMRIGHT");   right:SetWidth(1)
    end
    addBorder(dd, 0.5, 0.5, 0.5, 0.7)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    -- A dropdown is one line tall. Left to wrap, a long selection lays a second
    -- line over whatever sits beneath the button.
    if label.SetWordWrap then label:SetWordWrap(false) end
    dd.label = label

    local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -6, -1)
    arrow:SetText("v")

    local hl = dd:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Compat.SolidTexture(hl, 1, 1, 1, 0.12)

    dd.items = {}
    dd.selectedValue = nil

    local menu
    local function closeMenu()
        if menu then menu:Hide() end
        if openDropdownMenu == menu then hideDropdownCatcher() end
    end

    -- `keepOffset` reopens at a given scroll position instead of jumping to the
    -- selection, so a right-click that rewrites the list (see dd:Reopen) doesn't
    -- yank the menu out from under the cursor.
    local function openMenu(keepOffset)
        -- Timed in steps rather than as a whole. The total only says the menu
        -- was slow, which is the complaint, not the answer; the steps are very
        -- different kinds of work -- building frames the once, measuring text,
        -- drawing rows -- and which one holds the seconds decides what to fix.
        -- A list of a dozen entries being as slow as one of thousands already
        -- rules the per-entry work out, so the fixed costs need their own
        -- numbers before anything else is changed on a hunch.
        local lastStep = (type(debugprofilestop) == "function") and debugprofilestop() or nil
        local function step(label)
            if not lastStep then return end
            local now = debugprofilestop()
            Compat.Mark("dropdown: " .. label, now - lastStep)
            lastStep = now
        end

        if not menu then
            -- Parented to UIParent (not dd) so the popup is never clipped when the
            -- dropdown lives inside a ScrollFrame; still anchored to dd below.
            menu = CreateFrame("Frame", nil, UIParent)
            -- Published so the popup can be inspected once it exists. It is
            -- built lazily and otherwise unreachable, which makes everything
            -- about how a row is drawn impossible to check.
            dd.menu = menu
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetToplevel(true)
            menu:EnableMouse(true)
            local mbg = menu:CreateTexture(nil, "BACKGROUND")
            mbg:SetAllPoints()
            Compat.SolidTexture(mbg, 0, 0, 0, 0.94)
            addBorder(menu, 0.5, 0.5, 0.5, 0.8)
            menu.buttons = {}
        end
        step("build the menu frame")

        local items = dd.items
        local rowH = 20
        local maxVisible = 14
        local total = #items
        local visible = math.max(1, math.min(total, maxVisible))
        local maxOffset = math.max(0, total - visible)
        -- The menu may be wider than the button it drops from. A dropdown is
        -- sized to fit a row of controls; its entries are sized by whatever the
        -- longest one says, and squeezing those into the button's width is what
        -- makes a list unreadable. Callers set dd.menuWidth when they know the
        -- list is wider than the space the button gets.
        local w = math.max(dd:GetWidth(), tonumber(dd.menuWidth) or 0)
        -- Or measure the entries and fit them. A caller that knows its list is
        -- wide can say how wide; a caller whose entries are written at build
        -- time -- "Blood Elf Demon Hunter - masculine voice (115)" -- cannot,
        -- and guessing a number means either a truncated list or a menu padded
        -- out for a label that is not there. The scratch string is kept on the
        -- menu and reused, and only a bounded sample of entries is measured, so
        -- this costs the same whether the list holds ten names or ten thousand.
        if dd.menuFitItems then
            -- Underscored, per the rule for anything that has to read back as
            -- nil before it is set: a plain field name comes back from the
            -- test harness as a truthy no-op and this skips the creation.
            local probe = menu.__probe
            if not probe then
                probe = menu:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                if probe and probe.Hide then probe:Hide() end
                menu.__probe = probe
            end
            -- Measured once per list, not once per open: reopening the same
            -- menu asks the same question of the same strings, and the answer
            -- cannot have moved. SetItems drops this when the list changes.
            local widest = dd._fitWidth
            if not widest then
                widest = 0
                if probe and probe.GetStringWidth then
                    local n = longestEntries(items, total)
                    for c = 1, n do
                        probe:SetText(items[fitIdx[c]].text or "")
                        local sw = probe:GetStringWidth() or 0
                        if sw > widest then widest = sw end
                    end
                end
                -- Remembered only once it has measured something. A font
                -- string reports nothing until its frame has been drawn, and
                -- the menu is not shown until the end of this function, so the
                -- first open can measure a row of zeroes. Caching that would
                -- pin the menu to the button's width for the rest of the
                -- session; leaving it uncached costs one more pass and lets
                -- the next open get the real answer.
                if widest > 0 then dd._fitWidth = widest end
            end
            -- 8px of padding each side, plus room for the favourite star.
            -- Capped at the screen, since a menu wider than the window is a
            -- worse answer to a long name than cutting it off.
            local screen = UIParent and UIParent.GetWidth and UIParent:GetWidth()
            local cap = (screen and screen > 160) and (screen - 80) or 600
            if widest > 0 then w = math.max(w, math.min(widest + 40, cap)) end
        end
        step("fit the width to the entries")
        menu:SetWidth(w)
        menu:SetHeight(visible * rowH + 8)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)

        -- Open scrolled so the current selection is visible.
        local offset = keepOffset or 0
        if not keepOffset then
            for i = 1, total do
                if items[i].value == dd.selectedValue then
                    offset = i - math.floor(visible / 2) - 1
                    break
                end
            end
        end
        if offset < 0 then offset = 0 end
        if offset > maxOffset then offset = maxOffset end
        menu.offset = offset
        menu.total = total -- so Reopen can tell how much the list grew

        local function render()
            for i = 1, #menu.buttons do menu.buttons[i]:Hide() end
            for slot = 1, visible do
                local item = items[menu.offset + slot]
                if item then
                    local b = menu.buttons[slot]
                    if not b then
                        b = CreateFrame("Button", nil, menu)
                        b:SetHeight(rowH)
                        b:EnableMouseWheel(true)
                        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        t:SetPoint("LEFT", 8, 0)
                        t:SetPoint("RIGHT", -8, 0)
                        t:SetJustifyH("LEFT")
                        -- Rows are a fixed height and butt up against each
                        -- other, so an entry allowed to wrap does not push the
                        -- next one down -- it draws straight over it, and the
                        -- whole list turns to overlapping mush.
                        if t.SetWordWrap then t:SetWordWrap(false) end
                        b.text = t
                        local h = b:CreateTexture(nil, "HIGHLIGHT")
                        h:SetAllPoints()
                        Compat.SolidTexture(h, 1, 1, 1, 0.20)
                        b.highlight = h

                        -- Per-row favorite star. Its own button so it swallows
                        -- the click instead of selecting the row underneath.
                        local sb = CreateFrame("Button", nil, b)
                        sb:SetSize(16, 16)
                        sb:SetPoint("LEFT", 4, 0)
                        sb:SetFrameLevel(b:GetFrameLevel() + 2)
                        sb:EnableMouseWheel(true)
                        sb:SetScript("OnMouseWheel", function(_, d) menu:Scroll(d) end)
                        sb.tex = sb:CreateTexture(nil, "ARTWORK")
                        sb.tex:SetAllPoints()
                        -- Its own highlight: hovering the star takes the mouse
                        -- off the row, so the row's highlight drops out.
                        local shl = sb:CreateTexture(nil, "HIGHLIGHT")
                        shl:SetAllPoints()
                        Compat.SolidTexture(shl, 1, 1, 1, 0.25)
                        b.star = sb

                        b:SetScript("OnMouseWheel", function(_, d) menu:Scroll(d) end)
                        menu.buttons[slot] = b
                    end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 4, -4 - (slot - 1) * rowH)
                    b:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
                    b.text:SetText(item.text)

                    -- A row carries a star only when the list has a toggle
                    -- action and the item opts in with a boolean `toggle`.
                    local starred = dd.onToggle and item.toggle ~= nil and not item.header
                    b.text:ClearAllPoints()
                    b.text:SetPoint("LEFT", starred and 24 or 8, 0)
                    b.text:SetPoint("RIGHT", -8, 0)
                    if starred then
                        Compat.SetStar(b.star.tex, item.toggle)
                        b.star:SetScript("OnClick", function()
                            dd.onToggle(item.value)
                            dd:Reopen()
                        end)
                        b.star:Show()
                    else
                        b.star:Hide()
                    end
                    -- A header labels a section (e.g. "Favorites"). It is inert:
                    -- no selection, and no hover highlight to imply otherwise.
                    if item.header then
                        b.text:SetTextColor(0.7, 0.7, 0.7)
                        b.highlight:SetAlpha(0)
                        b:SetScript("OnClick", nil)
                    else
                        b.text:SetTextColor(1, 1, 1)
                        b.highlight:SetAlpha(1)
                        b:SetScript("OnClick", function(_, button)
                            -- Right-click is a secondary action on the row
                            -- (favoriting, in the language list) and deliberately
                            -- does not change the selection or close the menu.
                            if button == "RightButton" then
                                if dd.onAltClick then
                                    dd.onAltClick(item.value)
                                    dd:Reopen()
                                end
                                return
                            end
                            -- `label` lets a row say more than the button has
                            -- room for: the entry can spell out a count or a
                            -- status while the collapsed button just names the
                            -- choice.
                            dd:SetSelected(item.value, item.label or item.text)
                            closeMenu()
                            if dd.onSelect then dd.onSelect(item.value) end
                        end)
                    end
                    b:Show()
                end
            end
        end

        function menu:Scroll(delta)
            if total <= visible then return end
            self.offset = self.offset - delta   -- wheel up = earlier items
            if self.offset < 0 then self.offset = 0 end
            if self.offset > maxOffset then self.offset = maxOffset end
            render()
        end

        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(_, d) menu:Scroll(d) end)

        render()
        step("draw the rows")
        menu:Show()
        showDropdownCatcher(menu)
        step("show it and catch the next click")
    end

    dd:SetScript("OnClick", function()
        if menu and menu:IsShown() then
            closeMenu()
        else
            Compat.Timed("dropdown: open menu (" .. #(dd.items or {}) .. " entries)",
                openMenu)
        end
    end)
    dd:HookScript("OnHide", closeMenu)

    function dd:SetItems(items)
        self.items = items or {}
        -- The fitted width belongs to the entries that were measured for it.
        self._fitWidth = nil
    end
    function dd:SetSelected(value, text)
        self._selectedValue = value
        self.label:SetText(text or value or "")
    end
    function dd:GetValue()
        return self._selectedValue
    end
    dd.Close = closeMenu

    -- Redraw an open menu from freshly-set items, holding the scroll position.
    -- Used after onAltClick so the row you right-clicked stays where it was.
    function dd:Reopen()
        if not (menu and menu:IsShown()) then return end
        local keep = menu.offset
        -- The rows an alt-click adds go in at the top (a Favorites section, in
        -- the language list), which would slide everything below it down under
        -- the cursor. Absorb that shift so the row you clicked stays put --
        -- except at the very top, where staying at the top is what you want.
        if keep > 0 then keep = keep + (#self.items - (menu.total or #self.items)) end
        closeMenu()
        openMenu(keep)
    end

    return dd
end

--=========================================================================--
--  Status/progress bar. Portable (no StatusBar template quirks): a filled
--  texture over a dark track, with a centred caption. API:
--    bar:SetProgress(fraction 0..1)
--    bar:SetBarColor(r, g, b)
--    bar:SetText(str)
--=========================================================================--
function Compat.CreateStatusBar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width or 200, height or 16)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0, 0, 0, 0.55)
    Compat.AddBorder(bar, 0.4, 0.4, 0.45, 0.9)

    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    Compat.SolidTexture(fill, 0.4, 0.8, 0.4, 1)
    bar.fill = fill

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    -- White + outline + shadow so the label stays readable on any fill color
    -- (e.g. a full gold "Master" bar), instead of low-contrast tan-on-gold.
    text:SetTextColor(1, 1, 1, 1)
    local tf, tsz = text:GetFont()
    if tf then text:SetFont(tf, tsz, "OUTLINE") end
    if text.SetShadowColor then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    end
    bar.text = text

    bar._frac = 0
    function bar:SetProgress(frac)
        frac = math.max(0, math.min(1, frac or 0))
        self._frac = frac
        local w = self:GetWidth() - 2
        if w < 1 then w = 1 end
        self.fill:SetWidth(math.max(1, w * frac))
        if frac <= 0 then self.fill:Hide() else self.fill:Show() end
    end
    function bar:SetBarColor(r, g, b)
        Compat.SolidTexture(self.fill, r, g, b, 1)
    end
    function bar:SetText(t)
        self.text:SetText(t or "")
    end

    bar:SetProgress(0)
    return bar
end

--=========================================================================--
--  Minimap button. Dependency-free (no LibDBIcon), draggable around the ring.
--  opts = {
--    icon         = "Interface\\Icons\\...",
--    onClick      = function(mouseButton) end,
--    onTooltip    = function(GameTooltip) end,
--    onAngleChanged = function(angleDeg) end,   -- called while dragging
--  }
--  Returns the button; call btn:UpdatePosition(angleDeg) to place it.
--=========================================================================--
function Compat.CreateMinimapButton(globalName, opts)
    opts = opts or {}
    if not Minimap then return nil end

    local btn = CreateFrame("Button", globalName, Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)

    -- Standard round minimap-button look: a small round-cropped icon under the
    -- Blizzard tracking-border ring (same as LibDBIcon and other addons).
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(unpack(opts.iconTexCoord or { 0.06, 0.94, 0.06, 0.94 }))
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(icon)
    Compat.SolidTexture(hl, 1, 1, 1, 0.20)

    -- Match LibDBIcon's placement math (what every other addon button uses), so
    -- ours lines up with them and rides just OUTSIDE the ring regardless of the
    -- minimap's size/shape. A round minimap uses an ellipse on the edge; a square
    -- one projects onto the square edge. The old code clamped to r/sqrt(2), which
    -- pulled the button *inside* the map -- the reported "still inside" bug.
    function btn:UpdatePosition(angleDeg)
        local a = math.rad(angleDeg or 200)
        local cos, sin = math.cos(a), math.sin(a)
        local w = (Minimap:GetWidth() / 2) + 6
        local h = (Minimap:GetHeight() / 2) + 6
        local shape = (type(GetMinimapShape) == "function" and GetMinimapShape()) or "ROUND"
        local x, y
        if shape == "ROUND" then
            x, y = cos * w, sin * h
        else
            local diag = math.sqrt(2) * w - 10
            x = math.max(-w, math.min(cos * diag, w))
            y = math.max(-h, math.min(sin * diag, h))
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local px, py = GetCursorPosition()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            self:UpdatePosition(angle)
            if opts.onAngleChanged then opts.onAngleChanged(angle) end
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, mouseButton)
        if opts.onClick then opts.onClick(mouseButton) end
    end)

    if opts.onScroll then
        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", function(_, delta)
            opts.onScroll(delta)
        end)
    end

    btn:SetScript("OnEnter", function(self)
        if opts.onTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            opts.onTooltip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return btn
end

--=========================================================================--
--  Confirmation dialog. We deliberately do NOT use Blizzard's global
--  StaticPopupDialogs table. Adding our keys to it *taints that table*, and on
--  Retail 12.0+ (Midnight) any later read of StaticPopupDialogs -- which happens
--  when the Game menu / Esc handler and the player status bar run -- inherits
--  that taint and then faults on the player frame's "secret" health value:
--  "attempt to compare a secret number value (execution tainted by
--  'TonguesOfAzeroth')". Owning our own frame keeps us out of that secure path.
--  (Inserting into UISpecialFrames, by contrast, is taint-safe -- verified via
--  the client's taint.log -- so we still use it for Esc-to-close.)
--
--  Compat.ShowConfirm{ text=, acceptText=, cancelText=, onAccept=, onCancel= }
--=========================================================================--
local confirmFrame

local function resolveConfirm(f, accepted)
    if f._resolved then return end
    f._resolved = true
    local onAccept, onCancel = f._onAccept, f._onCancel
    f._onAccept, f._onCancel = nil, nil
    f:Hide()
    if accepted then
        if onAccept then onAccept() end
    elseif onCancel then
        onCancel()
    end
end

local function buildConfirm()
    local f = CreateFrame("Frame", "TonguesOfAzerothConfirm", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(440, 170)
    f:SetPoint("CENTER", 0, 120)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0.04, 0.04, 0.06, 0.97)
    Compat.AddBorder(f, 0.5, 0.45, 0.7, 0.95)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 18, -18)
    text:SetPoint("TOPRIGHT", -18, -18)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if text.SetWordWrap then text:SetWordWrap(true) end
    f.text = text

    local function makeButton()
        local b = CreateFrame("Button", nil, f)
        b:SetSize(130, 26)
        local bbg = b:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints()
        Compat.SolidTexture(bbg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(b, 0.5, 0.45, 0.7, 0.9)
        local bhl = b:CreateTexture(nil, "HIGHLIGHT"); bhl:SetAllPoints()
        Compat.SolidTexture(bhl, 1, 1, 1, 0.15)
        local bl = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bl:SetPoint("CENTER")
        b.label = bl
        return b
    end

    local accept = makeButton()
    accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 16)
    accept:SetScript("OnClick", function() resolveConfirm(f, true) end)
    f.accept = accept

    local cancel = makeButton()
    cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16)
    cancel:SetScript("OnClick", function() resolveConfirm(f, false) end)
    f.cancel = cancel

    -- Esc (via UISpecialFrames) hides us -> treat as cancel. If a button already
    -- resolved the dialog, _resolved is set and this is a harmless no-op.
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "TonguesOfAzerothConfirm") end
    f:SetScript("OnHide", function(self) resolveConfirm(self, false) end)

    return f
end

function Compat.ShowConfirm(opts)
    opts = opts or {}
    confirmFrame = confirmFrame or buildConfirm()
    local f = confirmFrame
    if f:IsShown() then resolveConfirm(f, false) end
    f._resolved = false
    f._onAccept = opts.onAccept
    f._onCancel = opts.onCancel
    f.text:SetText(opts.text or "")
    f.accept.label:SetText(opts.acceptText or (YES or "Yes"))
    f.cancel.label:SetText(opts.cancelText or (NO or "No"))
    f:Show()
    f:Raise()
    return f
end

--=========================================================================--
--  Line browser.
--
--  A searchable list, for picking one item out of thousands. The cast panel's
--  dropdowns are fine for the player's own race barks -- a hundred lines, in
--  five labelled groups -- but the game's NPC and boss dialogue runs to
--  thousands, and no dropdown is a reasonable way through that.
--
--    Compat.ShowLineBrowser{
--        title    = "Game voice lines",
--        groups   = function() return { {id=,label=}, ... } end,   -- optional
--        groupAll = "All speakers",
--        filter   = function(groupId, kind, query)
--                       return { {id=,text=,who=}, ... }, truncated
--                   end,
--        onPlay   = function(entry) end,
--        onPick   = function(entry) end,
--    }
--
--  Navigated by narrowing and then by typing. The category and speaker pickers
--  are the way in, and the search box is a sieve on top of them.
--
--  There were A-Z strips here as well, one for speakers and one for lines, on
--  the reasoning that a search box asks you to guess a word out of a corpus
--  you have never read. The categories answer that better: they say what is in
--  there in words, where an initial only says how many things start with S.
--  Two rows of 27 buttons bought nothing the pickers did not already give and
--  cost most of the window's height, so they are gone.
--
--  Clicking the speaker's name on a row narrows to that speaker, which is the
--  move the strips were really standing in for: you search for half a name,
--  see them in the results, and go from there to everything they say.
--
--  Rows are a fixed pool scrolled by moving an offset through the results,
--  rather than a ScrollFrame with a child sized to the result count. Both work;
--  this one cannot get the child height wrong, and a wrong child height is the
--  failure that draws an empty list rather than an error.
--=========================================================================--
local browserFrame

-- Keep the bar's range and position honest about the list behind it. Called
-- on every refresh because the range depends on the result count, which
-- changes with every narrowing.
local function browserScrollbar(f)
    local max = math.max(0, #(f.results or {}) - #f.rows)
    f.scroll:SetMinMaxValues(0, max)
    -- Guarded: setting a value fires OnValueChanged, which refreshes, which
    -- comes back here. The flag makes that re-entry a no-op instead of a loop.
    f._settingScroll = true
    f.scroll:SetValue(math.min(f.offset or 0, max))
    f._settingScroll = false
    -- A bar with nowhere to go is shown greyed rather than hidden, so the list
    -- does not change width as you narrow it.
    local thumb = f.scroll:GetThumbTexture()
    if thumb then thumb:SetAlpha(max > 0 and 1 or 0.25) end
end

local function browserRefresh(f, keepOffset)
    if not keepOffset then f.offset = 0 end
    local rows = f.rows
    local results = f.results or {}
    local shown = #rows

    f.offset = math.max(0, math.min(f.offset or 0, math.max(0, #results - shown)))
    browserScrollbar(f)

    for i, row in ipairs(rows) do
        local entry = results[i + f.offset]
        if entry then
            row._entry = entry
            row.text:SetText(entry.text)
            -- Who said it, when anybody did: the barks are the player's own
            -- voice and have no speaker to name.
            local who = entry.who or ""
            row.who:SetText(who)
            row.who:SetTextColor(0.5, 0.5, 0.5)

            -- The click target is fitted to the drawn name every refresh,
            -- because the name changes with the row. GetStringWidth answers 0
            -- for a string that has not been drawn yet; a 0-wide button would
            -- be a dead target, so the button stays hidden until there is a
            -- width to give it and picks one up on the next pass.
            local w = row.who:GetStringWidth() or 0
            if who ~= "" and w > 0 then
                row.whoBtn._who = who
                row.whoBtn:SetWidth(math.min(150, w + 2))
                row.whoBtn:Show()
            else
                row.whoBtn._who = nil
                row.whoBtn:Hide()
            end
            row:Show()
        else
            row._entry = nil
            row.whoBtn._who = nil
            row.whoBtn:Hide()
            row:Hide()
        end
    end

    local n = #results
    if n == 0 then
        f.status:SetText("Nothing here.")
    else
        f.status:SetText(string.format("%d line%s", n, n == 1 and "" or "s"))
    end
end

local function browserApply(f)
    f.query = f.input:GetText() or ""
    if f._filter then
        f.results, f.truncated = f._filter(f.group or "", f.kind or "", f.query)
    else
        f.results, f.truncated = {}, false
    end
    browserRefresh(f, false)
end

-- Repaint the strip for the group in play: which letters are reachable, and
-- which one is selected.
-- Fills the category dropdown: the shelf a speaker sits on, picked before the
-- speaker itself. Two controls rather than one nested list, because these are
-- two decisions and running them together means scrolling past every heading
-- in the catalogue to reach the one you wanted.
local function browserCategories(f)
    local all = f._categoryAll or "All speakers"
    local items = { { value = "", text = all } }
    for _, c in ipairs((f._categories and f._categories()) or {}) do
        items[#items + 1] = { value = c.id, text = c.label }
    end
    f.catDrop:SetItems(items)

    local label, found = all, (f.category == "")
    for _, it in ipairs(items) do
        if it.value == f.category then found = true label = it.text end
    end
    if not found then f.category = "" end
    f.catDrop:SetSelected(f.category, label)
end

-- Fills the speaker dropdown from the chosen category, narrowed further by
-- whatever is typed in the search box.
--
-- One search box rather than two: the catalogue runs to thousands of speakers,
-- and at that size "find" is the same question whether the word you remember
-- is a name or something that name said. The line filter already matches on
-- the speaker as well as on the text, so typing "sylvanas" narrows this
-- dropdown to her and shows her lines in the same move.
local function browserSpeakers(f)
    local all = f._groupAll or "Everything"
    local query = (f.input and f.input:GetText()) or ""
    local list = (f._groups and f._groups(f.category or "", query)) or {}

    local items = { { value = "", text = all } }
    for _, g in ipairs(list) do
        items[#items + 1] = { value = g.id, text = g.label }
    end
    f.groupDrop:SetItems(items)

    -- A speaker narrowed out of the list has stopped being a choice, so the
    -- selection falls back to everybody on this shelf rather than naming
    -- somebody the dropdown can no longer show.
    local label, found = all, (f.group == "")
    for _, it in ipairs(items) do
        if it.value == f.group then found = true label = it.text end
    end
    if not found then f.group = "" end
    f.groupDrop:SetSelected(f.group, label)
end

-- Jumps the browser to one speaker. Reached by clicking their name on a row,
-- which is the move that makes a half-remembered name enough: type "artha",
-- see Arthas in the results, click him and read the rest of what he says.
--
-- The search box is cleared on the way through. It did its job getting you
-- here, and leaving it set would answer "all of Arthas's lines" with only the
-- ones that also contain "artha" -- which is a handful of them, and looks like
-- the jump went wrong. The category is widened for the same reason: the
-- speaker has to be on the shelf that is showing or the dropdown cannot name
-- them.
local function browserGoToSpeaker(f, who)
    if not who or who == "" then return end
    f.category = ""
    if f.input then f.input:SetText("") end
    browserCategories(f)
    browserSpeakers(f)
    f.group = who
    browserSpeakers(f)
    f.renarrow(f)
end

local function buildBrowser()
    local ROWS, ROW_H = 14, 26
    local f = CreateFrame("Frame", "TonguesOfAzerothLineBrowser", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(700, 210 + ROWS * ROW_H)
    f:SetPoint("CENTER", 0, 40)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0.04, 0.04, 0.06, 0.97)
    Compat.AddBorder(f, 0.5, 0.45, 0.7, 0.95)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    f.title = title

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText("Narrow by category, then by speaker, or just type to search. Click a line to hear it, or a speaker's name to show everything they say.")

    -- Narrowing is dropped rather than kept when it stops being reachable: a
    -- letter that no longer has lines, or a kind of line this speaker does not
    -- have, would otherwise show an empty list and leave you to work out why.
    local function renarrow(f)
        -- Two shapes are accepted. A caller with a flat list of headings gives
        -- { name, count } and lets the label be built here; one with levels to
        -- show -- families and the groups indented under them -- gives
        -- { id, label } already formatted, because the indentation is its
        -- business and not this frame's.
        local kinds = (f._kinds and f._kinds(f.group)) or {}
        local function kindValue(k) return k.id or k.name end
        local function kindLabel(k)
            return k.label or string.format("%s (%d)", k.name, k.count or 0)
        end

        local found = (f.kind == "")
        for _, k in ipairs(kinds) do if kindValue(k) == f.kind then found = true end end
        if not found then f.kind = "" end

        local items = { { value = "", text = f._kindAll or "Everything" } }
        for _, k in ipairs(kinds) do
            items[#items + 1] = { value = kindValue(k), text = kindLabel(k) }
        end
        f.kindDrop:SetItems(items)
        local label = f._kindAll or "Everything"
        for _, it in ipairs(items) do if it.value == f.kind then label = it.text end end
        f.kindDrop:SetSelected(f.kind, label)

        browserApply(f)
    end
    f.renarrow = renarrow

    -- Every control gets a word above it saying what it narrows. They were
    -- bare before, which left three dropdowns reading "All speakers", "Every
    -- kind" and nothing -- labels for their own current value, not for the
    -- question they answer, so the only way to learn what one did was to
    -- change it and watch what moved.
    local function fieldLabel(text, anchor, relative, dx, dy)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", anchor, relative or "BOTTOMLEFT", dx or 0, dy or -10)
        fs:SetText(text)
        return fs
    end

    -- Row one: which shelf, then who is on it.
    local catLabel = fieldLabel("Category", hint)
    local catDrop = Compat.CreateDropdown(f, 300)
    catDrop.menuFitItems = true
    catDrop:SetPoint("TOPLEFT", catLabel, "BOTTOMLEFT", 0, -4)
    catDrop:SetHeight(22)
    catDrop.onSelect = function(value)
        f.category = value or ""
        -- browserSpeakers drops the chosen speaker if the new shelf does not
        -- hold them, and keeps them if it does. Clearing it here as well would
        -- throw away a selection that is still perfectly valid -- switching
        -- from "Your voice" to "Player races" should not lose your place.
        browserSpeakers(f)
        renarrow(f)
    end
    f.catDrop = catDrop

    local groupLabel = fieldLabel("Speaker", catLabel, "TOPLEFT", 312, 0)
    local groupDrop = Compat.CreateDropdown(f, 330)
    -- Speaker names run long -- "Blood Elf Demon Hunter - masculine voice" --
    -- and a name cut off mid-word is not a choice anybody can make.
    groupDrop.menuFitItems = true
    groupDrop:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, -4)
    groupDrop:SetHeight(22)
    groupDrop.onSelect = function(value)
        f.group = value or ""
        renarrow(f)
    end
    f.groupDrop = groupDrop

    -- Row two: what kind of line, and the search box.
    --
    -- The kind picker is what makes a speaker with 279 lines usable -- battle
    -- cries, threats and pain are different things to go looking for -- and it
    -- reads as doing nothing only while it is unlabelled and showing "Every
    -- kind".
    local kindLabel = fieldLabel("Kind of line", catDrop)
    local kindDrop = Compat.CreateDropdown(f, 300)
    kindDrop.menuFitItems = true
    kindDrop:SetPoint("TOPLEFT", kindLabel, "BOTTOMLEFT", 0, -4)
    kindDrop:SetHeight(22)
    kindDrop.onSelect = function(value)
        f.kind = value or ""
        browserApply(f)
    end
    f.kindDrop = kindDrop

    local searchLabel = fieldLabel("Search names and lines", kindLabel, "TOPLEFT", 312, 0)
    local input = CreateFrame("EditBox", "TonguesOfAzerothLineBrowserSearch", f,
        "InputBoxTemplate")
    input:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 6, -4)
    input:SetSize(240, 22)
    input:SetAutoFocus(false)
    input:SetScript("OnTextChanged", function()
        browserSpeakers(f)
        browserApply(f)
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.input = input

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("LEFT", input, "RIGHT", 12, 0)
    f.status = status

    f.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_H)
        if i == 1 then
            row:SetPoint("TOPLEFT", kindDrop, "BOTTOMLEFT", 0, -12)
        else
            row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end
        -- Clear of the scrollbar, which lives in the right margin.
        row:SetPoint("RIGHT", f, "RIGHT", -38, 0)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.10)

        -- The speaker's name, and a button sitting exactly on top of it.
        --
        -- Sized to the text rather than to the 150-wide column on purpose. The
        -- row underneath plays the line, so anything the name button covers is
        -- a click that does something other than what the row says it does --
        -- and a short name in a wide column would leave a band of blank space
        -- that silently jumps you to another character. The width is set from
        -- the string on every refresh, in browserRefresh.
        local who = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        who:SetPoint("LEFT", 4, 0)
        who:SetWidth(150)
        who:SetJustifyH("LEFT")
        row.who = who

        local whoBtn = CreateFrame("Button", nil, row)
        whoBtn:SetPoint("LEFT", who, "LEFT", 0, 0)
        whoBtn:SetHeight(ROW_H - 4)
        whoBtn:Hide()
        local whoHl = whoBtn:CreateTexture(nil, "HIGHLIGHT")
        whoHl:SetAllPoints()
        Compat.SolidTexture(whoHl, 1, 0.82, 0, 0.22)
        whoBtn:SetScript("OnEnter", function(self)
            -- Said out loud rather than left to be discovered. The name is the
            -- only thing on the row that does not play the line, so it has to
            -- announce itself before it is clicked, not after.
            row.who:SetTextColor(1, 0.82, 0)
            if GameTooltip and self._who then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self._who)
                GameTooltip:AddLine("Click to show everything they say.", 1, 0.82, 0)
                GameTooltip:Show()
            end
        end)
        whoBtn:SetScript("OnLeave", function()
            row.who:SetTextColor(0.5, 0.5, 0.5)
            if GameTooltip then GameTooltip:Hide() end
        end)
        whoBtn:SetScript("OnClick", function(self)
            if self._who and self._who ~= "" then browserGoToSpeaker(f, self._who) end
        end)
        row.whoBtn = whoBtn

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", who, "RIGHT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        -- Click hears it, double-click takes it. Hearing one is the common
        -- action by a wide margin -- the transcript tells you the words, so
        -- the only open question is the delivery.
        row:SetScript("OnClick", function(self)
            if not self._entry then return end
            f._selected = self._entry
            if f._onPlay then f._onPlay(self._entry) end
            for _, r in ipairs(f.rows) do
                r.text:SetTextColor(r == self and 0.53 or 1, r == self and 0.8 or 1, 1)
            end
        end)
        row:SetScript("OnDoubleClick", function(self)
            if self._entry and f._onPick then f._onPick(self._entry); f:Hide() end
        end)
        f.rows[i] = row
    end

    -- A real bar rather than paging. Built from the base Slider type for the
    -- usual reason: the scroll templates have been reworked more than once and
    -- a missing one is a frame that does not appear at all.
    local scroll = CreateFrame("Slider", nil, f)
    scroll:SetOrientation("VERTICAL")
    scroll:SetWidth(16)
    scroll:SetPoint("TOPRIGHT", f.rows[1], "TOPRIGHT", 22, -2)
    scroll:SetPoint("BOTTOMRIGHT", f.rows[ROWS], "BOTTOMRIGHT", 22, 2)
    scroll:SetValueStep(1)
    if scroll.SetObeyStepOnDrag then scroll:SetObeyStepOnDrag(true) end
    scroll:SetMinMaxValues(0, 0)
    scroll:SetValue(0)

    local track = scroll:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(6)
    Compat.SolidTexture(track, 1, 1, 1, 0.18)

    scroll:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    local thumb = scroll:GetThumbTexture()
    if thumb then thumb:SetSize(16, 24) end

    scroll:SetScript("OnValueChanged", function(self, value)
        if f._settingScroll then return end
        f.offset = math.floor(value + 0.5)
        browserRefresh(f, true)
    end)
    f.scroll = scroll

    -- The wheel moves the bar, so there is one source of truth for position
    -- rather than two that can disagree.
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        local _, max = self.scroll:GetMinMaxValues()
        if (max or 0) <= 0 then return end
        self.scroll:SetValue(math.max(0, math.min(max,
            (self.offset or 0) - delta * 3)))
    end)

    local function makeButton(w)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w or 120, 26)
        local bbg = b:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints()
        Compat.SolidTexture(bbg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(b, 0.5, 0.45, 0.7, 0.9)
        local bhl = b:CreateTexture(nil, "HIGHLIGHT"); bhl:SetAllPoints()
        Compat.SolidTexture(bhl, 1, 1, 1, 0.15)
        local bl = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bl:SetPoint("CENTER")
        b.label = bl
        return b
    end

    local use = makeButton()
    use:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
    use.label:SetText("Use this line")
    use:SetScript("OnClick", function()
        if f._selected and f._onPick then f._onPick(f._selected) end
        f:Hide()
    end)

    local cancel = makeButton()
    cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
    cancel.label:SetText(CANCEL or "Cancel")
    cancel:SetScript("OnClick", function() f:Hide() end)

    if type(UISpecialFrames) == "table" then
        tinsert(UISpecialFrames, "TonguesOfAzerothLineBrowser")
    end
    return f
end

function Compat.ShowLineBrowser(opts)
    opts = opts or {}
    if not browserFrame then
        browserFrame = Compat.Timed("browser: build the window once", buildBrowser)
    end
    local f = browserFrame
    f.title:SetText(opts.title or "Voice lines")
    f._filter = opts.filter
    f._kinds = opts.kinds
    f._kindAll = opts.kindAll or "Every kind"
    f._onPlay = opts.onPlay
    f._onPick = opts.onPick
    f._selected = nil
    f.group = opts.group or ""
    f.kind = opts.kind or ""
    for _, r in ipairs(f.rows) do r.text:SetTextColor(1, 1, 1) end

    f._groups = opts.groups
    f._groupAll = opts.groupAll or "Everything"
    f._categories = opts.categories
    f._categoryAll = opts.categoryAll or "All speakers"
    f.category = opts.category or ""
    Compat.Timed("browser: list the categories", browserCategories, f)
    Compat.Timed("browser: list the speakers", browserSpeakers, f)

    -- Seeds the box without firing a filter per character; renarrow applies
    -- once at the end, after the kind list and letter strip are built.
    f.input:SetText(opts.query or "")
    Compat.Timed("browser: narrow and fill the list", f.renarrow, f)
    f:Show()
    f:Raise()
    return f
end

--=========================================================================--
--  Color picker.
--
--  Blizzard reworked this in 10.2.5: the old contract was to assign callbacks
--  onto ColorPickerFrame as fields (.func, .cancelFunc, .opacityFunc) and show
--  the frame, and the new one passes them in a table to
--  SetupColorPickerAndShow. Feature-detected on that method rather than an
--  interface number, per the usual rule -- Forever reports 16001 while carrying
--  the modern frame.
--
--  Returns true if a picker was opened. A false return is not a failure the
--  caller should swallow: every caller must have a hex-entry path anyway, both
--  for clients where the frame is missing and for anyone who wants to type an
--  exact value.
--
--    Compat.ShowColorPicker{ r=, g=, b=, onChange=function(r,g,b) end,
--                            onCancel=function(r,g,b) end }
--
--  onChange fires live as the player drags, so callers should apply rather than
--  only commit; onCancel receives the original color to restore.
--=========================================================================--
function Compat.ShowColorPicker(opts)
    opts = opts or {}
    local picker = _G.ColorPickerFrame
    if not picker then return false end

    local r = tonumber(opts.r) or 1
    local g = tonumber(opts.g) or 1
    local b = tonumber(opts.b) or 1

    local function changed()
        if not opts.onChange then return end
        local nr, ng, nb = picker:GetColorRGB()
        opts.onChange(nr, ng, nb)
    end
    local function cancelled()
        if opts.onCancel then opts.onCancel(r, g, b) end
    end

    -- Wrapped because this is Blizzard UI: a frame that another addon has
    -- already replaced or half-initialised should cost us a fallback to the hex
    -- box, not a Lua error in the middle of the options panel.
    local ok = pcall(function()
        if picker.SetupColorPickerAndShow then
            picker:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                hasOpacity = false,
                swatchFunc = changed,
                cancelFunc = cancelled,
            })
        else
            picker.func = changed
            picker.cancelFunc = cancelled
            picker.opacityFunc = nil
            picker.hasOpacity = false
            picker.previousValues = { r = r, g = g, b = b }
            -- Hide first: re-showing an already-open picker leaves the old
            -- callbacks installed on some builds.
            picker:Hide()
            picker:SetColorRGB(r, g, b)
            picker:Show()
        end
    end)
    return ok
end
