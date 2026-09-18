# Cast phrases — reference copy

Generated from `CastLibrary.lua` by `tools/dump_phrases.lua`: **23 packs, 143 spells, 783 phrases**.

This is a read-only view. To change a line, edit `CastLibrary.lua` and re-run the dump.

---

## How a phrase is shaped

A phrase is the **body of an emote**, so it continues the sentence `<Your name> ...`.
`roars "Burn!"` reaches chat as *Corvin roars "Burn!"*. Hence:

| Rule | Why |
|---|---|
| Start with a **verb, lower case** | It continues your name, so a capital reads as a new sentence |
| End with **punctuation** | Nothing is appended after it |
| Words in `"double quotes"` are **spoken aloud** | Only these are translated into the current tongue; the rest stays English narration, which is the part onlookers are meant to follow |
| **No pronouns for the caster** | `sets his feet` only works if the character is male; the library ships to everyone |
| **No faction or faith** in a class pack | A Blood Elf paladin does not serve the Light; creeds are separate opt-in packs |
| Keep it **short** | The line shares one 255-character message with a translation that runs longer than the English |
| `%s` spell · `%p` pet's name · `%f` pet's family · `%t` target | A phrase whose token cannot be filled is skipped for that cast, so `%t` and `%p` lines are safe |
| No possessive openers | Emotes render as `"Name "` + text with the space baked in, so `'s pet growls` becomes *Corvin 's pet growls* |

## Tone

Lines are grouped by **Bearing** — how the character carries themselves — and may carry
a **Wording** tag of *courtly* or *blunt*. A player's character sheet picks a primary
Bearing and optionally a second; those groups rise in the roll and the rest drop out.

`plain` is the exception: it is both a Bearing you can choose and the neutral backbone,
so those lines stay in the roll whatever the sheet says. That is what lets a spell get
away with having no Fierce reading at all.

| Bearing | Reads as | Lines |
|---|---|---|
| Plain | states what happens, no flourish | 231 |
| Dry | understated, faintly amused | 148 |
| Fierce | loud, forward | 137 |
| Solemn | grave, weighty — not villainous | 133 |
| Warm | looks after people, even mid-fight | 134 |

Wording tags are a light touch: **227 of 783 lines (29%)** carry one — 125 courtly, 102 blunt.

## Health

- **420 of 783 lines (54%) speak aloud.** The quoted half is the only part the language
  engine gets to transform, so this is the number that decides whether the feature shows
  itself off. The target is roughly half.
- **104 of 143 spells (73%) cover all five Bearings.** A gap is deliberate where a spell
  has no sensible reading for one — there is no Fierce way to conjure a sandwich — and
  `plain` always plays, so a gap costs nothing.
- 342 of 783 lines use a `%` token.
- Longest line is 87 characters, Warlock / Hellfire: *spreads both arms and lets the fire spill outward until the stone underfoot goes black.*

---

## Warlock <!-- id: warlock -->

*Fel magic, pacts and pets.*

<!-- 13 spells, 70 phrases -->

### Immolate

**Plain**

- sets %t alight, and the heat rolls back over anyone standing close.
- traces a sigil that keeps smouldering after the hand has moved on.

**Dry**

- sets %t on fire and waits for the complaining to start.

**Fierce**

- snarls "Burn!" and the fire takes with a crack like wet wood.
- shoves a fistful of fire into %t and shakes the ash off after.  *(blunt)*

**Solemn**

- speaks the word of burning over %t, unhurried as a sentence read aloud.  *(courtly)*

**Warm**

- warns %t, "Stand back." and lets the fire go.

### Shadow Bolt

**Plain**

- gathers the dark into one point and lets it go with a thump of cold air.
- hurls a bolt of shadow that takes the warmth out of the air behind it.

**Dry**

- throws shadow at %t with the bored accuracy of someone posting a letter.

**Fierce**

- barks "Down!" and the shadow arrives like a slammed door.  *(blunt)*

**Solemn**

- calls upon the dark, and it answers before the words are finished.  *(courtly)*

**Warm**

- says "Nothing personal." and lets the bolt fly.

### Corruption

**Plain**

- sets something patient working inside %t, slow as rot in a rafter.
- murmurs "Give it time." and leaves it to work.

**Dry**

- gives %t something to think about in an hour or so.

**Fierce**

- spits "Rot." and the word seems to stick.  *(blunt)*

**Solemn**

- speaks a slow ruin into %t, one word at a time.  *(courtly)*

**Warm**

- tells %t, "This would have been kinder quickly."

### Fear

**Plain**

- speaks a word %t was never meant to hear, and %t stops hearing anything else.
- meets %t and says, evenly, "Go."

**Dry**

- suggests, mildly, that %t has somewhere else to be.

**Fierce**

- roars, and whatever %t sees in that moment is enough.  *(blunt)*

**Solemn**

- shows %t one true thing, and %t will not look at it twice.  *(courtly)*

**Warm**

- says "Run. Go on." and means it.

### Drain Life

**Plain**

- closes a hand and draws the warmth out of %t in a thin grey thread.

**Dry**

- borrows a little life from %t, indefinitely.

**Fierce**

- snarls "Mine." and does not let go until it is.  *(blunt)*

**Solemn**

- takes only what %t owes, and counts it out.  *(courtly)*

**Warm**

- says "I will be needing that." almost apologetically.

### Health Funnel

**Plain**

- opens a vein for %p without hesitating, and goes grey doing it.

**Dry**

- donates blood, involuntarily, to %p.

**Fierce**

- growls "Stay up!" and pours until %p stops shaking.  *(blunt)*

**Solemn**

- pays %p in blood, as was agreed, down to the last drop owed.  *(courtly)*

**Warm**

- tells %p, "Hold on. Nearly there."

### Hellfire

**Plain**

- spreads both arms and lets the fire spill outward until the stone underfoot goes black.

**Dry**

- sets everything on fire, including the obvious, including both boots.

**Fierce**

- bellows "Burn with me!" and lets go of the last of it, wreathed to the shoulders.

**Solemn**

- offers up the ground itself to the fire, and the fire does not refuse.  *(courtly)*

**Warm**

- says "Everyone back." a moment too late.

### Soulstone

**Plain**

- folds a soul into stone until the stone sits warm. "In case it comes to that."

**Dry**

- puts a little of %t somewhere safe. Insurance.

**Fierce**

- says "You are not dying today." and binds the stone hard enough to crack it.

**Solemn**

- binds the soul of %t to stone against what is coming, and names the hour.  *(courtly)*

**Warm**

- presses the stone into %t's hand. "Just in case."

### Create Healthstone

**Plain**

- works a small red stone out of nothing, still slick from the making.

**Dry**

- produces a stone that tastes worse than the wound it mends.

**Solemn**

- shapes a stone, and the shaping costs something that does not grow back.  *(courtly)*

**Warm**

- makes a stone for whoever needs it first, and holds it out.

### Summon Felhunter

**Plain**

- opens the air and %f steps through it, nose first.
- calls %p up, and %p arrives hungry and in no particular hurry.

**Dry**

- opens the air. %p is late, as usual.

**Fierce**

- tears the air open and %f comes through snarling before all four feet land.

**Solemn**

- calls %p by its true name, and the name is enough.  *(courtly)*

**Warm**

- greets %p like an old dog. "There you are."

### Summon Voidwalker

**Plain**

- draws something vast and unhurried into the light, and the light gives way for it.

**Dry**

- summons %p, who could not be less impressed.

**Fierce**

- hauls %f out of the dark by force, hand over hand.  *(blunt)*

**Solemn**

- calls the void, and a piece of it consents to be shaped.  *(courtly)*

**Warm**

- says "Good. You are here." to %p.

### Summon Imp

**Plain**

- summons %p, already mid-complaint about the weather.

**Dry**

- summons %p, and immediately regrets it.

**Fierce**

- snaps %p into the world by the scruff and tells it to keep up.

**Solemn**

- calls the least of them, and even the least attends.  *(courtly)*

**Warm**

- says "Behave." to %p, hopefully.

### Ritual of Summoning

**Plain**

- chalks the circle and says "Mind the edges."

**Dry**

- draws a circle and waits for someone to stand in it wrong.

**Fierce**

