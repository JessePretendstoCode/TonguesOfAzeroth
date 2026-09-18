--[[-------------------------------------------------------------------------
    Tongues of Azeroth - UI.lua
    In-game configuration registered under the game's AddOns options.
      * Main panel: enable, language, strength, channel filters, preview.
      * Learned Languages sub-panel: per-language checkboxes, decode display style.

    All widgets come from ns.Compat, so the same panel renders in the Settings
    tree and in our standalone window, with no reliance on UIDropDownMenu or
    templates that retail has removed.
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
local mainContent
local langDropdown, slider, valueText, enableCheck, previewInput, previewOutput
local minimapCheck, fluencyCheck, nativeHideCheck, autoDisableCheck
local widgetCheck, widgetLockCheck
local accentEnableCheck, accentDropdown, accentSlider, accentValueText
local accentTailSlider, accentTailValueText
local accentPreviewInput, accentPreviewOutput, accentEmotesCheck
local accentContent
local accentChannelChecks = {}
local customEditDropdown, customNameInput, customApostSlider, customApostText
local customOnsetInput, customNucleiInput, customCodaInput
local customPreviewInput, customPreviewOutput, customStatus, customEditingId
local customShareInput
local castPanel, castContent
local castEnableCheck, castPetCheck, castChanceSlider, castGapSlider, castSpellGapSlider
local castSpellDropdown, castMuteCheck, castNewInput, castNewLabel
local castPreviewText, castStatus, castAddRow, castEmptyNote
local castPackChecks = {}
local castPackBottom
local castCreedHeader, castCreedHint, castPackAnchor
local castBearingDropdown, castStreakDropdown, castWordingDropdown, castTalkDropdown
local castToneSummary
local castFilterSpellbookCheck, castShowOtherPacksCheck
local castRows = {}
local castSelectedKey
local castSpellEventsRegistered
local channelChecks = {}
local learnedRows = {}
local learnedBars = {}
local learnedOrder = {}
local learnedScroll, learnedChild, learnedRowH = nil, nil, 38
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
    TonguesOfAzerothDB.tagLanguage = true
    if TonguesOfAzerothDB.tagFluency == nil then TonguesOfAzerothDB.tagFluency = true end
    if not TonguesOfAzerothDB.accent then TonguesOfAzerothDB.accent = {} end
    if TonguesOfAzerothDB.accent.enabled == nil then TonguesOfAzerothDB.accent.enabled = false end
    if TonguesOfAzerothDB.accent.strength == nil then TonguesOfAzerothDB.accent.strength = 100 end
    if TonguesOfAzerothDB.accent.emotes == nil then TonguesOfAzerothDB.accent.emotes = false end
    if TonguesOfAzerothDB.hideNativeLanguages == nil then TonguesOfAzerothDB.hideNativeLanguages = true end
    if TonguesOfAzerothDB.autoDisableInInstances == nil then TonguesOfAzerothDB.autoDisableInInstances = true end
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
    -- List the languages you can speak. Sub-languages are grouped and indented
    -- under the primary whose word set they share. The dropdown scrolls, so the
    -- full list stays usable. Tongues your race already knows in-game are hidden
    -- here (unless that option is off) -- see ns.GetSpeakableLanguages.
    local all = (ns.GetSpeakableLanguages and ns.GetSpeakableLanguages()) or Language.GetLanguages()
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

    -- Every row carries a star: hollow until you click it. `toggle` is what
    -- tells the dropdown to draw one (see Compat.CreateDropdown).
    local function isFav(id)
        return (ns.IsFavorite and ns.IsFavorite(id)) and true or false
    end

    -- The main list, built first so we know whether it ends up with anything in
    -- it. A favorited language is left out of here entirely: it has moved up to
    -- the Favorites section, and listing it twice just invited the question of
    -- why the same tongue appears in two places.
    local rest = {}
    local emittedParent = {}
    for i = 1, #primaries do
        local p = primaries[i]
        local parentShown = not isFav(p.id)
        if parentShown then
            rest[#rest + 1] = { text = p.name, value = p.id, toggle = false }
        end
        -- Claimed either way, so the orphan pass below doesn't re-emit the subs
        -- of a primary we deliberately moved into Favorites.
        emittedParent[p.id] = true
        local subs = subsOf[p.id]
        if subs then
            for j = 1, #subs do
                local s = subs[j]
                if not isFav(s.id) then
                    -- Only indent when the parent row is actually above it.
                    rest[#rest + 1] = { text = (parentShown and "    " or "") .. s.name,
                                        value = s.id, toggle = false }
                end
            end
        end
    end

    -- Orphaned sub-languages: their parent primary is hidden (e.g. a Troll's
    -- Zandali is hidden by the race filter, but the tribal dialects Amani,
    -- Gurubashi and Drakkari should still be speakable). Emit them at the top
    -- level, in LANGUAGE_ORDER, so they don't vanish along with their parent.
    for i = 1, #all do
        local l = all[i]
        if l.sub and l.parent and not emittedParent[l.parent] and not isFav(l.id) then
            rest[#rest + 1] = { text = l.name, value = l.id, toggle = false }
        end
    end

    -- Your curated shortlist on top, in the order you built it, so the handful
    -- you actually speak aren't seventy rows down.
    local items = {}
    local favs = (ns.GetFavorites and ns.GetFavorites()) or {}
    local favRows = {}
    for i = 1, #favs do
        local id = favs[i]
        if not (ns.IsNativeLanguage and ns.IsNativeLanguage(id)) then
            favRows[#favRows + 1] =
                { text = Language.GetLanguageName(id), value = id, toggle = true }
        end
    end
    if #favRows > 0 then
        items[#items + 1] = { text = "Favorites", header = true }
        for i = 1, #favRows do items[#items + 1] = favRows[i] end
        -- Skipped when you've favorited everything, so the header can't be left
        -- sitting over an empty list.
        if #rest > 0 then items[#items + 1] = { text = "All languages", header = true } end
    end
    for i = 1, #rest do items[#items + 1] = rest[i] end
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

-- The "Lock the floating bar" checkbox only exists when the floating bar is on
-- (default off). When it's hidden, re-anchor the checkboxes below it straight
-- under "Show floating language bar" so we don't leave a dead ~28px gap -- that
-- reclaimed space keeps the whole panel inside the options safe zone.
local function layoutMainWidgetLock()
    if not (fluencyCheck and widgetCheck) then return end
    local d = db()
    local barOn = d.widget and d.widget.enabled and true or false
    fluencyCheck:ClearAllPoints()
    if barOn and widgetLockCheck then
        fluencyCheck:SetPoint("TOPLEFT", widgetLockCheck, "BOTTOMLEFT", -16, -6)
    else
        fluencyCheck:SetPoint("TOPLEFT", widgetCheck, "BOTTOMLEFT", 0, -6)
    end
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
    layoutMainWidgetLock()
    if fluencyCheck then fluencyCheck:SetChecked(d.tagFluency ~= false) end
    if nativeHideCheck then nativeHideCheck:SetChecked(d.hideNativeLanguages and true or false) end
    if autoDisableCheck then autoDisableCheck:SetChecked(d.autoDisableInInstances ~= false) end
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

    -- Size the scroll child to the actual bottom of the last element (accounts
    -- for the floating-bar lock row appearing/disappearing). Falls back to the
    -- generous default set at creation if geometry isn't ready yet.
    if mainContent and mainContent.SetContentHeight and mainPanel._lastChild then
        local top = mainContent:GetTop()
        local bot = mainPanel._lastChild:GetBottom()
        if top and bot and top > bot then
            mainContent:SetContentHeight(top - bot + 20)
        end
    end
end

-- Show only the languages your race can't already speak (when the option is on)
-- and re-flow the visible rows so there are no gaps, resizing the scroll child.
local function reflowLearnedRows()
    if not (learnedChild and #learnedOrder > 0) then return end
    local visible = 0
    for i = 1, #learnedOrder do
        local id = learnedOrder[i]
        local rowRef = learnedRows[id]
        local rowF = rowRef and rowRef.row
        if rowF then
            if ns.IsNativeLanguage and ns.IsNativeLanguage(id) then
                rowF:Hide()
            else
                rowF:ClearAllPoints()
                rowF:SetPoint("TOPLEFT", learnedChild, "TOPLEFT", 0, -(visible * learnedRowH))
                rowF:Show()
                visible = visible + 1
            end
        end
    end
    learnedChild:SetHeight(visible * learnedRowH + 6)
    if learnedScroll then
        local v = learnedScroll:GetVerticalScroll()
        local maxv = learnedScroll:GetVerticalScrollRange()
        if v > maxv then learnedScroll:SetVerticalScroll(maxv) end
    end
end

local function RefreshLearned()
    if not learnedPanel then return end
    local d = db()
    reflowLearnedRows()
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

-- The minimap button is driven through LibDBIcon (bundled) so it behaves exactly
-- like every other addon's button: correct placement AND collectable /
-- auto-hideable by minimap-button managers (SexyMap, etc.).
local ldbIcon
local LDB_NAME = "TonguesOfAzeroth"
-- Keep in step with `## IconTexture:` in the TOCs so the minimap button and the
-- addon list show the same scroll.
local ICON = "Interface\\Icons\\INV_Scroll_03"

local function ApplyMinimapShown()
    local hide = db().minimap.hide and true or false
    if ldbIcon then
        if hide then ldbIcon:Hide(LDB_NAME) else ldbIcon:Show(LDB_NAME) end
    elseif minimapButton then
        if hide then minimapButton:Hide() else minimapButton:Show() end
    end
end
ns.ApplyMinimapShown = ApplyMinimapShown

local function tooltipLines(tt)
    tt:AddLine("Tongues of Azeroth")
    tt:AddLine("Language: |cffffffff" .. Language.GetLanguageName(db().language) .. "|r", 0.8, 0.8, 0.8)
    tt:AddLine("Auto-translate: " .. (db().enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"), 0.8, 0.8, 0.8)
    tt:AddLine(" ")
    tt:AddLine("|cffffffffLeft-click|r  Open settings", 1, 1, 1)
    tt:AddLine("|cffffffffRight-click|r  Toggle auto-translate", 1, 1, 1)
    local favCount = (ns.GetFavorites and #ns.GetFavorites()) or 0
    tt:AddLine("|cffffffffScroll|r  Cycle " ..
        ((db().favOnly and favCount > 0) and "your favorites" or "learned languages"), 1, 1, 1)
end

local function setupLDBButton()
    if ldbIcon then return true end
    if not _G.LibStub then return false end
    local okI, iconLib = pcall(_G.LibStub, "LibDBIcon-1.0", true)
    local okD, ldb = pcall(_G.LibStub, "LibDataBroker-1.1", true)
    if not (okI and iconLib and okD and ldb) then return false end

    local obj = ldb.GetDataObjectByName and ldb:GetDataObjectByName(LDB_NAME)
    if not obj then
        local okObj, made = pcall(function()
            return ldb:NewDataObject(LDB_NAME, {
                type = "launcher",
                icon = ICON,
                OnClick = function(_, mouseButton)
                    if mouseButton == "RightButton" then
                        local d = db(); d.enabled = not d.enabled
                        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                    elseif ns.OpenConfig then
                        ns.OpenConfig()
                    end
                end,
                OnTooltipShow = tooltipLines,
            })
        end)
        if not okObj then return false end
        obj = made
    end

    -- db.minimap doubles as LibDBIcon's saved table (it uses .hide + .minimapPos).
    local okReg = pcall(function() iconLib:Register(LDB_NAME, obj, db().minimap) end)
    if not okReg then return false end
    ldbIcon = iconLib

    -- LibDBIcon doesn't wire the mouse wheel, so add scroll-to-cycle ourselves.
    local btn = iconLib.GetMinimapButton and iconLib:GetMinimapButton(LDB_NAME)
    if btn then
        btn:EnableMouseWheel(true)
        btn:SetScript("OnMouseWheel", function(_, delta)
            if ns.CycleLanguage then ns.CycleLanguage(delta > 0 and 1 or -1) end
        end)
    end
    return true
end

local function SetupMinimapButton()
    local d = db()
    if setupLDBButton() then
        ApplyMinimapShown()
        return
    end

    -- Safety net for when the bundled libs are unavailable (a stripped install, or
    -- LibStub losing a fight with another addon's copy): a dependency-free button,
    -- using a built-in Blizzard icon so it renders without loose texture files.
    if minimapButton then ApplyMinimapShown(); return end
    minimapButton = Compat.CreateMinimapButton("TonguesOfAzerothMinimapButton", {
        icon = ICON,
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
            tooltipLines(tt)
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
    if langWidget.fav then
        -- Filled only when the toggle is on AND there's a list to walk, so the
        -- star never claims a filter is active when it can't be.
        local n = (ns.GetFavorites and #ns.GetFavorites()) or 0
        Compat.SetStar(langWidget.fav.tex, d.favOnly and n > 0)
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

-- Right-click language menu for the floating widget. A self-contained popup (own
-- frame + full-screen click-catcher to close on outside click); no Blizzard
-- globals / UIDropDownMenu, so it renders everywhere and stays taint-free.
local widgetMenu
local openWidgetMenu

local function closeWidgetMenu()
    if widgetMenu then widgetMenu:Hide() end
end

openWidgetMenu = function()
    if not langWidget then return end
    if not widgetMenu then
        local m = CreateFrame("Frame", "TonguesOfAzerothLangMenu", UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetFrameLevel(60)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m:EnableMouseWheel(true)
        local bg = m:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.04, 0.04, 0.06, 0.97)
        Compat.AddBorder(m, 0.5, 0.45, 0.7, 0.95)
        m.langRows = {}   -- scrollable language list
        m.footRows = {}   -- pinned footer (auto-translate + settings)
        m.offset = 0
        -- Full-screen catcher behind the menu: any click outside a row closes it.
        local closer = CreateFrame("Button", nil, UIParent)
        closer:SetFrameStrata("FULLSCREEN_DIALOG")
        closer:SetFrameLevel(55)
        closer:SetAllPoints(UIParent)
        closer:RegisterForClicks("AnyUp")
        closer:SetScript("OnClick", function() m:Hide() end)
        closer:Hide()
        m.closer = closer
        m:SetScript("OnHide", function() closer:Hide() end)
        m:SetScript("OnMouseWheel", function(self, delta) if self.Scroll then self:Scroll(delta) end end)
        widgetMenu = m
    end

    local m = widgetMenu
    local d = db()
    local W, RH, PAD, DIV, MAXV = 190, 22, 6, 8, 10

    local function makeRow(pool, i)
        local r = pool[i]
        if not r then
            r = CreateFrame("Button", nil, m)
            r:SetHeight(RH)
            r:EnableMouseWheel(true)
            local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            t:SetPoint("LEFT", 10, 0); t:SetPoint("RIGHT", -10, 0); t:SetJustifyH("LEFT")
            r.text = t
            local h = r:CreateTexture(nil, "HIGHLIGHT"); h:SetAllPoints()
            Compat.SolidTexture(h, 1, 1, 1, 0.18)
            r:SetScript("OnMouseWheel", function(_, delta) if m.Scroll then m:Scroll(delta) end end)
            pool[i] = r
        end
        return r
    end

    local items = langItems()   -- full grouped list (every language), same as main dropdown
    local total = #items
    local visible = math.max(1, math.min(total, MAXV))
    local maxOffset = math.max(0, total - visible)

    -- Open scrolled so the active language is already in view.
    m.offset = 0
    for i = 1, total do
        if items[i].value == d.language then
            m.offset = i - math.floor(visible / 2) - 1
            break
        end
    end
    if m.offset < 0 then m.offset = 0 end
    if m.offset > maxOffset then m.offset = maxOffset end

    local function renderLangs()
        for i = 1, #m.langRows do m.langRows[i]:Hide() end
        for slot = 1, visible do
            local item = items[m.offset + slot]
            if item then
                local r = makeRow(m.langRows, slot)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -PAD - (slot - 1) * RH)
                r:SetPoint("RIGHT", m, "RIGHT", -4, 0)
                local isCur = (item.value == d.language)
                r.text:SetText(item.text)
                if isCur then r.text:SetTextColor(0.4, 0.85, 0.4) else r.text:SetTextColor(0.9, 0.9, 0.9) end
                r:SetScript("OnClick", function()
                    db().language = item.value
                    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                    closeWidgetMenu()
                end)
                r:Show()
            end
        end
    end

    function m:Scroll(delta)
        if total <= visible then return end
        self.offset = self.offset - delta   -- wheel up = earlier entries
        if self.offset < 0 then self.offset = 0 end
        if self.offset > maxOffset then self.offset = maxOffset end
        renderLangs()
    end

    renderLangs()

    -- Footer pinned below the (scrollable) language list.
    local footTop = PAD + visible * RH + DIV
    for i = 1, #m.footRows do m.footRows[i]:Hide() end

    if not m.divider then
        local dv = m:CreateTexture(nil, "ARTWORK")
        Compat.SolidTexture(dv, 0.4, 0.38, 0.55, 0.8)
        dv:SetHeight(1)
        m.divider = dv
    end
    m.divider:ClearAllPoints()
    m.divider:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -(PAD + visible * RH + DIV / 2))
    m.divider:SetPoint("TOPRIGHT", m, "TOPRIGHT", -6, -(PAD + visible * RH + DIV / 2))

    local rAuto = makeRow(m.footRows, 1)
    rAuto:ClearAllPoints()
    rAuto:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -footTop)
    rAuto:SetPoint("RIGHT", m, "RIGHT", -4, 0)
    rAuto.text:SetText(d.enabled and "Auto-translate: |cff66dd66ON|r" or "Auto-translate: |cffdd6666OFF|r")
    rAuto:SetScript("OnClick", function()
        local dd = db(); dd.enabled = not dd.enabled
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        openWidgetMenu()
    end)
    rAuto:Show()

    local rSet = makeRow(m.footRows, 2)
    rSet:ClearAllPoints()
    rSet:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -(footTop + RH))
    rSet:SetPoint("RIGHT", m, "RIGHT", -4, 0)
    rSet.text:SetText("Open settings...")
    rSet:SetScript("OnClick", function()
        closeWidgetMenu()
        if ns.OpenConfig then ns.OpenConfig() end
    end)
    rSet:Show()

    m:SetSize(W, footTop + 2 * RH + PAD)
    m:ClearAllPoints()
    m:SetPoint("BOTTOM", langWidget, "TOP", 0, 4)
    m.closer:Show()
    m:Show()
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
        -- Shifted left to clear the favorites star in the corner.
        dot:SetPoint("BOTTOMRIGHT", -24, 6)
        f.dot = dot

        -- "Scroll only my favorites" toggle. Its own button so clicking the
        -- star doesn't fall through to the frame's cycle-on-click, and it
        -- forwards the wheel so scrolling over it still cycles.
        local fav = CreateFrame("Button", nil, f)
        fav:SetSize(14, 14)
        fav:SetPoint("BOTTOMRIGHT", -5, 5)
        fav:SetFrameLevel(f:GetFrameLevel() + 2)
        fav:EnableMouseWheel(true)
        fav:SetScript("OnMouseWheel", function(_, delta)
            if ns.CycleLanguage then ns.CycleLanguage(delta > 0 and 1 or -1) end
        end)
        fav.tex = fav:CreateTexture(nil, "ARTWORK")
        fav.tex:SetAllPoints()
        local favHl = fav:CreateTexture(nil, "HIGHLIGHT")
        favHl:SetAllPoints()
        Compat.SolidTexture(favHl, 1, 1, 1, 0.25)
        fav:SetScript("OnClick", function()
            local d2 = db()
            d2.favOnly = not d2.favOnly
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        end)
        fav:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Scroll only my favorites", 1, 1, 1)
            local n = (ns.GetFavorites and #ns.GetFavorites()) or 0
            if n == 0 then
                GameTooltip:AddLine(
                    "No favorites yet. Click the star beside a language in the dropdown.",
                    0.8, 0.8, 0.8, true)
            elseif db().favOnly then
                GameTooltip:AddLine("On: scrolling walks your " .. n .. " favorite" ..
                    (n == 1 and "" or "s") .. ".", 0.4, 0.9, 0.4, true)
            else
                GameTooltip:AddLine("Off: scrolling walks everything you've learned.",
                    0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        fav:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.fav = fav

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
                if widgetMenu and widgetMenu:IsShown() then closeWidgetMenu() else openWidgetMenu() end
            end
        end)
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Tongues of Azeroth", 1, 1, 1)
            GameTooltip:AddLine("Language: |cffffffff" .. Language.GetLanguageName(db().language) .. "|r", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffLeft-click|r  Next language", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffScroll|r  Cycle languages", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffStar|r  Scroll only favorites", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffShift-click|r  Toggle auto-translate", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffRight-click|r  Language menu", 1, 1, 1)
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

    -- Everything lives inside a scroll region so the panel never spills outside
    -- the options window, no matter how tall the layout gets. Anchor children to
    -- `content` (the scroll child), not to mainPanel.
    local content = Compat.CreateScrollContent(mainPanel, 760)
    mainContent = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tongues of Azeroth")

    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Speak the languages of Azeroth in chat, Tongues-style.")

    -- Persistent heads-up: the instance chat restriction is a Blizzard limitation,
    -- not an addon bug. Kept near the top so it's the first thing players see.
    local instanceNote = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    instanceNote:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    instanceNote:SetPoint("RIGHT", content, "RIGHT", -170, 0)
    instanceNote:SetJustifyH("LEFT")
    if instanceNote.SetWordWrap then instanceNote:SetWordWrap(true) end
    instanceNote:SetText("|cffffd200Heads-up:|r During boss fights, Blizzard blocks addons from reading chat, so ToA can't translate or decode inside instances. This is a game restriction, not a bug -- see the option below. Accents are unaffected and keep working there.")

    local function makeNavButton(label, onClick)
        local btn = CreateFrame("Button", nil, content)
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
    trainerBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -16, -16)

    -- Opens the Learned Languages panel. Kept as an explicit button so the
    -- sub-panel is reachable from the standalone window too, which has no
    -- options tree to navigate.
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

    local castBtn = makeNavButton("Cast Phrases", function()
        if ns.OpenCastConfig then ns.OpenCastConfig() end
    end)
    castBtn:SetPoint("TOPRIGHT", customBtn, "BOTTOMRIGHT", 0, -4)

    enableCheck = Compat.CreateCheckbox(content, "Enable auto-translate in chat")
    enableCheck:SetPoint("TOPLEFT", instanceNote, "BOTTOMLEFT", 0, -16)
    enableCheck:SetScript("OnClick", function(self)
        db().enabled = self:GetChecked() and true or false
    end)

    minimapCheck = Compat.CreateCheckbox(content, "Show minimap button")
    minimapCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -8)
    minimapCheck:SetScript("OnClick", function(self)
        db().minimap.hide = not self:GetChecked()
        ApplyMinimapShown()
    end)

    widgetCheck = Compat.CreateCheckbox(content, "Show floating language bar")
    widgetCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -8)
    widgetCheck:SetScript("OnClick", function(self)
        db().widget.enabled = self:GetChecked() and true or false
        if not db().widget.enabled then closeWidgetMenu() end
        SetupLanguageWidget()
        if widgetLockCheck then widgetLockCheck:SetShown(db().widget.enabled) end
        layoutMainWidgetLock()
    end)

    widgetLockCheck = Compat.CreateCheckbox(content, "Lock the floating bar in place")
    widgetLockCheck:SetPoint("TOPLEFT", widgetCheck, "BOTTOMLEFT", 16, -6)
    widgetLockCheck:SetScript("OnClick", function(self)
        db().widget.locked = self:GetChecked() and true or false
    end)

    -- The [Language] tag itself is always on (it's what lets other players decode
    -- your speech reliably), so it isn't exposed as a setting. Only the optional
    -- fluency adjective prefix is configurable.
    fluencyCheck = Compat.CreateCheckbox(content, "Show fluency in tag (e.g. [Broken Orcish])")
    fluencyCheck:SetPoint("TOPLEFT", widgetLockCheck, "BOTTOMLEFT", -16, -8)
    fluencyCheck:SetScript("OnClick", function(self)
        db().tagFluency = self:GetChecked() and true or false
        refreshPreview()
    end)

    nativeHideCheck = Compat.CreateCheckbox(content, "Hide languages my race already speaks")
    nativeHideCheck:SetPoint("TOPLEFT", fluencyCheck, "BOTTOMLEFT", 0, -8)
    nativeHideCheck:SetScript("OnClick", function(self)
        db().hideNativeLanguages = self:GetChecked() and true or false
        if ns.EnsureSpeakLanguageVisible then ns.EnsureSpeakLanguageVisible() end
        -- Rebuilds the dropdown item list (and refreshes the panel) so the change
        -- shows immediately.
        if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshMain() end
    end)

    autoDisableCheck = Compat.CreateCheckbox(content, "Pause translation during instances")
    autoDisableCheck:SetPoint("TOPLEFT", nativeHideCheck, "BOTTOMLEFT", 0, -8)
    autoDisableCheck:SetScript("OnClick", function(self)
        db().autoDisableInInstances = self:GetChecked() and true or false
        -- Apply immediately if we're already inside an instance.
        if ns.RefreshInstanceState then ns.RefreshInstanceState() end
    end)

    local langLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", autoDisableCheck, "BOTTOMLEFT", 0, -16)
    langLabel:SetText("Language")

    langDropdown = Compat.CreateDropdown(content, 260)
    langDropdown:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    langDropdown:SetItems(langItems())
    langDropdown.onSelect = function(value)
        db().language = value
        -- Refresh the whole panel so the Fluency slider snaps to the newly
        -- selected language's fluency.
        RefreshMain()
    end
    -- Clicking a row's star favorites it without selecting the row or shutting
    -- the menu, so a shortlist can be built in one pass down the list. Right-
    -- click anywhere on a row does the same, for anyone who'd rather not aim at
    -- a 16px star.
    local function toggleFav(value)
        if ns.ToggleFavorite then ns.ToggleFavorite(value) end
        RefreshMain()
    end
    langDropdown.onToggle = toggleFav
    langDropdown.onAltClick = toggleFav

    -- No star or cycle button out here: favoriting belongs on the rows, and
    -- cycling is on the floating bar, the minimap wheel and /toa next.

    slider = Compat.CreateSlider(content, 0, 100, 1, "Fluency", "0 - None", "100 - Fluent")
    slider:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 0, -28)
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
    local fluencyHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fluencyHint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -20)
    fluencyHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    fluencyHint:SetJustifyH("LEFT")
    if fluencyHint.SetWordWrap then fluencyHint:SetWordWrap(true) end
    fluencyHint:SetText("How well you speak this tongue -- higher fluency = more of it comes through. Build it by hearing it, in the Trainer, or per-language under Learned Languages.")

    local channelLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", fluencyHint, "BOTTOMLEFT", 0, -14)
    channelLabel:SetText("Channels")

    local channelHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -2)
    channelHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    channelHint:SetJustifyH("LEFT")
    channelHint:SetText("Applies when you speak and when you listen.")

    local channelList = ns.CHANNEL_TYPES or {}
    local ROW_H = 24
    local COL2_X = 210
    local half = math.ceil(#channelList / 2)

    for i = 1, #channelList do
        local ch = channelList[i]
        local check = Compat.CreateCheckbox(content, CHANNEL_LABELS[ch] or ch)
        local row, col
        if i <= half then
            row = i - 1
            col = 0
        else
            row = i - half - 1
            col = COL2_X
        end
        check:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", col, -6 - row * ROW_H)
        check:SetScript("OnClick", function(self)
            db().channels[ch] = self:GetChecked() and true or false
        end)
        channelChecks[ch] = check
    end

    local channelRows = half
    local previewLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -12 - channelRows * ROW_H)
    previewLabel:SetText("Preview (type to test):")

    previewInput = CreateFrame("EditBox", "TonguesOfAzerothPreviewInput", content, "InputBoxTemplate")
    previewInput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    previewInput:SetSize(320, 20)
    previewInput:SetAutoFocus(false)
    previewInput:SetText(SAMPLE)
    previewInput:SetScript("OnTextChanged", refreshPreview)
    previewInput:SetScript("OnEnterPressed", previewInput.ClearFocus)
    previewInput:SetScript("OnEscapePressed", previewInput.ClearFocus)

    previewOutput = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    previewOutput:SetPoint("TOPLEFT", previewInput, "BOTTOMLEFT", -6, -8)
    previewOutput:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    previewOutput:SetJustifyH("LEFT")
    previewOutput:SetHeight(36)
    previewOutput:SetSpacing(2)
    -- Remember the last element so the scroll height can be sized to it exactly.
    mainPanel._lastChild = previewOutput

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

    -- Bulk "Learn all" / "Reset all" buttons on the list header row, both gated
    -- behind a confirmation.
    local function textButton(parent, w, label, rr, gg, bb)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(w, 22)
        local bbg = b:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints()
        Compat.SolidTexture(bbg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(b, rr or 0.5, gg or 0.45, bb or 0.7, 0.9)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.15)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER"); t:SetText(label)
        b.label = t
        return b
    end

    local learnAllBtn = textButton(learnedPanel, 84, "Learn all", 0.4, 0.6, 0.4)
    learnAllBtn:SetPoint("LEFT", langLabel, "RIGHT", 20, 0)
    learnAllBtn:SetScript("OnClick", function()
        Compat.ShowConfirm({
            text = "Become fully fluent in ALL languages?\n\nThis instantly sets every language to 100% -- you'll speak and understand all of them perfectly.",
            onAccept = function() if ns.MakeAllFluent then ns.MakeAllFluent() end end,
        })
    end)

    local resetAllBtn = textButton(learnedPanel, 84, "Reset all", 0.7, 0.4, 0.4)
    resetAllBtn:SetPoint("LEFT", learnAllBtn, "RIGHT", 8, 0)
    resetAllBtn:SetScript("OnClick", function()
        Compat.ShowConfirm({
            text = "Reset ALL languages to 0%?\n\nThis wipes your fluency and every word you've unlocked across all tongues. This cannot be undone.",
            onAccept = function() if ns.ResetAllFluency then ns.ResetAllFluency() end end,
        })
    end)

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
    learnedScroll, learnedChild = scroll, child

    -- Build a row for every primary language once; sub-languages share their
    -- parent's word set (and fluency), so the parent covers them. Rows for
    -- tongues your race natively speaks are hidden/re-flowed in RefreshLearned.
    local langs = Language.GetPrimaryLanguages()
    local ROW_H = 38
    learnedRowH = ROW_H
    local CHILD_W = 560
    child:SetSize(CHILD_W, #langs * ROW_H + 6)
    wipe(learnedOrder)

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

        learnedRows[entry.id] = { name = name, bar = bar, fluentBtn = fluentBtn, row = rowF }
        learnedOrder[#learnedOrder + 1] = entry.id
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
    accentPreviewOutput:SetText(Accent.Apply(src, d.accent.id, d.accent.strength, d.accent.emotes))
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
    local tails = d.accent.tails or Accent.TAIL_DIAL_DEFAULT
    if accentTailSlider then accentTailSlider:SetValue(tails) end
    if accentTailValueText then accentTailValueText:SetText(Accent.DescribeTailFrequency(tails)) end
    if accentEmotesCheck then accentEmotesCheck:SetChecked(d.accent.emotes) end
    local chans = d.accent.channels or {}
    for ch, check in pairs(accentChannelChecks) do
        check:SetChecked(chans[ch] ~= false)
    end
    refreshAccentPreview()

    -- Size the scroll child to the last element so the panel fits its window.
    if accentContent and accentContent.SetContentHeight and accentPanel._lastChild then
        local top = accentContent:GetTop()
        local bot = accentPanel._lastChild:GetBottom()
        if top and bot and top > bot then
            accentContent:SetContentHeight(top - bot + 20)
        end
    end
end

local function BuildAccentPanel()
    accentPanel = Compat.CreateOptionsPanel("TonguesOfAzerothAccentOptions")
    accentPanel.name = "Accents"
    accentPanel.parent = mainPanel.name

    -- Scrollable so the channel grid + preview always fit the options window.
    local content = Compat.CreateScrollContent(accentPanel, 700)
    accentContent = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Accents")

    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Flavor your English with a spoken dialect, e.g. Dwarven \"I cannae do this, aye!\" or Troll \"da voodoo, mon.\"")

    accentEnableCheck = Compat.CreateCheckbox(content, "Speak with an accent")
    accentEnableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    accentEnableCheck:SetScript("OnClick", function(self)
        db().accent.enabled = self:GetChecked() and true or false
    end)

    local hint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", accentEnableCheck, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    hint:SetJustifyH("LEFT")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    hint:SetText("Auto-translate overrides accents whenever you have any fluency in the spoken tongue, so turn auto-translate off (or speak a language you're 0% fluent in) to hear your accent. Text in (parentheses) is always left as plain speech.")

    local accentLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    accentLabel:SetText("Accent")

    accentDropdown = Compat.CreateDropdown(content, 260)
    accentDropdown:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -6)
    accentDropdown:SetItems(accentItems())
    accentDropdown.onSelect = function(value)
        db().accent.id = value
        accentDropdown:SetSelected(value, Accent.GetAccentName(value))
        refreshAccentPreview()
    end

    accentSlider = Compat.CreateSlider(content, 0, 100, 1, "Strength", "0 - Subtle", "100 - Thick")
    accentSlider:SetPoint("TOPLEFT", accentDropdown, "BOTTOMLEFT", 0, -34)
    accentSlider:SetWidth(320)
    accentValueText = accentSlider.valueText
    accentSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db().accent.strength = value
        accentValueText:SetText(value .. "%")
        refreshAccentPreview()
    end)

    accentTailSlider = Compat.CreateSlider(content, 0, 100, 1, "Interjections", "0 - Off", "100 - Often")
    accentTailSlider:SetPoint("TOPLEFT", accentSlider, "BOTTOMLEFT", 0, -34)
    accentTailSlider:SetWidth(320)
    accentTailValueText = accentTailSlider.valueText
    accentTailSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        db().accent.tails = value
        Accent.SetTailFrequency(value)
        accentTailValueText:SetText(Accent.DescribeTailFrequency(value))
        refreshAccentPreview()
    end)

    local tailHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    -- -34, the same gap used between the two sliders above: a slider's
    -- Off/value/Often labels hang below its frame rather than inside it, so a
    -- smaller offset lands this text on top of them.
    tailHint:SetPoint("TOPLEFT", accentTailSlider, "BOTTOMLEFT", 0, -34)
    tailHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    tailHint:SetJustifyH("LEFT")
    tailHint:SetText("How often a line ends with a flourish like \", aye.\" They are also "
        .. "spaced out, skipped on short lines and kept off questions, so they turn up "
        .. "less often in chat than in this preview.")

    accentEmotesCheck = Compat.CreateCheckbox(content, "Also apply accent to emotes (/e and inline *actions*)")
    accentEmotesCheck:SetPoint("TOPLEFT", tailHint, "BOTTOMLEFT", 0, -20)
    accentEmotesCheck:SetScript("OnClick", function(self)
        db().accent.emotes = self:GetChecked() and true or false
        refreshAccentPreview()
    end)

    -- Per-channel accent toggles (independent of the main panel's channels).
    local channelLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", accentEmotesCheck, "BOTTOMLEFT", 0, -14)
    channelLabel:SetText("Accent channels")

    local channelHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -2)
    channelHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    channelHint:SetJustifyH("LEFT")
    channelHint:SetText("Which chat channels your accent applies to (e.g. turn it off for raid/party).")

    local channelList = ns.CHANNEL_TYPES or {}
    local ROW_H = 24
    local COL2_X = 210
    local half = math.ceil(#channelList / 2)
    wipe(accentChannelChecks)
    for i = 1, #channelList do
        local ch = channelList[i]
        local check = Compat.CreateCheckbox(content, CHANNEL_LABELS[ch] or ch)
        local row, col
        if i <= half then row, col = i - 1, 0 else row, col = i - half - 1, COL2_X end
        check:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", col, -6 - row * ROW_H)
        check:SetScript("OnClick", function(self)
            local d = db()
            d.accent.channels = d.accent.channels or {}
            d.accent.channels[ch] = self:GetChecked() and true or false
        end)
        accentChannelChecks[ch] = check
    end

    local channelRows = half
    local previewLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -12 - channelRows * ROW_H)
    previewLabel:SetText("Preview (type to test):")

    accentPreviewInput = CreateFrame("EditBox", "TonguesOfAzerothAccentPreviewInput", content, "InputBoxTemplate")
    accentPreviewInput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    accentPreviewInput:SetSize(320, 20)
    accentPreviewInput:SetAutoFocus(false)
    accentPreviewInput:SetText(ACCENT_SAMPLE)
    accentPreviewInput:SetScript("OnTextChanged", refreshAccentPreview)
    accentPreviewInput:SetScript("OnEnterPressed", accentPreviewInput.ClearFocus)
    accentPreviewInput:SetScript("OnEscapePressed", accentPreviewInput.ClearFocus)

    accentPreviewOutput = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    accentPreviewOutput:SetPoint("TOPLEFT", accentPreviewInput, "BOTTOMLEFT", -6, -12)
    accentPreviewOutput:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    accentPreviewOutput:SetJustifyH("LEFT")
    accentPreviewOutput:SetHeight(36)
    accentPreviewOutput:SetSpacing(2)
    accentPanel._lastChild = accentPreviewOutput

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

--=========================================================================--
--  Cast Phrases
--=========================================================================--
-- One spell at a time: pick it from the list (or press the keybind while
-- hovering it on your bars), then edit the lines it can speak. Phrases from an
-- opted-in library pack sit in the same list as your own, because from the
-- player's side there's no difference worth showing -- they differ only in that
-- a pack line can be retired to weight 0 but not deleted.

local Casts = ns.Casts

local function castDB()
    local d = db()
    return d and d.casts
end

local function castStatusMsg(msg, isError)
    if not castStatus then return end
    castStatus:SetText(msg or "")
    if isError then
        castStatus:SetTextColor(1, 0.4, 0.4)
    else
        castStatus:SetTextColor(0.6, 1, 0.6)
    end
end

local function toneOptionName(list, id)
    if id == "" then return "None" end
    for _, opt in ipairs(list) do
        if opt.id == id then return opt.name end
    end
    return id
end

local function toneDropdownItems(list, includeNone)
    local items = {}
    if includeNone then
        items[#items + 1] = {
            text = "None",
            value = "",
            desc = "No secondary streak -- one Bearing is enough.",
        }
    end
    for _, opt in ipairs(list) do
        items[#items + 1] = { text = opt.name, value = opt.id, desc = opt.desc }
    end
    return items
end

local function bindDropdownDesc(dd, items)
    dd:HookScript("OnEnter", function()
        local val = dd:GetValue()
        for _, it in ipairs(items) do
            if it.value == val and it.desc then
                GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
                GameTooltip:AddLine(it.desc, 1, 1, 1, true)
                GameTooltip:Show()
                return
            end
        end
    end)
    dd:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function castSpellbookSet()
    local names = Compat.GetSpellbookNames()
    if not names then return nil, {} end
    local set = {}
    for _, name in ipairs(names) do
        local key = Casts.Key(name)
        if key then set[key] = name end
    end
    return names, set
end

local function castSpellItems()
    local items = {}
    if not Casts then return items end

    local c = castDB()
    local _, spellbookSet = castSpellbookSet()
    local canFilter = spellbookSet and next(spellbookSet) ~= nil
        and c and c.filterSpellbook ~= false

    local configuredSet = {}
    local configured = {}
    for _, key in ipairs(Casts.GetKeys()) do
        local keep = true
        if canFilter and not c.spells[key] and not spellbookSet[key] then
            keep = false
        end
        if keep then
            configured[#configured + 1] = key
            configuredSet[key] = true
        end
    end

    if #configured > 0 then
        items[#items + 1] = { text = "Configured", header = true }
        for _, key in ipairs(configured) do
            local label = Casts.DisplayName(key)
            if Casts.IsMuted(key) then
                label = label .. " |cff808080(muted)|r"
            end
            items[#items + 1] = { text = label, value = key }
        end
    end

    local spellbook = select(1, castSpellbookSet())
    if spellbook then
        local yours = {}
        for _, name in ipairs(spellbook) do
            local key = Casts.Key(name)
            if key and not configuredSet[key] then
                yours[#yours + 1] = { name = name, key = key }
            end
        end
        if #yours > 0 then
            items[#items + 1] = { text = "Your spells", header = true }
            for _, entry in ipairs(yours) do
                items[#items + 1] = { text = entry.name, value = entry.key }
            end
        end
    end

    if #items == 0 then
        items[1] = { text = "|cff808080No spells yet|r", value = nil, header = true }
    end
    return items
end

local function noteSpellKey(key)
    if not key then return end
    local _, spellbookSet = castSpellbookSet()
    if spellbookSet and spellbookSet[key] then
        Casts.NoteSpellName(spellbookSet[key])
    else
        Casts.NoteSpellName(Casts.DisplayName(key))
    end
end

local function phraseToneLabel(phrase)
    if phrase.user then return "" end
    local parts = {}
    if phrase.bearing then
        parts[#parts + 1] = toneOptionName(Casts.BEARINGS, phrase.bearing)
    end
    if phrase.wording then
        parts[#parts + 1] = toneOptionName(Casts.WORDINGS, phrase.wording)
    end
    if #parts == 0 then return "" end
    return table.concat(parts, " · ")
end

local function layoutCastPacks()
    if not (castPackAnchor and castPackBottom) then return end
    local c = castDB()
    local showOther = c and c.showOtherPacks
    local mine = ns.CastLibrary and ns.CastLibrary.PackForPlayer()
    local packs = (ns.CastLibrary and ns.CastLibrary.GetPacks()) or {}

    local mainList, creedList = {}, {}
    for _, pack in ipairs(packs) do
        local check = castPackChecks[pack.id]
        if check then
            if pack.kind == "creed" then
                creedList[#creedList + 1] = check
            elseif pack.kind == "universal" or pack.id == mine
                or (pack.kind == "class" and showOther) then
                mainList[#mainList + 1] = check
                check:Show()
            else
                check:Hide()
            end
        end
    end

    local colAnchor = castPackAnchor
    local bottom = castPackAnchor
    for i, check in ipairs(mainList) do
        check:ClearAllPoints()
        if i == 1 then
            check:SetPoint("TOPLEFT", castPackAnchor, "BOTTOMLEFT", 0, -8)
        elseif i % 2 == 1 then
            check:SetPoint("TOPLEFT", colAnchor, "BOTTOMLEFT", 0, -2)
        else
            check:SetPoint("TOPLEFT", colAnchor, "TOPLEFT", 240, 0)
        end
        if i % 2 == 1 then colAnchor = check end
        bottom = check
    end
    if castCreedHeader and #creedList > 0 then
        castCreedHeader:ClearAllPoints()
        castCreedHeader:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", 0, -16)
        castCreedHeader:Show()
        castCreedHint:ClearAllPoints()
        castCreedHint:SetPoint("TOPLEFT", castCreedHeader, "BOTTOMLEFT", 0, -4)
        castCreedHint:Show()
        bottom = castCreedHint
        colAnchor = castCreedHint
        for i, check in ipairs(creedList) do
            check:Show()
            check:ClearAllPoints()
            if i == 1 then
                check:SetPoint("TOPLEFT", castCreedHint, "BOTTOMLEFT", 0, -8)
            elseif i % 2 == 1 then
                check:SetPoint("TOPLEFT", colAnchor, "BOTTOMLEFT", 0, -2)
            else
                check:SetPoint("TOPLEFT", colAnchor, "TOPLEFT", 240, 0)
            end
            if i % 2 == 1 then colAnchor = check end
            bottom = check
        end
    elseif castCreedHeader then
        castCreedHeader:Hide()
        castCreedHint:Hide()
        for _, check in ipairs(creedList) do check:Hide() end
    end

    castPackBottom:ClearAllPoints()
    castPackBottom:SetPoint("TOPLEFT", bottom, "BOTTOMLEFT", 0, 0)
end

-- Rows are created once and reused, so switching between a spell with two
-- phrases and one with twelve doesn't leak frames.
local function castRow(index, parent)
    if castRows[index] then return castRows[index] end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)

    local function tinyButton(label, width)
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(width or 18, 18)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(btn, 0.5, 0.45, 0.7, 0.9)
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", 0, 0)
        t:SetText(label)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.12)
        btn.label = t
        return btn
    end

    -- A pair of nudge buttons rather than a slider: at 22px tall there's no
    -- room for a slider's labels, and the whole range is six steps.
    row.down = tinyButton("-")
    row.down:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.up = tinyButton("+")
    row.up:SetPoint("LEFT", row.down, "RIGHT", 24, 0)

    row.weight = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.weight:SetPoint("LEFT", row.down, "RIGHT", 0, 0)
    row.weight:SetWidth(24)
    row.weight:SetJustifyH("CENTER")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("LEFT", row.up, "RIGHT", 6, 0)
    row.meta:SetWidth(88)
    row.meta:SetJustifyH("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.meta, "RIGHT", 4, 0)
    row.text:SetJustifyH("LEFT")
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end

    row:EnableMouse(true)

    row.action = tinyButton("Delete", 56)
    row.action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetPoint("RIGHT", row.action, "LEFT", -8, 0)

    -- Names the pack a library line came from, where the Delete button would be.
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.source:SetWidth(56)
    row.source:SetJustifyH("RIGHT")

    castRows[index] = row
    return row
end

local function RefreshCasts()
    if not (castPanel and Casts) then return end
    local c = castDB()
    if not c then return end

    local tone = Casts.GetTone()
    if castBearingDropdown then
        castBearingDropdown:SetSelected(tone.bearing, toneOptionName(Casts.BEARINGS, tone.bearing))
    end
    if castStreakDropdown then
        castStreakDropdown:SetSelected(tone.second, toneOptionName(Casts.BEARINGS, tone.second))
    end
    if castWordingDropdown then
        castWordingDropdown:SetSelected(tone.wording, toneOptionName(Casts.WORDINGS, tone.wording))
    end
    if castTalkDropdown then
        castTalkDropdown:SetSelected(tone.talk, toneOptionName(Casts.TALK, tone.talk))
    end
    if castToneSummary then castToneSummary:SetText(Casts.DescribeTone()) end

    if castEnableCheck then castEnableCheck:SetChecked(c.enabled) end
    if castPetCheck then castPetCheck:SetChecked(c.pets) end

    local hasSpellbook = Compat.HasSpellbookAPI() and Compat.GetSpellbookNames() ~= nil
    if castFilterSpellbookCheck then
        if hasSpellbook then
            castFilterSpellbookCheck:Enable()
            castFilterSpellbookCheck:SetChecked(c.filterSpellbook ~= false)
        else
            c.filterSpellbook = false
            castFilterSpellbookCheck:SetChecked(false)
            castFilterSpellbookCheck:Disable()
        end
    end
    if castShowOtherPacksCheck then
        castShowOtherPacksCheck:SetChecked(c.showOtherPacks and true or false)
    end

    -- The captions are set here rather than left to OnValueChanged, which
    -- doesn't fire when the value is already what we're setting -- a slider
    -- sitting at its saved value would otherwise show no caption at all.
    local function setSlider(slider, value, caption)
        if not slider then return end
        slider:SetValue(value)
        if slider.valueText then slider.valueText:SetText(caption) end
    end
    local function seconds(value)
        return value == 0 and "No pause" or (value .. " seconds")
    end
    setSlider(castChanceSlider, c.chance or 35, (c.chance or 35) .. "%")
    setSlider(castGapSlider, c.gap or 20, seconds(c.gap or 20))
    setSlider(castSpellGapSlider, c.spellGap or 60, seconds(c.spellGap or 60))

    for packId, check in pairs(castPackChecks) do
        check:SetChecked(Casts.IsPackEnabled(packId))
    end
    layoutCastPacks()

    -- A selection is never taken away: a spell picked by name, or by the
    -- keybind, has no phrases yet by definition, and dropping it would undo the
    -- click that got you here. Only an empty selection falls back to the list.
    local keys = Casts.GetKeys()
    if not castSelectedKey then castSelectedKey = keys[1] end

    if castSpellDropdown then
        castSpellDropdown:SetItems(castSpellItems())
        if castSelectedKey then
            castSpellDropdown:SetSelected(castSelectedKey, Casts.DisplayName(castSelectedKey))
        else
            castSpellDropdown:SetSelected(nil, "Pick a spell")
        end
    end
    if castMuteCheck then
        castMuteCheck:SetChecked(castSelectedKey and Casts.IsMuted(castSelectedKey) or false)
    end
    if castNewLabel then
        castNewLabel:SetText(castSelectedKey
            and ("New phrase for " .. Casts.DisplayName(castSelectedKey))
            or "New phrase")
    end

    -- Lay the phrase rows out under the spell selector.
    local phrases = castSelectedKey and Casts.GetPhrases(castSelectedKey) or {}
    local anchor = castMuteCheck
    for i, phrase in ipairs(phrases) do
        local row = castRow(i, castContent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and 4 or 0, i == 1 and -10 or -2)
        row:SetPoint("RIGHT", castContent, "RIGHT", -24, 0)

        local step = phrase.step or 0
        row.weight:SetText(tostring(step))
        local grey = phrase.offTone or step == 0
        if grey then
            row.weight:SetTextColor(0.5, 0.5, 0.5)
            row.text:SetTextColor(0.5, 0.5, 0.5)
            row.meta:SetTextColor(0.4, 0.4, 0.4)
        else
            row.weight:SetTextColor(1, 0.82, 0)
            row.text:SetTextColor(1, 1, 1)
            row.meta:SetTextColor(0.55, 0.55, 0.55)
        end
        row.meta:SetText(phraseToneLabel(phrase))
        row.text:SetText(phrase.text)

        row:SetScript("OnEnter", function(self)
            if phrase.offTone then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Off character", 1, 0.82, 0)
                GameTooltip:AddLine(
                    "This line doesn't match your Bearing. Give it a weight to use it anyway.",
                    0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local key, text = castSelectedKey, phrase.text
        row.down:SetScript("OnClick", function()
            Casts.SetWeight(key, text, step - 1)
            RefreshCasts()
        end)
        row.up:SetScript("OnClick", function()
            Casts.SetWeight(key, text, step + 1)
            RefreshCasts()
        end)

        if phrase.user then
            row.action:Show()
            row.source:Hide()
            row.action:SetScript("OnClick", function()
                Casts.RemovePhrase(key, text)
                castStatusMsg("Removed that phrase.", false)
                RefreshCasts()
            end)
        else
            -- Library lines can't be deleted (the pack owns them), so weight 0
            -- is how you retire one. The pack name doubles as the explanation.
            row.action:Hide()
            row.source:Show()
            row.source:SetText(phrase.pack or "pack")
        end

        row:Show()
        anchor = row
    end
    for i = #phrases + 1, #castRows do
        castRows[i]:Hide()
    end

    if castEmptyNote then
        if #phrases == 0 then
            castEmptyNote:ClearAllPoints()
            castEmptyNote:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -10)
            castEmptyNote:SetPoint("RIGHT", castContent, "RIGHT", -24, 0)
            castEmptyNote:Show()
            anchor = castEmptyNote
        else
            castEmptyNote:Hide()
        end
    end

    if castAddRow then
        castAddRow:ClearAllPoints()
        castAddRow:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", #phrases > 0 and 0 or 0, -14)
        castAddRow:SetPoint("RIGHT", castContent, "RIGHT", -24, 0)
    end

    -- Preview whatever is being typed, so a phrase can be checked before it's
    -- saved; falls back to rolling one of the existing lines.
    if castPreviewText then
        local typed = castNewInput and castNewInput:GetText() or ""
        local spellName = castSelectedKey and Casts.DisplayName(castSelectedKey) or nil
        local line
        if typed:gsub("%s", "") ~= "" then
            line = Casts.Preview(typed, spellName)
        elseif phrases[1] then
            line = Casts.Preview(phrases[1].text, spellName)
        end
        castPreviewText:SetText(line or "|cff808080Add a phrase to see how it will read.|r")
    end

    if castContent and castContent.SetContentHeight and castPanel._lastChild then
        local top = castContent:GetTop()
        local bot = castPanel._lastChild:GetBottom()
        if top and bot and top > bot then
            castContent:SetContentHeight(top - bot + 24)
        end
    end
end

local function BuildCastPanel()
    castPanel = Compat.CreateOptionsPanel("TonguesOfAzerothCastOptions")
    castPanel.name = "Cast Phrases"
    castPanel.parent = mainPanel.name

    local content = Compat.CreateScrollContent(castPanel, 900)
    castContent = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Cast Phrases")

    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    if subtitle.SetWordWrap then subtitle:SetWordWrap(true) end
    subtitle:SetText("Speak a line of your own when a spell lands -- Corvin roars \"Nuk'luk!\" -- in whatever tongue you're currently speaking. Words in \"quotes\" are spoken aloud and get translated; the rest is narration and stays in English.")

    local limits = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    limits:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    limits:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    limits:SetJustifyH("LEFT")
    if limits.SetWordWrap then limits:SetWordWrap(true) end
    limits:SetText("|cffffd200Heads-up:|r lines go out as emotes. /say and /yell need a real keypress, so no addon can send them from a cast -- and during raid encounters, Mythic+ and rated PvP Blizzard blocks addon chat entirely, where the line is shown to you alone instead.")

    --  Character sheet ---------------------------------------------------
    local sheetLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sheetLabel:SetPoint("TOPLEFT", limits, "BOTTOMLEFT", 0, -16)
    sheetLabel:SetText("This character")

    local bearingLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bearingLabel:SetPoint("TOPLEFT", sheetLabel, "BOTTOMLEFT", 0, -10)
    bearingLabel:SetText("Bearing")

    local bearingItems = toneDropdownItems(Casts.BEARINGS)
    castBearingDropdown = Compat.CreateDropdown(content, 220)
    castBearingDropdown:SetPoint("TOPLEFT", bearingLabel, "BOTTOMLEFT", 0, -6)
    castBearingDropdown:SetItems(bearingItems)
    bindDropdownDesc(castBearingDropdown, bearingItems)
    castBearingDropdown.onSelect = function(value)
        Casts.SetTone("bearing", value)
        RefreshCasts()
    end

    local streakLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    streakLabel:SetPoint("TOPLEFT", bearingLabel, "TOPLEFT", 260, 0)
    streakLabel:SetText("Streak")

    local streakItems = toneDropdownItems(Casts.BEARINGS, true)
    castStreakDropdown = Compat.CreateDropdown(content, 220)
    castStreakDropdown:SetPoint("TOPLEFT", streakLabel, "BOTTOMLEFT", 0, -6)
    castStreakDropdown:SetItems(streakItems)
    bindDropdownDesc(castStreakDropdown, streakItems)
    castStreakDropdown.onSelect = function(value)
        Casts.SetTone("second", value)
        RefreshCasts()
    end

    local wordingLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    wordingLabel:SetPoint("TOPLEFT", castBearingDropdown, "BOTTOMLEFT", 0, -20)
    wordingLabel:SetText("Wording")

    local wordingItems = toneDropdownItems(Casts.WORDINGS)
    castWordingDropdown = Compat.CreateDropdown(content, 220)
    castWordingDropdown:SetPoint("TOPLEFT", wordingLabel, "BOTTOMLEFT", 0, -6)
    castWordingDropdown:SetItems(wordingItems)
    bindDropdownDesc(castWordingDropdown, wordingItems)
    castWordingDropdown.onSelect = function(value)
        Casts.SetTone("wording", value)
        RefreshCasts()
    end

    local talkLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    talkLabel:SetPoint("TOPLEFT", wordingLabel, "TOPLEFT", 260, 0)
    talkLabel:SetText("Talkativeness")

    local talkItems = toneDropdownItems(Casts.TALK)
    castTalkDropdown = Compat.CreateDropdown(content, 220)
    castTalkDropdown:SetPoint("TOPLEFT", talkLabel, "BOTTOMLEFT", 0, -6)
    castTalkDropdown:SetItems(talkItems)
    bindDropdownDesc(castTalkDropdown, talkItems)
    castTalkDropdown.onSelect = function(value)
        Casts.SetTone("talk", value)
        RefreshCasts()
    end

    castToneSummary = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    castToneSummary:SetPoint("TOPLEFT", castWordingDropdown, "BOTTOMLEFT", 0, -20)
    castToneSummary:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    castToneSummary:SetJustifyH("LEFT")

    local sheetHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sheetHint:SetPoint("TOPLEFT", castToneSummary, "BOTTOMLEFT", 0, -6)
    sheetHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    sheetHint:SetJustifyH("LEFT")
    if sheetHint.SetWordWrap then sheetHint:SetWordWrap(true) end
    sheetHint:SetText("The sheet decides which shipped lines suit this character; lines you write yourself are always used.")

    castEnableCheck = Compat.CreateCheckbox(content, "Speak a phrase when I cast something")
    castEnableCheck:SetPoint("TOPLEFT", sheetHint, "BOTTOMLEFT", 0, -14)
    castEnableCheck:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        castDB().enabled = enabled
        if enabled then Casts.SeedDefaultPacks() end
        RefreshCasts()
    end)

    castPetCheck = Compat.CreateCheckbox(content, "Also speak for my pet's abilities")
    castPetCheck:SetPoint("TOPLEFT", castEnableCheck, "BOTTOMLEFT", 0, -6)
    castPetCheck:SetScript("OnClick", function(self)
        castDB().pets = self:GetChecked() and true or false
    end)

    castChanceSlider = Compat.CreateSlider(content, 0, 100, 5, "How often", "0 - Never", "100 - Every cast")
    castChanceSlider:SetPoint("TOPLEFT", castPetCheck, "BOTTOMLEFT", 4, -34)
    castChanceSlider:SetWidth(320)
    castChanceSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 5 + 0.5) * 5
        castDB().chance = value
        self.valueText:SetText(value .. "%")
    end)

    castGapSlider = Compat.CreateSlider(content, 0, 120, 5, "Quiet time after a line", "0s", "2 min")
    castGapSlider:SetPoint("TOPLEFT", castChanceSlider, "BOTTOMLEFT", 0, -40)
    castGapSlider:SetWidth(320)
    castGapSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 5 + 0.5) * 5
        castDB().gap = value
        self.valueText:SetText(value == 0 and "No pause" or (value .. " seconds"))
    end)

    castSpellGapSlider = Compat.CreateSlider(content, 0, 300, 15, "...and for the same spell", "0s", "5 min")
    castSpellGapSlider:SetPoint("TOPLEFT", castGapSlider, "BOTTOMLEFT", 0, -40)
    castSpellGapSlider:SetWidth(320)
    castSpellGapSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 15 + 0.5) * 15
        castDB().spellGap = value
        self.valueText:SetText(value == 0 and "No pause" or (value .. " seconds"))
    end)

    local throttleHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    throttleHint:SetPoint("TOPLEFT", castSpellGapSlider, "BOTTOMLEFT", -4, -34)
    throttleHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    throttleHint:SetJustifyH("LEFT")
    if throttleHint.SetWordWrap then throttleHint:SetWordWrap(true) end
    throttleHint:SetText("The two pauses are what keep a spammable spell from turning your emotes into a wall of text. A cast that rolls a phrase while either pause is running simply stays quiet.")

    --  Packs -------------------------------------------------------------
    local packLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    packLabel:SetPoint("TOPLEFT", throttleHint, "BOTTOMLEFT", 0, -16)
    packLabel:SetText("Phrase packs")

    local packHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    packHint:SetPoint("TOPLEFT", packLabel, "BOTTOMLEFT", 0, -4)
    packHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    packHint:SetJustifyH("LEFT")
    if packHint.SetWordWrap then packHint:SetWordWrap(true) end
    packHint:SetText("Ready-made lines for spells you already cast. Tick one and its spells appear in the list below, where you can reword, reweight or retire any line. Packs match spells by English name.")

    castShowOtherPacksCheck = Compat.CreateCheckbox(content, "Show other classes")
    castShowOtherPacksCheck:SetPoint("TOPLEFT", packHint, "BOTTOMLEFT", 0, -8)
    castShowOtherPacksCheck:SetScript("OnClick", function(self)
        castDB().showOtherPacks = self:GetChecked() and true or false
        RefreshCasts()
    end)

    castPackAnchor = castShowOtherPacksCheck

    local packs = (ns.CastLibrary and ns.CastLibrary.GetPacks()) or {}
    local mine = ns.CastLibrary and ns.CastLibrary.PackForPlayer()
    local function addPackCheck(pack, label)
        local check = Compat.CreateCheckbox(content, label or pack.name)
        check:Hide()
        local packId = pack.id
        check:SetScript("OnClick", function(self)
            Casts.SetPackEnabled(packId, self:GetChecked() and true or false)
            RefreshCasts()
        end)
        if check.SetScript and pack.note then
            check:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(pack.name, 1, 1, 1)
                GameTooltip:AddLine(pack.note, 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine(string.format("%d spells, %d phrases", pack.spells, pack.phrases),
                    0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            check:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        castPackChecks[pack.id] = check
    end

    for _, pack in ipairs(packs) do
        if pack.kind ~= "creed" then
            local label = pack.name
            if pack.id == mine then label = label .. " |cff00ff00(yours)|r" end
            addPackCheck(pack, label)
        end
    end
    for _, pack in ipairs(packs) do
        if pack.kind == "creed" then addPackCheck(pack) end
    end

    castCreedHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    castCreedHeader:SetPoint("TOPLEFT", castPackAnchor, "BOTTOMLEFT", 0, -8)
    castCreedHeader:SetText("Creed packs")
    castCreedHeader:Hide()

    castCreedHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    castCreedHint:SetPoint("TOPLEFT", castCreedHeader, "BOTTOMLEFT", 0, -4)
    castCreedHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    castCreedHint:SetJustifyH("LEFT")
    if castCreedHint.SetWordWrap then castCreedHint:SetWordWrap(true) end
    castCreedHint:SetText("Creed lines are not tied to a spell -- they ride along on whichever spells you already have set up.")
    castCreedHint:Hide()

    castPackBottom = CreateFrame("Frame", nil, content)
    castPackBottom:SetSize(1, 1)
    castPackBottom:SetPoint("TOPLEFT", castPackAnchor, "BOTTOMLEFT", 0, 0)

    --  The spell being edited --------------------------------------------
    local spellLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", castPackBottom, "BOTTOMLEFT", 0, -20)
    spellLabel:SetText("Spell")

    castFilterSpellbookCheck = Compat.CreateCheckbox(content, "Only show spells I can cast")
    castFilterSpellbookCheck:SetPoint("TOPLEFT", spellLabel, "BOTTOMLEFT", 0, -4)
    castFilterSpellbookCheck:SetScript("OnClick", function(self)
        castDB().filterSpellbook = self:GetChecked() and true or false
        RefreshCasts()
    end)

    castSpellDropdown = Compat.CreateDropdown(content, 240)
    castSpellDropdown:SetPoint("TOPLEFT", castFilterSpellbookCheck, "BOTTOMLEFT", 0, -6)
    castSpellDropdown.onSelect = function(value)
        if value then noteSpellKey(value) end
        castSelectedKey = value
        castStatusMsg("", false)
        RefreshCasts()
    end

    -- Adding a spell the library doesn't cover. The keybind is the fast way in
    -- (hover it on your bars and press it); this is the way that works when
    -- you'd rather type, or the spell isn't on a bar at all.
    local addSpellInput = CreateFrame("EditBox", "TonguesOfAzerothCastSpell", content, "InputBoxTemplate")
    addSpellInput:SetPoint("LEFT", castSpellDropdown, "RIGHT", 16, 0)
    addSpellInput:SetSize(180, 20)
    addSpellInput:SetAutoFocus(false)
    addSpellInput:SetScript("OnEscapePressed", addSpellInput.ClearFocus)

    local function pickTypedSpell()
        local typed = addSpellInput:GetText() or ""
        local key = Casts.Key(typed)
        if not key then
            castStatusMsg("Type a spell's name first.", true)
            return
        end
        Casts.NoteSpellName((typed:gsub("^%s+", ""):gsub("%s+$", "")))
        castSelectedKey = key
        addSpellInput:SetText("")
        addSpellInput:ClearFocus()
        castStatusMsg("Editing " .. Casts.DisplayName(key) .. " -- add a phrase below.", false)
        RefreshCasts()
    end
    addSpellInput:SetScript("OnEnterPressed", pickTypedSpell)

    local addSpellHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    addSpellHint:SetPoint("TOPLEFT", addSpellInput, "BOTTOMLEFT", 0, -3)
    addSpellHint:SetText("or type a spell name and press Enter")

    castMuteCheck = Compat.CreateCheckbox(content, "Never speak for this spell")
    castMuteCheck:SetPoint("TOPLEFT", castSpellDropdown, "BOTTOMLEFT", 0, -10)
    castMuteCheck:SetScript("OnClick", function(self)
        if not castSelectedKey then return end
        Casts.SetMuted(castSelectedKey, self:GetChecked() and true or false)
        RefreshCasts()
    end)

    castEmptyNote = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    castEmptyNote:SetJustifyH("LEFT")
    if castEmptyNote.SetWordWrap then castEmptyNote:SetWordWrap(true) end
    castEmptyNote:SetText("No phrases for this spell yet. Tick a pack above, or write one below.")
    castEmptyNote:Hide()

    --  Adding a phrase ---------------------------------------------------
    castAddRow = CreateFrame("Frame", nil, content)
    castAddRow:SetHeight(46)

    castNewLabel = castAddRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    castNewLabel:SetPoint("TOPLEFT", castAddRow, "TOPLEFT", 0, 0)
    castNewLabel:SetText("New phrase")

    castNewInput = CreateFrame("EditBox", "TonguesOfAzerothCastPhrase", castAddRow, "InputBoxTemplate")
    castNewInput:SetPoint("TOPLEFT", castNewLabel, "BOTTOMLEFT", 6, -6)
    castNewInput:SetSize(440, 20)
    castNewInput:SetAutoFocus(false)
    castNewInput:SetScript("OnTextChanged", function() RefreshCasts() end)
    castNewInput:SetScript("OnEscapePressed", castNewInput.ClearFocus)

    local function addTypedPhrase()
        if not castSelectedKey then
            castStatusMsg("Pick a spell first.", true)
            return
        end
        local text = castNewInput:GetText() or ""
        local ok, err = Casts.AddPhrase(castSelectedKey, text)
        if ok then
            castNewInput:SetText("")
            castStatusMsg("Added.", false)
        else
            castStatusMsg("Not added: " .. tostring(err) .. ".", true)
        end
        RefreshCasts()
    end
    castNewInput:SetScript("OnEnterPressed", addTypedPhrase)

    local addBtn = CreateFrame("Button", nil, castAddRow)
    addBtn:SetPoint("LEFT", castNewInput, "RIGHT", 10, 0)
    addBtn:SetSize(70, 22)
    do
        local bg = addBtn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.18, 0.16, 0.24, 1)
        Compat.AddBorder(addBtn, 0.5, 0.45, 0.7, 0.9)
        local t = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER", 0, 0)
        t:SetText("Add")
        local hl = addBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Compat.SolidTexture(hl, 1, 1, 1, 0.12)
    end
    addBtn:SetScript("OnClick", addTypedPhrase)

    local tokenHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    tokenHint:SetPoint("TOPLEFT", castAddRow, "BOTTOMLEFT", 6, -2)
    tokenHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    tokenHint:SetJustifyH("LEFT")
    if tokenHint.SetWordWrap then tokenHint:SetWordWrap(true) end
    do
        local parts = {}
        for _, entry in ipairs(Casts and Casts.TOKEN_HELP or {}) do
            parts[#parts + 1] = entry.token .. " = " .. entry.desc
        end
        tokenHint:SetText("A phrase continues the sentence \"" ..
            (UnitName("player") or "You") .. " ...\", so start with a verb.  " ..
            table.concat(parts, "   "))
    end

    local previewLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", tokenHint, "BOTTOMLEFT", -6, -14)
    previewLabel:SetText("Preview")

    castPreviewText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    castPreviewText:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 6, -8)
    castPreviewText:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    castPreviewText:SetJustifyH("LEFT")
    castPreviewText:SetHeight(32)
    castPreviewText:SetSpacing(2)

    castStatus = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    castStatus:SetPoint("TOPLEFT", castPreviewText, "BOTTOMLEFT", 0, -6)
    castStatus:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    castStatus:SetJustifyH("LEFT")
    castStatus:SetText("")

    castPanel._lastChild = castStatus
    castPanel.refresh = RefreshCasts
    castPanel:SetScript("OnShow", RefreshCasts)

    if not castSpellEventsRegistered and Compat.HasSpellbookAPI() then
        local spellFrame = CreateFrame("Frame")
        spellFrame:RegisterEvent("SPELLS_CHANGED")
        if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
            pcall(spellFrame.RegisterEvent, spellFrame, "LEARNED_SPELL_IN_TAB")
        end
        spellFrame:SetScript("OnEvent", function()
            if castPanel and castPanel:IsVisible() then RefreshCasts() end
        end)
        castSpellEventsRegistered = true
    end
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

    BuildCastPanel()
    Compat.RegisterOptionsPanel(castPanel, castPanel.name, mainPanel.name)

    -- In the shared standalone window the sub-panels show a Back button (to the
    -- main panel) instead of their own close button.
    learnedPanel._backAction = function() ns.OpenConfig() end
    accentPanel._backAction = function() ns.OpenConfig() end
    customPanel._backAction = function() ns.OpenConfig() end
    castPanel._backAction = function() ns.OpenConfig() end

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
    if castPanel and castPanel:IsVisible() then RefreshCasts() end
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

-- `key` comes from the keybinding (the spell that was under the cursor), so the
-- panel opens already showing that spell's phrases.
function ns.OpenCastConfig(key)
    BuildPanels()
    if key then castSelectedKey = key end
    Compat.OpenOptionsPanel(castPanel)
    RefreshCasts()
end
