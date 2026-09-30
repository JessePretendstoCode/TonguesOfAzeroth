# Cast phrases — reference copy

Generated from `CastLibrary.lua` by `tools/dump_phrases.lua`: **15 packs, 143 spells, 362 phrases**.

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
| **No faction or faith** anywhere | A Blood Elf paladin does not serve the Light; a battlecry belongs to a character, so it is left for the player to write |
| Keep it **short** | The line shares one 255-character message with a translation that runs longer than the English |
| `%s` spell · `%p` pet's name · `%f` pet's family · `%t` target | A phrase whose token cannot be filled is skipped for that cast, so `%t` and `%p` lines are safe |
| No possessive openers | Emotes render as `"Name "` + text with the space baked in, so `'s pet growls` becomes *Corvin 's pet growls* |

## Two or three lines, and no more

Every line ships to everyone, so a spell's set has to suit a grim Forsaken and a cheerful
Gnome alike. There are no tone tags and no character sheet to filter them — a line either
earns its place in the two or three, or it is cut.

The bound is not about space. The throttle will not let a spell speak twice inside five
minutes, so a fourth line is one almost nobody hears, and one more clip to render in
every voice pack.

Spend the two or three on **different shapes** rather than three readings of the same
beat: one that narrates with a concrete detail, one that speaks aloud, and — on a spell
worth it — one that is wry.

## Health

- **200 of 362 lines (55%) speak aloud.** The quoted half is the only part the language
  engine gets to transform, so this is the number that decides whether the feature shows
  itself off. The target is roughly half.
- **194 distinct spoken spans.** This is the size of a voice pack: one rendered clip per
  span, per race and gender. Reusing a short span across two spells is a saving, not a
  failure of imagination.
- **76 of 143 spells carry the full three lines**; the rest make do with two, which is
  the right answer for a spell with only two things worth saying about it.
- 159 of 362 lines use a `%` token.
- Longest line is 87 characters, Warlock / Hellfire: *spreads both arms and lets the fire spill outward until the stone underfoot goes black.*

---

## Warlock <!-- id: warlock -->

*Fel magic, pacts and pets.*

<!-- 13 spells, 34 phrases -->

### Immolate

- sets %t alight, and the heat rolls back over anyone standing close.
- snarls "Burn!" and the fire takes with a crack like wet wood.
- sets %t on fire and waits for the complaining to start.

### Shadow Bolt

- gathers the dark into one point and lets it go with a thump of cold air.
- barks "Down!" and the shadow arrives like a slammed door.
- says "Nothing personal." and lets the bolt fly.

### Corruption

- sets something patient working inside %t, slow as rot in a rafter.
- spits "Rot." and the word seems to stick.
- gives %t something to think about in an hour or so.

### Fear

- speaks a word %t was never meant to hear, and %t stops hearing anything else.
- says "Run. Go on." and means it.
- suggests, mildly, that %t has somewhere else to be.

### Drain Life

- closes a hand and draws the warmth out of %t in a thin grey thread.
- snarls "Mine." and doesn't let go until it is.

### Health Funnel

- opens a vein for %p without hesitating, and goes grey doing it.
- tells %p, "Hold on. Nearly there."

### Hellfire

- spreads both arms and lets the fire spill outward until the stone underfoot goes black.
- bellows "Burn with me!" and lets go of the last of it, wreathed to the shoulders.
- sets everything on fire, including the obvious, including both boots.

### Soulstone

- folds a soul into stone until the stone sits warm. "In case it comes to that."
- puts a little of %t somewhere safe. Insurance.

### Create Healthstone

- works a small red stone out of nothing, still slick from the making.
- holds the stone out to whoever needs it first. "Take it."
- produces a stone that tastes worse than the wound it mends.

### Summon Felhunter

- opens the air and %f steps through it, nose first.
- greets %p like an old dog. "There you are."

### Summon Voidwalker