- barks "Two of you. Here. Now." and taps the chalk line twice.  *(blunt)*

**Solemn**

- sets the circle, speaks the summoning, and steps back to let it work.  *(courtly)*

**Warm**

- says "Come on through, it is safe." and holds the circle open.

## Mage <!-- id: mage -->

*Fire, frost and the arcane.*

<!-- 11 spells, 54 phrases -->

### Fireball

**Plain**

- lobs a fireball that leaves the air tasting of soot.
- shapes a sphere of fire and lets it go with a pop of heat.

**Dry**

- throws fire at %t, as is traditional.

**Fierce**

- barks "Move!" and the fire goes anyway, hot enough to peel paint.  *(blunt)*

**Solemn**

- speaks the fire into being, and the sparks cling to the sleeve.  *(courtly)*

**Warm**

- says "Mind yourself." and lets it fly before the heat rolls back.

### Frostbolt

**Plain**

- exhales, and the air cracks with cold.
- hurls a bolt of frost at %t that leaves rime on the nearest stone.

**Dry**

- cools %t down, somewhat abruptly.

**Fierce**

- snaps "Enough!" and frost answers with a crack like thin ice.

**Solemn**

- speaks cold into the air until breath starts to frost in front of the lips.  *(courtly)*

**Warm**

- says "Hold still." and lets the frost go in a white hiss.

### Pyroblast

**Plain**

- takes a long breath, and the whole room pulls toward the hands.
- builds fire into one terrible point and releases it in a roar of displaced air.

**Dry**

- promises %t "This one will hurt." and keeps the promise.

**Fierce**

- bellows "Burn!" and lets the blast go hard enough to stagger anyone close.  *(blunt)*

**Solemn**

- raises the fire with both hands until the heat bends the view around it.  *(courtly)*

**Warm**

- says "Mind the blast radius." a little late.

### Polymorph

**Plain**

- rewrites %t into something woollier.
- gestures at %t and threads the changing spell through the air like ribbon.

**Dry**

- turns %t into something with fewer opinions.

**Fierce**

- snaps "Quiet!" and the changing spell leaves hoofprints in the dust.

**Solemn**

- speaks a word of changing over %t, and the wool smell arrives before anything else.  *(courtly)*

**Warm**

- says "Sit. Stay." and sends the changing spell off like a well-trained thought.

### Blink

**Plain**

- steps sideways out of the world and back into it, leaving frost on the boots.

**Dry**

- was there. Was not. "Excuse me."

**Fierce**

- tears sideways through the air and leaves a cold spot where the body was.  *(blunt)*

**Warm**

- says "Pardon." and is suddenly elsewhere, dust still settling where they stood.

### Counterspell

**Plain**

- cuts the air with two fingers and says "No."
- flings a sharp silence at the spell leaving %t's lips.

**Dry**

- interrupts %t mid-thought. As one does.

**Fierce**

- barks "No!" and snaps the spell thread before it finishes.  *(blunt)*

**Solemn**

- speaks the word of ending at the spell still leaving %t's hands.  *(courtly)*

**Warm**

- says "Not that one." and folds the spell shut like paper.

### Ice Block

**Plain**

- pulls the winter in and holds still while breath fogs against the ice.

**Dry**

- becomes temporarily unavailable.

**Fierce**

- slams the cold shut around them and waits, visible only as a blur inside.  *(blunt)*

**Solemn**

- folds into ice and holds, frost creeping outward from the feet.  *(courtly)*

**Warm**

- mutters "Not today." and freezes solid with a sharp crack of settling ice.

### Arcane Intellect

**Plain**

- taps %t on the brow. "Try to keep up."

**Dry**

- taps %t and says "Pay attention."

**Solemn**

- speaks clarity over %t, and the eyes focus as if waking from a nap.  *(courtly)*

**Warm**

- says "You will need this." and leaves %t blinking at the sudden clarity.

### Blizzard

**Plain**

- raises both hands and calls the storm down until the hail pings off armor.

**Dry**

- calls down snow and says "Sorry about this."

**Fierce**

- shouts "Fall!" and the snow comes down hard enough to sting exposed skin.

**Solemn**

- calls the winter from above, and the temperature drops before the first flake.  *(courtly)*

**Warm**

- warns "Incoming snow." a moment too late.

### Conjure Refreshment

**Plain**

- conjures food out of thin air, as one does.

**Dry**

- mutters "It is edible." and conjures food.

**Warm**

- says "You look hungry." and conjures a snack that steams faintly.

### Slow Fall

**Plain**

- says "Mind the landing." a little too late.

**Dry**

- calls "Slowly!" down at %t.

**Warm**

- calls "Easy now." down at %t and threads a gentle lift into the fall.

## Priest <!-- id: priest -->

*Light, shadow and the words between.*

<!-- 11 spells, 50 phrases -->

### Power Word: Shield

**Plain**

- speaks a word over %t and something closes around %t with a faint hum.
- lays a hand on %t. "Stand."

**Dry**

- gives %t something to lean on, briefly.

**Fierce**

- snaps "Hold!" and the ward snaps shut with a pressure like deep water.  *(blunt)*

**Solemn**

- speaks the word of warding over %t, and the air hardens around the skin.  *(courtly)*

**Warm**

- says "You are not alone in this." and a steady warmth settles on %t.

### Flash Heal

**Plain**

- pours warmth into %t, quick enough to make %t gasp.
- says "Not today." and presses golden warmth into the worst of the hurt.

**Dry**

- patches %t up before the complaining starts.

**Fierce**

- barks "Stay up!" and slams the mending in hard enough to jar teeth.  *(blunt)*

**Solemn**

- speaks mending over %t, fast and sure as a seam pulled tight.  *(courtly)*

**Warm**

- says "There. Breathe." and leaves steady warmth where the pain was sharpest.

### Renew

**Plain**

- murmurs "Rest a moment." over %t.
- leaves a small warmth behind in %t, like sunlight on the back of the neck.

**Dry**

- tells %t, "Give it time."

**Solemn**

- sets a slow mending working in %t, deep as warmth under bruised skin.  *(courtly)*

**Warm**

- says "Easy does it." and lets the warmth linger like a blanket left on.

### Resurrection

**Plain**

- kneels, breathes warmth back toward still lungs, and asks for one more.
- tells the fallen, "Come back. We are not finished."

**Dry**

- insists %t was not finished yet.

**Fierce**

- demands "Up!" into the stillness and will not stop until something moves.  *(blunt)*

**Solemn**

- speaks the word of return over %t, voice steady as rope paid out by hand.  *(courtly)*

**Warm**

- says "Come on. We still need you." and keeps speaking until warmth returns.

### Shadow Word: Pain

**Plain**

- lets a thread of shadow settle into %t like grit under a nail.
- breathes something short and sharp over %t that tastes wrong in the mouth.

**Dry**

- murmurs "Remember this." over %t.

**Fierce**

- hisses "Hurt." and the shadow bites deep enough to leave a cold spot.  *(blunt)*

**Solemn**

- speaks pain into %t, quietly and without mercy, one syllable at a time.  *(courtly)*

### Mind Blast

**Plain**

- looks at %t and pushes, and the thought arrives like a fist through a wall.

**Dry**

- introduces %t to an unwelcome thought.

**Fierce**

- slams "Out!" into %t's thoughts hard enough to ring skull-bone.  *(blunt)*

**Solemn**

- speaks force into %t's skull until ears ring on both sides.  *(courtly)*

### Psychic Scream

**Plain**

- screams without making a sound.

**Dry**

- lets out a scream no one enjoys hearing.

**Fierce**

- screams "Go!" without making a sound, and the pressure rolls outward anyway.

### Mind Control

**Plain**

- settles into %t's thoughts and takes the reins, cold as a hand on the nape.

**Dry**

- borrows %t's body for a little while.

**Fierce**

- snaps "Mine." and threads will through %t's fingers from the inside.  *(blunt)*

**Solemn**

- enters %t's mind and assumes the place, uninvited as frost on glass.  *(courtly)*

### Dispel Magic

**Plain**

- says "Hold still." and brushes the magic off %t in a shower of sparks.

**Dry**

- picks the wrong magic off %t, patiently.

**Fierce**

- barks "Out!" and scrapes the magic away until the skin prickles clean.  *(blunt)*

