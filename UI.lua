--[[-------------------------------------------------------------------------
    Tongues of Azeroth - UI.lua
    In-game configuration registered under the game's AddOns options.

    Each panel answers one question, which is what decides where a setting goes:

      * Main -- what am I speaking right now? Auto-translate, language, fluency,
        preview, and the addon's own furniture (minimap button, floating bar).
      * Languages -- how is each tongue set up? The per-language list: what you
        understand, how fluently, and what color it reads in.
      * Chat -- where does translation apply, and how does it read? Split by the
        two directions the pipeline runs in: what leaves your keyboard
        (channels, tag, instances) and what arrives in your window (decode
        style, output frame).
      * Accents, Cast Phrases, Create Language -- self-contained jobs.

    A setting that answers none of those, or two of them, is a sign the grouping
    is wrong rather than an invitation to append it to whichever panel is
    nearest; that is how the main panel previously came to hold seven unrelated
    checkboxes in a flat stack.

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
    EMOTE         = "Emote (/e and *actions*)",
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
local chatPanel, chatContent
local mainContent
local langDropdown, enableCheck, previewInput, previewOutput
local voiceText, voiceHint
local minimapCheck, fluencyCheck, nativeHideCheck, autoDisableCheck
local namesCheck, nameColorCheck
local widgetCheck, widgetLockCheck
local accentDropdown, accentSlider, accentValueText
local accentTailSlider, accentTailValueText
local accentPreviewInput, accentPreviewOutput, accentEmotesCheck
local accentContent
local customEditDropdown, customNameInput, customApostSlider, customApostText
local customOnsetInput, customNucleiInput, customCodaInput
local customPreviewInput, customPreviewOutput, customStatus, customEditingId
local customShareInput
local castPanel, castContent
local castEnableCheck, castPetCheck, castChanceSlider, castGapSlider, castSpellGapSlider
local castSpellDropdown, castMuteCheck, castNewInput, castNewLabel
local castWeightHeader
local castPreviewText, castStatus, castAddRow, castEmptyNote
local castPackChecks = {}
local castPackBottom
local castPackAnchor
local castFilterSpellbookCheck, castShowOtherPacksCheck
local castVoiceCheck
local castRows = {}
local castSelectedKey
-- The reword in progress, or nil. Four things, and all four have to live here
-- rather than on the row: rows are pooled and redrawn constantly -- every
-- keystroke in the new-phrase field below redraws the whole list -- so anything
-- kept on the frame is lost the moment the list reflows.
--
--   orig   the text that ADDRESSES the phrase (a library line's shipped
--          wording), which is what its weight and its edit hang off
--   from    what it read as when the editor opened, so an untouched edit can
--          close without writing anything
--   typed   what is in the box now, which is the whole point: the box is
--          reseeded from this on every redraw, so a redraw cannot eat the edit
--   focus   set once when the editor opens. Grabbing focus on every redraw
--          would yank the cursor out of the new-phrase field the moment
--          somebody typed in it with a row still open.
local castEdit
local castSpellEventsRegistered
local channelChecks = {}
local learnedRows = {}
local learnedBars = {}
local learnedOrder = {}
local learnedSwatches = {}
local learnedStars = {}
local learnedScroll, learnedChild, learnedRowH = nil, nil, 38
local learnedTopId
-- Assigned by BuildLearnedPanel; lets rows be made after the panel exists.
local makeLearnedRow
local learnedRevision
local passiveCheck
local decodeStyleDropdown
local outputDropdown
local colorTagCheck, colorSpeechCheck, colorRealCheck
local panelsBuilt = false
local minimapButton

local function db()
    if TonguesOfAzerothDB == nil and OldGodTonguesDB ~= nil then
        TonguesOfAzerothDB = OldGodTonguesDB
    end
    TonguesOfAzerothDB = TonguesOfAzerothDB or {}
    if TonguesOfAzerothDB.inCharacter == nil then
        TonguesOfAzerothDB.inCharacter = TonguesOfAzerothDB.enabled and true or false
    end
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
    -- On by default: it is the only always-visible readout of what you're
    -- speaking and whether you're in character, and it carries the in/out of
    -- character button. Off by default made the addon's main signal opt-in.
    --
    -- The default changed after profiles already existed, and every one of them
    -- has an explicit `false` written by the old default -- indistinguishable
    -- from someone who switched the bar off deliberately. So the new default is
    -- applied once, tracked by its own key, rather than re-asserted every login:
    -- turn the bar off after this and it stays off.
    if TonguesOfAzerothDB.widget.enabled == nil then TonguesOfAzerothDB.widget.enabled = true end
    if not TonguesOfAzerothDB.widget.defaultedOn then
        TonguesOfAzerothDB.widget.defaultedOn = true
        TonguesOfAzerothDB.widget.enabled = true
    end
    if TonguesOfAzerothDB.widget.locked == nil then TonguesOfAzerothDB.widget.locked = false end
    if TonguesOfAzerothDB.widget.point == nil then TonguesOfAzerothDB.widget.point = "CENTER" end
    if TonguesOfAzerothDB.widget.x == nil then TonguesOfAzerothDB.widget.x = 0 end
    if TonguesOfAzerothDB.widget.y == nil then TonguesOfAzerothDB.widget.y = -140 end
    if TonguesOfAzerothDB.outputFrame == nil then TonguesOfAzerothDB.outputFrame = 0 end
    TonguesOfAzerothDB.tagLanguage = true
    if TonguesOfAzerothDB.tagFluency == nil then TonguesOfAzerothDB.tagFluency = true end
    if not TonguesOfAzerothDB.accent then TonguesOfAzerothDB.accent = {} end
    if TonguesOfAzerothDB.accent.strength == nil then TonguesOfAzerothDB.accent.strength = 100 end
    if TonguesOfAzerothDB.accent.emotes == nil then TonguesOfAzerothDB.accent.emotes = false end
    if TonguesOfAzerothDB.hideNativeLanguages == nil then TonguesOfAzerothDB.hideNativeLanguages = true end
    if TonguesOfAzerothDB.autoDisableInInstances == nil then TonguesOfAzerothDB.autoDisableInInstances = true end
    -- Mirrors Core's migration: a profile that never picked an accent has none,
    -- rather than silently arriving with Dwarven selected.
    if TonguesOfAzerothDB.accent.id == nil then
        TonguesOfAzerothDB.accent.id = (Accent and Accent.NONE) or "none"
    elseif not (Accent and Accent.IsValid(TonguesOfAzerothDB.accent.id)) then
        TonguesOfAzerothDB.accent.id = (Accent and Accent.DEFAULT) or "dwarf"
    end
    return TonguesOfAzerothDB
end

-- Fluency % (0-100) of a language from the trainer store. How well you speak a
-- tongue IS your fluency in it -- there is no second number -- so this is what
-- the rows, the summary and the preview all read.
local function fluencyPct(langId)
    if ns.Trainer and ns.Trainer.GetProgress and langId then
        local ok, _, _, frac = pcall(ns.Trainer.GetProgress, langId)
        if ok and type(frac) == "number" then return math.floor(frac * 100 + 0.5) end
    end
    return db().strength or 100
end

-- A word for a fluency number, with a color to match. Up here beside
-- fluencyPct rather than next to the floating bar that first needed it: the
-- landing panel's voice summary reads it too, and it is defined before either.
local function fluencyAdjective(pct)
    if pct >= 100 then return "Perfect", 1, 0.85, 0.2 end
    if pct >= 75 then return "Fluent", 0.4, 0.85, 0.4 end
    if pct >= 25 then return "Partial", 0.95, 0.8, 0.3 end
    return "Broken", 0.95, 0.5, 0.4
end

local function refreshPreview()
    if not (previewInput and previewOutput) then return end
    local d = db()
    local src = previewInput:GetText()
    if src == "" then src = SAMPLE end

    -- Run the real outgoing path rather than translating by hand, so the
    -- preview shows the composed voice -- tongue first, accent over whatever
    -- English the fluency left behind -- and goes plain the moment you drop
    -- out of character. A preview that only modelled half of it was quietly
    -- lying about the half people came here to hear.
    --
    -- `live` false: a preview must not advance the accent's interjection
    -- spacing or seed the decode cache.
    local out
    if ns.EncodeSpeech then
        local ok, res = pcall(ns.EncodeSpeech, src, false)
        if ok then out = res end
    end
    if type(out) ~= "string" then
        local strength = (ns.GetSpeakingStrength and ns.GetSpeakingStrength())
            or fluencyPct(d.language)
        out = Language.TranslateText(src, strength, d.language)
    end
    -- Painted here the same way the chat filter paints a real line, so the
    -- preview answers "did my name survive that?" without having to go and say
    -- it to someone.
    if ns.Names then out = ns.Names.Highlight(out) end
    previewOutput:SetText(out)
end

-- One sentence naming the voice, then where each half of it is changed. Shared
-- so the Languages panel and anything else that wants the summary agree.
local function RefreshVoice()
    local d = db()
    if voiceText then
        local plain = Language.IsPlain and Language.IsPlain(d.language)
        local accentOn = Accent and d.accent and d.accent.id ~= Accent.NONE
        local accentName = accentOn and Accent.GetAccentName(d.accent.id) or nil

        local voice
        if plain and accentOn then
            voice = string.format("Plain speech, %s accent", accentName)
        elseif plain then
            voice = "Plain speech"
        else
            local adj = select(1, fluencyAdjective(fluencyPct(d.language)))
            voice = string.format("%s  |cff909090(%s, %d%%)|r",
                Language.GetLanguageName(d.language), adj, fluencyPct(d.language))
            if accentOn then
                voice = voice .. string.format(", %s accent", accentName)
            end
        end
        if not d.inCharacter then
            voice = "|cff808080" .. voice:gsub("|cff909090", "|cff606060") .. "|r"
        end
        voiceText:SetText(voice)
    end

    if voiceHint then
        -- One line either way: the list below is the reason this panel is short
        -- of vertical space, so the hint doesn't get to grow when you go out of
        -- character.
        voiceHint:SetText(d.inCharacter
            and "Drag a handle below to change how much of a tongue comes through. Your accent is under |cffffd200Accents|r."
            or "|cffff8080Out of character -- none of this is applied to your chat right now.|r")
    end
    refreshPreview()
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

    -- Favorites are only *grouped* here now, not set here -- the stars live on
    -- the language rows on the same panel. So this list has no `toggle` fields
    -- and no onToggle; see Compat.CreateDropdown.
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
            rest[#rest + 1] = { text = p.name, value = p.id }
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
                                        value = s.id }
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
            rest[#rest + 1] = { text = l.name, value = l.id }
        end
    end

    -- Your curated shortlist on top, in the order you built it, so the handful
    -- you actually speak aren't seventy rows down.
    local items = {}

    -- "None" first, above even the favorites. It is the other half of the
    -- accent's None: together they let you dial your voice down to plain
    -- English without leaving character, so somebody who only wants an accent
    -- has a setting that says so rather than having to park on a tongue they
    -- are 0% fluent in and hope.
    --
    -- Pinned rather than favoritable. A star here would be the only one in a
    -- list the stars were deliberately moved out of, and it would be earning
    -- its keep only to lift None to a position it already holds: being the
    -- first row is exactly what a player favorites something to get.
    items[#items + 1] = { text = Language.GetLanguageName("none"), value = "none" }
    local favs = (ns.GetFavorites and ns.GetFavorites()) or {}
    local favRows = {}
    for i = 1, #favs do
        local id = favs[i]
        -- None is pinned above, so it must not come round again under the
        -- header. Right-clicking any row still favorites it, which has always
        -- meant None could be favorited and listed twice.
        if id ~= "none" and not (ns.IsNativeLanguage and ns.IsNativeLanguage(id)) then
            favRows[#favRows + 1] = { text = Language.GetLanguageName(id), value = id }
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
-- A label with a hairline rule running out to the right edge, marking off a
-- group of related controls.
--
-- These panels are long vertical stacks, and an unbroken stack reads as one
-- undifferentiated list: every setting looks equally important and equally
-- related to the one above it. That is how the main panel came to hold seven
-- unrelated checkboxes in a row with nothing to say where one concern ended and
-- the next began.
local function sectionHeader(parent, text, rightInset)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0.2)

    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", parent, "RIGHT", -(rightInset or 24), 0)
    Compat.SolidTexture(rule, 1, 1, 1, 0.12)

    label.rule = rule
    return label
end

-- The lock row only means anything while the bar is shown, so it comes and
-- goes. It is the last control on the panel, so nothing needs re-anchoring
-- underneath it -- only the scroll height has to follow, which RefreshMain
-- reads off `_lastChild`.
local function layoutMainWidgetLock()
    if not (mainPanel and widgetCheck) then return end
    local d = db()
    local barOn = d.widget and d.widget.enabled and true or false
    mainPanel._lastChild = (barOn and widgetLockCheck) or widgetCheck
end

local function RefreshMain()
    if not mainPanel then return end
    local d = db()
    if minimapCheck then minimapCheck:SetChecked(not d.minimap.hide) end
    if widgetCheck then widgetCheck:SetChecked(d.widget.enabled and true or false) end
    if widgetLockCheck then
        widgetLockCheck:SetChecked(d.widget.locked and true or false)
        widgetLockCheck:SetShown(d.widget.enabled and true or false)
    end
    layoutMainWidgetLock()
    enableCheck:SetChecked(d.inCharacter)

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

local function RefreshChat()
    if not chatPanel then return end
    local d = db()
    for ch, check in pairs(channelChecks) do
        check:SetChecked(d.channels[ch] and true or false)
    end
    if fluencyCheck then fluencyCheck:SetChecked(d.tagFluency ~= false) end
    if namesCheck then namesCheck:SetChecked(d.protectNames ~= false) end
    if nameColorCheck then
        nameColorCheck:SetChecked(d.colorNames ~= false)
        -- Greyed rather than reset when protection is off: turning it back on
        -- should restore the color setting the player last chose, not whatever
        -- it collapsed to while the box above was unticked.
        if d.protectNames ~= false then
            nameColorCheck:Enable()
            nameColorCheck.labelText:SetTextColor(1, 1, 1)
        else
            nameColorCheck:Disable()
            nameColorCheck.labelText:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    if autoDisableCheck then autoDisableCheck:SetChecked(d.autoDisableInInstances ~= false) end
    if decodeStyleDropdown then
        decodeStyleDropdown:SetSelected(d.decodeStyle, decodeStyleLabel(d.decodeStyle))
    end
    if outputDropdown then
        -- Rebuilt every time: the list is the player's actual chat windows, and
        -- those can be renamed, added or closed while the panel is shut.
        outputDropdown:SetItems(outputItems())
        outputDropdown:SetSelected(d.outputFrame or 0, outputWindowLabel(d.outputFrame or 0))
    end

    if chatContent and chatContent.SetContentHeight and chatPanel._lastChild then
        local top, bot = chatContent:GetTop(), chatPanel._lastChild:GetBottom()
        if top and bot and top > bot then
            chatContent:SetContentHeight(top - bot + 20)
        end
    end
end

-- Make sure there is a row for every primary language, and that learnedOrder
-- lists them all. Cheap on the common path: the registry hands out a revision
-- number, and this does nothing until it moves.
--
-- It moves when a language is created (or deleted) on the Create Language
-- panel. Rows are built once, so without this a tongue you had just made would
-- appear in the Speaking dropdown but nowhere in Your languages -- no fluency
-- bar to drag, no color swatch, no star -- which is not a language you can
-- actually use.
local function syncLearnedRows()
    if not makeLearnedRow then return end
    local rev = Language.GetRevision and Language.GetRevision() or 0
    if rev == learnedRevision then return end
    learnedRevision = rev

    wipe(learnedOrder)
    local langs = Language.GetPrimaryLanguages()
    for i = 1, #langs do
        local entry = langs[i]
        if not learnedRows[entry.id] then makeLearnedRow(entry) end
        learnedOrder[#learnedOrder + 1] = entry.id
    end
end

-- The order the rows are drawn in: what you're speaking, then your favorites,
-- then everything else in the usual order.
--
-- The preview sits directly above this list, and the pairing only works if you
-- can see both at once -- the whole point is dragging a language's fluency and
-- watching the line rewrite itself. With the list in fixed order that meant
-- hunting your tongue out of seventy rows every time, which made the preview
-- effectively unreachable for the one language it was previewing.
--
-- Rows exist for primaries only, so a sub-dialect pins its parent: they share a
-- word set, and therefore a fluency and a row.
local function learnedDisplayOrder()
    local order, seen = {}, {}
    local function push(id)
        if not id then return end
        id = Language.GetWordsetId(id)
        if learnedRows[id] and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    push(db().language)
    local favs = (ns.GetFavorites and ns.GetFavorites()) or {}
    for i = 1, #favs do push(favs[i]) end
    for i = 1, #learnedOrder do push(learnedOrder[i]) end
    return order
end

-- Show only the languages your race can't already speak (when the option is on)
-- and re-flow the visible rows so there are no gaps, resizing the scroll child.
local function reflowLearnedRows()
    syncLearnedRows()
    if not (learnedChild and #learnedOrder > 0) then return end
    local order = learnedDisplayOrder()
    local visible, placed = 0, {}
    for i = 1, #order do
        local id = order[i]
        local rowRef = learnedRows[id]
        local rowF = rowRef and rowRef.row
        if rowF then
            placed[id] = true
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
    -- A deleted custom language keeps its row (frames can't be destroyed), so
    -- anything the order no longer mentions has to be put away explicitly or it
    -- stays on screen where it was last drawn.
    for id, rowRef in pairs(learnedRows) do
        if not placed[id] and rowRef.row then rowRef.row:Hide() end
    end
    learnedChild:SetHeight(visible * learnedRowH + 6)
    if learnedScroll then
        -- Pinning a new language to the top is no help if the list is still
        -- scrolled where it was, so switching tongues snaps back up to it.
        if order[1] and order[1] ~= learnedTopId then
            learnedTopId = order[1]
            learnedScroll:SetVerticalScroll(0)
        end
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
      -- A deleted custom language leaves its row behind, hidden. Nothing below
      -- expects an id the registry has never heard of, so skip it outright.
      if Language.IsValid(langId) then
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

        -- The handle tracks the value whether or not the fill is drawn, so a
        -- language at 0% still shows something to grab.
        if bar and bar.thumbEdge then
            bar.thumbEdge:ClearAllPoints()
            bar.thumbEdge:SetPoint("CENTER", bar, "LEFT", bar.barW * (frac or 0), 0)
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

        local star = learnedStars[langId]
        if star then Compat.SetStar(star.tex, ns.IsFavorite and ns.IsFavorite(langId)) end

        local swatch = learnedSwatches[langId]
        if swatch and ns.Colors then
            local r, g, b = ns.Colors.Get(langId)
            if r then Compat.SolidTexture(swatch.fill, r, g, b, 1) end
            -- Dimmed only when neither axis is on, so the row shows the setting
            -- rather than advertising a color that isn't reaching chat.
            swatch:SetAlpha(ns.Colors.AnyEnabled() and 1 or 0.35)
        end
      end
    end
    if colorTagCheck then colorTagCheck:SetChecked(colorTagCheck._get() and true or false) end
    if colorSpeechCheck then colorSpeechCheck:SetChecked(colorSpeechCheck._get() and true or false) end
    if colorRealCheck then colorRealCheck:SetChecked(colorRealCheck._get() and true or false) end
    if passiveCheck then passiveCheck:SetChecked(d.passiveLearning ~= false) end
    if nativeHideCheck then nativeHideCheck:SetChecked(d.hideNativeLanguages and true or false) end
    if langDropdown then
        langDropdown:SetSelected(d.language, Language.GetLanguageName(d.language))
    end
    RefreshVoice()
end

-- The minimap button is driven through LibDBIcon (bundled) so it behaves exactly
-- like every other addon's button: correct placement AND collectable /
-- auto-hideable by minimap-button managers (SexyMap, etc.).
local ldbIcon
local ldbObject
local LDB_NAME = "TonguesOfAzeroth"
-- Two icons, not one icon tinted. The button used to be a scroll, desaturated
-- and washed green or red, which answers "am I in character" only if you
-- already know the code; a speaker with sound coming out of it and a speaker
-- with a cross through it answer it to anybody who glances at the minimap.
--
-- Keep ICON in step with `## IconTexture:` in the TOCs, so the addon list and
-- the button show the same thing. Shipped with the addon rather than borrowed
-- from Blizzard's icon set, because nothing in there is a speaker.
local ICON = "Interface\\AddOns\\TonguesOfAzeroth\\Media\\ToA-Voice-On"
local ICON_MUTED = "Interface\\AddOns\\TonguesOfAzeroth\\Media\\ToA-Voice-Off"

-- In character / out of character at a glance, in one place so the minimap
-- button and the floating bar can't disagree about which colors mean what.
local IC_TINT  = { 0.45, 1.00, 0.45 }
local OOC_TINT = { 1.00, 0.42, 0.42 }

local function stateTint()
    local d = db()
    local c = d.inCharacter and IC_TINT or OOC_TINT
    return c[1], c[2], c[3], d.inCharacter and true or false
end

-- Swap the minimap icon by state. Hovering to read a tooltip is a poor way to
-- answer a question you ask constantly, so the button answers it on sight.
--
-- The artwork carries the state now, so the old desaturate-and-tint has to be
-- undone rather than merely stopped: a button that was greyed out before the
-- upgrade stays greyed out until something sets it back.
local function ApplyMinimapState()
    local muted = not db().inCharacter
    -- LibDBIcon rebuilds the button's texture from the data object, so the
    -- object is where the choice has to live or the next refresh undoes it.
    if ldbObject then ldbObject.icon = muted and ICON_MUTED or ICON end

    local btn = minimapButton
        or (ldbIcon and ldbIcon.GetMinimapButton and ldbIcon:GetMinimapButton(LDB_NAME))
    local icon = btn and btn.icon
    if not icon then return end
    if icon.SetDesaturated then pcall(icon.SetDesaturated, icon, false) end
    icon:SetVertexColor(1, 1, 1)
    icon:SetTexture(muted and ICON_MUTED or ICON)
end

local function ApplyMinimapShown()
    local hide = db().minimap.hide and true or false
    if ldbIcon then
        if hide then ldbIcon:Hide(LDB_NAME) else ldbIcon:Show(LDB_NAME) end
    elseif minimapButton then
        if hide then minimapButton:Hide() else minimapButton:Show() end
    end
    ApplyMinimapState()
end
ns.ApplyMinimapShown = ApplyMinimapShown

-- Tooltips are built once, in OnEnter. Anything that changes state while one is
-- already open -- flipping in or out of character with the bar's own button,
-- scrolling the minimap icon to cycle languages -- leaves stale text sitting
-- under the cursor until you move off the frame and back on. That is the exact
-- moment the tooltip is worth reading, so re-running the owner's OnEnter
-- rebuilds it in place.
--
-- Only for frames that opt in with `_toaTooltip` (including the minimap button,
-- which we tag when LibDBIcon hands it over): re-entering an arbitrary frame
-- that happens to own the tooltip is not ours to do.
--
-- GameTooltip is not the only tooltip our frames end up in. LibDBIcon builds a
-- private LibDBIconTooltip and shows the minimap button's text there, so asking
-- GameTooltip who owns it skipped the minimap entirely -- the one frame whose
-- tooltip is most likely to be open while the state it reports changes, since
-- scrolling the icon cycles languages without the cursor ever leaving it.
local function toolTipFrames()
    -- Resolved per call: LibDBIcon's tooltip does not exist until the library
    -- loads, which is after this file is parsed.
    return GameTooltip, _G.LibDBIconTooltip
end

local function refreshOpenTooltip()
    for i = 1, 2 do
        local tt = select(i, toolTipFrames())
        local owner = tt and tt.GetOwner and tt:GetOwner()
        if owner and owner._toaTooltip
            and not (tt.IsShown and not tt:IsShown())
            and not (owner.IsMouseOver and not owner:IsMouseOver()) then
            local onEnter = owner.GetScript and owner:GetScript("OnEnter")
            if onEnter then pcall(onEnter, owner) end
        end
    end
end

-- Every entry point into the in-character switch routes through Core so the
-- panel, the bar and the minimap can never disagree about it. Silent: these are
-- the frames that turn green or red as you click them, so a chat line saying
-- what you just watched happen is only noise.
local function toggleInCharacter()
    if ns.ToggleInCharacter then
        ns.ToggleInCharacter(true)
    else
        local d = db(); d.inCharacter = not d.inCharacter
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    end
end

local function tooltipLines(tt)
    tt:AddLine("Tongues of Azeroth")
    tt:AddLine("Language: |cffffffff" .. Language.GetLanguageName(db().language) .. "|r", 0.8, 0.8, 0.8)
    tt:AddLine("In character: " .. (db().inCharacter and "|cff00ff00YES|r" or "|cffff0000NO|r"), 0.8, 0.8, 0.8)
    if not db().inCharacter then
        -- Said here because this is where it gets switched off, and a button
        -- that silences four features ought to admit to all four of them.
        tt:AddLine("Muted: no tongue, no accent, no cast phrases.", 0.8, 0.5, 0.5)
    end
    tt:AddLine(" ")
    tt:AddLine("|cffffffffLeft-click|r  Open settings", 1, 1, 1)
    tt:AddLine("|cffffffffRight-click|r  Mute / unmute everything it says for you", 1, 1, 1)
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
                        toggleInCharacter()
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
    ldbObject = obj

    -- db.minimap doubles as LibDBIcon's saved table (it uses .hide + .minimapPos).
    local okReg = pcall(function() iconLib:Register(LDB_NAME, obj, db().minimap) end)
    if not okReg then return false end
    ldbIcon = iconLib

    -- LibDBIcon doesn't wire the mouse wheel, so add scroll-to-cycle ourselves.
    local btn = iconLib.GetMinimapButton and iconLib:GetMinimapButton(LDB_NAME)
    if btn then
        -- LibDBIcon owns this button's OnEnter, which calls the OnTooltipShow
        -- above. Tagging it lets refreshOpenTooltip re-run that when the state
        -- it reports changes -- scrolling the icon to cycle languages being the
        -- obvious case, since the cursor never leaves the button.
        btn._toaTooltip = true
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
    -- LibStub losing a fight with another addon's copy): a dependency-free button
    -- carrying the same two icons, which ship inside the addon and so are there
    -- whatever happened to LibStub.
    if minimapButton then ApplyMinimapShown(); return end
    minimapButton = Compat.CreateMinimapButton("TonguesOfAzerothMinimapButton", {
        icon = ICON,
        onClick = function(mouseButton)
            if mouseButton == "RightButton" then
                toggleInCharacter()
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

-- Floating-widget metrics, shared between the frame that is built once and the
-- refresh that resizes it to the current language name.
local WIDGET_MIN_W = 140
local WIDGET_PAD = 8
-- Left inset of the fluency word (8) + the gap the "Auto"/"Off" text is held
-- off the right edge for the star (24) + breathing room between the two.
local WIDGET_BOTTOM_RESERVE = 8 + 24 + 10

local function RefreshLanguageWidget()
    if not langWidget then return end
    local d = db()
    if not d.widget.enabled then langWidget:Hide(); return end
    langWidget:Show()
    langWidget.name:SetText(Language.GetLanguageName(d.language))
    local adj, ar, ag, ab = fluencyAdjective(fluencyPct(d.language))
    langWidget.sub:SetText(adj)
    langWidget.sub:SetTextColor(ar, ag, ab)
    local tr, tg, tb, inChar = stateTint()
    langWidget.dot:SetText(inChar and "IC" or "OOC")
    langWidget.dot:SetTextColor(tr, tg, tb)
    if langWidget.border then
        langWidget.border:SetColor(tr * 0.75, tg * 0.75, tb * 0.75, 0.95)
    end
    if langWidget.icBtn then
        langWidget.icBtn:SetWidth(math.max(20, math.ceil(langWidget.dot:GetStringWidth()) + 8))
    end
    if langWidget.fav then
        -- Filled only when the toggle is on AND there's a list to walk, so the
        -- star never claims a filter is active when it can't be.
        local n = (ns.GetFavorites and #ns.GetFavorites()) or 0
        Compat.SetStar(langWidget.fav.tex, d.favOnly and n > 0)
    end

    -- Grow the box to whatever it is holding. A fixed width can't work here:
    -- "Eldre'Thalassian (Skyborne)" already overflows it, and a custom language
    -- can be named anything at all. Measured after every SetText above, since
    -- GetStringWidth reports the width of the current string.
    local needed = langWidget.name:GetStringWidth() + WIDGET_PAD * 2
    -- The bottom row is fluency on the left, auto/off on the right, and the
    -- favorites star outside that -- it can be the wider of the two rows.
    local bottom = langWidget.sub:GetStringWidth() + langWidget.dot:GetStringWidth()
        + WIDGET_BOTTOM_RESERVE
    if bottom > needed then needed = bottom end
    if needed < WIDGET_MIN_W then needed = WIDGET_MIN_W end
    langWidget:SetWidth(math.ceil(needed))
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
    rAuto.text:SetText(d.inCharacter and "Speaking: |cff66dd66IN CHARACTER|r" or "Speaking: |cffdd6666OUT OF CHARACTER|r")
    rAuto:SetScript("OnClick", function()
        toggleInCharacter()
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
        -- Starting width only; RefreshLanguageWidget sizes it to its contents.
        f:SetSize(WIDGET_MIN_W, 40)
        f:SetFrameStrata("MEDIUM")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        f:RegisterForDrag("LeftButton")

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        Compat.SolidTexture(bg, 0.05, 0.05, 0.08, 0.9)
        -- Kept so the bar's edge can carry the in/out-of-character state. The
        -- bar is usually read peripherally, mid-conversation, so the signal has
        -- to survive not being looked at directly -- which a word cannot.
        f.border = Compat.AddBorder(f, 0.5, 0.45, 0.7, 0.95)

        local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOP", 0, -6)
        name:SetTextColor(1, 0.82, 0.2)
        f.name = name

        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("BOTTOMLEFT", 8, 6)
        f.sub = sub

        -- IC/OOC is the switch you hit mid-conversation, so it gets a real
        -- button on the bar instead of only a shift-click nobody discovers.
        -- Its own button (like the star) so the click doesn't fall through to
        -- the frame's cycle-on-click, and it forwards the wheel so scrolling
        -- over it still cycles languages.
        local icBtn = CreateFrame("Button", nil, f)
        icBtn:SetPoint("BOTTOMRIGHT", -24, 4)
        icBtn:SetSize(36, 16)
        icBtn:SetFrameLevel(f:GetFrameLevel() + 2)
        icBtn:EnableMouseWheel(true)
        icBtn:SetScript("OnMouseWheel", function(_, delta)
            if ns.CycleLanguage then ns.CycleLanguage(delta > 0 and 1 or -1) end
        end)
        local icHL = icBtn:CreateTexture(nil, "HIGHLIGHT")
        icHL:SetAllPoints()
        Compat.SolidTexture(icHL, 1, 1, 1, 0.18)

        local dot = icBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dot:SetPoint("RIGHT", icBtn, "RIGHT", 0, 0)
        f.dot = dot
        f.icBtn = icBtn

        -- Its tooltip reports the very thing the button changes, and the cursor
        -- is still on it afterwards, so it has to rebuild in place.
        icBtn._toaTooltip = true
        icBtn:SetScript("OnClick", function() toggleInCharacter() end)
        icBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local inChar = db().inCharacter
            GameTooltip:SetText(inChar and "Speaking in character" or "Speaking out of character", 1, 1, 1)
            if inChar then
                GameTooltip:AddLine("Your chat is translated and accented on the channels you picked.", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine("Your chat goes out exactly as you type it.", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:AddLine("You read and decode everyone else either way.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffClick|r  Switch", 1, 1, 1)
            local key = GetBindingKey and GetBindingKey("TONGUESOFAZEROTH_TOGGLE_IC")
            if key then GameTooltip:AddLine("|cffffffffKeybind|r  " .. key, 1, 1, 1) end
            GameTooltip:Show()
        end)
        icBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
        fav._toaTooltip = true
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
                    "No favorites yet. Star a language on its row under Options -> Languages.",
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
                    toggleInCharacter()
                elseif ns.CycleLanguage then
                    ns.CycleLanguage(1)
                end
            elseif button == "RightButton" then
                if widgetMenu and widgetMenu:IsShown() then closeWidgetMenu() else openWidgetMenu() end
            end
        end)
        f._toaTooltip = true
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Tongues of Azeroth", 1, 1, 1)
            GameTooltip:AddLine("Language: |cffffffff" .. Language.GetLanguageName(db().language) .. "|r", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffLeft-click|r  Next language", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffScroll|r  Cycle languages", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffStar|r  Scroll only favorites", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffShift-click|r  Toggle in character", 1, 1, 1)
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

    -- Opens the Languages panel. Kept as an explicit button so the sub-panel is
    -- reachable from the standalone window too, which has no options tree to
    -- navigate.
    local learnedBtn = makeNavButton("Languages", function()
        if ns.OpenLearnedConfig then ns.OpenLearnedConfig() end
    end)
    learnedBtn:SetPoint("TOPRIGHT", trainerBtn, "BOTTOMRIGHT", 0, -4)

    local chatBtn = makeNavButton("Chat", function()
        if ns.OpenChatConfig then ns.OpenChatConfig() end
    end)
    chatBtn:SetPoint("TOPRIGHT", learnedBtn, "BOTTOMRIGHT", 0, -4)

    local accentBtn = makeNavButton("Accents", function()
        if ns.OpenAccentConfig then ns.OpenAccentConfig() end
    end)
    accentBtn:SetPoint("TOPRIGHT", chatBtn, "BOTTOMRIGHT", 0, -4)

    local customBtn = makeNavButton("Create Language", function()
        if ns.OpenCustomConfig then ns.OpenCustomConfig() end
    end)
    customBtn:SetPoint("TOPRIGHT", accentBtn, "BOTTOMRIGHT", 0, -4)

    local castBtn = makeNavButton("Cast Phrases", function()
        if ns.OpenCastConfig then ns.OpenCastConfig() end
    end)
    castBtn:SetPoint("TOPRIGHT", customBtn, "BOTTOMRIGHT", 0, -4)

    -- One switch over everything the addon says in your name: the tongue, the
    -- accent, and the cast phrases with the voice clips that ride on them. It
    -- is still not an "is the addon on" switch -- with it off you read other
    -- players, get the colors and go on training exactly as before. It mutes
    -- what you send. It's the thing you hit to answer your raid leader in
    -- plain English and hit again after.
    enableCheck = Compat.CreateCheckbox(content, "Speak in character")
    enableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    enableCheck:SetScript("OnClick", function(self)
        db().inCharacter = self:GetChecked() and true or false
        if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshMain() end
    end)

    local enableHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    enableHint:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 24, -2)
    enableHint:SetPoint("RIGHT", content, "RIGHT", -170, 0)
    enableHint:SetJustifyH("LEFT")
    if enableHint.SetWordWrap then enableHint:SetWordWrap(true) end
    enableHint:SetText("Off mutes everything this addon says for you: your chat goes out exactly as typed, with no accent, and cast phrases stay quiet. You still read, color and decode everyone else either way. Applies to the channels picked under |cffffd200Chat|r.")

    -- The voice readout and the preview used to live here. They moved to
    -- Languages, which is where the tongue, the fluency and the color are all
    -- picked now: hearing the result is part of tuning it, so the preview
    -- belongs beside the dials that move it, not one panel away from them.
    -- What is left here is the one switch that governs the whole addon, plus
    -- the furniture below, and the navigation buttons out to everything else.

    -- Addon furniture, set once and forgotten -- but on this panel rather than
    -- buried in a sub-panel, because "where do I turn off the minimap button"
    -- is a question people arrive with.
    -- Inset past the nav button column on the right: with the voice block gone
    -- this header sits high enough to collide with it.
    local ifaceHeader = sectionHeader(content, "Interface", 170)
    ifaceHeader:SetPoint("TOPLEFT", enableHint, "BOTTOMLEFT", -24, -20)

    minimapCheck = Compat.CreateCheckbox(content, "Show minimap button")
    minimapCheck:SetPoint("TOPLEFT", ifaceHeader, "BOTTOMLEFT", 0, -8)
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
        RefreshMain()
    end)

    widgetLockCheck = Compat.CreateCheckbox(content, "Lock the floating bar in place")
    widgetLockCheck:SetPoint("TOPLEFT", widgetCheck, "BOTTOMLEFT", 16, -6)
    widgetLockCheck:SetScript("OnClick", function(self)
        db().widget.locked = self:GetChecked() and true or false
    end)

    -- Last element, so the scroll height can be sized to it exactly. Which one
    -- that is depends on whether the lock row is showing; layoutMainWidgetLock
    -- keeps it current.
    mainPanel._lastChild = widgetLockCheck

    mainPanel.refresh = RefreshMain
    mainPanel:SetScript("OnShow", RefreshMain)
end

--=========================================================================--
--  Chat panel
--  Everything about the chat pipeline itself, split by the two directions it
--  runs in: what leaves your keyboard, and what arrives in your window. These
--  settings were previously spread across the main panel (channels, tag
--  fluency, the instance pause) and the language list (decode style, output
--  window), where neither group had anything to do with its neighbours.
--=========================================================================--
local function BuildChatPanel()
    chatPanel = Compat.CreateOptionsPanel("TonguesOfAzerothChatOptions")
    chatPanel.name = "Chat"
    chatPanel.parent = mainPanel.name

    local content = Compat.CreateScrollContent(chatPanel, 700)
    chatContent = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Chat")

    local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Where translation applies, and how foreign speech reads when it reaches you.")

    --------------------------------------------------------------------
    -- When you speak
    --------------------------------------------------------------------
    local speakHeader = sectionHeader(content, "When you speak")
    speakHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)

    local channelHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", speakHeader, "BOTTOMLEFT", 0, -6)
    channelHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    channelHint:SetJustifyH("LEFT")
    channelHint:SetText("The channels you're in character on. Your tongue and your accent both follow this list; anywhere unchecked, you speak plainly.")

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

    -- Anchor for whatever follows the two-column channel grid.
    local channelBottom = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelBottom:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -10 - half * ROW_H)
    channelBottom:SetText(" ")

    -- The [Language] tag itself is always on (it's what lets other players decode
    -- your speech reliably), so it isn't exposed as a setting. Only the optional
    -- fluency adjective prefix is configurable.
    fluencyCheck = Compat.CreateCheckbox(content, "Show fluency in tag (e.g. [Broken Orcish])")
    fluencyCheck:SetPoint("TOPLEFT", channelBottom, "BOTTOMLEFT", 0, -4)
    fluencyCheck:SetScript("OnClick", function(self)
        db().tagFluency = self:GetChecked() and true or false
        refreshPreview()
    end)

    namesCheck = Compat.CreateCheckbox(content, "Leave player names readable")
    namesCheck:SetPoint("TOPLEFT", fluencyCheck, "BOTTOMLEFT", 0, -8)
    namesCheck:SetScript("OnClick", function(self)
        db().protectNames = self:GetChecked() and true or false
        RefreshChat()
        refreshPreview()
    end)
    namesCheck._toaTooltip = true
    namesCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Leave player names readable", 1, 0.82, 0)
        GameTooltip:AddLine(
            "Names pass through untranslated, the way a real language treats a "
                .. "proper noun, so someone can tell they're being addressed even "
                .. "when they can't read the rest.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "Recognises people who have spoken near you, your group, guild and "
                .. "friends, and whoever you target. A name only counts when you "
                .. "capitalise it, so ordinary words keep translating.",
            0.6, 0.6, 0.6, true)
        if ns.Names then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.Names.Count() .. " name(s) remembered right now.", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    namesCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Indented because it only means anything while the box above is ticked.
    nameColorCheck = Compat.CreateCheckbox(content, "Color those names in your chat window")
    nameColorCheck:SetPoint("TOPLEFT", namesCheck, "BOTTOMLEFT", 16, -6)
    nameColorCheck:SetScript("OnClick", function(self)
        db().colorNames = self:GetChecked() and true or false
        refreshPreview()
    end)
    nameColorCheck._toaTooltip = true
    nameColorCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Color those names", 1, 0.82, 0)
        GameTooltip:AddLine(
            "A name that came through untranslated and a word your fluency "
                .. "happened to leave in English look identical. Coloring the "
                .. "names says which is which.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "Class color when the class is known -- from your group, guild, "
                .. "friends or whoever you've targeted -- and "
                .. "|cff" .. (ns.Colors and ns.Colors.NameHex() or "ffd100") .. "gold|r "
                .. "otherwise.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "Only your own chat window is painted. Nothing is added to the "
                .. "message other people receive.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    nameColorCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    autoDisableCheck = Compat.CreateCheckbox(content, "Pause translation during instances")
    autoDisableCheck:SetPoint("TOPLEFT", nameColorCheck, "BOTTOMLEFT", -16, -8)
    autoDisableCheck:SetScript("OnClick", function(self)
        db().autoDisableInInstances = self:GetChecked() and true or false
        -- Apply immediately if we're already inside an instance.
        if ns.RefreshInstanceState then ns.RefreshInstanceState() end
    end)

    -- The instance restriction is a Blizzard limitation, not an addon bug. It
    -- sits with the option it explains rather than at the top of the panel you
    -- land on, where it was the first thing a new player read.
    local instanceNote = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    instanceNote:SetPoint("TOPLEFT", autoDisableCheck, "BOTTOMLEFT", 24, -2)
    instanceNote:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    instanceNote:SetJustifyH("LEFT")
    if instanceNote.SetWordWrap then instanceNote:SetWordWrap(true) end
    instanceNote:SetText("|cffffd200Heads-up:|r During boss fights Blizzard blocks addons from reading chat, so ToA can't translate or decode inside instances either way. This is a game restriction, not a bug. Accents are unaffected and keep working there.")

    --------------------------------------------------------------------
    -- When you listen
    --------------------------------------------------------------------
    local listenHeader = sectionHeader(content, "When you listen")
    listenHeader:SetPoint("TOPLEFT", instanceNote, "BOTTOMLEFT", -24, -20)

    local listenHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listenHint:SetPoint("TOPLEFT", listenHeader, "BOTTOMLEFT", 0, -6)
    listenHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    listenHint:SetJustifyH("LEFT")
    if listenHint.SetWordWrap then listenHint:SetWordWrap(true) end
    listenHint:SetText("How a tongue you understand is shown to you once it's decoded. Which languages you understand is set under |cffffd200Languages|r.")

    local styleLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", listenHint, "BOTTOMLEFT", 0, -12)
    styleLabel:SetText("Decode display style")

    decodeStyleDropdown = Compat.CreateDropdown(content, 220)
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
    local outputLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outputLabel:SetPoint("TOPLEFT", styleLabel, "TOPLEFT", 250, 0)
    outputLabel:SetText("Show translations in")

    outputDropdown = Compat.CreateDropdown(content, 220)
    outputDropdown:SetPoint("TOPLEFT", outputLabel, "BOTTOMLEFT", 0, -6)
    outputDropdown:SetItems(outputItems())
    outputDropdown.onSelect = function(value)
        db().outputFrame = value
        outputDropdown:SetSelected(value, outputWindowLabel(value))
    end

    local colorPointer = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colorPointer:SetPoint("TOPLEFT", decodeStyleDropdown, "BOTTOMLEFT", 0, -14)
    colorPointer:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    colorPointer:SetJustifyH("LEFT")
    if colorPointer.SetWordWrap then colorPointer:SetWordWrap(true) end
    colorPointer:SetText("Per-language chat colors live with the languages themselves, under |cffffd200Languages|r.")

    chatPanel._lastChild = colorPointer
    chatPanel.refresh = RefreshChat
    chatPanel:SetScript("OnShow", RefreshChat)
end

-- Small square icon button with a tooltip: the check and circle-slash pair used
-- on the language rows, and on a phrase row while it is being reworded. Shared
-- so that accepting a change looks the same everywhere it can be accepted.
local function iconButton(parent, tex, tip, r, g, b, size)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size or 24, size or 24)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    Compat.SolidTexture(bg, 0.16, 0.15, 0.20, 1)
    Compat.AddBorder(btn, r or 0.5, g or 0.45, b or 0.7, 0.9)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize((size or 24) - 8, (size or 24) - 8)
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

local ICON_ACCEPT = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local ICON_DISCARD = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local function BuildLearnedPanel()
    learnedPanel = Compat.CreateOptionsPanel("TonguesOfAzerothLearnedOptions")
    -- "Learned Languages" while it only held the learned list. It is the
    -- per-language panel now -- fluency, color and what you understand, all
    -- edited on the same row -- and the shorter name says that.
    learnedPanel.name = "Languages"
    learnedPanel.parent = mainPanel.name

    local title = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Languages")

    local subtitle = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Which tongue you speak, how fluently you speak each one, and the color it reads in. |cffffd200Drag the handle|r on a bar to set fluency; |cffffd200star|r a language to keep it near the top. The tongue you're speaking is always the first row.")

    -- "Which language am I speaking" lives here, not on the panel you land on.
    -- It is the same kind of setting as the fluency and color on the rows
    -- below -- pick the tongue, then set it up -- and splitting it off onto the
    -- front panel is what sent people hunting for it here in the first place.
    --
    -- A dropdown rather than making the rows selectable, because the rows are
    -- primaries only (a sub-dialect shares its parent's fluency and color, so
    -- it gets no row), while this list also carries sub-dialects, your
    -- favorites and "None".
    local speakLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    speakLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    speakLabel:SetText("Speaking")

    langDropdown = Compat.CreateDropdown(learnedPanel, 260)
    langDropdown:SetPoint("TOPLEFT", speakLabel, "BOTTOMLEFT", 0, -6)
    langDropdown:SetItems(langItems())
    langDropdown.onSelect = function(value)
        db().language = value
        -- Goes through the shared refresh: the landing panel's voice summary
        -- and the floating bar both report this.
        if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshLearned() end
    end
    -- Favoriting moved to the stars on the language rows below; this list still
    -- groups your favorites at the top, it just no longer sets them. Right-click
    -- stays, without a star drawn on every row, because it is the only way to
    -- favorite a *sub-dialect* -- the rows below are primaries, so Eldre'Thalassian
    -- (Skyborne) has no star of its own to click.
    langDropdown.onAltClick = function(value)
        if ns.ToggleFavorite then ns.ToggleFavorite(value) end
        if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshLearned() end
    end

    -- Global learning method: passive (learn by hearing). The Trainer minigame is
    -- always available from its own panel; this toggles the automatic learning.
    passiveCheck = Compat.CreateCheckbox(learnedPanel, "Passive learning -- overhearing a tongue slowly builds your fluency in it")
    passiveCheck:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 0, -14)
    passiveCheck:SetScript("OnClick", function(self)
        db().passiveLearning = self:GetChecked() and true or false
    end)

    -- Filters this list and the language dropdown alike, so it belongs with the
    -- list it filters rather than on the panel you land on.
    nativeHideCheck = Compat.CreateCheckbox(learnedPanel, "Hide languages my race already speaks")
    nativeHideCheck:SetPoint("TOPLEFT", passiveCheck, "BOTTOMLEFT", 0, -6)
    nativeHideCheck:SetScript("OnClick", function(self)
        db().hideNativeLanguages = self:GetChecked() and true or false
        if ns.EnsureSpeakLanguageVisible then ns.EnsureSpeakLanguageVisible() end
        -- Rebuilds the dropdown item list (and refreshes the panel) so the change
        -- shows immediately.
        if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshLearned() end
    end)

    -- Chat colors. Labels are kept short so the three sit on one line and cost
    -- the language list below only a single row of height; the detail lives in
    -- the tooltips. They sit here, above the list, because the per-language
    -- swatches are on its rows -- the switch next to the thing it switches.
    local function colorCheck(label, tip, get, set)
        local cb = Compat.CreateCheckbox(learnedPanel, label)
        cb:SetScript("OnClick", function(self)
            if ns.Colors then set(self:GetChecked() and true or false) end
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        end)
        cb:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
        cb._get = get
        return cb
    end

    colorTagCheck = colorCheck("Color tags",
        "Paint the [Language] tag in that tongue's color, so you can tell Demonic from Old God at a glance -- including on lines you can't read yet.\n\nIndependent of \"Tint speech\": turn this off with that on and the words are tinted while the tag stays in its usual color.",
        function() return ns.Colors and ns.Colors.TagsEnabled() end,
        function(v) ns.Colors.SetTagsEnabled(v) end)
    colorTagCheck:SetPoint("TOPLEFT", nativeHideCheck, "BOTTOMLEFT", 0, -10)

    colorSpeechCheck = colorCheck("Tint speech",
        "Color the spoken words themselves. Off by default -- the tag alone marks the language without repainting whole conversations.\n\nIndependent of \"Color tags\": either can be on without the other.",
        function() return ns.Colors and ns.Colors.SpeechEnabled() end,
        function(v) ns.Colors.SetSpeechEnabled(v) end)
    colorSpeechCheck:SetPoint("LEFT", colorTagCheck.labelText, "RIGHT", 24, 0)

    colorRealCheck = colorCheck("Tint in-game languages",
        "Also color WoW's own languages from players who don't run the addon. Off by default: nearly all chat is Common or your faction's tongue, so this tints most of the window rather than picking anything out of it.",
        function() return ns.Colors and ns.Colors.RealLanguagesEnabled() end,
        function(v) ns.Colors.SetRealLanguagesEnabled(v) end)
    colorRealCheck:SetPoint("LEFT", colorSpeechCheck.labelText, "RIGHT", 24, 0)

    -- What everything above and below adds up to. Every dial that shapes your
    -- voice is on this panel now, so the readout and the preview are too: pick
    -- the tongue, drag its fluency, watch the line change.
    --
    -- Full width, on its own line. Squeezing it into a second column beside the
    -- Speaking dropdown fit the panel but not the content -- the preview is a
    -- sentence, and half a panel is not enough to read one in.
    --
    -- The summary shares the header's line rather than taking another, so the
    -- block costs the language list as little height as possible.
    local voiceLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    voiceLabel:SetPoint("TOPLEFT", colorTagCheck, "BOTTOMLEFT", 0, -16)
    voiceLabel:SetText("Your voice")
    voiceLabel:SetTextColor(1, 0.82, 0.2)

    voiceText = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    voiceText:SetPoint("LEFT", voiceLabel, "RIGHT", 10, 0)
    voiceText:SetJustifyH("LEFT")

    local voiceRule = learnedPanel:CreateTexture(nil, "ARTWORK")
    voiceRule:SetHeight(1)
    voiceRule:SetPoint("LEFT", voiceText, "RIGHT", 8, 0)
    voiceRule:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    Compat.SolidTexture(voiceRule, 1, 1, 1, 0.12)

    voiceHint = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    voiceHint:SetPoint("TOPLEFT", voiceLabel, "BOTTOMLEFT", 0, -6)
    voiceHint:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    voiceHint:SetJustifyH("LEFT")

    local previewLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", voiceHint, "BOTTOMLEFT", 0, -10)
    previewLabel:SetText("Preview")

    previewInput = CreateFrame("EditBox", "TonguesOfAzerothPreviewInput", learnedPanel, "InputBoxTemplate")
    previewInput:SetPoint("LEFT", previewLabel, "RIGHT", 12, 0)
    previewInput:SetPoint("RIGHT", learnedPanel, "RIGHT", -36, 0)
    previewInput:SetHeight(20)
    previewInput:SetAutoFocus(false)
    previewInput:SetText(SAMPLE)
    previewInput:SetScript("OnTextChanged", refreshPreview)
    previewInput:SetScript("OnEnterPressed", previewInput.ClearFocus)
    previewInput:SetScript("OnEscapePressed", previewInput.ClearFocus)

    previewOutput = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    previewOutput:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -8)
    previewOutput:SetPoint("RIGHT", learnedPanel, "RIGHT", -32, 0)
    previewOutput:SetJustifyH("LEFT")
    previewOutput:SetHeight(32)
    previewOutput:SetSpacing(2)

    local langLabel = learnedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", previewOutput, "BOTTOMLEFT", 0, -14)
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
    note:SetText("Fluency is how fully you speak a tongue -- build it by hearing it, in the Language Trainer, or with the buttons above. Decoding only works on text produced by Tongues of Azeroth.")

    -- Scrollable single-column list: each row is a language with its fluency bar
    -- and two icon buttons -- a check (make fully fluent) and a circle-slash
    -- (reset to 0%), both behind a confirmation. Mouse-wheel scrolls.
    local scroll = CreateFrame("ScrollFrame", "TonguesOfAzerothLearnedScroll", learnedPanel)
    scroll:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", note, "TOPRIGHT", 0, 10)
    scroll:EnableMouseWheel(true)

    local ROW_H = 38
    learnedRowH = ROW_H
    local CHILD_W = 560

    local child = CreateFrame("Frame", nil, scroll)
    -- A scroll child needs a real size of its own: at zero width it draws
    -- nothing at all, however many rows are parented to it. Only the width is
    -- settled here -- reflowLearnedRows owns the height, which depends on how
    -- many rows are actually shown.
    child:SetSize(CHILD_W, ROW_H)
    scroll:SetScrollChild(child)
    learnedScroll, learnedChild = scroll, child

    -- One row per primary language; sub-languages share their parent's word set
    -- (and fluency), so the parent covers them. Rows for tongues your race
    -- natively speaks are hidden and re-flowed in RefreshLearned.
    --
    -- Kept as a function rather than a loop so a language registered *after*
    -- this panel was built can still get one. Creating a tongue on the Create
    -- Language panel has to produce a full citizen here -- fluency bar, color
    -- swatch, star -- not just a new line in the Speaking dropdown.
    makeLearnedRow = function(entry)
        local rowF = CreateFrame("Frame", nil, child)
        rowF:SetSize(CHILD_W, ROW_H)
        -- Placeholder anchor; reflowLearnedRows sets the real position and this
        -- row's place in the order every refresh.
        rowF:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)

        -- Favorite star, at the head of the row where it marks the row rather
        -- than acting on it. It used to live on the Speaking dropdown's rows,
        -- which put the one control for curating a shortlist inside the long
        -- list the shortlist exists to shorten: you had to go hunting through
        -- seventy entries to mark the handful that would have saved you the
        -- hunt. Here it sits beside the fluency and the color, with the rest of
        -- what you set per language.
        local star = CreateFrame("Button", nil, rowF)
        star:SetSize(18, 18)
        star:SetPoint("TOPLEFT", rowF, "TOPLEFT", 2, -2)
        star.tex = star:CreateTexture(nil, "ARTWORK")
        star.tex:SetAllPoints()
        local starHL = star:CreateTexture(nil, "HIGHLIGHT"); starHL:SetAllPoints()
        Compat.SolidTexture(starHL, 1, 1, 1, 0.25)
        star:SetScript("OnClick", function()
            if ns.ToggleFavorite then ns.ToggleFavorite(entry.id) end
            if ns.OnSettingsChanged then ns.OnSettingsChanged() else RefreshLearned() end
        end)
        star._toaTooltip = true
        star:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name, 1, 1, 1)
            local on = ns.IsFavorite and ns.IsFavorite(entry.id)
            GameTooltip:AddLine(on and "A favorite. Sorted to the top of this list and of the Speaking dropdown, and included when you cycle languages."
                or "Favorite it to sort it to the top of this list and of the Speaking dropdown, and to cycle to it with the next/previous language keybinds.",
                0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        star:SetScript("OnLeave", function() GameTooltip:Hide() end)
        learnedStars[entry.id] = star

        local name = rowF:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        name:SetPoint("TOPLEFT", star, "TOPRIGHT", 6, -1)
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

        -- Color swatch. Left-click opens the picker, right-click restores the
        -- shipped color. Only primary languages get a row here, which lines up
        -- with the palette itself: a sub-dialect inherits its parent's color, so
        -- recoloring Zandali recolors Amani with it. Setting a sub apart is
        -- still possible, just from the slash command.
        local swatch = CreateFrame("Button", nil, rowF)
        swatch:SetSize(24, 24)
        local swatchFill = swatch:CreateTexture(nil, "BACKGROUND")
        swatchFill:SetAllPoints()
        Compat.SolidTexture(swatchFill, 1, 1, 1, 1)
        Compat.AddBorder(swatch, 0.5, 0.45, 0.7, 0.9)
        local swatchHL = swatch:CreateTexture(nil, "HIGHLIGHT"); swatchHL:SetAllPoints()
        Compat.SolidTexture(swatchHL, 1, 1, 1, 0.25)
        swatch.fill = swatchFill
        swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        swatch:SetScript("OnClick", function(_, button)
            if not ns.Colors then return end
            if button == "RightButton" then
                ns.Colors.Reset(entry.id)
                if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                return
            end
            local r, g, b = ns.Colors.Get(entry.id)
            local opened = Compat.ShowColorPicker({
                r = r, g = g, b = b,
                -- Applied live as the player drags, so chat and the swatch
                -- preview the color before they commit to it.
                onChange = function(nr, ng, nb)
                    ns.Colors.Set(entry.id, nr, ng, nb)
                    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                end,
                onCancel = function(or_, og, ob)
                    ns.Colors.Set(entry.id, or_, og, ob)
                    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
                end,
            })
            if not opened and ns.Print then
                ns.Print("No color picker on this client -- use |cffffff00/toa color "
                    .. entry.id .. " <hex>|r instead.")
            end
            if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        end)
        swatch._toaTooltip = true
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name, 1, 1, 1)
            if ns.Colors then
                local hex = ns.Colors.Hex(entry.id)
                GameTooltip:AddLine("|cff" .. hex .. hex .. "|r"
                    .. (ns.Colors.IsCustom(entry.id) and "  (custom)" or "  (default)"), 1, 1, 1)
            end
            GameTooltip:AddLine("|cffffffffClick|r  Pick a color", 1, 1, 1)
            GameTooltip:AddLine("|cffffffffRight-click|r  Back to the default", 1, 1, 1)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
        learnedSwatches[entry.id] = swatch

        local fluentBtn = iconButton(rowF, "Interface\\RAIDFRAME\\ReadyCheck-Ready",
            "Make " .. entry.name .. " fully fluent (100%)", 0.4, 0.6, 0.4)
        fluentBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
        swatch:SetPoint("RIGHT", fluentBtn, "LEFT", -8, 0)
        fluentBtn:SetScript("OnClick", function()
            Compat.ShowConfirm({
                text = string.format("Become fully fluent in \"%s\"?\n\nThis instantly sets your fluency to 100%% (you'll speak and understand it perfectly).", entry.name),
                onAccept = function() if ns.MakeLanguageFluent then ns.MakeLanguageFluent(entry.id) end end,
            })
        end)

        -- Fluency bar beneath the label (left of the buttons). Draggable: this
        -- is the one place fluency is edited now. The front panel used to carry
        -- a fluency slider, which read like a live "how much comes through"
        -- dial but silently overwrote character progress -- so the number lives
        -- here, on the row it belongs to, where dragging it obviously means
        -- "change how well I know THIS language".
        -- Right margin for the button cluster, plus the star the name is now
        -- indented past.
        local barW = CHILD_W - 132
        local bar = CreateFrame("Frame", nil, rowF)
        bar:SetSize(barW, 8)
        bar:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        bar:EnableMouse(true)
        -- 8px is too thin to grab; extend the hit area above and below without
        -- growing the drawn bar.
        bar:SetHitRectInsets(0, 0, -5, -5)
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

        local hover = bar:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        Compat.SolidTexture(hover, 1, 1, 1, 0.15)

        -- A track with a lit section reads as a progress meter: it reports, it
        -- doesn't invite. The cap is what makes it legible as a slider without
        -- having to hover it for the tooltip -- and it is drawn at every value
        -- including 0%, where the fill is hidden and there would otherwise be
        -- nothing on screen to take hold of.
        --
        -- Taller than the 8px track on purpose, so it reads as sitting on the
        -- bar rather than being part of it -- but only by 3px a side. The bar
        -- clears the name above it by 3px, so a cap much taller than this
        -- crowds the text it belongs to. Well within the hit area
        -- SetHitRectInsets already added, so the cap stays grabbable
        -- everywhere it is visible. Created after the fill: within one draw
        -- layer, later textures sit on top.
        local thumbEdge = bar:CreateTexture(nil, "OVERLAY")
        thumbEdge:SetSize(9, 14)
        thumbEdge:SetPoint("CENTER", bar, "LEFT", 0, 0)
        Compat.SolidTexture(thumbEdge, 0.04, 0.04, 0.06, 1)
        local thumb = bar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(7, 12)
        thumb:SetPoint("CENTER", thumbEdge, "CENTER")
        Compat.SolidTexture(thumb, 0.80, 0.80, 0.86, 1)
        bar.thumb, bar.thumbEdge = thumb, thumbEdge

        local function litThumb(self, lit)
            if not self.thumb then return end
            if lit then
                Compat.SolidTexture(self.thumb, 1, 1, 1, 1)
            else
                Compat.SolidTexture(self.thumb, 0.80, 0.80, 0.86, 1)
            end
        end

        local function fluencyFromCursor(self)
            local left, scale = self:GetLeft(), self:GetEffectiveScale()
            if not left or not scale or scale == 0 then return end
            local x = (GetCursorPosition() / scale) - left
            local frac = x / (self.barW > 0 and self.barW or 1)
            if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
            if ns.SetLanguageFluency then ns.SetLanguageFluency(entry.id, frac) end
            -- The lightweight refresh: this runs once per frame for the length
            -- of a drag, and the full one rebuilds the language dropdown's item
            -- list every time it is called.
            if ns.RefreshFluencyIfShown then
                ns.RefreshFluencyIfShown()
            elseif ns.OnSettingsChanged then
                ns.OnSettingsChanged()
            end
            if GameTooltip:IsOwned(self) then bar:GetScript("OnEnter")(self) end
        end

        bar:SetScript("OnMouseDown", function(self)
            self.dragging = true
            litThumb(self, true)
            fluencyFromCursor(self)
            -- OnUpdate only runs while a drag is in progress; leaving it
            -- attached would tick once per frame per language row.
            self:SetScript("OnUpdate", function(s)
                if s.dragging then fluencyFromCursor(s) else s:SetScript("OnUpdate", nil) end
            end)
        end)
        local function endDrag(self)
            self.dragging = false
            self:SetScript("OnUpdate", nil)
            litThumb(self, self:IsMouseOver())
        end
        bar:SetScript("OnMouseUp", endDrag)
        -- The cursor routinely leaves an 8px bar mid-drag; without this the row
        -- would keep tracking the mouse across the whole panel.
        bar:SetScript("OnHide", endDrag)
        bar:SetScript("OnEnter", function(self)
            litThumb(self, true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name, 1, 1, 1)
            GameTooltip:AddLine("Fluency: |cffffd200" .. fluencyPct(entry.id) .. "%|r", 1, 1, 1)
            GameTooltip:AddLine("How much of this tongue you speak and understand.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffDrag the handle|r  Set fluency", 1, 1, 1)
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function(self)
            if not self.dragging then litThumb(self, false) end
            GameTooltip:Hide()
        end)

        learnedRows[entry.id] = { name = name, bar = bar, fluentBtn = fluentBtn, row = rowF }
    end

    -- syncLearnedRows owns learnedOrder, so it does the first pass too.
    syncLearnedRows()

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
    if accentDropdown then accentDropdown:SetSelected(d.accent.id, Accent.GetAccentName(d.accent.id)) end
    if accentSlider then accentSlider:SetValue(d.accent.strength) end
    if accentValueText then accentValueText:SetText(d.accent.strength .. "%") end
    local tails = d.accent.tails or Accent.TAIL_DIAL_DEFAULT
    if accentTailSlider then accentTailSlider:SetValue(tails) end
    if accentTailValueText then accentTailValueText:SetText(Accent.DescribeTailFrequency(tails)) end
    if accentEmotesCheck then accentEmotesCheck:SetChecked(d.accent.emotes) end
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

    -- No enable checkbox here any more: "None" in the list below is the off
    -- switch, and whether your voice applies at all is the one in-character
    -- switch on the front panel.
    local hint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    hint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    hint:SetJustifyH("LEFT")
    if hint.SetWordWrap then hint:SetWordWrap(true) end
    hint:SetText("Your accent layers onto whatever your fluency leaves in English, so the two stack instead of competing -- speak Orcish at 50% and the English half still sounds like you. Text in (parentheses) is always left as plain speech. Needs |cffffd200Speak in character|r on, and applies to the channels picked under |cffffd200Chat|r.")

    local accentLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    accentLabel:SetText("Accent")

    accentDropdown = Compat.CreateDropdown(content, 260)
    accentDropdown:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -6)
    accentDropdown:SetItems(accentItems())
    accentDropdown.onSelect = function(value)
        db().accent.id = value
        accentDropdown:SetSelected(value, Accent.GetAccentName(value))
        -- Goes through the shared refresh so the copy of this dropdown on the
        -- front panel, and the preview there, follow it.
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
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

    -- The accent used to carry its own copy of the channel grid, so "where does
    -- my voice apply" had two answers that could quietly disagree. One list
    -- under Chat governs both halves now; this just points at it.
    local channelHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelHint:SetPoint("TOPLEFT", accentEmotesCheck, "BOTTOMLEFT", 0, -14)
    channelHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    channelHint:SetJustifyH("LEFT")
    if channelHint.SetWordWrap then channelHint:SetWordWrap(true) end
    channelHint:SetText("Your accent follows the same channels as your tongue -- pick them under |cffffd200Chat|r.")

    local previewLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelHint, "BOTTOMLEFT", 0, -16)
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

-- Close the open reword, if there is one. `save` is the default answer for
-- everything except an explicit discard, because clicking away from a line you
-- have just retyped is universally read as "keep that" -- losing it is the only
-- outcome nobody ever wants. A save that fails validation deliberately does NOT
-- close: the editor stays open with the text still in it and the reason on
-- screen, so a rejected line is something you fix rather than something you
-- watch disappear. Returns whether the editor is now closed.
local function castFinishEdit(save)
    if not castEdit then return true end
    if not save or castEdit.typed == nil or castEdit.typed == castEdit.from then
        castEdit = nil
        return true
    end
    local ok, err = Casts.SetPhraseText(castSelectedKey, castEdit.orig, castEdit.typed)
    if ok then
        castEdit = nil
        castStatusMsg("Saved.", false)
        return true
    end
    castStatusMsg("Not saved: " .. tostring(err) .. ". Fix it, or discard it with Escape.", true)
    return false
end

-- Leaving the spell, or the panel, behind. The same rule -- keep what was typed
-- -- except that there is nowhere to hold a line the validator refuses, since
-- the editor is about to leave with the spell the line belonged to. The only two
-- refusals are an empty box and a line you already have, neither of which is
-- worth refusing to change spell over.
local function castLeaveEdit()
    if not castFinishEdit(true) then castEdit = nil end
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

-- What a row says about where its line came from. Yours say nothing -- you know
-- where they came from -- so the label is only there to name the pack a shipped
-- line arrived with.
local function phraseSourceLabel(phrase)
    if phrase.user or not phrase.pack then return "" end
    local packs = (ns.CastLibrary and ns.CastLibrary.GetPacks()) or {}
    for _, p in ipairs(packs) do
        if p.id == phrase.pack then return p.name end
    end
    return ""
end

local function layoutCastPacks()
    if not (castPackAnchor and castPackBottom) then return end
    local c = castDB()
    local showOther = c and c.showOtherPacks
    local mine = ns.CastLibrary and ns.CastLibrary.PackForPlayer()
    local packs = (ns.CastLibrary and ns.CastLibrary.GetPacks()) or {}

    local mainList = {}
    for _, pack in ipairs(packs) do
        local check = castPackChecks[pack.id]
        if check then
            if pack.kind == "universal" or pack.id == mine
                or (pack.kind == "class" and showOther) then
                mainList[#mainList + 1] = check
                check:Show()
            else
                check:Hide()
            end
        end
    end

    -- colAnchor is the LEFT-hand checkbox of the row being filled, and it is
    -- what everything below the grid hangs off. Anchoring to "the last checkbox
    -- placed" instead looks equivalent and is not: on an even count that is a
    -- right-hand checkbox, sitting 240px in, and every section below inherits
    -- the indent. Both columns of a row are the same height, so the left one
    -- gives the same vertical position with none of that.
    local colAnchor = castPackAnchor
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
    end
    castPackBottom:ClearAllPoints()
    castPackBottom:SetPoint("TOPLEFT", colAnchor, "BOTTOMLEFT", 0, 0)
end

-- Rows are created once and reused, so switching between a spell with two
-- phrases and one with twelve doesn't leak frames.
-- Every row is two strips: the phrase, and the voice it speaks in. The voice
-- picker is permanent rather than something editing reveals, because the whole
-- reason it exists is that a line can read one way and sound another -- a state
-- you have to be able to see across the whole list at a glance, not one row at
-- a time. Hiding it also broke it outright: Compat's dropdown closes its menu
-- on OnHide, and clicking the picker took focus off the edit box, which closed
-- the edit, which hid the picker, which shut the menu the click had just opened.
--
-- Editing adds a third strip, the preview of what the line will read as. Rows
-- anchor to the row above, so a row that grows pushes the rest down.
local ROW_LINE_H = 22
local ROW_VOICE_H = 30
local ROW_REST_H = ROW_LINE_H + ROW_VOICE_H
local ROW_EDIT_H = ROW_REST_H + 18

-- Three columns, shared by both strips of the row, because a row read down the
-- list is read as columns whether or not it was built as any.
--
--   [ - 50% + ] [ the words ....................... ] [ what to do about it ]
--   [   Says   ] [ who says it, and what ........... ] [ Browse  Play  x    ]
--
-- The phrase and the line it is pinned to start at the same x, so the eye goes
-- down the words rather than stepping around the controls between them; the
-- controls all end at the same right edge for the same reason.
local ROW_TEXT_X = 84      -- clear of the - 50% + block
local ROW_GUTTER = 96      -- Revert, or the name of the pack the line came from

local function castRow(index, parent)
    if castRows[index] then return castRows[index] end

    -- A Button rather than a Frame so the whole row is the edit affordance.
    -- An "Edit" button would have to come out of the phrase column, which is the
    -- one part of the row that is already too narrow for the longer library
    -- lines; the child buttons swallow their own clicks, so nothing is lost.
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_REST_H)

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

    -- The phrase itself and its controls live on a strip pinned to the top of
    -- the row, rather than on the row directly. Everything up here is centred
    -- vertically on what it is anchored to, so anchoring to a row that grows
    -- would slide the whole line downwards as the editor opened beneath it.
    --
    -- A Button, so the strip is the edit affordance rather than the whole row:
    -- the voice picker below it has its own meaning, and clicking beside it
    -- ought not to open an editor nobody asked for.
    row.line1 = CreateFrame("Button", nil, row)
    row.line1:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.line1:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.line1:SetHeight(ROW_LINE_H)

    -- A pair of nudge buttons rather than a slider: at 22px tall there's no
    -- room for a slider's labels, and the whole range is six steps.
    row.down = tinyButton("-")
    row.down:SetPoint("LEFT", row.line1, "LEFT", 0, 0)
    row.up = tinyButton("+")
    row.up:SetPoint("LEFT", row.down, "RIGHT", 38, 0)

    -- Shown as the share of casts this line will take, not as the 0-5 weight
    -- underneath it. The weight is a number that only means anything next to
    -- the other weights in the same list, which is exactly the comparison a
    -- reader should not have to do in their head.
    row.weight = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.weight:SetPoint("LEFT", row.down, "RIGHT", 0, 0)
    row.weight:SetWidth(38)
    row.weight:SetJustifyH("CENTER")

    -- The pack a line came from used to be named twice on the same row: once
    -- prettily on the left of the phrase and once as its raw id on the right.
    -- It is said on the right now, and only there -- the left-hand copy was
    -- holding eighty-eight pixels open on every row, blank on all the ones you
    -- wrote yourself, and pushing the words it labelled out of their own column.
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.line1, "LEFT", ROW_TEXT_X, 0)
    row.text:SetJustifyH("LEFT")
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end

    row.line1:EnableMouse(true)

    row.action = tinyButton("Delete", 56)
    row.action:SetPoint("RIGHT", row.line1, "RIGHT", 0, 0)
    -- A fixed gutter rather than an anchor to whichever of the two is showing,
    -- so the words end in the same place on every row.
    row.text:SetPoint("RIGHT", row.line1, "RIGHT", -ROW_GUTTER, 0)

    -- Faint wash on hover, so the phrase reads as something you can click. It
    -- belongs to the strip rather than the row: a HIGHLIGHT texture only lights
    -- up for the frame that owns it, and washing the voice picker below would
    -- imply it was part of the same click.
    local rowHL = row.line1:CreateTexture(nil, "HIGHLIGHT")
    rowHL:SetAllPoints()
    Compat.SolidTexture(rowHL, 1, 1, 1, 0.07)

    -- Names the pack a library line came from, where the Delete button would be.
    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.source:SetPoint("RIGHT", row.line1, "RIGHT", 0, 0)
    row.source:SetWidth(ROW_GUTTER - 8)
    row.source:SetJustifyH("RIGHT")
    if row.source.SetWordWrap then row.source:SetWordWrap(false) end

    -- Editing happens where the line already is, so you can read it against its
    -- neighbours while rewording it. Built from a bare EditBox rather than
    -- InputBoxTemplate: the template's art carries padding sized for a full-width
    -- field and doesn't sit inside a 22px row.
    -- Keep / discard, the same check and circle-slash the language rows use, and
    -- shown only while this row is open. They are here because Enter used to be
    -- the only way to keep a change and nothing on screen said so: the box looked
    -- like every other field that saves itself, so clicking away from it read as
    -- committing rather than as abandoning. Now clicking away does commit, and
    -- these two say out loud which of the two things a click will do.
    row.discard = iconButton(row, ICON_DISCARD, "Discard this rewording (Escape)", 0.7, 0.4, 0.4, 18)
    row.discard:SetPoint("RIGHT", row.action, "LEFT", -6, 0)
    row.discard:Hide()

    row.keep = iconButton(row, ICON_ACCEPT, "Keep this rewording (Enter)", 0.4, 0.6, 0.4, 18)
    row.keep:SetPoint("RIGHT", row.discard, "LEFT", -4, 0)
    row.keep:Hide()

    row.input = CreateFrame("EditBox", nil, row)
    row.input:SetPoint("LEFT", row.text, "LEFT", -4, 0)
    row.input:SetPoint("RIGHT", row.keep, "LEFT", -6, 0)
    row.input:SetHeight(18)
    row.input:SetAutoFocus(false)
    row.input:SetFontObject("GameFontHighlightSmall")
    row.input:SetTextInsets(4, 4, 0, 0)
    local ibg = row.input:CreateTexture(nil, "BACKGROUND")
    ibg:SetAllPoints()
    Compat.SolidTexture(ibg, 0.06, 0.05, 0.10, 1)
    Compat.AddBorder(row.input, 0.6, 0.55, 0.85, 0.9)
    row.input:Hide()

    -- The voice strip, always on show. Which lines have a recording pinned to
    -- them and which go out silent is the question this panel exists to answer,
    -- and answering it one row at a time behind a click is not answering it.
    -- Indented under the phrase it belongs to, because the pinned line is often
    -- a sentence and will not fit beside a phrase.
    row.voiceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.voiceLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 26, -ROW_LINE_H - 5)
    row.voiceLabel:SetText("Says")

    -- The three controls sit at the right, not between the label and the line
    -- they act on. Two hundred pixels of button in front of the quote pushed it
    -- so far across that it wrapped, and what fell onto the wrapped line was the
    -- name of whoever says it -- the one word on the row worth reading.
    --
    -- Laid out right to left so they end flush with Revert on the strip above,
    -- while still reading Browse, Play, x.
    --
    -- Unpinning is hidden while nothing is pinned, because a button that clears
    -- an empty thing is a button that only ever raises the question of what it
    -- would have done. It keeps its slot either way, so the two beside it do
    -- not shuffle sideways as rows are pinned and cleared.
    row.voiceClear = tinyButton("x", 18)
    row.voiceClear:ClearAllPoints()
    -- Flush with Revert on the strip above, not four pixels short of it.
    row.voiceClear:SetPoint("RIGHT", row.line1, "RIGHT", 0, 0)
    row.voiceClear:SetPoint("TOP", row.voiceLabel, "TOP", 0, 4)
    row.voiceClear:Hide()

    row.voicePlay = tinyButton("Play", 40)
    row.voicePlay:ClearAllPoints()
    row.voicePlay:SetPoint("RIGHT", row.voiceClear, "LEFT", -6, 0)

    -- A window rather than a dropdown. The catalogue runs to thousands of lines
    -- across dozens of characters, which is not something you pour into a menu:
    -- it wants a speaker to pick, a kind of line to narrow to, and a list to
    -- scroll. See Compat.ShowLineBrowser.
    row.voiceBrowse = tinyButton("Browse voice lines", 118)
    row.voiceBrowse:ClearAllPoints()
    row.voiceBrowse:SetPoint("RIGHT", row.voicePlay, "LEFT", -6, 0)

    -- What it is pinned to, starting at the same x as the phrase above it, so
    -- the two things a row says read as one column rather than two indents.
    row.spokenText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.spokenText:SetPoint("LEFT", row, "LEFT", ROW_TEXT_X, 0)
    row.spokenText:SetPoint("TOP", row.voiceLabel, "TOP", 0, 0)
    row.spokenText:SetPoint("RIGHT", row.voiceBrowse, "LEFT", -10, 0)
    row.spokenText:SetJustifyH("LEFT")
    -- Never wrap: the row is a fixed height, so a second line draws over the
    -- preview rather than making room for itself.
    if row.spokenText.SetWordWrap then row.spokenText:SetWordWrap(false) end

    -- What the line will actually read as in chat, tokens filled in. This one
    -- really is an editing aid -- it answers "did I write that right", which is
    -- only a question while you are writing it.
    row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.preview:SetPoint("TOPLEFT", row, "TOPLEFT", 26, -ROW_REST_H)
    row.preview:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.preview:SetJustifyH("LEFT")
    row.preview:Hide()

    -- A hairline under each row. Every row is two strips that belong together
    -- and sit directly above two more that don't, and nothing said which pairs
    -- were which -- so eight lines of text read as eight rows rather than four.
    -- Faint enough to be a grouping rather than a grid.
    row.rule = row:CreateTexture(nil, "BACKGROUND")
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
    row.rule:SetHeight(1)
    Compat.SolidTexture(row.rule, 1, 1, 1, 0.07)

    castRows[index] = row
    return row
