# Changelog

All notable changes to Glyphic are documented here. The addon was called
Tongues of Azeroth before 0.5.3.

## [0.5.5]
- **Native dialect.** Pick the language your character grew up speaking, and
  the words your fluency doesn't cover come out in *that* instead of English.
  A half-learned tongue finally sounds like someone falling back on their own
  rather than a flawless Common speaker sprinkling in foreign words. Set it
  at the top of the Languages panel, or with `/glyphic native <language>`
  It is off by default and stays off when you upgrade, because it changes how
  every line you speak sounds and that should be asked for.
  Fluency now reads as a slider between two real languages: at nothing you
  speak entirely your own, at full you speak entirely theirs, and in between
  the line is genuinely part one and part the other. Speaking a tongue you
  know nothing of used to leave your chat in plain English; with a native
  dialect set it no longer does, which is the whole point.
  Your accent has little left to do once this is on. An accent reshapes
  English, and a native dialect is what removes the English.
- **A tag that names every tongue in the line.** A sentence that came out
  part Orcish and part Darnassian now says so: `[Partial Orcish, Darnassian]`.
  The tongue you were attempting leads and carries the fluency word; a native
  dialect is spoken perfectly by definition, so grading it says nothing.
  Each tongue in the tag is painted in its own colour, so a two-language line
  looks like two languages at a glance. The words themselves stay the colour
  your settings say they should be: colouring a tag used to leave an unclosed
  colour code behind it for each language it named, which painted the rest of
  the line too. That also quietly affected any line carrying an item link. A line
  that ended up entirely in one tongue names only that one, which means
  speaking at no fluency at all no longer claims a language that isn't there.
- **Both halves of a mixed line can now be read.** A listener who knows
  Darnassian reads the Darnassian words and still sees the Orcish as Orcish;
  a listener who knows both reads the whole sentence. Previously a mixed line
  travelled as a single mapping and was all-or-nothing, so whoever the tag
  named could read everything and everyone else could read none of it.
  Players on an older build get the half their tongue covers rather than
  nothing at all.
- **Fixed:** a line you understood was relabelled with *your* fluency, not the
  speaker's, so reading a sentence perfectly could still show it as
  `[Broken Darnassian]`. Decoded lines now keep the tag they arrived with.
- **The Languages panel scrolls.** It had grown past the bottom of the options
  window, which put the end of the language list out of reach. The list is no
  longer a scroll region inside a panel that doesn't scroll -- the whole page
  moves, and the rows stopped being clipped at the right-hand edge while they
  were at it.
- **Fixed:** a handful of words come back from a tongue unchanged -- Orcish
  "no" is still "no" -- and the addon counted them as translated, so a line
  made only of those wore a `[Broken Orcish]` tag over untouched English.
  They now fall through to your native dialect, or stay plain, like any other
  word the tongue doesn't cover.

## [0.5.4]
- **Profiles.** A new panel under `/glyphic` turns everything on a character --
  language, fluency, accents, channels, cast phrases, the languages you
  invented, and the shared colour palette -- into a code you can paste onto
  another character, another realm, or another install. `/glyphic profile
  export` and `/glyphic profile import <code>` do the same from chat.
  The reason it exists: WoW stores settings in a file named after the account,
  realm and character they belong to, so they are welded to one character on
  one install. That is invisible until the ground moves. When a beta ends, or a
  character is rerolled under a new name, there is no file to copy -- the
  destination does not exist yet, or is spelled differently. A code does not
  care where it is going.
  Importing replaces everything on the character and asks you to confirm first,
  telling you which character and which date the code came from, so you can
  tell two backups apart. The interface reloads afterwards.
  Codes carry a checksum. Chat windows, forum posts and spreadsheet cells all
  truncate long text, and a truncated code would otherwise decode into
  plausible nonsense and quietly import the wrong thing; instead it is refused
  with a reason. Codes are data and never code: nothing inside one is ever
  executed, so a profile someone hands you cannot run anything on your client.

## [0.5.3]
- Tongues of Azeroth is now **Glyphic**. Same addon, same author, same project
  page. The old name shortened to "ToA", which is already how people refer to
  the Tournament of Ages, and it never said what the addon did.
- Your settings carry over. Languages, fluency, learned tongues, colors, custom
  languages and cast phrases all survive the rename, and so do your keybinds.
  `/toa` still works alongside the new `/glyphic`, as do `/tongues` and
  `/oldgod`, so nothing already sitting in a macro needs changing.
- The addon folder is now `Glyphic`. WoW names a settings file after the folder
  an addon lives in, so a rename on its own would have left every existing
  profile on disk and unreadable, and your first login would have looked like a
  fresh install. A small `TonguesOfAzeroth` folder ships alongside to hand those
  settings over on first launch. It appears in your AddOns list, does nothing
  else, and will be removed in a later release -- leave it enabled until then.
- New icon: a speech bubble holding a line of writing in no alphabet, on the
  addon list and the project page.
- The minimap button is now a single bold rune rather than a shrunken copy of
  that bubble, and it tells you your state on sight: green while you are in
  character, red and struck through when you are not. The old button pointed at
  the voice feature, which is a different thing entirely, and at the size the
  minimap actually draws -- eighteen pixels, trimmed to about sixteen -- its
  line of glyphs was under two pixels each and its gold rim sat underneath
  Blizzard's own gold ring, so the whole thing read as a dark smudge. The disc
  behind the rune also goes cold and grey when muted, so the state still reads
  if you cannot tell red from green.
- `/glyphic` is the command, `/gly` the short form.

## [0.5.2]
- Fixed: a character with a surname was never recognised as themselves. WoW: Forever added
  surnames, and the addon decided whether a line was yours by comparing the sender to the
  one name `UnitName` reports. Those two need not agree once a surname exists: chat can put
  the full name on a line while `UnitName` answers the bare one, and neither is wrong. They
  simply differ, and a name compared against one form alone then matched nothing.
  Two things went wrong because of it, both silent. Spoken cast phrases are voiced when
  your own emote comes back from the server, so every cast was filed as a stranger's and
  nothing you cast ever made a sound, while the emote itself went out perfectly every time.
  And your own translated speech was held to your fluency when it was read back to you,
  so a surnamed player saw their own sentences returned as gibberish.
  The addon now asks every call that has an opinion about your name and accepts any of
  their answers, with and without a realm suffix. It also prefers the sender's GUID, which
  every CHAT_MSG event carries and which has no variants, falling back to the name on the
  Classic flavors where the event has none. It is deliberately not a "starts with your
  first name" test, since surnames exist precisely so that first names need not be unique,
  and that test would hand one player's lines to another.
- Fixed: a pinned voice line never played on a phrase that had no speech marks in it.
  Playback was gated on the emote containing something in quotes, on the reasoning that
  quotes are what mark a line as speech. That reasoning belongs to translation, which
  rewrites your words and so can only touch the words you are actually saying. A recording
  is not your words. Pinning one to a line that narrates is a deliberate act and the sound
  is the whole point of it, so it now plays whenever the emote fires.
  This was not a small corner. Of the 362 lines the packs ship, 162 narrate without saying
  anything, and the panel let you pin a recording to any of them and then showed it on the
  row as though it were set. Nothing reported the refusal, so the symptom was a cast that
  made no sound with no indication of why.
  The same gate applied to other people's lines, where it was also throwing away the half
  of the rendezvous it was meant to be waiting for: a pin that arrives over the wire is
  held until that player's emote shows up, and a narration emote was not counting, so the
  pin either expired or attached itself to whatever they said next.
- `/toa voice` now reports where the chain stopped instead of one count of everything.
  Sounds are counted separately by where they came from, because the Play button, your own
  cast and somebody else's line all finish at the same call and a single total cannot
  answer the only question it ever gets asked. Alongside those it names each way a cast can
  end up silent: an emote that never arrived, one this client will not let addons read, one
  with no sender to match, a phrase with nothing pinned, a pin naming a recording this
  client does not carry, and an emote that came back worded differently than it went out.
  The last of those prints both wordings, since the difference is the answer.

## [0.5.1]
- Cast phrases can be removed, not just turned off. Every line in a spell's list now has a
  Remove button. Before this only the ones you wrote yourself could go; a shipped line
  could be taken down to 0% so it was never picked, but it stayed on the list, and a spell
  you had worked over was mostly lines you had already decided against.
  What Remove does depends on who wrote the line, because the two cases genuinely differ.
  One of yours is deleted, along with the weight and the pinned recording hanging off it,
  since nothing will ever offer those words again and leaving the settings behind would
  mean retyping the same phrase later and finding it already retired with somebody else's
  voice on it. A shipped line is set aside instead: its pack will go on offering it, and
  unlike yours you cannot type it back from memory, so removing one has to be undoable.
  A spell with lines set aside shows a count and a Restore under the list, which brings
  them all back carrying the weight and the wording they had when they went.
  Remove asks first. It sits at the right of the phrase strip, one row above the Play
  button you press over and over while auditioning voices, so the misclick is likeliest at
  exactly the moment you are least expecting to lose anything. The question quotes the line
  it is about to take out and says whether it can be brought back.