**Solemn**

- speaks cleansing over %t, and the taint lifts like smoke off wet stone.  *(courtly)*

**Warm**

- says "There. Better." and brushes the last of the wrongness from %t.

### Fade

**Plain**

- becomes markedly less interesting.

**Dry**

- steps out of the foreground. "Who?"

### Levitate

**Plain**

- says "Mind the landing." and sends lightness into %t's bones.

**Dry**

- puts %t somewhere slightly above the ground.

**Solemn**

- speaks lightness into %t's bones until the feet forget weight.  *(courtly)*

**Warm**

- says "Easy now." and eases %t upward on a thread of calm.

## Warrior <!-- id: warrior -->

*Shouts, charges and bad ideas.*

<!-- 10 spells, 39 phrases -->

### Charge

**Plain**

- picks %t out of the crowd and runs at it, boots throwing sparks off the flagstones.
- closes the gap in one rush, shoulder tucked and mud kicking off the mail.

**Dry**

- says "Coming through!" and runs at %t with the urgency of someone late for dinner.

**Fierce**

- roars "Out of my way!" and closes the gap in a skid of dust and armour.

### Battle Shout

**Plain**

- bellows "With me!" loud enough to hurt.
- shouts until the stone rings and armour stops rattling.

**Dry**

- raises the volume until courage seems plausible.

**Fierce**

- bellows "Fight!" until the ground shakes.  *(blunt)*

**Solemn**

- speaks one word, and it carries to the back of the hall.  *(courtly)*

**Warm**

- says "We have this." and sells it with a nod nobody argues with.

### Taunt

**Plain**

- points at %t and says "Me. Try me."
- insults %t's mother, thoroughly.

**Dry**

- calls %t "Over here!" with feeling.

**Fierce**

- spits "Try me!" at %t, knuckles white on the haft.  *(blunt)*

### Execute

**Plain**

- looks down at %t and says "Done." with breath still fogging the visor.

**Dry**

- finishes what %t started.

**Fierce**

- barks "Down!" and puts every ounce of weight behind the blow.  *(blunt)*

**Solemn**

- passes sentence with one stroke that rings through the gauntlet.  *(courtly)*

### Shield Wall

**Plain**

- sets both feet on gravel until they stop sliding. "Nothing gets past."

**Dry**

- becomes temporarily inconvenient to kill.

**Fierce**

- plants the shield and dares anything through, boots dug to the ankle.  *(blunt)*

**Solemn**

- holds the line and does not yield, even when the rim begins to dent.  *(courtly)*

**Warm**

- says "Behind me." and raises the shield until the strap creaks.

### Intimidating Shout

**Plain**

- roars, and something in it is not entirely human.

**Dry**

- screams until nearby plans change.

**Fierce**

- bellows "Run!" until the rafters answer.

### Thunder Clap

**Plain**

- brings the ground up to meet everyone in a jar of teeth and dust.

**Dry**

- says "Down!" and brings the ground up.

**Fierce**

- roars "Down!" and cracks the earth.  *(blunt)*

### Berserker Rage

**Plain**

- stops pretending to be reasonable.

**Dry**

- mutters "Fine." and stops being careful.

**Fierce**

- snarls "More!" and the grip on the haft goes white-knuckled.  *(blunt)*

### Heroic Throw

**Plain**

- throws an axe and shouts "Catch!" The haft hums once leaving the hand.

**Dry**

- tosses steel at %t. Enthusiastically.

**Fierce**

- hurls the axe and roars "Take it!" with a wrist snap that pops.  *(blunt)*

### Victory Rush

**Plain**

- spits, grins, and keeps going.

**Dry**

- finds a second wind and spends it immediately.

**Fierce**

- barks "Again!" and surges forward on bloodied boots.  *(blunt)*

**Warm**

- says "Not done yet." and presses on through the ache.

## Paladin <!-- id: paladin -->

*Oaths, hammers and judgement.*

<!-- 10 spells, 60 phrases -->

### Lay on Hands

**Plain**

- presses both hands to %t and gives everything, heat draining out through the palms.
- says "Take mine." and means it, even when the knees go soft.

**Dry**

- mutters "All of it." and presses both hands to %t until the palms go numb.

**Fierce**

- barks "Stay up!" and pours it in until the hands tremble.  *(blunt)*

**Solemn**

- places both palms on %t and pays in full, down to the last warmth owed.  *(courtly)*

**Warm**

- tells %t, "Not your turn yet." and does not let go.

### Hammer of Justice

**Plain**

- brings the hammer down on %t with a crack like wet timber.
- says "Kneel." and swings before the word finishes.

**Dry**

- says "Down." and invites %t to reconsider footing.

**Fierce**

- roars "Down!" and the hammer lands hard enough to ring.  *(blunt)*

**Solemn**

- pronounces the blow before it lands, word by measured word.  *(courtly)*

**Warm**

- says "Sit this one out." and raises the hammer overhead.

### Consecration

**Plain**

- marks the ground and dares anyone to cross it, ash curling at the boot toes.
- sprinkles the circle and holds the line until the stone begins to glow.

**Dry**

- claims the ground and mutters "Mine."

**Fierce**

- shouts "This far!" and burns the border into the flagstones.

**Solemn**

- sets the ward into the ground and waits, unmoving as a boundary stone.  *(courtly)*

**Warm**

- says "Stand inside." and lays the ward in a careful ring.

### Divine Shield

**Plain**

- is briefly, gloriously untouchable.
- says "Not today." and locks the shell shut with a soft click.

**Dry**

- becomes the most irritating target in reach.

**Fierce**

- snaps "Try me." behind the barrier, fist on the rim.

**Solemn**

- raises the shield and stands unmoved, even as blows skid off.  *(courtly)*

**Warm**

- says "Give me a moment." inside the glow, voice muffled by glass.

### Redemption

**Plain**

- kneels by the fallen and refuses to let go, hands sunk past the wrist in cold earth.
- tells the dead "Get up. Not yet."

**Dry**

- argues death into a brief recess.

**Fierce**

- barks "Back!" at the stillness, knuckles bloody on the breastplate.  *(blunt)*

**Solemn**

- speaks over the fallen, word by word, unhurried as an oath read aloud.  *(courtly)*

**Warm**

- says "We are not done." and pulls %t back from the edge by the wrist.

### Judgement

**Plain**

- passes sentence on %t without raising voice, one flat syllable at a time.
- looks at %t and says "Verdict." with no room left to argue.

**Dry**

- renders %t's account in one stroke that chips the pauldron.

**Fierce**

- snaps "Guilty." and strikes before the echo fades.  *(blunt)*

**Solemn**

- speaks the sentence before the blow, each word weighed.  *(courtly)*

**Warm**

- tells %t, "This could have gone differently." and means it.

### Avenging Wrath

**Plain**

- unfurls power and stops holding back, wings throwing heat against the face.
- says "Enough." and means it now, voice stripped to bare metal.

**Dry**

- says "No more." and becomes visibly less negotiable, glow included.

**Fierce**

- roars and lets the wrath show, heat rippling off the pauldrons.

**Solemn**

- calls the full weight down and stands in it, unblinking.  *(courtly)*

**Warm**

- says "Behind me." and steps forward until the ground scorches underfoot.

### Blessing of Might

**Plain**

- lays a blessing on %t like a hand on a shoulder, grip firm through the mail.
- touches %t and says "Stronger." like a promise kept.

**Dry**

- hands %t a little more than %t had, no receipt required.

**Fierce**

- barks "Fight." into %t's ear loud enough to sting.

**Solemn**

- speaks strength over %t, word by word, until the breath steadies.  *(courtly)*

**Warm**

- tells %t, "You have got this." and makes it sound true.

### Hand of Protection

**Plain**

- puts a wall between %t and the world, palm flat against the air.
- wraps %t in something nothing passes, humming at the edge of hearing.

**Dry**

- makes %t temporarily everybody else's problem.

**Fierce**

- snaps "Not %t!" and shields with an arm still ringing from the last blow.  *(blunt)*

**Solemn**

- places the ward on %t and holds it, unmoved as a locked gate.  *(courtly)*

**Warm**

- says "Stay behind me." and seals %t in with a gentle push.

### Devotion Aura

**Plain**

