--[[-------------------------------------------------------------------------
    Tongues of Azeroth - UI.lua
    In-game configuration registered under the game's AddOns options.
      * Main panel: enable, language, strength, channel filters, preview.
      * Learned Languages sub-panel: per-language checkboxes, decode display style.

    All widgets come from ns.Compat, so the same panel renders on the 3.3.5a
    client (Interface Options) and on modern clients (the Settings panel), with
    no reliance on UIDropDownMenu or templates that retail has removed.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language
local Compat = ns.Compat
local Accent = ns.Accent

local SAMPLE = "The old gods whisper madness into your mind."

local CHANNEL_LABELS = {
    SAY           = "Say",
    YELL          = "Yell",
    WHISPER       = "Whisper",
    PARTY         = "Party",
    RAID          = "Raid",
    RAID_WARNING  = "Raid Warning",
    INSTANCE_CHAT = "Instance",
    GUILD         = "Guild",
    OFFICER       = "Officer",
    CHANNEL       = "General & Trade Channels",
}

local DECODE_STYLES = {
    { id = "inline",  name = "In-line (rewrite the chat line, like WoW)" },
    { id = "emote",   name = "Emote (separate yellow * line)" },
    { id = "whisper", name = "Whisper (separate purple line)" },
}

local mainPanel, learnedPanel, accentPanel, customPanel
local langDropdown, slider, valueText, enableCheck, previewInput, previewOutput
local minimapCheck, tagCheck, fluencyCheck
local widgetCheck, widgetLockCheck
local accentEnableCheck, accentDropdown, accentSlider, accentValueText
local accentPreviewInput, accentPreviewOutput
local customEditDropdown, customNameInput, customApostSlider, customApostText
local customOnsetInput, customNucleiInput, customCodaInput
local customPreviewInput, customPreviewOutput, customStatus, customEditingId
local customShareInput
local channelChecks = {}
local learnedRows = {}
local learnedBars = {}
local passiveCheck
local decodeStyleDropdown
local outputDropdown
local panelsBuilt = false
local minimapButton

local function db()
    if TonguesOfAzerothDB == nil and OldGodTonguesDB ~= nil then
        TonguesOfAzerothDB = OldGodTonguesDB
    end
    TonguesOfAzerothDB = TonguesOfAzerothDB or {}
    if TonguesOfAzerothDB.enabled == nil then TonguesOfAzerothDB.enabled = false end
    if TonguesOfAzerothDB.strength == nil then
        TonguesOfAzerothDB.strength = TonguesOfAzerothDB.corruption or 100
    end
    if TonguesOfAzerothDB.language == nil or not Language.IsValid(TonguesOfAzerothDB.language) then
        TonguesOfAzerothDB.language = Language.DEFAULT
    end
    if not TonguesOfAzerothDB.channels then TonguesOfAzerothDB.channels = {} end
    if not TonguesOfAzerothDB.learned then TonguesOfAzerothDB.learned = {} end
    if TonguesOfAzerothDB.decodeStyle == nil then TonguesOfAzerothDB.decodeStyle = "inline" end
    if not TonguesOfAzerothDB.minimap then TonguesOfAzerothDB.minimap = {} end
    if TonguesOfAzerothDB.minimap.hide == nil then TonguesOfAzerothDB.minimap.hide = false end
    if TonguesOfAzerothDB.minimap.angle == nil then TonguesOfAzerothDB.minimap.angle = 200 end
    if not TonguesOfAzerothDB.widget then TonguesOfAzerothDB.widget = {} end
    if TonguesOfAzerothDB.widget.enabled == nil then TonguesOfAzerothDB.widget.enabled = false end
    if TonguesOfAzerothDB.widget.locked == nil then TonguesOfAzerothDB.widget.locked = false end
    if TonguesOfAzerothDB.widget.point == nil then TonguesOfAzerothDB.widget.point = "CENTER" end
    if TonguesOfAzerothDB.widget.x == nil then TonguesOfAzerothDB.widget.x = 0 end
    if TonguesOfAzerothDB.widget.y == nil then TonguesOfAzerothDB.widget.y = -140 end
    if TonguesOfAzerothDB.outputFrame == nil then TonguesOfAzerothDB.outputFrame = 0 end
    if TonguesOfAzerothDB.tagLanguage == nil then TonguesOfAzerothDB.tagLanguage = true end
    if TonguesOfAzerothDB.tagFluency == nil then TonguesOfAzerothDB.tagFluency = true end
    if not TonguesOfAzerothDB.accent then TonguesOfAzerothDB.accent = {} end
    if TonguesOfAzerothDB.accent.enabled == nil then TonguesOfAzerothDB.accent.enabled = false end
    if TonguesOfAzerothDB.accent.strength == nil then TonguesOfAzerothDB.accent.strength = 100 end
    if TonguesOfAzerothDB.accent.id == nil or not (Accent and Accent.IsValid(TonguesOfAzerothDB.accent.id)) then
        TonguesOfAzerothDB.accent.id = (Accent and Accent.DEFAULT) or "dwarf"
    end
    return TonguesOfAzerothDB
end

-- Fluency % (0-100) of a language from the trainer store. Speaking strength ==
-- fluency, so this is what the main slider and the preview use now.
local function fluencyPct(langId)
    if ns.Trainer and ns.Trainer.GetProgress and langId then
        local ok, _, _, frac = pcall(ns.Trainer.GetProgress, langId)
        if ok and type(frac) == "number" then return math.floor(frac * 100 + 0.5) end
    end
    return db().strength or 100
end

-- Guard so RefreshMain's programmatic slider:SetValue() doesn't write fluency
-- back (which would fight with passive learning / the Trainer).
local settingSlider = false

local function refreshPreview()
    if not (previewInput and previewOutput) then return end
    local d = db()
    local src = previewInput:GetText()
    if src == "" then src = SAMPLE end
    previewOutput:SetText(Language.TranslateText(src, fluencyPct(d.language), d.language))
end

local function langItems()
    -- List every language. Sub-languages are grouped and indented under the
    -- primary whose word set they share. The dropdown scrolls, so the full list
    -- stays usable.
    local all = Language.GetLanguages()
    local subsOf, primaries = {}, {}
    for i = 1, #all do
        local l = all[i]
        if l.sub and l.parent then
            subsOf[l.parent] = subsOf[l.parent] or {}
            table.insert(subsOf[l.parent], l)
        elseif not l.sub then
            primaries[#primaries + 1] = l
        end
    end

    local items = {}
    for i = 1, #primaries do
        local p = primaries[i]
        items[#items + 1] = { text = p.name, value = p.id }
        local subs = subsOf[p.id]
        if subs then
            for j = 1, #subs do
                items[#items + 1] = { text = "    " .. subs[j].name, value = subs[j].id }
            end
        end
    end
    return items
end

local function decodeStyleLabel(styleId)
    if styleId == "inline" then return "In-line (rewrite the chat line, like WoW)" end
    if styleId == "whisper" then return "Whisper (separate purple line)" end
    return "Emote (separate yellow * line)"
end

local function outputWindowLabel(idx)
    if not idx or idx == 0 then return "Default (current window)" end
    local name = GetChatWindowInfo and GetChatWindowInfo(idx)
    if name and name ~= "" then return idx .. ": " .. name end
    return "Chat window " .. idx
end

-- Every named chat window, plus a "default" entry. Rebuilt on panel show so a
-- window the player renamed/created since login appears without a reload.
local function outputItems()
    local items = { { text = outputWindowLabel(0), value = 0 } }
    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        local name = GetChatWindowInfo and GetChatWindowInfo(i)
        if name and name ~= "" then
            items[#items + 1] = { text = i .. ": " .. name, value = i }
        end
    end
    return items
end

local function RefreshMain()
    if not mainPanel then return end
    local d = db()
    enableCheck:SetChecked(d.enabled)
    if minimapCheck then minimapCheck:SetChecked(not d.minimap.hide) end
    if widgetCheck then widgetCheck:SetChecked(d.widget.enabled and true or false) end
    if widgetLockCheck then
        widgetLockCheck:SetChecked(d.widget.locked and true or false)
        widgetLockCheck:SetShown(d.widget.enabled and true or false)
    end
    if tagCheck then tagCheck:SetChecked(d.tagLanguage ~= false) end
    if fluencyCheck then fluencyCheck:SetChecked(d.tagFluency ~= false) end
    langDropdown:SetSelected(d.language, Language.GetLanguageName(d.language))
    local fp = fluencyPct(d.language)
    settingSlider = true
    slider:SetValue(fp)
    settingSlider = false
    valueText:SetText(fp .. "%")
    for ch, check in pairs(channelChecks) do
        check:SetChecked(d.channels[ch] and true or false)
    end
    refreshPreview()
end

local function RefreshLearned()
    if not learnedPanel then return end
    local d = db()
    for langId, rowRef in pairs(learnedRows) do
        local base = Language.GetLanguageName(langId)
        local frac = 0
        if ns.Trainer and ns.Trainer.GetProgress then
            _, _, frac = ns.Trainer.GetProgress(langId)
        end

        local bar = rowRef.bar
        -- Gate on fluency %, not solved-word count, so passively-learned or
        -- slider-/button-set fluency shows a bar too.
        if frac and frac > 0 then
            local rank, color = ns.Trainer.GetRank(frac)
            local hex = color and string.format("%02x%02x%02x",
                math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255)) or "9fd8ff"
            rowRef.name:SetText(string.format("%s  |cff%s(%s %d%%)|r",
                base, hex, rank, math.floor(frac * 100 + 0.5)))
            if bar then
                bar.fill:SetWidth(math.max(1, bar.barW * frac))
                if color then Compat.SolidTexture(bar.fill, color[1], color[2], color[3], 1) end
                bar.fill:Show()
            end
        else
            rowRef.name:SetText(base)
            if bar then bar.fill:Hide() end
        end

        -- Light up the "make fluent" check when you already fully know it.
        local isFluent = (d.learned[langId] or (frac and frac >= 1)) and true or false
        if rowRef.fluentBtn and rowRef.fluentBtn.icon then
            if isFluent then
                rowRef.fluentBtn.icon:SetVertexColor(1, 1, 1, 1)
            else
                rowRef.fluentBtn.icon:SetVertexColor(0.55, 0.55, 0.55, 0.9)
            end
        end
    end
    if passiveCheck then passiveCheck:SetChecked(d.passiveLearning ~= false) end
    decodeStyleDropdown:SetSelected(d.decodeStyle, decodeStyleLabel(d.decodeStyle))
    if outputDropdown then
        outputDropdown:SetItems(outputItems())
        outputDropdown:SetSelected(d.outputFrame or 0, outputWindowLabel(d.outputFrame or 0))
    end
end

local function ApplyMinimapShown()
    if not minimapButton then return end
    if db().minimap.hide then minimapButton:Hide() else minimapButton:Show() end
end
ns.ApplyMinimapShown = ApplyMinimapShown

local function SetupMinimapButton()
    if minimapButton then ApplyMinimapShown(); return end
    local d = db()
    -- Generic purple orb (a built-in Blizzard icon, so it also renders on Ascension,
    -- which won't load custom/loose texture files).
    minimapButton = Compat.CreateMinimapButton("TonguesOfAzerothMinimapButton", {
        icon = "Interface\\Icons\\INV_Misc_Orb_04",
        onClick = function(mouseButton)
            if mouseButton == "RightButton" then
                d.enabled = not d.enabled
                if ns.OnSettingsChanged then ns.OnSettingsChanged() end
            else
                ns.OpenConfig()
            end
        end,
        onScroll = function(delta)
            if ns.CycleLanguage then ns.CycleLanguage(delta > 0 and 1 or -1) end
        end,
        onTooltip = function(tt)
            tt:AddLine("Tongues of Azeroth")
            tt:AddLine("Language: |cffffffff" .. Language.GetLanguageName(d.language) .. "|r", 0.8, 0.8, 0.8)
            tt:AddLine("Auto-translate: " .. (d.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"), 0.8, 0.8, 0.8)
            tt:AddLine(" ")
            tt:AddLine("|cffffffffLeft-click|r  Open settings", 1, 1, 1)
            tt:AddLine("|cffffffffRight-click|r  Toggle auto-translate", 1, 1, 1)
            tt:AddLine("|cffffffffScroll|r  Cycle learned languages", 1, 1, 1)
            tt:AddLine("|cffffffffDrag|r  Move around minimap", 1, 1, 1)
        end,
        onAngleChanged = function(angle)
            d.minimap.angle = angle
        end,
    })
    if minimapButton then
        minimapButton:UpdatePosition(d.minimap.angle)
        ApplyMinimapShown()
    end
end
ns.SetupMinimapButton = SetupMinimapButton

--=========================================================================--
--  Floating language widget. A small draggable HUD in the spirit of the old
--  Tongues button: shows your active language at a glance and makes switching
--  quick. Off by default. It's entirely our own frame on UIParent with no
--  Blizzard globals and is NOT added to UISpecialFrames/UIPanelWindows, so it
--  never touches the (protected) panel manager -- i.e. completely taint-free.
--=========================================================================--
local langWidget

local function fluencyAdjective(pct)
    if pct >= 100 then return "Perfect", 1, 0.85, 0.2 end
    if pct >= 75 then return "Fluent", 0.4, 0.85, 0.4 end
    if pct >= 25 then return "Partial", 0.95, 0.8, 0.3 end
    return "Broken", 0.95, 0.5, 0.4
end

local function RefreshLanguageWidget()
    if not langWidget then return end
    local d = db()
    if not d.widget.enabled then langWidget:Hide(); return end
    langWidget:Show()
    langWidget.name:SetText(Language.GetLanguageName(d.language))
    local adj, ar, ag, ab = fluencyAdjective(fluencyPct(d.language))
    langWidget.sub:SetText(adj)
    langWidget.sub:SetTextColor(ar, ag, ab)
    if d.enabled then
        langWidget.dot:SetText("Auto")
        langWidget.dot:SetTextColor(0.4, 0.9, 0.4)
    else
        langWidget.dot:SetText("Off")
        langWidget.dot:SetTextColor(0.9, 0.4, 0.4)
    end
end
ns.RefreshLanguageWidget = RefreshLanguageWidget

local function saveWidgetPosition()
    local point, _, relPoint, x, y = langWidget:GetPoint()
    local d = db()
    d.widget.point = point or "CENTER"
    d.widget.relPoint = relPoint or point or "CENTER"
    d.widget.x = x or 0
    d.widget.y = y or 0
end

local function SetupLanguageWidget()
    local d = db()
    if not langWidget then
        local f = CreateFrame("Frame", "TonguesOfAzerothLangWidget", UIParent)
        f:SetSize(140, 40)
        f:SetFrameStrata("MEDIUM")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        f:RegisterForDrag("LeftButton")

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.05, 0.05, 0.08, 0.9)
        Compat.AddBorder(f, 0.5, 0.45, 0.7, 0.95)

        local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOP", 0, -6)
        name:SetTextColor(1, 0.82, 0.2)
        f.name = name

        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("BOTTOMLEFT", 8, 6)
        f.sub = sub

        local dot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dot:SetPoint("BOTTOMRIGHT", -8, 6)
        f.dot = dot

        f:SetScript("OnDragStart", function(self)
            if db().widget.locked then return end
            self:StartMoving()
        end)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            saveWidgetPosition()
        end)
        f:SetScript("OnMouseWheel", function(_, delta)
            if ns.CycleLanguage then ns.CycleLanguage(delta > 0 and 1 or -1) end
        end)
        f:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                if IsShiftKeyDown and IsShiftKeyDown() then
                    local dd = db()
                    dd.enabled = not dd.enabled
                    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                elseif ns.CycleLanguage then
                    ns.CycleLanguage(1)
                end
            elseif button == "RightButton" then
                if ns.OpenConfig then ns.OpenConfig() end
            end
        end)
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Tongues of Azeroth", 1, 1, 1)
            GameTooltip:AddLine("Language: |cffffffff" .. Language.GetLanguageName(db().language) .. "|r", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffLeft-click|r  Next learned language", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffScroll|r  Cycle languages", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffShift-click|r  Toggle auto-translate", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffRight-click|r  Open settings", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffDrag|r  Move (unlock in options)", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)

        langWidget = f
    end
    langWidget:ClearAllPoints()
    langWidget:SetPoint(d.widget.point or "CENTER", UIParent,
        d.widget.relPoint or d.widget.point or "CENTER", d.widget.x or 0, d.widget.y or -140)
    RefreshLanguageWidget()
end
ns.SetupLanguageWidget = SetupLanguageWidget

local function BuildMainPanel()
    mainPanel = Compat.CreateOptionsPanel("TonguesOfAzerothOptions")
    mainPanel.name = "Tongues of Azeroth"

    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tongues of Azeroth")

    local subtitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Speak the languages of Azeroth in chat, Tongues-style.")

    local function makeNavButton(label, onClick)
        local btn = CreateFrame("Button", nil, mainPanel)
        btn:SetSize(150, 24)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(btn, 0.5, 0.45, 0.7, 0.9)
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", 0, 0)
        text:SetText(label)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.12)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- Nav buttons are stacked vertically down the right edge so a growing list
    -- of sub-panels stays clear of the title on the left.
    local trainerBtn = makeNavButton("Language Trainer", function()
        if ns.OpenTrainer then ns.OpenTrainer() end
    end)
    trainerBtn:SetPoint("TOPRIGHT", mainPanel, "TOPRIGHT", -16, -16)

    -- Opens the Learned Languages panel. On legacy/custom clients (Ascension)
    -- the config is a standalone window with no options tree, so this button is
    -- the way to reach the sub-panel.
    local learnedBtn = makeNavButton("Learned Languages", function()
        if ns.OpenLearnedConfig then ns.OpenLearnedConfig() end
    end)
    learnedBtn:SetPoint("TOPRIGHT", trainerBtn, "BOTTOMRIGHT", 0, -4)

    local accentBtn = makeNavButton("Accents", function()
        if ns.OpenAccentConfig then ns.OpenAccentConfig() end
    end)
    accentBtn:SetPoint("TOPRIGHT", learnedBtn, "BOTTOMRIGHT", 0, -4)

    local customBtn = makeNavButton("Create Language", function()
        if ns.OpenCustomConfig then ns.OpenCustomConfig() end
    end)
    customBtn:SetPoint("TOPRIGHT", accentBtn, "BOTTOMRIGHT", 0, -4)

    enableCheck = Compat.CreateCheckbox(mainPanel, "Enable auto-translate in chat")
    enableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    enableCheck:SetScript("OnClick", function(self)
        db().enabled = self:GetChecked() and true or false
    end)

    minimapCheck = Compat.CreateCheckbox(mainPanel, "Show minimap button")
    minimapCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -6)
    minimapCheck:SetScript("OnClick", function(self)
        db().minimap.hide = not self:GetChecked()
        ApplyMinimapShown()
    end)

    widgetCheck = Compat.CreateCheckbox(mainPanel, "Show floating language bar")
    widgetCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -6)
    widgetCheck:SetScript("OnClick", function(self)
        db().widget.enabled = self:GetChecked() and true or false
        SetupLanguageWidget()
        if widgetLockCheck then widgetLockCheck:SetShown(db().widget.enabled) end
    end)

    widgetLockCheck = Compat.CreateCheckbox(mainPanel, "Lock the floating bar in place")
    widgetLockCheck:SetPoint("TOPLEFT", widgetCheck, "BOTTOMLEFT", 16, -4)
    widgetLockCheck:SetScript("OnClick", function(self)
        db().widget.locked = self:GetChecked() and true or false
    end)

    tagCheck = Compat.CreateCheckbox(mainPanel, "Prefix messages with [Language]")
    tagCheck:SetPoint("TOPLEFT", widgetLockCheck, "BOTTOMLEFT", -16, -6)
    tagCheck:SetScript("OnClick", function(self)
        db().tagLanguage = self:GetChecked() and true or false
    end)

    fluencyCheck = Compat.CreateCheckbox(mainPanel, "Show fluency in tag (Broken / Partial / Fluent / Perfect)")
    fluencyCheck:SetPoint("TOPLEFT", tagCheck, "BOTTOMLEFT", 16, -4)
    fluencyCheck:SetScript("OnClick", function(self)
        db().tagFluency = self:GetChecked() and true or false
        refreshPreview()
    end)

    local langLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", fluencyCheck, "BOTTOMLEFT", -16, -18)
    langLabel:SetText("Language")

    langDropdown = Compat.CreateDropdown(mainPanel, 260)
    langDropdown:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    langDropdown:SetItems(langItems())
    langDropdown.onSelect = function(value)
        db().language = value
        -- Refresh the whole panel so the Fluency slider snaps to the newly
        -- selected language's fluency.
        RefreshMain()
    end

    -- Quick-cycle button through your learned languages (also on the minimap
    -- scroll wheel and via /toa next|prev).
    local cycleBtn = CreateFrame("Button", nil, mainPanel)
    cycleBtn:SetSize(92, 24)
    cycleBtn:SetPoint("LEFT", langDropdown, "RIGHT", 8, 0)
    local cbg = cycleBtn:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    Compat.SolidTexture(cbg, 0.18, 0.16, 0.24, 1)
    Compat.AddBorder(cycleBtn, 0.5, 0.45, 0.7, 0.9)
    local cbtext = cycleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbtext:SetPoint("CENTER", 0, 0)
    cbtext:SetText("Next |cff9a7cff>|r")
    local chl = cycleBtn:CreateTexture(nil, "HIGHLIGHT")
    chl:SetAllPoints()
    Compat.SolidTexture(chl, 1, 1, 1, 0.12)
    cycleBtn:SetScript("OnClick", function()
        if ns.CycleLanguage then ns.CycleLanguage(1) end
        RefreshMain()
    end)

    slider = Compat.CreateSlider(mainPanel, 0, 100, 1, "Fluency", "0 - None", "100 - Fluent")
    slider:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 0, -34)
    slider:SetWidth(320)
    valueText = slider.valueText
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value .. "%")
        if settingSlider then return end
        -- Fluency IS your speaking strength: this sets how fully you speak the
        -- selected language (and drives its decode tag).
        if ns.SetLanguageFluency then ns.SetLanguageFluency(db().language, value / 100) end
        refreshPreview()
    end)

    -- Anchored well below the slider so it clears the slider's own min/max and
    -- value labels (which sit just under the track).
    local fluencyHint = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fluencyHint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -26)
    fluencyHint:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    fluencyHint:SetJustifyH("LEFT")
    if fluencyHint.SetWordWrap then fluencyHint:SetWordWrap(true) end
    fluencyHint:SetText("How well you speak this tongue -- higher fluency = more of it comes through. Build it by hearing it, in the Trainer, or per-language under Learned Languages.")

    local channelLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", fluencyHint, "BOTTOMLEFT", 0, -16)
    channelLabel:SetText("Channels")

    local channelHint = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -2)
    channelHint:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    channelHint:SetJustifyH("LEFT")
    channelHint:SetText("Applies when you speak and when you listen.")

    local channelList = ns.CHANNEL_TYPES or {}
    local ROW_H = 22
    local COL2_X = 210
    local half = math.ceil(#channelList / 2)

    for i = 1, #channelList do
        local ch = channelList[i]
        local check = Compat.CreateCheckbox(mainPanel, CHANNEL_LABELS[ch] or ch)
        local row, col
        if i <= half then
            row = i - 1
            col = 0
        else
            row = i - half - 1
            col = COL2_X
        end
        check:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", col, -4 - row * ROW_H)
        check:SetScript("OnClick", function(self)
            db().channels[ch] = self:GetChecked() and true or false
        end)
        channelChecks[ch] = check
    end

    local channelRows = half
    local previewLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -12 - channelRows * ROW_H)
    previewLabel:SetText("Preview (type to test):")

    previewInput = CreateFrame("EditBox", "TonguesOfAzerothPreviewInput", mainPanel, "InputBoxTemplate")
    previewInput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    previewInput:SetSize(320, 20)
    previewInput:SetAutoFocus(false)
    previewInput:SetText(SAMPLE)
    previewInput:SetScript("OnTextChanged", refreshPreview)
    previewInput:SetScript("OnEnterPressed", previewInput.ClearFocus)
    previewInput:SetScript("OnEscapePressed", previewInput.ClearFocus)

    previewOutput = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    previewOutput:SetPoint("TOPLEFT", previewInput, "BOTTOMLEFT", -6, -12)
    previewOutput:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    previewOutput:SetJustifyH("LEFT")
    previewOutput:SetHeight(36)
    previewOutput:SetSpacing(2)

    mainPanel.refresh = RefreshMain
    mainPanel:SetScript("OnShow", RefreshMain)
