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

-- 1px edge border drawn on a frame's own BORDER layer (never covers content).
-- Works identically on 3.3.5a and modern clients (no SetBackdrop / BackdropTemplate).
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

-- A single, shared, draggable window that hosts ONE options panel at a time
-- (main panel, learned, trainer, ...). Used on legacy / custom clients where the
-- native Interface Options is unreliable. Navigation model:
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
    titlebar:SetPoint("TOPRIGHT", -74, 0)   -- room for the back/close button
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

    -- Back button - shown on sub-panels; runs the current panel's _backAction.
    local back = CreateFrame("Button", nil, win)
    back:SetSize(64, 22)
    back:SetPoint("TOPRIGHT", -4, -2)
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
        local action = win._current and win._current._backAction
        if action then action() end
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
    if frame._backAction then
        win.closeBtn:Hide()
        win.backBtn:Show()
    else
        win.backBtn:Hide()
        win.closeBtn:Show()
    end

    win:Show()
    if win.Raise then win:Raise() end
    if type(frame.refresh) == "function" then frame.refresh() end
end

function Compat.OpenOptionsPanel(frame)
    if not frame then return end
    if Compat.hasSettingsAPI and frame._settingsCategory then
        -- Modern clients: the Settings panel open-to-category is reliable.
        Settings.OpenToCategory(frame._settingsCategory:GetID())
        return
    end
    -- Legacy 3.3.5a / custom clients (Ascension): InterfaceOptionsFrame_OpenToCategory
    -- is unreliable (or absent), so use our own guaranteed standalone window.
    Compat.ShowStandalone(frame)
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
        local offset = 0
        for i = 1, total do
            if items[i].value == dd.selectedValue then
                offset = i - math.floor(visible / 2) - 1
                break
            end
        end
        if offset < 0 then offset = 0 end
        if offset > maxOffset then offset = maxOffset end
        menu.offset = offset

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
                        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        t:SetPoint("LEFT", 8, 0)
                        t:SetPoint("RIGHT", -8, 0)
                        t:SetJustifyH("LEFT")
                        b.text = t
                        local h = b:CreateTexture(nil, "HIGHLIGHT")
                        h:SetAllPoints()
                        Compat.SolidTexture(h, 1, 1, 1, 0.20)
                        b:SetScript("OnMouseWheel", function(_, d) menu:Scroll(d) end)
                        menu.buttons[slot] = b
                    end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 4, -4 - (slot - 1) * rowH)
                    b:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
                    b.text:SetText(item.text)
                    b:SetScript("OnClick", function()
                        dd:SetSelected(item.value, item.text)
                        closeMenu()
                        if dd.onSelect then dd.onSelect(item.value) end
                    end)
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

    local radius = 80
    function btn:UpdatePosition(angleDeg)
        local a = math.rad(angleDeg or 200)
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
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