- stands a little straighter, and so does everyone near, boots finding the same beat.
- sets the pace and others match it, step for step on the flagstones.

**Dry**

- says "Closer." and makes standing near look wise.

**Fierce**

- barks "Hold!" and the line stiffens like a drawn bow.  *(blunt)*

**Solemn**

- holds the centre until others find it, anchor-weight and steady.  *(courtly)*

**Warm**

- says "Stay close." and means stay close, shoulder to shoulder.

## Hunter <!-- id: hunter -->

*Marks, traps and one good animal.*

<!-- 10 spells, 58 phrases -->

### Hunter's Mark

**Plain**

- marks %t and says, quietly, "There you are," thumb still on the bowstring.
- sets the mark on %t and does not look away, even when %t moves.

**Dry**

- labels %t for later. Much later.

**Fierce**

- snaps "Found you." and marks %t before %t knows.  *(blunt)*

**Solemn**

- marks %t once, and that is enough.  *(courtly)*

**Warm**

- says "Got you." softly over the mark, hand on %p's flank.

### Aimed Shot

**Plain**

- breathes out, and lets the arrow go with a sharp twang.
- says "Steady." and takes the long shot, wind in the fletching.

**Dry**

- takes the shot %t was hoping nobody would take.

**Fierce**

- snaps "Got it." and looses before the bowstring stops humming.  *(blunt)*

**Solemn**

- draws, holds, and looses on the exhale.  *(courtly)*

**Warm**

- says "Quick, at least." and looses with an apologetic shrug.

### Multi-Shot

**Plain**

- looses three arrows in the time most need one, quiver rattling.
- says "All three." and the air goes full of whistling.

**Dry**

- sends three answers to a question nobody asked.

**Fierce**

- barks "All of you!" and looses until the string burns.  *(blunt)*

**Solemn**

- fires once, twice, thrice, each on the breath.  *(courtly)*

**Warm**

- says "Spread out." after the volley, ears still ringing.

### Freezing Trap

**Plain**

- sets the trap and steps back before the cold catches.
- says "Wait for it." and watches, breath held.

**Dry**

- leaves %t a surprise on the ground.

**Fierce**

- snaps "Hold still." and arms the trap with a click like teeth.

**Solemn**

- lays the snare and waits on the frost to climb the wire.  *(courtly)*

**Warm**

- mutters "Careful there." over the trigger, palm flat.

### Feign Death

**Plain**

- is, regrettably, dead.
- drops and plays dead, going limp mid-breath.

**Dry**

- plays dead and mutters "Convincing enough."

**Fierce**

- hits the ground hard and shouts "Wound!"  *(blunt)*

**Warm**

- says "Not me." and goes limp with the arrow still in the quiver.

### Mend Pet

**Plain**

- checks %p over, fingers in the fur, and says "You'll do."
- digs the arrowhead out of %p, gently.

**Dry**

- patches %p up with less fuss than %p deserves.

**Fierce**

- growls "Stay up, %p." through a mouthful of cloth.  *(blunt)*

**Solemn**

- works over %p until the breathing evens out.  *(courtly)*

**Warm**

- tells %p, "Almost good as new," and %p leans into the hand.

### Revive Pet

**Plain**

- refuses to let %p go, and is not asking.
- whispers "Not you. Get up." to %p with blood on the gloves.

**Dry**

- argues %p back into the fight.

**Fierce**

- snaps "Up, %p!" and pulls against the weight.  *(blunt)*

**Solemn**

- speaks over %p until the chest rises once.  *(courtly)*

**Warm**

- says "Come back." to %p and waits, hand on the scruff.

### Call Pet

**Plain**

- whistles once, and %p comes running through the brush.
- calls %p by name and %p answers with a bark.

**Dry**

- whistles once and says "Late again, %p."

**Fierce**

- barks "Here, %p!" sharp enough to carry.  *(blunt)*

**Solemn**

- calls %p once, and %p attends.  *(courtly)*

**Warm**

- says "There you are." when %p arrives, mud on both.

### Misdirection

**Plain**

- points %p at %t with two fingers, no shout needed.
- directs %p toward %t without raising voice, only a click.

**Dry**

- lets %p take the credit %t was saving for %p.

**Fierce**

- snaps "Go." at %p and %p is already moving.  *(blunt)*

**Warm**

- tells %p, "That one." and steps aside with a hand on %p's neck.

### Disengage

**Plain**

- leaves, at speed, and calls it tactics.
- says "Out." and springs backward, boots skidding on stone.

**Dry**

- decides %t can keep this problem.

**Fierce**

- barks "Not today!" and leaps back before the blade lands.  *(blunt)*

**Solemn**

- retreats one bound, already counting again.  *(courtly)*

**Warm**

- says "Cover me." on the way out, arrow nocked behind.

## Rogue <!-- id: rogue -->

*Quiet work.*

<!-- 9 spells, 50 phrases -->

### Stealth

**Plain**

- is no longer quite where you were looking, only the curtain moving.
- says "Gone." and slips out of sight without a footfall.

**Dry**

- was never in that spot. "Must have been someone else."

**Fierce**

- drops out of view mid-step, before you finish the thought.  *(blunt)*

**Warm**

- says "Quiet now." and fades into the wall shadow.

### Sap

**Plain**

- slips behind %t and offers the weighted cosh without a sound.
- catches %t unawares and lets the bag fall on a held breath.

**Dry**

- introduces %t to a short nap.

**Fierce**

- brings the cosh up and hisses "Sleep."  *(blunt)*

**Solemn**

- places the cosh against %t without a sound.  *(courtly)*

**Warm**

- whispers "Rest." at %t's ear, breath held.

### Vanish

**Plain**

- was never here. Ask anyone.
- says "Nowhere." and steps out of the room mid-stride.

**Dry**

- leaves no witness and murmurs "Forget it."

**Fierce**

- cuts away mid-step. Gone.  *(blunt)*

**Warm**

- says "Forget me." and is gone before the echo.

### Pick Pocket

**Plain**

- admires %t's coin purse. Briefly.
- says "Mine now." and relieves %t of a coin's weight.

**Dry**

- borrows from %t and whispers "Thanks."

**Fierce**

- takes what %t was not holding tight, fingers already moving.  *(blunt)*

**Warm**

- mutters "Finders keepers." and moves on.

### Kidney Shot

**Plain**

- finds the spot below the ribs without a word.
- finds the spot and says "There."

**Dry**

- reminds %t where the kidneys are. "Here."

**Fierce**

- snarls "Down." and strikes below the ribs.  *(blunt)*

**Solemn**

- lands the fist below the ribs and lets silence follow.  *(courtly)*

**Warm**

- says "Stay down." and walks away.

### Eviscerate

**Plain**

- finishes close and fast, blade still warm.
- says "Last one." and works %t over at arm's length.

**Dry**

- closes the account and mutters "Paid."

**Fierce**

- spits "Done." and cuts deep enough to feel.  *(blunt)*

**Solemn**

- ends the cut cleanly, up close.  *(courtly)*

**Warm**

- says "Sorry." and finishes anyway.

### Blind

**Plain**

- throws powder and says "Look away," hand already empty.
- throws a handful of dust at %t's face.

**Dry**

- takes %t's eyes off the matter at hand.

**Fierce**

- snaps "Eyes down!" and throws a stinging handful.  *(blunt)*

**Solemn**

- throws the dust and waits on the dark.  *(courtly)*

**Warm**

- says "This will sting." before the powder leaves the hand.

### Sprint

**Plain**

- decides this is someone else's problem now.
- says "Not today." and breaks into a run, heels flashing.

**Dry**

- reassigns the chase and calls "Too slow!"

**Fierce**

- snaps "Move!" and bolts before the shout fades.  *(blunt)*

**Warm**

- says "Tell them I went east." and runs, coin purse bouncing.

### Shadowstep

**Plain**

- crosses the room the short way, two heartbeats flat.
- says "Behind you." and arrives beside %t on a puff of ash.

**Dry**

- cuts the distance and murmurs "Closer."

**Fierce**

- appears behind %t without warning, blade already raised.  *(blunt)*

**Solemn**

- takes the hidden path to %t's flank, silent as dust.  *(courtly)*

**Warm**

- says "Missed me." beside %t, close enough to breathe on.

