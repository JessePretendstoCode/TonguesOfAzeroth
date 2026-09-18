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

    Tone:
      Lines are grouped by Bearing -- plain, dry, fierce, solemn, warm -- and may
      carry a Wording tag of courtly or blunt. The player's character sheet
      picks a primary Bearing and optionally a second, and those groups rise to
      the top of the roll while the rest drop out. The exception is `plain`,
      which is the neutral backbone: those lines suit anyone and stay in the
      roll whatever the sheet says, which is what lets a spell get away with
      having no Fierce reading at all.

      Write for the Bearing, not around it. A Dry line should be funny because
      of the understatement, not because it has a joke bolted on; a Solemn one
      should carry weight without turning the character into a villain. Nothing
      here should assume WHY the character fights, which is what the creed packs
      are for -- keep faction and religion out of the class packs entirely.

      Avoid pronouns. The emote reads "<Name> <your line>", and "their" lands
      oddly in that frame, so prefer phrasings that need no pronoun at all.
---------------------------------------------------------------------------]]

local ADDON, ns = ...

local CastLibrary = {}
ns.CastLibrary = CastLibrary

local PACKS = {}
local byKey = {}
local wildcards = {}

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

-- Bearings, in the order they're written and displayed. "plain" is special: it
-- is both a Bearing you can choose and the neutral backbone, so plain lines
-- stay eligible whatever the character's Bearing is. Every other group is
-- suppressed entirely unless it matches -- see Casts.ToneWeight.
local BEARINGS = { "plain", "dry", "fierce", "solemn", "warm" }
CastLibrary.BEARINGS = BEARINGS

