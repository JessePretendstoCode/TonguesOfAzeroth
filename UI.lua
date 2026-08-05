--[[-------------------------------------------------------------------------
    Tongues of Azeroth - UI.lua
    In-game configuration registered under Interface -> AddOns.
      * Main panel: enable, language, strength, channel filters, preview.
      * Learned Languages sub-panel: per-language checkboxes, decode display style.

    Settings apply live (written straight to SavedVariables). Uses only stock
    3.3.5a widgets.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language

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

local mainPanel, learnedPanel
local langDropdown, slider, valueText, enableCheck, previewInput, previewOutput
local channelChecks = {}
local learnedChecks = {}
local decodeStyleDropdown
local panelsBuilt = false

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
    return TonguesOfAzerothDB
end

local function refreshPreview()
    if not (previewInput and previewOutput) then return end
    local d = db()
    local src = previewInput:GetText()
    if src == "" then src = SAMPLE end
    previewOutput:SetText(Language.TranslateText(src, d.strength, d.language))
end

local function initLangDropdown()
    local d = db()
    local langs = Language.GetLanguages()
    for i = 1, #langs do
        local entry = langs[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.name
        info.value = entry.id
        info.checked = (entry.id == d.language)
        info.func = function()
            d.language = entry.id
            UIDropDownMenu_SetSelectedValue(langDropdown, entry.id)
            UIDropDownMenu_SetText(langDropdown, Language.GetLanguageName(entry.id))
            refreshPreview()
        end
        UIDropDownMenu_AddButton(info)
    end
end

local function decodeStyleLabel(styleId)
    if styleId == "whisper" then return "Whisper (purple line)" end
    return "Emote (yellow * line)"
end

local function initDecodeStyleDropdown()
    local d = db()
    local styles = {
        { id = "emote", name = "Emote (yellow * line)" },
        { id = "whisper", name = "Whisper (purple line)" },
    }
    for i = 1, #styles do
        local entry = styles[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.name
        info.value = entry.id
        info.checked = (entry.id == d.decodeStyle)
        info.func = function()
            d.decodeStyle = entry.id
            UIDropDownMenu_SetSelectedValue(decodeStyleDropdown, entry.id)
            UIDropDownMenu_SetText(decodeStyleDropdown, entry.name)
        end
        UIDropDownMenu_AddButton(info)
    end
end

local function RefreshMain()
    if not mainPanel then return end
    local d = db()
    enableCheck:SetChecked(d.enabled)
    UIDropDownMenu_SetSelectedValue(langDropdown, d.language)
    UIDropDownMenu_SetText(langDropdown, Language.GetLanguageName(d.language))
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
    end
    UIDropDownMenu_SetSelectedValue(decodeStyleDropdown, d.decodeStyle)
    UIDropDownMenu_SetText(decodeStyleDropdown, decodeStyleLabel(d.decodeStyle))
end

local function BuildMainPanel()
    mainPanel = CreateFrame("Frame", "TonguesOfAzerothOptions", InterfaceOptionsFramePanelContainer)
    mainPanel.name = "Tongues of Azeroth"
    mainPanel:Hide()

    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tongues of Azeroth")

    local subtitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Speak the languages of Azeroth in chat, Tongues-style.")

    enableCheck = CreateFrame("CheckButton", "TonguesOfAzerothEnable", mainPanel, "InterfaceOptionsCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    _G[enableCheck:GetName() .. "Text"]:SetText("Enable auto-translate in chat")
    enableCheck:SetScript("OnClick", function(self)
        db().enabled = self:GetChecked() and true or false
    end)

    local langLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -18)
    langLabel:SetText("Language")

    langDropdown = CreateFrame("Frame", "TonguesOfAzerothLangDropdown", mainPanel, "UIDropDownMenuTemplate")
    langDropdown:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(langDropdown, 260)
    UIDropDownMenu_Initialize(langDropdown, initLangDropdown)

    slider = CreateFrame("Slider", "TonguesOfAzerothSlider", mainPanel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 16, -40)
    slider:SetWidth(320)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    _G[slider:GetName() .. "Low"]:SetText("0 - Plain")
    _G[slider:GetName() .. "High"]:SetText("100 - Full")
    _G[slider:GetName() .. "Text"]:SetText("Strength")

    valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db().strength = value
        valueText:SetText(value .. "%")
        refreshPreview()
    end)

    local channelLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -16, -20)
    channelLabel:SetText("Channels")

    local channelHint = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -2)
    channelHint:SetPoint("RIGHT", mainPanel, "RIGHT", -32, 0)
    channelHint:SetJustifyH("LEFT")
    channelHint:SetText("Applies when you speak and when you listen.")

    local channelList = ns.CHANNEL_TYPES or {}
    local ROW_H = 20
    local COL2_X = 210
    local half = math.ceil(#channelList / 2)

    for i = 1, #channelList do
        local ch = channelList[i]
        local check = CreateFrame("CheckButton", "TonguesOfAzerothChannel_" .. ch, mainPanel, "InterfaceOptionsCheckButtonTemplate")
        local row, col
        if i <= half then
            row = i - 1
            col = 0
        else
            row = i - half - 1
            col = COL2_X
        end
        check:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", col, -4 - row * ROW_H)
        _G[check:GetName() .. "Text"]:SetText(CHANNEL_LABELS[ch] or ch)
        check:SetScript("OnClick", function(self)
            db().channels[ch] = self:GetChecked() and true or false
        end)
        channelChecks[ch] = check
    end

    local channelRows = half
    local previewLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -8 - channelRows * ROW_H)
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
    learnedPanel = CreateFrame("Frame", "TonguesOfAzerothLearnedOptions", mainPanel)
    learnedPanel.name = "Learned Languages"
    learnedPanel.parent = mainPanel.name
    learnedPanel:Hide()

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

    decodeStyleDropdown = CreateFrame("Frame", "TonguesOfAzerothDecodeStyle", learnedPanel, "UIDropDownMenuTemplate")
    decodeStyleDropdown:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(decodeStyleDropdown, 220)
    UIDropDownMenu_Initialize(decodeStyleDropdown, initDecodeStyleDropdown)

    local langLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", decodeStyleDropdown, "BOTTOMLEFT", 16, -24)
    langLabel:SetText("Languages you understand")

    local langs = Language.GetLanguages()
    local ROW_H = 20
    local COL2_X = 210
    local half = math.ceil(#langs / 2)

    for i = 1, #langs do
        local entry = langs[i]
        local check = CreateFrame("CheckButton", "TonguesOfAzerothLearned_" .. entry.id, learnedPanel, "InterfaceOptionsCheckButtonTemplate")
        local row, col
        if i <= half then
            row = i - 1
            col = 0
        else
            row = i - half - 1
            col = COL2_X
        end
        check:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", col, -4 - row * ROW_H)
        _G[check:GetName() .. "Text"]:SetText(entry.name)
        check:SetScript("OnClick", function(self)
            db().learned[entry.id] = self:GetChecked() and true or false
        end)
        learnedChecks[entry.id] = check
    end

    local langRows = half
    local note = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -8 - langRows * ROW_H)
    note:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Decoding only works for text produced by Tongues of Azeroth. Rare words may not reverse perfectly.")

    learnedPanel.refresh = RefreshLearned
    learnedPanel:SetScript("OnShow", RefreshLearned)
end

local function BuildPanels()
    if panelsBuilt then return end
    if not InterfaceOptionsFramePanelContainer then return end

    BuildMainPanel()
    InterfaceOptions_AddCategory(mainPanel)

    BuildLearnedPanel()
    InterfaceOptions_AddCategory(learnedPanel)

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
end)

ns.OnSettingsChanged = function()
    if mainPanel and mainPanel:IsVisible() then RefreshMain() end
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
end

function ns.OpenConfig()
    BuildPanels()
    if not mainPanel then return end
    if InterfaceAddOnsList_Update then InterfaceAddOnsList_Update() end
    InterfaceOptionsFrame_OpenToCategory(mainPanel)
    InterfaceOptionsFrame_OpenToCategory(mainPanel)
end

function ns.OpenLearnedConfig()
    BuildPanels()
    if not learnedPanel then return end
    if InterfaceAddOnsList_Update then InterfaceAddOnsList_Update() end
    InterfaceOptionsFrame_OpenToCategory(learnedPanel)
    InterfaceOptionsFrame_OpenToCategory(learnedPanel)
end