- draws something vast and unhurried into the light, and the light gives way for it.
- says "Good. You're here." to %p.
- summons %p, who couldn't be less impressed.

### Summon Imp

- summons %p, already mid-complaint about the weather.
- says "Behave." to %p, hopefully.
- snaps %p into the world by the scruff and tells it to keep up.

### Ritual of Summoning

- chalks the circle and says "Mind the edges."
- draws a circle and waits for someone to stand in it wrong.

## Mage <!-- id: mage -->

*Fire, frost and the arcane.*

<!-- 11 spells, 29 phrases -->

### Fireball

- lobs a fireball that leaves the air tasting of soot.
- barks "Move!" and the fire goes anyway, hot enough to peel paint.
- throws fire at %t, as is traditional.

### Frostbolt

- exhales, and the air cracks with cold.
- snaps "Enough!" and frost answers with a crack like thin ice.
- cools %t down, somewhat abruptly.

### Pyroblast

- takes a long breath, and the whole room pulls toward the hands.
- bellows "Burn!" and lets the blast go hard enough to stagger anyone close.
- promises %t "This one will hurt." and keeps the promise.

### Polymorph

- rewrites %t into something woollier.
- snaps "Quiet!" and the changing spell leaves hoofprints in the dust.
- turns %t into something with fewer opinions.

### Blink

- steps sideways out of the world and back into it, leaving frost on the boots.
- was there. Was not. "Excuse me."

### Counterspell

- cuts the air with two fingers and says "No."
- interrupts %t mid-thought. As one does.
- says "Not that one." and folds the spell shut like paper.

### Ice Block

- pulls the winter in and holds still while breath fogs against the ice.
- mutters "Not today." and freezes solid with a sharp crack of settling ice.
- becomes temporarily unavailable.

### Arcane Intellect

- taps %t on the brow. "Try to keep up."
- says "You'll need this." and leaves %t blinking at the sudden clarity.

### Blizzard

- raises both hands and calls the storm down until the hail pings off armor.
- shouts "Fall!" and the snow comes down hard enough to sting exposed skin.
- calls down snow and says "Sorry about this."

### Conjure Refreshment

- conjures food out of thin air, as one does.
- says "You look hungry." and conjures a snack that steams faintly.

### Slow Fall

- says "Mind the landing." a little too late.
- calls "Easy now." down at %t and threads a gentle lift into the fall.

## Priest <!-- id: priest -->

*Light, shadow and the words between.*

<!-- 11 spells, 26 phrases -->

### Power Word: Shield

- speaks a word over %t and something closes around %t with a faint hum.
- snaps "Hold!" and the ward snaps shut with a pressure like deep water.
- says "You're not alone in this." and a steady warmth settles on %t.

### Flash Heal

- pours warmth into %t, quick enough to make %t gasp.
- barks "Stay up!" and slams the mending in hard enough to jar teeth.
- says "There. Breathe." and leaves steady warmth where the pain was sharpest.

### Renew

- murmurs "Rest a moment." over %t.
- leaves a small warmth behind in %t, like sunlight on the back of the neck.

### Resurrection

- kneels, breathes warmth back toward still lungs, and asks for one more.
- tells the fallen, "Come back. We're not finished."
- demands "Up!" into the stillness and won't stop until something moves.

### Shadow Word: Pain

- lets a thread of shadow settle into %t like grit under a nail.
- hisses "Hurt." and the shadow bites deep enough to leave a cold spot.
- murmurs "Remember this." over %t.

### Mind Blast

- looks at %t and pushes, and the thought arrives like a fist through a wall.
- slams "Out!" into %t's thoughts hard enough to ring skull-bone.

### Psychic Scream

- screams without making a sound.
- screams "Go!" without making a sound, and the pressure rolls outward anyway.

### Mind Control

- settles into %t's thoughts and takes the reins, cold as a hand on the nape.
- snaps "Mine." and threads will through %t's fingers from the inside.

### Dispel Magic

- says "Hold still." and brushes the magic off %t in a shower of sparks.
- picks the wrong magic off %t, patiently.

