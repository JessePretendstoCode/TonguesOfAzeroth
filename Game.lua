--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Game.lua
    "Decipher" - a Wordle-style language trainer.

    A random English word is chosen and shown written in the currently selected
    language (its same-length translation). You guess the English word in 6 tries;
    each guess gives classic green/yellow/gray letter feedback.

    Difficulty sets the word length and how much fluency each solve is worth:
        Easy (4 letters) = 1%   Medium (5) = 2%   Hard (6) = 3%   Very Hard (7) = 4%
    A solve streak multiplies that (a longer streak earns more fluency per solve).

    Built entirely from ns.Compat widgets + base frames, so it renders on the
    3.3.5a client (Ascension) and modern clients alike.
---------------------------------------------------------------------------]]

local ADDON, ns = ...
local Language = ns.Language
local Compat = ns.Compat

local MAX_GUESSES = 6
local MAXLEN = 7            -- widest grid we ever build (Very Hard)
local TILE, GAP = 36, 5

-- Fluency is driven by your solve streak: each solve adds a base % (from the
-- chosen difficulty), and a longer streak makes each solve worth more. Fluency
-- points persist and never drop, so fluency only grows -- streaks grow it faster.
local STREAK_BONUS = 0.25  -- +25% fluency per solve for each streak step above 1

local DIFFICULTIES = {
    { id = "easy",     name = "Easy (4)",      len = 4, pct = 1 },
    { id = "medium",   name = "Medium (5)",    len = 5, pct = 2 },
    { id = "hard",     name = "Hard (6)",      len = 6, pct = 3 },
    { id = "veryhard", name = "Very Hard (7)", len = 7, pct = 4 },
}
local function diffFor(id)
    for i = 1, #DIFFICULTIES do
        if DIFFICULTIES[i].id == id then return DIFFICULTIES[i] end
    end
    return DIFFICULTIES[2]   -- default to Medium
end

