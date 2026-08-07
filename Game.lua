--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Game.lua
    "Decipher" - a Wordle-style language trainer.

    A random 5-letter English word is chosen and shown written in the currently
    selected language (its same-length translation). You guess the English word
    in 6 tries; each guess gives classic green/yellow/gray letter feedback.
    Solving it reinforces that word's translation and counts toward the number
    of words you've "learned" in that language.

    Endless practice: press New Word for another round anytime.

    Built entirely from ns.Compat widgets + base frames, so it renders on the
    3.3.5a client (Ascension) and modern clients alike.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language
local Compat = ns.Compat

local WORD_LEN = 5
local MAX_GUESSES = 6

-- Curated common 5-letter words.
local WORDS = {
    "apple", "beach", "beast", "blade", "blaze", "bloom", "brave", "bread",
    "brick", "brook", "broom", "chair", "chalk", "charm", "chest", "cider",
    "cliff", "cloak", "cloth", "cloud", "coast", "crane", "crown", "dance",
    "dream", "drink", "druid", "eagle", "earth", "elder", "ember", "feast",
    "ferry", "field", "flame", "flute", "forge", "frost", "ghost", "giant",
    "glass", "globe", "grape", "grass", "green", "guild", "heart", "honey",
    "honor", "horse", "house", "ivory", "jewel", "knife", "lance", "lemon",
    "light", "linen", "magic", "manor", "march", "medal", "metal", "moose",
    "mount", "mouse", "night", "noble", "north", "ocean", "olive", "onion",
    "opera", "otter", "panic", "peace", "pearl", "phase", "plant", "plate",
    "pouch", "pride", "quest", "quiet", "raven", "realm", "reign", "rider",
    "ridge", "river", "roast", "robin", "rogue", "royal", "ruins", "saint",
    "scale", "scout", "sharp", "shell", "shine", "shore", "sight", "stone",
    "storm", "sugar", "sword", "table", "tiger", "torch", "tower", "trail",
    "truce", "trust", "vault", "water", "wheat", "witch", "world", "wound",
    -- Expanded pool (so higher fluency ranks take more words to reach).
    "about", "above", "actor", "admit", "adopt", "adult", "agent", "agree",
    "alarm", "album", "alert", "alien", "alley", "alpha", "altar", "amber",
    "angel", "anger", "angle", "ankle", "arena", "argue", "armor", "arrow",
    "asset", "audio", "avoid", "awake", "award", "badge", "baker", "basic",
    "beard", "began", "begin", "belly", "bench", "berry", "birth", "black",
    "blame", "blank", "blast", "blend", "blind", "block", "blood", "board",
    "bonus", "boost", "booth", "bound", "brain", "brand", "brass", "breed",
    "brief", "bring", "brown", "brush", "build", "built", "bunch", "burst",
    "cabin", "cable", "camel", "canal", "candy", "cargo", "catch", "cause",
    "chain", "chaos", "cheap", "cheek", "cheer", "chief", "chill", "choir",
    "civil", "claim", "clash", "clean", "clear", "clerk", "click", "climb",
    "clock", "close", "coach", "comet", "coral", "couch", "count", "court",
    "cover", "crack", "craft", "crash", "cream", "creek", "creep", "crime",
    "crisp", "cross", "crowd", "crush", "curve", "cycle", "daily", "dairy",
    "delay", "delta", "dense", "depth", "devil", "diary", "dodge", "donor",
    "dough", "dozen", "draft", "drain", "drama", "dress", "drift", "drill",
    "drive", "drove", "dwarf",
}

-- Tile colors: {r, g, b, a}.
local COLORS = {
    empty  = { 0.10, 0.10, 0.13, 0.90 },
    filled = { 0.17, 0.17, 0.22, 1.00 },
    green  = { 0.29, 0.53, 0.24, 1.00 },
    yellow = { 0.72, 0.60, 0.18, 1.00 },
    gray   = { 0.22, 0.22, 0.25, 1.00 },
}

local gameFrame
local tiles = {}
local input, clueLabel, clueText, statusText, statsText, repBar
local built = false

-- Round state.
local target, clue, langId, row, over