### Fade

- becomes markedly less interesting.
- steps out of the foreground. "Who?"

### Levitate

- says "Mind the landing." and sends lightness into %t's bones.
- puts %t somewhere slightly above the ground.

## Warrior <!-- id: warrior -->

*Shouts, charges and bad ideas.*

<!-- 10 spells, 25 phrases -->

### Charge

- picks %t out of the crowd and runs at it, boots throwing sparks off the flagstones.
- roars "Out of my way!" and closes the gap in a skid of dust and armour.
- says "Coming through!" and runs at %t with the urgency of someone late for dinner.

### Battle Shout

- bellows "With me!" loud enough to hurt.
- raises the volume until courage seems plausible.
- says "We've got this." and sells it with a nod nobody argues with.

### Taunt

- points at %t and says "Me. Try me."
- insults %t's mother, thoroughly.
- calls %t "Over here!" with feeling.

### Execute

- looks down at %t and says "Done." with breath still fogging the visor.
- finishes what %t started.

### Shield Wall

- sets both feet on gravel until they stop sliding. "Nothing gets past."
- becomes temporarily inconvenient to kill.
- says "Behind me." and raises the shield until the strap creaks.

### Intimidating Shout

- roars, and something in it isn't entirely human.
- bellows "Run!" until the rafters answer.

### Thunder Clap

- brings the ground up to meet everyone in a jar of teeth and dust.
- roars "Down!" and cracks the earth.

### Berserker Rage

- stops pretending to be reasonable.
- snarls "More!" and the grip on the haft goes white-knuckled.

### Heroic Throw

- throws an axe and shouts "Catch!" The haft hums once leaving the hand.
- tosses steel at %t. Enthusiastically.

### Victory Rush

- spits, grins, and keeps going.
- barks "Again!" and surges forward on bloodied boots.
- says "Not done yet." and presses on through the ache.

## Paladin <!-- id: paladin -->

*Oaths, hammers and judgement.*

<!-- 10 spells, 28 phrases -->

### Lay on Hands

- presses both hands to %t and gives everything, heat draining out through the palms.
- says "Take mine." and means it, even when the knees go soft.
- tells %t, "Not your turn yet." and doesn't let go.

### Hammer of Justice

- brings the hammer down on %t with a crack like wet timber.
- says "Kneel." and swings before the word finishes.
- says "Sit this one out." and raises the hammer overhead.

### Consecration

- marks the ground and dares anyone to cross it, ash curling at the boot toes.
- shouts "This far!" and burns the border into the flagstones.
- claims the ground and mutters "Mine."

### Divine Shield

- is briefly, gloriously untouchable.
- says "Not today." and locks the shell shut with a soft click.
- becomes the most irritating target in reach.

### Redemption

- kneels by the fallen and refuses to let go, hands sunk past the wrist in cold earth.
- tells the dead "Get up. Not yet."
- argues death into a brief recess.

### Judgement

- passes sentence on %t without raising voice, one flat syllable at a time.
- snaps "Guilty." and strikes before the echo fades.
- tells %t, "This could've gone differently." and means it.

### Avenging Wrath

- unfurls power and stops holding back, wings throwing heat against the face.
- says "Enough." and means it now, voice stripped to bare metal.
- roars and lets the wrath show, heat rippling off the pauldrons.

### Blessing of Might

- lays a blessing on %t like a hand on a shoulder, grip firm through the mail.
- tells %t, "You've got this." and makes it sound true.

### Hand of Protection

- puts a wall between %t and the world, palm flat against the air.
- makes %t temporarily everybody else's problem.
- says "Stay behind me." and seals %t in with a gentle push.

### Devotion Aura

- stands a little straighter, and so does everyone near, boots finding the same beat.
- says "Stay close." and means stay close, shoulder to shoulder.

## Hunter <!-- id: hunter -->

*Marks, traps and one good animal.*

<!-- 10 spells, 27 phrases -->