## Druid <!-- id: druid -->

*Forms, roots and rebirth.*

<!-- 10 spells, 53 phrases -->

### Bear Form

**Plain**

- says "Bear." and the shoulders bulk up before the rest catches.
- becomes bear-shaped and the air smells like wet hide.

**Dry**

- grows fur, claws, and a better opinion of standing ground.

**Fierce**

- growls "Back." and the shift lands with a thump of weight.  *(blunt)*

**Solemn**

- mutters "Heavy." and bone and fur settle into place.

**Warm**

- says "Easy now." and the change comes on like a deep breath.

### Cat Form

**Plain**

- slips into cat form and claws click once on the stone.
- says "Cat." and the world tilts closer to the ground.

**Dry**

- says "Smaller." and becomes faster, harder to pet.

**Fierce**

- snarls "Try me." and the ears flatten before the lunge.  *(blunt)*

**Solemn**

- whispers "Cat." and holds still until the fur settles.

**Warm**

- says "Quick feet now." and lands light on all fours.

### Travel Form

**Plain**

- says "Go." and four legs take the weight in one step.

**Dry**

- says "Faster." and hooves or paws replace boot-leather with a scrape.

**Fierce**

- barks "Move!" and the shift smells of wind and open road.  *(blunt)*

**Solemn**

- takes the road shape without hurry, and grass flattens underfoot.  *(courtly)*

**Warm**

- says "Stay close." and drops to four legs with a ready shake.

### Rebirth

**Plain**

- coaxes life back toward %t, and green warmth threads through the air.
- says "Not yet." and the ground under %t goes soft with new growth.

**Dry**

- interrupts %t's rest with inconvenient timing.

**Fierce**

- snaps "Up!" and throws a burst of green warmth at %t.  *(blunt)*

**Solemn**

- calls life back into %t, slow as sap rising in spring wood.  *(courtly)*

**Warm**

- tells %t, "The fight is not over. Get up."

### Healing Touch

**Plain**

- murmurs "Heal." and green warmth spreads through %t like sun through leaves.

**Dry**

- says "There." and passes a slow green warmth through %t.

**Fierce**

- snaps "Hold!" and presses palm to %t until the heat stops jumping.  *(blunt)*

**Solemn**

- says "Hold." and keeps steady pressure on %t like bark over a wound.

**Warm**

- says "Easy. Breathe." and the warmth comes in slow, even pulses.

### Entangling Roots

**Plain**

- asks the ground and green shoots crack through the soil around %t.

**Dry**

- tells %t "Stay a while." as vines race up from the turf.

**Fierce**

- snaps "Stay put." and the earth splits with the snap of dry wood.  *(blunt)*

**Solemn**

- bids the earth rise around %t, and roots wriggle up through grass.  *(courtly)*

**Warm**

- says "Sorry about this." while thorny roots boil up from %t's shadow.

### Moonfire

**Plain**

- calls "Mark." and a thin cold light sinks into %t's skin.

**Dry**

- says "There." and traces a pale circle on %t that keeps smouldering.

**Fierce**

- barks "Burn bright!" and silver fire dots %t and keeps smouldering.  *(blunt)*

**Solemn**

- sets cold starlight on %t, and it keeps eating inward.  *(courtly)*

**Warm**

- warns %t, "Hold still." and pins a cold silver mark between %t's shoulders.

### Hibernate

**Plain**

- sings low at %t until the melody goes soft and dragging.
- hums "Rest now." and the note thins out like dusk.

**Dry**

- suggests, gently, that %t nap now.

**Solemn**

- sings a lullaby at %t, and each line drops lower than the last.  *(courtly)*

**Warm**

- says "Sleep. I will watch." and keeps the hum going under %t's ear.

### Innervate

**Plain**

- says "Take this." and shares focus with %t in a rush of clear-headed air.

**Dry**

- says "You asked." and lends %t energy.

**Fierce**

- barks "Again!" and pours focus into %t until the air hums.  *(blunt)*

**Solemn**

- offers %t a breath of deep-wood quiet, cool and bottomless.  *(courtly)*

**Warm**

- says "I have you." and fills %t with focus that smells of rain on pine.

### Mark of the Wild

**Plain**

- says "Marked." and %t's skin prickles with borrowed toughness.

**Dry**

- tells %t "Later." and sets the mark anyway.

**Fierce**

- growls "Stronger." and stamps the wild mark on %t like a brand.  *(blunt)*

**Solemn**

- sets the wild mark on %t with care, and fur seems to stir on %t's arms.  *(courtly)*

**Warm**

- says "You will need this." and leaves %t smelling of bark and wind.

## Shaman <!-- id: shaman -->

*Elements and ancestors.*

<!-- 10 spells, 50 phrases -->

### Lightning Bolt

**Plain**

- draws lightning down and the air goes sharp and metallic before it leaves.
- says "There." and a bolt threads from cloud to %t with a crack.

**Dry**

- says "Sorry." and introduces %t to lightning.

**Fierce**

- barks "Down!" and ozone rolls off %t before the flash.  *(blunt)*

**Solemn**

- speaks the storm word over %t, and hair stands up all around.  *(courtly)*

**Warm**

- says "Look out!" a moment before the bolt lands.

### Chain Lightning

**Plain**

- says "Spread." and the bolt forks with a smell of hot copper.

**Dry**

- says "Next." and lets physics argue.

**Fierce**

- snarls "Spread!" and lightning stutters from hand to sky.  *(blunt)*

**Solemn**

- says "Again." and tracks each fork with a tapped finger.

**Warm**

- says "Everyone back." as the air starts to taste like pennies.

### Healing Wave

**Plain**

- says "Wash." and cool water shears over %t like a breaking wave.

**Dry**

- calls it "Medicine." and sends a wave through %t.

**Fierce**

- snaps "Live!" and the wave hits %t with salt and thunder.  *(blunt)*

**Solemn**

- pours the healing wave over %t, slow and steady as tide coming in.  *(courtly)*

**Warm**

- says "Hold on." and washes the hurt from %t in one cold rinse.

### Ancestral Spirit

**Plain**

- speaks over the fallen and ghost-light pools around %t like mist.
- says "Not yet." and the air around %t smells of cedar smoke.

**Dry**

- interrupts %t's rest with inconvenient timing.

**Fierce**

- barks "Up!" and throws ancestor-light at %t in a rough burst.  *(blunt)*

**Solemn**

- calls %t back with old words, each one dropped like a stone in still water.  *(courtly)*

**Warm**

- tells %t, "Come back. We need you."

### Earth Shock

**Plain**

- shoves the ground at %t.
- says "Down." and stone-force jumps from the soil into %t.

**Dry**

- says "Ground." and introduces %t to the earth at speed.

**Fierce**

- snarls "Down!" and a slab of stone-force cracks upward toward %t.  *(blunt)*

**Solemn**

- strikes %t with stone that arrives like a slammed door.  *(courtly)*

### Ghost Wolf

**Plain**

- says "Run." and fur ripples up the spine in one pass.

**Dry**

- says "Wolf." and pretends that was always the plan.

**Fierce**

- barks "Run!" and the shift comes with a wet snarl of wolf breath.  *(blunt)*

**Solemn**

- says "Go." and becomes wolf without looking back.

**Warm**

- says "Follow me." and drops to wolf with ears forward.

### Bloodlust

**Plain**

- counts "One. Two." and beats a rhythm that makes the chest tighten.

**Dry**

- says "Feel that?" and starts a drumbeat nobody asked for.

**Fierce**

- roars "Faster!" and the drumbeat hits like a second heartbeat.  *(blunt)*

**Solemn**

- beats a war rhythm into the air until dust jumps off the stones.  *(courtly)*

**Warm**

- says "Keep going!" and the rhythm surges hot under the skin.

### Heroism

**Plain**

- shouts "Now!" until veins stand out and the air shivers.

**Dry**

- yells "Up!" and suddenly everyone has energy.

**Fierce**

- bellows "Now!" and heroism ripples outward on a wave of brass sound.  *(blunt)*

**Solemn**

- lifts one voice, and the air rings like a bell being struck.  *(courtly)*

**Warm**

- cries "For each other!" and heroism spreads on a warm rush of breath.

### Water Walking

**Plain**

- speaks over the water until the surface skins over under %t.

