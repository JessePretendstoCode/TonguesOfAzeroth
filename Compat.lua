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
    end

    -- `keepOffset` reopens at a given scroll position instead of jumping to the
    -- selection, so a right-click that rewrites the list (see dd:Reopen) doesn't
    -- yank the menu out from under the cursor.
    local function openMenu(keepOffset)
        if not menu then
            -- Parented to UIParent (not dd) so the popup is never clipped when the
            -- dropdown lives inside a ScrollFrame; still anchored to dd below.
            menu = CreateFrame("Frame", nil, UIParent)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetToplevel(true)
            menu:EnableMouse(true)
            local mbg = menu:CreateTexture(nil, "BACKGROUND")
            mbg:SetAllPoints()
            Compat.SolidTexture(mbg, 0, 0, 0, 0.94)
            addBorder(menu, 0.5, 0.5, 0.5, 0.8)
            menu.buttons = {}
        end

        local items = dd.items
        local rowH = 20
        local maxVisible = 14
        local total = #items
        local visible = math.max(1, math.min(total, maxVisible))
        local maxOffset = math.max(0, total - visible)
        local w = dd:GetWidth()
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
                            dd:SetSelected(item.value, item.text)
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
        menu:Show()
    end

    dd:SetScript("OnClick", function()
        if menu and menu:IsShown() then closeMenu() else openMenu() end
    end)
    dd:HookScript("OnHide", closeMenu)

    function dd:SetItems(items)
        self.items = items or {}
    end
    function dd:SetSelected(value, text)
        self.selectedValue = value
        self.label:SetText(text or value or "")
    end
    function dd:GetValue()
        return self.selectedValue
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