### Hunter's Mark

- marks %t and says, quietly, "There you are," thumb still on the bowstring.
- labels %t for later. Much later.
- snaps "Found you." and marks %t before %t knows.

### Aimed Shot

- breathes out, and lets the arrow go with a sharp twang.
- says "Steady." and takes the long shot, wind in the fletching.
- takes the shot %t was hoping nobody would take.

### Multi-Shot

- looses three arrows in the time most need one, quiver rattling.
- says "All three." and the air goes full of whistling.
- sends three answers to a question nobody asked.

### Freezing Trap

- sets the trap and steps back before the cold catches.
- snaps "Hold still." and arms the trap with a click like teeth.

### Feign Death

- is, regrettably, dead.
- plays dead and mutters "Convincing enough."
- drops and plays dead, going limp mid-breath.

### Mend Pet

- checks %p over, fingers in the fur, and says "You'll do."
- tells %p, "Almost good as new," and %p leans into the hand.

### Revive Pet

- refuses to let %p go, and isn't asking.
- whispers "Not you. Get up." to %p with blood on the gloves.
- says "Come back." to %p and waits, hand on the scruff.

### Call Pet

- whistles once, and %p comes running through the brush.
- whistles once and says "Late again, %p."
- calls %p by name and %p answers with a bark.

### Misdirection

- points %p at %t with two fingers, no shout needed.
- tells %p, "That one." and steps aside with a hand on %p's neck.

### Disengage

- leaves, at speed, and calls it tactics.
- says "Out." and springs backward, boots skidding on stone.
- decides %t can keep this problem.

## Rogue <!-- id: rogue -->

*Quiet work.*

<!-- 9 spells, 25 phrases -->

### Stealth

- is no longer quite where you were looking, only the curtain moving.
- says "Gone." and slips out of sight without a footfall.
- was never in that spot. "Must've been someone else."

### Sap

- slips behind %t and offers the weighted cosh without a sound.
- introduces %t to a short nap.
- whispers "Rest." at %t's ear, breath held.

### Vanish

- was never here. Ask anyone.
- says "Nowhere." and steps out of the room mid-stride.
- leaves no witness and murmurs "Forget it."

### Pick Pocket

- admires %t's coin purse. Briefly.
- says "Mine now." and relieves %t of a coin's weight.

### Kidney Shot

- finds the spot below the ribs without a word.
- snarls "Down." and strikes below the ribs.
- reminds %t where the kidneys are. "Here."

### Eviscerate

- finishes close and fast, blade still warm.
- says "Last one." and works %t over at arm's length.
- closes the account and mutters "Paid."

### Blind

- throws powder and says "Look away," hand already empty.
- takes %t's eyes off the matter at hand.

### Sprint

- decides this is someone else's problem now.
- says "Not today." and breaks into a run, heels flashing.
- says "Tell them I went east." and runs, coin purse bouncing.

### Shadowstep

- crosses the room the short way, two heartbeats flat.
- says "Behind you." and arrives beside %t on a puff of ash.
- cuts the distance and murmurs "Closer."

## Druid <!-- id: druid -->

*Forms, roots and rebirth.*

<!-- 10 spells, 24 phrases -->

### Bear Form

- says "Bear." and the shoulders bulk up before the rest catches.
- becomes bear-shaped and the air smells like wet hide.
- grows fur, claws, and a better opinion of standing ground.

### Cat Form

- slips into cat form and claws click once on the stone.
- says "Cat." and the world tilts closer to the ground.
- says "Smaller." and becomes faster, harder to pet.

### Travel Form

- says "Go." and four legs take the weight in one step.
- says "Faster." and hooves or paws replace boot-leather with a scrape.

### Rebirth

- coaxes life back toward %t, and green warmth threads through the air.
- says "Not yet." and the ground under %t goes soft with new growth.
- tells %t, "The fight isn't over. Get up."

### Healing Touch