**Dry**

- tells the water "Patient." and %t's reflection stops moving.

**Solemn**

- speaks until the water under %t holds flat as a pane of glass.  *(courtly)*

**Warm**

- says "Step lightly." and the water beneath %t tightens like stretched skin.

### Far Sight

**Plain**

- says "See." and the world pulls back until the horizon jumps closer.

**Dry**

- mutters "There." and peers at the horizon.

**Solemn**

- sends sight far, and blinks when it snaps back.  *(courtly)*

**Warm**

- says "Wait." and watches from very far away, wind in the teeth.

## Death Knight <!-- id: deathknight -->

*Cold, debts and the risen.*

<!-- 9 spells, 44 phrases -->

### Death Grip

**Plain**

- says "Here." and hauls %t in close on a thread of cold.
- barks "In!" and pulls %t inward on a bar of frost.

**Dry**

- closes the gap without asking %t's opinion, frost at the pull line.

**Fierce**

- snarls "Closer!" and the grip arrives like a slammed door of ice.  *(blunt)*

**Solemn**

- says "Come." and draws %t in on a line that hums with cold.

**Warm**

- says "Over here." and pulls %t close, frost still on the gauntlet.

### Death Coil

**Plain**

- says "Take." and spends a little death on %t in a pulse of winter air.

**Dry**

- tosses death at %t and says "Catch."

**Fierce**

- barks "Take it!" and a coil of cold green light jumps the gap.  *(blunt)*

**Solemn**

- offers %t a wrapped piece of the cold, sealed with a breath of frost.  *(courtly)*

### Raise Dead

**Plain**

- says "Rise." and the corpse stirs with a scrape of bone on stone.

**Dry**

- says "Stand." and the fallen obeys, joints creaking.

**Fierce**

- snarls "Up!" and the dead climbs up with a rattle of iron.  *(blunt)*

**Solemn**

- calls the body back to duty, and frost dusts the risen collar.  *(courtly)*

**Warm**

- says "One more try." and the corpse stirs, unhurried.

### Army of the Dead

**Plain**

- says "All of you." and the ground gives up its dead in a slow exhale of frost.

**Dry**

- says "Up." and opens the earth.

**Fierce**

- roars "Rise!" and the army answers with a sound like grinding ice.  *(blunt)*

**Solemn**

- speaks once, and graves empty to a winter stillness.  *(courtly)*

**Warm**

- says "Stand with me." and the dead rise, frost on every brow.

### Death and Decay

**Plain**

- says "Remember." and the ground recalls what it buried.

**Dry**

- says "Stay out." and makes the ground unpleasant.

**Fierce**

- growls "Rot here!" and the air turns sour with cold decay.  *(blunt)*

**Solemn**

- sets death on the earth and lets it work, cold creeping through the cracks.  *(courtly)*

**Warm**

- says "Clear out." before the rot takes hold and frost veils the air.

### Anti-Magic Shell

**Plain**

- says "More." and drinks the magic in until the shell hums.

**Dry**

- says "Mine." and eats the spell offered.

**Fierce**

- snarls "More!" and the shell blooms frost-white.  *(blunt)*

**Solemn**

- says "Hold." and takes the magic without flinching.

**Warm**

- says "On me." and the shell rises, frost crawling the shoulders.

### Path of Frost

**Plain**

- says "Ice." and freezes the water ahead with a crack like glass settling.

**Dry**

- says "Cold." and makes ice where none was invited.

**Solemn**

- says "Through." and sets frost underfoot that does not melt.

**Warm**

- says "Mind the step." and frosts the path for those behind.

### Mind Freeze

**Plain**

- says "Stop." and sends a blade of cold toward %t's brow.

**Dry**

- says "No." and aims a touch of frost at %t's brow.

**Fierce**

- snaps "Quiet!" and thrusts cold toward %t at arm's length.  *(blunt)*

**Solemn**

- offers %t a touch of frost at the temple, unhurried.  *(courtly)*

### Chains of Ice

**Plain**

- says "Hold." and wraps %t in river-cold.
- binds %t in chains of cold that clink like winter rigging.

**Dry**

- says "Still." and sends river-cold curling toward %t.

**Fierce**

- barks "Freeze!" and hurls chains of cold at %t.  *(blunt)*

**Solemn**

- sets ice chains on %t with a sound like winter rigging.  *(courtly)*

**Warm**

- says "Do not move." and sends cold chains toward %t.

## Monk <!-- id: monk -->

*Chi, brew and forward momentum.*

<!-- 8 spells, 48 phrases -->

### Roll

**Plain**

- rolls aside and says "Clear," landing without a sound.
- is elsewhere, and did it gracefully.

**Dry**

- was standing here. Was.

**Fierce**

- snaps "Move!" and is already gone, dust still rising.  *(blunt)*

**Solemn**

- steps light and leaves no mark.  *(courtly)*

**Warm**

- rolls past %t and murmurs "Mind yourself," close enough to ruffle cloth.

### Provoke

**Plain**

- invites %t to try, with one open palm and no hurry.
- gestures at %t and says "Try me."

**Dry**

- gives %t a reason to be rude.

**Fierce**

- snaps "Me. Now." at %t, chin lifted.  *(blunt)*

**Solemn**

- offers %t the first move, as courtesy.  *(courtly)*

**Warm**

- steps between %t and the others and says "My turn."

### Spinning Crane Kick

**Plain**

- becomes briefly a problem for everyone nearby.
- spins once and says "Room," heels clipping air.

**Dry**

- introduces several elbows to several people.

**Fierce**

- shouts "Out!" and spins through the crowd, a blur of cloth.

**Solemn**

- turns once, and the form is complete.  *(courtly)*

**Warm**

- spins through the press and calls "Behind me!" breath still even.

### Fortifying Brew

**Plain**

- drinks deeply and squares up, breath catching on the burn.
- swallows the brew and mutters "Steady."

**Dry**

- tastes the brew and does not flinch.

**Fierce**

- downs the brew and barks "Again," eyes watering.  *(blunt)*

**Solemn**

- drinks as one who knows the cost, and the cup comes away empty.  *(courtly)*

**Warm**

- raises the flask and says "For those behind me."

### Resuscitate

**Plain**

- breathes the fallen back into the fight, warm air against cold skin.
- presses a palm to %t and says "Up," feeling for a heartbeat.

**Dry**

- convinces death to wait its turn.

**Fierce**

- grabs %t and snarls "Up!" knuckles white.  *(blunt)*

**Solemn**

- breathes into %t, as the old art teaches, slow and measured.  *(courtly)*

**Warm**

- kneels by %t and says "Easy. Breathe."

### Touch of Death

**Plain**

- touches %t once, and the air goes still.
- places a hand on %t and says "Enough," palm flat and quiet.

**Dry**

- answers %t with one touch, no follow-through.

**Fierce**

- touches %t and growls "Done," one finger on the sternum.  *(blunt)*

**Solemn**

- places one finger on %t, and even the breath waits.  *(courtly)*

**Warm**

- touches %t once and whispers "No more," almost gently.

### Transcendence

**Plain**

- leaves a spirit behind and steps away, the echo still breathing.
- sets a mark and says "Wait here."

**Dry**

- saves a spot and uses the other one.

**Fierce**

- barks "Hold this ground!" and vanishes.  *(blunt)*

**Solemn**

- sets the spirit anchor with deliberate care, sand settling around it.  *(courtly)*

**Warm**

- leaves an echo behind and says "I will return."

### Legacy of the Emperor

**Plain**

- passes the old emperor's blessing to %t, hands steady as tea poured.
- speaks the legacy over %t until the air tastes of incense.

**Dry**

- lends %t a little borrowed grandeur.

**Fierce**

- shouts "Stand tall!" and bestows the legacy on %t.

**Solemn**

- bestows the emperor's blessing upon %t with both palms raised.  *(courtly)*

**Warm**

- touches %t's shoulder and says "You carry it well."

## Demon Hunter <!-- id: demonhunter -->

*Fel, wings and momentum.*

<!-- 8 spells, 47 phrases -->

### Fel Rush

**Plain**

- crosses the gap in a streak of green fire that leaves the air cold behind it.
- says "Now." and launches forward before the word settles.

**Dry**

- closes the distance before anyone finishes blinking.