## [0.5.0]
- Fixed: a brand-new install spoke fluent Shath'yar. A fresh character now starts out of
  character, knowing no tongue, set to *None (speak plainly)*. It used to land on Old God
  at 100%. `Language.DEFAULT` was still `"oldgod"` from back when the addon was called Old
  God Tongues, a new save took its language from it, and the one-time fluency migration
  then seeded that language to full from the default strength. Nothing was *spoken* until
  you went in character, but the moment you did, you were a fluent speaker of a tongue you
  never chose.
  That constant was doing two unrelated jobs, so it is now two. `Language.DEFAULT` is what
  a character speaks unless they pick something. `Language.FALLBACK` is what the engine
  resolves an unknown id to, and that one still has to be a real tongue, or a bad id would
  quietly emit plain English and look like the translator had broken. Upgrades are
  untouched: an existing character keeps the tongue and the fluency they had.
- The creed packs are gone; write your own. Eight tickboxes (the Horde, the Alliance, the
  Light, Elune, the ancestors, the elements, the fel, the shadow) were never going to fit
  anybody exactly, and now that any line can be reworded and given a voice, the better
  answer to "what does my character believe" is that you write it. The packs, their
  wildcard mechanism and the panel section they lived in are all removed, and a creed left
  ticked in an old save is cleared on upgrade. Write your own *"For the Horde!"* on
  whatever spell suits it and pin it to whichever of the game's recordings suits the
  character shouting it.