end

local function BuildLearnedPanel()
    learnedPanel = Compat.CreateOptionsPanel("TonguesOfAzerothLearnedOptions")
    learnedPanel.name = "Learned Languages"
    learnedPanel.parent = mainPanel.name

    local title = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Learned Languages")

    local subtitle = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Your languages and how fluently you speak each. Use the |cff66dd66check|r to instantly master a tongue, or |cffdd6666reset|r it to 0%.")

    -- Global learning method: passive (learn by hearing). The Trainer minigame is
    -- always available via its own button; this toggles the automatic learning.
    passiveCheck = Compat.CreateCheckbox(learnedPanel, "Passive learning -- overhearing a tongue slowly builds your fluency in it")
    passiveCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    passiveCheck:SetScript("OnClick", function(self)
        db().passiveLearning = self:GetChecked() and true or false
    end)

    local styleLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", passiveCheck, "BOTTOMLEFT", 0, -12)
    styleLabel:SetText("Decode display style")

    decodeStyleDropdown = Compat.CreateDropdown(learnedPanel, 220)
    decodeStyleDropdown:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -6)
    local styleItems = {}
    for i = 1, #DECODE_STYLES do
        styleItems[i] = { text = DECODE_STYLES[i].name, value = DECODE_STYLES[i].id }
    end
    decodeStyleDropdown:SetItems(styleItems)
    decodeStyleDropdown.onSelect = function(value)
        db().decodeStyle = value
    end

    -- Where decoded translations are printed. Sits beside the style picker.
    local outputLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outputLabel:SetPoint("TOPLEFT", styleLabel, "TOPLEFT", 250, 0)
    outputLabel:SetText("Show translations in")

    outputDropdown = Compat.CreateDropdown(learnedPanel, 220)
    outputDropdown:SetPoint("TOPLEFT", outputLabel, "BOTTOMLEFT", 0, -6)
    outputDropdown:SetItems(outputItems())
    outputDropdown.onSelect = function(value)
        db().outputFrame = value
        outputDropdown:SetSelected(value, outputWindowLabel(value))
    end

    local langLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", decodeStyleDropdown, "BOTTOMLEFT", 0, -22)
    langLabel:SetText("Your languages")

    -- Footer note, pinned to the bottom so the scroll area can size against it.
    local note = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", learnedPanel, "BOTTOMLEFT", 16, 14)
    note:SetPoint("BOTTOMRIGHT", learnedPanel, "BOTTOMRIGHT", -28, 14)
    note:SetJustifyH("LEFT")
    note:SetText("Fluency = how fully you speak a tongue. Build it by hearing it (passive), in the Language Trainer, or with the buttons above. Decoding works for text produced by Tongues of Azeroth; rare words may not reverse perfectly.")

    -- Small square icon button with a tooltip (used for the check / reset icons).
    local function iconButton(parent, tex, tip, r, g, b)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(24, 24)
        local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.16, 0.15, 0.20, 1)
        Compat.AddBorder(btn, r or 0.5, g or 0.45, b or 0.7, 0.9)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER", 0, 0)
        icon:SetSize(16, 16)
        icon:SetTexture(tex)
        btn.icon = icon
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.15)
        if tip then
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return btn
    end

    -- Scrollable single-column list: each row is a language with its fluency bar
    -- and two icon buttons -- a check (make fully fluent) and a circle-slash
    -- (reset to 0%), both behind a confirmation. Mouse-wheel scrolls.
    local scroll = CreateFrame("ScrollFrame", "TonguesOfAzerothLearnedScroll", learnedPanel)
    scroll:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", note, "TOPRIGHT", 0, 10)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)

    -- Primary languages only; sub-languages share their parent's word set (and
    -- fluency), so learning/showing the parent covers them.
    local langs = Language.GetPrimaryLanguages()
    local ROW_H = 38
    local CHILD_W = 560
    child:SetSize(CHILD_W, #langs * ROW_H + 6)

    for i = 1, #langs do
        local entry = langs[i]
        local rowF = CreateFrame("Frame", nil, child)
        rowF:SetSize(CHILD_W, ROW_H)
        rowF:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((i - 1) * ROW_H))

        local name = rowF:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        name:SetPoint("TOPLEFT", rowF, "TOPLEFT", 4, -3)
        name:SetText(entry.name)

        -- Reset (circle-slash) + Make Fluent (check) icons, vertically centered.
        local resetBtn = iconButton(rowF, "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
            "Reset " .. entry.name .. " to 0% (wipes fluency)", 0.7, 0.4, 0.4)
        resetBtn:SetPoint("RIGHT", rowF, "RIGHT", -6, 0)
        resetBtn:SetScript("OnClick", function()
            Compat.ShowConfirm({
                text = string.format("Reset \"%s\" to 0%%?\n\nThis wipes your fluency and any words you've unlocked for it.", entry.name),
                onAccept = function() if ns.ResetLanguageFluency then ns.ResetLanguageFluency(entry.id) end end,
            })
        end)

        local fluentBtn = iconButton(rowF, "Interface\\RAIDFRAME\\ReadyCheck-Ready",
            "Make " .. entry.name .. " fully fluent (100%)", 0.4, 0.6, 0.4)
        fluentBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
        fluentBtn:SetScript("OnClick", function()
            Compat.ShowConfirm({
                text = string.format("Become fully fluent in \"%s\"?\n\nThis instantly sets your fluency to 100%% (you'll speak and understand it perfectly).", entry.name),
                onAccept = function() if ns.MakeLanguageFluent then ns.MakeLanguageFluent(entry.id) end end,
            })
        end)

        -- Thin fluency bar beneath the label (left of the buttons).
        local barW = CHILD_W - 110
        local bar = CreateFrame("Frame", nil, rowF)
        bar:SetSize(barW, 6)
        bar:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        Compat.SolidTexture(track, 1, 1, 1, 0.10)
        local fill = bar:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", 0, 0)
        fill:SetWidth(1)
        Compat.SolidTexture(fill, 0.4, 0.8, 0.4, 1)
        fill:Hide()
        bar.fill = fill
        bar.barW = barW
        learnedBars[entry.id] = bar

        learnedRows[entry.id] = { name = name, bar = bar, fluentBtn = fluentBtn }
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * ROW_H
        if v < 0 then v = 0 end
        local maxv = self:GetVerticalScrollRange()
        if v > maxv then v = maxv end
        self:SetVerticalScroll(v)
    end)

    learnedPanel.refresh = RefreshLearned
    learnedPanel:SetScript("OnShow", RefreshLearned)