**Fierce**

- snarls "Too slow!" and closes the gap in one bound.  *(blunt)*

**Solemn**

- commits to the rush, and the ground falls away under trailing fel.  *(courtly)*

**Warm**

- reaches %t first, skidding on the heels, and says "Move."

### Metamorphosis

**Plain**

- stops holding the demon in, and the skin cracks along old scar lines.
- unfolds into something with wings that throw a shadow twice their span.

**Dry**

- lets the other shape out for a while.

**Fierce**

- roars "Out!" and the wings come free with a crack of displaced air.

**Solemn**

- accepts the form, and the borrowed power settles heavy in the ribs.  *(courtly)*

**Warm**

- unfolds the wings wide enough to shade %t and says "Stay close."

### Eye Beam

**Plain**

- opens both eyes, and fel pours out in a sheet that scorches grass underfoot.
- turns the gaze on %t and murmurs "See."

**Dry**

- looks at %t with entirely too much honesty.

**Fierce**

- barks "Look at me!" and the beam cuts loose with a whine of heat.  *(blunt)*

**Solemn**

- holds the gaze until the air stops shimmering and the fel drains away.  *(courtly)*

**Warm**

- sweeps the beam low, heat washing the floor, and calls "Down!"

### Blade Dance

**Plain**

- turns once, and everything nearby regrets it.
- spins the blades and says "Wide." The glaives sing.

**Dry**

- adds a few extra cuts to the rotation.

**Fierce**

- snarls "Dance!" and the blades blur until they hum.

**Solemn**

- moves through the form, blade by blade, grit thrown from each turn.  *(courtly)*

**Warm**

- spins through the press, wind off the blades, and calls "Clear out!"

### Chaos Strike

**Plain**

- cuts %t with something that should not be a blade.
- strikes %t and mutters "There." Green sparks skitter off the edge.

**Dry**

- hits %t with chaos at an ill-chosen moment.

**Fierce**

- snarls "Break!" and the chaos lands with a crack like splitting wood.  *(blunt)*

**Solemn**

- delivers the strike, and the air around %t ripples green for a moment.  *(courtly)*

**Warm**

- strikes %t once and says "Enough."

### Imprison

**Plain**

- draws sigils around %t until the air between them goes still and glassy.

**Dry**

- draws sigils around %t that take up more room than %t does.

**Fierce**

- snarls "Stay." and slams sigils shut in a ring around %t.  *(blunt)*

**Solemn**

- inscribes runes around %t, and the space between them tightens.  *(courtly)*

**Warm**

- traces sigils around %t and says "Wait."

### Spectral Sight

**Plain**

- looks through walls, and the people within.
- opens the inner sight, outlines flickering on stone, and whispers "Show me."

**Dry**

- sees more than was strictly invited.

**Fierce**

- snarls "Found you." at the shapes the sight outlines.  *(blunt)*

**Solemn**

- opens the inner eye, and heat signatures bloom through the stone.  *(courtly)*

**Warm**

- marks a safe path and murmurs "This way."

### Glide

**Plain**

- steps off the edge and does not fall.
- spreads the wings and says "Easy." The descent goes quiet.

**Dry**

- declines gravity with the wings out.

**Fierce**

- drops from above, wings snapped tight, and shouts "Incoming!"

**Solemn**

- glides down without hurry or sound.  *(courtly)*

**Warm**

- sweeps low over %t and says "Jump."

## Evoker <!-- id: evoker -->

*Empowerment and the old flights.*

<!-- 7 spells, 42 phrases -->

### Living Flame

**Plain**

- breathes a small, patient flame at %t that clings to cloth and skin.
- lifts a hand and says "Burn steady." Smoke threads upward.

**Dry**

- sets a modest fire on %t and waits.

**Fierce**

- hurls flame at %t and snarls "Burn!" Heat rolls off the cast.

**Solemn**

- breathes a measured flame over %t until the air above shimmers.  *(courtly)*

**Warm**

- breathes warmth into %t and murmurs "There."

### Deep Breath

**Plain**

- takes a long breath, ribs spreading wide, and then the sky.
- draws breath until the ground drops away beneath and says "Up."

**Dry**

- occupies rather more sky than before.

**Fierce**

- roars, and the breath becomes a storm that flattens grass below.

**Solemn**

- draws the old breath from deep within, and scale-markings flare along the arms.  *(courtly)*

**Warm**

- lifts on the breath and calls "Clear below!" Wind rattles cloaks.

### Hover

**Plain**

- declines to touch the ground for a moment.
- rises a little, dust falling from boots, and says "Steady."

**Dry**

- floats with the dignity of something that ignores stairs.

**Fierce**

- snaps "Up!" and leaves the ground behind in a puff of displaced air.

**Solemn**

- hovers, unhurried, above the fray.  *(courtly)*

**Warm**

- hangs in the air and calls down "Need a lift?"

### Verdant Embrace

**Plain**

- wraps %t in green fire that smells of rain on hot stone.
- pulls %t close and says "Hold." The warmth comes through at once.

**Dry**

- embraces %t with more magic than tact.

**Fierce**

- snatches %t in green fire and barks "Live!" Heat pours off both.  *(blunt)*

**Solemn**

- enfolds %t in verdant fire older than the stones underfoot.  *(courtly)*

**Warm**

- wraps %t in green warmth and murmurs "Stay with me."

### Time Spiral

**Plain**

- folds a little time into everyone nearby, and footsteps come quicker.
- says "Quickly!" and time loosens its grip around the group.

**Dry**

- lends the group a sliver of stolen momentum.

**Fierce**

- snarls "Move!" and the air around everyone goes slick with borrowed speed.  *(blunt)*

**Solemn**

- turns the spiral, and seconds come free with a sound like tearing silk.  *(courtly)*

**Warm**

- spins time outward and calls "Take it." Heartbeats skip, briefly.

### Rescue

**Plain**

- picks %t up and carries %t clear, protesting all the way.
- says "Hold on." and hauls %t out of the way by the collar.

**Dry**

- relocates %t without asking nicely.

**Fierce**

- grabs %t and barks "Move!" Boots leave the ground at once.  *(blunt)*

**Solemn**

- lifts %t clear with a wingbeat worth of old strength behind it.  *(courtly)*

**Warm**

- sweeps %t up and says "Got you."

### Fire Breath

**Plain**

- exhales the way dragons do.
- opens the throat and says "Burn." Heat rolls forward in layers.

**Dry**

- breathes fire with entirely too much enthusiasm.

**Fierce**

- roars, and the fire follows in a wall that blackens stone.

**Solemn**

- breathes the old flame across the field until the grass curls under it.  *(courtly)*

**Warm**

- exhales flame low and calls "Down!" Warmth washes ankles.

## Pets <!-- id: pets -->

*Lines for what your pet does, on any class.*

<!-- 8 spells, 41 phrases -->

### Growl

**Plain**

- watches %p decide %t is the problem, fur up along the neck.
- lets %f do the talking.

**Dry**

- lets %p handle the introductions.

**Fierce**

- snaps "Take it!" and %p goes in before the word is finished.  *(blunt)*

**Solemn**

- sets %p upon %t, and it obeys without a sound.  *(courtly)*

**Warm**

- says "Go on, then." and lets %p work the growl loose in its chest.

### Claw

**Plain**

- watches %p open %t up, claws catching on mail.

**Dry**

- watches %p do something unhygienic to %t.

**Fierce**

- shouts "Again!" as %p tears in, claws catching daylight.

**Solemn**

- watches %p set claw to %t with the patience of a butcher.  *(courtly)*

**Warm**

- says "Good." as %p strikes once, twice, and stops.

### Bite

**Plain**

- watches %p find the throat.

**Dry**

- notes that %p has found the throat again.

**Fierce**

- barks "Hold it!" and %p bites down with a wet click.  *(blunt)*

**Solemn**

- watches %p finish what was started, jaw locked.  *(courtly)*

**Warm**

- says "That will do." as %p lets go, reluctantly.

### Spell Lock

**Plain**

- says nothing; %p bites the spell in half.

**Dry**

- lets %p explain why %t should not have done that.

**Fierce**

- snaps "Shut it!" and %p obliges with a snarl.  *(blunt)*

**Solemn**

