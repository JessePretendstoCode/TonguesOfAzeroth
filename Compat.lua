--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Compat.lua
    Cross-client compatibility shim. Loaded FIRST (before every other file).

    One addon, many clients: this file smooths over the API differences between
    the 2010-era 3.3.5a client (Project Ascension / WotLK private servers) and
    the modern engine (Retail "Midnight", plus Cata / Mists / Vanilla Classic).

    Everything here is *feature-detected*, never version-hardcoded, so it keeps
    working on future patches. The rest of the addon only ever talks to
    ns.Compat, never to the raw client APIs that move around.

    What it abstracts:
      * client tier detection (ns.Compat.isModern / isLegacy)
      * addon metadata            (GetAddOnMetadata vs C_AddOns.GetAddOnMetadata)
      * addon messaging           (SendAddonMessage vs C_ChatInfo.*)
      * group checks              (GetNumRaidMembers vs IsInRaid, etc.)
      * options panel register/open (InterfaceOptions_* vs Settings.*)
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
-- The modern Settings API exists on Retail and all current Classic flavors.
-- The legacy InterfaceOptions API only exists on the old 3.3.5a client.
Compat.hasSettingsAPI      = (type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function")
Compat.hasLegacyOptionsAPI = (type(InterfaceOptions_AddCategory) == "function")
Compat.isModern = Compat.hasSettingsAPI
Compat.isLegacy = not Compat.hasSettingsAPI

-- Interface build number, e.g. 30300 (3.3.5a) or 120007 (Midnight).
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
    -- Not present on 3.3.5a (addon messages there need no registration).
    if type(rawRegPrefix) == "function" then
        pcall(rawRegPrefix, prefix)
    end
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
--  Solid-color textures (SetColorTexture is modern-only; 3.3.5a uses SetTexture).
--=========================================================================--
function Compat.SolidTexture(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture(r, g, b, a or 1)
    end
end

--=========================================================================--
--  Options panel: create / register / open.
--  Legacy: InterfaceOptions_AddCategory + InterfaceOptionsFrame_OpenToCategory.
--  Modern: Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory /
--          RegisterCanvasLayoutSubcategory + Settings.OpenToCategory.
--=========================================================================--
ns._optionCategories = ns._optionCategories or {}

function Compat.CreateOptionsPanel(globalName)
    -- On modern clients InterfaceOptionsFramePanelContainer is nil; UIParent is
    -- a safe parent since the Settings canvas reparents the frame anyway.
    local parent = InterfaceOptionsFramePanelContainer or UIParent
    local f = CreateFrame("Frame", globalName, parent)
    f:Hide()
    return f
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
    elseif Compat.hasLegacyOptionsAPI then
        InterfaceOptions_AddCategory(frame)
    end
end

function Compat.OpenOptionsPanel(frame)
    if not frame then return end
    if Compat.hasSettingsAPI and frame._settingsCategory then
        local id = frame._settingsCategory:GetID()
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        if InterfaceAddOnsList_Update then InterfaceAddOnsList_Update() end
        -- Called twice to work around a 3.3.5a open-to-category quirk.
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end

--=========================================================================--
--  Widgets. Built from base frame types + universally-available textures so
--  they render identically on 3.3.5a and modern clients (no template churn,
--  no removed UIDropDownMenu).
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
    return s
end

-- Portable dropdown. API:
--   dd:SetItems({ {text=, value=}, ... })
--   dd:SetSelected(value, text)
--   dd:GetValue()
--   dd.onSelect = function(value) ... end   (called on pick)
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

    local function openMenu()
        if not menu then
            menu = CreateFrame("Frame", nil, dd)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:EnableMouse(true)
            local mbg = menu:CreateTexture(nil, "BACKGROUND")
            mbg:SetAllPoints()
            Compat.SolidTexture(mbg, 0, 0, 0, 0.94)
            addBorder(menu, 0.5, 0.5, 0.5, 0.8)
            menu.buttons = {}
        end

        local items = dd.items
        local rowH = 20
        local w = dd:GetWidth()
        menu:SetWidth(w)
        menu:SetHeight(math.max(rowH, #items * rowH + 8))
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)

        for i = 1, #menu.buttons do menu.buttons[i]:Hide() end

        for i = 1, #items do
            local item = items[i]
            local b = menu.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, menu)
                b:SetHeight(rowH)
                local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                t:SetPoint("LEFT", 8, 0)
                t:SetPoint("RIGHT", -8, 0)
                t:SetJustifyH("LEFT")
                b.text = t
                local h = b:CreateTexture(nil, "HIGHLIGHT")
                h:SetAllPoints()
                Compat.SolidTexture(h, 1, 1, 1, 0.20)
                menu.buttons[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * rowH)
            b:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
            b.text:SetText(item.text)
            b:SetScript("OnClick", function()
                dd:SetSelected(item.value, item.text)
                closeMenu()
                if dd.onSelect then dd.onSelect(item.value) end
            end)
            b:Show()
        end
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

    return dd
end