end

local ACCENT_SAMPLE = "I'm going to the tavern tonight. What do you think about a good drink with the lads?"

local function refreshAccentPreview()
    if not (accentPreviewInput and accentPreviewOutput and Accent) then return end
    local d = db()
    local src = accentPreviewInput:GetText()
    if src == "" then src = ACCENT_SAMPLE end
    accentPreviewOutput:SetText(Accent.Apply(src, d.accent.id, d.accent.strength))
end

local function accentItems()
    local items = {}
    if not Accent then return items end
    local list = Accent.GetAccents()
    for i = 1, #list do
        items[i] = { text = list[i].name, value = list[i].id }
    end
    return items
end

local function RefreshAccent()
    if not accentPanel then return end
    local d = db()
    if accentEnableCheck then accentEnableCheck:SetChecked(d.accent.enabled) end
    if accentDropdown then accentDropdown:SetSelected(d.accent.id, Accent.GetAccentName(d.accent.id)) end
    if accentSlider then accentSlider:SetValue(d.accent.strength) end
    if accentValueText then accentValueText:SetText(d.accent.strength .. "%") end
    refreshAccentPreview()
end

local function BuildAccentPanel()
    accentPanel = Compat.CreateOptionsPanel("TonguesOfAzerothAccentOptions")
    accentPanel.name = "Accents"
    accentPanel.parent = mainPanel.name

    local title = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Accents")

    local subtitle = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", accentPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Flavor your English with a spoken dialect, e.g. Dwarven \"I cannae do this, aye!\" or Troll \"da voodoo, mon.\"")

    accentEnableCheck = Compat.CreateCheckbox(accentPanel, "Speak with an accent")
    accentEnableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    accentEnableCheck:SetScript("OnClick", function(self)
        db().accent.enabled = self:GetChecked() and true or false
    end)

    local hint = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", accentEnableCheck, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", accentPanel, "RIGHT", -32, 0)
    hint:SetJustifyH("LEFT")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    hint:SetText("Uses the same channels as the main panel. Auto-translate overrides accents whenever you have any fluency in the spoken tongue, so turn auto-translate off (or speak a language you're 0% fluent in) to hear your accent.")

    local accentLabel = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    accentLabel:SetText("Accent")

    accentDropdown = Compat.CreateDropdown(accentPanel, 260)
    accentDropdown:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -6)
    accentDropdown:SetItems(accentItems())
    accentDropdown.onSelect = function(value)
        db().accent.id = value
        accentDropdown:SetSelected(value, Accent.GetAccentName(value))
        refreshAccentPreview()
    end

    accentSlider = Compat.CreateSlider(accentPanel, 0, 100, 1, "Strength", "0 - Subtle", "100 - Thick")
    accentSlider:SetPoint("TOPLEFT", accentDropdown, "BOTTOMLEFT", 0, -34)
    accentSlider:SetWidth(320)
    accentValueText = accentSlider.valueText
    accentSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db().accent.strength = value
        accentValueText:SetText(value .. "%")
        refreshAccentPreview()
    end)

    local previewLabel = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", accentSlider, "BOTTOMLEFT", 0, -28)
    previewLabel:SetText("Preview (type to test):")

    accentPreviewInput = CreateFrame("EditBox", "TonguesOfAzerothAccentPreviewInput", accentPanel, "InputBoxTemplate")
    accentPreviewInput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    accentPreviewInput:SetSize(320, 20)
    accentPreviewInput:SetAutoFocus(false)
    accentPreviewInput:SetText(ACCENT_SAMPLE)
    accentPreviewInput:SetScript("OnTextChanged", refreshAccentPreview)
    accentPreviewInput:SetScript("OnEnterPressed", accentPreviewInput.ClearFocus)
    accentPreviewInput:SetScript("OnEscapePressed", accentPreviewInput.ClearFocus)

    accentPreviewOutput = accentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    accentPreviewOutput:SetPoint("TOPLEFT", accentPreviewInput, "BOTTOMLEFT", -6, -12)
    accentPreviewOutput:SetPoint("RIGHT", accentPanel, "RIGHT", -32, 0)
    accentPreviewOutput:SetJustifyH("LEFT")
    accentPreviewOutput:SetHeight(36)
    accentPreviewOutput:SetSpacing(2)

    accentPanel.refresh = RefreshAccent
    accentPanel:SetScript("OnShow", RefreshAccent)