- A phrase can be pinned to any line the game ships. That's 30,572 recordings from 2,560
  speakers: Sylvanas, Nathanos, Arthas, Darion Mograine, the 57 player voices,
  abominations, ghouls, banshees, and most of the creatures in the game besides. They are
  sorted under what kind of line each one is, across 39 kinds, among them battle cries,
  threats, boasts, orders, mockery, farewells, attack grunts, pain and death cries. The
  grunts are spelled out as what they actually are, so you're choosing *"RAAAGH!"* or
  *"GURGH!"* rather than *Pain Sound 3*.
  Nothing is downloaded, because nothing is shipped but numbers: the client already has
  the audio on disk, and the addon plays it by file id. Every phrase row carries a Says
  strip. Browse voice lines opens the catalogue, Play auditions what is pinned, and the
  pinned line is spelled out beside them with the name of whoever says it, so which lines
  have sound is readable down the whole list at once rather than one row at a time behind
  a click. The browser narrows by category (player races, named characters, or any of
  WoW's own creature types), then by speaker, then by kind of line, with a search box over
  the top that matches names as well as words. Clicking a speaker's name in the results
  shows everything they say.
  The words on screen and the words you hear are allowed to disagree. A line reading
  *"Let it all burn!"* can speak with *"Burn!"*. That is the trade the feature exists to
  offer, because the alternative is that nothing anybody writes is ever spoken. The pin is
  keyed to the wording the pack shipped, so it survives rewording the line, which is the
  moment it is worth the most. It stays in your own settings and is never sent.
- Sound no longer costs you your tongue. Turning voices on used to turn translation off
  for cast phrases, because no finite set of synthesised clips could cover every garbled
  form a tongue produces. The game's own recordings have no such constraint: your words
  translate as usual and the recording plays over the top. Accents keep working too.
- The synthesised voice packs are removed. There was a second addon to download, hundreds
  of megabytes of locally rendered text-to-speech, one clip per line per race and gender.
  It doesn't hold a candle to the game's own voice actors, and the game has an enormous
  amount of material already. With it go the choice of synthesised speaker, the *hear
  other players* setting and the two dropdowns that sat on every phrase row. An old save
  has all three cleared on upgrade, along with any pin that pointed at a rendered clip
  rather than at a real recording.
- The lines contract the way people actually speak. *"You have got this."* isn't
  something anyone says out loud, and a handful of shipped lines read like that. Fourteen
  spoken lines and ten pieces of narration now contract: *"You've got this."*,
  *"You'll need this."*, *"There's enough for everyone."*, *"The fel doesn't tire."*
  Two kept their full forms because contracting them would be wrong rather than merely
  formal. *"There you are."* does not become *"There you're."*
  A line's audio is addressed by a hash of its exact wording, so every changed line is a
  different clip. All four built voices were re-rendered and the fifty-six clips the
  change orphaned were removed. That also finished moving `common-male`, `common-female`
  and `troll-male` off the older Piper renders onto Kokoro, so all four voices now match
  each other as well as the text.
- Rewording a phrase keeps what you typed. Clicking away from a line you were part way
  through rewording used to throw the whole edit away. Enter was the only thing that
  saved, and nothing on screen said so. The box looked like every other field on the
  panel, and every other field on the panel saves itself, so clicking off it read as
  finishing rather than abandoning.
  It now keeps the wording. Clicking another line, clicking the panel behind it, changing
  spell: all of them save. Two buttons on the row say which is which, a green check to
  keep and a red circle-slash to discard, the same pair the language rows use for making a
  language fluent or resetting it. Enter and Escape still do the same two things.
  A wording the addon cannot store, such as an empty line or one you already have, no
  longer vanishes while you read why it was refused. The editor stays open with the text
  still in it and the reason underneath, so it is something to fix rather than to retype.
  Underneath, the in-progress wording is held by the panel instead of by the text box.
  The phrase list redraws on every keystroke in the new-phrase field beneath it, and each
  redraw used to put the shipped wording back into the box mid-edit.
- Two or three lines per spell, and the character sheet is gone. The Bearing, Streak,
  Wording and Talkativeness dials have been removed, along with the 783-line library they
  selected from. In their place every spell carries two or three lines that suit any
  character, and all of them are always in the roll.
  It reads like a cut. In practice it is closer to the opposite. The sheet weighted the
  library by dropping every non-matching group to zero, so a character on the default
  sheet reached one or two lines per spell, on all 143 spells without exception, and one
  on any other Bearing reached about two and a half. Five and a half lines were written
  per spell to deliver two. The other four were written and reviewed for players who would
  never hear them.
  So the number of lines you can actually hear per spell has not gone down, and what you
  hear is better: the surviving set was picked from all five Bearings, which means the
  fierce and warm readings that only some characters used to reach are now everyone's.
  There is no space budget behind the number either. A spell will not speak twice inside
  five minutes, so a fourth line is one almost nobody reaches.
  Per-phrase weights still do the work the sheet was reaching for, and more directly:
  raise a line you like, set one to zero to retire it, reword any of them. Anything you
  wrote yourself is untouched. Saved character sheets are discarded on upgrade rather
  than left in the file looking meaningful.
- The number in front of each phrase says what it is. It was a bare 1 to 5 between two
  nudge buttons, which answered nothing: not what it counted, and not why nudging one line
  changed the figure on another. It now reads as a percentage, this line's share of the
  casts that speak, with a line above the list saying so and a tooltip on the nudge
  buttons explaining that the thing being stored underneath is still a weight, which is
  why the other numbers move with it. A retired line reads "off" rather than 0%, because
  one of those is a decision and the other is a rounding.
- Clicking a line to edit it puts the cursor at the start. It used to land at the end,
  which is the wrong end of a sentence you are correcting, and on a long line it scrolled
  the beginning off screen before you had read it.
- The beasts stopped all sounding like snakes. Fourteen creature tongues were borrowing
  another animal's word set: raptors and devilsaurs were pointed at Serpent, hyenas at
  Wolf, turtles at Trentish. It reads fine in a list and falls apart the moment you hear
  it, because a raptor rendered out of Serpent's pools hisses, *"Ssaaash ssaaazz
  sseeess"*, when the animal screeches, and nothing about a devilsaur is
  sibilant. Raptor, Devilsaur, Crocolisk, Chimaera, Nether, Hyena, Core Hound, Sporebat,
  Turtle, Wasp, Spider, Scorpid, Ravager and Silithid each have their own sounds now,
  built around the noise the creature actually makes. The same sentence, before and after:
  *"Ssaaash ssaaazz sseeess scaishsseaax"* becomes *"Kyieeeek kyieerr kriiaak
  kyiaakchkaak"* for a raptor, and *"Voraarr voraamm moroorm groaarn"* for a devilsaur.
  The ids haven't changed, so a saved setting, macro or share code naming one of them
  keeps working and simply starts sounding right. Qiraji still shares Nerubian's words,
  which is the one case where it's a relationship between peoples rather than a label
  stuck on an animal.
- The tribes stopped being four names for one tongue. Amani, Gurubashi and Drakkari were
  aliases of Zandali, which meant they produced the same sentence down to the last letter:
  four entries in the dropdown that did exactly the same thing. The same was true of
  Sindassi and Shalassian under Thalassian, Qiraji under Nerubian, and Low Common under
  Common. Each now has a sound of its own, drawn from where its people live. Amani are
  forest trolls and come out clipped and hard, Gurubashi are jungle trolls and come out
  breathy, Drakkari are ice trolls and come out heavy and guttural.
  *"Mek deh cyaa"* in Zandali is *"Mek dek cya"* in Amani, *"Mekh dheh cyaa"* in
  Gurubashi and *"Mek degh kyaar"* in Drakkari. Shalassian drifts furthest of all, the
  Nightborne having spent ten thousand years sealed under the Nightwell. Low Common is
  the odd one out, being a register rather than a region: it stays plain English and
  slurs a handful of words, so it reads fine for someone who doesn't run the addon.
  They still share their parent's vocabulary, which is the point. Fluency is stored per
  word set, so learning Zandali teaches you all three tribes rather than making you grind
  the same language four times. Speech stays deterministic and still decodes.
- Fixed: 100% fluency didn't mean you could read it. There are two ways to come to know a
  tongue and only one of them counted. Ticking a language in the Languages list marks it
  understood; dragging that same row's fluency bar to 100% sets your fluency and nothing
  else. The decoder only ever asked about the tick, so a character the addon itself
  described as *Perfect*, with the word right there in the tag on their own speech, still
  read their own words as gibberish. The only way out was Learn all, which ticks
  everything, and which made it look as though learning one language was broken while
  learning them all worked. Full fluency now counts on its own. Because fluency is stored
  per word set, this is also what makes Zandali's bar at 100% let you read Amani,
  Gurubashi and Drakkari.
- Fixed: a line lost its fluency word the moment you understood it. Speech goes out
  tagged *[Perfect Amani (Troll)]*, but a line that came back decoded was re-tagged
  *[Amani (Troll)]* from a different piece of code, so the tag appeared to break at
  exactly the point you learned the tongue. Both now name the language the same way.
- Fixed: every line you understood threw an error instead of being read to you. The fix
  above reached for the function that builds a language's display name, from inside the
  chat filter, where the client's own language for the line arrives as a parameter of
  exactly that name and shadows it completely. The call threw, the filter died before it
  could rewrite anything, and the line was shown untranslated: the same symptom as not
  knowing the tongue at all, with a Lua error on top. The filter now goes through the
  public name. That path is also tested end to end now, said, encoded, heard and decoded,
  which it never had been, which is how 1,500 passing checks had nothing to say about it.
- Your own words always come back to you in English. Fluency is how well you *speak* a
  tongue. It was never a question about whether you remember your own sentence, and
  someone with one word of French knows perfectly well that the *"Bonjour"* they chose
  means hello. The decoder asked the comprehension question about your own speech anyway,
  so at anything under 100% the addon handed your line back to you as gibberish. Your own
  chat line is now always the sentence you typed, at any fluency, including none.
  Nothing is hidden by this. How the line actually left your mouth, half in Amani at 50%,
  is in the chat bubble over your head, which is what everyone standing near you is
  reading; and the non-inline decode styles spell out both halves in chat for anyone who
  wants it there as well. The language tag is still on every line, so saying something in
  the wrong tongue is as visible as it ever was, which is its own kind of fun and happens
  to multilingual people constantly.
  Who you are is now worked out properly. This was guarded by comparing the sender to your
  own name, which the client does not answer consistently: your speech comes back as
  *Jessae-MoonGuard* while `UnitName` says *Jessae*, so the rule applied to your own
  speech roughly whenever a realm happened not to come along. Speaking to yourself no
  longer teaches you the tongue either, which that comparison had also been deciding at
  random.
- Fixed: a dialect looked like something you could speak but never learn. The tribes and
  the other dialects have no row of their own in the Languages list, because they share
  their parent's fluency, color and understood box. Nothing said so, though, so Amani
  appeared in the Speaking dropdown with no fluency bar anywhere and read as unlearnable.
  Each tongue's row now names the dialects it covers, greyed beside it, and "Make fully
  fluent" says which ones come with it.
  `/toa learned` was also wrong, and that one was a real bug: the chat decoder understood
  a dialect through its parent, while the list of what you understand checked only the
  dialect's own box, so chat would quietly decode Amani for you while `/toa learned`
  insisted you couldn't read it. Both now ask the same question, and the list marks an
  inherited one as *(through Zandali (Troll))* rather than implying you ticked it
  yourself.
- Player names stay readable inside translated speech. Say "Corvin, get back"
  in Demonic and Corvin now comes through as Corvin, the way a real language
  leaves a proper noun alone. Someone who can't read a word of the tongue can
  still tell they're the one being addressed, which is usually the point of
  saying their name.
  There is no API that lists the players around you, so the addon assembles a
  list instead. The best source turned out to be one already running: SAY, EMOTE
  and YELL are proximity-filtered by the server before they reach the client and
  carry the sender as plain text, so everyone nearby who has spoken is known for
  free. Your group, guild, friends, whoever you target or mouse over, and
  friendly nameplates fill in the rest.
  The hard part was not matching the wrong word. Every RP realm has players
  called Light, Storm, Raven and Hope, and an English word that silently stops
  translating is a worse bug than the one being fixed, because the sentence still
  looks right. So a name only counts when you capitalise it, common words are
  refused outright however many players are using them as names, names seen in
  passing are forgotten after twenty minutes, and public channels like Trade are
  never harvested. Toggle it under Chat, or with `/toa names on|off`;
  `/toa names` shows what is currently remembered.
  Names read off unit tokens are checked for Midnight's secret values first, and
  nameplate scanning stops entirely in combat and in instances.
- Those names are colored, so you can see which words came through on purpose. A
  protected name and a word your fluency happened to leave in English look identical from
  the outside, and the difference is the whole feature. Names now arrive in their class
  color where the class is known, from your group, guild, friends list or whoever you've
  targeted, and in interface gold where it isn't, which is most of the time, since a chat
  line tells us nothing about the speaker beyond their name and their GUID.
  Like the rest of the palette this happens when a line is displayed, never when it is
  sent. Your chat window is painted from your own list, the text on the wire stays clean,
  nobody is handed markup they didn't ask for, and none of it eats into the 255-character
  budget. It also means other people's speech is highlighted too, using the names your
  client already knows.
  Decoded lines are left alone, since once you can read the whole sentence there is
  nothing for a highlight to tell you. Player links are handed through untouched, because
  `|Hplayer:Corvin|h` carries the name in its target and a color inserted there would
  break the link rather than paint it. Under Chat beside the name toggle, or
  `/toa names color`.
- Cast phrases start much rarer. A new character now rolls a line on 5% of casts rather
  than 35%, with both pauses starting at the top of their sliders: two minutes of quiet
  after any line, five before the same spell speaks again. Play-testing the old defaults
  made the point. A cast phrase is text in other people's chat, and on a spammable spell
  the failure mode is a wall of it. Rare enough that a line lands as a moment is the
  setting worth shipping, and anyone who wants their character talking constantly can
  still find the sliders.
  Existing characters keep whatever they had set. The three numbers now live in one place
  instead of being repeated as a fallback in four files, and the test suite pins them,
  which it previously did not. Every test set its own pacing, so nothing knew what the
  addon actually shipped with.

## [0.4.0]
- Every cast phrase can be reworded, including the ones the packs ship. Only
  lines you had written yourself could be changed; a library line could be
  weighted or retired but not touched, so a phrase that was nearly right for a
  character had to be set to 0 and retyped from scratch as a new one, losing its
  Bearing and its place in the list. Click any line to edit it in place.
  A reworded library line keeps the text its pack shipped as its identity. That
  lets the weight you set survive the edit, keeps the line matched to its pack
  across updates, and leaves its Bearing and Wording applying as before. You are
  changing what it says, not what kind of line it is. The pack column turns into
  Revert on a line you have changed, and editing one back to its original wording
  clears the edit rather than storing a no-op. Lines you wrote are renamed where
  they sit, so the list doesn't reshuffle mid-edit, and their weight moves with
  them.
  Hovering a line now also shows its full text, which matters because the phrase
  column is narrower than most library lines.
- One "Speak in character" switch, and one voice behind it. There were two master
  switches (one for translation, one for accents), each with its own channel
  list, each governing half of how your character talks. Nothing said they were
  related, so the only way to find out that an accent needed its own switch *and*
  its own channel enabled was to be silently misheard.
  There is one switch now. It covers the tongue and the accent together. With it
  off you still read other players, still decode, still get the per-language
  colors, still build fluency. It is the switch you hit to answer your raid
  leader in plain English and hit again after (many times a session), which is
  why it is also a button on the floating bar and a keybind (Options →
  Keybindings → AddOns), not just a checkbox three panels deep.
  The two channel lists collapsed into one, "the channels I'm in character on".
  Where they disagreed the language list wins: turning translation back on
  somewhere a player had deliberately silenced would leave them unintelligible
  in a channel they had chosen to be clear in, while losing an accent somewhere
  is cosmetic and one click to restore.
  The switch is also visible at a glance: the minimap button and the floating
  bar go green in character, red out of it, so the state of something you toggle
  all evening no longer needs a hover to read.
- "None" is a choice in both lists, instead of a switch beside them. The accent's
  on/off checkbox is gone; speaking plainly is a voice like any other, so it is
  an entry in the accent list. The language list gained the same entry, which
  finally gives "plain English in my own accent" an honest spelling. Previously
  you had to fake it by parking on a tongue you were 0% fluent in.
  Upgrading: every old combination lands on the setup that sounds the same.
  Accents-on-with-translation-off (a popular setup) becomes *in character,
  language None*, keeping the accent rather than dropping it. Anyone who had an
  accent switched off keeps their pick in reserve, so `/toa accent on` hands
  back their own accent rather than the default.
- Settings live where the thing they configure lives. The panel you land on had
  become a second place to change your language and your accent, competing with
  the panels that own them, so people went looking for "my languages" under
  Languages, found the list but not the picker, and came back out.
  Both pickers moved to their own panels. Languages is now where you choose which
  tongue you speak and how fluently you speak each one; Accents is where you
  choose your accent. The landing panel keeps the one thing that is genuinely
  global (Speak in character) plus the minimap/bar options and the way through
  to everything else.
- "Your voice" and the preview sit with the dials that move them. Every control
  that shapes how you sound now lives on Languages (the tongue, the fluency, the
  color), so the readout and the preview followed them there. Hearing the result
  is part of tuning it, and it was one panel away from every control that
  changed it.
  The preview also runs the real outgoing path now, so it shows the *composed*
  voice: the tongue first, your accent over whatever English the fluency left
  behind. It drops to plain text the moment you go out of character. It
  previously modelled only the translation half, which meant it was quietly
  wrong for anyone speaking with an accent.
- The Language Trainer is its own panel. It is a whole minigame with its own
  fluency economy, and it was reachable only through a button on the landing
  page, so nothing in the navigation suggested it existed. It sits in the
  settings tree beside Languages, Chat and Accents now.
  *(Two fixes since the first cut. It seeded its RNG with `math.randomseed(time())`,
  and `time` is not a global on every client. The builder runs behind a pcall,
  so that one nil call aborted the whole panel and it never reached the settings
  tree. Seeding is now optional in every part; the client seeds its own RNG. It
  was also built early enough in the login sequence that the game could not yet
  say which tongues your race speaks, so it would have baked in a practice list
  it should have filtered; it now builds once the player exists.)*
- A language you create is a real language everywhere. Creating one on the Create
  Language panel left it half-registered: it might be selectable, but it had no
  row under *Your languages* (no fluency bar to drag, no color swatch, no star).
  Two separate causes. `GetLanguages()` is memoised and the custom registration
  path edited the registry directly without clearing the cache, so most of the
  addon carried on as though the tongue did not exist; the registry now
  invalidates on every change, in one place, rather than at each call site that
  remembered to. And the language rows were built once when the panel was first
  opened, with no way to add a later arrival. A language registered after that
  now gets a row made for it. Deleting a custom language removes it cleanly in
  the same pass.
- Dropdown menus close when you click away from them. They only closed by
  clicking the dropdown a second time, so every other instinct (click the panel,
  click another control, click the world) left the menu hanging over the UI. The
  menus are parented to the screen so they survive being opened inside a
  scrolling panel, which also meant nothing was positioned to notice the click
  that should have dismissed them.
- The floating language bar is on by default. It is the only always-visible
  readout of what you're speaking and whether you're in character, and it
  carries the in/out of character button. Having it off by default made the
  addon's main signal opt-in.
  Upgrading: existing characters have an explicit "off" written by the old
  default, which is indistinguishable from having switched the bar off on
  purpose, so the new default is applied once on first login after this update.
  Turn it off after that and it stays off.
- Fixed the Cast Phrases panel being shoved sideways. Everything from *Spell*
  downwards (the dropdown, the phrase list, *New phrase* and the preview) was
  drawn a column to the right and ran off the edge of the panel, with the Add
  button pushed off entirely. The pack checkboxes are a two-column grid where the
  right-hand column sits 240px in, and the section below them was anchored to
  *the last checkbox placed* rather than to the left-hand column, so an even
  number of creed packs indented the whole rest of the panel. Both columns of a
  row are the same height, so it now anchors to the left one. The spell-name box
  and the new-phrase box also take their right edge from the panel instead of a
  fixed width, so neither can run past it on a narrower canvas.
- Tooltips rebuild while you're still hovering them. They are built in `OnEnter`,
  so anything that changed state while one was open left stale text under a
  cursor that never moved: flipping in or out of character with the bar's own
  button still read "Speaking in character", and scrolling the minimap icon to
  cycle languages still named the previous tongue. The minimap button, the
  floating bar and its star and in-character button, and the per-language star
  and color swatch now redraw their tooltip in place. This covers LibDBIcon's
  private tooltip frame as well as `GameTooltip`. The minimap icon uses the
  former, so a first pass at this fixed everything except the one frame you
  cycle languages from.
- Switching in and out of character no longer reports to chat, unless you asked
  for it by typing `/toa on`, `/toa off` or `/toa ic`. The minimap icon, the
  floating bar's button and the keybinding all turn green or red as you use them,
  which says the same thing without a line of chat each time you flip.
- The language you're speaking is always the first row. The preview sits
  directly above the language list, and the pair is only worth anything if you
  can see both at once: drag a fluency, read the line it produces. In a fixed
  list of seventy tongues that meant hunting for your own row every time, which
  made the preview effectively unreachable for the one language it was
  previewing. Your tongue pins to the top (a sub-dialect pins its parent, whose
  row it shares), your favorites follow it, then everything else in the usual
  order. Switching tongues scrolls the list back up to it.
- Favorites are starred on the language rows, not in the Speaking dropdown. The
  one control for curating a shortlist was buried inside the long list the
  shortlist exists to shorten: you had to hunt through seventy entries to mark
  the handful that would have saved you the hunt. The star now sits on each
  language's row beside its fluency and its color, with the rest of what you set
  per language. The dropdown still groups your favorites at the top; it just no
  longer sets them. (Right-clicking a dropdown row still toggles it, which
  remains the way to favorite a *sub-dialect*: the rows are primaries, so
  Eldre'Thalassian (Skyborne) has no row, and no star, of its own.)
- "Your voice" gets its own line. It spent a version squeezed into a second
  column beside the Speaking dropdown, which fit the panel but not the content.
  The preview is a sentence, and half a panel is not enough to read one in.
- The fluency bars look like sliders. They are draggable, but a track with a lit
  section reads as a progress meter. It reports; it doesn't invite. There was
  nothing to suggest you could grab one. Each bar now carries a handle at its
  current value, drawn at every value including 0%, where the fill is hidden and
  there was previously nothing on screen to take hold of.
- Fluency is one number again, on the row it belongs to. The front panel's
  Fluency slider read like a live "how much is coming through" dial and got used
  like one, but it wrote character progress, so dialing it down to sound broken
  for one conversation permanently erased fluency you had earned.
  There is only one number now. Drag a language's bar on the Languages panel to
  set its fluency; that is the only place it is edited, and it is the same
  number everything else reads. (A brief attempt at a separate non-destructive
  "coming through" cap made this worse rather than better. Nothing could tell
  you which of the two numbers you were looking at. It is gone, and any saved
  value is cleared on upgrade.)
- Accents and languages compose instead of competing. They were two subsystems
  racing for each line, and the language always won: your accent was only ever
  heard on lines translation had left alone (Common, 0% fluency, or a channel
  with translation switched off). Configure an accent while speaking a tongue
  and it silently did nothing. `/toa debug` carried a diagnostic whose entire
  job was explaining why. That was a design problem worked around rather than
  fixed, and it is most of why the two read as separate addons bolted together.
  Partial fluency already leaves part of a line in English (that is what partial
  fluency *means*), and English spoken by a dwarf should sound dwarven. So the
  accent now applies to exactly that remainder:

  | Fluency | Dwarf speaking Orcish |
  |---|---|
  | 0% | *hello ma braw laddie we attack the tower at dawn* |
  | 50% | *magan mu braw laddie ko attack the throm no dawn, right enough.* |
  | 100% | *magan mu nogu revash ko goth'a kaz throm no uruk* |

  The translated words are held behind sentinels while the accent runs and are
  never touched by it. Decoding is a lookup on the exact encoded string, so an
  accent that respelled a foreign word would make the line undecodable for every
  listener. The mapping other players receive is now the composed line, accent
  and all, rather than the pre-accent version.
  For you: lines that came out as flat English now carry your accent, and anyone
  who had an accent configured but never saw it will start hearing it. Nothing
  needs reconfiguring.
- The settings are reorganized, because they had stopped being organized at all.
  Options had been landing on whichever panel was open when they were written,
  and the main panel had drifted into holding seven unrelated checkboxes in a
  flat stack (a master switch, the minimap button, the floating bar and its lock,
  tag appearance, a list filter and an instance toggle) above the language and
  fluency controls you actually opened it for. "Learned Languages" had gone the
  same way, collecting the decode style and output window (which are about
  reading other people, not about your learned list) and, most recently, the
  color toggles.
  Every panel now answers one question. That is also the rule for where anything
  new goes:
  - Tongues of Azeroth: *what am I speaking right now?* Auto-translate,
    language, fluency, preview. The minimap button and floating bar stay here
    under an Interface heading at the bottom. They are furniture rather than
    language settings, but "where do I turn off the minimap button" is a question
    people arrive with, and they are three checkboxes, not a panel.
  - Languages (was "Learned Languages"): *how is each tongue set up?* The
    per-language list, where what you understand, how fluently and what color it
    reads in are all edited on the same row. The color toggles sit directly
    above the swatches they govern, and "Hide languages my race already speaks"
    moved here from the main panel, next to the list it filters.
  - Chat (new): *where does translation apply, and how does it read?* Split by
    the two directions the pipeline runs in. *When you speak:* channels, the
    fluency tag, and pausing inside instances. *When you listen:* decode style
    and which window translations appear in. The instance heads-up now sits
    beside the option it explains instead of being the first thing a new player
    reads on the landing panel.
  - Accents, Cast Phrases, Create Language are unchanged; each was already one
    self-contained job.
  Nothing was removed and no setting was reset. Every option is still there, and
  section headings now separate groups instead of running them together.
  The fluency slider also says outright that it is a shortcut for the language
  you are speaking and shows the same number as that tongue's row under
  Languages. Two controls over one value is fine; two controls over one value
  with nothing saying so is how you get a bug report.
- New: a color for every tongue. Demonic reads as a warm orange, Old God as a
  deep purple, and the other sixty-odd arrive with their own distinct color
  rather than sharing one. The colors that were worth choosing by hand were
  chosen by hand; the rest are derived from the language's own id, with the
  saturation and brightness pinned to a band that stays legible on the chat
  background, so a beast or faction dialect is still recognisable without anyone
  hand-picking fifty more swatches. Sub-dialects inherit their parent, because
  Amani, Gurubashi and Drakkari already sound like Troll and should look like it
  too.
  The color lands whether or not you can read the line. Coloring happens before
  the decode attempt rather than as part of it, so a tongue you have not learned
  still announces itself. Your own speech is colored as well; the chat filter
  used to skip your own lines entirely.
- Tags are colored by default, speech is not. A tag marks the language without
  repainting a conversation, so that is the setting that ships on. Tint the
  spoken words too with the "Tint speech" toggle if you want it fuller.
  The two are independent. The first cut had it wrong: tag color was a master
  switch, so turning it off killed the speech tint along with it. All four
  combinations now do what the two checkboxes say they do, including
  tags-off/speech-on, which tints the words and leaves the tag in the channel's
  own color. A cast phrase is the one line where a single span is both the
  marker and the speech. It has no tag, and the quoted words are the only thing
  naming the tongue, so either setting colors it.
- WoW's own languages can be tinted too, for players who do not run the addon at
  all (real Orcish, Darnassian and the rest). This one ships off, because nearly
  all chat is Common or your faction's tongue, so turning it on tints most of the
  window rather than picking anything out of it. The client's names for these
  are not ours ("Dwarvish" to our "Dwarven"), so they go through an explicit
  map and a name we guessed wrong simply does not tint.
- Saved account-wide. The palette is the first setting in the addon that is not
  per-character, on the grounds that a color scheme is something you want on
  every alt rather than something to rebuild seventy times.
- Set colors from the swatch on each row of the Languages panel (click to pick,
  right-click for the default) or from `/toa color <lang> <hex>`. The color
  picker is feature-detected, since Blizzard replaced that API in 10.2.5, and
  falls back to the slash command where it is unavailable.
- Fixed: three languages appeared in the list twice, under two names. "Eredun
  (Demonic)" sat directly below "Demonic (Eredun)" and was the same tongue. A
  sub-language shares its parent's word set, so the two translated identically.
  "Forsaken" under "Gutterspeak (Forsaken)" and "Elemental" under "Kalimag
  (Elemental)" were the same mistake. The dropdown, `/toa list`, cycling, the
  Learned tab and the color list now show 66 languages instead of 69, with
  nothing lost: the three ids still resolve, so a macro, a saved setting or a
  share code naming one keeps working, and anything saved is moved onto the name
  that is shown. The test suite now enforces the rule that caught them. A
  dialect whose name says nothing its parent's name does not is a second label,
  not a dialect.
- Fixed: long language names overflowed the floating bar. The box was a fixed
  140px and "Eldre'Thalassian (Skyborne)" ran out of both ends of it. It
  measures its contents now, so every shipped name fits and a custom language can
  be called whatever you like.

## [0.3.1]
- `/toa` is the command now, and `/ogt` is gone. `/toa` has actually worked for
  some time, but the help text and the documentation still taught `/ogt`
  throughout, so that is what everyone learned. It was short for *Old God
  Tongues*, the addon's name two renames ago, and it told a new user nothing
  about what this addon is. Every command, every printed hint and every line of
  documentation now reads `/toa`. `/oldgod` and `/tongues` still work as
  aliases.
  If you have `/ogt` in a macro or a keybind, it will stop working. Swap it for
  `/toa`. Entries for older versions below are left as they were written, so they
  still name `/ogt`; read those as `/toa`.
- Added an AI disclosure to the README and the project page. This addon is built
  with heavy AI assistance and it is better to say so plainly than to let someone
  work it out from the commit history. The screenshots are real captures, which
  is worth stating separately, since AI-altered showcase images are the one thing
  CurseForge actually requires a disclaimer for.

## [0.3.0]
- New: Cast Phrases. Your character can now speak when a spell lands (*Corvin
  roars "Nuk'luk!"*) in whatever tongue you're currently speaking. Words in
  "quotes" inside a phrase are spoken aloud and go through your language and
  accent exactly as chat does; everything outside the quotes is narration and
  stays in plain English, since that's the part onlookers are meant to follow.
  Off until you turn it on, because it puts text in other people's chat.
- Fifteen opt-in phrase packs ship with it (one per class, plus pets and
  professions), covering 143 spells with 783 lines, a little over half of which
  have something spoken aloud. Tick a pack and its spells appear in the list,
  where any line can be reworded, reweighted, or retired. Packs are matched by
  spell *name* rather than id, so a single entry covers every rank of a Classic
  spell and the retail version at once; the trade-off is that the shipped packs
  only match an English client. Phrases you write yourself are captured from
  your own client and work on any locale.
- The lines read like a DM narrating the action, which took a second pass over
  all 783 of them. The first draft was flat in a specific way: "gathers the dark
  into one point and lets it go" states the action twice and never says what it
  was like. The fix was density rather than length. One concrete detail beyond
  the action, drawn from movement, sensation, sound or consequence, and rotated
  so consecutive casts don't come out the same shape. So the same line is now
  "gathers the dark into one point and lets it go with a thump of cold air."
  Length is tiered by how often a spell is cast, on the principle every DM
  guide repeats: a filler gets one tight detail, while a long cooldown earns the
  fuller clause. About a quarter of the library was deliberately left alone,
  mostly the dry lines, where understatement was already doing the work.
  Two rules came out of that pass and are now enforced by the suite. A line may
  not claim a mechanical effect that did not happen. The addon fires on cast and
  knows nothing about the outcome, so nothing may be described as knocked down,
  silenced or killed. And no line may run past 110 characters, since the emote
  shares one 255-character message with your name, the language attribution and
  a translation longer than the English it replaced.
- A character sheet decides how your character sounds. Rather than one house
  voice, every shipped line is written for a Bearing (Plain, Dry, Fierce, Solemn
  or Warm) and may carry a Wording of courtly or blunt. Pick a Bearing,
  optionally a second as a streak that cuts against the first, a Wording, and
  how much your character talks, and those groups rise in the roll while the
  rest drop out. "Solemn, courtly, measured" and "Dry, blunt, quiet" are
  recognisably different characters drawing on the same library.
  Nothing you write yourself is ever filtered by the sheet. You wrote it, so it
  is your character's voice by definition. Putting a weight on a library line by
  hand overrides the filter for that line.
  Talkativeness needs no separate content: whether a line speaks is visible in
  the line itself, so the dial simply reweights what is already there.
- Creeds are separate, opt-in, and not tied to any spell. What a character
  believes belongs to the character, so "For the Horde!" cannot sensibly be
  attached to Immolate. Tick any of eight creeds (the Horde, the Alliance, the
  Light, Elune, the ancestors, the elements, the fel, the shadow) and their
  lines ride along on whichever spells you have already set up, at a third of
  the weight of a spell's own lines. This replaces a "Battle cries" pack that,
  as first written, was keyed to a spell name nothing casts and so could never
  fire at all.
- Consequently the class packs name no faction or faith, which they previously
  did throughout: a Blood Elf paladin does not serve the Light, and a shaman who
  venerates the elements now gets that from the creed instead. Nor do any of the
  783 lines use a gendered pronoun for the caster. "Sets his feet" only ever
  suited half the people reading it. Both rules are enforced by the test suite
  rather than by good intentions.
- The spell list is built from your spellbook. It previously listed only spells
  that already had phrases, which made it look nearly empty and gave no way to
  find a spell other than typing its name exactly. It now has a Configured
  section and a "Your spells" section drawn from the live spellbook, including
  your pet's, and can hide library spells you have no way to cast, so a retail
  character stops being offered Classic's First Aid. It refreshes when you learn
  a spell or change spec.
- You only see your own class's pack. Fourteen irrelevant class packs were
  noise, and an Evoker pack is meaningless on Classic Era. Yours, the universal
  packs and the creeds are shown; "Show other classes" reveals the rest, since a
  warlock may well want a hunter's pet lines. Turning the feature on for the
  first time also ticks your class pack, and Pets if you have one, so that
  something actually happens.
- Weights decide how often each line comes up, 0 to 5, and 0 retires a line
  without deleting it. That is how you drop a library phrase you don't like,
  since a pack owns its own lines. Alongside that there's a single "how often"
  chance for whether a cast speaks at all, and two pauses (one global, one
  per-spell) that stop a spammable spell turning your emotes into a wall of text.
- Pets speak too, on any class: `%p` and `%f` fill in your pet's name and
  family. Your own casts and your pet's are the two Blizzard explicitly exempts
  from Midnight's secret values, so these are the only casts an addon can still
  read. Another player's are opaque.
- A keybinding opens a spell's phrase list from the spell itself. Hover it on
  your action bars or in the spellbook and press the bind (Key Bindings ->
  AddOns -> Tongues of Azeroth); the panel opens on that spell, ready for a new
  line. Macros are followed to the spell they cast. Also on `/ogt cast`, with
  `on|off`, `list`, `test [spell]` and `status`.
- Lines go out as emotes. `/say`, `/yell` and numbered channels have needed a
  hardware event (an actual keypress) since 8.2.5, so no addon on any client can
  send them from a cast handler. Emote carries no such requirement, which is why
  this can work at all.
- During raid encounters, Mythic+ and rated PvP, Midnight blocks addon chat
  outright. There's no way around it, so the line is printed for you alone
  instead, formatted as the emote would have read. The same happens when you've
  asked ToA to stand down inside instances. `/ogt cast status` says which of
  those is in effect.
- A cast phrase names its tongue in prose, not in a leading tag. Ordinary chat
  wears `[Broken Demonic] ` at the front, but an emote is rendered as your name
  plus the text, so the tag landed between the name and the verb and the
  sentence came apart: *Corvin [Broken Demonic (Eredun)] snarls "Aman!" and the
  fire takes hold.* The tongue is now named where a reader expects it, directly
  after the speech it describes: *Corvin snarls "Aman!" in Broken Demonic and
  the fire takes hold.* Once per line however many spans it has, and the
  sentence gets its full stop back when the speech ran to the end.
  Receivers find the tongue by name instead of by position, so a line still
  proves which language it is in. Partial decoding for a tongue you are part way
  through learning keeps working, and so does passive learning by overhearing,
  though that now counts only the spoken words, not the English narration around
  them, which was over-generous. When you do understand the line, the decoded
  version no longer gets a `[Language]` marker stapled to the front either, since
  the sentence already says it.
- Incoming emotes are now decoded. ToA has always translated a typed `/e` on the
  way out but never read one on the way in, so a translated emote was
  permanently gibberish to every recipient. Emote joins say and yell in the
  decode path, which is also what lets other ToA users understand the spoken part
  of a cast phrase.
- Added `tools/test_casts.lua`, an offline test (123 checks) that drives the
  cast engine against a stub of the WoW API: token substitution, quoted speech,
  weighting, the throttles, pack opt-in, the lockdown fallback, the tone
  weighting, and a render of every shipped phrase to catch a typo'd token or an
  unbalanced quote. It also holds the library to its own writing rules, failing
  the run on a gendered pronoun, a faction reference in a class pack, a stray
  non-ASCII character, or a spoken-line ratio that has drifted away from half.
- Fixed the help text under the Accents panel's Interjections slider rendering
  on top of the slider's own Off/Occasional/Often labels.

## [0.2.25]
- New: Favorites. Seventy-odd tongues ship with the addon and a character
  typically speaks a handful, so the dropdown had become a haystack. Every row
  in the language list now carries a hollow star; click it and it fills in and
  the language moves up into a Favorites section at the top of the list, in the
  order you added them. It leaves the main list when it does, rather than
  sitting in both places, so there's only ever one row per tongue. The menu
  stays open, so a shortlist can be built in one pass. Right-click anywhere on
  a row does the same, for anyone who'd rather not aim at a 16px star, and
  there's `/ogt fav [id]`, `/ogt fav list` and `/ogt fav off`.
- Favoriting a primary language doesn't orphan its dialects: they stay where
  they were in the main list, just un-indented now that the parent row that was
  above them has moved to the top.
- The floating language bar has a star that toggles "scroll only my favorites".
  It governs every way you cycle (the bar, the minimap wheel, `/ogt next` and
  `/ogt prev`) and is on by default, so with favorites set they're what you
  walk through; switch it off to walk everything you've learned instead. The
  star only lights up when you actually have favorites, so it never claims a
  filter is active when there's nothing to filter. Also on `/ogt favonly
  [on|off]`, since the floating bar is optional and the toggle would otherwise
  be unreachable with it hidden.
- The star and Next buttons beside the language dropdown are gone. They crowded
  the row and both jobs are better placed elsewhere: favoriting is on the
  dropdown rows themselves, and cycling was already on the floating bar, the
  minimap scroll wheel and `/ogt next`.
- The star is Blizzard's own favorite art (the one on Auction House searches
  and profession recipes) rather than a glyph or a bundled texture. Atlas names
  have moved between expansions and the atlas API doesn't exist on the older
  clients we ship for, so the exact art is probed for at runtime and falls back
  to the cooldown starburst, tinted gold, on anything that has neither. Where
  no hollow star is available the filled one is dimmed and desaturated instead,
  which is indistinguishable at 16px.
- Favorites take over cycling. Once you've starred anything, `/ogt next`, `/ogt
  prev`, the Next button and the minimap scroll wheel walk your favorites instead
  of everything you've learned; with none starred, nothing changes. Unlike the
  learned-language fallback, favorites aren't filtered by trainer progress. You
  picked them deliberately. Tongues your race natively speaks are still skipped
  either way.
- The dropdown widget grew two general-purpose features to support this: inert
  section headers, and a right-click action per row that leaves the menu open
  and holds its scroll position.

- Accent tails are far less frequent, and no longer arrive in clusters. They
  fired on roughly 26% of messages with nothing stopping two in a row, which is
  what made them feel constant; it's now about 5%, and never twice in a row. The
  gate changed from a bare per-message coin flip to a minimum three-message gap
  between tails, a higher word-count floor (5, up from 3), and half the chance on
  mid-length lines, so a flourish lands on a sentence with room for it.
- Tails now fit the sentence they're joining. A question no longer absorbs a
  statement interjection. "Where's the inn, aye?" was not English, so only a
  standalone phrase or an emote may follow one. A tail is also skipped when the
  message already uses its wording, which is what stopped "mon" from turning up
  twice in one breath. That check matches whole words, so "monk" isn't read as
  "mon" nor "player" as "aye".
- Dwarven has three tails instead of one. Earlier feedback removed ", lad", ",
  ah tell ye" and ", ye ken", leaving ", aye." by itself, so every Dwarven
  flourish was the same word. It's now joined by ", nae doubt." and ", right
  enough.", both gender-neutral, which also gives the no-repeat rule a choice.
- The options preview and `/ogt debug` no longer disturb tail spacing, so
  previewing a line doesn't consume the flourish your next real message would get.
- New "Interjections" slider on the Accents tab (and `/ogt accenttails
  <0-100>`) to tune this yourself, from Off through to roughly twice the default
  rate. The minimum gap between tails is deliberately not on the dial. Spacing
  is what stops them clustering, so even the top of the slider won't bring back
  the old run-of-three effect.
- Troll no longer turns "friend" into "mon" as well as "man". Two swaps and a
  tail all produced the same word, which is most of why it felt relentless.
  "friend" now uses Patois' own word, "bredren".

- New language: Eldre'Thalassian, the tongue of the Skyborne (the new race in
  WoW: Forever), as `/ogt lang skyborne`. Blizzard wrote no parser word list for
  them (the race's listed languages are Darnassian plus Common or Orcish by
  faction), so unlike the other playable-race tongues this one comes from a
  syllable generator, as Old God (Shath'yar) does. It is its own language, not
  an alias of Darnassian: the shen'dorei fled Eldre'Thalas after the War of the
  Ancients and spent ten thousand years sealed in Skywall, the same span over
  which Thalassian split from the same root, so they get their own sound. The
  pools stay recognisably elven (liquid consonants, the "quel" and "shen" roots,
  apostrophes on longer words) over airier vowels and the sibilants of their
  wind-spirit patrons.
- Because it is its own language rather than a dialect, trainer fluency in it is
  earned separately and does not come with Darnassian.
- It leads the language list rather than sitting seventy entries down the
  dropdown, since it's the one most people are looking for at the moment. Old
  God (Shath'yar) is now second, but is still the default and still what the
  ambient whispers key off. Every list in the addon reads from the same order, so
  `/ogt list`, cycling and the Learned tab all match the dropdown.

- The addon list now shows a scroll instead of a red question mark. None of the
  TOC files declared an icon, so the client fell back to its placeholder. All of
  them now set `## IconTexture:` to the parchment scroll `INV_Scroll_03`, a
  built-in icon that exists on every flavor we ship. Note that the field arrived in
  patch 10.1.0, so the Wrath TOC (interface `30405`) still ignores it.
- The minimap button uses that same scroll, so the two match. It reads from one
  `ICON` constant in `UI.lua` now rather than repeating the path per call site.

## [0.2.24]
- Dropped support for the 2010-era 3.3.5a client (Project Ascension and similar
  private servers), which has shut down. The base `TonguesOfAzeroth.toc` no longer
  declares interface `30300`; it now mirrors retail and serves purely as a
  fallback for any client that has no matching flavor TOC. If you still need a
  3.3.5a build, 0.2.23 remains available and works.
- Removed the code paths that existed only for that client. The legacy
  `InterfaceOptions_AddCategory` registration branch is gone, along with the
  now-unread `Compat.isLegacy` / `Compat.isModern` flags and a `math.randomseed`
  workaround for custom clients that stripped it. Nothing that serves a live
  client was touched: the portable widgets stay (they exist to dodge retail's
  removed `UIDropDownMenu` and template churn), and so does the standalone
  window, which is what the Language Trainer has always opened in.
- The base TOC now loads the bundled libraries like every other flavor, so the
  minimap button goes through LibDBIcon everywhere.
- Documentation no longer claims 3.3.5a support, and the README's stale "no
  external libraries" line is corrected. LibDBIcon has shipped since 0.2.19.

## [0.2.23]
- Support for World of Warcraft: Forever. Forever is its own game type
  (`camelot`) rather than a retail patch, so the addon now ships a
  `TonguesOfAzeroth_Camelot.toc` built for interface `16001`. Without it a Forever
  client fell back to the retail TOC and flagged the addon as far out of date,
  because Forever numbers its builds `1.60.x` even though it runs Midnight's API.
- Fixed UI taint on Forever. The check for "does this client use the secure chat
  pipeline?" compared the interface number against `120000`. Forever reports
  `16001`, so it failed that test, took the legacy path and overwrote the global
  `SendChatMessage`, reintroducing exactly the taint fixed in 0.2.16, where
  opening the Character frame or Game Menu throws "attempt to compare a secret
  number value". The check now detects `issecretvalue` instead, which ships with
  the secure chat pipeline itself, so Forever is handled correctly and 3.3.5a and
  the Classic flavors keep the hook they still need.
- Corrected the author name in the TOC files, which still read a placeholder.

## [0.2.22]
- Accents now keep working inside instances. The instance auto-disable added in
  0.2.20 switched off everything, accents included, so an accent simply did nothing
  in a raid or dungeon. Translation genuinely has to pause there, because Blizzard
  blocks addons from reading incoming chat and nobody's client can decode encoded
  speech. An accent is ordinary English that needs no decoding and works fine in
  an instance, so it was being suppressed as collateral damage. The pause is now
  scoped to translation only. The wording follows suit: the entry notice and the
  options heads-up both say translation is paused and accents still work, and the
  checkbox now reads "Pause translation during instances".
- Accents now work while speaking Common. 0.2.20 made Common (and Low Common)
  read as plain speech, but the outgoing pipeline still treated "translation is
  switched on" as translation having claimed the line, so with Common selected it
  translated the message into exactly itself and returned, and the accent never
  ran. A translation that changes nothing now falls through to the accent. This
  also covers the other no-op case: a short line where no word had a mapping yet at
  low fluency. Picking a real tongue still takes precedence over the accent, as
  before, since accents are meant to flavor English.
- `/ogt debug` now reports which branch handles your chat. A new `SAY path=` line
  reads `language`, `accent`, or `none (sent exactly as typed)`, so "it's
  switched on but nothing happens" takes one command to pin down instead of
  guesswork.
## [0.2.21]
- Fixed plain English being rewritten and tagged as a language. Chat from players
  who don't even run ToA could be partially rewritten and stamped with a tag like
  `[Gilnean (Codespeak)]`. The cause: for every incoming line ToA tried a
  speculative word-by-word decode against each language you had learned, and an
  ordinary English word can coincidentally be some generated language's encoding
  of a *different* word, so real sentences got "decoded" into nonsense. Using
  "Learn all" made it far worse, since every extra learned tongue added more
  chances to collide. Decoding now requires proof the line really is encoded:
  either an exact cached mapping (delivered by the sender's addon-sync or your own
  round-trip, whose keys plain English cannot match) or a recognized `[Language]`
  tag. When there is a tag, only that one tongue is tried. Untagged, uncached lines
  are left exactly as sent. `/ogt decode` still tries every language on request.
- The `[Language]` tag is now always on. It is the signal other players' clients
  rely on to know a line is encoded and which tongue it is in, so it is no longer
  a setting that can be switched off. Turning it off silently stopped others from
  decoding you. The "Prefix messages with [Language]" checkbox is gone, and a
  saved setting that had it off is corrected on load. The fluency prefix stays
  optional: keep "Show fluency in tag" ticked for `[Broken Orcish]`, untick it
  for a plain `[Orcish]`. `/ogt tag on|off` now toggles that prefix.
- Decoding performance. Ranking candidate words used a linear scan of the whole
  common-word list, and it was called from inside sort comparators, so ranking a
  single word was quadratic, which is what made busy chat lag once you had
  languages learned. That lookup is now a prebuilt O(1) rank table, the
  per-comparison bonus is resolved once up front instead of on every comparison,
  and decoded words are memoized per language (invalidated only when that
  language's reverse map actually gains a mapping). Decode results are unchanged.
- Options panel alignment. Removing the tag checkbox left the checkboxes below it
  indented a step too far left; they line up again.
## [0.2.20]
- Auto-disable during instances (and re-enable on leaving). Blizzard blocks addons
  from reading chat during boss fights, so ToA can't translate or decode there.
  New option "Automatically disable during instances" (on by default) cleanly
  switches ToA off when you enter an instance and turns it back on when you leave,
  so you never send text others can't decode, and it's obvious this is a game
  restriction, not a bug. You get a short on-screen + chat notice on entry and
  exit. A persistent note at the top of the options panel explains the boss-fight
  limitation. Toggle with the checkbox or `/toa autodisable on|off`.
- Fixed a Retail (Midnight, 12.0) error on incoming chat. On modern retail, chat
  text and sender names from other players can arrive as protected "secret"
  values (notably inside instances) that addons aren't allowed to read. ToA was
  throwing `attempt to compare ... a secret string value` when it tried to decode
  them. ToA now detects secret values (`issecretvalue`) and skips them cleanly:
  such messages are shown exactly as the game delivers them (they can't be
  decoded), and everything else works as before. No effect on older clients.
- Hide languages your race already speaks. New option (on by default, under the
  main panel) that removes the tongues your character natively knows in-game from
  ToA's language lists: the speak dropdown, the Learned Languages tab, and the
  Language Trainer. A Human no longer sees Common, an Orc no longer sees Orcish,
  a Zandalari Troll no longer sees Zandali (or Orcish), and so on for every race.
  Speaking a language your race already knows is handled by WoW itself, so ToA now
  focuses on the tongues you *can't* already speak. Detected from WoW's own
  known-language list by locale-independent language ID, so it works on every
  client language and every race. `/ogt lang` still knows every language, and you
  can turn the option off if you'd rather see the full list.
- Removed the duplicate "Troll" language. Zandali *is* the trolls' racial tongue,
  so the separate "Troll (Zandali)" entry was just a redundant copy of "Zandali
  (Troll)" and has been dropped for everyone. The tribal flavors (Amani,
  Gurubashi and Drakkari) remain, so trolls still get those but no longer see
  Zandali twice (and, with race-hiding on, don't see Zandali at all). Anyone
  previously speaking/learning the old "Troll" entry is moved to Zandali.
- Common now reads as plain speech. Speaking the Common tongue no longer
  substitutes words. Since everyone in Azeroth understands Common, it's sent as
  your normal text instead of looking garbled to other players. (Low Common
  behaves the same.)
- OOC text in (parentheses) is never transformed. Anything inside `( ... )` is
  left exactly as typed for both accents and language translation, so
  out-of-character asides read normally.
- Per-channel accent toggles. The Accents tab now has its own channel grid,
  independent of the main panel's channels, so you can keep your accent on for
  say/yell while turning it off for raid/party (or any other channel). The
  Accents tab is scrollable so everything fits.
- Accent on emotes now covers `/e` *and* inline `*actions*`. The "Also apply
  accent to emotes" option (off by default) governs both `/emote` lines and
  asterisk-wrapped `*actions*` in normal chat: off leaves them as plain speech,
  on gives them the accent too. (The `/e` half of this option now actually works.
  Previously it never fired.)
- Dwarven accent cleanup. Removed the ill-fitting `", ye ken?"` sentence tail
  (following `", lad."` and `", ah tell ye."` in earlier passes). The Dwarven
  accent now only adds the natural, gender-neutral `", aye."` flourish.
- Performance. The per-message database migration check now latches once it's done
  instead of re-validating ~40 settings on every chat line, and the language list
  used for decoding is cached instead of rebuilt for every message received.
- Main options panel now scrolls. The main settings page is wrapped in a scroll
  region with a slim scrollbar (mouse-wheel too), so the layout (right down to the
  live preview) always stays inside the options window instead of spilling past
  the bottom, and the spacing is roomier again. The scrollbar only appears when
  the content is taller than the window.

## [0.2.19]
- Minimap button now uses LibDBIcon. On modern clients the button is driven by the
  standard LibDBIcon library (bundled), so it's placed exactly like every other
  addon's button, reliably *outside* the ring, and can be collected/auto-hidden by
  minimap-button managers (SexyMap, etc.). Genuine 3.3.5a (Ascension) keeps the
  built-in dependency-free button.
- Floating bar: right-click language menu. Right-clicking the floating language bar
  now opens a scrollable menu of *every* language (grouped, with your active one
  highlighted) plus quick Auto-translate and Open-settings entries, instead of
  opening the full window.
- Learn all / Reset all. New buttons at the top of the Learned Languages list to
  instantly master, or wipe, every language at once (each behind a confirmation).
- Quieter chat. Cycling languages (minimap scroll, floating bar, `/toa next|prev`)
  no longer spams a line into chat on every switch.

## [0.2.18]
- Yapper compatibility. Yapper replaces the chat edit box and sends through its
  own pipeline, so our normal intercepts never saw its messages. We now hook into
  Yapper's official public API (`YapperAPI` `PRE_SEND` filter), so text you type
  in Yapper is translated/accented just like the default edit box. Taint-free
  (uses Yapper's supported API; no Blizzard globals touched).
- Minimap button sits outside the ring now. The position is derived from your
  actual minimap size (and shape) instead of a fixed radius, so it no longer lands
  *inside* the minimap on larger/scaled setups.
- New floating language bar. An optional, draggable HUD (in the spirit of the old
  Tongues button) that shows your active language and fluency at a glance:
  left-click cycles your learned languages, scroll cycles too, shift-click toggles
  auto-translate, right-click opens settings. Off by default; enable it (and lock
  its position) under the main options. It's a plain frame; no taint.

## [0.2.17]
- Actually fixed the Retail taint error (confirmed via the client's taint log). The
  real culprit was registering our confirmation/import dialogs in Blizzard's global
  `StaticPopupDialogs` table. On Midnight (12.0+), touching that table taints it,
  and the Game menu / Esc handler reading it then faulted on the player frame's
  protected health value (`attempt to compare a secret number value`). Our dialogs
  now use a self-contained frame that never touches any Blizzard global, so opening
  the Character frame or pressing Esc is clean. (The 0.2.16 `SendChatMessage`
  change is still correct and stays in.)

## [0.2.16]
- Fixed a taint error on Retail (12.0+/Midnight). Opening the Character frame or
  the Game menu could throw `attempt to compare a secret number value (execution
  tainted by 'TonguesOfAzeroth')`. On Midnight, overwriting the global
  `SendChatMessage` leaks taint into Blizzard's secure chat/UI pipeline. We now
  rely solely on the taint-safe `OnEditBoxPreSendText` event for typed chat on
  Retail and never replace the global there (older clients that lack that event are
  unaffected and keep working as before). A full client restart clears any taint
  left over from a previous session.

## [0.2.15]
- Updated for Retail patch 12.1.0 (interface 120100) so it loads without the
  out-of-date warning on the current live client.
- Fluency now decides how you speak. The main slider is now a per-language Fluency
  control: a 40%-fluent speaker only renders ~40% of their words in the tongue
  (sounds broken), while a Perfect speaker speaks it fully. The slider snaps to
  whichever language you have selected, and it's the same value behind your
  `[Broken/Partial/Fluent/Perfect]` chat tag. How well you know a tongue and how
  you sound in it are one and the same now.
- Choose how you learn. Under Learned Languages:
  - Passive learning (on by default): overhearing a tongue (any tagged message)
    slowly builds your fluency in it (roughly 100 words a tier).
  - Language Trainer: the Decipher minigame, as before.
  - Make Fluent / Reset buttons on every language row: instantly become 100%
    fluent (with a confirmation), or wipe a language back to 0%.
- Heads-up: because speaking now scales with fluency, a tongue you haven't learned
  yet comes out mostly in plain speech until you build it up. Your previously-set
  strength is carried over to the language you were speaking.
- `/toa fluency <0-100>` sets your fluency in the current language (replaces the old
  `/toa strength`).

## [0.2.14]
- Accents got a serious accent. Every dialect was rebuilt with far richer, more
  distinctive spelling and slang, so the flavor actually comes through. Dwarven,
  for example: *"Ah'm gaun tae the tavern tonicht; whit dae ye think aboot a braw
  drink wi' the lads?"* Now covering Dwarven, Troll, Orcish, Draenei, Goblin,
  Gilnean, Vrykul and Pirate.
- Strength now sets how garbled the sentence is. Instead of randomly picking which
  words get touched, the slider sets an intensity level: low strength gives just
  the signature markers, and as you raise it more (and heavier) sound-shifts switch
  on across the *whole* line. Fully deterministic, so a message always reads the
  same. Crank it to 100% for a thick, unmistakable accent.
- Retired a few accents that didn't read well (Tauren, Night Elf, Pandaren,
  Forsaken); if you had one selected it falls back to Dwarven automatically.
- Share your custom languages. The Create Language panel now has a Share section:
  Copy code produces a compact, copy/paste share code (great for Discord or
  forums), and paste one in + Import to add it instantly. The code pins the
  language's internal id so an import reproduces it *exactly* for everyone.
- Send it in-game, no copying. Share to target (or `/toa share [player]`) sends a
  custom language straight to another Tongues of Azeroth user over the hidden addon
  channel, to your target, party, or raid. They get an Accept/Decline prompt and
  it's added on accept.
- New slash commands: `/toa import <code>`, `/toa export [name]`, `/toa share [player]`.

## [0.2.13]
- Create your own languages! New "Create Language" panel (also `/toa custom`) lets
  you build a tongue from sound pools (starting sounds, vowels, ending sounds) with
  an apostrophe-frequency slider and a live preview. Saved languages appear
  everywhere: the language dropdown, quick-cycle, the Trainer, fluency tags and
  in-line decode. Because the sync payload carries the original text, other Tongues
  of Azeroth users see your custom speech decoded in-line even without your
  definition.
- Add-on API for power users: `TonguesOfAzeroth_RegisterLanguage{ name=...,
  onsets=..., nuclei=..., codas=..., apostrophe=... }` registers a language from
  your own Lua (e.g. a personal file), no UI needed.

## [0.2.12]
- In-line translation (like retail): decoded speech now rewrites the actual chat
  line in place (e.g. `Crunch says: [Orcish] Lok'tar!`) instead of posting a
  separate emote/whisper line. Tongues you don't understand stay gibberish, and
  words you've unlocked in the trainer show through for a real "learning" feel.
  This is now the default; the old separate-line styles are still available under
  Learned Languages -> Decode display style.
- Fluency in the tag: your `[Language]` prefix now reflects how well you speak it,
  from your Language Trainer progress: Broken (<25%), Partial (<75%), Fluent
  (<100%), or Perfect at full mastery. Toggle with "Show fluency in tag" on the
  main panel.
- Cycle your languages fast: scroll the mouse wheel over the minimap button, hit the
  new "Next" button by the language dropdown, or use `/toa next` and `/toa prev` to
  rotate through the languages you've learned or trained.

## [0.2.11]
- Fix: `/target`, `/cast`, and other protected commands no longer error on Retail.
  The previous edit-box hook tainted the chat send path, which broke protected
  slash commands typed into chat. Removed that hook entirely.
- Language tags on outgoing messages: your speech is now prefixed with the
  language, e.g. `[Orcish] Lok'tar!`, so others can see what tongue you're using.
  Toggle it with the "Prefix messages with [Language]" checkbox or `/toa tag`. The
  tag is cosmetic and is stripped before decoding on the listener's side.
- Retail 12.0 (Midnight) chat rework: typed-chat translation now uses Blizzard's
  dedicated `ChatFrame.OnEditBoxPreSendText` event, which is taint-safe (it fires
  after slash-command parsing, so protected commands are untouched). Note: Blizzard
  blocks chat-text edits during combat lockdown, so messages sent while in combat go
  out untranslated. That is an engine limitation that affects every chat-modifying
  addon on Midnight.

## [0.2.10]
- Accents feel natural: tail interjections are now occasional (about 30% of messages
  at full strength, scaled down with strength) instead of tagged onto every line,
  and short messages get none. Comma-style tails are woven into the sentence
  ("...madness, aye.") rather than tacked on as a new clause. Trimmed the most
  out-of-place lines (e.g. the Goblin sales pitches).
- Route translations to a chat window: new "Show translations in" option (Learned
  Languages panel) sends decoded translations to a chat tab of your choice instead
  of the main window. Also via `/toa output <1-N|default>`.

## [0.2.9]
- Fix: translation & accents on Retail. Messages you *type* are now translated
  reliably on modern Retail. Blizzard's secure chat path doesn't route typed
  messages through an addon's `SendChatMessage` replacement, so the addon now
  translates the text in the chat edit box just before it's sent. Auto-translate,
  accents, and 0%-strength "pure accent" mode all work when typing directly into
  chat, on every supported client.
- Added `/toa debug`, which prints hook status and runs a live translate/accent test
  to help diagnose chat issues.

## [0.2.8]
- Language Trainer difficulty: choose Easy (4), Medium (5), Hard (6), or Very Hard
  (7) letters. The grid resizes to fit, and each difficulty is worth more fluency
  per solve (1% / 2% / 3% / 4%), further multiplied by your streak.
- Reveal button: give up on the current word to see the answer (this resets your
  streak and earns no fluency). The answer is also shown when you run out of tries.
- Streak-driven fluency: solves add fluency scaled by your current streak, so a
  longer streak grows fluency faster. Fluency still persists and never drops.
- Trainer close button: the trainer (and other sub-panels) now always have a close
  (X) alongside Back, fixing a case on modern clients where the trainer window
  could be left open behind the Settings panel.

## [0.2.7]
- Accents: a new dialect system that *flavors your English* instead of translating
  it. Dwarven ("I cannae do this, aye!"), Troll ("da voodoo, mon."), plus Orcish,
  Darnassian, Draenei, Tauren, Forsaken, Pandaren, Goblin, Gilnean, Vrykul, and
  Pirate. Each has its own dropdown and strength slider (0-100). Set Language
  strength to 0% (or turn auto-translate off) to speak with a pure accent.
- Language Trainer ("Decipher"): a Wordle-style minigame for learning languages,
  with a per-language picker, reputation ranks, and fluency progress.
- Fluency & partial decoding: learned languages track a rank and percentage shown
  with live-updating progress bars; solving words in the trainer unlocks partial
  decoding of a language before you've fully learned it.
- 70+ languages & dialects (up from 11): creature/beast tongues (Wolf, Bear,
  Serpent, Bird, Cat, Raptor...), faction tongues (Dark Iron, Gilnean, Goblin,
  Vrykul, Ogre...), elemental/eldritch (Kalimag, Titan, Draconic, Nerubian,
  Ethereal...), and Troll/Elf sub-dialects that share their parent's sound.
- Minimap button for one-click access, plus a standalone draggable window with
  Back/Close navigation for clients without a native options tree (e.g. Ascension).
- Chat output now stays in the default chat frame (no stray panels), and generated
  languages fall back to word-by-word decoding so common words still translate for
  other users.

## [0.2.6]
- Cross-client support: one install now runs on 3.3.5a (Wrath / Ascension), Classic
  (Vanilla / Cata / Mists), and Retail, via a feature-detected compatibility layer
  (`Compat.lua`) and version-suffixed TOCs.
- Portable options UI that works on both the legacy Interface Options panel (3.3.5a)
  and the modern Settings panel, without UIDropDownMenu.
- Add Ko-fi support link; publish to CurseForge.

## [0.2.5]
- Multi-language engine using Blizzard's authentic in-game parser word lists
  (Orcish, Darnassian, Thalassian, Dwarven, Gnomish, Taur-ahe, Zandali, Draenei,
  Gutterspeak, Demonic) plus a length-capped Old God (Shath'yar) generator.
- Corruption slider (0-100) and Interface -> AddOns options panel.