--=========================================================================--
--  Word pools by length. Lists are validated at load (any word of the wrong
--  length is dropped) so a miscount can never desync the grid.
--=========================================================================--
local RAW = {
    [4] = {
        "able","acid","aged","army","atom","aunt","axis","baby","back","ball",
        "band","bank","barn","base","bath","beam","bean","bear","beat","bell",
        "belt","bird","blue","boat","body","bone","book","boot","born","bowl",
        "cage","cake","calm","camp","card","care","cart","cave","cell","city",
        "clan","claw","clay","coal","coat","code","coin","cold","cook","cool",
        "cord","corn","crew","crop","cube","cure","dark","dawn","deal","deep",
        "deer","desk","dice","dirt","dish","dock","door","dove","drum","duck",
        "dust","east","edge","fair","farm","fast","fern","fire","fish","flag",
        "foam","fold","food","fork","fort","frog","fuel","gate","gear","gift",
        "glow","goat","gold","grip","hall","hand","hawk","herb","hero","hill",
        "hive","hood","hook","horn","hunt","iron","isle","jade","king","lake",
        "lamb","lamp","land","lava","leaf","lens","lime","lion","lock","loft",
        "lord","lung","maid","mane","mask","mast","maze","milk","mill","mind",
        "mint","mist","moon","moss","moth","myth","nest","node","oath","oven",
        "pact","palm","park","path","pawn","peak","pear","pine","pint","plum",
        "pond","pony","pool","port","reed","reef","ring","road","rock","root",
        "rope","rose","ruby","rune","sage","sail","salt","sand","seal","seed",
        "ship","shoe","silk","snow","song","star","stew","tail","tale","tent",
        "tide","tomb","tree","vine","wall","wand","wave","weed","well","wind",
        "wing","wolf","wood","wool","yarn",
    },
    [5] = {
        "apple","beach","beast","blade","blaze","bloom","brave","bread",
        "brick","brook","broom","chair","chalk","charm","chest","cider",
        "cliff","cloak","cloth","cloud","coast","crane","crown","dance",
        "dream","drink","druid","eagle","earth","elder","ember","feast",
        "ferry","field","flame","flute","forge","frost","ghost","giant",
        "glass","globe","grape","grass","green","guild","heart","honey",
        "honor","horse","house","ivory","jewel","knife","lance","lemon",
        "light","linen","magic","manor","march","medal","metal","moose",
        "mount","mouse","night","noble","north","ocean","olive","onion",
        "opera","otter","panic","peace","pearl","phase","plant","plate",
        "pouch","pride","quest","quiet","raven","realm","reign","rider",
        "ridge","river","roast","robin","rogue","royal","ruins","saint",
        "scale","scout","sharp","shell","shine","shore","sight","stone",
        "storm","sugar","sword","table","tiger","torch","tower","trail",
        "truce","trust","vault","water","wheat","witch","world","wound",
        "about","above","actor","admit","adopt","adult","agent","agree",
        "alarm","album","alert","alien","alley","alpha","altar","amber",
        "angel","anger","angle","ankle","arena","argue","armor","arrow",
        "asset","audio","avoid","awake","award","badge","baker","basic",
        "beard","began","begin","belly","bench","berry","birth","black",
        "blame","blank","blast","blend","blind","block","blood","board",
        "bonus","boost","booth","bound","brain","brand","brass","breed",
        "brief","bring","brown","brush","build","built","bunch","burst",
        "cabin","cable","camel","canal","candy","cargo","catch","cause",
        "chain","chaos","cheap","cheek","cheer","chief","chill","choir",
        "civil","claim","clash","clean","clear","clerk","click","climb",
        "clock","close","coach","comet","coral","couch","count","court",
        "cover","crack","craft","crash","cream","creek","creep","crime",
        "crisp","cross","crowd","crush","curve","cycle","daily","dairy",
        "delay","delta","dense","depth","devil","diary","dodge","donor",
        "dough","dozen","draft","drain","drama","dress","drift","drill",
        "drive","drove","dwarf",
    },
    [6] = {
        "amulet","anchor","animal","archer","armory","autumn","banner","barrel",
        "basket","battle","beacon","bottle","branch","breeze","bridge","bright",
        "bronze","candle","canvas","canyon","castle","cavern","cellar","chapel",
        "cheese","cherry","clever","cloudy","clover","copper","cotton","county",
        "crater","cattle","damage","dagger","danger","dragon","driver","empire",
        "emblem","escape","falcon","family","forest","fossil","frozen","garden",
        "goblet","ground","guitar","hammer","hamlet","harbor","health","hollow",
        "hunter","indigo","island","jungle","keeper","knight","lagoon","legend",
        "lizard","lumber","mallet","marble","market","meadow","meteor","mirror",
        "museum","nectar","oxygen","palace","parcel","parrot","pepper","pewter",
        "pillar","planet","potion","priest","puzzle","quiver","ravine","region",
        "ribbon","saddle","savage","scroll","shield","shovel","silver","sphere",
        "spider","spirit","sprout","statue","stream","summit","sunset","temple",
        "throne","timber","tunnel","valley","velvet","violet","walnut","warden",
        "wealth","willow","window","winter","wizard","wonder","wooden",
    },
    [7] = {
        "academy","admiral","ancient","antique","arrival","balcony","bandage",
        "banquet","blanket","blossom","bravery","brigade","cabinet","caravan",
        "cascade","cavalry","chamber","chapter","cheetah","chimney","citadel",
        "compass","concord","cottage","crimson","crystal","cyclone","dolphin",
        "dungeon","emerald","evening","fantasy","feather","fortune","freedom",
        "gallery","gateway","general","glacier","granite","gravity","harvest",
        "journey","kingdom","lantern","leopard","library","mansion","mariner",
        "mineral","monarch","mystery","obelisk","orchard","outpost","pendant",
        "phoenix","pyramid","quarter","rampart","respect","saffron","scepter",
        "scholar","serpent","shatter","shelter","soldier","sparrow","station",
        "stellar","thunder","tornado","trident","venison","village","warrior",
        "whisper","wildcat",
    },
}