end

--=========================================================================--
--  Custom Language builder
--=========================================================================--
local CUSTOM_SAMPLE = "Hello friend, well met on the road"
local CUSTOM_DEFAULTS = {
    onsets = "k, th, v, sh, r, n, m, g, dr, gr",
    nuclei = "a, e, i, o, u, ae, ei",
    codas  = ", n, r, th, k, l",
    apostrophe = 10,
}

-- Split a comma-separated sound list; empty tokens (from ",,") are kept so a
-- player can allow "no sound" in a position, mirroring the built-in generators.
local function splitPool(text)
    local out = {}
    if type(text) ~= "string" or text:gsub("%s", "") == "" then return out end
    for token in (text .. ","):gmatch("(.-),") do
        out[#out + 1] = token:gsub("^%s+", ""):gsub("%s+$", "")
    end
    return out
end

local function joinPool(list)
    if type(list) ~= "table" then return "" end
    return table.concat(list, ", ")
end

local function customFieldsToDef()
    return {
        id = customEditingId, -- nil for a new language (id is derived from name)
        name = customNameInput and customNameInput:GetText() or "",
        onsets = splitPool(customOnsetInput and customOnsetInput:GetText()),
        nuclei = splitPool(customNucleiInput and customNucleiInput:GetText()),
        codas  = splitPool(customCodaInput and customCodaInput:GetText()),
        apostrophe = (customApostSlider and customApostSlider:GetValue() or 10) / 100,
    }
end

local function refreshCustomPreview()
    if not customPreviewOutput then return end
    local src = customPreviewInput and customPreviewInput:GetText() or ""
    if src == "" then src = CUSTOM_SAMPLE end
    customPreviewOutput:SetText(Language.PreviewTranslate(src, customFieldsToDef()))
end

local function customStatusMsg(text, isError)
    if not customStatus then return end
    customStatus:SetText((isError and "|cffff5555" or "|cff55ff55") .. text .. "|r")
end

local function customEditItems()
    local items = { { text = "+ New language", value = "" } }
    local list = ns.GetCustomLanguages and ns.GetCustomLanguages() or {}
    for i = 1, #list do
        items[#items + 1] = { text = list[i].name, value = list[i].id }
    end
    return items
end

local function loadCustomIntoFields(id)
    local def
    if id and id ~= "" then
        local saved = TonguesOfAzerothDB and TonguesOfAzerothDB.customLanguages
        def = saved and saved[id]
    end
    customEditingId = (def and id) or nil
    if def then
        customNameInput:SetText(def.name or id)
        customOnsetInput:SetText(joinPool(def.onsets))
        customNucleiInput:SetText(joinPool(def.nuclei))
        customCodaInput:SetText(joinPool(def.codas))
        local pct = math.floor((tonumber(def.apostrophe) or 0) * 100 + 0.5)
        customApostSlider:SetValue(pct)
        customApostText:SetText(pct .. "%")
    else
        customNameInput:SetText("")
        customOnsetInput:SetText(CUSTOM_DEFAULTS.onsets)
        customNucleiInput:SetText(CUSTOM_DEFAULTS.nuclei)
        customCodaInput:SetText(CUSTOM_DEFAULTS.codas)
        customApostSlider:SetValue(CUSTOM_DEFAULTS.apostrophe)
        customApostText:SetText(CUSTOM_DEFAULTS.apostrophe .. "%")
    end
    refreshCustomPreview()
end

function ns.ShowExportCode(id)
    if not customShareInput then return end
    local code = ns.ExportCustomLanguage and ns.ExportCustomLanguage(id)
    if code then
        customShareInput:SetText(code)
        customShareInput:SetFocus()
        customShareInput:HighlightText()
    end
end

local function RefreshCustom()
    if not customPanel then return end
    if customEditDropdown then
        customEditDropdown:SetItems(customEditItems())
        local label = customEditingId and Language.GetLanguageName(customEditingId) or "+ New language"
        customEditDropdown:SetSelected(customEditingId or "", label)
    end
    refreshCustomPreview()
end

local function BuildCustomPanel()
    customPanel = Compat.CreateOptionsPanel("TonguesOfAzerothCustomOptions")
    customPanel.name = "Create Language"
    customPanel.parent = mainPanel.name

    local title = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Create a Language")

    local subtitle = customPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", customPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    if subtitle.SetWordWrap then subtitle:SetWordWrap(true) end
    subtitle:SetText("Build a tongue from sounds. Words keep their length so it reads like a real language. Separate sounds with commas; use two commas (, ,) to allow \"no sound\".")

    local editLabel = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    editLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    editLabel:SetText("Edit")
    customEditDropdown = Compat.CreateDropdown(customPanel, 220)
    customEditDropdown:SetPoint("TOPLEFT", editLabel, "BOTTOMLEFT", 0, -6)
    customEditDropdown:SetItems(customEditItems())
    customEditDropdown.onSelect = function(value)
        loadCustomIntoFields(value)
        RefreshCustom()
    end

    local nameLabel = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", editLabel, "TOPLEFT", 250, 0)
    nameLabel:SetText("Name")
    customNameInput = CreateFrame("EditBox", "TonguesOfAzerothCustomName", customPanel, "InputBoxTemplate")
    customNameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 6, -6)
    customNameInput:SetSize(220, 20)
    customNameInput:SetAutoFocus(false)
    customNameInput:SetScript("OnTextChanged", refreshCustomPreview)
    customNameInput:SetScript("OnEnterPressed", customNameInput.ClearFocus)
    customNameInput:SetScript("OnEscapePressed", customNameInput.ClearFocus)

    local function poolBox(name, labelText, anchorTo, gapY)
        local lbl = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, gapY)
        lbl:SetText(labelText)
        local box = CreateFrame("EditBox", name, customPanel, "InputBoxTemplate")
        box:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 6, -6)
        box:SetSize(470, 20)
        box:SetAutoFocus(false)
        box:SetScript("OnTextChanged", refreshCustomPreview)
        box:SetScript("OnEnterPressed", box.ClearFocus)
        box:SetScript("OnEscapePressed", box.ClearFocus)
        return box
    end

    customOnsetInput  = poolBox("TonguesOfAzerothCustomOnsets", "Starting sounds (onsets)", customEditDropdown, -20)
    customNucleiInput = poolBox("TonguesOfAzerothCustomNuclei", "Vowel sounds (required)", customOnsetInput, -12)
    customCodaInput   = poolBox("TonguesOfAzerothCustomCodas", "Ending sounds (codas)", customNucleiInput, -12)

    customApostSlider = Compat.CreateSlider(customPanel, 0, 30, 1, "Apostrophes", "0 - None", "30 - Lots")
    customApostSlider:SetPoint("TOPLEFT", customCodaInput, "BOTTOMLEFT", -6, -28)
    customApostSlider:SetWidth(320)
    customApostText = customApostSlider.valueText
    customApostSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        customApostText:SetText(value .. "%")
        refreshCustomPreview()
    end)

    local previewLabel = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", customApostSlider, "BOTTOMLEFT", 6, -26)
    previewLabel:SetText("Preview (type to test):")
    customPreviewInput = CreateFrame("EditBox", "TonguesOfAzerothCustomPreviewInput", customPanel, "InputBoxTemplate")
    customPreviewInput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    customPreviewInput:SetSize(470, 20)
    customPreviewInput:SetAutoFocus(false)
    customPreviewInput:SetText(CUSTOM_SAMPLE)
    customPreviewInput:SetScript("OnTextChanged", refreshCustomPreview)
    customPreviewInput:SetScript("OnEnterPressed", customPreviewInput.ClearFocus)
    customPreviewInput:SetScript("OnEscapePressed", customPreviewInput.ClearFocus)

    customPreviewOutput = customPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    customPreviewOutput:SetPoint("TOPLEFT", customPreviewInput, "BOTTOMLEFT", -6, -12)
    customPreviewOutput:SetPoint("RIGHT", customPanel, "RIGHT", -32, 0)
    customPreviewOutput:SetJustifyH("LEFT")
    customPreviewOutput:SetHeight(36)
    customPreviewOutput:SetSpacing(2)

    local function styleButton(btn, label, w)
        btn:SetSize(w or 110, 24)
        local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(btn, 0.5, 0.45, 0.7, 0.9)
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER", 0, 0); t:SetText(label)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.12)
    end

    local saveBtn = CreateFrame("Button", nil, customPanel)
    saveBtn:SetPoint("TOPLEFT", customPreviewOutput, "BOTTOMLEFT", 6, -14)
    styleButton(saveBtn, "Save", 110)
    saveBtn:SetScript("OnClick", function()
        local def = customFieldsToDef()
        if not def.name or def.name:gsub("%s", "") == "" then
            customStatusMsg("Give your language a name first.", true)
            return
        end
        local ok, idOrErr = ns.SaveCustomLanguage(def)
        if ok then
            customEditingId = idOrErr
            if langDropdown then langDropdown:SetItems(langItems()) end
            RefreshCustom()
            customStatusMsg("Saved \"" .. def.name .. "\" -- it's in your language list now.", false)
        else
            customStatusMsg("Could not save: " .. tostring(idOrErr), true)
        end
    end)

    local deleteBtn = CreateFrame("Button", nil, customPanel)
    deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    styleButton(deleteBtn, "Delete", 110)
    deleteBtn:SetScript("OnClick", function()
        if not customEditingId then
            customStatusMsg("Pick a saved language to delete first.", true)
            return
        end
        local nm = Language.GetLanguageName(customEditingId)
        if ns.DeleteCustomLanguage(customEditingId) then
            customEditingId = nil
            if langDropdown then langDropdown:SetItems(langItems()) end
            loadCustomIntoFields(nil)
            RefreshCustom()
            customStatusMsg("Deleted \"" .. nm .. "\".", false)
        end
    end)

    customStatus = customPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    customStatus:SetPoint("LEFT", deleteBtn, "RIGHT", 12, 0)
    customStatus:SetText("")

    -- Share section: copy/paste code + direct in-game send.
    local shareLabel = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shareLabel:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", -6, -18)
    shareLabel:SetText("Share")

    local shareHint = customPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    shareHint:SetPoint("TOPLEFT", shareLabel, "BOTTOMLEFT", 0, -4)
    shareHint:SetPoint("RIGHT", customPanel, "RIGHT", -32, 0)
    shareHint:SetJustifyH("LEFT")
    if shareHint.SetWordWrap then shareHint:SetWordWrap(true) end
    shareHint:SetText("Copy the code to send via Discord, or paste one in and Import. \"Share to target\" sends it in-game to your target/group.")

    customShareInput = CreateFrame("EditBox", "TonguesOfAzerothCustomShare", customPanel, "InputBoxTemplate")
    customShareInput:SetPoint("TOPLEFT", shareHint, "BOTTOMLEFT", 6, -8)
    customShareInput:SetSize(470, 20)
    customShareInput:SetAutoFocus(false)
    customShareInput:SetScript("OnEnterPressed", customShareInput.ClearFocus)
    customShareInput:SetScript("OnEscapePressed", customShareInput.ClearFocus)
    -- Select-all on focus so the player can just Ctrl+C.
    customShareInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local getCodeBtn = CreateFrame("Button", nil, customPanel)
    getCodeBtn:SetPoint("TOPLEFT", customShareInput, "BOTTOMLEFT", -6, -12)
    styleButton(getCodeBtn, "Copy code", 110)
    getCodeBtn:SetScript("OnClick", function()
        if not customEditingId then
            customStatusMsg("Save your language first, then Copy code.", true)
            return
        end
        local code = ns.ExportCustomLanguage and ns.ExportCustomLanguage(customEditingId)
        if code then
            customShareInput:SetText(code)
            customShareInput:SetFocus()
            customShareInput:HighlightText()
            customStatusMsg("Code ready -- press Ctrl+C to copy.", false)
        else
            customStatusMsg("Could not build a share code.", true)
        end
    end)

    local importBtn = CreateFrame("Button", nil, customPanel)
    importBtn:SetPoint("LEFT", getCodeBtn, "RIGHT", 8, 0)
    styleButton(importBtn, "Import", 110)
    importBtn:SetScript("OnClick", function()
        local code = customShareInput:GetText() or ""
        if code:gsub("%s", "") == "" then
            customStatusMsg("Paste a share code into the box first.", true)
            return
        end
        local ok, idOrErr = ns.ImportCustomLanguage(code)
        if ok then
            customEditingId = idOrErr
            loadCustomIntoFields(idOrErr)
            if langDropdown then langDropdown:SetItems(langItems()) end
            RefreshCustom()
            customShareInput:SetText("")
            customStatusMsg("Imported \"" .. Language.GetLanguageName(idOrErr) .. "\".", false)
        else
            customStatusMsg("Import failed: " .. tostring(idOrErr), true)
        end
    end)

    local shareTargetBtn = CreateFrame("Button", nil, customPanel)
    shareTargetBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    styleButton(shareTargetBtn, "Share to target", 130)
    shareTargetBtn:SetScript("OnClick", function()
        if not customEditingId then
            customStatusMsg("Save your language first, then share it.", true)
            return
        end
        local target = (UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") and UnitName("target")) or nil
        local ok, msg = ns.ShareCustomLanguage(customEditingId, target)
        customStatusMsg(msg, not ok)
    end)

    loadCustomIntoFields(nil)
    customPanel.refresh = RefreshCustom
    customPanel:SetScript("OnShow", RefreshCustom)
end

local function BuildPanels()
    if panelsBuilt then return end

    BuildMainPanel()
    Compat.RegisterOptionsPanel(mainPanel, mainPanel.name)

    BuildLearnedPanel()
    Compat.RegisterOptionsPanel(learnedPanel, learnedPanel.name, mainPanel.name)

    BuildAccentPanel()
    Compat.RegisterOptionsPanel(accentPanel, accentPanel.name, mainPanel.name)

    BuildCustomPanel()
    Compat.RegisterOptionsPanel(customPanel, customPanel.name, mainPanel.name)

    -- In the shared standalone window (legacy/custom clients), the sub-panels
    -- show a Back button (to the main panel) instead of their own close button.
    learnedPanel._backAction = function() ns.OpenConfig() end
    accentPanel._backAction = function() ns.OpenConfig() end
    customPanel._backAction = function() ns.OpenConfig() end

    panelsBuilt = true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= ADDON then return end
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and name == ADDON) then
        BuildPanels()
    end
    if event == "PLAYER_LOGIN" then
        SetupMinimapButton()
        SetupLanguageWidget()
    end
