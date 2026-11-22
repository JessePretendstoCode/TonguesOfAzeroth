local ADDON, ns = ...
local Compat = ns.Compat

--[[---------------------------------------------------------------------------
    Walkups: your character thinking out loud, as a hook for anyone nearby.

    In RP a walkup is approaching someone with no OOC arrangement, and the
    advice is always the same -- "Hi" goes nowhere, a hook goes somewhere.
    So these lines are musings, not greetings: each should leave a passer-by
    something to ask about.

    One walkup is one thought, drawn from one of three lists: your race's,
    your class's, or the lines written for that exact pairing, where a dwarf
    shaman's clans argue and the spirits weigh in. Lines are never joined.
    That was tried, and two halves written apart read as two trains of
    thought smashed together. A pairing nobody has written for yet still
    has its race and class lines to draw on.

    It is only ever sent from a click, a keybind or a macro. SAY needs a
    hardware event on every client, so there is no timer here and must not
    be one; nor may a line wait for some later keypress to ride out on.
    The player picks the moment, so nothing here looks for who is nearby.

    A line that leans on a later expansion carries that era (CATA "..."),
    and is left out while the player's chosen era is earlier: a dwarf on a
    Classic-era world has no burst dam to mourn. Untagged means "from the
    start", and the start is the race's or class's own debut -- a worgen's
    lines are Cataclysm lore, but a worgen existing at all says as much.
-----------------------------------------------------------------------------]]

local Walkup = {}
ns.Walkup = Walkup

Walkup.PAIR_CHANCE = 0.5    -- how often a pairing's own line is chosen, when it has any

-- In release order; a line's era is an index into this.
Walkup.ERAS = {
    "Classic", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm",
    "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
    "Shadowlands", "Dragonflight", "The War Within", "Midnight",
}

local function since(era)
    return function(text) return { text = text, era = era } end
end
local WRATH, CATA, MISTS, LEGION, BFA = since(3), since(4), since(5), since(7), since(8)