- murmurs "Heal." and green warmth spreads through %t like sun through leaves.
- says "Easy. Breathe." and the warmth comes in slow, even pulses.

### Entangling Roots

- asks the ground and green shoots crack through the soil around %t.
- tells %t "Stay a while." as vines race up from the turf.
- says "Sorry about this." while thorny roots boil up from %t's shadow.

### Moonfire

- calls "Mark." and a thin cold light sinks into %t's skin.
- barks "Burn bright!" and silver fire dots %t and keeps smouldering.

### Hibernate

- sings low at %t until the melody goes soft and dragging.
- says "Sleep. I'll watch." and keeps the hum going under %t's ear.

### Innervate

- says "Take this." and shares focus with %t in a rush of clear-headed air.
- says "I've got you." and fills %t with focus that smells of rain on pine.

### Mark of the Wild

- says "Marked." and %t's skin prickles with borrowed toughness.
- says "You'll need this." and leaves %t smelling of bark and wind.

## Shaman <!-- id: shaman -->

*Elements and ancestors.*

<!-- 10 spells, 24 phrases -->

### Lightning Bolt

- draws lightning down and the air goes sharp and metallic before it leaves.
- barks "Down!" and ozone rolls off %t before the flash.
- says "Sorry." and introduces %t to lightning.

### Chain Lightning

- says "Spread." and the bolt forks with a smell of hot copper.
- says "Next." and lets physics argue.

### Healing Wave

- says "Wash." and cool water shears over %t like a breaking wave.
- snaps "Live!" and the wave hits %t with salt and thunder.
- says "Hold on." and washes the hurt from %t in one cold rinse.

### Ancestral Spirit

- speaks over the fallen and ghost-light pools around %t like mist.
- says "Not yet." and the air around %t smells of cedar smoke.
- tells %t, "Come back. We need you."

### Earth Shock

- shoves the ground at %t.
- snarls "Down!" and a slab of stone-force cracks upward toward %t.

### Ghost Wolf

- says "Run." and fur ripples up the spine in one pass.
- says "Wolf." and pretends that was always the plan.

### Bloodlust

- counts "One. Two." and beats a rhythm that makes the chest tighten.
- roars "Faster!" and the drumbeat hits like a second heartbeat.
- says "Feel that?" and starts a drumbeat nobody asked for.

### Heroism

- shouts "Now!" until veins stand out and the air shivers.
- cries "For each other!" and heroism spreads on a warm rush of breath.

### Water Walking

- speaks over the water until the surface skins over under %t.
- says "Step lightly." and the water beneath %t tightens like stretched skin.

### Far Sight

- says "See." and the world pulls back until the horizon jumps closer.
- mutters "There." and peers at the horizon.

## Death Knight <!-- id: deathknight -->

*Cold, debts and the risen.*

<!-- 9 spells, 21 phrases -->

### Death Grip

- says "Here." and hauls %t in close on a thread of cold.
- snarls "Closer!" and the grip arrives like a slammed door of ice.
- closes the gap without asking %t's opinion, frost at the pull line.

### Death Coil

- says "Take." and spends a little death on %t in a pulse of winter air.
- tosses death at %t and says "Catch."

### Raise Dead

- says "Rise." and the corpse stirs with a scrape of bone on stone.
- snarls "Up!" and the dead climbs up with a rattle of iron.
- says "Stand." and the fallen obeys, joints creaking.

### Army of the Dead

- says "All of you." and the ground gives up its dead in a slow exhale of frost.
- roars "Rise!" and the army answers with a sound like grinding ice.
- says "Stand with me." and the dead rise, frost on every brow.

### Death and Decay

- says "Remember." and the ground recalls what it buried.
- growls "Rot here!" and the air turns sour with cold decay.

### Anti-Magic Shell

- says "More." and drinks the magic in until the shell hums.
- says "Mine." and eats the spell offered.

### Path of Frost

- says "Ice." and freezes the water ahead with a crack like glass settling.
- says "Mind the step." and frosts the path for those behind.