- bids %p silence %t, and the last syllable never comes.  *(courtly)*

**Warm**

- says "Quick now." and %p closes in low and fast.

### Devour Magic

**Plain**

- watches %p eat the magic off %t, sparks on its teeth.

**Dry**

- watches %p have the magic for lunch.

**Fierce**

- snaps "Eat it!" and %p does, swallowing the glow.  *(blunt)*

**Solemn**

- has %p unmake what was woven on %t, thread by thread.  *(courtly)*

**Warm**

- says "Careful." while %p feeds, licking sparks from its lips.

### Torment

**Plain**

- lets %p do what it enjoys.

**Dry**

- lets %p enjoy itself, within reason.

**Fierce**

- shouts "Get in there!" and %p does, all claws and noise.

**Solemn**

- sets %p to its work, and %p takes its time.  *(courtly)*

**Warm**

- says "Not too long." and lets %p in, tail wagging aside.

### Suffering

**Plain**

- lets %f insist, loudly, on being hit.

**Dry**

- watches %f demand attention it will regret.

**Fierce**

- roars "Hold them!" and %p plants itself between %t and everything else.  *(blunt)*

**Solemn**

- bids %p bear what follows, and does not look away.  *(courtly)*

**Warm**

- says "Brace." and %p takes the weight with a grunt.

### Intercept

**Plain**

- points, and %p is already moving.

**Dry**

- points. %p was already going.

**Fierce**

- shouts "Now!" and %p hits like a thrown brick.  *(blunt)*

**Solemn**

- sends %p ahead, and it goes without looking back.  *(courtly)*

**Warm**

- says "Go." and %p goes, paws already in full stride.

## Professions & travel <!-- id: professions -->

*The quiet, everyday casts.*

<!-- 9 spells, 40 phrases -->

### Hearthstone

**Plain**

- turns the stone over until it warms, and says "Home."
- holds the hearthstone up until the glow fills both hands.

**Dry**

- decides that is quite enough adventuring.

**Fierce**

- says "Done." and takes the stone before the glow fades.  *(blunt)*

**Solemn**

- speaks the word of returning, and the world goes soft at the edges.  *(courtly)*

**Warm**

- says "Right. Home." to nobody in particular, stone already humming.

### Fishing

**Plain**

- casts a line and settles in until the bobber stops dancing.

**Dry**

- begins the long and thankless work of fishing.

**Solemn**

- casts the line and waits, as is proper, rod tip still.  *(courtly)*

**Warm**

- casts a line and says "No hurry." while the reel clicks.

### Mining

**Plain**

- sets to the rock with a practised swing, sparks skittering off steel.

**Dry**

- negotiates with the rock. The rock loses.

**Fierce**

- swings until dust coats the tongue, and tells the rock "Come on."

**Solemn**

- works the seam with care, listening for the hollow sound.  *(courtly)*

**Warm**

- works the rock, humming against the ring of metal on stone.

### Herb Gathering

**Plain**

- takes only what the plant can spare, roots still damp.

**Dry**

- robs a plant, gently.

**Solemn**

- takes the herb with thanks, dirt under the nails.  *(courtly)*

**Warm**

- says "Thank you." to the plant.

### Skinning

**Plain**

- works the hide free, carefully, knife warmed by the body heat.

**Dry**

- does the part nobody wants to watch.

**Solemn**

- takes the hide, and wastes nothing, scraping clean to the bone.  *(courtly)*

**Warm**

- works the hide free and says "Waste nothing." fingers tacky with fat.

### Cooking

**Plain**

- gets a fire going and something over it, grease popping in the pan.

**Dry**

- cooks. Results may vary.

**Solemn**

- sets the fire and the pot, in order, smoke rising straight.  *(courtly)*

**Warm**

- says "There is enough for everyone." over a pot already steaming.

### First Aid

**Plain**

- binds the wound the ordinary way, cloth going pink fast.

**Dry**

- applies a bandage and hopes.

**Fierce**

- snaps "Hold still." and binds it tight enough to bruise.  *(blunt)*

**Solemn**

- binds the wound, as any decent person would, knot flat and firm.  *(courtly)*

**Warm**

- says "This will sting." and binds the wound with steady hands.

### Disenchant

**Plain**

- unmakes it, and keeps the dust that settles on the bench.

**Dry**

- turns something perfectly good into dust.

**Solemn**

- unmakes the work and keeps what remains, glittering in the palm.  *(courtly)*

**Warm**

- says "Sorry." and unmakes it, dust puffing up between the fingers.

### Enchanting

**Plain**

- talks the magic into staying put, runes smoking on the metal.

**Dry**

- argues with the magic until it settles.

**Solemn**

- binds the enchantment where it belongs, and the air tastes of ozone.  *(courtly)*

**Warm**

- says "Hold there." and the magic holds with a faint blue hum.

---

# Creeds

These belong to a character rather than to a spell, so they are not keyed to one. Tick
a creed and its lines ride along on whichever spells you have already set up, at a
third of the weight of a spell's own lines — enough to season your casts, not to take
them over.

## Creed: the Horde <!-- id: creed_horde -->

*Lok'tar ogar.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "For the Horde." like a plain fact.

**Dry**

- mutters "For the Horde, apparently." and gets on with it.

**Fierce**

- roars "For the Horde!" loud enough to carry over the noise.
- bellows "Lok'tar ogar!" and does not wait for an answer.  *(blunt)*

**Solemn**

- says "For the Horde." as an oath, not a shout.  *(courtly)*

**Warm**

- says "Strength to you." to nobody in particular.

## Creed: the Alliance <!-- id: creed_alliance -->

*For the Alliance.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "For the Alliance." the way it was drilled in.

**Dry**

- offers a dutiful "For the Alliance." and leaves it at that.

**Fierce**

- roars "For the Alliance!" until the word goes ragged.
- shouts "Hold the line!" and plants both feet.  *(blunt)*

**Solemn**

- swears "For the Alliance, and all it keeps."  *(courtly)*

**Warm**

- says "Stay close, all of you." with a glance back.

## Creed: the Light <!-- id: creed_light -->

*For those who serve it.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "Light guide us." out of long habit.

**Dry**

- says "Light willing." without much confidence.

**Fierce**

- shouts "The Light is with us!" and believes it for a moment.

**Solemn**

- murmurs "By the Light, let it be so." with eyes shut.  *(courtly)*

**Warm**

- says "The Light keep you." and means every word.

## Creed: Elune <!-- id: creed_elune -->

*For the moon and her own.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "Elune be with us." quietly, as though indoors.

**Fierce**

- cries "Elune, give me strength!" with both hands open.

**Solemn**

- whispers "Elune-adore." and lets the word hang.  *(courtly)*

**Warm**

- says "May Elune watch over you." and touches a shoulder.

## Creed: the ancestors <!-- id: creed_ancestors -->

*For those who came before.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "The ancestors are watching." like a weather report.

**Fierce**

- shouts "For the ancestors!" and then the name of one of them.

**Solemn**

- says "Ancestors, guide my hand." with the palm turned up.  *(courtly)*

**Warm**

- says "Walk with the ancestors." to whoever needs to hear it.

## Creed: the elements <!-- id: creed_elements -->

*For earth, sea, sky and flame.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "The elements are restless today."

**Fierce**

- shouts "The elements answer!" over the noise of them doing it.

**Solemn**

- says "Elements, lend your strength." and waits to be heard.  *(courtly)*

**Warm**

- thanks the elements, quietly, the way one thanks a neighbour.

## Creed: the fel <!-- id: creed_fel -->

*For power, and what it costs.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "The fel does not tire." which is most of the appeal.

**Dry**

- observes that this was always going to end in fel.

**Fierce**

- snarls "Burn it all!" and sounds glad about it.  *(blunt)*

**Solemn**

- says "This is the price. It is paid."  *(courtly)*

## Creed: the shadow <!-- id: creed_shadow -->

*For the patient dark.*

<!-- creed pack: rides along on whichever spells you have set up -->


**Plain**

- says "The shadow is patient." as if quoting someone.

**Dry**

- notes that the shadow is, as ever, unhelpful.

**Fierce**

- hisses "Into the dark with you!" through the teeth.

**Solemn**

- murmurs "The shadow hears." and does not explain.  *(courtly)*