end)

ns.OnSettingsChanged = function()
    if mainPanel and mainPanel:IsVisible() then RefreshMain() end
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
    if accentPanel and accentPanel:IsVisible() then RefreshAccent() end
    if customPanel and customPanel:IsVisible() then RefreshCustom() end
    -- Keep the main language dropdown in sync when custom languages change.
    if langDropdown then langDropdown:SetItems(langItems()) end
    RefreshLanguageWidget()
end

-- Called by the trainer after a solve so fluency bars update live if the
-- Learned Languages panel happens to be open at the same time.
ns.RefreshLearnedIfShown = function()
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
end

-- Lightweight refresh for frequent fluency changes (passive learning, slider
-- drags, Make Fluent / Reset). Only touches visible panels and, crucially, does
-- NOT rebuild the language dropdown list (unlike OnSettingsChanged).
ns.RefreshFluencyIfShown = function()
    if mainPanel and mainPanel:IsVisible() then RefreshMain() end
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
    RefreshLanguageWidget()
end

function ns.OpenConfig()
    BuildPanels()
    Compat.OpenOptionsPanel(mainPanel)
end

function ns.OpenLearnedConfig()
    BuildPanels()
    Compat.OpenOptionsPanel(learnedPanel)
end

function ns.OpenAccentConfig()
    BuildPanels()
    Compat.OpenOptionsPanel(accentPanel)
end

function ns.OpenCustomConfig()
    BuildPanels()
    Compat.OpenOptionsPanel(customPanel)
end