### Mind Freeze

- says "Stop." and sends a blade of cold toward %t's brow.
- snaps "Quiet!" and thrusts cold toward %t at arm's length.

### Chains of Ice

- says "Hold." and wraps %t in river-cold.
- binds %t in chains of cold that clink like winter rigging.

## Monk <!-- id: monk -->

*Chi, brew and forward momentum.*

<!-- 8 spells, 21 phrases -->

### Roll

- rolls aside and says "Clear," landing without a sound.
- is elsewhere, and did it gracefully.

### Provoke

- invites %t to try, with one open palm and no hurry.
- gestures at %t and says "Try me."
- steps between %t and the others and says "My turn."

### Spinning Crane Kick

- becomes briefly a problem for everyone nearby.
- spins once and says "Room," heels clipping air.
- introduces several elbows to several people.

### Fortifying Brew

- drinks deeply and squares up, breath catching on the burn.
- swallows the brew and mutters "Steady."
- raises the flask and says "For those behind me."

### Resuscitate

- breathes the fallen back into the fight, warm air against cold skin.
- presses a palm to %t and says "Up," feeling for a heartbeat.
- kneels by %t and says "Easy. Breathe."

### Touch of Death

- touches %t once, and the air goes still.
- places a hand on %t and says "Enough," palm flat and quiet.
- answers %t with one touch, no follow-through.

### Transcendence

- leaves a spirit behind and steps away, the echo still breathing.
- sets a mark and says "Wait here."

### Legacy of the Emperor

- passes the old emperor's blessing to %t, hands steady as tea poured.
- touches %t's shoulder and says "You carry it well."

## Demon Hunter <!-- id: demonhunter -->

*Fel, wings and momentum.*

<!-- 8 spells, 21 phrases -->

### Fel Rush

- crosses the gap in a streak of green fire that leaves the air cold behind it.
- says "Now." and launches forward before the word settles.
- snarls "Too slow!" and closes the gap in one bound.

### Metamorphosis

- stops holding the demon in, and the skin cracks along old scar lines.
- unfolds into something with wings that throw a shadow twice their span.
- roars "Out!" and the wings come free with a crack of displaced air.

### Eye Beam

- opens both eyes, and fel pours out in a sheet that scorches grass underfoot.
- turns the gaze on %t and murmurs "See."
- looks at %t with entirely too much honesty.

### Blade Dance

- turns once, and everything nearby regrets it.
- spins the blades and says "Wide." The glaives sing.
- snarls "Dance!" and the blades blur until they hum.

### Chaos Strike

- cuts %t with something that shouldn't be a blade.
- snarls "Break!" and the chaos lands with a crack like splitting wood.

### Imprison

- draws sigils around %t until the air between them goes still and glassy.
- traces sigils around %t and says "Wait."

### Spectral Sight

- looks through walls, and the people within.
- opens the inner sight, outlines flickering on stone, and whispers "Show me."

### Glide

- steps off the edge and doesn't fall.
- spreads the wings and says "Easy." The descent goes quiet.
- declines gravity with the wings out.

## Evoker <!-- id: evoker -->

*Empowerment and the old flights.*

<!-- 7 spells, 20 phrases -->

### Living Flame

- breathes a small, patient flame at %t that clings to cloth and skin.
- lifts a hand and says "Burn steady." Smoke threads upward.
- sets a modest fire on %t and waits.

### Deep Breath

- takes a long breath, ribs spreading wide, and then the sky.
- roars, and the breath becomes a storm that flattens grass below.
- lifts on the breath and calls "Clear below!" Wind rattles cloaks.

### Hover

- declines to touch the ground for a moment.
- rises a little, dust falling from boots, and says "Steady."
- floats with the dignity of something that ignores stairs.

### Verdant Embrace

- wraps %t in green fire that smells of rain on hot stone.
- pulls %t close and says "Hold." The warmth comes through at once.
- wraps %t in green warmth and murmurs "Stay with me."

### Time Spiral