-- Keyed by UnitRace's second return, the client's file string.
Walkup.RACES = {
    Dwarf = {
        "Haven't seen a proper mountain in weeks. These hills are just ambitious lumps.",
        "Ironforge ale spoils you. Everything else tastes like it was brewed in a boot.",
        "Every stone out here has a story. Most of them are about being stepped on.",
        "Somebody's forge is running too hot. I can smell it from here.",
        "My grandsire swore the Titans made us from stone. Some days I feel it in my knees.",
        "Bronzebeard, Wildhammer, Dark Iron. Three clans, and still one argument about who started it.",
        "Dun Morogh snow gets into your beard and stays there until summer.",
        "Too many days since I last slept under a good stone ceiling.",
        "Folk up here build with wood. Wood! It burns, it rots, and it creaks all night.",
        "There's an old dig site near here, I'd wager. The ground has that hollow sound to it.",
        "Hard to trust a sky with nothing holding it up.",
        "I'd trade my good boots for one more night at the Thunderbrew bar.",
    },
    Human = {
        CATA "Stormwind's been rebuilt twice in my lifetime. I keep wondering what the third time will cost.",
        "My grandmother still won't say Lordaeron out loud. She says the name brings the cold with it.",
        "Elwynn's farmers say the wolves are bolder this year. Nobody's asked the wolves why.",
        "Every human I know has a cousin in the Defias, or a cousin who swears they don't.",
        "The Cathedral bells rang at the wrong hour this morning. Nobody's told me why yet.",
        "Strange to think we were the young ones once, and now everyone looks to us to hold things together.",
        "I heard the stonemasons never did get paid for the first Stormwind. Some debts outlive kingdoms.",
        "Westfall bread tastes of dust these days. Bad harvest, or something worse.",
        "There's a ballad about Lordaeron I can only ever remember the first verse of.",
        "Funny how quickly a farm boy becomes a soldier once the war drums start.",
        "Every tavern in Stormwind has its own story about the Second War, and every teller was there.",
        "We don't live as long as the elves, so we try to make more noise while we're here.",
    },
    NightElf = {
        "Ten thousand years, and the trees still remember things I've tried very hard to forget.",
        "I miss the old night. The stars burned brighter before the Well was lost.",
        "The younger races measure time in seasons. I measure it in which forests are still standing.",
        "Elune's light falls differently here. Thinner, somehow, like it has further to travel.",
        BFA "Teldrassil's roots used to hum at night. I've not heard anything like it since.",
        "The Highborne thought they were the wisest of us. Look how that turned out.",
        "Every owl in this wood has been watching me. I think they're waiting for me to say something worthwhile.",
        "Humans build in stone so they'll be remembered. We planted trees, and the trees remember for us.",
        "I've outlived three of my favourite songs, and the taverns that sang them.",
        "Something in this wood is grieving. You can hear it in the way the leaves move.",
        "A sentinel's watch never truly ends. You just learn to stand it in other places.",
        "My mother fought at the Well of Eternity. She still won't tell me which side she started on.",
    },
    Gnome = {
        "Gnomeregan's still down there, humming. Some nights I swear my old workbench is calling me.",
        "I've got a pocketful of sprockets and absolutely no memory of where they came from.",
        "Everyone looks down at gnomes. It gives us an excellent view of their bootlaces.",
        "Sixty percent of my inventions work first time. The other half just need a bigger spring.",
        "Mekkatorque says we'll take the city back any year now. He's been saying it for years.",
        "I recalibrated my goggles this morning, and now everything looks slightly more exciting.",
        "There's a leak in a radiation seal somewhere near here. Or that's just my lunch.",
        "Tall folk always think gnomes are cute, right up until we start explaining the theory.",
        "I keep a spare cog in each boot. You never know when the world needs a little adjustment.",
        "Ironforge lent us a district after Gnomeregan fell, and they've never once let us forget it.",
        "Somebody nearby has a badly balanced flywheel. I can hear it wobbling.",
        "If it ticks, I can fix it. If it explodes, I can fix it faster.",
    },
    Draenei = {
        "The Exodar still smells of the stars, if you know what to sniff for.",
        "Twenty-five thousand years running from the Legion, and this world is where we finally stopped.",
        "The Naaru's light is warm here. Warmer than it was on Argus, before the end.",
        "I've seen two worlds fall. I'd like very much for this one to be the exception.",
        "My hooves never quite agree with cobblestones. Grass, though, grass I could get used to.",
        "The children born on this world have never seen the stars from the other side. I envy them.",
        "Prophet Velen sees further than any of us. Some nights I wonder what he sees and doesn't say.",
        "Draenor was beautiful, before the orcs. I try to remember it the way it was.",
        "The crystals still sing faintly, if you hold them to your ear. Most people never think to try.",
        "The eredar had a saying about patience. It lost something when the eredar themselves forgot it.",
        "Azeroth's moons are lovely. Two is a very respectable number of moons.",
        "I lost count of my birthdays somewhere around the eleventh millennium. Nobody's offered to help.",
    },
    Worgen = {
        "The Wall kept the world out of Gilneas for years. Turns out it kept the curse in as well.",
        "There's a moment, just before the change, when every scent in the world comes rushing in at once.",
        "My mother still lays out the good silver, as if Gilneas City were waiting for us to come home.",
        "The rain here is too warm. Gilnean rain has the decency to chill you to the bone.",
        "I can smell three dogs, a wet cat and a lie somewhere in this crowd.",
        "Folk give me a wide berth when the moon's full. I've stopped telling them it makes no difference.",
        "Genn Greymane taught us all how to hold a grudge. Some of us were already very good at it.",
        "Tea's the one thing that tastes the same in either shape. Thank the Light for that.",
        "The wolf in me wants to run. The rest of me wants a proper chair and a newspaper.",
        "Half of Gilneas thinks the curse was a punishment. The other half thinks it was a gift.",
        "I still check the hedgerows for Forsaken. Old habits from a short, bad war.",
        "Nobody warns you how much a worgen's coat sheds in summer.",
    },
    Pandaren = {
        "The turtle I grew up on had very particular opinions about the weather.",
        "A good meal fixes most problems. A good nap fixes the rest.",
        "My grandfather walked to the edge of the world once. He said the view was fine, but the noodles were better.",
        "The mists hid our home for ten thousand years. Some days I think we were the lucky ones.",
        "The Tushui say patience, the Huojin say action. I say lunch, and both of them agree.",
        "There's a brewing contest coming up, and I have a very strange plan involving peaches.",
        "Everything outside the mists moves so fast. Does nobody here drink their tea while it's warm?",
        "I keep a little jar of road dust from every place I've walked. It's getting to be a lot of jars.",
        "Somebody here has carried their anger a long while. In Pandaria, we'd worry about that.",
        "My belly says it's been too long since breakfast. My belly is usually right.",
        "The old masters say balance is found, not made. I'm still looking under the furniture.",
        "I've never met a barrel I couldn't empty, or a staff I couldn't hit something with.",
    },
    Orc = {
        "The blood curse is gone, but I still see red some nights, just for a moment.",
        "My grandsire drank from Mannoroth's cup. I spend my life trying to deserve a cleaner name.",
        "Durotar's dust gets into everything. Even my dreams taste of it.",
        "Lok'tar is easy to shout. Living up to it is the hard part.",
        "Orgrimmar never sleeps. Somebody is always forging, feasting or fighting.",
        "Draenor was green once, my elders say. I've only ever known red earth.",
        "The internment camps broke a lot of good orcs. Thrall put most of us back together.",
        "There is honor in a fair fight. There is more honor in knowing when not to start one.",
        "My clan's old banner hangs in a human museum, last I heard. Someday I'll go and take it back.",
        "Every scar I carry has a name. Some of them are the names of friends.",
        "A warrior who never doubts is a warrior who never listens. My mother taught me that with a shield.",
        "The wolves here are smaller than Draenor's, but they have twice the opinions.",
    },
    Scourge = {
        "I don't sleep any more. I just stand very still and think about everything I used to be.",
        "Someone asked me what death felt like. I told them it was much like a Tuesday, only colder.",
        "My old house still stands in Tirisfal. Another family lives there, and they never look up.",
        "I can't taste much any more, but I remember that apples used to be wonderful.",
        "The living keep staring at my jaw. It's attached. Mostly.",
        "Sylvanas gave us our will back. I still haven't decided what to do with mine.",
        "I had a name before the Plague. I wrote it down so I wouldn't lose it.",
        "Brill's always been grey. Even when I was alive, I think it was grey.",
        "Being dead taught me patience. Being Forsaken taught me grudges.",
        "People ask if I miss the Light. It's more that the Light misses me, and pretends it doesn't.",
        "My heart stopped years ago, and somehow it still finds ways to ache.",
        "The Undercity has rats the size of hounds. Somebody down there is breeding them, I'm sure of it.",
    },
    Tauren = {
        "The Earth Mother hums beneath every step, if you walk slowly enough to hear her.",
        "Thunder Bluff's winds can knock a kodo off its feet. You learn to lean.",
        "My grandmother remembers when the centaur drove us from plain to plain.",
        "The plains are wider than any city, and they never once asked me to duck through a doorway.",
        "The orcs taught us to hold our ground. We taught them to listen to it.",
        CATA "Cairne used to say a tribe is only as strong as its quietest member.",
        "These shoes the city folk wear look like a punishment.",
        "A kodo never forgets a kindness. I try to live by that, though my memory is shorter.",
        "The sun rises the same here as over Mulgore, but here it seems to be in a hurry.",
        "Someone's cooking with far too much sage. The ancestors would frown at that.",
        "I carved a totem when I came of age. It still watches over the hearth I left behind.",
        "Stand still long enough in a field and the grass starts telling you who passed by.",
    },
    Troll = {
        "The loa are watching this place. They always are, but today they're watching closer.",
        "My people ruled empires when the elves were still learning to stand. We remember, even if nobody else does.",
        "The Echo Isles had the best fishing in the world. Then Zalazane happened.",
        "Every jungle has a loa. You just have to know which offerings make it laugh.",
        "Vol'jin said the Darkspear don't kneel. I've never once seen one of us try it.",
        "Healing fast is a fine gift, but it doesn't make the first cut hurt any less.",
        "The old spirits of the jungle whisper in the vines. You learn to whisper back, politely.",
        "Somebody here smells of a hex. Not a bad hex, mind. Just a careless one.",
        "The Gurubashi built temples that reached the sky. Now monkeys nest in them.",
        "I've got a necklace of teeth, and only half are from things that tried to eat me.",
        CATA "Bwonsamdi takes his cut of every soul eventually. I'd rather keep him waiting.",
        "Tusks get in the way when you drink. Nobody tells you that when you're young.",
    },
    BloodElf = {
        "Silvermoon is still beautiful, if you don't look east of the river.",
        "We lived on the Sunwell's light for ages. You can't imagine how quiet the world sounded without it.",
        "Everyone stares at elven eyes. Mine were green for a while, and some folk still look for it.",
        "The magistrix keeps a list of everyone who's ever disappointed her. I'm told I'm on page four.",
        "Arthas walked right through Quel'Thalas. I still find his footprints in my nightmares.",
        "Every broom in Silvermoon sweeps itself. I'd forgotten how to hold one until I left.",
        "The Dead Scar runs straight through our homeland. We built around it, the way you build around a grave.",
        "Humans age so quickly. I've met three generations of the same family at the same inn.",
        "The Horde is hardly what our grandparents had in mind, but they came when we needed them.",
        "I miss the smell of Eversong. Cinnamon and summer, and something you'll never quite place.",
        "Magic is a thirst. Some of us drink politely, and some of us drown.",
        "Kael'thas was a prince, once. I'd rather remember that version of him.",
    },
    Goblin = {
        "Everything's got a price. The trick is knowing who's paying it.",
        "Kezan blew up, my savings blew up, and I'm still the most optimistic person on this street.",
        "I'm putting together a little venture. Nothing illegal. Mostly nothing illegal.",
        "Gallywix owes me eleven gold and an apology. I'll take the gold first.",
        "Smell that? That's opportunity, or somebody's engine is on fire.",
        "My cousin sells insurance against dragon attacks. Business has never been better.",
        "Explosions are always more fun when someone else is paying for them.",
        "The Steamwheedle Cartel has a stall in every port. Nobody's ever seen who actually runs it.",
        "Time is money, and I've already wasted at least four copper standing here.",
        "Kaja'Cola gives you ideas. Usually terrible ones, but ideas.",
        "I've been blown up nine times. You get a real feel for which way to dive.",
        "Everyone thinks goblins are greedy. We're just honest about it.",
    },
    VoidElf = {
        "The whispers are louder near water. Nobody's ever been able to tell me why.",
        "We were exiled for asking questions. The answers turned out to be worse than the exile.",
        "Telogrus Rift is beautiful, if you like your sky without a single star in it.",
        "Alleria says the Void can be mastered. She also talks to things none of us can see.",
        "Some mornings my reflection blinks a little after I do.",
        "Silvermoon called us traitors. Stormwind calls us allies. I'm still deciding what I call myself.",
        "The shadows here are thin. They barely have anything to say.",
        "I keep a candle burning at night. Not for the light, but so I know which shadows are mine.",
        "Every thought I have seems to echo, somewhere just behind my ears.",
        "We named ourselves children of the void. We were in a dramatic mood that year.",
        "There's a hunger under everything. Most people never notice it, which is a mercy.",
        "I used to be afraid of the dark. Now the dark is a little afraid of me.",
    },
    LightforgedDraenei = {
        "The Light burned through me on the Vindicaar. Some days I still feel it under my skin.",
        "Thousands of years fighting the Legion, and now I don't know what to do with my mornings.",
        "Argus is a scar in the sky. I still look for it every night.",
        "Turalyon fought beside us for a thousand years. He still doesn't know how to make tea.",
        "Lightforging leaves you certain of a great many things. It's uncertainty I've had to learn.",
        "Every peace feels like a pause between battles. I'm told that isn't normal.",
        "The Army of the Light never rested. I'm discovering I quite enjoy sleep.",
        "My armor still glows in the dark. It makes sneaking up on anyone quite impossible.",
        "We spent a millennium in the Twisting Nether. Azeroth's weather is very novel.",
        "Xe'ra gave us purpose. Some of us are still angry about how she gave it.",
        "The Light doesn't whisper. It insists. You learn to tell the difference.",
        "I keep expecting demons around every corner. So far, only taverns.",
    },
    DarkIronDwarf = {
        "Shadowforge City was a fine place, before Ragnaros moved in downstairs.",
        "Bronzebeards still look at us sideways. Fair enough, after what our grandsires did.",
        "Moira says we're one people again. Moira says a lot of things, and most of them stick.",
        "There's lava in my blood, or near enough. Cold weather is wasted on me.",
        "Blackrock Mountain still rumbles in my dreams. Home's like that, even a burning one.",
        "Thaurissan summoned a Firelord and lost a kingdom. We tell that one to children, as a warning.",
        "My forge runs hotter than any in Ironforge. Ask anyone there, they'll grumble about it.",
        "We lost the War of the Three Hammers, and spent centuries making sure nobody forgot it.",
        "A Dark Iron doesn't say sorry. We build you something nice and leave it on your doorstep.",
        "Fire takes and fire forges. Most folk only ever see the taking.",
        "I can smell sulfur from a mile off. Handy, in some company.",
        "The Twilight's Hammer tried to recruit me once. I sent them back with a few hammers of my own.",
    },
    KulTiran = {
        "The sea gives, and the sea takes. Mostly it takes, if I'm honest.",
        "Boralus harbor smells of salt and tar and fish. I've never smelled anything finer.",
        "The Proudmoores have ruled the waves for generations. Some of them even deserved it.",
        "Drustvar's witches still frighten me, and I'm twice the size of most of them.",
        "A Kul Tiran never trusts calm water. That's only the sea thinking.",
        "My grandfather sailed with Daelin. He never once talked about Theramore.",
        "Every tide in Tiragarde has a name. Most of them are rude.",
        "Folk on land walk like they've never once had a deck move under them.",
        "The tidesages say the sea has a voice. I say it mostly just shouts.",
        "I've tied every knot there is. A few I'm fairly sure I invented.",
        "There's nothing like a storm at sea to make you feel very small and very alive.",
        "Stormsong Valley grows the best barley in the world. Kul Tiran ale is the proof.",
    },
    Mechagnome = {
        "I replaced my left knee with a gyroscope. Best decision I ever made, and I've made several.",
        "Mechagon was built by a king who thought flesh was a flaw. He wasn't entirely wrong.",
        "Every morning I oil my joints and wonder which parts of me are still original.",
        "Gelbin Mekkatorque calls us cousins. I'm still running the diagnostics on that.",
        "I can hear the gears in this place. They need tuning, all of them.",
        "The rust storms on Mechagon could strip paint off a mountain. I miss them a little.",
        "Somebody nearby has a power cell about to go. Shall I tell them, or wait for the bang?",
        "Flesh heals, but slowly. Steel just gets replaced. I find that very relaxing.",
        "My grandmother was half clockwork. She ticked when she laughed.",
        "Organic food remains a puzzle. I eat it mostly out of politeness.",
        "There's a junkyard on Mechagon taller than Stormwind's walls. I grew up climbing it.",
        "Upgrades are a lifestyle. I'm on version four of my left hand.",
    },
    Nightborne = {
        "Ten thousand years under a dome, and the first thing I learned outside was that rain is wet.",
        "The Nightwell sustained us for millennia. I still reach for it some mornings, out of habit.",
        "Suramar was the jewel of the world. It still is, if you squint past the scars.",
        "Arcwine was the finest drink ever made. Everything else tastes rather bland.",
        "Elisande made a choice for all of us. I've never decided whether to thank her or curse her.",
        "The withered still haunt the edges of the city. Some of them were my friends.",
        "The stars move strangely here, as if they've wandered off without telling anyone.",
        "I spent a hundred centuries at the same masquerade. Surprisingly few guests ever left.",
        "Mana hunger is like thirst, only in every part of you at once.",
        "The Horde took us in when nobody else would. I'm still learning their table manners.",
        "Ten thousand years of peace, and in a single year we lost nearly everything.",
        "Magic isn't a tool. It's a sense, like smell. Most of you are walking around without it.",
    },
    HighmountainTauren = {
        "The mountain stands, and so do we. That's the oldest thing my tribe ever taught me.",
        "Huln's spear is still on Highmountain. I touched it once, when nobody was looking.",
        "Moose are noble creatures. They're also enormous idiots, and I love them dearly.",
        "The drogbar used to be our neighbors. Now they're still our neighbors, only angrier.",
        "Thunder Totem sits so high the clouds pass under it. You learn not to look down.",
        "Our cousins in Mulgore talk of plains. I try to imagine all that flat ground and get dizzy.",
        "Every tribe on the mountain carves its own totem. Ours is the tallest, though nobody admits it.",
        "The eagles carry messages between the peaks. Some of them read them first, I'm sure.",
        "I've climbed every cliff on Highmountain. I've also fallen off most of them.",
        "The Earth Mother sleeps deeper under the mountain. You have to knock harder.",
        "Snow up there is so quiet you can hear your own heart. I miss that.",
        "Highmountain survived a thousand storms by standing together. That's harder than it sounds.",
    },
    MagharOrc = {
        "My people never drank the blood. I'm still trying to understand the ones who did.",
        "Draenor's sky was red when I was born, and it never looked wrong to me.",
        "Garrosh came to our world and tried to make us his. We remember that.",
        "The Iron Horde called us weak. We called them a lesson.",
        "Azeroth's orcs are greener than I expected. Like a fruit not quite ripe.",
        "Grommash taught the Mag'har never to bow. He learned it the hard way himself.",
        "Nagrand's winds carry spirits. Here they carry gossip.",
        "My clan rode wolves before anyone forged iron. Our wolves still think they're in charge.",
        "I came through the Dark Portal looking for family. I found cousins, and a great many questions.",
        "The Frostwolves sing to the mountain. It never sings back, but it listens.",
        "Every warrior I respect has lost at least once. The ones who never lost never tried.",
        "Azeroth tastes different. The water, the meat, even the air.",
    },
    ZandalariTroll = {
        "The Zandalari ruled before your ancestors had a word for ruling. We are patient about it.",
        "Dazar'alor's golden pyramid can be seen from the sea. That was very much the point.",
        "Rastakhan's crown passed to Talanji. She wears it heavier than he did.",
        "Every loa has a price. The wise ones ask what it is before they kneel.",
        "Our histories go back further than the elves'. We just kept the good parts.",
        "A pterrordax can carry a grown troll. It also complains about it the entire way.",
        "Zuldazar's jungles hide temples older than any kingdom on your maps.",
        "Gonk, Pa'ku, Kimbul. I've prayed to all of them, and none answer the same way twice.",
        "Sea and stone and sun. Everything good in Zuldazar comes from those three.",
        "Other trolls call us proud. We call it remembering accurately.",
        "Bwonsamdi made a deal with my queen. I still don't know which of them got the better of it.",
        "There are blood trolls in Nazmir who still bleed for G'huun. Never follow a stranger into that swamp.",
    },
    Vulpera = {
        "Our caravan has crossed Vol'dun more times than I can count. The sand still isn't bored of us.",
        "Every vulpera has a pack full of things they might need. Most of it is string.",
        "I can hear a beetle sneeze at fifty paces. You learn that, out in the dunes.",
        "The sethrak chased us across half the desert. We still won't eat snake, on principle.",
        "Home is wherever the wagon stops. Right now that's wherever I've left my bedroll.",
        "People think we're cute. We find that very useful at the market.",
        "The old temples in the desert are full of things that bite. Also some very good scrap.",
        "Never trust a camel that smiles. Ask any vulpera, we've all learned that one.",
        "The stars over Vol'dun are the finest map in the world, if you know how to read them.",
        "Big folk keep stepping on my tail. I've started charging them a toll.",
        "Somebody's dropped a coin around here. My ears never lie.",
        "My grandmother can bake bread in a dune with nothing but sunlight and stubbornness.",
    },
    Dracthyr = {
        "I woke in a hidden aerie after ten thousand years. The world had changed rather a lot.",
        "Neltharion made us to be his soldiers. We've decided to be something else.",
        "Wearing two shapes is strange. My visage always wants to sit up straighter.",
        "The Dragon Isles feel like home, though I've only been there a short while.",
        "Wrathion keeps calling me sibling. I'm not sure I ever agreed to that.",
        "Every flight's essence flows through us. Some days that's a lot of opinions at once.",
        "Scalecommander Emberthal says discipline first. I say breakfast first, quietly.",
        "My wings are too small to carry me far. I glide. It's undignified, but quick.",
        "The Forbidden Reach held us like a held breath. It's good to exhale.",
        "Some of us remember what Neltharion became. Most of us would rather not.",
        "Humans flinch when I take this shape. Elves flinch when I take the other one.",
        "I breathe fire when I sneeze. It's been socially complicated.",
    },
    EarthenDwarf = {
        "I was made from stone in the deeps of Khaz Algar. Sunlight is still a novelty.",
        "The machine speakers want us to be what the Titans intended. I'd rather decide that myself.",
        "Dornogal sits on the surface now. Some of the old earthen still refuse to climb the stairs.",
        "Food is a strange idea. We never needed it, and now I can't stop thinking about cheese.",
        "I'm told the Bronzebeards are my distant cousins. They drink a great deal more than I do.",
        "The edicts said obey. Thinking for myself has been the hardest work I've ever done.",
        "Underground, every sound has a shape. Out here it all just drifts away.",
        "Some of my kin slept for ages in the stone. They wake up with very strong opinions.",
        "The nerubians below never sleep. That's what keeps me awake.",
        "My skin's granite. My temper's limestone, worn down by patient water.",
        "We were made to guard. Nobody ever told us what to do once the guarding was done.",
        "I counted every stair in the Ringing Deeps once. I lost count at fourteen thousand.",
    },
    Harronir = {
        "Harandar's roots run deeper than any mountain. I can still feel them under every step.",
        "Above ground the sky is so large it feels like falling upward.",
        "My people kept to the deep places longer than anyone remembers. Now everyone wants to know why.",
        "The roots carry songs from far away. Here the ground is quiet, and that worries me.",
        "Every plant up here grows toward the sun. Ours grew toward each other.",
        "Surface folk talk so loudly. Below, a whisper carries for miles.",
        "I keep a seed from home in my pocket. It hasn't sprouted yet, but it's thinking about it.",
        "Daylight without glowing moss feels harsh. My eyes are still learning it.",
        "We kept the roots. Someone has to remember what holds the world together.",
        "Rain is the strangest thing. Water falling from nowhere, and nobody here thinks it odd.",
        "The old stories say Azeroth dreams through her roots. Some nights I swear I hear her.",
        "Strangers keep asking if I'm part tree. I keep asking them if they're part rock.",
    },
}
-- The same people under a second token: the race's own name, or a linked form.
Walkup.RACES.Haranir = Walkup.RACES.Harronir
Walkup.RACES.Earthen = Walkup.RACES.EarthenDwarf