end

local function RefreshCasts()
    if not (castPanel and Casts) then return end
    local c = castDB()
    if not c then return end

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
    if castVoiceCheck then castVoiceCheck:SetChecked(c.voice and true or false) end

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
    local cd = ns.CAST_DEFAULTS
    setSlider(castChanceSlider, c.chance or cd.chance, (c.chance or cd.chance) .. "%")
    setSlider(castGapSlider, c.gap or cd.gap, seconds(c.gap or cd.gap))
    setSlider(castSpellGapSlider, c.spellGap or cd.spellGap, seconds(c.spellGap or cd.spellGap))

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

    -- The percentages are shares of this spell's own list, so they need the
    -- total before any row can be drawn. Retired lines contribute nothing, and
    -- a list that is entirely retired would divide by zero -- the 1 keeps the
    -- arithmetic safe and every row reads "off" in that case anyway.
    local castWeightTotal = 0
    for _, p in ipairs(phrases) do castWeightTotal = castWeightTotal + (p.step or 0) end
    if castWeightTotal == 0 then castWeightTotal = 1 end

    -- The legend only makes sense above a list, so it comes and goes with one.
    if castWeightHeader then
        if #phrases > 0 then
            castWeightHeader:ClearAllPoints()
            castWeightHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -10)
            castWeightHeader:SetPoint("RIGHT", castContent, "RIGHT", -24, 0)
            castWeightHeader:Show()
            anchor = castWeightHeader
        else
            castWeightHeader:Hide()
        end
    end
    for i, phrase in ipairs(phrases) do
        local row = castRow(i, castContent)
        row:ClearAllPoints()
        -- Eight rather than two between rows: the hairline under each one needs
        -- air on both sides to read as a divider instead of an underline.
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", i == 1 and 4 or 0, i == 1 and -10 or -8)
        row:SetPoint("RIGHT", castContent, "RIGHT", -24, 0)

        local step = phrase.step or 0
        -- Out of the whole list, so the number answers "how often will I say
        -- this one" rather than "what is this one set to". Retired lines read
        -- as "off" rather than 0%: the two are the same arithmetic but one of
        -- them says it was a decision.
        row.weight:SetText(step == 0 and "off"
            or string.format("%d%%", math.floor(step / castWeightTotal * 100 + 0.5)))
        local grey = step == 0
        if grey then
            row.weight:SetTextColor(0.5, 0.5, 0.5)
            row.text:SetTextColor(0.5, 0.5, 0.5)
            row.source:SetTextColor(0.4, 0.4, 0.4)
        else
            row.weight:SetTextColor(1, 0.82, 0)
            row.text:SetTextColor(1, 1, 1)
            row.source:SetTextColor(0.55, 0.55, 0.55)
        end
        -- No marker for a borrowed voice here any more: the picker below the
        -- phrase names it outright, which is the whole point of it being on
        -- show, and saying it twice on one row only crowds the column.
        row.text:SetText(phrase.text)

        row.line1:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- The row is wider than the column it can draw in, so the tooltip is
            -- also where you read a line that's too long to fit.
            GameTooltip:AddLine(phrase.text, 1, 1, 1, true)
            if phrase.spoken then
                local heard = (ns.Voice and ns.Voice.GameText
                    and ns.Voice.GameText(phrase.spoken)) or phrase.spoken
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Pinned", 0.53, 0.8, 1)
                GameTooltip:AddLine("Plays \"" .. heard
                    .. "\" out loud, whatever the words above read as.", 0.8, 0.8, 0.8, true)
            end
            if phrase.edited then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Reworded by you", 1, 0.82, 0)
                GameTooltip:AddLine("Ships as: " .. tostring(phrase.orig), 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine("Revert puts it back.", 0.6, 0.6, 0.6, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to reword this line. It keeps what you type; Escape puts it back.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        row.line1:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Weights and edits are both addressed by the phrase's identity, which
        -- for a library line is the wording the pack ships, not what it reads as
        -- now. Using the displayed text here would strand the weight on a reword.
        local key, text = castSelectedKey, phrase.orig or phrase.text
        row.down:SetScript("OnClick", function()
            Casts.SetWeight(key, text, step - 1)
            RefreshCasts()
        end)
        row.up:SetScript("OnClick", function()
            Casts.SetWeight(key, text, step + 1)
            RefreshCasts()
        end)

        -- The percentage is what you steer by, but the thing being stored is a
        -- weight of 0 to 5, and that is worth saying somewhere: it explains why
        -- nudging one line moves the numbers on all the others.
        local function weightTip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("How often this line is picked", 1, 1, 1)
            GameTooltip:AddLine(string.format("Weight %d of %d, against %d across the list.",
                step, Casts.MAX_WEIGHT, castWeightTotal), 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Raising one line lowers the share of every other, "
                .. "because they divide the same casts between them.", 0.6, 0.6, 0.6, true)
            if step == 0 then
                GameTooltip:AddLine("At 0 this line is retired and never picked.", 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
        local function hideTip() GameTooltip:Hide() end
        row.down:SetScript("OnEnter", weightTip)
        row.down:SetScript("OnLeave", hideTip)
        row.up:SetScript("OnEnter", weightTip)
        row.up:SetScript("OnLeave", hideTip)

        -- What the line will read as in chat once its %tokens are filled in,
        -- plus what it will sound like when the two differ. Refreshed straight
        -- from the edit box as it is typed in, rather than on the next full
        -- redraw, so the preview keeps up with the typing it is previewing.
        local function updatePreview()
            local template = (castEdit and castEdit.orig == text and castEdit.typed) or phrase.text
            local rendered = Casts.Preview(template, key)
            if not rendered then
                row.preview:SetText("|cffcc6666That won't fill in -- check the %tokens.|r")
                return
            end
            local note = ""
            if phrase.spoken and not template:find('"') then
                -- A pin on a line with nothing in quotes never plays. Worth
                -- saying outright: the pin is right there on the row looking
                -- like it works.
                note = "   |cffcc6666nothing in quotes, so the pinned line won't play|r"
            elseif not template:find('"') then
                note = "   |cff909090nothing in quotes, so nothing is said aloud|r"
            end
            row.preview:SetText("|cffb0b0b0" .. rendered .. "|r" .. note)
        end

        -- What this phrase is pinned to, on every row whether or not it is
        -- being edited. Which lines have a recording and which go out silent is
        -- the question this panel exists to answer, and it has to be answerable
        -- down the list at a glance.
        local Voice = ns.Voice
        local pinned = phrase.spoken
        local said = pinned and Voice and Voice.GameText and Voice.GameText(pinned)
        if pinned then
            local who = Voice and Voice.GameId and ns.GameVoices
                and ns.GameVoices.SpeakerById[Voice.GameId(pinned)]
            -- Who first, then what. The quote can be long and the row cannot
            -- grow, so whichever comes last is the part that gets cut off --
            -- and the speaker is both the shorter of the two and the reason
            -- the line was picked. The whole quote is in the tooltip anyway.
            row.spokenText:SetText((who and ("|cff707070" .. who .. "|r  ") or "")
                .. "|cff88ccff\"" .. (said or pinned) .. "\"|r")
            row.voiceClear:Show()
        else
            row.spokenText:SetText("|cff808080nothing pinned -- this line goes out silent|r")
            row.voiceClear:Hide()
        end

        row.voiceClear:SetScript("OnClick", function()
            Casts.SetPhraseSpoken(key, text, nil)
            castStatusMsg("Unpinned. That line goes out silent again.", false)
            RefreshCasts()
        end)

        row.voicePlay:SetScript("OnClick", function()
            if not pinned then
                castStatusMsg("Nothing is pinned to that line yet -- press Browse voice lines.", true)
            elseif not (Voice and Voice.Audition) then
                castStatusMsg("The voice module isn't loaded.", true)
            elseif Voice.Audition(pinned) then
                castStatusMsg("Played \"" .. (said or pinned) .. "\".", false)
            else
                -- The catalogue is built from one build of the game and the
                -- player may be running another. Worth saying which of the two
                -- went wrong, because only one of them is fixable from here.
                castStatusMsg("Your client doesn't seem to carry that recording.", true)
            end
        end)

        row.voiceBrowse:SetScript("OnClick", function()
            local gv = ns.GameVoices
            if not (gv and gv.Search) then
                castStatusMsg("No game voice lines are indexed.", true)
                return
            end
            Compat.ShowLineBrowser{
                title = "Voice lines from the game",
                groupAll = "All speakers",
                -- Opens on your own character's voice rather than on all
                -- ninety-three speakers. Most of the time the line you want is
                -- one your character already says, and starting from the whole
                -- catalogue makes you scroll past ninety-two strangers to
                -- reach it. "All speakers" is still one click away.
                group = (gv.MyVoices and gv.MyVoices()[1]) or nil,
                groups = function()
                    local out, mine = {}, {}
                    for _, who in ipairs(gv.MyVoices and gv.MyVoices() or {}) do
                        mine[who] = true
                    end
                    -- Your own voices first, marked, then everyone else in the
                    -- order the catalogue lists them.
                    for _, pass in ipairs({ true, false }) do
                        for _, s in ipairs(gv.Speakers()) do
                            if (mine[s.who] or false) == pass then
                                -- The count belongs on the label: it is what
                                -- tells you whether a speaker is worth opening
                                -- before you open it.
                                -- Marked with a star in front rather than a
                                -- note behind. The names already run to forty
                                -- characters and the ones that matter are the
                                -- ones you can pick out at a glance, not the
                                -- ones with the longest explanation.
                                out[#out + 1] = { id = s.who, label =
                                    string.format("%s%s (%d)",
                                        pass and "|cffffd200*|r " or "",
                                        s.who, s.count) }
                            end
                        end
                    end
                    return out
                end,
                kindAll = "Every kind",
                -- Families, with their groups indented underneath. Thirty-one
                -- headings in a flat list is more than anyone reads down.
                kinds = function(who) return gv.BrowseList(who) end,
                letters = function(who, kind) return gv.Letters(who, kind) end,
                filter = function(who, kind, letter, q)
                    return gv.Filter{ who = who, group = kind, letter = letter,
                        query = q, limit = 2000 }
                end,
                onPlay = function(entry)
                    if ns.Voice and ns.Voice.PlayGame then ns.Voice.PlayGame(entry.id) end
                end,
                onPick = function(entry)
                    local ok, err = Casts.SetPhraseSpoken(key, text,
                        ns.Voice and ns.Voice.GameRef(entry.id) or nil)
                    if ok then
                        castStatusMsg("Now says \"" .. entry.text .. "\" out loud.", false)
                    else
                        castStatusMsg("Not set: " .. tostring(err) .. ".", true)
                    end
                    RefreshCasts()
                end,
            }
        end)

        local editing = (castEdit ~= nil and castEdit.orig == text)
        if editing then
            row:SetHeight(ROW_EDIT_H)
            row.text:Hide()
            row.input:Show()
            row.keep:Show()
            row.discard:Show()
            row.preview:Show()

            -- The box is a view of castEdit.typed, never of the saved phrase.
            -- Seeding it from the phrase was the bug: the list redraws on every
            -- keystroke in the new-phrase field below, and each redraw put the
            -- saved wording back, so anything typed here vanished the moment
            -- anything else on the panel moved.
            if castEdit.focus then
                row.input:SetText(castEdit.typed or phrase.text)
                row.input:SetFocus()
                -- Cursor at the start, nothing selected. These lines are long
                -- enough to run past the right edge of the box, so landing at
                -- the end means landing on a view scrolled away from the words
                -- you clicked. Selecting the lot was worse again: the first
                -- key you pressed replaced the phrase you meant to adjust.
                row.input:HighlightText(0, 0)
                row.input:SetCursorPosition(0)
                castEdit.focus = nil
            elseif not row.input:HasFocus() and row.input:GetText() ~= castEdit.typed then
                -- Redrawn while the cursor is somewhere else. Put the pending
                -- text back, but do not take focus: somebody typing in the
                -- new-phrase field would have the cursor pulled out from under
                -- them on their first keypress.
                row.input:SetText(castEdit.typed or phrase.text)
            end
            updatePreview()
        else
            row:SetHeight(ROW_REST_H)
            row.input:Hide()
            row.keep:Hide()
            row.discard:Hide()
            row.preview:Hide()
            row.text:Show()
        end

        row.input:SetScript("OnTextChanged", function(self)
            if castEdit and castEdit.orig == text then
                castEdit.typed = self:GetText()
                updatePreview()
            end
        end)
        local function keep(self)
            if castEdit then castEdit.typed = row.input:GetText() end
            castFinishEdit(true)
            if castEdit then castEdit.focus = true else row.input:ClearFocus() end
            RefreshCasts()
        end
        local function discard()
            castFinishEdit(false)
            row.input:ClearFocus()
            castStatusMsg("Left as it was.", false)
            RefreshCasts()
        end
        row.input:SetScript("OnEnterPressed", keep)
        row.input:SetScript("OnEscapePressed", discard)
        -- Clicking away from the box -- at a different row, at the panel behind
        -- it, at anything -- keeps what is in it. That is the assumption people
        -- arrive with, and the reason this handler exists.
        row.input:SetScript("OnEditFocusLost", function()
            if castEdit and castEdit.orig == text then
                castEdit.typed = row.input:GetText()
                castFinishEdit(true)
                RefreshCasts()
            end
        end)
        row.keep:SetScript("OnClick", keep)
        row.discard:SetScript("OnClick", discard)

        row.line1:SetScript("OnClick", function()
            -- Clicking the row being edited would close the edit under the
            -- cursor mid-typing, which is never what the click meant.
            if editing then return end
            -- Opening this one puts away whichever was open, keeping it.
            if not castFinishEdit(true) then return end
            castEdit = { orig = text, from = phrase.text, typed = phrase.text, focus = true }
            RefreshCasts()
        end)

        if phrase.user then
            row.action:Show()
            row.source:Hide()
            row.action.label:SetText("Delete")
            row.action:SetScript("OnClick", function()
                Casts.RemovePhrase(key, text)
                if castEdit and castEdit.orig == text then castEdit = nil end
                castStatusMsg("Removed that phrase.", false)
                RefreshCasts()
            end)
        elseif phrase.edited then
            -- A reworded library line still belongs to its pack, so the column
            -- that names the pack offers the way back instead.
            row.action:Show()
            row.source:Hide()
            row.action.label:SetText("Revert")
            row.action:SetScript("OnClick", function()
                Casts.ClearPhraseText(key, text)
                if castEdit and castEdit.orig == text then castEdit = nil end
                castStatusMsg("Back to the wording the pack ships.", false)
                RefreshCasts()
            end)
        else
            -- Library lines can't be deleted (the pack owns them), so weight 0
            -- is how you retire one. The pack name doubles as the explanation.
            row.action:Hide()
            row.source:Show()
            -- The pack's name, not its id: "Priest", not "priest". The id was
            -- only ever here because the pretty version was over on the left.
            row.source:SetText(phraseSourceLabel(phrase))
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

    castEnableCheck = Compat.CreateCheckbox(content, "Speak a phrase when I cast something")
    castEnableCheck:SetPoint("TOPLEFT", limits, "BOTTOMLEFT", 0, -16)
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

    --  Voice ---------------------------------------------------------------
    local voiceLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    voiceLabel:SetPoint("TOPLEFT", throttleHint, "BOTTOMLEFT", 0, -16)
    voiceLabel:SetText("Voice")

    local voiceHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    voiceHint:SetPoint("TOPLEFT", voiceLabel, "BOTTOMLEFT", 0, -4)
    voiceHint:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    voiceHint:SetJustifyH("LEFT")
    if voiceHint.SetWordWrap then voiceHint:SetWordWrap(true) end
    voiceHint:SetText("Play a recording out loud when a phrase with \"quotes\" in it goes off. The recordings are the game's own -- boss lines, NPC chatter, grunts and death cries -- read by the people Blizzard hired, and already sitting in your client. Nothing is downloaded.")

    castVoiceCheck = Compat.CreateCheckbox(content, "Speak phrases out loud")
    castVoiceCheck:SetPoint("TOPLEFT", voiceHint, "BOTTOMLEFT", 0, -8)
    castVoiceCheck:SetScript("OnClick", function(self)
        castDB().voice = self:GetChecked() and true or false
        RefreshCasts()
    end)

    local voiceNote = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    voiceNote:SetPoint("TOPLEFT", castVoiceCheck, "BOTTOMLEFT", 0, -10)
    voiceNote:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    voiceNote:SetJustifyH("LEFT")
    if voiceNote.SetWordWrap then voiceNote:SetWordWrap(true) end
    voiceNote:SetText("|cffffd200A phrase stays silent until you pin a line to it.|r Pick one with |cffffd200Browse voice lines|r on the phrase itself, in the list above. Your tongue and accent keep working either way -- a recording says whatever Blizzard recorded it saying, so there is nothing for a translation to disagree with.")

    --  Packs -------------------------------------------------------------
    local packLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    packLabel:SetPoint("TOPLEFT", voiceNote, "BOTTOMLEFT", 0, -16)
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
        local label = pack.name
        if pack.id == mine then label = label .. " |cff00ff00(yours)|r" end
        addPackCheck(pack, label)
    end

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
        castLeaveEdit()
        castSelectedKey = value
        castStatusMsg("", false)
        RefreshCasts()
    end

    -- Adding a spell the library doesn't cover. The keybind is the fast way in
    -- (hover it on your bars and press it); this is the way that works when
    -- you'd rather type, or the spell isn't on a bar at all.
    local addSpellInput = CreateFrame("EditBox", "TonguesOfAzerothCastSpell", content, "InputBoxTemplate")
    -- Right edge follows the content rather than a fixed width, so the box takes
    -- whatever room is left beside the dropdown instead of running past the edge
    -- on a narrower canvas.
    addSpellInput:SetPoint("LEFT", castSpellDropdown, "RIGHT", 16, 0)
    addSpellInput:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    addSpellInput:SetHeight(20)
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
        castLeaveEdit()
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

    -- A legend for the number at the head of every phrase row. Without it the
    -- column is a bare figure between two nudge buttons, and the one thing a
    -- reader cannot work out from looking is what it is a figure of.
    castWeightHeader = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    castWeightHeader:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    castWeightHeader:SetJustifyH("LEFT")
    if castWeightHeader.SetWordWrap then castWeightHeader:SetWordWrap(true) end
    castWeightHeader:SetText("The |cffffd200%|r on each line is how often this spell picks it. Nudge it with |cffffd200-|r and |cffffd200+|r; take a line down to |cffffd200off|r to retire it without deleting it.")

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

    -- The Add button hangs off the input's right, so the input has to leave room
    -- for it instead of claiming a fixed width. At 440 the pair wanted 526 inside
    -- a row only as wide as the options canvas allows, which pushed the button
    -- clean off the panel and clipped the input with it.
    local ADD_BTN_W = 70

    castNewInput = CreateFrame("EditBox", "TonguesOfAzerothCastPhrase", castAddRow, "InputBoxTemplate")
    castNewInput:SetPoint("TOPLEFT", castNewLabel, "BOTTOMLEFT", 6, -6)
    castNewInput:SetPoint("RIGHT", castAddRow, "RIGHT", -(ADD_BTN_W + 10), 0)
    castNewInput:SetHeight(20)
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
    addBtn:SetSize(ADD_BTN_W, 22)
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

    BuildChatPanel()
    Compat.RegisterOptionsPanel(chatPanel, chatPanel.name, mainPanel.name)

    BuildAccentPanel()
    Compat.RegisterOptionsPanel(accentPanel, accentPanel.name, mainPanel.name)

    BuildCustomPanel()
    Compat.RegisterOptionsPanel(customPanel, customPanel.name, mainPanel.name)

    BuildCastPanel()
    Compat.RegisterOptionsPanel(castPanel, castPanel.name, mainPanel.name)

    -- In the shared standalone window the sub-panels show a Back button (to the
    -- main panel) instead of their own close button.
    learnedPanel._backAction = function() ns.OpenConfig() end
    chatPanel._backAction = function() ns.OpenConfig() end
    accentPanel._backAction = function() ns.OpenConfig() end
    customPanel._backAction = function() ns.OpenConfig() end
    castPanel._backAction = function() ns.OpenConfig() end

    panelsBuilt = true
end

-- The trainer is built in Game.lua and registered here with the rest, but at
-- PLAYER_LOGIN rather than ADDON_LOADED like its siblings.
--
-- Building it asks which tongues your race already speaks so it can leave them
-- out of the practice list, and GetNumLanguages() has nothing to say until the
-- player actually exists. The trainer builds exactly once, so asking too early
-- would bake the wrong list in permanently -- and any error thrown that early
-- would take the registration down with it, which is how it went missing from
-- the settings tree entirely.
local trainerRegistered = false
local function RegisterTrainerPanel()
    if trainerRegistered or not ns.BuildTrainerPanel then return end
    BuildPanels()
    local trainer = ns.BuildTrainerPanel()
    -- nil means BuildTrainerPanel already reported why in chat.
    if not trainer then return end
    Compat.RegisterOptionsPanel(trainer, trainer.name, mainPanel.name)
    trainer._backAction = function() ns.OpenConfig() end
    trainerRegistered = true
end
ns.EnsureTrainerPanel = RegisterTrainerPanel

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
        RegisterTrainerPanel()
    end
end)

ns.OnSettingsChanged = function()
    if mainPanel and mainPanel:IsVisible() then RefreshMain() end
    if learnedPanel and learnedPanel:IsVisible() then RefreshLearned() end
    if chatPanel and chatPanel:IsVisible() then RefreshChat() end
    if accentPanel and accentPanel:IsVisible() then RefreshAccent() end
    if customPanel and customPanel:IsVisible() then RefreshCustom() end
    if castPanel and castPanel:IsVisible() then RefreshCasts() end
    -- Keep the main language dropdown in sync when custom languages change.
    if langDropdown then langDropdown:SetItems(langItems()) end
    RefreshLanguageWidget()
    ApplyMinimapState()
    -- Last, so a tooltip open over the minimap button or the floating bar is
    -- rebuilt from the state everything above just finished updating.
    refreshOpenTooltip()
end

-- Called by the trainer after a solve so fluency bars update live if the
-- Languages panel happens to be open at the same time.
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

function ns.OpenChatConfig()
    BuildPanels()
    Compat.OpenOptionsPanel(chatPanel)
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
    castLeaveEdit()
    if key then castSelectedKey = key end
    Compat.OpenOptionsPanel(castPanel)
    RefreshCasts()
end