local WORDS_BY_LEN = {}
for len, list in pairs(RAW) do
    local t = {}
    for i = 1, #list do
        if #list[i] == len then t[#t + 1] = list[i] end
    end
    WORDS_BY_LEN[len] = t
end
local TOTAL5 = #WORDS_BY_LEN[5]   -- used to seed fluency for pre-points saves

-- Tile colors: {r, g, b, a}.
local COLORS = {
    empty  = { 0.10, 0.10, 0.13, 0.90 },
    filled = { 0.17, 0.17, 0.22, 1.00 },
    green  = { 0.29, 0.53, 0.24, 1.00 },
    yellow = { 0.72, 0.60, 0.18, 1.00 },
    gray   = { 0.22, 0.22, 0.25, 1.00 },
}

local gameFrame, grid
local tiles = {}
local input, clueLabel, clueText, statusText, statsText, repBar
local built = false
local wordLen = 5

-- Round state.
local target, clue, langId, row, over

-- Forward declarations.
local newRound, updateStats, submitGuess, fillCurrentRow, applyLength, setDifficulty

local function DB()
    TonguesOfAzerothDB = TonguesOfAzerothDB or {}
    local t = TonguesOfAzerothDB.trainer or {}
    TonguesOfAzerothDB.trainer = t
    if t.played == nil then t.played = 0 end
    if t.wins   == nil then t.wins   = 0 end
    if t.streak == nil then t.streak = 0 end
    if t.best   == nil then t.best   = 0 end
    t.words = t.words or {}
    t.points = t.points or {}
    if t.difficulty == nil then t.difficulty = "medium" end
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
--  Fluency is a 0-100% value accumulated from solves; ranks are checked
--  high-to-low, the first threshold you meet wins.
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

local function countWords(set)
    local n = 0
    if set then for _ in pairs(set) do n = n + 1 end end
    return n
end

local function progressFor(id)
    id = Language.GetWordsetId(id or "")
    local d = DB()
    local learned = countWords(d.words[id or ""])
    -- Fluency % comes from accumulated points. Older saves (pre-points) fall back
    -- to their solved-word ratio so they don't reset to 0.
    local frac = d.points and d.points[id or ""]
    if frac == nil then
        frac = (TOTAL5 > 0) and (learned / TOTAL5) or 0
    end
    if frac > 1 then frac = 1 end
    return learned, TOTAL5, frac
end

-- Exposed so the settings UI can show each language's rank/progress too.
ns.Trainer = ns.Trainer or {}
ns.Trainer.GetProgress = progressFor
function ns.Trainer.GetRank(frac)
    local r = rankFor(frac)
    return r.name, r.color
end

-- Directly set a language's fluency (0-1). Used by passive learning, the main
-- panel Fluency slider and the Make Fluent / Reset buttons. Writes to the same
-- per-wordset "points" store the trainer uses, so speaking strength, decode
-- tags and trainer progress all stay in sync. Returns the clamped value.
function ns.Trainer.SetFluency(id, frac)
    local key = Language.GetWordsetId(id or "")
    if not key or key == "" then return 0 end
    local d = DB()
    frac = tonumber(frac) or 0
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    d.points[key] = frac
    return frac
end

-- Add (or subtract) fluency, clamped to 0-1. Returns the new value.
function ns.Trainer.AddFluency(id, delta)
    local _, _, cur = progressFor(id)
    return ns.Trainer.SetFluency(id, (cur or 0) + (tonumber(delta) or 0))
end

-- Wipe a language's fluency and the words unlocked for its wordset (full reset).
function ns.Trainer.ResetFluency(id)
    local key = Language.GetWordsetId(id or "")
    if not key or key == "" then return end
    local d = DB()
    d.points[key] = 0
    d.words[key] = nil
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
        for c = 1, MAXLEN do setTile(r, c, "", "empty") end
    end
end