-- Forward declarations.
local newRound, updateStats, submitGuess, fillCurrentRow

local function DB()
    TonguesOfAzerothDB = TonguesOfAzerothDB or {}
    local t = TonguesOfAzerothDB.trainer or {}
    TonguesOfAzerothDB.trainer = t
    if t.played == nil then t.played = 0 end
    if t.wins   == nil then t.wins   = 0 end
    if t.streak == nil then t.streak = 0 end
    if t.best   == nil then t.best   = 0 end
    t.words = t.words or {}
    -- The trainer has its own language, independent of the chat speaking language.
    if t.lang == nil or not Language.IsValid(t.lang) then
        if TonguesOfAzerothDB.language and Language.IsValid(TonguesOfAzerothDB.language) then
            t.lang = TonguesOfAzerothDB.language
        else
            t.lang = Language.DEFAULT
        end
    end
    return t
end

local function langName()
    return Language.GetLanguageName(langId or (TonguesOfAzerothDB and TonguesOfAzerothDB.language) or Language.DEFAULT)
end

--=========================================================================--
--  Fluency progress + reputation-style ranks.
--  Progress = words solved in a language / size of the trainer word pool.
--  Ranks are checked high-to-low; the first threshold you meet wins.
--=========================================================================--
local RANKS = {
    { min = 1.00, name = "Master",     color = { 1.00, 0.82, 0.00 } },
    { min = 0.75, name = "Fluent",     color = { 0.55, 0.85, 1.00 } },
    { min = 0.50, name = "Speaker",    color = { 0.35, 0.80, 0.40 } },
    { min = 0.25, name = "Apprentice", color = { 0.55, 0.78, 0.45 } },
    { min = 0.10, name = "Novice",     color = { 0.78, 0.74, 0.35 } },
    { min = 0.0001, name = "Dabbler",  color = { 0.80, 0.58, 0.42 } },
    { min = 0.00, name = "Stranger",   color = { 0.55, 0.55, 0.60 } },
}