-- Keyed by UnitClass's second return, the upper-case class token.
Walkup.CLASSES = {
    SHAMAN = {
        "The earth's restless today. Something's stirring under our feet.",
        "Wind's carrying news from the east. I can't make all of it out yet.",
        "Fire keeps its own counsel. Ask it a question and it answers with heat.",
        "The spirits are quiet here. Too quiet, if you ask me.",
        "Water remembers every hand that's touched it. This place has seen a lot of hands.",
        "I left an offering at the last shrine. Something took it, and it wasn't an animal.",
        "The elements don't serve anyone. You ask, and sometimes they agree.",
        "My totems have been humming all morning. I wish I knew what about.",
        "There's a storm coming. Not today, but the air already knows.",
        "The ancestors walk close in places like this. Mind where you step.",
        CATA "The Earthen Ring says the world's wounds are still healing. Some days I believe them.",
        "Even a pebble has a spirit, if you listen long enough. Most just want to be left alone.",
    },
    WARRIOR = {
        "My shield arm aches whenever it's about to rain. Best weather warning I've ever had.",
        "Every fight teaches you something. The lesson's usually where you should have stepped.",
        "I've broken three swords this season. The smith has started calling me by name.",
        "A warrior's only as good as the one beside them. I've stood beside some very good ones.",
        "There's a rhythm to a battle, if you live long enough to hear it.",
        "Somebody once asked me why I fight. I said I'd let them know when I work it out.",
        "Plate armor in summer is a test of character. I'm failing it today.",
        "I learned to fight before I learned to read. I'm still not sure I chose the right order.",
        "The trick isn't hitting hard. It's getting up after you've been hit harder.",
        "Old soldiers never die. They just get worse knees and better stories.",
        "Every scar is a lesson. I'm very well educated.",
        "A good battle cry should make the enemy hesitate and your friends laugh.",
    },
    PALADIN = {
        "The Light doesn't always answer when I call. But it's never once left when I needed it.",
        "Uther said a paladin's strength is in what they protect. I think about that every morning.",
        "My hammer is heavy, but the oath I swore is heavier.",
        "Some days faith is a fire. Other days it's just the decision to keep walking.",
        LEGION "The Silver Hand has broken and reformed so many times. It always comes back together.",
        "Polishing plate is a meditation, they told me. They lied. It's just polishing.",
        "Mercy is harder than justice. Anyone can swing a hammer.",
        "I've seen the Light heal a wound I thought was fatal. I've also seen it decline to.",
        "The undead always seem to know where I'm standing. I glow a little too brightly, I think.",
        "There's a prayer for every hour of the day. I mostly use the one for patience.",
        "Not every paladin is a saint. Some of us are just stubborn in the right direction.",
        "When I lay hands on someone, I feel their pain for a moment. Nobody ever thanks you for that part.",
    },
    HUNTER = {
        "The tracks here are fresh. Something big came through last night and didn't stop.",
        "My companion has better instincts than I do. I mostly follow and pretend I knew.",
        "Wind's from the north. Everything downwind of us knows exactly where we are.",
        "The best shot is the one you never have to take.",
        "My pet ate my lunch again. I'm starting to think it's a strategy.",
        "Wild things don't hate you. They just don't care, which is worse.",
        "The birds have gone quiet. Something's moving out there.",
        "Every bow has a temper. Mine prefers cold mornings and dislikes rain.",
        "I tracked a wolf for three days once. Turned out it was tracking me.",
        "Out in the wild, you learn to sleep with one ear open.",
        "A good arrow costs a copper. A bad one costs you dinner.",
        "My beast and I don't speak the same language, but we argue just the same.",
    },
    ROGUE = {
        "Funny how nobody ever looks up. Rooftops are the quietest roads in any city.",
        "I'm not saying I know who took the guard captain's boots. I'm saying they fit me nicely.",
        "Every lock has a story. Most of them are about someone who thought it was enough.",
        "The best secrets are the ones people tell you without noticing.",
        "There's a door around here nobody's opened in years. I'd like to know why.",
        "Coin weighs nothing, if you carry it properly.",
        "SI:7 and Ravenholdt both think I owe them. They're both right, technically.",
        "A shadow's only a shadow until somebody steps into it.",
        "I never carry fewer than four knives. Three is how you end up in a story.",
        "The trick to a crowd is walking like you belong in it.",
        "Somebody on this street has been watching me for an hour. I've been watching them for two.",
        "Poison's an art form. Most folk only ever see the last brushstroke.",
    },
    PRIEST = {
        "Everyone carries something heavy. Some of us just have better posture about it.",
        "The Light and the Shadow are closer cousins than either likes to admit.",
        "I prayed for patience once. The Light sent me apprentices.",
        "Healing the body is the easy part. It's the rest of a person that takes time.",
        "I hear confessions in my sleep. Not mine, other people's.",
        "A good sermon is short. A good priest knows when to stop talking.",
        "Sometimes the holiest thing you can do is sit with someone in silence.",
        "The chapel candles flickered when I walked in. I'm choosing to take it as a compliment.",
        "Faith is a choice you make every morning, before your boots go on.",
        "I've sat with people at the very edge of death. They all ask for the same things.",
        "The Shadow offers answers. The Light offers questions. I'm not sure which is harder.",
        "There's a grief on this street. I can feel it, like cold air from an open door.",
    },
    DEATHKNIGHT = {
        "I remember dying. Not the pain, just the quiet afterward.",
        "The Lich King's voice is gone from my head. The silence where it was is louder.",
        "Runeblades hunger. Mine's been restless all day.",
        "Cold doesn't bother me any more. Nothing much does, which is its own problem.",
        "Acherus still hangs over us somewhere. Some nights I can feel it watching.",
        "Children cross the street when they see me. The clever ones, anyway.",
        "I was a hero once, before the Scourge. People still know my face, and they look away.",
        "I don't need to eat. I do it anyway, to remember the shape of being alive.",
        "Every death knight has a list of what they did for the Lich King. Mine is very long.",
        "The Ebon Blade asks one thing of us. To be better than what we were made for.",
        "The living warm my hands just by standing close. I try not to stand too close.",
        "Frost, blood or plague. Everyone asks which I prefer, and nobody likes the answer.",
    },
    MAGE = {
        "The ley lines run close here. My fingertips have been tingling all morning.",
        "Somebody nearby is using cheap teleport runes. I can smell the burnt air.",
        WRATH "Dalaran goes wherever it likes. I've stopped trying to predict the commute.",
        "I conjured my own breakfast. It tasted of magic and disappointment.",
        "Every spell has a cost. The Kirin Tor just keep the receipts hidden.",
        "There's a book in the Violet Citadel I was never allowed to read. I still think about it.",
        "A fireball solves most problems. A good mage knows which problems it doesn't.",
        "Time magic gives me headaches. The bronze dragons say that's normal, and also not.",
        "Arcane is the purest school. That's what all the arcane mages say, at least.",
        "I polymorphed my tutor once, by accident. He was a much better sheep than teacher.",
        "Magic is just the world agreeing with you. Very loudly.",
        "Somewhere, someone just cast a portal and missed by a mile. I felt it.",
    },
    WARLOCK = {
        "My imp has been unusually polite today. I don't trust it at all.",
        "Everyone says demons can't be trusted. They're right, which is why you never ask twice.",
        "Fel magic leaves a taste in the mouth. Like copper and regret.",
        "The Twisting Nether is closer than most people think. It's just behind the curtain.",
        "I keep a soul shard in my coat pocket. Most people assume it's a fancy stone.",
        "There's a price for power. I paid mine in advance, which is how I like it.",
        "People cross the street when they see my felhunter. It only chases the ones who run.",
        MISTS "The Black Harvest says knowledge has no morals. Then again, they would say that.",
        "Every warlock thinks they're the one who won't be corrupted. I'm the exception, obviously.",
        "My candles burn green on their own. I've stopped explaining it to landlords.",
        "Something in the Nether knows my name. I'd like to know how.",
        "A demon offered me a bargain this morning. I'm still reading the small print.",
    },
    MONK = {
        "Balance isn't standing still. It's moving in the right direction, very carefully.",
        "I can catch a fly with chopsticks. Nobody's ever asked me to, but I can.",
        "A good brew and a good kick share the same secret. Timing.",
        "The body is a temple. Mine has a few cracks in the walls.",
        "Chi flows through everything. Even the ugly things, which I find comforting.",
        "My master taught me to breathe before I fight. I've been breathing a lot today.",
        "Stillness is a skill. Most people think it's just doing nothing.",
        "I meditated for six hours this morning. Mostly I thought about dumplings.",
        "The Shado-Pan watched the wall for generations. Some of us are still watching.",
        "A punch thrown in anger always misses something, even when it lands.",
        "Every strike should be a question. The answer is whether they're still standing.",
        "Tea is a teacher. It shows you exactly how impatient you are.",
    },
    DRUID = {
        "The trees here have been whispering since dawn. I wish I knew what's upset them.",
        "The Emerald Dream is close tonight. Close enough to smell the rain.",
        "I spent last week as a bear. My manners are still coming back.",
        "Every seed is a promise. Most of them get broken by squirrels.",
        "Cenarius taught that balance takes everything. I keep finding out how much everything is.",
        "Flying as a crow teaches you humility. The real crows are terribly rude.",
        "The soil here is tired. Too many feet, and not enough stillness.",
        "A cat's patience is learned. I learned mine in a tree, waiting for a mouse.",
        "Somebody nearby has been cutting trees without asking. The roots remember.",
        "Moonglade is the quietest place in the world. I miss it most when things are loud.",
        "Nature isn't kind or cruel. It just keeps going, and it'll keep going after us.",
        "My antlers itch when the weather turns. Druids just don't talk about it.",
    },
    DEMONHUNTER = {
        "I gave up my eyes to see the Legion. Now I see a little too much of everyone.",
        "Illidan was right, in the end. I'm still waiting for anyone to say so to my face.",
        "The demon inside me is quiet today. That always means it's thinking.",
        "Ten thousand years in a prison, and the first thing I wanted was a decent meal.",
        "My wings came with the fel. They don't fold comfortably into chairs.",
        "Somebody here has touched fel recently. I can see it on them, like ash.",
        "The Illidari are not heroes. We're what's left when heroes aren't enough.",
        "Everyone stares at the blindfold. They should look at the horns, they're far more interesting.",
        "I hunted demons for millennia. Now people ask me for directions.",
        "Most of my training class didn't survive Mardum. The ones who did don't talk about it.",
        "Every demon I've consumed left a whisper behind. I hear them when I'm tired.",
        "Hate the Legion, not the hunter. I'm told that's a reasonable request.",
    },
    EVOKER = {
        "Every flight's color runs through me. It makes choosing what to wear very hard.",
        "My essence hums when I'm near a dragon. Even the ones pretending to be people.",
        "Breathing fire is easy. Breathing it politely is a skill.",
        "Time magic tastes like sand. Life magic tastes like spring. Don't ask me how I know.",
        "The Aspects gave us their gifts. I'm still waiting for the instructions.",
        "I hover when I'm thinking. People find it unsettling, which is fair.",
        "A dragon's patience is long, but mine isn't. I'm still young, by our measure.",
        "Somebody here smells of the bronze flight. Or they've been standing near an hourglass.",
        "Every spell I cast leaves a little warmth behind, like a hearth after the fire's gone out.",
        "Fire and life come from the same place. Most people only remember the fire.",
        "Being made for war doesn't mean you have to want it. That took me a while to learn.",
        "My maker taught me war. The red flight taught me how to mend what war breaks.",
    },
}