local function evaluate(guess, tgt)
    local n = #tgt
    local res = {}
    local counts = {}
    for i = 1, n do
        local ch = tgt:sub(i, i)
        counts[ch] = (counts[ch] or 0) + 1
    end
    for i = 1, n do
        local ch = guess:sub(i, i)
        if ch == tgt:sub(i, i) then
            res[i] = "green"
            counts[ch] = counts[ch] - 1
        end
    end
    for i = 1, n do
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
        local learned, _, frac = progressFor(langId)
        local r = rankFor(frac)
        repBar:SetBarColor(r.color[1], r.color[2], r.color[3])
        repBar:SetProgress(frac)
        repBar:SetText(string.format("%s  -  %s  (%d%% fluent, %d words)",
            langName(), r.name, math.floor(frac * 100 + 0.5), learned))
    end

    -- Live-update the Learned Languages panel's fluency bars if it's open too.
    if ns.RefreshLearnedIfShown then ns.RefreshLearnedIfShown() end
end

function fillCurrentRow(text)
    if over or not row or not built then return end
    local g = string.upper(text or "")
    g = g:gsub("[^A-Z]", "")
    for c = 1, wordLen do
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

    local pool = WORDS_BY_LEN[wordLen] or WORDS_BY_LEN[5]
    local w
    repeat w = pool[math.random(#pool)] until w ~= d.lastWord or #pool == 1
    d.lastWord = w

    target = string.upper(w)
    clue = string.upper(Language.TranslateText(w, 100, langId) or w)
    row = 1
    over = false

    clearGrid()
    clueLabel:SetText("Decipher this |cffffd200" .. langName() .. "|r word:")
    clueText:SetText(clue)
    statusText:SetText("Guess the " .. wordLen .. "-letter word in " .. MAX_GUESSES .. " tries.")
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
    if #g ~= wordLen then
        statusText:SetText("|cffff8800Enter a " .. wordLen .. "-letter word.|r")
        return
    end

    local fb = evaluate(g, target)
    for c = 1, wordLen do
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

        -- Seed fluency from any pre-points progress so upgrades don't regress.
        if d.points[key] == nil then
            d.points[key] = (TOTAL5 > 0) and (countWords(d.words[key]) / TOTAL5) or 0
        end
        -- Difficulty base %, scaled by streak (streak 1 = x1, 2 = x1.25, 3 = x1.5...).
        local base = diffFor(d.difficulty).pct / 100
        local gain = base * (1 + (d.streak - 1) * STREAK_BONUS)
        d.points[key] = math.min(1, d.points[key] + gain)

        statusText:SetText(string.format(
            "|cff33ff33Solved!|r  |cffffd200%s|r = |cffffffff%s|r   |cff88ff88+%.1f%% fluency|r (streak %d)",
            clue, target, gain * 100, d.streak))
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

-- Give up on the current word: reveal the answer, end the round, and break the
-- streak (revealing isn't a solve, so it earns no fluency).
local function revealAnswer()
    if not built or over then return end
    local d = DB()
    d.played = d.played + 1
    d.streak = 0
    for c = 1, wordLen do setTile(row, c, target:sub(c, c), "green") end
    statusText:SetText("|cffff5555Revealed.|r  |cffffd200" .. clue .. "|r = |cffffffff" .. target .. "|r")
    over = true
    if input then
        input:SetText("")
        input:ClearFocus()
    end
    updateStats()
end

-- Show only the columns the current difficulty needs and resize/recenter the grid.
function applyLength(len)
    wordLen = len
    for r = 1, MAX_GUESSES do
        for c = 1, MAXLEN do
            local tile = tiles[r] and tiles[r][c]
            if tile then
                if c <= len then tile.frame:Show() else tile.frame:Hide() end
            end
        end
    end
    if grid then grid:SetWidth(len * TILE + (len - 1) * GAP) end
    if input then input:SetMaxLetters(len) end
end

function setDifficulty(id)
    local d = DB()
    d.difficulty = diffFor(id).id
    applyLength(diffFor(id).len)
    newRound()
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
    -- main panel) alongside the always-present close (X).
    gameFrame._backAction = function() if ns.OpenConfig then ns.OpenConfig() end end
    local f = gameFrame

    -- Language picker: train any language, independent of the chat language.
    local pickLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pickLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -18)
    pickLabel:SetText("Language:")

    local pickDD = Compat.CreateDropdown(f, 210)
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

    -- Difficulty picker: sets word length + fluency value per solve.
    local diffLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    diffLabel:SetPoint("LEFT", pickDD, "RIGHT", 16, 0)
    diffLabel:SetText("Difficulty:")

    local diffDD = Compat.CreateDropdown(f, 120)
    diffDD:SetPoint("LEFT", diffLabel, "RIGHT", 6, 0)
    local ditems = {}
    for i = 1, #DIFFICULTIES do
        ditems[i] = { text = DIFFICULTIES[i].name, value = DIFFICULTIES[i].id }
    end
    diffDD:SetItems(ditems)
    diffDD:SetSelected(DB().difficulty, diffFor(DB().difficulty).name)
    diffDD.onSelect = function(value)
        diffDD:SetSelected(value, diffFor(value).name)
        setDifficulty(value)
    end

    clueLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    clueLabel:SetPoint("TOP", f, "TOP", 0, -56)

    clueText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    clueText:SetPoint("TOP", clueLabel, "BOTTOM", 0, -6)
    clueText:SetTextColor(0.85, 0.75, 1)

    local gridH = MAX_GUESSES * TILE + (MAX_GUESSES - 1) * GAP

    grid = CreateFrame("Frame", nil, f)
    grid:SetSize(MAXLEN * TILE + (MAXLEN - 1) * GAP, gridH)
    grid:SetPoint("TOP", clueText, "BOTTOM", 0, -16)

    for r = 1, MAX_GUESSES do
        tiles[r] = {}
        for c = 1, MAXLEN do
            local t = CreateFrame("Frame", nil, grid)
            t:SetSize(TILE, TILE)
            t:SetPoint("TOPLEFT", grid, "TOPLEFT", (c - 1) * (TILE + GAP), -((r - 1) * (TILE + GAP)))
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

    -- Input + action buttons, centered under the grid so they stay on-screen
    -- regardless of the grid's width (which changes with difficulty).
    local controls = CreateFrame("Frame", nil, f)
    controls:SetSize(366, 24)
    controls:SetPoint("TOP", grid, "BOTTOM", 0, -18)

    input = CreateFrame("EditBox", "TonguesOfAzerothGameInput", controls, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetMaxLetters(wordLen)
    input:SetSize(110, 24)
    input:SetPoint("LEFT", controls, "LEFT", 6, 0)
    input:SetScript("OnTextChanged", function(self) fillCurrentRow(self:GetText()) end)
    input:SetScript("OnEnterPressed", function() submitGuess() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local guessBtn = makeButton(controls, "Guess", 72)
    guessBtn:SetPoint("LEFT", input, "RIGHT", 10, 0)
    guessBtn:SetScript("OnClick", function() submitGuess() end)

    local revealBtn = makeButton(controls, "Reveal", 72)
    revealBtn:SetPoint("LEFT", guessBtn, "RIGHT", 8, 0)
    revealBtn:SetScript("OnClick", function() revealAnswer() end)

    local newBtn = makeButton(controls, "New Word", 86)
    newBtn:SetPoint("LEFT", revealBtn, "RIGHT", 8, 0)
    newBtn:SetScript("OnClick", function() newRound() end)

    statusText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOP", controls, "BOTTOM", 0, -16)
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

    repBar = Compat.CreateStatusBar(f, 340, 18)
    repBar:SetPoint("TOP", repLabel, "BOTTOM", 0, -4)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOP", repBar, "BOTTOM", 0, -14)
    hint:SetPoint("LEFT", f, "LEFT", 20, 0)
    hint:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    hint:SetJustifyH("CENTER")
    hint:SetText("Green = right letter & spot, Yellow = right letter wrong spot, Gray = not in word.\nHarder words and longer streaks earn more fluency. Reveal gives up (and resets the streak).")

    -- Match the grid to the saved difficulty before the first round.
    applyLength(diffFor(DB().difficulty).len)

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