- folds a little time into everyone nearby, and footsteps come quicker.
- says "Quickly!" and time loosens its grip around the group.

### Rescue

- picks %t up and carries %t clear, protesting all the way.
- says "Hold on." and hauls %t out of the way by the collar.
- sweeps %t up and says "Got you."

### Fire Breath

- exhales the way dragons do.
- opens the throat and says "Burn." Heat rolls forward in layers.
- breathes fire with entirely too much enthusiasm.

## Pets <!-- id: pets -->

*Lines for what your pet does, on any class.*

<!-- 8 spells, 18 phrases -->

### Growl

- watches %p decide %t is the problem, fur up along the neck.
- lets %f do the talking.
- says "Go on, then." and lets %p work the growl loose in its chest.

### Claw

- watches %p open %t up, claws catching on mail.
- shouts "Again!" as %p tears in, claws catching daylight.

### Bite

- watches %p find the throat.
- says "That'll do." as %p lets go, reluctantly.

### Spell Lock

- says nothing; %p bites the spell in half.
- snaps "Shut it!" and %p obliges with a snarl.

### Devour Magic

- watches %p eat the magic off %t, sparks on its teeth.
- snaps "Eat it!" and %p does, swallowing the glow.
- watches %p have the magic for lunch.

### Torment

- lets %p do what it enjoys.
- shouts "Get in there!" and %p does, all claws and noise.

### Suffering

- lets %f insist, loudly, on being hit.
- says "Brace." and %p takes the weight with a grunt.

### Intercept

- points, and %p is already moving.
- says "Go." and %p goes, paws already in full stride.

## Professions & travel <!-- id: professions -->

*The quiet, everyday casts.*

<!-- 9 spells, 19 phrases -->

### Hearthstone

- turns the stone over until it warms, and says "Home."
- decides that's quite enough adventuring.
- holds the hearthstone up until the glow fills both hands.

### Fishing

- casts a line and settles in until the bobber stops dancing.
- begins the long and thankless work of fishing.

### Mining

- sets to the rock with a practised swing, sparks skittering off steel.
- negotiates with the rock. The rock loses.

### Herb Gathering

- takes only what the plant can spare, roots still damp.
- robs a plant, gently.

### Skinning

- works the hide free, carefully, knife warmed by the body heat.
- does the part nobody wants to watch.

### Cooking

- gets a fire going and something over it, grease popping in the pan.
- says "There's enough for everyone." over a pot already steaming.

### First Aid

- binds the wound the ordinary way, cloth going pink fast.
- says "This will sting." and binds the wound with steady hands.

### Disenchant

- unmakes it, and keeps the dust that settles on the bench.
- turns something perfectly good into dust.

### Enchanting

- talks the magic into staying put, runes smoking on the metal.
- argues with the magic until it settles.

---

# Spoken lines with no phrase

These were the creed packs — lines tied to no spell, which rode along on whatever you
already cast. The packs are gone: what a character believes is exactly the sort of thing
that wants writing rather than ticking, and eight tickboxes were never going to fit
anybody properly.

The words stayed. Audio can only be rendered ahead of time, and the **Says** picker only
offers lines that were — so dropping these would leave somebody who writes their own
`roars "For the Horde!"` with no way to make it audible, which is the one thing removing
the packs was meant to make easier. They are no longer phrases, but they are still voices:
write your own line and point it at one of these.

- "For the Horde."
- "For the Horde!"
- "Lok'tar ogar!"
- "For the Alliance."
- "For the Alliance!"
- "Hold the line!"
- "Light guide us."
- "The Light is with us!"
- "The Light keep you."
- "Elune be with us."
- "Elune, give me strength!"
- "Elune-adore."
- "The ancestors are watching."
- "For the ancestors!"
- "Walk with the ancestors."
- "The elements are restless today."
- "The elements answer!"
- "The fel doesn't tire."
- "Burn it all!"
- "The shadow is patient."
- "Into the dark with you!"
