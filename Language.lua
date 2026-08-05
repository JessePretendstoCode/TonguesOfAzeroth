--[[-------------------------------------------------------------------------
    Tongues of Azeroth - Language.lua
    A constructed-language engine that mirrors WoW's own in-game language parser.

    HOW BLIZZARD DOES IT (and how we replicate it):
      * Text is split into words.
      * Each word is replaced with a word of the SAME LETTER-LENGTH drawn from a
        fixed per-language word list (bucketed by letter count, capped at 18).
        If no bucket exists for that length, the next shorter bucket is used.
      * The replacement is chosen deterministically from the word's hash, so the
        same word always maps to the same output and sentences stay consistent.
      * The replacement copies the original word's capitalisation.

    Because replacements match the source word's length, output length tracks
    input length -- no more 20-letter monstrosities.

    The per-language WORD LISTS below are the authentic in-game parser word lists
    documented on Wowpedia / Warcraft Wiki (the game's real "dictionary"; the
    parser is cosmetic and not a true translator). Buckets are indexed by letter
    count: WORDS[n] is the list of words used for n-letter source words.

    OLD GOD (Shath'yar) has no in-game parser list, so it uses a length-capped
    syllable generator instead (see GENERATORS).
---------------------------------------------------------------------------]]

local ADDON, ns = ...
ns = ns or {}

local Language = {}
ns.Language = Language

local floor = math.floor
local strbyte, strlen, strsub, strupper, strlower = string.byte, string.len, string.sub, string.upper, string.lower

Language.DEFAULT = "oldgod"
local MAX_WORD_LEN = 18 -- Blizzard caps parser lookups at 18 letters.

--=========================================================================--
--  Language registry
--=========================================================================--
local LANGUAGES = {}
local LANGUAGE_ORDER = {}

local function register(id, def)
    def.id = id
    LANGUAGES[id] = def
    LANGUAGE_ORDER[#LANGUAGE_ORDER + 1] = id
end

--=========================================================================--
--  OLD GOD (Shath'yar) - eldritch; generated, length-capped.
--=========================================================================--
register("oldgod", {
    name = "Old God (Shath'yar)",
    generator = {
        apostrophe = 0.3,
        onsets = { "", "y", "z", "zz", "sh", "th", "gh", "ph", "kth", "qw", "vr", "sh", "og", "n", "m", "h", "s", "v", "gn", "gr", "kr", "bh", "ny", "gl", "fh" },
        nuclei = { "a", "aa", "o", "oo", "u", "uu", "i", "ii", "ee", "ya", "ua", "yo", "iy", "ai", "ou", "ah" },
        codas  = { "", "th", "gth", "r", "l", "n", "g", "kh", "sh", "z", "x", "gn", "ph", "hn" },
    },
})

--=========================================================================--
--  ORCISH  (authentic in-game parser word list)
--=========================================================================--
register("orcish", {
    name = "Orcish",
    words = {
        { "A", "N", "G", "O", "L" },
        { "Ha", "Ko", "No", "Mu", "Ag", "Ka", "Gi", "Il" },
        { "Lok", "Tar", "Kaz", "Ruk", "Kek", "Mog", "Zug", "Gul", "Nuk", "Aaz", "Kil", "Ogg" },
        { "Rega", "Nogu", "Tago", "Uruk", "Kagg", "Zaga", "Grom", "Ogar", "Gesh", "Thok", "Dogg", "Maka", "Maza" },
        { "Regas", "Nogah", "Kazum", "Magan", "No'bu", "Golar", "Throm", "Zugas", "Re'ka", "No'ku", "Ro'th" },
        { "Thrakk", "Revash", "Nakazz", "Moguna", "No'gor", "Goth'a", "Raznos", "Ogerin", "Gezzno", "Thukad", "Makogg", "Aaz'no" },
        { "Lok'Tar", "Gul'rok", "Kazreth", "Tov'osh", "Zil'Nok", "Rath'is", "Kil'azi" },
        { "Throm'ka", "Osh'Kava", "Gul'nath", "Kog'zela", "Ragath'a", "Zuggossh", "Moth'aga" },
        { "Tov'nokaz", "Osh'kazil", "No'throma", "Gesh'nuka", "Lok'mogul", "Lok'bolar", "Ruk'ka'ha" },
        { "Regasnogah", "Kazum'nobu", "Throm'bola", "Gesh'zugas", "Maza'rotha", "Ogerin'naz" },
        { "Thrakk'reva", "Kaz'goth'no", "No'gor'goth", "Kil'azi'aga", "Zug-zug'ama", "Maza'thrakk" },
        { "Lokando'nash", "Ul'gammathar", "Golgonnashar", "Dalggo'mazah" },
        { "Khaz'rogg'ahn", "Moth'kazoroth" },
    },
})

--=========================================================================--
--  DARNASSIAN  (authentic in-game parser word list)
--=========================================================================--
register("darnassian", {
    name = "Darnassian",
    words = {
        { "A", "D", "E", "I", "N", "O" },
        { "Al", "An", "Da", "Do", "Lo", "Ni", "No", "Ri", "Su" },
        { "Ala", "Ano", "Anu", "Ash", "Dor", "Dur", "Fal", "Nei", "Nor", "Osa", "Tal", "Tur" },
        { "Alah", "Aman", "Anar", "Andu", "Dath", "Dieb", "Diel", "Fulo", "Mush", "Rini", "Shar", "Thus" },
        { "Adore", "Balah", "Bandu", "Eburi", "Fandu", "Ishnu", "Shano", "Shari", "Talah", "Terro", "Thera", "Turus" },
        { "Asto're", "Belore", "Do'rah", "Dorini", "Ethala", "Falla", "Ishura", "Man'ar", "Neph'o", "Shando", "T'as'e", "U'phol" },
        { "Al'shar", "Alah'ni", "Aman'ni", "Anoduna", "Dor'Ano", "Mush'al", "Shan're" },
        { "D'ana'no", "Dal'dieb", "Dorithur", "Eraburis", "Il'amare", "Mandalas", "Thoribas" },
        { "Banthalos", "Dath'anar", "Dune'adah", "Fala'andu", "Neph'anis", "Shari'fal", "Thori'dal" },
        { "Ash'therod", "Dorados'no", "Isera'duna", "Shar'adore", "Thero'shan" },
        { "Fandu'talah", "Shari'adune" },
        { "Dor'ana'badu", "T'ase'mushal" },
        { "U'phol'belore" },
        { "Anu'dorannador", "Turus'il'amare" },
        { "Asto're'dunadah", "Shindu'falla'na" },
    },
})

--=========================================================================--
--  THALASSIAN  (authentic in-game parser word list)
--=========================================================================--
register("thalassian", {
    name = "Thalassian",
    words = {
        { "A", "N", "I", "O", "E", "D" },
        { "Da", "Lo", "An", "Ni", "Al", "Do", "Ri", "Su", "No" },
        { "Ano", "Dur", "Tal", "Nei", "Ash", "Dor", "Anu", "Fal", "Tur", "Ala", "Nor", "Osa" },
        { "Alah", "Andu", "Dath", "Mush", "Shar", "Thus", "Fulo", "Aman", "Diel", "Dieb", "Rini", "Anar" },
        { "Talah", "Adore", "Ishnu", "Bandu", "Balah", "Fandu", "Thera", "Turus", "Shari", "Shano", "Terro", "Eburi" },
        { "Dorini", "Shando", "Ethala", "Fallah", "Belore", "Do'rah", "Neph'o", "Man'ar", "Ishura", "U'phol", "T'as'e" },
        { "Asto're", "Anoduna", "Alah'ni", "Dor'Ano", "Al'shar", "Mush'al", "Aman'ni", "Shan're" },
        { "Mandalas", "Eraburis", "Dorithur", "Dal'dieb", "Thoribas", "D'ana'no", "Il'amare" },
        { "Neph'anis", "Dune'adah", "Banthalos", "Fala'andu", "Dath'anar", "Shari'fal", "Thori'dal" },
        { "Thero'shan", "Isera'duna", "Ash'therod", "Dorados'no", "Shar'adore" },
        { "Fandu'talah", "Shari'adune" },
        { "Dor'ana'badu", "T'ase'mushal" },
        { "U'phol'belore" },
        { "Turus'il'amare", "Anu'dorannador" },
        { "Asto're'dunadah" },
        { "Shindu'fallah'na" },
    },
})

--=========================================================================--
--  DWARVEN / DWARVISH  (authentic in-game parser word list)
--=========================================================================--
register("dwarven", {
    name = "Dwarven",
    words = {
        { "A" },
        { "Am", "Ga", "Go", "Ke", "Lo", "Ok", "Ta", "Um", "We", "Zu" },
        { "Ahz", "Dum", "Dun", "Eft", "Gar", "Gor", "Hor", "Kha", "Mok", "Mos", "Red", "Ruk" },
        { "Gear", "Gosh", "Grum", "Guma", "Helm", "Hine", "Hoga", "Hrim", "Khaz", "Kost", "Loch", "Modr", "Rand", "Rune", "Thon" },
        { "Algaz", "Angor", "Dagum", "Frean", "Gimil", "Goten", "Havar", "Havas", "Mitta", "Modan", "Modor", "Scyld", "Skalf", "Thros", "Weard" },
        { "Bergum", "Drugan", "Farode", "Haldir", "Haldji", "Modgud", "Modoss", "Mogoth", "Robush", "Rugosh", "Skolde", "Syddan" },
        { "Dun-fel", "Ganrokh", "Geardum", "Godkend", "Haldren", "Havagun", "Kaelsag", "Kost-um", "Mok-kha", "Ok-Hoga", "Thorneb", "Zu-Modr" },
        { "Azregahn", "Gefrunon", "Golganar", "Khaz-dum", "Khazrega", "Misfaran", "Mogodune", "Moth-tur", "Thulmane" },
        { "Ahz-Dagum", "Angor-dum", "Arad-Khaz", "Gor-skalf", "Grum-mana", "Khaz-rand", "Kost-Guma", "Mund-helm" },
        { "Angor-Magi", "Gar-Mogoth", "Hoga-Modan", "Midd-Havas", "Nagga-roth", "Thros-gare" },
        { "Azgol-haman", "Dun-haldren", "Ge'ar-anvil", "Guma-syddan" },
        { "Robush-mogan", "Thros-am-Kha" },
        { "Gimil-thumane", "Gol'gethrunon", "Haldji-drugan" },
        { "Gosh-algaz-dun", "Scyld-modor-ok" },
    },
})

--=========================================================================--
--  GNOMISH  (authentic in-game parser word list)
--=========================================================================--
register("gnomish", {
    name = "Gnomish",
    words = {
        { "A", "C", "D", "E", "F", "G", "I", "O", "T" },
        { "Am", "Ga", "Ke", "Lo", "Ok", "So", "Ti", "Um", "Va", "We" },
        { "Bur", "Dun", "Fez", "Giz", "Gal", "Gar", "Her", "Mik", "Mor", "Mos", "Nid", "Rod", "Zah" },
        { "Buma", "Cost", "Dani", "Gear", "Gosh", "Grum", "Helm", "Hine", "Huge", "Lock", "Kahs", "Rand", "Riff", "Rune" },
        { "Algos", "Angor", "Dagem", "Frend", "Goten", "Haven", "Havis", "Mitta", "Modan", "Modor", "Nagin", "Tiras", "Thros", "Weird" },
        { "Danieb", "Drugan", "Dumssi", "Gizber", "Haldir", "Helmok", "Mergud", "Protos", "Revosh", "Rugosh", "Shermt", "Waldor" },
        { "Bergrim", "Costirm", "Ferdosr", "Ganrokh", "Geardum", "Godling", "Haidren", "Havagun", "Noxtyec", "Scrutin", "Sturome", "Thorneb" },
        { "Aldanoth", "Azregorn", "Bolthelm", "Botlikin", "Dimligar", "Gefrunon", "Godunmug", "Grumgizr", "Kahsgear", "Kahzregi", "Landivar", "Methrine", "Mikthros", "Misfaran", "Nandiger", "Thulmane" },
        { "Angordame", "Elodergim", "Elodmodor", "Naggirath", "Nockhavis" },
        { "Ahzodaugum", "Alegaskron", "Algosgoten", "Danavandar", "Dyrstagist", "Falhadrink", "Frendgalva", "Mosgodunan", "Mundgizber", "Naginbumat", "Sihnvulden", "Throsigear", "Vustrangin" },
        { "Ferdosmodan", "Gizbarlodun", "Haldjinagin", "Helmokheram", "Kahzhaldren", "Lockrevoshi", "Robuswaldir", "Skalfgizgar", "Thrunon'gol", "Thumanerand" },
    },
})

--=========================================================================--
--  TAUR-AHE  (authentic in-game parser word list)
--=========================================================================--
register("taurahe", {
    name = "Taur-ahe (Tauren)",
    words = {
        { "A", "E", "I", "N", "O" },
        { "Ba", "Ki", "Lo", "Ne", "Ni", "No", "Po", "Ta", "Te", "Tu", "Wa" },
        { "Aki", "Alo", "Awa", "Chi", "Ich", "Ish", "Kee", "Owa", "Paw", "Rah", "Uku", "Zhi" },
        { "A'ke", "Awak", "Balo", "Eche", "Isha", "Hale", "Halo", "Mani", "Nahe", "Shne", "Shte", "Tawa", "Towa" },
        { "A'hok", "A'iah", "Abalo", "Ahmen", "Anohe", "Ishte", "Kashu", "Nechi", "Nokee", "Pawni", "Poalo", "Porah", "Shush", "Ti'ha", "Tanka", "Yakee" },
        { "Aloaki", "Hetawa", "Ichnee", "Lakota", "Lomani", "Neahok", "Nitawa", "Owachi", "Pawene", "Sho'wa", "Taisha", "Washte" },
        { "Ishnelo", "Owakeri", "Pikialo", "Sechalo", "Shtealo", "Shteawa", "Tihikea", "Kichalo" },
        { "Akiticha", "Awaihilo", "Ishnialo", "O'ba'chi", "Orahpajo", "Ovaktalo", "Owatanka", "Porahalo", "Shtumani", "Tatahalo", "Towateke" },
        { "Echeyakee", "Haloyakee", "Ishne'alo", "Tawaporah" },
        { "Awaka'nahe", "Ichnee'awa", "Ishamuhale", "Shteowachi" },
        { "Aloaki'shne", "Awakeekielo", "Lakota'mani", "Shtumanialo" },
        { "Awakeekielo", "Aloaki'shne" },
        { "Ishne'awahalo", "Neashushahmen" },
        { "Awakeeahmenalo" },
        { "Ishne'alo'porah" },
    },
})

--=========================================================================--
--  ZANDALI (Troll)  (authentic in-game parser word list)
--=========================================================================--
register("zandali", {
    name = "Zandali (Troll)",
    words = {
        { "A", "E", "H", "J", "M", "N", "O", "S", "U" },
        { "Di", "Fi", "Fu", "Im", "Ir", "Is", "Ju", "So", "Wi", "Yu" },
        { "Deh", "Dim", "Fus", "Han", "Mek", "Noh", "Sca", "Tor", "Weh", "Wha" },
        { "Cyaa", "Duti", "Iman", "Iyaz", "Riva", "Skam", "Ting", "Worl", "Yudo" },
        { "Ackee", "Atuad", "Caang", "Difus", "Nehjo", "Siame", "T'ief", "Wassa" },
        { "Bwoyar", "Deh'yo", "Fidong", "Honnah", "Icense", "Italaf", "Quashi", "Saakes", "Smadda", "Stoosh", "Wi'mek", "Yuutee" },
        { "Chakari", "Craaweh", "Flimeff", "Godehsi", "Lok'dim", "Reespek", "Rivasuf", "Tanponi", "Uptfeel", "Yahsoda", "Ziondeh" },
        { "Ginnalka", "Machette", "Nyamanpo", "Oondasta", "Wehnehjo", "Whutless", "Yeyewata", "Zutopong" },
        { "Fus'obeah", "Or'manley" },
    },
})

--=========================================================================--
--  DRAENEI  (authentic in-game parser word list)
--=========================================================================--
register("draenei", {
    name = "Draenei",
    words = {
        { "A", "E", "G", "I", "O", "U", "X", "Y" },
        { "Az", "Il", "Me", "No", "Re", "Te", "Ul", "Ur", "Xi", "Za", "Ze" },
        { "Asj", "Daz", "Gul", "Kar", "Laz", "Lek", "Lok", "Maz", "Ril", "Ruk", "Shi", "Tor", "Zar" },
        { "Alar", "Aman", "Amir", "Ante", "Ashj", "Kiel", "Maev", "Maez", "Orah", "Parn", "Raka", "Rikk", "Veni", "Zenn", "Zila" },
        { "Adare", "Belan", "Buras", "Enkil", "Golad", "Gular", "Kamil", "Melar", "Modas", "Nagas", "Rakir", "Refir", "Revos", "Soran", "Tiros", "Zekul" },
        { "Arakal", "Archim", "Azgala", "Karkun", "Kazile", "Mannor", "Mishun", "Rakkan", "Rakkas", "Rethul", "Revola", "Thorje", "Tichar" },
        { "Amanare", "Belaros", "Danashj", "Faralos", "Faramos", "Gulamir", "Karaman", "Kieldaz", "Rethule", "Tiriosh", "Toralar", "Zennshi" },
        { "Amanalar", "Ashjraka", "Azgalada", "Azrathud", "Belankar", "Enkilzar", "Kirasath", "Maladath", "Mordanas", "Romathis", "Rukadare", "Sorankar", "Theramas" },
        { "Arakalada", "Kanrethad", "Melamagas", "Melarorah", "Nagasraka", "Naztheros", "Soranaman", "Teamanare", "Zilthuras" },
        { "Amanemodas", "Ashjrethul", "Benthadoom", "Burasadare", "Enkilgular", "Kamilgolad", "Matheredor", "Pathrebosh", "Ticharamir", "Zennrakkan" },
        { "Archimtiros", "Ashjrakamas", "Mannorgulan", "Mishunadare", "Zekulrakkas" },
        { "Zennshinagas" },
    },
})

--=========================================================================--
--  GUTTERSPEAK (Forsaken; shares the Common word list)
--=========================================================================--
register("gutterspeak", {
    name = "Gutterspeak (Forsaken)",
    words = {
        { "A", "E", "I", "O", "U", "Y" },
        { "An", "Ko", "Lo", "Lu", "Me", "Ne", "Re", "Ru", "Se", "Ti", "Va", "Ve" },
        { "Ash", "Bor", "Bur", "Far", "Gol", "Hir", "Lon", "Mos", "Nud", "Ras", "Ver", "Vil", "Wos" },
        { "Ador", "Agol", "Dana", "Goth", "Lars", "Noth", "Nuff", "Odes", "Ruff", "Thor", "Uden", "Veld", "Vohl", "Vrum" },
        { "Algos", "Barad", "Borne", "Eynes", "Ergin", "Garde", "Gloin", "Majis", "Melka", "Nagan", "Novas", "Regen", "Tiras", "Wirsh" },
        { "Aesire", "Aziris", "Daegil", "Danieb", "Ealdor", "Engoth", "Goibon", "Mandos", "Nevren", "Rogesh", "Rothas", "Ruftos", "Skilde", "Valesh", "Vandar", "Waldir" },
        { "Andovis", "Ewiddan", "Faergas", "Forthis", "Kaelsig", "Koshvel", "Lithtos", "Nandige", "Nostyec", "Novaedi", "Sturume", "Vassild" },
        { "Aldonoth", "Cynegold", "Endirvis", "Hamerung", "Landowar", "Lordaere", "Methrine", "Ruftvess", "Thorniss" },
        { "Aetwinter", "Danagarde", "Eloderung", "Firalaine", "Gloinador", "Gothalgos", "Regenthor", "Udenmajis", "Vandarwos", "Veldbarad" },
        { "Aelgestron", "Cynewalden", "Danavandar", "Dyrstigost", "Falhedring", "Vastrungen" },
        { "Agolandovis", "Bornevalesh", "Farlandowar", "Forthasador", "Thorlithtos", "Vassildador", "Wershaesire" },
        { "Adorstaerume", "Golveldbarad", "Mandosdaegil", "Nevrenrothas", "Waldirskilde" },
    },
})

--=========================================================================--
--  DEMONIC (Eredun)  (authentic in-game parser word list)
--=========================================================================--
register("demonic", {
    name = "Demonic (Eredun)",
    words = {
        { "A", "E", "I", "G", "O", "U", "X", "Y" },
        { "Az", "Il", "Me", "No", "Re", "Te", "Ul", "Ur", "Xi", "Za", "Ze" },
        { "Asj", "Daz", "Gul", "Kar", "Laz", "Lek", "Lok", "Maz", "Ril", "Ruk", "Shi", "Tor", "Zar" },
        { "Alar", "Aman", "Amir", "Ante", "Ashj", "Kiel", "Maev", "Maez", "Orah", "Parn", "Raka", "Rikk", "Veni", "Zenn", "Zila" },
        { "Adare", "Belan", "Buras", "Enkil", "Golad", "Gular", "Kamil", "Melar", "Modas", "Nagas", "Rakir", "Refir", "Revos", "Soran", "Tiros", "Zekul" },
        { "Arakal", "Archim", "Azgala", "Karkun", "Kazile", "Mannor", "Mishun", "Rakkan", "Rakkas", "Rethul", "Revola", "Thorje", "Tichar" },
        { "Amanare", "Belaros", "Danashj", "Faramos", "Gulamir", "Karaman", "Kieldaz", "Rethule", "Tiriosh", "Toralar", "Zennshi" },
        { "Amanalar", "Ashjraka", "Azgalada", "Azrathud", "Belankar", "Enkilzar", "Kirasath", "Maladath", "Mordanas", "Romathis", "Rukadare", "Sorankar", "Theramas" },
        { "Arakalada", "Kanrethad", "Melarorah", "Nagasraka", "Naztheros", "Soranaman", "Teamanare", "Zilthuras" },
        { "Amanemodas", "Ashjrethul", "Benthadoom", "Burasadare", "Enkilgular", "Kamilgolad", "Matheredor", "Melarnagas", "Pathrebosh", "Ticharamir", "Zennrakkan" },
        { "Archimtiros", "Ashjrakamas", "Mannorgulan", "Mishunadare", "Zekulrakkas" },
        { "Zennshinagas" },
    },
})

--=========================================================================--
--  Deterministic hashing + PRNG (Lua 5.1 / WoW safe; all math < 2^53).
--=========================================================================--
local function hashString(s)
    local h = 5381
    for i = 1, strlen(s) do
        h = (h * 33 + strbyte(s, i)) % 2147483648
    end
    return h
end

local function makeRNG(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end

local function pick(rng, pool)
    return pool[1 + floor(rng() * #pool)]
end

--=========================================================================--
--  Old God generator (length-targeted so output ~ source length).
--=========================================================================--
local generateCache = {}

local function generateWord(lower, lang)
    local key = lang.id .. ":" .. lower
    local cached = generateCache[key]
    if cached then return cached end

    local gen = lang.generator
    local rng = makeRNG(hashString(key) + 1)

    local target = strlen(lower)
    if target < 2 then target = 2 end
    if target > MAX_WORD_LEN then target = MAX_WORD_LEN end

    local word = ""
    while strlen(word) < target do
        local syl = pick(rng, gen.onsets) .. pick(rng, gen.nuclei) .. pick(rng, gen.codas)
        if syl == "" then syl = pick(rng, gen.nuclei) end
        if word ~= "" and rng() < gen.apostrophe then
            word = word .. "'" .. syl
        else
            word = word .. syl
        end
    end

    generateCache[key] = word
    return word
end

--=========================================================================--
--  Capitalisation helpers so translated text mirrors the original casing.
--=========================================================================--
local function isUpper(ch) return ch >= "A" and ch <= "Z" end

local function applyCase(original, translated)
    if strlen(original) == 0 or strlen(translated) == 0 then
        return translated
    end
    if strlen(original) > 1 and strupper(original) == original then
        return strupper(translated)
    end
    if isUpper(strsub(original, 1, 1)) then
        return strupper(strsub(translated, 1, 1)) .. strsub(translated, 2)
    end
    return translated
end

--=========================================================================--
--  Word lookup via same-length bucket (Blizzard parser behaviour).
--=========================================================================--
local function bucketWord(lower, lang)
    local words = lang.words
    local L = strlen(lower)
    if L > MAX_WORD_LEN then L = MAX_WORD_LEN end
    while L >= 1 and not words[L] do
        L = L - 1
    end
    local bucket = words[L]
    if not bucket or #bucket == 0 then
        return lower -- no bucket found: leave unchanged
    end
    local idx = (hashString(lower) % #bucket) + 1
    return strlower(bucket[idx])
end

--=========================================================================--
--  Public API
--=========================================================================--
local function resolveLang(langId)
    return LANGUAGES[langId or Language.DEFAULT] or LANGUAGES[Language.DEFAULT]
end

function Language.GetLanguages()
    local out = {}
    for i = 1, #LANGUAGE_ORDER do
        local id = LANGUAGE_ORDER[i]
        out[i] = { id = id, name = LANGUAGES[id].name }
    end
    return out
end

function Language.GetLanguageName(langId)
    local lang = LANGUAGES[langId]
    return lang and lang.name or "?"
end

function Language.IsValid(langId)
    return LANGUAGES[langId] ~= nil
end

-- Word token pattern: letters plus in-word apostrophes/hyphens (Dun-fel, Ok-Hoga).
local WORD_PATTERN = "[%a][%a'-]*"
function Language.WordTranslates(word, strength)
    if strength >= 100 then return true end
    if strength <= 0 then return false end
    return (hashString(strlower(word)) % 100) < strength
end

-- Backward-compatible alias.
Language.WordCorrupts = Language.WordTranslates

-- Translate a single alphabetic word (no surrounding punctuation).
function Language.TranslateWord(word, langId)
    local lang = resolveLang(langId)
    local lower = strlower(word)
    local result
    if lang.dict and lang.dict[lower] then
        result = lang.dict[lower]
    elseif lang.words then
        result = bucketWord(lower, lang)
    else
        result = generateWord(lower, lang)
    end
    return applyCase(word, result)
end

-- Translate a full string. Only alphabetic runs are converted; punctuation,
-- numbers, spacing and links are left untouched.
--   strength (0-100): fraction turned to the chosen tongue (default 100).
--   langId: which language to use (default Language.DEFAULT).
local ENCODE_CACHE = {} -- ENCODE_CACHE[langId][encodedText] = { english, strength }
local SEGMENT_PLACEHOLDER = "\002"

local function protectSegments(text)
    local saved = {}
    local n = 0
    local function stash(segment)
        n = n + 1
        saved[n] = segment
        return SEGMENT_PLACEHOLDER .. n .. SEGMENT_PLACEHOLDER
    end

    -- WoW item/spell/player hyperlinks first (they contain bracketed labels).
    local out = text:gsub("|c%x+|H.-|h.-|h|r", stash)
    -- Any remaining [bracketed] text (should not be translated).
    out = out:gsub("%b[]", stash)
    return out, saved
end

local function restoreSegments(text, saved)
    return text:gsub(SEGMENT_PLACEHOLDER .. "(%d+)" .. SEGMENT_PLACEHOLDER, function(i)
        return saved[tonumber(i)] or ""
    end)
end

local function rememberEncodedMessage(langId, english, encoded, strength)
    if not langId or not encoded or not english or encoded == english then return end
    local bucket = ENCODE_CACHE[langId]
    if not bucket then
        bucket = {}
        ENCODE_CACHE[langId] = bucket
    end
    if bucket[encoded] then return end
    bucket[encoded] = { english = english, strength = strength or 100 }
end

function Language.RememberEncodedMessage(langId, english, encoded, strength)
    rememberEncodedMessage(langId, english, encoded, strength)
end

function Language.TranslateText(text, strength, langId, remember)
    if not text or text == "" then return text end
    strength = strength or 100
    if strength <= 0 then return text end
    local lang = resolveLang(langId)
    local protected, saved = protectSegments(text)
    local translated = protected:gsub(WORD_PATTERN, function(word)
        if Language.WordTranslates(word, strength) then
            return Language.TranslateWord(word, lang.id)
        end
        return word
    end)
    local result = restoreSegments(translated, saved)
    if remember ~= false then
        rememberEncodedMessage(lang.id, text, result, strength)
    end
    return result
end

--=========================================================================--
--  Reverse lookup for "Learned" decoding (English <- translated output).
--=========================================================================--
local REVERSE = {} -- REVERSE[langId][outputLower] = sourceLower | { sources }

-- Common RP / chat vocabulary used to seed the reverse maps at load time.
local COMMON_WORDS = {
    "a", "about", "after", "again", "against", "all", "also", "always", "am", "an", "and",
    "any", "are", "as", "at", "back", "be", "because", "been", "before", "being", "best",
    "better", "between", "both", "but", "by", "call", "can", "cannot", "come", "could",
    "day", "did", "do", "does", "doing", "done", "down", "each", "even", "every", "evil",
    "eyes", "face", "far", "few", "find", "first", "for", "friend", "from", "give", "go",
    "god", "gods", "good", "great", "had", "has", "have", "he", "help", "her", "here",
    "him", "his", "how", "i", "if", "in", "into", "is", "it", "its", "just", "keep", "kill",
    "know", "last", "left", "let", "life", "like", "little", "long", "look", "lord", "love",
    "made", "make", "man", "many", "may", "me", "mind", "more", "most", "much", "must",
    "my", "never", "new", "no", "not", "now", "of", "off", "old", "on", "once", "one",
    "only", "or", "other", "our", "out", "over", "own", "people", "power", "put", "right",
    "said", "say", "see", "shall", "she", "should", "so", "some", "still", "such", "take",
    "tell", "than", "that", "the", "their", "them", "then", "there", "these", "they",
    "thing", "think", "this", "those", "though", "through", "time", "to", "too", "true",
    "under", "until", "up", "us", "very", "want", "was", "we", "well", "were", "what",
    "when", "where", "which", "while", "who", "why", "will", "with", "without", "word",
    "world", "would", "yes", "yet", "you", "your",
    "hello", "hi", "hey", "thanks", "thank", "please", "sorry", "welcome", "bye", "goodbye",
    "attack", "defend", "run", "wait", "stop", "listen", "speak", "hear", "watch", "follow",
    "leader", "ready", "pull", "heal", "buff", "loot", "need", "want", "trade", "group",
    "party", "raid", "guild", "king", "queen", "prince", "princess", "war", "peace", "death",
    "blood", "fire", "ice", "shadow", "light", "dark", "darkness", "magic", "spell", "sword",
    "shield", "honor", "glory", "vengeance", "mercy", "hope", "fear", "pain", "soul", "heart",
    "whisper", "whispers", "madness", "dream", "dreams", "night", "day", "sun", "moon", "star",
    "stars", "sky", "earth", "stone", "forest", "mountain", "river", "sea", "north", "south",
    "east", "west", "home", "land", "city", "town", "village", "castle", "tower", "throne",
    "brother", "sister", "mother", "father", "son", "daughter", "child", "children", "family",
    "enemy", "enemies", "ally", "allies", "hero", "villain", "monster", "beast", "dragon",
    "demon", "angel", "priest", "warrior", "mage", "hunter", "rogue", "paladin", "shaman",
    "druid", "warlock", "deathknight", "northrend", "azeroth", "stormwind", "orgrimmar",
    "ironforge", "darnassus", "undercity", "thunderbluff", "silvermoon", "exodar", "lorderon",
    "arathor", "alliance", "horde", "lok", "tar", "regards", "greetings", "farewell",
    -- casual chat
    "shut", "yeah", "yep", "yup", "nope", "nah", "ok", "okay", "lol", "omg", "wtf", "um", "uh",
    "hmm", "hm", "bro", "dude", "guys", "stuff", "gonna", "wanna", "gotta", "kinda", "idk",
    "dunno", "maybe", "sure", "random", "rand", "forgot", "forgotten", "remember", "try", "tried",
    "again", "working", "work", "works", "broke", "broken", "fix", "test", "testing", "enable",
    "disable", "auto", "translate", "speak", "speaking", "understand", "learn", "learned",
    "mean", "meant", "guess", "suppose", "really", "actually", "probably", "definitely",
    "something", "anything", "nothing", "everything", "someone", "everyone", "gosh", "dumb",
    "stupid", "crap", "damn", "hell", "ass", "lmao", "rofl", "brb", "afk", "sec", "min",
    "mins", "minute", "minutes", "second", "seconds", "today", "tomorrow", "yesterday",
    "guy", "girl", "man", "woman", "boy", "boys", "miss", "mister", "sir", "maam", "please",
    "help", "helped", "show", "showed", "look", "looked", "looking", "saw", "seen", "heard",
    "hear", "hearing", "talk", "talking", "talked", "ask", "asked", "reply", "replied",
    "answer", "answered", "send", "sent", "get", "got", "getting", "give", "gave", "take",
    "took", "put", "keep", "kept", "leave", "left", "stay", "stayed", "move", "moved",
    "start", "started", "stop", "stopped", "open", "opened", "close", "closed", "use",
    "used", "using", "buy", "bought", "sell", "sold", "pay", "paid", "lose", "lost",
    "win", "won", "fight", "fought", "hit", "hurt", "die", "died", "dead", "alive",
    "live", "lived", "real", "fake", "true", "false", "wrong", "right", "bad", "nice",
    "cool", "awesome", "great", "fine", "well", "sick", "weird", "strange", "funny",
    "happy", "sad", "angry", "mad", "scared", "afraid", "worry", "worried", "care",
    "cared", "love", "loved", "hate", "hated", "like", "liked", "dislike", "want",
    "wanted", "need", "needed", "wish", "wished", "hope", "hoped", "believe", "believed",
    "agree", "agreed", "disagree", "plan", "planned", "idea", "ideas", "problem",
    "problems", "question", "questions", "reason", "reasons", "story", "stories",
    "name", "named", "call", "called", "spell", "spells", "cast", "casting", "level",
    "levels", "class", "classes", "race", "races", "item", "items", "gear", "gold",
    "silver", "copper", "money", "cost", "costs", "price", "prices", "free", "new",
    "old", "young", "big", "small", "large", "little", "long", "short", "high", "low",
    "fast", "slow", "hard", "easy", "simple", "clear", "done", "ready", "wait", "waiting",
    "let", "lets", "allow", "allowed", "forbid", "forbidden", "must", "cant", "cannot",
    "wont", "will", "would", "could", "should", "shall", "may", "might",
}

local function addReverseEntry(langId, outputLower, sourceLower)
    local map = REVERSE[langId]
    if not map then
        map = {}
        REVERSE[langId] = map
    end
    local existing = map[outputLower]
    if not existing then
        map[outputLower] = sourceLower
    elseif type(existing) == "string" then
        if existing ~= sourceLower then
            map[outputLower] = { existing, sourceLower }
        end
    else
        local found = false
        for i = 1, #existing do
            if existing[i] == sourceLower then found = true break end
        end
        if not found then
            existing[#existing + 1] = sourceLower
        end
    end
end

local function rememberTranslation(langId, sourceWord, outputWord)
    local outputLower = strlower(outputWord)
    local sourceLower = strlower(sourceWord)
    addReverseEntry(langId, outputLower, sourceLower)
    local entry = REVERSE[langId] and REVERSE[langId][outputLower]
    if type(entry) == "table" then
        for i = 1, #entry do
            if entry[i] == sourceLower then
                table.remove(entry, i)
                table.insert(entry, 1, sourceLower)
                break
            end
        end
    end
end

local function buildReverseMaps(forwardFn)
    for i = 1, #LANGUAGE_ORDER do
        local langId = LANGUAGE_ORDER[i]
        for j = 1, #COMMON_WORDS do
            local word = COMMON_WORDS[j]
            local out = forwardFn(word, langId)
            rememberTranslation(langId, word, out)
        end
    end
end

local function wordFrequencyScore(lower)
    for i = 1, #COMMON_WORDS do
        if COMMON_WORDS[i] == lower then return i end
    end
    return 5000 + #lower
end

local origTranslateWord = Language.TranslateWord
buildReverseMaps(origTranslateWord)

local function sortReverseCollisions()
    for _, map in pairs(REVERSE) do
        for _, entry in pairs(map) do
            if type(entry) == "table" then
                table.sort(entry, function(a, b)
                    return wordFrequencyScore(a) < wordFrequencyScore(b)
                end)
            end
        end
    end
end
sortReverseCollisions()

local function getMappedCandidates(outputWord, langId)
    local lower = strlower(outputWord)
    local list = {}
    local seen = {}

    local function add(src)
        local srcLower = strlower(src)
        if seen[srcLower] then return end
        if strlower(origTranslateWord(srcLower, langId)) ~= lower then return end
        seen[srcLower] = true
        list[#list + 1] = srcLower
    end

    local map = REVERSE[langId]
    if map then
        local entry = map[lower]
        if type(entry) == "string" then
            add(entry)
        elseif entry then
            for k = 1, #entry do
                add(entry[k])
            end
        end
    end

    for j = 1, #COMMON_WORDS do
        add(COMMON_WORDS[j])
    end

    table.sort(list, function(a, b)
        local function priority(src)
            local score = wordFrequencyScore(src)
            local entry = REVERSE[langId] and REVERSE[langId][lower]
            if type(entry) == "table" then
                for i = 1, #entry do
                    if entry[i] == src then return score - i * 10000 end
                end
            elseif entry == src then
                return score - 10000
            end
            return score
        end
        return priority(a) < priority(b)
    end)

    return list
end

local function findSourceWord(outputWord, langId)
    local mapped = getMappedCandidates(outputWord, langId)
    return mapped[1]
end

function Language.DecodeWord(word, langId)
    local source = findSourceWord(word, langId)
    if not source then return word end
    if strlower(origTranslateWord(source, langId)) ~= strlower(word) then return word end
    return applyCase(word, source)
end

function Language.DecodeText(text, langId)
    if not text or text == "" then return text end
    local decoded = Language.TryDecode(text, langId)
    return decoded or text
end

-- Returns decoded text and inferred speaker strength (0-100), or nil if not decodable.
-- Decoding uses cached encode mappings (local speech + addon sync from other ToA users).
-- The Blizzard parser has hash collisions, so word-guessing decode is not reliable.
function Language.TryDecode(text, langId, hintStrength)
    if not text or text == "" then return nil end

    local cached = ENCODE_CACHE[langId] and ENCODE_CACHE[langId][text]
    if cached then
        if not hintStrength or cached.strength == hintStrength then
            return cached.english, cached.strength
        end
    end

    return nil
end

function Language.ImportDecodePayload(payload, sender)
    if not payload or payload == "" then return end
    local sep = "\001"
    local langId, strengthStr, english, encoded = payload:match(
        "^(.-)" .. sep .. "(%d+)" .. sep .. "(.-)" .. sep .. "(.*)$")
    if not langId or not Language.IsValid(langId) or not english or not encoded then return end
    local strength = tonumber(strengthStr) or 100
    local bucket = ENCODE_CACHE[langId]
    if not bucket then
        bucket = {}
        ENCODE_CACHE[langId] = bucket
    end
    bucket[encoded] = { english = english, strength = strength }
end

-- Grow reverse maps from outgoing speech at runtime.
function Language.TranslateWord(word, langId)
    local result = origTranslateWord(word, langId)
    if result and result ~= word then
        rememberTranslation(langId or Language.DEFAULT, word, result)
    end
    return result
end

return Language
