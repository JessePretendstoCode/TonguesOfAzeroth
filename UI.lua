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
    { id = "emote",   name = "Emote (yellow * line)" },
    { id = "whisper", name = "Whisper (purple line)" },
}

local mainPanel, learnedPanel, accentPanel
local langDropdown, slider, valueText, enableCheck, previewInput, previewOutput
local minimapCheck
local accentEnableCheck, accentDropdown, accentSlider, accentValueText
local accentPreviewInput, accentPreviewOutput
local channelChecks = {}
local learnedChecks = {}
local learnedBars = {}
local decodeStyleDropdown
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
    if TonguesOfAzerothDB.decodeStyle == nil then TonguesOfAzerothDB.decodeStyle = "emote" end
    if not TonguesOfAzerothDB.minimap then TonguesOfAzerothDB.minimap = {} end
    if TonguesOfAzerothDB.minimap.hide == nil then TonguesOfAzerothDB.minimap.hide = false end
    if TonguesOfAzerothDB.minimap.angle == nil then TonguesOfAzerothDB.minimap.angle = 200 end
    if not TonguesOfAzerothDB.accent then TonguesOfAzerothDB.accent = {} end
    if TonguesOfAzerothDB.accent.enabled == nil then TonguesOfAzerothDB.accent.enabled = false end
    if TonguesOfAzerothDB.accent.strength == nil then TonguesOfAzerothDB.accent.strength = 100 end
    if TonguesOfAzerothDB.accent.id == nil or not (Accent and Accent.IsValid(TonguesOfAzerothDB.accent.id)) then
        TonguesOfAzerothDB.accent.id = (Accent and Accent.DEFAULT) or "dwarf"
    end
    return TonguesOfAzerothDB
end

local function refreshPreview()
    if not (previewInput and previewOutput) then return end
    local d = db()
    local src = previewInput:GetText()
    if src == "" then src = SAMPLE end
    previewOutput:SetText(Language.TranslateText(src, d.strength, d.language))
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
    if styleId == "whisper" then return "Whisper (purple line)" end
    return "Emote (yellow * line)"
end

local function RefreshMain()
    if not mainPanel then return end
    local d = db()
    enableCheck:SetChecked(d.enabled)
    if minimapCheck then minimapCheck:SetChecked(not d.minimap.hide) end
    langDropdown:SetSelected(d.language, Language.GetLanguageName(d.language))
    slider:SetValue(d.strength)
    valueText:SetText(d.strength .. "%")
    for ch, check in pairs(channelChecks) do
        check:SetChecked(d.channels[ch] and true or false)
    end
    refreshPreview()
end