local function rankFor(frac)
    for i = 1, #RANKS do
        if frac >= RANKS[i].min then return RANKS[i] end
    end
    return RANKS[#RANKS]
end

local function progressFor(id)
    id = Language.GetWordsetId(id or "")
    local d = DB()
    local learned = 0
    local wl = d.words[id or ""]
    if wl then for _ in pairs(wl) do learned = learned + 1 end end
    local total = #WORDS
    return learned, total, (total > 0 and learned / total or 0)
end

-- Exposed so the settings UI can show each language's rank/progress too.
ns.Trainer = ns.Trainer or {}
ns.Trainer.GetProgress = progressFor
function ns.Trainer.GetRank(frac)
    local r = rankFor(frac)
    return r.name, r.color
end

local function setTile(r, c, letter, state)
    local tile = tiles[r] and tiles[r][c]
    if not tile then return end
    tile.text:SetText(letter or "")
    local col = COLORS[state] or COLORS.empty
    Compat.SolidTexture(tile.bg, col[1], col[2], col[3], col[4])
end

local function clearGrid()
    for r = 1, MAX_GUESSES do
        for c = 1, WORD_LEN do setTile(r, c, "", "empty") end
    end
end

local function evaluate(guess, tgt)
    local res = {}
    local counts = {}
    for i = 1, WORD_LEN do
        local ch = tgt:sub(i, i)
        counts[ch] = (counts[ch] or 0) + 1
    end
    for i = 1, WORD_LEN do
        local ch = guess:sub(i, i)
        if ch == tgt:sub(i, i) then
            res[i] = "green"
            counts[ch] = counts[ch] - 1
        end
    end
    for i = 1, WORD_LEN do
        if not res[i] then
            local ch = guess:sub(i, i)
            if (counts[ch] or 0) > 0 then
                res[i] = "yellow"
                counts[ch] = counts[ch] - 1
            else
                res[i] = "gray"
            end
        end
    end
    return res
end

function updateStats()
    if not statsText then return end
    local d = DB()
    statsText:SetText(string.format(
        "Streak: |cffffd200%d|r    Best: |cffffd200%d|r    Solved: |cffffd200%d/%d|r",
        d.streak, d.best, d.wins, d.played))

    if repBar then
        local learned, total, frac = progressFor(langId)
        local r = rankFor(frac)
        repBar:SetBarColor(r.color[1], r.color[2], r.color[3])
        repBar:SetProgress(frac)
        repBar:SetText(string.format("%s  -  %s  (%d/%d words, %d%%)",
            langName(), r.name, learned, total, math.floor(frac * 100 + 0.5)))
    end

    -- Live-update the Learned Languages panel's fluency bars if it's open too.
    if ns.RefreshLearnedIfShown then ns.RefreshLearnedIfShown() end
end

function fillCurrentRow(text)
    if over or not row or not built then return end
    local g = string.upper(text or "")
    g = g:gsub("[^A-Z]", "")
    for c = 1, WORD_LEN do
        local ch = g:sub(c, c)
        if ch ~= "" then
            setTile(row, c, ch, "filled")
        else
            setTile(row, c, "", "empty")
        end
    end
end

function newRound()
    local d = DB()
    langId = d.lang

    local w
    repeat w = WORDS[math.random(#WORDS)] until w ~= d.lastWord or #WORDS == 1
    d.lastWord = w

    target = string.upper(w)
    clue = string.upper(Language.TranslateText(w, 100, langId) or w)
    row = 1
    over = false

    clearGrid()
    clueLabel:SetText("Decipher this |cffffd200" .. langName() .. "|r word:")
    clueText:SetText(clue)
    statusText:SetText("Guess the English word in " .. MAX_GUESSES .. " tries.")
    if input then
        input:SetText("")
        input:SetFocus()
    end
    updateStats()
end

function submitGuess()
    if over or not built then return end
    local g = string.upper(input:GetText() or "")
    g = g:gsub("[^A-Z]", "")
    if #g ~= WORD_LEN then
        statusText:SetText("|cffff8800Enter a " .. WORD_LEN .. "-letter word.|r")
        return
    end

    local fb = evaluate(g, target)
    for c = 1, WORD_LEN do
        setTile(row, c, g:sub(c, c), fb[c])
    end

    local d = DB()
    if g == target then
        d.played = d.played + 1
        d.wins = d.wins + 1
        d.streak = d.streak + 1
        if d.streak > d.best then d.best = d.streak end
        local key = Language.GetWordsetId(langId)
        d.words[key] = d.words[key] or {}
        d.words[key][target] = true
        statusText:SetText("|cff33ff33Solved!|r  |cffffd200" .. clue .. "|r = |cffffffff" .. target .. "|r")
        over = true
        input:SetText("")
        input:ClearFocus()
    elseif row >= MAX_GUESSES then
        d.played = d.played + 1
        d.streak = 0
        statusText:SetText("|cffff5555Out of tries.|r  |cffffd200" .. clue .. "|r = |cffffffff" .. target .. "|r")
        over = true
        input:SetText("")
        input:ClearFocus()
    else
        row = row + 1
        input:SetText("")
        input:SetFocus()
    end
    updateStats()
end

local function makeButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, 24)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Compat.SolidTexture(bg, 0.18, 0.16, 0.24, 1)
    Compat.AddBorder(b, 0.5, 0.45, 0.7, 0.9)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Compat.SolidTexture(hl, 1, 1, 1, 0.12)
    return b
end

local function build()
    if built then return end
    -- Some custom clients (Ascension) strip math.randomseed. Seed if we can;
    -- otherwise perturb the default sequence using the clock for per-session variety.
    if type(math.randomseed) == "function" then
        math.randomseed(time())
    else
        for _ = 1, (time() % 97) do math.random() end
    end

    gameFrame = Compat.CreateOptionsPanel("TonguesOfAzerothGameFrame")
    gameFrame.name = "Language Trainer"
    -- In the shared standalone window, the trainer shows a Back button (to the
    -- main panel) instead of its own close button.
    gameFrame._backAction = function() if ns.OpenConfig then ns.OpenConfig() end end
    local f = gameFrame

    -- Language picker: train any language, independent of the chat language.
    local pickLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pickLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -18)
    pickLabel:SetText("Language:")

    local pickDD = Compat.CreateDropdown(f, 240)
    pickDD:SetPoint("LEFT", pickLabel, "RIGHT", 8, 0)
    local items = {}
    local primaries = Language.GetPrimaryLanguages()
    for i = 1, #primaries do
        items[i] = { text = primaries[i].name, value = primaries[i].id }
    end
    pickDD:SetItems(items)
    pickDD:SetSelected(DB().lang, Language.GetLanguageName(DB().lang))
    pickDD.onSelect = function(value)
        DB().lang = value
        newRound()
    end

    clueLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    clueLabel:SetPoint("TOP", f, "TOP", 0, -52)

    clueText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    clueText:SetPoint("TOP", clueLabel, "BOTTOM", 0, -6)
    clueText:SetTextColor(0.85, 0.75, 1)

    local tileSize, gap = 36, 5
    local gridW = WORD_LEN * tileSize + (WORD_LEN - 1) * gap
    local gridH = MAX_GUESSES * tileSize + (MAX_GUESSES - 1) * gap

    local grid = CreateFrame("Frame", nil, f)
    grid:SetSize(gridW, gridH)
    grid:SetPoint("TOP", clueText, "BOTTOM", 0, -16)

    for r = 1, MAX_GUESSES do
        tiles[r] = {}
        for c = 1, WORD_LEN do
            local t = CreateFrame("Frame", nil, grid)
            t:SetSize(tileSize, tileSize)
            t:SetPoint("TOPLEFT", grid, "TOPLEFT", (c - 1) * (tileSize + gap), -((r - 1) * (tileSize + gap)))
            local bg = t:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            Compat.SolidTexture(bg, COLORS.empty[1], COLORS.empty[2], COLORS.empty[3], COLORS.empty[4])
            Compat.AddBorder(t, 0.35, 0.35, 0.42, 0.9)
            local tx = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            tx:SetPoint("CENTER", 0, 0)
            tx:SetTextColor(1, 1, 1)
            tiles[r][c] = { frame = t, bg = bg, text = tx }
        end
    end

    input = CreateFrame("EditBox", "TonguesOfAzerothGameInput", f, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetMaxLetters(WORD_LEN)
    input:SetSize(120, 24)
    input:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 6, -18)
    input:SetScript("OnTextChanged", function(self) fillCurrentRow(self:GetText()) end)
    input:SetScript("OnEnterPressed", function() submitGuess() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local guessBtn = makeButton(f, "Guess", 80)
    guessBtn:SetPoint("LEFT", input, "RIGHT", 10, 0)
    guessBtn:SetScript("OnClick", function() submitGuess() end)

    local newBtn = makeButton(f, "New Word", 90)
    newBtn:SetPoint("LEFT", guessBtn, "RIGHT", 8, 0)
    newBtn:SetScript("OnClick", function() newRound() end)

    statusText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOP", input, "BOTTOM", 0, -16)
    statusText:SetPoint("LEFT", f, "LEFT", 20, 0)
    statusText:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    statusText:SetJustifyH("CENTER")

    statsText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statsText:SetPoint("TOP", statusText, "BOTTOM", 0, -10)
    statsText:SetPoint("LEFT", f, "LEFT", 20, 0)
    statsText:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    statsText:SetJustifyH("CENTER")

    local repLabel = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    repLabel:SetPoint("TOP", statsText, "BOTTOM", 0, -12)
    repLabel:SetText("Language fluency")

    repBar = Compat.CreateStatusBar(f, gridW + 140, 18)
    repBar:SetPoint("TOP", repLabel, "BOTTOM", 0, -4)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOP", repBar, "BOTTOM", 0, -14)
    hint:SetPoint("LEFT", f, "LEFT", 20, 0)
    hint:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    hint:SetJustifyH("CENTER")
    hint:SetText("Green = right letter & spot, Yellow = right letter wrong spot, Gray = not in word.\nChange the language in the main settings to train a different tongue.")

    gameFrame.refresh = updateStats
    built = true
end

function ns.OpenTrainer()
    local ok, err = pcall(function()
        build()
        if not target or over then newRound() end
        Compat.ShowStandalone(gameFrame)
        if input then input:SetFocus() end
    end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[ToA Trainer error]|r " .. tostring(err))
    end
end
