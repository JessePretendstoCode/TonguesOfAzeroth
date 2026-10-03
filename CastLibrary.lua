--[[-------------------------------------------------------------------------
    Tongues of Azeroth - CastLibrary.lua
    The shipped phrase packs: ready-made lines for spells you already cast, so
    the feature is usable without writing seventy phrases first. Every pack is
    opt-in -- nothing here speaks until you tick it in Cast Phrases.

    Writing phrases:
      * A phrase is the body of an emote, so it continues the sentence "<Your
        name> ...". Start with a verb, lower case, and end with punctuation.
      * Words in "double quotes" are spoken aloud and get translated into
        whatever tongue you're speaking. Everything else is narration and stays
        in plain English, since that's the part onlookers should understand.
      * %s spell, %p pet's name, %f pet's family, %t target. A phrase whose
        token can't be filled in is skipped for that cast rather than emoted
        with a hole in it, so %t lines are safe to include.
      * Keep them short. The whole line shares one 255-character chat message
        with the translation, which runs longer than the English it replaces,
        plus your name and the "in Broken Demonic" attribution.

    Register -- how much colour, and where:
      These read like a DM narrating an action, and the craft advice there is
      consistent: match the detail to how much the moment matters. Routine
      attacks stay brisk; the turning points get the flourish. A cast phrase
      fires constantly, so most lines are the third longsword swing of the
      fight, not the killing blow. Two sentences of cinematic prose on every
      Shadow Bolt is spam in party chat.

      So the fix for a flat line is DENSITY, not length. "gathers the dark into
      one point and lets it go" states the action twice and never says what it
      was like. Spend the same words on one concrete detail beyond the action,
      drawn from movement, sensation, sound or consequence -- "... and lets it
      go with a thump of cold air" -- and rotate which of those you reach for,
      so consecutive casts don't come out the same shape.

      Tier it by how often the spell is cast: a filler gets one detail, a long
      cooldown (a Hellfire, a Metamorphosis) earns the fuller line.

      Two things not to do. Don't let narration claim a mechanical effect that
      did not happen -- a line may not say the target was folded over, disarmed
      or killed, because the game did not say so. And don't buy colour with the
      spoken part: the words in quotes are the only thing the language engine
      transforms, so a pack that narrates beautifully and says nothing aloud has
      given up the feature's whole point. Keep quotes short and let the
      narration around them do the work.
      * Spells are matched by NAME (see Casts.lua), which is why these are
        written out rather than given as spell ids: one entry covers every rank
        on Classic and the retail version of the same spell at once. The flip
        side is that this library only matches an English client.

    Two or three lines per spell, and no more:
      Every line here ships to everyone, so a spell's set has to suit a grim
      Forsaken and a cheerful Gnome alike. Two or three is not a budget forced
      on us by space -- it is what the throttle makes useful. A spell will not
      speak twice inside five minutes, so a fourth line is one almost nobody
      hears.

      Spend those two or three on DIFFERENT SHAPES rather than three readings of
      the same beat. The set that works is roughly: one that narrates with a
      concrete detail, one that speaks aloud, and -- on a spell worth it -- one
      that is wry. Three lines all built "says X and does Y" read as one line
      with the words shuffled.

      Nothing here should assume WHY the character fights. Faction and religion
      belong to a character, not to a spell, so they are left to the player to
      write -- keep them out of the packs entirely. Avoid pronouns: the emote
      reads "<Name> <your line>", and "their" lands oddly in that frame, so
      prefer phrasings that need none.
---------------------------------------------------------------------------]]

local ADDON, ns = ...

local CastLibrary = {}
ns.CastLibrary = CastLibrary

local PACKS = {}
local byKey = {}

-- Which pack belongs to which class, by the locale-independent token from
-- UnitClass. Declared up here because pack() uses it to work out whether a pack
-- is a class pack (shown only to that class) or a universal one.
local CLASS_PACKS = {
    WARLOCK = "warlock", MAGE = "mage", PRIEST = "priest", WARRIOR = "warrior",
    PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue", DRUID = "druid",
    SHAMAN = "shaman", DEATHKNIGHT = "deathknight", MONK = "monk",
    DEMONHUNTER = "demonhunter", EVOKER = "evoker",
}

local CLASS_PACK_IDS = {}
for _, id in pairs(CLASS_PACKS) do CLASS_PACK_IDS[id] = true end