-- PAIRS[race][class]: race and class in one thought.
Walkup.PAIRS = {
    Dwarf = {
        SHAMAN = {
            "Bronzebeard, Wildhammer, Dark Iron, still arguing over who started it. Ask the spirits and they'll tell you the mountain did.",
            "Ironforge was carved out of a living mountain. Some nights I swear I can still hear it grumbling about that.",
            "My grandsire swore the Titans made us from stone. The earth spirits have never once disagreed, and that worries me.",
            "It was the Wildhammer who taught us to listen to the elements. Took the rest of us a thousand years to admit the stone talks back.",
            "A forge fire and a fire spirit want the same thing, which is feeding. Only one of them ever says thank you.",
            "These hills are just ambitious lumps. The earth here agrees with me, it's only too polite to say so.",
            "I spent half my life digging ore out of the ground without asking. Now I ask first, and the ground is a good deal less cranky about it.",
            "There's an old dig site near here, I'd wager. The stone has that hollow sound, like it misses something that was taken.",
            "Ale is the only offering I've ever left the spirits that they sent back for seconds.",
            "Nothing holding the sky up out here. The wind spirits think that's very funny. I don't.",
            "Thaurissan called up a fire lord once and it swallowed half a mountain. I ask politely, these days.",
            CATA "The water spirits in Loch Modan have been sulking since the dam broke. Can't say I blame them, half their loch ran off.",
        },
    },
    Human = {
        PALADIN = {
            "Uther trained the first of us in Lordaeron. I've knelt in the chapel where he knelt, and the stones there are still warm.",
            "The Silver Hand was founded in our darkest hour. Every paladin since has been trying to deserve that.",
            "My father was a farmer and my mother a priest. I suppose a paladin was inevitable, in a sense.",
            "Arthas was one of us, once. I think about him every time the Light starts to feel too easy.",
            "The Cathedral of Light is the heart of the order, but the Light never needed a cathedral to find me.",
            "Swinging a hammer and saying a prayer at the same time takes practice. Mostly you just shout the prayer.",
            "The undead of Lordaeron were my grandparents' neighbors. When I face them, I try to remember they had names.",
            "Northshire Abbey still trains the young ones. The brothers there have never let me forget the incident with the bells.",
            "A human's oath is short, because we don't live long enough for long ones. We try to keep it well.",
            "Tirion Fordring said the Light abides in every heart. Even mine, on a morning like this one.",
            "Stormwind honors its paladins with statues. I'd rather it honored them with fewer wars.",
            "The Light chose a farm boy like me to carry its hammer. I've never understood why, and I've never stopped trying to earn it.",
        },
    },
    NightElf = {
        DRUID = {
            "I slept a century in the Emerald Dream once. When I woke, my favorite tree had become a forest.",
            "Malfurion taught the first of us. I still remember his voice, and how much quieter the world was then.",
            "The Cenarion Circle has argued about balance for ten thousand years. We'll probably settle it any century now.",
            "A night elf as a cat isn't so different from a night elf. Both of us mostly wait in the shade.",
            "The Barrow Dens are quiet now. Some nights I still wake expecting to hear the other sleepers breathing.",
            "For ten thousand years our women were priestesses and our men were druids. I'm glad that tradition is changing.",
            "Ashenvale's trees remember every axe the orcs ever swung. I try to remind them that some of the orcs have learned.",
            "The Dream is beautiful, until you remember it's also where the Nightmare grew. I never close my eyes there without a little fear.",
            "I can speak with owls, stags and bears. The bears have the best gossip and the worst tempers.",
            "We gave up the Well for the wild, and I've never regretted it. The Highborne in me still sighs sometimes.",
            "Moonglade's moonwells sing at midnight. If you've never heard one, you've never really heard Elune.",
            "A night elf druid learns patience the way a tree does. One ring at a time, very slowly.",
        },
        DEMONHUNTER = {
            "Illidan gave me my sight and took my eyes. I'm still deciding whether that was a fair trade.",
            "The Wardens kept me in the Vault for ten thousand years. Maiev still visits, in my nightmares.",
            "My sister still lights a candle for me. She thinks I died in the war, and I've never corrected her.",
            "Our people called us traitors for following Illidan. Then the Legion came back, and suddenly we were useful.",
            "Elune's light still touches me, but it burns now. I wear the blindfold partly to hide that.",
            "I was a sentinel before Illidan found me. I still check the tree line before I sleep.",
            "My family disowned me twice. Once for following Illidan, and once for coming back.",
            "My spectral sight shows me fel wherever it lingers. In a city, it lingers in the oddest places.",
            "Ten thousand years of hunting demons, and I still haven't learned to like the taste of them.",
            "My wings were a gift of the fel. The sentinels I trained with would weep to see them.",
            "Tyrande speaks to me again, after a fashion. She doesn't look at me while she does it.",
            "I remember Zin-Azshari before the Sundering. That's part of why I became what I am.",
        },
    },
    Gnome = {
        MAGE = {
            "Arcane and engineering are basically the same thing. One uses spells and one uses spanners, and both explode.",
            "I keep a teleport rune in each pocket. Gnomeregan taught me to always have an exit.",
            "Most mages make do with a plain staff. Mine has a spring-loaded extension, just in case.",
            "Curing a leper gnome with a little polymorph is my life's work. It's going very slowly.",
            "The Kirin Tor think gnomes make adorable apprentices. They stop thinking that after the first demonstration.",
            "I calculated the exact angle for the perfect fireball. Forty-three degrees, give or take a burnt eyebrow.",
            "Gnomish magic is just engineering with fewer moving parts. Fewer parts means fewer things to explode.",
            "My frost spells work better in Dun Morogh. I suspect the snow is simply happy to see me.",
            "Everyone assumes the gnome in the robe is a novice. That's the sort of assumption I enjoy correcting.",
            "I once blinked onto a table during a lecture in Dalaran. Nobody believed it was an accident, and that was fair.",
            "Mechanical familiars are more reliable than cats. They never knock your potions off the shelf, unless you program them to.",
            "Gnomeregan's radiation did something peculiar to my arcane affinity. My hair still glows when I'm excited.",
        },
    },
    Draenei = {
        SHAMAN = {
            "For thousands of years my people never listened to the elements. Nobundo had to be broken before he heard them.",
            "Nobundo was an outcast when the elements first spoke to him. I think of that every time I'm passed over.",
            "The Light and the elements are both very old. Neither one likes being called the younger of the two.",
            "On Argus we knew only the Light. Azeroth's earth and wind still sound very loud to my ears.",
            "The Exodar wounded Azuremyst when it fell. The water spirits there have only just begun to forgive us.",
            "A draenei shaman learns patience twice. Once from the Light, and once more from stubborn stone.",
            "My totems hum in a key that sounds like the Naaru's song. I like to think they're cousins somehow.",
            "The elements of Outland were broken and furious. I'm still learning what calm spirits sound like.",
            "Velen sees the future. I just ask the wind, and it usually gives me the weather.",
            "Fire burned our first home. It took me years to trust a fire spirit, and I still keep water nearby.",
            "The Earthen Ring welcomed us. I'm not sure they knew how many questions we'd bring.",
            "My hooves give me a fine sense of the earth's mood. Today it's grumpy, and wants its lunch.",
        },
    },
    Pandaren = {
        MONK = {
            "Every pandaren learns two things as a cub. How to brew, and how to throw someone who's had too much of it.",
            "Master Shang Xi taught on the back of Shen-zin Su. The turtle never once complained about the shouting.",
            "Chi flows through brew and fist alike. That's why the best brewmasters are also the most dangerous drunks.",
            "I left the Wandering Isle to learn what balance means to the rest of the world. So far it means a lot of shouting.",
            "A good monk can stop a punch with an open palm. A great monk can do it while holding a full mug.",
            "The Shado-Pan train for years to master their fear. I mostly master my appetite, which is harder.",
            "The old masters say a fist should flow like water. Mine flows more like a river in spring, with a lot of debris.",
            "My grandfather broke stone with one finger. I broke a table once, and he still hasn't let me forget it.",
            "The Tushui teach patience and the Huojin teach action. A good monk learns when to be which.",
            "At the monastery we meditated before breakfast. I still can't think clearly until I've had a dumpling.",
            "Outsiders think pandaren are lazy. They've never seen us train at dawn, or recover by noon.",
            "The way of the monk is simple. Breathe, step, strike, then make tea for whoever you just knocked down.",
        },
    },
    Orc = {
        WARRIOR = {
            "My grandsire fought in the First War with an axe bigger than I am. I still use it, and it still argues with me.",
            "Thrall taught us honor. The arena taught me the rest.",
            "An orc warrior's first lesson is to stand. The second is to stand longer than anyone else.",
            "I was born in an internment camp. Learning to fight was the first thing I ever chose for myself.",
            "There's an old Blackrock war song that only works if you're hitting something. I've never once managed to finish it.",
            "The blood curse is gone, but we still fight like our ancestors are watching. Maybe they are.",
            "In Orgrimmar we spar in the Valley of Honor. The bruises are how you know someone respects you.",
            "Victory or death, the old cry goes. My mother added a third choice, which was dinner, and it always won.",
            "Humans think we fight because we're angry. We fight because a warrior who doesn't forgets who they are.",
            "Every blade I own is named in my clan's tongue. Most of the names translate to something like bad day.",
            "My first axe was a stone tied to a stick in the camps. I keep it, so I never forget where strength begins.",
            MISTS "The Kor'kron called me too wild and the old guard called me too soft. I fought for neither of them.",
        },
        SHAMAN = {
            "Ner'zhul was a shaman too, before he sold us to the Legion. Every orc shaman since has had to win back the elements' trust.",
            "Thrall brought the old ways back to our people. I learned from a woman who learned from him.",
            "The elements left us when we turned to fel. They took a long time to answer when we called again, and they were right to.",
            "Durotar's fire spirits are hot-tempered, like the orcs who settled there. We understand each other.",
            "My grandmother was a warlock in the Horde's dark days. I became a shaman partly to apologize for her.",
            "The Earthen Ring has nearly as many orcs as tauren now. I'm still proud of that.",
            "Before the Dark Portal, every clan had its own shaman. Mine are still trying to remember the old Frostwolf songs.",
            CATA "The air spirits whistle through the Valley of Wisdom. They used to talk to Thrall there, they say.",
            "An orc shaman learns humility early. The elements don't care how strong your arm is.",
            "When I call lightning, I think of Draenor's storms. My elders say they were wilder, and freer.",
            "The fel left a scar in our blood. The earth, at least, is willing to help us heal it.",
            "My wolf and I share one spirit, the old shamans say. He takes more than his share of the food.",
        },
    },
    Scourge = {
        WARLOCK = {
            "Demons can't offer me eternal life, since I've already got the unpleasant version. It drives them mad.",
            "My felhunter loves the Undercity. All those dark corridors, and all that old magic seeping out of the walls.",
            "The Forsaken have nothing left to sell the Legion but our will, and Sylvanas made very sure we kept it.",
            "My imp keeps asking what it's like being dead. I keep telling it we'll find out together if it doesn't stop.",
            "Living warlocks spend their lives worrying about their souls. Mine already went somewhere and came back, so I worry less.",
            "The apothecaries and the warlocks of the Undercity share a corridor. The smell is simply indescribable.",
            "Shadow comes easily to the dead. Fel takes a little more persuading, but we have nothing but time.",
            "My voidwalker served a warlock in Lordaeron once. It recognised me from before I died, and it laughed.",
            "Demons offer power for a price. I've already paid the biggest price there is, so I'm rather good at haggling.",
            "A soul shard feels warm in my hand. It's the closest I come to remembering what a heartbeat felt like.",
            "Most warlocks fear their demons turning on them. Mine already know there's very little of me left to hurt.",
            "The Plague made me, the Lich King used me, and now a succubus tells me I need to get out more. It's been a strange unlife.",
        },
    },
    Tauren = {
        DRUID = {
            "Hamuul Runetotem learned the old ways from Cenarius himself. Thunder Bluff and the night elves have been arguing about it since.",
            "A tauren in bear form is mostly just a slightly furrier tauren. My friends barely notice the difference.",
            "The Earth Mother and the Emerald Dream speak with different voices, but they never once disagree about what matters.",
            "On the plains of Mulgore the grass grows back from every hoofprint. I try to walk through the world like that.",
            "I take the shape of a stag so often that the kodo herds treat me as one of their own. They are terrible conversationalists.",
            "My grandmother planted a tree for every child born in our village. I go back and talk to mine whenever I can.",
            "The night elves of Moonglade still look surprised when a tauren walks in. Then they offer me a chair that's far too small.",
            "The Earth Mother's eyes are the sun and the moon. As a druid, I spend half my nights staring into one of them.",
            "When I take bird form, the winds of Thunder Bluff throw me about like a leaf. I've never once landed up there gracefully.",
            "The plains remember every stampede. Put your ear to the ground in Mulgore and you can still hear the old ones running.",
            "My totem and my moonstone sit side by side on the hearth. They seem to get along, which is more than I can say for their makers.",
            "Every spring I spend a week as a bear by Stonebull Lake. The fish there know my name and fear it.",
        },
    },
    Troll = {
        HUNTER = {
            "My raptor and I came from the Echo Isles together. She still thinks she's the one in charge.",
            "A Darkspear hunter learns two things young. Where the beast sleeps, and which loa it answers to.",
            "Bethekk, the panther loa, watches over every hunter on the isles. I leave her a fresh catch every new moon.",
            "Trolls hunted these jungles before the world had names. We still know where all the good trails are.",
            "My bat is the only creature I've met who complains more than my grandmother. I love them both.",
            "In Stranglethorn everything is either prey or predator. The trick is knowing which you are today.",
            "My pet once caught a wolf twice its size. It brought it back to show me, then ate it anyway.",
            "Spears were for my grandfather. I prefer a good bow, and the raptor prefers a good chase.",
            "The Darkspear eat what they hunt. It keeps us honest about what we kill and why.",
            BFA "Zandalari hunters ride dinosaurs. We ride raptors and pretend we aren't jealous.",
            "Every beast has a spirit, and every spirit has a price. My raptor charges extra on rainy days.",
            "I've tracked beasts through jungle, desert and snow. Snow is the worst, it remembers every mistake you make.",
        },
    },
    BloodElf = {
        PALADIN = {
            "We forced the Light out of a captured naaru once. The Light forgave us, which was somehow worse.",
            "The Blood Knights were built on stolen light. We've spent the years since learning to ask for it properly.",
            "Lady Liadrin gave up the Light once and found it again. I keep that in mind on my bad days.",
            "Silvermoon's paladins polish their armor until it gleams like the Sunwell. Vanity, perhaps, but it does catch the eye of anything undead.",
            "My grandmother said the Light was for humans and priests. I'd love to see her face if she saw me now.",
            "The Sunwell burns again, and the Light flows through it. On a clear day in Quel'Thalas you can feel the two humming together.",
            "Arthas was a paladin too, the day he marched through our gates. I swore an oath that night, and the Light was listening.",
            "When I first channeled the Light, I expected it to feel like magic. It felt more like being forgiven for something I hadn't done yet.",
            "The Aldor and the Scryers argued over who had the Light right. Our order quietly took notes from both.",
            "Every Blood Knight carries a little guilt beside the hammer. I find it keeps the swing honest.",
            "The magisters think we're crude and the priests think we're arrogant. The Scourge, at least, just think we're dangerous.",
            "The undead keep drifting back to the Dead Scar, as if they miss it. I spend a lot of time explaining that they shouldn't.",
        },
    },
}