--   { "Spell Name",
--       plain  = { "does the thing." },
--       fierce = { 'roars "Now!" and does the thing.' },
--       solemn = { { "performs the rite.", "courtly" } },
--   }
--
-- A line is either a bare string or { text, wording } when it also wants a
-- Wording tag. Bearings may be left out: a spell with no sensible Fierce
-- reading is better off with a gap, since the plain group always plays.
--
-- Each pack keeps `list`, its spells in the order written here, as well as
-- feeding the flat byKey lookup the game reads. The ordered copy is what
-- tools/dump_phrases.lua turns into PHRASES.md for review, so the document and
-- the shipped lines can't drift apart.
local function addLines(sink, id, bearing, lines, counter, wildcard)
    for _, line in ipairs(lines) do
        local text, wording = line, nil
        if type(line) == "table" then text, wording = line[1], line[2] end
        sink[#sink + 1] = {
            pack = id, text = text, bearing = bearing, wording = wording,
            wildcard = wildcard or nil,
        }
        if counter then counter[#counter + 1] = { text = text, bearing = bearing, wording = wording } end
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
        local written = {}
        if type(entry[2]) == "string" then
            -- Shorthand: a bare list of lines after the spell name means they
            -- are all `plain`. Handy for a spell whose lines suit anyone, and
            -- what every pack looked like before Bearings existed.
            local flat = {}
            for i = 2, #entry do flat[#flat + 1] = entry[i] end
            addLines(rec.entries, id, "plain", flat, written)
        end
        for _, bearing in ipairs(BEARINGS) do
            if entry[bearing] then
                addLines(rec.entries, id, bearing, entry[bearing], written)
            end
        end
        p.phrases = p.phrases + #written
        p.list[#p.list + 1] = { name = spellName, phrases = written }
        p.spells = p.spells + 1
    end
    PACKS[#PACKS + 1] = p
end

-- A creed pack: lines tied to no spell in particular, which ride along on
-- whichever spells you've already set up. This is the only way a cry like "For
-- the Horde!" can work -- it belongs to a character, not to a spell. Wildcard
-- lines carry a lower base weight than a spell's own, so ticking a creed
-- seasons your casts rather than taking them over.
local function creed(id, name, note, groups)
    local p = {
        id = id, name = name, note = note, spells = 0, phrases = 0,
        kind = "creed", list = {},
    }
    local written = {}
    for _, bearing in ipairs(BEARINGS) do
        if groups[bearing] then
            addLines(wildcards, id, bearing, groups[bearing], written, true)
        end
    end
    p.phrases = #written
    p.list[#p.list + 1] = { name = name, phrases = written }
    PACKS[#PACKS + 1] = p
end

--=========================================================================--
--@phrases-begin@  (everything to @phrases-end@ is rewritten by
--                  tools/apply_phrases.lua from PHRASES.md -- edit that, or
--                  edit here and re-run tools/dump_phrases.lua to match)

pack('warlock', 'Warlock', 'Fel magic, pacts and pets.', {
    { 'Immolate',
        plain  = { 'sets %t alight, and the heat rolls back over anyone standing close.',
                   'traces a sigil that keeps smouldering after the hand has moved on.' },
        dry    = { 'sets %t on fire and waits for the complaining to start.' },
        fierce = { 'snarls "Burn!" and the fire takes with a crack like wet wood.',
                   { 'shoves a fistful of fire into %t and shakes the ash off after.', 'blunt' } },
        solemn = { { 'speaks the word of burning over %t, unhurried as a sentence read aloud.', 'courtly' } },
        warm   = { 'warns %t, "Stand back." and lets the fire go.' } },
    { 'Shadow Bolt',
        plain  = { 'gathers the dark into one point and lets it go with a thump of cold air.',
                   'hurls a bolt of shadow that takes the warmth out of the air behind it.' },
        dry    = { 'throws shadow at %t with the bored accuracy of someone posting a letter.' },
        fierce = { { 'barks "Down!" and the shadow arrives like a slammed door.', 'blunt' } },
        solemn = { { 'calls upon the dark, and it answers before the words are finished.', 'courtly' } },
        warm   = { 'says "Nothing personal." and lets the bolt fly.' } },
    { 'Corruption',
        plain  = { 'sets something patient working inside %t, slow as rot in a rafter.',
                   'murmurs "Give it time." and leaves it to work.' },
        dry    = { 'gives %t something to think about in an hour or so.' },
        fierce = { { 'spits "Rot." and the word seems to stick.', 'blunt' } },
        solemn = { { 'speaks a slow ruin into %t, one word at a time.', 'courtly' } },
        warm   = { 'tells %t, "This would have been kinder quickly."' } },
    { 'Fear',
        plain  = { 'speaks a word %t was never meant to hear, and %t stops hearing anything else.',
                   'meets %t and says, evenly, "Go."' },
        dry    = { 'suggests, mildly, that %t has somewhere else to be.' },
        fierce = { { 'roars, and whatever %t sees in that moment is enough.', 'blunt' } },
        solemn = { { 'shows %t one true thing, and %t will not look at it twice.', 'courtly' } },
        warm   = { 'says "Run. Go on." and means it.' } },
    { 'Drain Life',
        plain  = { 'closes a hand and draws the warmth out of %t in a thin grey thread.' },
        dry    = { 'borrows a little life from %t, indefinitely.' },
        fierce = { { 'snarls "Mine." and does not let go until it is.', 'blunt' } },
        solemn = { { 'takes only what %t owes, and counts it out.', 'courtly' } },
        warm   = { 'says "I will be needing that." almost apologetically.' } },
    { 'Health Funnel',
        plain  = { 'opens a vein for %p without hesitating, and goes grey doing it.' },
        dry    = { 'donates blood, involuntarily, to %p.' },
        fierce = { { 'growls "Stay up!" and pours until %p stops shaking.', 'blunt' } },
        solemn = { { 'pays %p in blood, as was agreed, down to the last drop owed.', 'courtly' } },
        warm   = { 'tells %p, "Hold on. Nearly there."' } },
    { 'Hellfire',
        plain  = { 'spreads both arms and lets the fire spill outward until the stone underfoot goes black.' },
        dry    = { 'sets everything on fire, including the obvious, including both boots.' },
        fierce = { 'bellows "Burn with me!" and lets go of the last of it, wreathed to the shoulders.' },
        solemn = { { 'offers up the ground itself to the fire, and the fire does not refuse.', 'courtly' } },
        warm   = { 'says "Everyone back." a moment too late.' } },
    { 'Soulstone',
        plain  = { 'folds a soul into stone until the stone sits warm. "In case it comes to that."' },
        dry    = { 'puts a little of %t somewhere safe. Insurance.' },
        fierce = { 'says "You are not dying today." and binds the stone hard enough to crack it.' },
        solemn = { { 'binds the soul of %t to stone against what is coming, and names the hour.', 'courtly' } },
        warm   = { 'presses the stone into %t\'s hand. "Just in case."' } },
    { 'Create Healthstone',
        plain  = { 'works a small red stone out of nothing, still slick from the making.' },
        dry    = { 'produces a stone that tastes worse than the wound it mends.' },
        solemn = { { 'shapes a stone, and the shaping costs something that does not grow back.', 'courtly' } },
        warm   = { 'makes a stone for whoever needs it first, and holds it out.' } },
    { 'Summon Felhunter',
        plain  = { 'opens the air and %f steps through it, nose first.',
                   'calls %p up, and %p arrives hungry and in no particular hurry.' },
        dry    = { 'opens the air. %p is late, as usual.' },
        fierce = { 'tears the air open and %f comes through snarling before all four feet land.' },
        solemn = { { 'calls %p by its true name, and the name is enough.', 'courtly' } },
        warm   = { 'greets %p like an old dog. "There you are."' } },
    { 'Summon Voidwalker',
        plain  = { 'draws something vast and unhurried into the light, and the light gives way for it.' },
        dry    = { 'summons %p, who could not be less impressed.' },
        fierce = { { 'hauls %f out of the dark by force, hand over hand.', 'blunt' } },
        solemn = { { 'calls the void, and a piece of it consents to be shaped.', 'courtly' } },
        warm   = { 'says "Good. You are here." to %p.' } },
    { 'Summon Imp',
        plain  = { 'summons %p, already mid-complaint about the weather.' },
        dry    = { 'summons %p, and immediately regrets it.' },
        fierce = { 'snaps %p into the world by the scruff and tells it to keep up.' },
        solemn = { { 'calls the least of them, and even the least attends.', 'courtly' } },
        warm   = { 'says "Behave." to %p, hopefully.' } },
    { 'Ritual of Summoning',
        plain  = { 'chalks the circle and says "Mind the edges."' },
        dry    = { 'draws a circle and waits for someone to stand in it wrong.' },
        fierce = { { 'barks "Two of you. Here. Now." and taps the chalk line twice.', 'blunt' } },
        solemn = { { 'sets the circle, speaks the summoning, and steps back to let it work.', 'courtly' } },
        warm   = { 'says "Come on through, it is safe." and holds the circle open.' } },
})

pack('mage', 'Mage', 'Fire, frost and the arcane.', {
    { 'Fireball',
        plain  = { 'lobs a fireball that leaves the air tasting of soot.',
                   'shapes a sphere of fire and lets it go with a pop of heat.' },
        dry    = { 'throws fire at %t, as is traditional.' },
        fierce = { { 'barks "Move!" and the fire goes anyway, hot enough to peel paint.', 'blunt' } },
        solemn = { { 'speaks the fire into being, and the sparks cling to the sleeve.', 'courtly' } },
        warm   = { 'says "Mind yourself." and lets it fly before the heat rolls back.' } },
    { 'Frostbolt',
        plain  = { 'exhales, and the air cracks with cold.',
                   'hurls a bolt of frost at %t that leaves rime on the nearest stone.' },
        dry    = { 'cools %t down, somewhat abruptly.' },
        fierce = { 'snaps "Enough!" and frost answers with a crack like thin ice.' },
        solemn = { { 'speaks cold into the air until breath starts to frost in front of the lips.', 'courtly' } },
        warm   = { 'says "Hold still." and lets the frost go in a white hiss.' } },
    { 'Pyroblast',
        plain  = { 'takes a long breath, and the whole room pulls toward the hands.',
                   'builds fire into one terrible point and releases it in a roar of displaced air.' },
        dry    = { 'promises %t "This one will hurt." and keeps the promise.' },
        fierce = { { 'bellows "Burn!" and lets the blast go hard enough to stagger anyone close.', 'blunt' } },
        solemn = { { 'raises the fire with both hands until the heat bends the view around it.', 'courtly' } },
        warm   = { 'says "Mind the blast radius." a little late.' } },
    { 'Polymorph',
        plain  = { 'rewrites %t into something woollier.',
                   'gestures at %t and threads the changing spell through the air like ribbon.' },
        dry    = { 'turns %t into something with fewer opinions.' },
        fierce = { 'snaps "Quiet!" and the changing spell leaves hoofprints in the dust.' },
        solemn = { { 'speaks a word of changing over %t, and the wool smell arrives before anything else.', 'courtly' } },
        warm   = { 'says "Sit. Stay." and sends the changing spell off like a well-trained thought.' } },
    { 'Blink',
        plain  = { 'steps sideways out of the world and back into it, leaving frost on the boots.' },
        dry    = { 'was there. Was not. "Excuse me."' },
        fierce = { { 'tears sideways through the air and leaves a cold spot where the body was.', 'blunt' } },
        warm   = { 'says "Pardon." and is suddenly elsewhere, dust still settling where they stood.' } },
    { 'Counterspell',
        plain  = { 'cuts the air with two fingers and says "No."',
                   'flings a sharp silence at the spell leaving %t\'s lips.' },
        dry    = { 'interrupts %t mid-thought. As one does.' },
        fierce = { { 'barks "No!" and snaps the spell thread before it finishes.', 'blunt' } },
        solemn = { { 'speaks the word of ending at the spell still leaving %t\'s hands.', 'courtly' } },
        warm   = { 'says "Not that one." and folds the spell shut like paper.' } },
    { 'Ice Block',
        plain  = { 'pulls the winter in and holds still while breath fogs against the ice.' },
        dry    = { 'becomes temporarily unavailable.' },
        fierce = { { 'slams the cold shut around them and waits, visible only as a blur inside.', 'blunt' } },
        solemn = { { 'folds into ice and holds, frost creeping outward from the feet.', 'courtly' } },
        warm   = { 'mutters "Not today." and freezes solid with a sharp crack of settling ice.' } },
    { 'Arcane Intellect',
        plain  = { 'taps %t on the brow. "Try to keep up."' },
        dry    = { 'taps %t and says "Pay attention."' },
        solemn = { { 'speaks clarity over %t, and the eyes focus as if waking from a nap.', 'courtly' } },
        warm   = { 'says "You will need this." and leaves %t blinking at the sudden clarity.' } },
    { 'Blizzard',
        plain  = { 'raises both hands and calls the storm down until the hail pings off armor.' },
        dry    = { 'calls down snow and says "Sorry about this."' },
        fierce = { 'shouts "Fall!" and the snow comes down hard enough to sting exposed skin.' },
        solemn = { { 'calls the winter from above, and the temperature drops before the first flake.', 'courtly' } },
        warm   = { 'warns "Incoming snow." a moment too late.' } },
    { 'Conjure Refreshment',
        plain  = { 'conjures food out of thin air, as one does.' },
        dry    = { 'mutters "It is edible." and conjures food.' },
        warm   = { 'says "You look hungry." and conjures a snack that steams faintly.' } },
    { 'Slow Fall',
        plain  = { 'says "Mind the landing." a little too late.' },
        dry    = { 'calls "Slowly!" down at %t.' },
        warm   = { 'calls "Easy now." down at %t and threads a gentle lift into the fall.' } },
})

pack('priest', 'Priest', 'Light, shadow and the words between.', {
    { 'Power Word: Shield',
        plain  = { 'speaks a word over %t and something closes around %t with a faint hum.',
                   'lays a hand on %t. "Stand."' },
        dry    = { 'gives %t something to lean on, briefly.' },
        fierce = { { 'snaps "Hold!" and the ward snaps shut with a pressure like deep water.', 'blunt' } },
        solemn = { { 'speaks the word of warding over %t, and the air hardens around the skin.', 'courtly' } },
        warm   = { 'says "You are not alone in this." and a steady warmth settles on %t.' } },
    { 'Flash Heal',
        plain  = { 'pours warmth into %t, quick enough to make %t gasp.',
                   'says "Not today." and presses golden warmth into the worst of the hurt.' },
        dry    = { 'patches %t up before the complaining starts.' },
        fierce = { { 'barks "Stay up!" and slams the mending in hard enough to jar teeth.', 'blunt' } },
        solemn = { { 'speaks mending over %t, fast and sure as a seam pulled tight.', 'courtly' } },
        warm   = { 'says "There. Breathe." and leaves steady warmth where the pain was sharpest.' } },
    { 'Renew',
        plain  = { 'murmurs "Rest a moment." over %t.',
                   'leaves a small warmth behind in %t, like sunlight on the back of the neck.' },
        dry    = { 'tells %t, "Give it time."' },
        solemn = { { 'sets a slow mending working in %t, deep as warmth under bruised skin.', 'courtly' } },
        warm   = { 'says "Easy does it." and lets the warmth linger like a blanket left on.' } },
    { 'Resurrection',
        plain  = { 'kneels, breathes warmth back toward still lungs, and asks for one more.',
                   'tells the fallen, "Come back. We are not finished."' },
        dry    = { 'insists %t was not finished yet.' },
        fierce = { { 'demands "Up!" into the stillness and will not stop until something moves.', 'blunt' } },
        solemn = { { 'speaks the word of return over %t, voice steady as rope paid out by hand.', 'courtly' } },
        warm   = { 'says "Come on. We still need you." and keeps speaking until warmth returns.' } },
    { 'Shadow Word: Pain',
        plain  = { 'lets a thread of shadow settle into %t like grit under a nail.',
                   'breathes something short and sharp over %t that tastes wrong in the mouth.' },
        dry    = { 'murmurs "Remember this." over %t.' },
        fierce = { { 'hisses "Hurt." and the shadow bites deep enough to leave a cold spot.', 'blunt' } },
        solemn = { { 'speaks pain into %t, quietly and without mercy, one syllable at a time.', 'courtly' } } },
    { 'Mind Blast',
        plain  = { 'looks at %t and pushes, and the thought arrives like a fist through a wall.' },
        dry    = { 'introduces %t to an unwelcome thought.' },
        fierce = { { 'slams "Out!" into %t\'s thoughts hard enough to ring skull-bone.', 'blunt' } },
        solemn = { { 'speaks force into %t\'s skull until ears ring on both sides.', 'courtly' } } },
    { 'Psychic Scream',
        plain  = { 'screams without making a sound.' },
        dry    = { 'lets out a scream no one enjoys hearing.' },
        fierce = { 'screams "Go!" without making a sound, and the pressure rolls outward anyway.' } },
    { 'Mind Control',
        plain  = { 'settles into %t\'s thoughts and takes the reins, cold as a hand on the nape.' },
        dry    = { 'borrows %t\'s body for a little while.' },
        fierce = { { 'snaps "Mine." and threads will through %t\'s fingers from the inside.', 'blunt' } },
        solemn = { { 'enters %t\'s mind and assumes the place, uninvited as frost on glass.', 'courtly' } } },
    { 'Dispel Magic',
        plain  = { 'says "Hold still." and brushes the magic off %t in a shower of sparks.' },
        dry    = { 'picks the wrong magic off %t, patiently.' },
        fierce = { { 'barks "Out!" and scrapes the magic away until the skin prickles clean.', 'blunt' } },
        solemn = { { 'speaks cleansing over %t, and the taint lifts like smoke off wet stone.', 'courtly' } },
        warm   = { 'says "There. Better." and brushes the last of the wrongness from %t.' } },
    { 'Fade',
        plain  = { 'becomes markedly less interesting.' },
        dry    = { 'steps out of the foreground. "Who?"' } },
    { 'Levitate',
        plain  = { 'says "Mind the landing." and sends lightness into %t\'s bones.' },
        dry    = { 'puts %t somewhere slightly above the ground.' },
        solemn = { { 'speaks lightness into %t\'s bones until the feet forget weight.', 'courtly' } },
        warm   = { 'says "Easy now." and eases %t upward on a thread of calm.' } },
})

pack('warrior', 'Warrior', 'Shouts, charges and bad ideas.', {
    { 'Charge',
        plain  = { 'picks %t out of the crowd and runs at it, boots throwing sparks off the flagstones.',
                   'closes the gap in one rush, shoulder tucked and mud kicking off the mail.' },
        dry    = { 'says "Coming through!" and runs at %t with the urgency of someone late for dinner.' },
        fierce = { 'roars "Out of my way!" and closes the gap in a skid of dust and armour.' } },
    { 'Battle Shout',
        plain  = { 'bellows "With me!" loud enough to hurt.',
                   'shouts until the stone rings and armour stops rattling.' },
        dry    = { 'raises the volume until courage seems plausible.' },
        fierce = { { 'bellows "Fight!" until the ground shakes.', 'blunt' } },
        solemn = { { 'speaks one word, and it carries to the back of the hall.', 'courtly' } },
        warm   = { 'says "We have this." and sells it with a nod nobody argues with.' } },
    { 'Taunt',
        plain  = { 'points at %t and says "Me. Try me."',
                   'insults %t\'s mother, thoroughly.' },
        dry    = { 'calls %t "Over here!" with feeling.' },
        fierce = { { 'spits "Try me!" at %t, knuckles white on the haft.', 'blunt' } } },
    { 'Execute',
        plain  = { 'looks down at %t and says "Done." with breath still fogging the visor.' },
        dry    = { 'finishes what %t started.' },
        fierce = { { 'barks "Down!" and puts every ounce of weight behind the blow.', 'blunt' } },
        solemn = { { 'passes sentence with one stroke that rings through the gauntlet.', 'courtly' } } },
    { 'Shield Wall',
        plain  = { 'sets both feet on gravel until they stop sliding. "Nothing gets past."' },
        dry    = { 'becomes temporarily inconvenient to kill.' },
        fierce = { { 'plants the shield and dares anything through, boots dug to the ankle.', 'blunt' } },
        solemn = { { 'holds the line and does not yield, even when the rim begins to dent.', 'courtly' } },
        warm   = { 'says "Behind me." and raises the shield until the strap creaks.' } },
    { 'Intimidating Shout',
        plain  = { 'roars, and something in it is not entirely human.' },
        dry    = { 'screams until nearby plans change.' },
        fierce = { 'bellows "Run!" until the rafters answer.' } },
    { 'Thunder Clap',
        plain  = { 'brings the ground up to meet everyone in a jar of teeth and dust.' },
        dry    = { 'says "Down!" and brings the ground up.' },
        fierce = { { 'roars "Down!" and cracks the earth.', 'blunt' } } },
    { 'Berserker Rage',
        plain  = { 'stops pretending to be reasonable.' },
        dry    = { 'mutters "Fine." and stops being careful.' },
        fierce = { { 'snarls "More!" and the grip on the haft goes white-knuckled.', 'blunt' } } },
    { 'Heroic Throw',
        plain  = { 'throws an axe and shouts "Catch!" The haft hums once leaving the hand.' },
        dry    = { 'tosses steel at %t. Enthusiastically.' },
        fierce = { { 'hurls the axe and roars "Take it!" with a wrist snap that pops.', 'blunt' } } },
    { 'Victory Rush',
        plain  = { 'spits, grins, and keeps going.' },
        dry    = { 'finds a second wind and spends it immediately.' },
        fierce = { { 'barks "Again!" and surges forward on bloodied boots.', 'blunt' } },
        warm   = { 'says "Not done yet." and presses on through the ache.' } },
})

pack('paladin', 'Paladin', 'Oaths, hammers and judgement.', {
    { 'Lay on Hands',
        plain  = { 'presses both hands to %t and gives everything, heat draining out through the palms.',
                   'says "Take mine." and means it, even when the knees go soft.' },
        dry    = { 'mutters "All of it." and presses both hands to %t until the palms go numb.' },
        fierce = { { 'barks "Stay up!" and pours it in until the hands tremble.', 'blunt' } },
        solemn = { { 'places both palms on %t and pays in full, down to the last warmth owed.', 'courtly' } },
        warm   = { 'tells %t, "Not your turn yet." and does not let go.' } },
    { 'Hammer of Justice',
        plain  = { 'brings the hammer down on %t with a crack like wet timber.',
                   'says "Kneel." and swings before the word finishes.' },
        dry    = { 'says "Down." and invites %t to reconsider footing.' },
        fierce = { { 'roars "Down!" and the hammer lands hard enough to ring.', 'blunt' } },
        solemn = { { 'pronounces the blow before it lands, word by measured word.', 'courtly' } },
        warm   = { 'says "Sit this one out." and raises the hammer overhead.' } },
    { 'Consecration',
        plain  = { 'marks the ground and dares anyone to cross it, ash curling at the boot toes.',
                   'sprinkles the circle and holds the line until the stone begins to glow.' },
        dry    = { 'claims the ground and mutters "Mine."' },
        fierce = { 'shouts "This far!" and burns the border into the flagstones.' },
        solemn = { { 'sets the ward into the ground and waits, unmoving as a boundary stone.', 'courtly' } },
        warm   = { 'says "Stand inside." and lays the ward in a careful ring.' } },
    { 'Divine Shield',
        plain  = { 'is briefly, gloriously untouchable.',
                   'says "Not today." and locks the shell shut with a soft click.' },
        dry    = { 'becomes the most irritating target in reach.' },
        fierce = { 'snaps "Try me." behind the barrier, fist on the rim.' },
        solemn = { { 'raises the shield and stands unmoved, even as blows skid off.', 'courtly' } },
        warm   = { 'says "Give me a moment." inside the glow, voice muffled by glass.' } },
    { 'Redemption',
        plain  = { 'kneels by the fallen and refuses to let go, hands sunk past the wrist in cold earth.',
                   'tells the dead "Get up. Not yet."' },
        dry    = { 'argues death into a brief recess.' },
        fierce = { { 'barks "Back!" at the stillness, knuckles bloody on the breastplate.', 'blunt' } },
        solemn = { { 'speaks over the fallen, word by word, unhurried as an oath read aloud.', 'courtly' } },
        warm   = { 'says "We are not done." and pulls %t back from the edge by the wrist.' } },
    { 'Judgement',
        plain  = { 'passes sentence on %t without raising voice, one flat syllable at a time.',
                   'looks at %t and says "Verdict." with no room left to argue.' },
        dry    = { 'renders %t\'s account in one stroke that chips the pauldron.' },
        fierce = { { 'snaps "Guilty." and strikes before the echo fades.', 'blunt' } },
        solemn = { { 'speaks the sentence before the blow, each word weighed.', 'courtly' } },
        warm   = { 'tells %t, "This could have gone differently." and means it.' } },
    { 'Avenging Wrath',
        plain  = { 'unfurls power and stops holding back, wings throwing heat against the face.',
                   'says "Enough." and means it now, voice stripped to bare metal.' },
        dry    = { 'says "No more." and becomes visibly less negotiable, glow included.' },
        fierce = { 'roars and lets the wrath show, heat rippling off the pauldrons.' },
        solemn = { { 'calls the full weight down and stands in it, unblinking.', 'courtly' } },
        warm   = { 'says "Behind me." and steps forward until the ground scorches underfoot.' } },
    { 'Blessing of Might',
        plain  = { 'lays a blessing on %t like a hand on a shoulder, grip firm through the mail.',
                   'touches %t and says "Stronger." like a promise kept.' },
        dry    = { 'hands %t a little more than %t had, no receipt required.' },
        fierce = { 'barks "Fight." into %t\'s ear loud enough to sting.' },
        solemn = { { 'speaks strength over %t, word by word, until the breath steadies.', 'courtly' } },
        warm   = { 'tells %t, "You have got this." and makes it sound true.' } },
    { 'Hand of Protection',
        plain  = { 'puts a wall between %t and the world, palm flat against the air.',
                   'wraps %t in something nothing passes, humming at the edge of hearing.' },
        dry    = { 'makes %t temporarily everybody else\'s problem.' },
        fierce = { { 'snaps "Not %t!" and shields with an arm still ringing from the last blow.', 'blunt' } },
        solemn = { { 'places the ward on %t and holds it, unmoved as a locked gate.', 'courtly' } },
        warm   = { 'says "Stay behind me." and seals %t in with a gentle push.' } },
    { 'Devotion Aura',
        plain  = { 'stands a little straighter, and so does everyone near, boots finding the same beat.',
                   'sets the pace and others match it, step for step on the flagstones.' },
        dry    = { 'says "Closer." and makes standing near look wise.' },
        fierce = { { 'barks "Hold!" and the line stiffens like a drawn bow.', 'blunt' } },
        solemn = { { 'holds the centre until others find it, anchor-weight and steady.', 'courtly' } },
        warm   = { 'says "Stay close." and means stay close, shoulder to shoulder.' } },
})

pack('hunter', 'Hunter', 'Marks, traps and one good animal.', {
    { 'Hunter\'s Mark',
        plain  = { 'marks %t and says, quietly, "There you are," thumb still on the bowstring.',
                   'sets the mark on %t and does not look away, even when %t moves.' },
        dry    = { 'labels %t for later. Much later.' },
        fierce = { { 'snaps "Found you." and marks %t before %t knows.', 'blunt' } },
        solemn = { { 'marks %t once, and that is enough.', 'courtly' } },
        warm   = { 'says "Got you." softly over the mark, hand on %p\'s flank.' } },
    { 'Aimed Shot',
        plain  = { 'breathes out, and lets the arrow go with a sharp twang.',
                   'says "Steady." and takes the long shot, wind in the fletching.' },
        dry    = { 'takes the shot %t was hoping nobody would take.' },
        fierce = { { 'snaps "Got it." and looses before the bowstring stops humming.', 'blunt' } },
        solemn = { { 'draws, holds, and looses on the exhale.', 'courtly' } },
        warm   = { 'says "Quick, at least." and looses with an apologetic shrug.' } },
    { 'Multi-Shot',
        plain  = { 'looses three arrows in the time most need one, quiver rattling.',
                   'says "All three." and the air goes full of whistling.' },
        dry    = { 'sends three answers to a question nobody asked.' },
        fierce = { { 'barks "All of you!" and looses until the string burns.', 'blunt' } },
        solemn = { { 'fires once, twice, thrice, each on the breath.', 'courtly' } },
        warm   = { 'says "Spread out." after the volley, ears still ringing.' } },
    { 'Freezing Trap',
        plain  = { 'sets the trap and steps back before the cold catches.',
                   'says "Wait for it." and watches, breath held.' },
        dry    = { 'leaves %t a surprise on the ground.' },
        fierce = { 'snaps "Hold still." and arms the trap with a click like teeth.' },
        solemn = { { 'lays the snare and waits on the frost to climb the wire.', 'courtly' } },
        warm   = { 'mutters "Careful there." over the trigger, palm flat.' } },
    { 'Feign Death',
        plain  = { 'is, regrettably, dead.',
                   'drops and plays dead, going limp mid-breath.' },
        dry    = { 'plays dead and mutters "Convincing enough."' },
        fierce = { { 'hits the ground hard and shouts "Wound!"', 'blunt' } },
        warm   = { 'says "Not me." and goes limp with the arrow still in the quiver.' } },
    { 'Mend Pet',
        plain  = { 'checks %p over, fingers in the fur, and says "You\'ll do."',
                   'digs the arrowhead out of %p, gently.' },
        dry    = { 'patches %p up with less fuss than %p deserves.' },
        fierce = { { 'growls "Stay up, %p." through a mouthful of cloth.', 'blunt' } },
        solemn = { { 'works over %p until the breathing evens out.', 'courtly' } },
        warm   = { 'tells %p, "Almost good as new," and %p leans into the hand.' } },
    { 'Revive Pet',
        plain  = { 'refuses to let %p go, and is not asking.',
                   'whispers "Not you. Get up." to %p with blood on the gloves.' },
        dry    = { 'argues %p back into the fight.' },
        fierce = { { 'snaps "Up, %p!" and pulls against the weight.', 'blunt' } },
        solemn = { { 'speaks over %p until the chest rises once.', 'courtly' } },
        warm   = { 'says "Come back." to %p and waits, hand on the scruff.' } },
    { 'Call Pet',
        plain  = { 'whistles once, and %p comes running through the brush.',
                   'calls %p by name and %p answers with a bark.' },
        dry    = { 'whistles once and says "Late again, %p."' },
        fierce = { { 'barks "Here, %p!" sharp enough to carry.', 'blunt' } },
        solemn = { { 'calls %p once, and %p attends.', 'courtly' } },
        warm   = { 'says "There you are." when %p arrives, mud on both.' } },
    { 'Misdirection',
        plain  = { 'points %p at %t with two fingers, no shout needed.',
                   'directs %p toward %t without raising voice, only a click.' },
        dry    = { 'lets %p take the credit %t was saving for %p.' },
        fierce = { { 'snaps "Go." at %p and %p is already moving.', 'blunt' } },
        warm   = { 'tells %p, "That one." and steps aside with a hand on %p\'s neck.' } },
    { 'Disengage',
        plain  = { 'leaves, at speed, and calls it tactics.',
                   'says "Out." and springs backward, boots skidding on stone.' },
        dry    = { 'decides %t can keep this problem.' },
        fierce = { { 'barks "Not today!" and leaps back before the blade lands.', 'blunt' } },
        solemn = { { 'retreats one bound, already counting again.', 'courtly' } },
        warm   = { 'says "Cover me." on the way out, arrow nocked behind.' } },
})

pack('rogue', 'Rogue', 'Quiet work.', {
    { 'Stealth',
        plain  = { 'is no longer quite where you were looking, only the curtain moving.',
                   'says "Gone." and slips out of sight without a footfall.' },
        dry    = { 'was never in that spot. "Must have been someone else."' },
        fierce = { { 'drops out of view mid-step, before you finish the thought.', 'blunt' } },
        warm   = { 'says "Quiet now." and fades into the wall shadow.' } },
    { 'Sap',
        plain  = { 'slips behind %t and offers the weighted cosh without a sound.',
                   'catches %t unawares and lets the bag fall on a held breath.' },
        dry    = { 'introduces %t to a short nap.' },
        fierce = { { 'brings the cosh up and hisses "Sleep."', 'blunt' } },
        solemn = { { 'places the cosh against %t without a sound.', 'courtly' } },
        warm   = { 'whispers "Rest." at %t\'s ear, breath held.' } },
    { 'Vanish',
        plain  = { 'was never here. Ask anyone.',
                   'says "Nowhere." and steps out of the room mid-stride.' },
        dry    = { 'leaves no witness and murmurs "Forget it."' },
        fierce = { { 'cuts away mid-step. Gone.', 'blunt' } },
        warm   = { 'says "Forget me." and is gone before the echo.' } },
    { 'Pick Pocket',
        plain  = { 'admires %t\'s coin purse. Briefly.',
                   'says "Mine now." and relieves %t of a coin\'s weight.' },
        dry    = { 'borrows from %t and whispers "Thanks."' },
        fierce = { { 'takes what %t was not holding tight, fingers already moving.', 'blunt' } },
        warm   = { 'mutters "Finders keepers." and moves on.' } },
    { 'Kidney Shot',
        plain  = { 'finds the spot below the ribs without a word.',
                   'finds the spot and says "There."' },
        dry    = { 'reminds %t where the kidneys are. "Here."' },
        fierce = { { 'snarls "Down." and strikes below the ribs.', 'blunt' } },
        solemn = { { 'lands the fist below the ribs and lets silence follow.', 'courtly' } },
        warm   = { 'says "Stay down." and walks away.' } },
    { 'Eviscerate',
        plain  = { 'finishes close and fast, blade still warm.',
                   'says "Last one." and works %t over at arm\'s length.' },
        dry    = { 'closes the account and mutters "Paid."' },
        fierce = { { 'spits "Done." and cuts deep enough to feel.', 'blunt' } },
        solemn = { { 'ends the cut cleanly, up close.', 'courtly' } },
        warm   = { 'says "Sorry." and finishes anyway.' } },
    { 'Blind',
        plain  = { 'throws powder and says "Look away," hand already empty.',
                   'throws a handful of dust at %t\'s face.' },
        dry    = { 'takes %t\'s eyes off the matter at hand.' },
        fierce = { { 'snaps "Eyes down!" and throws a stinging handful.', 'blunt' } },
        solemn = { { 'throws the dust and waits on the dark.', 'courtly' } },
        warm   = { 'says "This will sting." before the powder leaves the hand.' } },
    { 'Sprint',
        plain  = { 'decides this is someone else\'s problem now.',
                   'says "Not today." and breaks into a run, heels flashing.' },
        dry    = { 'reassigns the chase and calls "Too slow!"' },
        fierce = { { 'snaps "Move!" and bolts before the shout fades.', 'blunt' } },
        warm   = { 'says "Tell them I went east." and runs, coin purse bouncing.' } },
    { 'Shadowstep',
        plain  = { 'crosses the room the short way, two heartbeats flat.',
                   'says "Behind you." and arrives beside %t on a puff of ash.' },
        dry    = { 'cuts the distance and murmurs "Closer."' },
        fierce = { { 'appears behind %t without warning, blade already raised.', 'blunt' } },
        solemn = { { 'takes the hidden path to %t\'s flank, silent as dust.', 'courtly' } },
        warm   = { 'says "Missed me." beside %t, close enough to breathe on.' } },
})

pack('druid', 'Druid', 'Forms, roots and rebirth.', {
    { 'Bear Form',
        plain  = { 'says "Bear." and the shoulders bulk up before the rest catches.',
                   'becomes bear-shaped and the air smells like wet hide.' },
        dry    = { 'grows fur, claws, and a better opinion of standing ground.' },
        fierce = { { 'growls "Back." and the shift lands with a thump of weight.', 'blunt' } },
        solemn = { 'mutters "Heavy." and bone and fur settle into place.' },
        warm   = { 'says "Easy now." and the change comes on like a deep breath.' } },
    { 'Cat Form',
        plain  = { 'slips into cat form and claws click once on the stone.',
                   'says "Cat." and the world tilts closer to the ground.' },
        dry    = { 'says "Smaller." and becomes faster, harder to pet.' },
        fierce = { { 'snarls "Try me." and the ears flatten before the lunge.', 'blunt' } },
        solemn = { 'whispers "Cat." and holds still until the fur settles.' },
        warm   = { 'says "Quick feet now." and lands light on all fours.' } },
    { 'Travel Form',
        plain  = { 'says "Go." and four legs take the weight in one step.' },
        dry    = { 'says "Faster." and hooves or paws replace boot-leather with a scrape.' },
        fierce = { { 'barks "Move!" and the shift smells of wind and open road.', 'blunt' } },
        solemn = { { 'takes the road shape without hurry, and grass flattens underfoot.', 'courtly' } },
        warm   = { 'says "Stay close." and drops to four legs with a ready shake.' } },
    { 'Rebirth',
        plain  = { 'coaxes life back toward %t, and green warmth threads through the air.',
                   'says "Not yet." and the ground under %t goes soft with new growth.' },
        dry    = { 'interrupts %t\'s rest with inconvenient timing.' },
        fierce = { { 'snaps "Up!" and throws a burst of green warmth at %t.', 'blunt' } },
        solemn = { { 'calls life back into %t, slow as sap rising in spring wood.', 'courtly' } },
        warm   = { 'tells %t, "The fight is not over. Get up."' } },
    { 'Healing Touch',
        plain  = { 'murmurs "Heal." and green warmth spreads through %t like sun through leaves.' },
        dry    = { 'says "There." and passes a slow green warmth through %t.' },
        fierce = { { 'snaps "Hold!" and presses palm to %t until the heat stops jumping.', 'blunt' } },
        solemn = { 'says "Hold." and keeps steady pressure on %t like bark over a wound.' },
        warm   = { 'says "Easy. Breathe." and the warmth comes in slow, even pulses.' } },
    { 'Entangling Roots',
        plain  = { 'asks the ground and green shoots crack through the soil around %t.' },
        dry    = { 'tells %t "Stay a while." as vines race up from the turf.' },
        fierce = { { 'snaps "Stay put." and the earth splits with the snap of dry wood.', 'blunt' } },
        solemn = { { 'bids the earth rise around %t, and roots wriggle up through grass.', 'courtly' } },
        warm   = { 'says "Sorry about this." while thorny roots boil up from %t\'s shadow.' } },
    { 'Moonfire',
        plain  = { 'calls "Mark." and a thin cold light sinks into %t\'s skin.' },
        dry    = { 'says "There." and traces a pale circle on %t that keeps smouldering.' },
        fierce = { { 'barks "Burn bright!" and silver fire dots %t and keeps smouldering.', 'blunt' } },
        solemn = { { 'sets cold starlight on %t, and it keeps eating inward.', 'courtly' } },
        warm   = { 'warns %t, "Hold still." and pins a cold silver mark between %t\'s shoulders.' } },
    { 'Hibernate',
        plain  = { 'sings low at %t until the melody goes soft and dragging.',
                   'hums "Rest now." and the note thins out like dusk.' },
        dry    = { 'suggests, gently, that %t nap now.' },
        solemn = { { 'sings a lullaby at %t, and each line drops lower than the last.', 'courtly' } },
        warm   = { 'says "Sleep. I will watch." and keeps the hum going under %t\'s ear.' } },
    { 'Innervate',
        plain  = { 'says "Take this." and shares focus with %t in a rush of clear-headed air.' },
        dry    = { 'says "You asked." and lends %t energy.' },
        fierce = { { 'barks "Again!" and pours focus into %t until the air hums.', 'blunt' } },
        solemn = { { 'offers %t a breath of deep-wood quiet, cool and bottomless.', 'courtly' } },
        warm   = { 'says "I have you." and fills %t with focus that smells of rain on pine.' } },
    { 'Mark of the Wild',
        plain  = { 'says "Marked." and %t\'s skin prickles with borrowed toughness.' },
        dry    = { 'tells %t "Later." and sets the mark anyway.' },
        fierce = { { 'growls "Stronger." and stamps the wild mark on %t like a brand.', 'blunt' } },
        solemn = { { 'sets the wild mark on %t with care, and fur seems to stir on %t\'s arms.', 'courtly' } },
        warm   = { 'says "You will need this." and leaves %t smelling of bark and wind.' } },
})

pack('shaman', 'Shaman', 'Elements and ancestors.', {
    { 'Lightning Bolt',
        plain  = { 'draws lightning down and the air goes sharp and metallic before it leaves.',
                   'says "There." and a bolt threads from cloud to %t with a crack.' },
        dry    = { 'says "Sorry." and introduces %t to lightning.' },
        fierce = { { 'barks "Down!" and ozone rolls off %t before the flash.', 'blunt' } },
        solemn = { { 'speaks the storm word over %t, and hair stands up all around.', 'courtly' } },
        warm   = { 'says "Look out!" a moment before the bolt lands.' } },
    { 'Chain Lightning',
        plain  = { 'says "Spread." and the bolt forks with a smell of hot copper.' },
        dry    = { 'says "Next." and lets physics argue.' },
        fierce = { { 'snarls "Spread!" and lightning stutters from hand to sky.', 'blunt' } },
        solemn = { 'says "Again." and tracks each fork with a tapped finger.' },
        warm   = { 'says "Everyone back." as the air starts to taste like pennies.' } },
    { 'Healing Wave',
        plain  = { 'says "Wash." and cool water shears over %t like a breaking wave.' },
        dry    = { 'calls it "Medicine." and sends a wave through %t.' },
        fierce = { { 'snaps "Live!" and the wave hits %t with salt and thunder.', 'blunt' } },
        solemn = { { 'pours the healing wave over %t, slow and steady as tide coming in.', 'courtly' } },
        warm   = { 'says "Hold on." and washes the hurt from %t in one cold rinse.' } },
    { 'Ancestral Spirit',
        plain  = { 'speaks over the fallen and ghost-light pools around %t like mist.',
                   'says "Not yet." and the air around %t smells of cedar smoke.' },
        dry    = { 'interrupts %t\'s rest with inconvenient timing.' },
        fierce = { { 'barks "Up!" and throws ancestor-light at %t in a rough burst.', 'blunt' } },
        solemn = { { 'calls %t back with old words, each one dropped like a stone in still water.', 'courtly' } },
        warm   = { 'tells %t, "Come back. We need you."' } },
    { 'Earth Shock',
        plain  = { 'shoves the ground at %t.',
                   'says "Down." and stone-force jumps from the soil into %t.' },
        dry    = { 'says "Ground." and introduces %t to the earth at speed.' },
        fierce = { { 'snarls "Down!" and a slab of stone-force cracks upward toward %t.', 'blunt' } },
        solemn = { { 'strikes %t with stone that arrives like a slammed door.', 'courtly' } } },
    { 'Ghost Wolf',
        plain  = { 'says "Run." and fur ripples up the spine in one pass.' },
        dry    = { 'says "Wolf." and pretends that was always the plan.' },
        fierce = { { 'barks "Run!" and the shift comes with a wet snarl of wolf breath.', 'blunt' } },
        solemn = { 'says "Go." and becomes wolf without looking back.' },
        warm   = { 'says "Follow me." and drops to wolf with ears forward.' } },
    { 'Bloodlust',
        plain  = { 'counts "One. Two." and beats a rhythm that makes the chest tighten.' },
        dry    = { 'says "Feel that?" and starts a drumbeat nobody asked for.' },
        fierce = { { 'roars "Faster!" and the drumbeat hits like a second heartbeat.', 'blunt' } },
        solemn = { { 'beats a war rhythm into the air until dust jumps off the stones.', 'courtly' } },
        warm   = { 'says "Keep going!" and the rhythm surges hot under the skin.' } },
    { 'Heroism',
        plain  = { 'shouts "Now!" until veins stand out and the air shivers.' },
        dry    = { 'yells "Up!" and suddenly everyone has energy.' },
        fierce = { { 'bellows "Now!" and heroism ripples outward on a wave of brass sound.', 'blunt' } },
        solemn = { { 'lifts one voice, and the air rings like a bell being struck.', 'courtly' } },
        warm   = { 'cries "For each other!" and heroism spreads on a warm rush of breath.' } },
    { 'Water Walking',
        plain  = { 'speaks over the water until the surface skins over under %t.' },
        dry    = { 'tells the water "Patient." and %t\'s reflection stops moving.' },
        solemn = { { 'speaks until the water under %t holds flat as a pane of glass.', 'courtly' } },
        warm   = { 'says "Step lightly." and the water beneath %t tightens like stretched skin.' } },
    { 'Far Sight',
        plain  = { 'says "See." and the world pulls back until the horizon jumps closer.' },
        dry    = { 'mutters "There." and peers at the horizon.' },
        solemn = { { 'sends sight far, and blinks when it snaps back.', 'courtly' } },
        warm   = { 'says "Wait." and watches from very far away, wind in the teeth.' } },
})

pack('deathknight', 'Death Knight', 'Cold, debts and the risen.', {
    { 'Death Grip',
        plain  = { 'says "Here." and hauls %t in close on a thread of cold.',
                   'barks "In!" and pulls %t inward on a bar of frost.' },
        dry    = { 'closes the gap without asking %t\'s opinion, frost at the pull line.' },
        fierce = { { 'snarls "Closer!" and the grip arrives like a slammed door of ice.', 'blunt' } },
        solemn = { 'says "Come." and draws %t in on a line that hums with cold.' },
        warm   = { 'says "Over here." and pulls %t close, frost still on the gauntlet.' } },
    { 'Death Coil',
        plain  = { 'says "Take." and spends a little death on %t in a pulse of winter air.' },
        dry    = { 'tosses death at %t and says "Catch."' },
        fierce = { { 'barks "Take it!" and a coil of cold green light jumps the gap.', 'blunt' } },
        solemn = { { 'offers %t a wrapped piece of the cold, sealed with a breath of frost.', 'courtly' } } },
    { 'Raise Dead',
        plain  = { 'says "Rise." and the corpse stirs with a scrape of bone on stone.' },
        dry    = { 'says "Stand." and the fallen obeys, joints creaking.' },
        fierce = { { 'snarls "Up!" and the dead climbs up with a rattle of iron.', 'blunt' } },
        solemn = { { 'calls the body back to duty, and frost dusts the risen collar.', 'courtly' } },
        warm   = { 'says "One more try." and the corpse stirs, unhurried.' } },
    { 'Army of the Dead',
        plain  = { 'says "All of you." and the ground gives up its dead in a slow exhale of frost.' },
        dry    = { 'says "Up." and opens the earth.' },
        fierce = { { 'roars "Rise!" and the army answers with a sound like grinding ice.', 'blunt' } },
        solemn = { { 'speaks once, and graves empty to a winter stillness.', 'courtly' } },
        warm   = { 'says "Stand with me." and the dead rise, frost on every brow.' } },
    { 'Death and Decay',
        plain  = { 'says "Remember." and the ground recalls what it buried.' },
        dry    = { 'says "Stay out." and makes the ground unpleasant.' },
        fierce = { { 'growls "Rot here!" and the air turns sour with cold decay.', 'blunt' } },
        solemn = { { 'sets death on the earth and lets it work, cold creeping through the cracks.', 'courtly' } },
        warm   = { 'says "Clear out." before the rot takes hold and frost veils the air.' } },
    { 'Anti-Magic Shell',
        plain  = { 'says "More." and drinks the magic in until the shell hums.' },
        dry    = { 'says "Mine." and eats the spell offered.' },
        fierce = { { 'snarls "More!" and the shell blooms frost-white.', 'blunt' } },
        solemn = { 'says "Hold." and takes the magic without flinching.' },
        warm   = { 'says "On me." and the shell rises, frost crawling the shoulders.' } },
    { 'Path of Frost',
        plain  = { 'says "Ice." and freezes the water ahead with a crack like glass settling.' },
        dry    = { 'says "Cold." and makes ice where none was invited.' },
        solemn = { 'says "Through." and sets frost underfoot that does not melt.' },
        warm   = { 'says "Mind the step." and frosts the path for those behind.' } },
    { 'Mind Freeze',
        plain  = { 'says "Stop." and sends a blade of cold toward %t\'s brow.' },
        dry    = { 'says "No." and aims a touch of frost at %t\'s brow.' },
        fierce = { { 'snaps "Quiet!" and thrusts cold toward %t at arm\'s length.', 'blunt' } },
        solemn = { { 'offers %t a touch of frost at the temple, unhurried.', 'courtly' } } },
    { 'Chains of Ice',
        plain  = { 'says "Hold." and wraps %t in river-cold.',
                   'binds %t in chains of cold that clink like winter rigging.' },
        dry    = { 'says "Still." and sends river-cold curling toward %t.' },
        fierce = { { 'barks "Freeze!" and hurls chains of cold at %t.', 'blunt' } },
        solemn = { { 'sets ice chains on %t with a sound like winter rigging.', 'courtly' } },
        warm   = { 'says "Do not move." and sends cold chains toward %t.' } },
})

pack('monk', 'Monk', 'Chi, brew and forward momentum.', {
    { 'Roll',
        plain  = { 'rolls aside and says "Clear," landing without a sound.',
                   'is elsewhere, and did it gracefully.' },
        dry    = { 'was standing here. Was.' },
        fierce = { { 'snaps "Move!" and is already gone, dust still rising.', 'blunt' } },
        solemn = { { 'steps light and leaves no mark.', 'courtly' } },
        warm   = { 'rolls past %t and murmurs "Mind yourself," close enough to ruffle cloth.' } },
    { 'Provoke',
        plain  = { 'invites %t to try, with one open palm and no hurry.',
                   'gestures at %t and says "Try me."' },
        dry    = { 'gives %t a reason to be rude.' },
        fierce = { { 'snaps "Me. Now." at %t, chin lifted.', 'blunt' } },
        solemn = { { 'offers %t the first move, as courtesy.', 'courtly' } },
        warm   = { 'steps between %t and the others and says "My turn."' } },
    { 'Spinning Crane Kick',
        plain  = { 'becomes briefly a problem for everyone nearby.',
                   'spins once and says "Room," heels clipping air.' },
        dry    = { 'introduces several elbows to several people.' },
        fierce = { 'shouts "Out!" and spins through the crowd, a blur of cloth.' },
        solemn = { { 'turns once, and the form is complete.', 'courtly' } },
        warm   = { 'spins through the press and calls "Behind me!" breath still even.' } },
    { 'Fortifying Brew',
        plain  = { 'drinks deeply and squares up, breath catching on the burn.',
                   'swallows the brew and mutters "Steady."' },
        dry    = { 'tastes the brew and does not flinch.' },
        fierce = { { 'downs the brew and barks "Again," eyes watering.', 'blunt' } },
        solemn = { { 'drinks as one who knows the cost, and the cup comes away empty.', 'courtly' } },
        warm   = { 'raises the flask and says "For those behind me."' } },
    { 'Resuscitate',
        plain  = { 'breathes the fallen back into the fight, warm air against cold skin.',
                   'presses a palm to %t and says "Up," feeling for a heartbeat.' },
        dry    = { 'convinces death to wait its turn.' },
        fierce = { { 'grabs %t and snarls "Up!" knuckles white.', 'blunt' } },
        solemn = { { 'breathes into %t, as the old art teaches, slow and measured.', 'courtly' } },
        warm   = { 'kneels by %t and says "Easy. Breathe."' } },
    { 'Touch of Death',
        plain  = { 'touches %t once, and the air goes still.',
                   'places a hand on %t and says "Enough," palm flat and quiet.' },
        dry    = { 'answers %t with one touch, no follow-through.' },
        fierce = { { 'touches %t and growls "Done," one finger on the sternum.', 'blunt' } },
        solemn = { { 'places one finger on %t, and even the breath waits.', 'courtly' } },
        warm   = { 'touches %t once and whispers "No more," almost gently.' } },
    { 'Transcendence',
        plain  = { 'leaves a spirit behind and steps away, the echo still breathing.',
                   'sets a mark and says "Wait here."' },
        dry    = { 'saves a spot and uses the other one.' },
        fierce = { { 'barks "Hold this ground!" and vanishes.', 'blunt' } },
        solemn = { { 'sets the spirit anchor with deliberate care, sand settling around it.', 'courtly' } },
        warm   = { 'leaves an echo behind and says "I will return."' } },
    { 'Legacy of the Emperor',
        plain  = { 'passes the old emperor\'s blessing to %t, hands steady as tea poured.',
                   'speaks the legacy over %t until the air tastes of incense.' },
        dry    = { 'lends %t a little borrowed grandeur.' },
        fierce = { 'shouts "Stand tall!" and bestows the legacy on %t.' },
        solemn = { { 'bestows the emperor\'s blessing upon %t with both palms raised.', 'courtly' } },
        warm   = { 'touches %t\'s shoulder and says "You carry it well."' } },
})

pack('demonhunter', 'Demon Hunter', 'Fel, wings and momentum.', {
    { 'Fel Rush',
        plain  = { 'crosses the gap in a streak of green fire that leaves the air cold behind it.',
                   'says "Now." and launches forward before the word settles.' },
        dry    = { 'closes the distance before anyone finishes blinking.' },
        fierce = { { 'snarls "Too slow!" and closes the gap in one bound.', 'blunt' } },
        solemn = { { 'commits to the rush, and the ground falls away under trailing fel.', 'courtly' } },
        warm   = { 'reaches %t first, skidding on the heels, and says "Move."' } },
    { 'Metamorphosis',
        plain  = { 'stops holding the demon in, and the skin cracks along old scar lines.',
                   'unfolds into something with wings that throw a shadow twice their span.' },
        dry    = { 'lets the other shape out for a while.' },
        fierce = { 'roars "Out!" and the wings come free with a crack of displaced air.' },
        solemn = { { 'accepts the form, and the borrowed power settles heavy in the ribs.', 'courtly' } },
        warm   = { 'unfolds the wings wide enough to shade %t and says "Stay close."' } },
    { 'Eye Beam',
        plain  = { 'opens both eyes, and fel pours out in a sheet that scorches grass underfoot.',
                   'turns the gaze on %t and murmurs "See."' },
        dry    = { 'looks at %t with entirely too much honesty.' },
        fierce = { { 'barks "Look at me!" and the beam cuts loose with a whine of heat.', 'blunt' } },
        solemn = { { 'holds the gaze until the air stops shimmering and the fel drains away.', 'courtly' } },
        warm   = { 'sweeps the beam low, heat washing the floor, and calls "Down!"' } },
    { 'Blade Dance',
        plain  = { 'turns once, and everything nearby regrets it.',
                   'spins the blades and says "Wide." The glaives sing.' },
        dry    = { 'adds a few extra cuts to the rotation.' },
        fierce = { 'snarls "Dance!" and the blades blur until they hum.' },
        solemn = { { 'moves through the form, blade by blade, grit thrown from each turn.', 'courtly' } },
        warm   = { 'spins through the press, wind off the blades, and calls "Clear out!"' } },
    { 'Chaos Strike',
        plain  = { 'cuts %t with something that should not be a blade.',
                   'strikes %t and mutters "There." Green sparks skitter off the edge.' },
        dry    = { 'hits %t with chaos at an ill-chosen moment.' },
        fierce = { { 'snarls "Break!" and the chaos lands with a crack like splitting wood.', 'blunt' } },
        solemn = { { 'delivers the strike, and the air around %t ripples green for a moment.', 'courtly' } },
        warm   = { 'strikes %t once and says "Enough."' } },
    { 'Imprison',
        plain  = { 'draws sigils around %t until the air between them goes still and glassy.' },
        dry    = { 'draws sigils around %t that take up more room than %t does.' },
        fierce = { { 'snarls "Stay." and slams sigils shut in a ring around %t.', 'blunt' } },
        solemn = { { 'inscribes runes around %t, and the space between them tightens.', 'courtly' } },
        warm   = { 'traces sigils around %t and says "Wait."' } },
    { 'Spectral Sight',
        plain  = { 'looks through walls, and the people within.',
                   'opens the inner sight, outlines flickering on stone, and whispers "Show me."' },
        dry    = { 'sees more than was strictly invited.' },
        fierce = { { 'snarls "Found you." at the shapes the sight outlines.', 'blunt' } },
        solemn = { { 'opens the inner eye, and heat signatures bloom through the stone.', 'courtly' } },
        warm   = { 'marks a safe path and murmurs "This way."' } },
    { 'Glide',
        plain  = { 'steps off the edge and does not fall.',
                   'spreads the wings and says "Easy." The descent goes quiet.' },
        dry    = { 'declines gravity with the wings out.' },
        fierce = { 'drops from above, wings snapped tight, and shouts "Incoming!"' },
        solemn = { { 'glides down without hurry or sound.', 'courtly' } },
        warm   = { 'sweeps low over %t and says "Jump."' } },
})

pack('evoker', 'Evoker', 'Empowerment and the old flights.', {
    { 'Living Flame',
        plain  = { 'breathes a small, patient flame at %t that clings to cloth and skin.',
                   'lifts a hand and says "Burn steady." Smoke threads upward.' },
        dry    = { 'sets a modest fire on %t and waits.' },
        fierce = { 'hurls flame at %t and snarls "Burn!" Heat rolls off the cast.' },
        solemn = { { 'breathes a measured flame over %t until the air above shimmers.', 'courtly' } },
        warm   = { 'breathes warmth into %t and murmurs "There."' } },
    { 'Deep Breath',
        plain  = { 'takes a long breath, ribs spreading wide, and then the sky.',
                   'draws breath until the ground drops away beneath and says "Up."' },
        dry    = { 'occupies rather more sky than before.' },
        fierce = { 'roars, and the breath becomes a storm that flattens grass below.' },
        solemn = { { 'draws the old breath from deep within, and scale-markings flare along the arms.', 'courtly' } },
        warm   = { 'lifts on the breath and calls "Clear below!" Wind rattles cloaks.' } },
    { 'Hover',
        plain  = { 'declines to touch the ground for a moment.',
                   'rises a little, dust falling from boots, and says "Steady."' },
        dry    = { 'floats with the dignity of something that ignores stairs.' },
        fierce = { 'snaps "Up!" and leaves the ground behind in a puff of displaced air.' },
        solemn = { { 'hovers, unhurried, above the fray.', 'courtly' } },
        warm   = { 'hangs in the air and calls down "Need a lift?"' } },
    { 'Verdant Embrace',
        plain  = { 'wraps %t in green fire that smells of rain on hot stone.',
                   'pulls %t close and says "Hold." The warmth comes through at once.' },
        dry    = { 'embraces %t with more magic than tact.' },
        fierce = { { 'snatches %t in green fire and barks "Live!" Heat pours off both.', 'blunt' } },
        solemn = { { 'enfolds %t in verdant fire older than the stones underfoot.', 'courtly' } },
        warm   = { 'wraps %t in green warmth and murmurs "Stay with me."' } },
    { 'Time Spiral',
        plain  = { 'folds a little time into everyone nearby, and footsteps come quicker.',
                   'says "Quickly!" and time loosens its grip around the group.' },
        dry    = { 'lends the group a sliver of stolen momentum.' },
        fierce = { { 'snarls "Move!" and the air around everyone goes slick with borrowed speed.', 'blunt' } },
        solemn = { { 'turns the spiral, and seconds come free with a sound like tearing silk.', 'courtly' } },
        warm   = { 'spins time outward and calls "Take it." Heartbeats skip, briefly.' } },
    { 'Rescue',
        plain  = { 'picks %t up and carries %t clear, protesting all the way.',
                   'says "Hold on." and hauls %t out of the way by the collar.' },
        dry    = { 'relocates %t without asking nicely.' },
        fierce = { { 'grabs %t and barks "Move!" Boots leave the ground at once.', 'blunt' } },
        solemn = { { 'lifts %t clear with a wingbeat worth of old strength behind it.', 'courtly' } },
        warm   = { 'sweeps %t up and says "Got you."' } },
    { 'Fire Breath',
        plain  = { 'exhales the way dragons do.',
                   'opens the throat and says "Burn." Heat rolls forward in layers.' },
        dry    = { 'breathes fire with entirely too much enthusiasm.' },
        fierce = { 'roars, and the fire follows in a wall that blackens stone.' },
        solemn = { { 'breathes the old flame across the field until the grass curls under it.', 'courtly' } },
        warm   = { 'exhales flame low and calls "Down!" Warmth washes ankles.' } },
})

pack('pets', 'Pets', 'Lines for what your pet does, on any class.', {
    { 'Growl',
        plain  = { 'watches %p decide %t is the problem, fur up along the neck.',
                   'lets %f do the talking.' },
        dry    = { 'lets %p handle the introductions.' },
        fierce = { { 'snaps "Take it!" and %p goes in before the word is finished.', 'blunt' } },
        solemn = { { 'sets %p upon %t, and it obeys without a sound.', 'courtly' } },
        warm   = { 'says "Go on, then." and lets %p work the growl loose in its chest.' } },
    { 'Claw',
        plain  = { 'watches %p open %t up, claws catching on mail.' },
        dry    = { 'watches %p do something unhygienic to %t.' },
        fierce = { 'shouts "Again!" as %p tears in, claws catching daylight.' },
        solemn = { { 'watches %p set claw to %t with the patience of a butcher.', 'courtly' } },
        warm   = { 'says "Good." as %p strikes once, twice, and stops.' } },
    { 'Bite',
        plain  = { 'watches %p find the throat.' },
        dry    = { 'notes that %p has found the throat again.' },
        fierce = { { 'barks "Hold it!" and %p bites down with a wet click.', 'blunt' } },
        solemn = { { 'watches %p finish what was started, jaw locked.', 'courtly' } },
        warm   = { 'says "That will do." as %p lets go, reluctantly.' } },
    { 'Spell Lock',
        plain  = { 'says nothing; %p bites the spell in half.' },
        dry    = { 'lets %p explain why %t should not have done that.' },
        fierce = { { 'snaps "Shut it!" and %p obliges with a snarl.', 'blunt' } },
        solemn = { { 'bids %p silence %t, and the last syllable never comes.', 'courtly' } },
        warm   = { 'says "Quick now." and %p closes in low and fast.' } },
    { 'Devour Magic',
        plain  = { 'watches %p eat the magic off %t, sparks on its teeth.' },
        dry    = { 'watches %p have the magic for lunch.' },
        fierce = { { 'snaps "Eat it!" and %p does, swallowing the glow.', 'blunt' } },
        solemn = { { 'has %p unmake what was woven on %t, thread by thread.', 'courtly' } },
        warm   = { 'says "Careful." while %p feeds, licking sparks from its lips.' } },
    { 'Torment',
        plain  = { 'lets %p do what it enjoys.' },
        dry    = { 'lets %p enjoy itself, within reason.' },
        fierce = { 'shouts "Get in there!" and %p does, all claws and noise.' },
        solemn = { { 'sets %p to its work, and %p takes its time.', 'courtly' } },
        warm   = { 'says "Not too long." and lets %p in, tail wagging aside.' } },
    { 'Suffering',
        plain  = { 'lets %f insist, loudly, on being hit.' },
        dry    = { 'watches %f demand attention it will regret.' },
        fierce = { { 'roars "Hold them!" and %p plants itself between %t and everything else.', 'blunt' } },
        solemn = { { 'bids %p bear what follows, and does not look away.', 'courtly' } },
        warm   = { 'says "Brace." and %p takes the weight with a grunt.' } },
    { 'Intercept',
        plain  = { 'points, and %p is already moving.' },
        dry    = { 'points. %p was already going.' },
        fierce = { { 'shouts "Now!" and %p hits like a thrown brick.', 'blunt' } },
        solemn = { { 'sends %p ahead, and it goes without looking back.', 'courtly' } },
        warm   = { 'says "Go." and %p goes, paws already in full stride.' } },
})

pack('professions', 'Professions & travel', 'The quiet, everyday casts.', {
    { 'Hearthstone',
        plain  = { 'turns the stone over until it warms, and says "Home."',
                   'holds the hearthstone up until the glow fills both hands.' },
        dry    = { 'decides that is quite enough adventuring.' },
        fierce = { { 'says "Done." and takes the stone before the glow fades.', 'blunt' } },
        solemn = { { 'speaks the word of returning, and the world goes soft at the edges.', 'courtly' } },
        warm   = { 'says "Right. Home." to nobody in particular, stone already humming.' } },
    { 'Fishing',
        plain  = { 'casts a line and settles in until the bobber stops dancing.' },
        dry    = { 'begins the long and thankless work of fishing.' },
        solemn = { { 'casts the line and waits, as is proper, rod tip still.', 'courtly' } },
        warm   = { 'casts a line and says "No hurry." while the reel clicks.' } },
    { 'Mining',
        plain  = { 'sets to the rock with a practised swing, sparks skittering off steel.' },
        dry    = { 'negotiates with the rock. The rock loses.' },
        fierce = { 'swings until dust coats the tongue, and tells the rock "Come on."' },
        solemn = { { 'works the seam with care, listening for the hollow sound.', 'courtly' } },
        warm   = { 'works the rock, humming against the ring of metal on stone.' } },
    { 'Herb Gathering',
        plain  = { 'takes only what the plant can spare, roots still damp.' },
        dry    = { 'robs a plant, gently.' },
        solemn = { { 'takes the herb with thanks, dirt under the nails.', 'courtly' } },
        warm   = { 'says "Thank you." to the plant.' } },
    { 'Skinning',
        plain  = { 'works the hide free, carefully, knife warmed by the body heat.' },
        dry    = { 'does the part nobody wants to watch.' },
        solemn = { { 'takes the hide, and wastes nothing, scraping clean to the bone.', 'courtly' } },
        warm   = { 'works the hide free and says "Waste nothing." fingers tacky with fat.' } },
    { 'Cooking',
        plain  = { 'gets a fire going and something over it, grease popping in the pan.' },
        dry    = { 'cooks. Results may vary.' },
        solemn = { { 'sets the fire and the pot, in order, smoke rising straight.', 'courtly' } },
        warm   = { 'says "There is enough for everyone." over a pot already steaming.' } },
    { 'First Aid',
        plain  = { 'binds the wound the ordinary way, cloth going pink fast.' },
        dry    = { 'applies a bandage and hopes.' },
        fierce = { { 'snaps "Hold still." and binds it tight enough to bruise.', 'blunt' } },
        solemn = { { 'binds the wound, as any decent person would, knot flat and firm.', 'courtly' } },
        warm   = { 'says "This will sting." and binds the wound with steady hands.' } },
    { 'Disenchant',
        plain  = { 'unmakes it, and keeps the dust that settles on the bench.' },
        dry    = { 'turns something perfectly good into dust.' },
        solemn = { { 'unmakes the work and keeps what remains, glittering in the palm.', 'courtly' } },
        warm   = { 'says "Sorry." and unmakes it, dust puffing up between the fingers.' } },
    { 'Enchanting',
        plain  = { 'talks the magic into staying put, runes smoking on the metal.' },
        dry    = { 'argues with the magic until it settles.' },
        solemn = { { 'binds the enchantment where it belongs, and the air tastes of ozone.', 'courtly' } },
        warm   = { 'says "Hold there." and the magic holds with a faint blue hum.' } },
})

-- Creeds. What a character believes belongs to the character, not to any one
-- spell, so these ride along on whatever you already cast rather than being
-- keyed to a spell of their own. Tick as many as fit; nothing here is tied to
-- a class, and the class packs deliberately stay clear of faction and faith.

creed('creed_horde', 'Creed: the Horde', 'Lok\'tar ogar.', {
    plain  = { 'says "For the Horde." like a plain fact.' },
    dry    = { 'mutters "For the Horde, apparently." and gets on with it.' },
    fierce = { 'roars "For the Horde!" loud enough to carry over the noise.',
               { 'bellows "Lok\'tar ogar!" and does not wait for an answer.', 'blunt' } },
    solemn = { { 'says "For the Horde." as an oath, not a shout.', 'courtly' } },
    warm   = { 'says "Strength to you." to nobody in particular.' },
})

creed('creed_alliance', 'Creed: the Alliance', 'For the Alliance.', {
    plain  = { 'says "For the Alliance." the way it was drilled in.' },
    dry    = { 'offers a dutiful "For the Alliance." and leaves it at that.' },
    fierce = { 'roars "For the Alliance!" until the word goes ragged.',
               { 'shouts "Hold the line!" and plants both feet.', 'blunt' } },
    solemn = { { 'swears "For the Alliance, and all it keeps."', 'courtly' } },
    warm   = { 'says "Stay close, all of you." with a glance back.' },
})

creed('creed_light', 'Creed: the Light', 'For those who serve it.', {
    plain  = { 'says "Light guide us." out of long habit.' },
    dry    = { 'says "Light willing." without much confidence.' },
    fierce = { 'shouts "The Light is with us!" and believes it for a moment.' },
    solemn = { { 'murmurs "By the Light, let it be so." with eyes shut.', 'courtly' } },
    warm   = { 'says "The Light keep you." and means every word.' },
})

creed('creed_elune', 'Creed: Elune', 'For the moon and her own.', {
    plain  = { 'says "Elune be with us." quietly, as though indoors.' },
    fierce = { 'cries "Elune, give me strength!" with both hands open.' },
    solemn = { { 'whispers "Elune-adore." and lets the word hang.', 'courtly' } },
    warm   = { 'says "May Elune watch over you." and touches a shoulder.' },
})

creed('creed_ancestors', 'Creed: the ancestors', 'For those who came before.', {
    plain  = { 'says "The ancestors are watching." like a weather report.' },
    fierce = { 'shouts "For the ancestors!" and then the name of one of them.' },
    solemn = { { 'says "Ancestors, guide my hand." with the palm turned up.', 'courtly' } },
    warm   = { 'says "Walk with the ancestors." to whoever needs to hear it.' },
})

creed('creed_elements', 'Creed: the elements', 'For earth, sea, sky and flame.', {
    plain  = { 'says "The elements are restless today."' },
    fierce = { 'shouts "The elements answer!" over the noise of them doing it.' },
    solemn = { { 'says "Elements, lend your strength." and waits to be heard.', 'courtly' } },
    warm   = { 'thanks the elements, quietly, the way one thanks a neighbour.' },
})

creed('creed_fel', 'Creed: the fel', 'For power, and what it costs.', {
    plain  = { 'says "The fel does not tire." which is most of the appeal.' },
    dry    = { 'observes that this was always going to end in fel.' },
    fierce = { { 'snarls "Burn it all!" and sounds glad about it.', 'blunt' } },
    solemn = { { 'says "This is the price. It is paid."', 'courtly' } },
})

creed('creed_shadow', 'Creed: the shadow', 'For the patient dark.', {
    plain  = { 'says "The shadow is patient." as if quoting someone.' },
    dry    = { 'notes that the shadow is, as ever, unhelpful.' },
    fierce = { 'hisses "Into the dark with you!" through the teeth.' },
    solemn = { { 'murmurs "The shadow hears." and does not explain.', 'courtly' } },
})

--@phrases-end@
--=========================================================================--

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

-- Creed lines from every ticked creed pack. Casts.GetPhrases mixes these into
-- any spell that already has phrases of its own; see creed() above for why they
-- can't simply be attached to a spell.
function CastLibrary.GetWildcards()
    local out = {}
    local Casts = ns.Casts
    if not Casts then return out end
    for _, entry in ipairs(wildcards) do
        if Casts.IsPackEnabled(entry.pack) then out[#out + 1] = entry end
    end
    return out
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

-- Classes that can have a pet worth narrating, so switching the feature on can
-- tick the Pets pack for the people it applies to and nobody else.
local PET_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true, MAGE = true }

function CastLibrary.PlayerHasPetClass()
    if type(UnitClass) ~= "function" then return false end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok or type(token) ~= "string" then return false end
    return PET_CLASSES[token:upper()] and true or false
end