--   { "Spell Name",
--       "does the thing.",
--       'roars "Now!" and does the thing.',
--   }
--
-- A spell is its name followed by its lines, and that is the whole format.
-- There is deliberately nothing to tag a line with: a line either earns its
-- place in the two or three, or it is cut.
--
-- Each pack keeps `list`, its spells in the order written here, as well as
-- feeding the flat byKey lookup the game reads. The ordered copy is what
-- tools/dump_phrases.lua turns into PHRASES.md for review, so the document and
-- the shipped lines can't drift apart.
local function addLines(sink, id, lines, counter)
    for _, text in ipairs(lines) do
        sink[#sink + 1] = { pack = id, text = text }
        if counter then counter[#counter + 1] = { text = text } end
    end
end

local function pack(id, name, note, spells)
    local p = {
        id = id, name = name, note = note, spells = 0, phrases = 0, list = {},
        kind = CLASS_PACK_IDS[id] and "class" or "universal",
    }
    for _, entry in ipairs(spells) do
        local spellName = entry[1]
        local key = spellName:lower()
        local rec = byKey[key]
        if not rec then
            rec = { display = spellName, entries = {} }
            byKey[key] = rec
        end
        local lines = {}
        for i = 2, #entry do lines[#lines + 1] = entry[i] end
        local written = {}
        addLines(rec.entries, id, lines, written)
        p.phrases = p.phrases + #written
        p.list[#p.list + 1] = { name = spellName, phrases = written }
        p.spells = p.spells + 1
    end
    PACKS[#PACKS + 1] = p
end

--=========================================================================--
--@phrases-begin@  (dumped to PHRASES.md by tools/dump_phrases.lua -- edit
--                  here and re-run the dump so the document matches)

pack('warlock', 'Warlock', 'Fel magic, pacts and pets.', {
    { 'Immolate',
        'sets %t alight, and the heat rolls back over anyone standing close.',
        'snarls "Burn!" and the fire takes with a crack like wet wood.',
        'sets %t on fire and waits for the complaining to start.' },
    { 'Shadow Bolt',
        'gathers the dark into one point and lets it go with a thump of cold air.',
        'barks "Down!" and the shadow arrives like a slammed door.',
        'says "Nothing personal." and lets the bolt fly.' },
    { 'Corruption',
        'sets something patient working inside %t, slow as rot in a rafter.',
        'spits "Rot." and the word seems to stick.',
        'gives %t something to think about in an hour or so.' },
    { 'Fear',
        'speaks a word %t was never meant to hear, and %t stops hearing anything else.',
        'says "Run. Go on." and means it.',
        'suggests, mildly, that %t has somewhere else to be.' },
    { 'Drain Life',
        'closes a hand and draws the warmth out of %t in a thin grey thread.',
        'snarls "Mine." and doesn\'t let go until it is.' },
    { 'Health Funnel',
        'opens a vein for %p without hesitating, and goes grey doing it.',
        'tells %p, "Hold on. Nearly there."' },
    { 'Hellfire',
        'spreads both arms and lets the fire spill outward until the stone underfoot goes black.',
        'bellows "Burn with me!" and lets go of the last of it, wreathed to the shoulders.',
        'sets everything on fire, including the obvious, including both boots.' },
    { 'Soulstone',
        'folds a soul into stone until the stone sits warm. "In case it comes to that."',
        'puts a little of %t somewhere safe. Insurance.' },
    { 'Create Healthstone',
        'works a small red stone out of nothing, still slick from the making.',
        'holds the stone out to whoever needs it first. "Take it."',
        'produces a stone that tastes worse than the wound it mends.' },
    { 'Summon Felhunter',
        'opens the air and %f steps through it, nose first.',
        'greets %p like an old dog. "There you are."' },
    { 'Summon Voidwalker',
        'draws something vast and unhurried into the light, and the light gives way for it.',
        'says "Good. You\'re here." to %p.',
        'summons %p, who couldn\'t be less impressed.' },
    { 'Summon Imp',
        'summons %p, already mid-complaint about the weather.',
        'says "Behave." to %p, hopefully.',
        'snaps %p into the world by the scruff and tells it to keep up.' },
    { 'Ritual of Summoning',
        'chalks the circle and says "Mind the edges."',
        'draws a circle and waits for someone to stand in it wrong.' },
})

pack('mage', 'Mage', 'Fire, frost and the arcane.', {
    { 'Fireball',
        'lobs a fireball that leaves the air tasting of soot.',
        'barks "Move!" and the fire goes anyway, hot enough to peel paint.',
        'throws fire at %t, as is traditional.' },
    { 'Frostbolt',
        'exhales, and the air cracks with cold.',
        'snaps "Enough!" and frost answers with a crack like thin ice.',
        'cools %t down, somewhat abruptly.' },
    { 'Pyroblast',
        'takes a long breath, and the whole room pulls toward the hands.',
        'bellows "Burn!" and lets the blast go hard enough to stagger anyone close.',
        'promises %t "This one will hurt." and keeps the promise.' },
    { 'Polymorph',
        'rewrites %t into something woollier.',
        'snaps "Quiet!" and the changing spell leaves hoofprints in the dust.',
        'turns %t into something with fewer opinions.' },
    { 'Blink',
        'steps sideways out of the world and back into it, leaving frost on the boots.',
        'was there. Was not. "Excuse me."' },
    { 'Counterspell',
        'cuts the air with two fingers and says "No."',
        'interrupts %t mid-thought. As one does.',
        'says "Not that one." and folds the spell shut like paper.' },
    { 'Ice Block',
        'pulls the winter in and holds still while breath fogs against the ice.',
        'mutters "Not today." and freezes solid with a sharp crack of settling ice.',
        'becomes temporarily unavailable.' },
    { 'Arcane Intellect',
        'taps %t on the brow. "Try to keep up."',
        'says "You\'ll need this." and leaves %t blinking at the sudden clarity.' },
    { 'Blizzard',
        'raises both hands and calls the storm down until the hail pings off armor.',
        'shouts "Fall!" and the snow comes down hard enough to sting exposed skin.',
        'calls down snow and says "Sorry about this."' },
    { 'Conjure Refreshment',
        'conjures food out of thin air, as one does.',
        'says "You look hungry." and conjures a snack that steams faintly.' },
    { 'Slow Fall',
        'says "Mind the landing." a little too late.',
        'calls "Easy now." down at %t and threads a gentle lift into the fall.' },
})

pack('priest', 'Priest', 'Light, shadow and the words between.', {
    { 'Power Word: Shield',
        'speaks a word over %t and something closes around %t with a faint hum.',
        'snaps "Hold!" and the ward snaps shut with a pressure like deep water.',
        'says "You\'re not alone in this." and a steady warmth settles on %t.' },
    { 'Flash Heal',
        'pours warmth into %t, quick enough to make %t gasp.',
        'barks "Stay up!" and slams the mending in hard enough to jar teeth.',
        'says "There. Breathe." and leaves steady warmth where the pain was sharpest.' },
    { 'Renew',
        'murmurs "Rest a moment." over %t.',
        'leaves a small warmth behind in %t, like sunlight on the back of the neck.' },
    { 'Resurrection',
        'kneels, breathes warmth back toward still lungs, and asks for one more.',
        'tells the fallen, "Come back. We\'re not finished."',
        'demands "Up!" into the stillness and won\'t stop until something moves.' },
    { 'Shadow Word: Pain',
        'lets a thread of shadow settle into %t like grit under a nail.',
        'hisses "Hurt." and the shadow bites deep enough to leave a cold spot.',
        'murmurs "Remember this." over %t.' },
    { 'Mind Blast',
        'looks at %t and pushes, and the thought arrives like a fist through a wall.',
        'slams "Out!" into %t\'s thoughts hard enough to ring skull-bone.' },
    { 'Psychic Scream',
        'screams without making a sound.',
        'screams "Go!" without making a sound, and the pressure rolls outward anyway.' },
    { 'Mind Control',
        'settles into %t\'s thoughts and takes the reins, cold as a hand on the nape.',
        'snaps "Mine." and threads will through %t\'s fingers from the inside.' },
    { 'Dispel Magic',
        'says "Hold still." and brushes the magic off %t in a shower of sparks.',
        'picks the wrong magic off %t, patiently.' },
    { 'Fade',
        'becomes markedly less interesting.',
        'steps out of the foreground. "Who?"' },
    { 'Levitate',
        'says "Mind the landing." and sends lightness into %t\'s bones.',
        'puts %t somewhere slightly above the ground.' },
})

pack('warrior', 'Warrior', 'Shouts, charges and bad ideas.', {
    { 'Charge',
        'picks %t out of the crowd and runs at it, boots throwing sparks off the flagstones.',
        'roars "Out of my way!" and closes the gap in a skid of dust and armour.',
        'says "Coming through!" and runs at %t with the urgency of someone late for dinner.' },
    { 'Battle Shout',
        'bellows "With me!" loud enough to hurt.',
        'raises the volume until courage seems plausible.',
        'says "We\'ve got this." and sells it with a nod nobody argues with.' },
    { 'Taunt',
        'points at %t and says "Me. Try me."',
        'insults %t\'s mother, thoroughly.',
        'calls %t "Over here!" with feeling.' },
    { 'Execute',
        'looks down at %t and says "Done." with breath still fogging the visor.',
        'finishes what %t started.' },
    { 'Shield Wall',
        'sets both feet on gravel until they stop sliding. "Nothing gets past."',
        'becomes temporarily inconvenient to kill.',
        'says "Behind me." and raises the shield until the strap creaks.' },
    { 'Intimidating Shout',
        'roars, and something in it isn\'t entirely human.',
        'bellows "Run!" until the rafters answer.' },
    { 'Thunder Clap',
        'brings the ground up to meet everyone in a jar of teeth and dust.',
        'roars "Down!" and cracks the earth.' },
    { 'Berserker Rage',
        'stops pretending to be reasonable.',
        'snarls "More!" and the grip on the haft goes white-knuckled.' },
    { 'Heroic Throw',
        'throws an axe and shouts "Catch!" The haft hums once leaving the hand.',
        'tosses steel at %t. Enthusiastically.' },
    { 'Victory Rush',
        'spits, grins, and keeps going.',
        'barks "Again!" and surges forward on bloodied boots.',
        'says "Not done yet." and presses on through the ache.' },
})

pack('paladin', 'Paladin', 'Oaths, hammers and judgement.', {
    { 'Lay on Hands',
        'presses both hands to %t and gives everything, heat draining out through the palms.',
        'says "Take mine." and means it, even when the knees go soft.',
        'tells %t, "Not your turn yet." and doesn\'t let go.' },
    { 'Hammer of Justice',
        'brings the hammer down on %t with a crack like wet timber.',
        'says "Kneel." and swings before the word finishes.',
        'says "Sit this one out." and raises the hammer overhead.' },
    { 'Consecration',
        'marks the ground and dares anyone to cross it, ash curling at the boot toes.',
        'shouts "This far!" and burns the border into the flagstones.',
        'claims the ground and mutters "Mine."' },
    { 'Divine Shield',
        'is briefly, gloriously untouchable.',
        'says "Not today." and locks the shell shut with a soft click.',
        'becomes the most irritating target in reach.' },
    { 'Redemption',
        'kneels by the fallen and refuses to let go, hands sunk past the wrist in cold earth.',
        'tells the dead "Get up. Not yet."',
        'argues death into a brief recess.' },
    { 'Judgement',
        'passes sentence on %t without raising voice, one flat syllable at a time.',
        'snaps "Guilty." and strikes before the echo fades.',
        'tells %t, "This could\'ve gone differently." and means it.' },
    { 'Avenging Wrath',
        'unfurls power and stops holding back, wings throwing heat against the face.',
        'says "Enough." and means it now, voice stripped to bare metal.',
        'roars and lets the wrath show, heat rippling off the pauldrons.' },
    { 'Blessing of Might',
        'lays a blessing on %t like a hand on a shoulder, grip firm through the mail.',
        'tells %t, "You\'ve got this." and makes it sound true.' },
    { 'Hand of Protection',
        'puts a wall between %t and the world, palm flat against the air.',
        'makes %t temporarily everybody else\'s problem.',
        'says "Stay behind me." and seals %t in with a gentle push.' },
    { 'Devotion Aura',
        'stands a little straighter, and so does everyone near, boots finding the same beat.',
        'says "Stay close." and means stay close, shoulder to shoulder.' },
})

pack('hunter', 'Hunter', 'Marks, traps and one good animal.', {
    { 'Hunter\'s Mark',
        'marks %t and says, quietly, "There you are," thumb still on the bowstring.',
        'labels %t for later. Much later.',
        'snaps "Found you." and marks %t before %t knows.' },
    { 'Aimed Shot',
        'breathes out, and lets the arrow go with a sharp twang.',
        'says "Steady." and takes the long shot, wind in the fletching.',
        'takes the shot %t was hoping nobody would take.' },
    { 'Multi-Shot',
        'looses three arrows in the time most need one, quiver rattling.',
        'says "All three." and the air goes full of whistling.',
        'sends three answers to a question nobody asked.' },
    { 'Freezing Trap',
        'sets the trap and steps back before the cold catches.',
        'snaps "Hold still." and arms the trap with a click like teeth.' },
    { 'Feign Death',
        'is, regrettably, dead.',
        'plays dead and mutters "Convincing enough."',
        'drops and plays dead, going limp mid-breath.' },
    { 'Mend Pet',
        'checks %p over, fingers in the fur, and says "You\'ll do."',
        'tells %p, "Almost good as new," and %p leans into the hand.' },
    { 'Revive Pet',
        'refuses to let %p go, and isn\'t asking.',
        'whispers "Not you. Get up." to %p with blood on the gloves.',
        'says "Come back." to %p and waits, hand on the scruff.' },
    { 'Call Pet',
        'whistles once, and %p comes running through the brush.',
        'whistles once and says "Late again, %p."',
        'calls %p by name and %p answers with a bark.' },
    { 'Misdirection',
        'points %p at %t with two fingers, no shout needed.',
        'tells %p, "That one." and steps aside with a hand on %p\'s neck.' },
    { 'Disengage',
        'leaves, at speed, and calls it tactics.',
        'says "Out." and springs backward, boots skidding on stone.',
        'decides %t can keep this problem.' },
})

pack('rogue', 'Rogue', 'Quiet work.', {
    { 'Stealth',
        'is no longer quite where you were looking, only the curtain moving.',
        'says "Gone." and slips out of sight without a footfall.',
        'was never in that spot. "Must\'ve been someone else."' },
    { 'Sap',
        'slips behind %t and offers the weighted cosh without a sound.',
        'introduces %t to a short nap.',
        'whispers "Rest." at %t\'s ear, breath held.' },
    { 'Vanish',
        'was never here. Ask anyone.',
        'says "Nowhere." and steps out of the room mid-stride.',
        'leaves no witness and murmurs "Forget it."' },
    { 'Pick Pocket',
        'admires %t\'s coin purse. Briefly.',
        'says "Mine now." and relieves %t of a coin\'s weight.' },
    { 'Kidney Shot',
        'finds the spot below the ribs without a word.',
        'snarls "Down." and strikes below the ribs.',
        'reminds %t where the kidneys are. "Here."' },
    { 'Eviscerate',
        'finishes close and fast, blade still warm.',
        'says "Last one." and works %t over at arm\'s length.',
        'closes the account and mutters "Paid."' },
    { 'Blind',
        'throws powder and says "Look away," hand already empty.',
        'takes %t\'s eyes off the matter at hand.' },
    { 'Sprint',
        'decides this is someone else\'s problem now.',
        'says "Not today." and breaks into a run, heels flashing.',
        'says "Tell them I went east." and runs, coin purse bouncing.' },
    { 'Shadowstep',
        'crosses the room the short way, two heartbeats flat.',
        'says "Behind you." and arrives beside %t on a puff of ash.',
        'cuts the distance and murmurs "Closer."' },
})

pack('druid', 'Druid', 'Forms, roots and rebirth.', {
    { 'Bear Form',
        'says "Bear." and the shoulders bulk up before the rest catches.',
        'becomes bear-shaped and the air smells like wet hide.',
        'grows fur, claws, and a better opinion of standing ground.' },
    { 'Cat Form',
        'slips into cat form and claws click once on the stone.',
        'says "Cat." and the world tilts closer to the ground.',
        'says "Smaller." and becomes faster, harder to pet.' },
    { 'Travel Form',
        'says "Go." and four legs take the weight in one step.',
        'says "Faster." and hooves or paws replace boot-leather with a scrape.' },
    { 'Rebirth',
        'coaxes life back toward %t, and green warmth threads through the air.',
        'says "Not yet." and the ground under %t goes soft with new growth.',
        'tells %t, "The fight isn\'t over. Get up."' },
    { 'Healing Touch',
        'murmurs "Heal." and green warmth spreads through %t like sun through leaves.',
        'says "Easy. Breathe." and the warmth comes in slow, even pulses.' },
    { 'Entangling Roots',
        'asks the ground and green shoots crack through the soil around %t.',
        'tells %t "Stay a while." as vines race up from the turf.',
        'says "Sorry about this." while thorny roots boil up from %t\'s shadow.' },
    { 'Moonfire',
        'calls "Mark." and a thin cold light sinks into %t\'s skin.',
        'barks "Burn bright!" and silver fire dots %t and keeps smouldering.' },
    { 'Hibernate',
        'sings low at %t until the melody goes soft and dragging.',
        'says "Sleep. I\'ll watch." and keeps the hum going under %t\'s ear.' },
    { 'Innervate',
        'says "Take this." and shares focus with %t in a rush of clear-headed air.',
        'says "I\'ve got you." and fills %t with focus that smells of rain on pine.' },
    { 'Mark of the Wild',
        'says "Marked." and %t\'s skin prickles with borrowed toughness.',
        'says "You\'ll need this." and leaves %t smelling of bark and wind.' },
})

pack('shaman', 'Shaman', 'Elements and ancestors.', {
    { 'Lightning Bolt',
        'draws lightning down and the air goes sharp and metallic before it leaves.',
        'barks "Down!" and ozone rolls off %t before the flash.',
        'says "Sorry." and introduces %t to lightning.' },
    { 'Chain Lightning',
        'says "Spread." and the bolt forks with a smell of hot copper.',
        'says "Next." and lets physics argue.' },
    { 'Healing Wave',
        'says "Wash." and cool water shears over %t like a breaking wave.',
        'snaps "Live!" and the wave hits %t with salt and thunder.',
        'says "Hold on." and washes the hurt from %t in one cold rinse.' },
    { 'Ancestral Spirit',
        'speaks over the fallen and ghost-light pools around %t like mist.',
        'says "Not yet." and the air around %t smells of cedar smoke.',
        'tells %t, "Come back. We need you."' },
    { 'Earth Shock',
        'shoves the ground at %t.',
        'snarls "Down!" and a slab of stone-force cracks upward toward %t.' },
    { 'Ghost Wolf',
        'says "Run." and fur ripples up the spine in one pass.',
        'says "Wolf." and pretends that was always the plan.' },
    { 'Bloodlust',
        'counts "One. Two." and beats a rhythm that makes the chest tighten.',
        'roars "Faster!" and the drumbeat hits like a second heartbeat.',
        'says "Feel that?" and starts a drumbeat nobody asked for.' },
    { 'Heroism',
        'shouts "Now!" until veins stand out and the air shivers.',
        'cries "For each other!" and heroism spreads on a warm rush of breath.' },
    { 'Water Walking',
        'speaks over the water until the surface skins over under %t.',
        'says "Step lightly." and the water beneath %t tightens like stretched skin.' },
    { 'Far Sight',
        'says "See." and the world pulls back until the horizon jumps closer.',
        'mutters "There." and peers at the horizon.' },
})

pack('deathknight', 'Death Knight', 'Cold, debts and the risen.', {
    { 'Death Grip',
        'says "Here." and hauls %t in close on a thread of cold.',
        'snarls "Closer!" and the grip arrives like a slammed door of ice.',
        'closes the gap without asking %t\'s opinion, frost at the pull line.' },
    { 'Death Coil',
        'says "Take." and spends a little death on %t in a pulse of winter air.',
        'tosses death at %t and says "Catch."' },
    { 'Raise Dead',
        'says "Rise." and the corpse stirs with a scrape of bone on stone.',
        'snarls "Up!" and the dead climbs up with a rattle of iron.',
        'says "Stand." and the fallen obeys, joints creaking.' },
    { 'Army of the Dead',
        'says "All of you." and the ground gives up its dead in a slow exhale of frost.',
        'roars "Rise!" and the army answers with a sound like grinding ice.',
        'says "Stand with me." and the dead rise, frost on every brow.' },
    { 'Death and Decay',
        'says "Remember." and the ground recalls what it buried.',
        'growls "Rot here!" and the air turns sour with cold decay.' },
    { 'Anti-Magic Shell',
        'says "More." and drinks the magic in until the shell hums.',
        'says "Mine." and eats the spell offered.' },
    { 'Path of Frost',
        'says "Ice." and freezes the water ahead with a crack like glass settling.',
        'says "Mind the step." and frosts the path for those behind.' },
    { 'Mind Freeze',
        'says "Stop." and sends a blade of cold toward %t\'s brow.',
        'snaps "Quiet!" and thrusts cold toward %t at arm\'s length.' },
    { 'Chains of Ice',
        'says "Hold." and wraps %t in river-cold.',
        'binds %t in chains of cold that clink like winter rigging.' },
})

pack('monk', 'Monk', 'Chi, brew and forward momentum.', {
    { 'Roll',
        'rolls aside and says "Clear," landing without a sound.',
        'is elsewhere, and did it gracefully.' },
    { 'Provoke',
        'invites %t to try, with one open palm and no hurry.',
        'gestures at %t and says "Try me."',
        'steps between %t and the others and says "My turn."' },
    { 'Spinning Crane Kick',
        'becomes briefly a problem for everyone nearby.',
        'spins once and says "Room," heels clipping air.',
        'introduces several elbows to several people.' },
    { 'Fortifying Brew',
        'drinks deeply and squares up, breath catching on the burn.',
        'swallows the brew and mutters "Steady."',
        'raises the flask and says "For those behind me."' },
    { 'Resuscitate',
        'breathes the fallen back into the fight, warm air against cold skin.',
        'presses a palm to %t and says "Up," feeling for a heartbeat.',
        'kneels by %t and says "Easy. Breathe."' },
    { 'Touch of Death',
        'touches %t once, and the air goes still.',
        'places a hand on %t and says "Enough," palm flat and quiet.',
        'answers %t with one touch, no follow-through.' },
    { 'Transcendence',
        'leaves a spirit behind and steps away, the echo still breathing.',
        'sets a mark and says "Wait here."' },
    { 'Legacy of the Emperor',
        'passes the old emperor\'s blessing to %t, hands steady as tea poured.',
        'touches %t\'s shoulder and says "You carry it well."' },
})

pack('demonhunter', 'Demon Hunter', 'Fel, wings and momentum.', {
    { 'Fel Rush',
        'crosses the gap in a streak of green fire that leaves the air cold behind it.',
        'says "Now." and launches forward before the word settles.',
        'snarls "Too slow!" and closes the gap in one bound.' },
    { 'Metamorphosis',
        'stops holding the demon in, and the skin cracks along old scar lines.',
        'unfolds into something with wings that throw a shadow twice their span.',
        'roars "Out!" and the wings come free with a crack of displaced air.' },
    { 'Eye Beam',
        'opens both eyes, and fel pours out in a sheet that scorches grass underfoot.',
        'turns the gaze on %t and murmurs "See."',
        'looks at %t with entirely too much honesty.' },
    { 'Blade Dance',
        'turns once, and everything nearby regrets it.',
        'spins the blades and says "Wide." The glaives sing.',
        'snarls "Dance!" and the blades blur until they hum.' },
    { 'Chaos Strike',
        'cuts %t with something that shouldn\'t be a blade.',
        'snarls "Break!" and the chaos lands with a crack like splitting wood.' },
    { 'Imprison',
        'draws sigils around %t until the air between them goes still and glassy.',
        'traces sigils around %t and says "Wait."' },
    { 'Spectral Sight',
        'looks through walls, and the people within.',
        'opens the inner sight, outlines flickering on stone, and whispers "Show me."' },
    { 'Glide',
        'steps off the edge and doesn\'t fall.',
        'spreads the wings and says "Easy." The descent goes quiet.',
        'declines gravity with the wings out.' },
})

pack('evoker', 'Evoker', 'Empowerment and the old flights.', {
    { 'Living Flame',
        'breathes a small, patient flame at %t that clings to cloth and skin.',
        'lifts a hand and says "Burn steady." Smoke threads upward.',
        'sets a modest fire on %t and waits.' },
    { 'Deep Breath',
        'takes a long breath, ribs spreading wide, and then the sky.',
        'roars, and the breath becomes a storm that flattens grass below.',
        'lifts on the breath and calls "Clear below!" Wind rattles cloaks.' },
    { 'Hover',
        'declines to touch the ground for a moment.',
        'rises a little, dust falling from boots, and says "Steady."',
        'floats with the dignity of something that ignores stairs.' },
    { 'Verdant Embrace',
        'wraps %t in green fire that smells of rain on hot stone.',
        'pulls %t close and says "Hold." The warmth comes through at once.',
        'wraps %t in green warmth and murmurs "Stay with me."' },
    { 'Time Spiral',
        'folds a little time into everyone nearby, and footsteps come quicker.',
        'says "Quickly!" and time loosens its grip around the group.' },
    { 'Rescue',
        'picks %t up and carries %t clear, protesting all the way.',
        'says "Hold on." and hauls %t out of the way by the collar.',
        'sweeps %t up and says "Got you."' },
    { 'Fire Breath',
        'exhales the way dragons do.',
        'opens the throat and says "Burn." Heat rolls forward in layers.',
        'breathes fire with entirely too much enthusiasm.' },
})

pack('pets', 'Pets', 'Lines for what your pet does, on any class.', {
    { 'Growl',
        'watches %p decide %t is the problem, fur up along the neck.',
        'lets %f do the talking.',
        'says "Go on, then." and lets %p work the growl loose in its chest.' },
    { 'Claw',
        'watches %p open %t up, claws catching on mail.',
        'shouts "Again!" as %p tears in, claws catching daylight.' },
    { 'Bite',
        'watches %p find the throat.',
        'says "That\'ll do." as %p lets go, reluctantly.' },
    { 'Spell Lock',
        'says nothing; %p bites the spell in half.',
        'snaps "Shut it!" and %p obliges with a snarl.' },
    { 'Devour Magic',
        'watches %p eat the magic off %t, sparks on its teeth.',
        'snaps "Eat it!" and %p does, swallowing the glow.',
        'watches %p have the magic for lunch.' },
    { 'Torment',
        'lets %p do what it enjoys.',
        'shouts "Get in there!" and %p does, all claws and noise.' },
    { 'Suffering',
        'lets %f insist, loudly, on being hit.',
        'says "Brace." and %p takes the weight with a grunt.' },
    { 'Intercept',
        'points, and %p is already moving.',
        'says "Go." and %p goes, paws already in full stride.' },
})

pack('professions', 'Professions & travel', 'The quiet, everyday casts.', {
    { 'Hearthstone',
        'turns the stone over until it warms, and says "Home."',
        'decides that\'s quite enough adventuring.',
        'holds the hearthstone up until the glow fills both hands.' },
    { 'Fishing',
        'casts a line and settles in until the bobber stops dancing.',
        'begins the long and thankless work of fishing.' },
    { 'Mining',
        'sets to the rock with a practised swing, sparks skittering off steel.',
        'negotiates with the rock. The rock loses.' },
    { 'Herb Gathering',
        'takes only what the plant can spare, roots still damp.',
        'robs a plant, gently.' },
    { 'Skinning',
        'works the hide free, carefully, knife warmed by the body heat.',
        'does the part nobody wants to watch.' },
    { 'Cooking',
        'gets a fire going and something over it, grease popping in the pan.',
        'says "There\'s enough for everyone." over a pot already steaming.' },
    { 'First Aid',
        'binds the wound the ordinary way, cloth going pink fast.',
        'says "This will sting." and binds the wound with steady hands.' },
    { 'Disenchant',
        'unmakes it, and keeps the dust that settles on the bench.',
        'turns something perfectly good into dust.' },
    { 'Enchanting',
        'talks the magic into staying put, runes smoking on the metal.',
        'argues with the magic until it settles.' },
})

--@phrases-end@
--=========================================================================--

-- The creed packs -- "For the Horde!", "Elune-adore." -- used to leave a list
-- of spoken lines behind them here, kept because the synthesised audio for them
-- had already been rendered and the picker would only offer lines that had. The
-- synthesiser is gone and nothing is rendered ahead of time any more, so there
-- is nothing for a list of bare words to be the key to. Write the line you want
-- and pin it to one of the game's own recordings.

function CastLibrary.GetPacks()
    return PACKS
end

function CastLibrary.DisplayName(key)
    local rec = byKey[key]
    return rec and rec.display or nil
end

-- Phrases for a spell from every pack the player has opted into.
function CastLibrary.GetPhrases(key)
    local out = {}
    local rec = key and byKey[key]
    if not rec then return out end
    local Casts = ns.Casts
    if not Casts then return out end
    for _, entry in ipairs(rec.entries) do
        if Casts.IsPackEnabled(entry.pack) then out[#out + 1] = entry end
    end
    return out
end

-- Every spell covered by an enabled pack. Snapshots the list up front so the
-- caller can tick packs while iterating without surprises.
function CastLibrary.EachEnabledKey()
    local keys = {}
    local Casts = ns.Casts
    if Casts then
        for key, rec in pairs(byKey) do
            for _, entry in ipairs(rec.entries) do
                if Casts.IsPackEnabled(entry.pack) then
                    keys[#keys + 1] = key
                    break
                end
            end
        end
    end
    local i = 0
    return function()
        i = i + 1
        return keys[i]
    end
end

-- The pack matching the player's class, so the panel can show the obvious one
-- instead of making them read fourteen checkboxes. Matched on the
-- locale-independent class token from UnitClass.
function CastLibrary.PackForPlayer()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok or type(token) ~= "string" then return nil end
    return CLASS_PACKS[token:upper()]
end