local _issecret = _G.issecretvalue

-- nil for anything secret. Asked before any other look at the value,
-- including a comparison, since comparing a secret throws too.
local function readable(v)
    if _issecret and _issecret(v) then return nil end
    return v
end

local function db()
    GlyphicDB = GlyphicDB or {}
    local w = GlyphicDB.walkup
    if type(w) ~= "table" then w = {}; GlyphicDB.walkup = w end
    if w.enabled == nil then w.enabled = false end
    if w.point == nil then w.point = "CENTER" end
    if w.x == nil then w.x = 0 end
    if w.y == nil then w.y = -200 end
    if w.era == nil then w.era = "auto" end
    return w
end

-- The era this client's world is set in. Forever runs Midnight's client over
-- a Classic-era world, and its 16001 is not an expansion number, so it is
-- asked by game type; every other client's interface leads with its expansion.
function Walkup.ClientEra()
    if Compat.IsForever() then return 1 end
    local iface = type(GetBuildInfo) == "function" and select(4, GetBuildInfo())
    local era = type(iface) == "number" and math.floor(iface / 10000) or #Walkup.ERAS
    return math.max(1, math.min(era, #Walkup.ERAS))
end

-- "auto" or an index into ERAS.
function Walkup.GetEraSetting() return db().era end

function Walkup.SetEra(v)
    if v ~= "auto" and not Walkup.ERAS[v] then return end
    db().era = v
end

function Walkup.Era()
    local v = db().era
    if Walkup.ERAS[v] then return v end
    return Walkup.ClientEra()
end

-- The lines of `pool` that belong to `era`, as plain text; nil if none do.
local function inEra(pool, era)
    if not pool then return nil end
    local out = {}
    for _, line in ipairs(pool) do
        if type(line) == "string" then
            out[#out + 1] = line
        elseif line.era <= era then
            out[#out + 1] = line.text
        end
    end
    return out[1] and out or nil
end
Walkup.InEra = inEra

local function playerToken(fn)
    if type(fn) ~= "function" then return nil end
    local ok, _, token = pcall(fn, "player")
    if not ok then return nil end
    return readable(token)
end

-- The race, class and pairing lines your character can draw on in the chosen
-- era; any may be nil.
function Walkup.Pools()
    local race, class = playerToken(UnitRace) or "", playerToken(UnitClass) or ""
    local byClass = Walkup.PAIRS[race]
    local era = Walkup.Era()
    return inEra(Walkup.RACES[race], era), inEra(Walkup.CLASSES[class], era),
        inEra(byClass and byClass[class], era)
end

local last = {}

-- A random line from `pool`, never the one it gave last time.
local function pick(pool, slot, rand)
    local n = #pool
    if n == 0 then return nil end
    local i = rand(n)
    if n > 1 and i == last[slot] then i = (i % n) + 1 end
    last[slot] = i
    return pool[i]
end

-- `rand` is math.random's shape: rand(n) is 1..n, rand() is [0, 1).
function Walkup.Compose(rand)
    rand = rand or math.random
    local race, class, pair = Walkup.Pools()
    if pair and (rand() < Walkup.PAIR_CHANCE or not (race or class)) then
        return pick(pair, "pair", rand)
    end
    if race and class then
        if rand(2) == 1 then return pick(race, "race", rand) end
        return pick(class, "class", rand)
    end
    if race then return pick(race, "race", rand) end
    if class then return pick(class, "class", rand) end
    return nil
end

function Walkup.Speak()
    if Compat.InChatLockdown() then
        ns.Print("chat is locked during this encounter, so your walkup stays unsaid.")
        return nil
    end
    local text = Walkup.Compose()
    if not text then
        ns.Print("there are no walkup lines for your race or class yet.")
        return nil
    end
    return ns.SayInCharacter(text)
end

--=========================================================================--
--  The floating button
--=========================================================================--
local button

local function savePosition()
    local point, _, relPoint, x, y = button:GetPoint()
    local w = db()
    w.point, w.relPoint = point or "CENTER", relPoint or point or "CENTER"
    w.x, w.y = x or 0, y or 0
end

local function showTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Walkup Helper", 1, 1, 1)
    GameTooltip:AddLine("Your character thinks out loud in /say, shaped by their race, "
        .. "their class or both, through your tongue and accent like anything "
        .. "you type.", 0.8, 0.8, 0.8, true)
    local race, class, pair = Walkup.Pools()
    if not (pair or race or class) then
        GameTooltip:AddLine("No lines for your race or class yet.", 0.8, 0.5, 0.5, true)
    elseif not pair and not (race and class) then
        GameTooltip:AddLine("Only your " .. (race and "race" or "class")
            .. " has lines so far.", 0.8, 0.8, 0.5, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffffffClick|r  Say a walkup line", 1, 1, 1)
    local key = GetBindingKey and GetBindingKey("GLYPHIC_WALKUP")
    if key then GameTooltip:AddLine("|cffffffffKeybind|r  " .. key, 1, 1, 1) end
    GameTooltip:AddLine("|cffffffffDrag|r  Move (unlock the bar in options)", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function build()
    if button then return button end
    local b = CreateFrame("Button", "GlyphicWalkupButton", UIParent)
    Compat.PanelButton(b, "Walkup Helper", 116, 22, "GameFontNormalSmall")
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function() Walkup.Speak() end)
    b:SetScript("OnDragStart", function(self)
        if GlyphicDB and GlyphicDB.widget and GlyphicDB.widget.locked then return end
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
    Walkup._button = b
    return b
end

function Walkup.Refresh()
    local w = db()
    if not w.enabled then
        if button then button:Hide() end
        return
    end
    build()
    button:ClearAllPoints()
    button:SetPoint(w.point or "CENTER", UIParent, w.relPoint or w.point or "CENTER",
        w.x or 0, w.y or -200)
    button:Show()
end

function Walkup.IsShown() return db().enabled and true or false end

function Walkup.SetShown(on)
    db().enabled = on and true or false
    Walkup.Refresh()
end

-- /glyphic walkup [show|hide]. Bare, it speaks: a macro is a keypress.
function Walkup.Command(rest)
    local arg = string.lower(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "show" or arg == "on" then
        Walkup.SetShown(true)
        ns.Print("walkup button shown.")
    elseif arg == "hide" or arg == "off" then
        Walkup.SetShown(false)
        ns.Print("walkup button hidden.")
    elseif arg == "toggle" then
        Walkup.SetShown(not Walkup.IsShown())
    else
        Walkup.Speak()
    end
    if ns.RefreshGeneralPanel then ns.RefreshGeneralPanel() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() Walkup.Refresh() end)