local function RefreshLearned()
    if not learnedPanel then return end
    local d = db()
    for langId, check in pairs(learnedChecks) do
        check:SetChecked(d.learned[langId] and true or false)

        local base = Language.GetLanguageName(langId)
        local learnedWords, frac = 0, 0
        if ns.Trainer and ns.Trainer.GetProgress then
            learnedWords, _, frac = ns.Trainer.GetProgress(langId)
        end

        local bar = learnedBars[langId]
        if learnedWords and learnedWords > 0 then
            local rank, color = ns.Trainer.GetRank(frac)
            local hex = color and string.format("%02x%02x%02x",
                math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255)) or "9fd8ff"
            if check.labelText then
                check.labelText:SetText(string.format("%s  |cff%s(%s %d%%)|r",
                    base, hex, rank, math.floor(frac * 100 + 0.5)))
            end
            if bar then
                bar.fill:SetWidth(math.max(1, bar.barW * frac))
                if color then Compat.SolidTexture(bar.fill, color[1], color[2], color[3], 1) end
                bar.fill:Show()
            end
        else
            if check.labelText then check.labelText:SetText(base) end
            if bar then bar.fill:Hide() end
        end
    end
    decodeStyleDropdown:SetSelected(d.decodeStyle, decodeStyleLabel(d.decodeStyle))
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
        onTooltip = function(tt)
            tt:AddLine("Tongues of Azeroth")
            tt:AddLine("Language: |cffffffff" .. Language.GetLanguageName(d.language) .. "|r", 0.8, 0.8, 0.8)
            tt:AddLine("Auto-translate: " .. (d.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"), 0.8, 0.8, 0.8)
            tt:AddLine(" ")
            tt:AddLine("|cffffffffLeft-click|r  Open settings", 1, 1, 1)
            tt:AddLine("|cffffffffRight-click|r  Toggle auto-translate", 1, 1, 1)
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

    local langLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -18)
    langLabel:SetText("Language")

    langDropdown = Compat.CreateDropdown(mainPanel, 260)
    langDropdown:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    langDropdown:SetItems(langItems())
    langDropdown.onSelect = function(value)
        db().language = value
        langDropdown:SetSelected(value, Language.GetLanguageName(value))
        refreshPreview()
    end

    slider = Compat.CreateSlider(mainPanel, 0, 100, 1, "Strength", "0 - Plain", "100 - Full")
    slider:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 0, -34)
    slider:SetWidth(320)
    valueText = slider.valueText
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db().strength = value
        valueText:SetText(value .. "%")
        refreshPreview()
    end)

    local channelLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -24)
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
    subtitle:SetText("Check languages you understand. Decoding uses the same channel filters as the main panel.")

    local styleLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
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

    local langLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", decodeStyleDropdown, "BOTTOMLEFT", 0, -22)
    langLabel:SetText("Languages you understand")

    -- Footer note, pinned to the bottom so the scroll area can size against it.
    local note = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", learnedPanel, "BOTTOMLEFT", 16, 14)
    note:SetPoint("BOTTOMRIGHT", learnedPanel, "BOTTOMRIGHT", -28, 14)
    note:SetJustifyH("LEFT")
    note:SetText("Fluency (rank & %) is earned by solving words in the Language Trainer. Decoding works for text produced by Tongues of Azeroth; rare words may not reverse perfectly.")

    -- Scrollable list: fits every language (with a progress bar per row) inside
    -- the fixed window. Mouse-wheel scrolls; ScrollFrame clips overflow.
    local scroll = CreateFrame("ScrollFrame", "TonguesOfAzerothLearnedScroll", learnedPanel)
    scroll:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", note, "TOPRIGHT", 0, 10)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)

    -- Primary languages only; sub-languages share their parent's word set (and
    -- fluency), so learning/showing the parent covers them.
    local langs = Language.GetPrimaryLanguages()
    local ROW_H = 34
    local COLS = 2
    local CHILD_W = 540
    local COL_W = CHILD_W / COLS
    local rows = math.ceil(#langs / COLS)
    child:SetSize(CHILD_W, rows * ROW_H + 6)

    for i = 1, #langs do
        local entry = langs[i]
        local col = math.floor((i - 1) / rows)   -- column-major so columns stay balanced
        local row = (i - 1) % rows
        local x = col * COL_W
        local y = -(row * ROW_H)

        local check = Compat.CreateCheckbox(child, entry.name)
        check:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
        check:SetScript("OnClick", function(self)
            db().learned[entry.id] = self:GetChecked() and true or false
        end)
        learnedChecks[entry.id] = check

        -- Thin fluency bar beneath the label.
        local barW = COL_W - 44
        local bar = CreateFrame("Frame", nil, child)
        bar:SetSize(barW, 6)
        bar:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 26, -1)
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

local ACCENT_SAMPLE = "I cannot do this, my friend. Are you going to the meeting?"

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
    hint:SetText("Uses the same channels as the main panel. Auto-translate overrides accents, so turn it off (or set Language strength to 0%) to hear your accent.")

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

local function BuildPanels()
    if panelsBuilt then return end

    BuildMainPanel()
    Compat.RegisterOptionsPanel(mainPanel, mainPanel.name)

    BuildLearnedPanel()
    Compat.RegisterOptionsPanel(learnedPanel, learnedPanel.name, mainPanel.name)

    BuildAccentPanel()
    Compat.RegisterOptionsPanel(accentPanel, accentPanel.name, mainPanel.name)

    -- In the shared standalone window (legacy/custom clients), the sub-panels
    -- show a Back button (to the main panel) instead of their own close button.
    learnedPanel._backAction = function() ns.OpenConfig() end
    accentPanel._backAction = function() ns.OpenConfig() end

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
    end
end)

ns.OnSettingsChanged = function()
    if mainPanel and mainPanel:IsVisible() then RefreshMain() end
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
    if accentPanel and accentPanel:IsVisible() then RefreshAccent() end
end

-- Called by the trainer after a solve so fluency bars update live if the
-- Learned Languages panel happens to be open at the same time.
ns.RefreshLearnedIfShown = function()
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
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
