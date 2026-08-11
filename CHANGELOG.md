# Changelog

All notable changes to Tongues of Azeroth are documented here.

## [0.2.15]
- **Updated for Retail patch 12.1.0** (interface 120100) so it loads without the
  out-of-date warning on the current live client.
- **Fluency now decides how you speak.** The main slider is now a per-language
  **Fluency** control: a 40%-fluent speaker only renders ~40% of their words in
  the tongue (sounds broken), while a Perfect speaker speaks it fully. The slider
  snaps to whichever language you have selected, and it's the same value behind
  your `[Broken/Partial/Fluent/Perfect]` chat tag -- how well you know a tongue
  and how you sound in it are finally one and the same.
- **Choose how you learn.** Under **Learned Languages**:
  - **Passive learning** (on by default): overhearing a tongue -- any tagged
    message -- slowly builds your fluency in it (roughly 100 words a tier).
  - **Language Trainer**: the Decipher minigame, as before.
  - **Make Fluent / Reset** buttons on every language row: instantly become 100%
    fluent (with a confirmation), or wipe a language back to 0%.
- Heads-up: because speaking now scales with fluency, a tongue you haven't
  learned yet comes out mostly in plain speech until you build it up. Your
  previously-set strength is carried over to the language you were speaking.
- `/toa fluency <0-100>` sets your fluency in the current language (replaces the
  old `/toa strength`).

## [0.2.14]
- **Accents got a serious accent.** Every dialect was rebuilt with far richer,
  more distinctive spelling and slang, so the flavor actually comes through --
  e.g. Dwarven *"Ah'm gaun tae the tavern tonicht -- whit dae ye think aboot a
  braw drink wi' the lads?"* Now covering **Dwarven, Troll, Orcish, Draenei,
  Goblin, Gilnean, Vrykul** and **Pirate**.
- **Strength now = how garbled the sentence is.** Instead of randomly picking
  which words get touched, the slider sets an intensity level: low strength gives
  just the signature markers, and as you raise it more (and heavier) sound-shifts
  switch on across the *whole* line -- fully deterministic, so a message always
  reads the same. Crank it to 100% for a thick, unmistakable accent.
- Retired a few accents that didn't read well (Tauren, Night Elf, Pandaren,
  Forsaken); if you had one selected it falls back to Dwarven automatically.
- **Share your custom languages.** The Create Language panel now has a Share
  section: **Copy code** produces a compact, copy/paste share code (great for
  Discord or forums), and paste one in + **Import** to add it instantly. The code
  pins the language's internal id so an import reproduces it *exactly* for
  everyone.
- **Send it in-game, no copying.** **Share to target** (or `/toa share [player]`)
  sends a custom language straight to another Tongues of Azeroth user over the
  hidden addon channel -- to your target, party, or raid. They get an
  Accept/Decline prompt and it's added on accept.
- New slash commands: `/toa import <code>`, `/toa export [name]`, `/toa share [player]`.

## [0.2.13]
- **Create your own languages!** New "Create Language" panel (also `/toa custom`)
  lets you build a tongue from sound pools -- starting sounds, vowels, ending
  sounds -- with an apostrophe-frequency slider and a live preview. Saved
  languages appear everywhere: the language dropdown, quick-cycle, the Trainer,
  fluency tags and in-line decode. Because the sync payload carries the original
  text, other Tongues of Azeroth users see your custom speech decoded in-line
  even without your definition.
- **Add-on API for power users:** `TonguesOfAzeroth_RegisterLanguage{ name=...,
  onsets=..., nuclei=..., codas=..., apostrophe=... }` registers a language from
  your own Lua (e.g. a personal file), no UI needed.

## [0.2.12]
- **In-line translation (like retail):** decoded speech now rewrites the actual
  chat line in place -- e.g. `Crunch says: [Orcish] Lok'tar!` -- instead of
  posting a separate emote/whisper line. Tongues you don't understand stay
  gibberish, and words you've unlocked in the trainer show through for a real
  "learning" feel. This is now the default; the old separate-line styles are
  still available under Learned Languages -> Decode display style.
- **Fluency in the tag:** your `[Language]` prefix now reflects how well you speak
  it, from your Language Trainer progress: **Broken** (<25%), **Partial**
  (<75%), **Fluent** (<100%), or **Perfect** at full mastery. Toggle with "Show
  fluency in tag" on the main panel.
- **Cycle your languages fast:** scroll the mouse wheel over the minimap button,
  hit the new "Next" button by the language dropdown, or use `/toa next` and
  `/toa prev` to rotate through the languages you've learned or trained.

## [0.2.11]
- **Fix: `/target`, `/cast`, and other protected commands no longer error on
  Retail.** The previous edit-box hook tainted the chat send path, which broke
  protected slash commands typed into chat. Removed that hook entirely.
- **Language tags on outgoing messages:** your speech is now prefixed with the
  language, e.g. `[Orcish] Lok'tar!`, so others can see what tongue you're using.
  Toggle it with the "Prefix messages with [Language]" checkbox or `/toa tag`.
  The tag is cosmetic and is stripped before decoding on the listener's side.
- **Retail 12.0 (Midnight) chat rework:** typed-chat translation now uses
  Blizzard's dedicated `ChatFrame.OnEditBoxPreSendText` event, which is
  taint-safe (it fires after slash-command parsing, so protected commands are
  untouched). Note: Blizzard blocks chat-text edits during combat lockdown, so
  messages sent while in combat go out untranslated — an engine limitation that
  affects every chat-modifying addon on Midnight.

## [0.2.10]
- **Accents feel natural:** tail interjections are now occasional (about 30% of
  messages at full strength, scaled down with strength) instead of tagged onto
  every line, and short messages get none. Comma-style tails are woven into the
  sentence ("...madness, aye.") rather than tacked on as a new clause. Trimmed the
  most out-of-place lines (e.g. the Goblin sales pitches).
- **Route translations to a chat window:** new "Show translations in" option
  (Learned Languages panel) sends decoded translations to a chat tab of your
  choice instead of the main window. Also via `/toa output <1-N|default>`.

## [0.2.9]
- **Fix: translation & accents on Retail.** Messages you *type* are now translated
  reliably on modern Retail. Blizzard's secure chat path doesn't route typed
  messages through an addon's `SendChatMessage` replacement, so the addon now
  translates the text in the chat edit box just before it's sent. Auto-translate,
  accents, and 0%-strength "pure accent" mode all work when typing directly into
  chat, on every supported client.
- Added `/toa debug` — prints hook status and runs a live translate/accent test to
  help diagnose chat issues.

## [0.2.8]
- **Language Trainer difficulty:** choose Easy (4), Medium (5), Hard (6), or Very
  Hard (7) letters. The grid resizes to fit, and each difficulty is worth more
  fluency per solve (1% / 2% / 3% / 4%), further multiplied by your streak.
- **Reveal button:** give up on the current word to see the answer (this resets
  your streak and earns no fluency). The answer is also shown when you run out of
  tries.
- **Streak-driven fluency:** solves add fluency scaled by your current streak, so a
  longer streak grows fluency faster. Fluency still persists and never drops.
- **Trainer close button:** the trainer (and other sub-panels) now always have a
  close (X) alongside Back, fixing a case on modern clients where the trainer
  window could be left open behind the Settings panel.

## [0.2.7]
- **Accents:** a new dialect system that *flavors your English* instead of
  translating it — Dwarven ("I cannae do this, aye!"), Troll ("da voodoo, mon."),
  plus Orcish, Darnassian, Draenei, Tauren, Forsaken, Pandaren, Goblin, Gilnean,
  Vrykul, and Pirate. Each has its own dropdown and strength slider (0-100). Set
  Language strength to 0% (or turn auto-translate off) to speak with a pure accent.
- **Language Trainer ("Decipher"):** a Wordle-style minigame for learning
  languages, with a per-language picker, reputation ranks, and fluency progress.
- **Fluency & partial decoding:** learned languages track a rank and percentage
  shown with live-updating progress bars; solving words in the trainer unlocks
  partial decoding of a language before you've fully learned it.
- **70+ languages & dialects** (up from 11): creature/beast tongues (Wolf, Bear,
  Serpent, Bird, Cat, Raptor...), faction tongues (Dark Iron, Gilnean, Goblin,
  Vrykul, Ogre...), elemental/eldritch (Kalimag, Titan, Draconic, Nerubian,
  Ethereal...), and Troll/Elf sub-dialects that share their parent's sound.
- **Minimap button** for one-click access, plus a standalone draggable window with
  Back/Close navigation for clients without a native options tree (e.g. Ascension).
- Chat output now stays in the default chat frame (no stray panels), and generated
  languages fall back to word-by-word decoding so common words still translate for
  other users.

## [0.2.6]
- Cross-client support: one install now runs on 3.3.5a (Wrath / Ascension),
  Classic (Vanilla / Cata / Mists), and Retail, via a feature-detected
  compatibility layer (`Compat.lua`) and version-suffixed TOCs.
- Portable options UI that works on both the legacy Interface Options panel
  (3.3.5a) and the modern Settings panel, without UIDropDownMenu.
- Add Ko-fi support link; publish to CurseForge.

## [0.2.5]
- Multi-language engine using Blizzard's authentic in-game parser word lists
  (Orcish, Darnassian, Thalassian, Dwarven, Gnomish, Taur-ahe, Zandali, Draenei,
  Gutterspeak, Demonic) plus a length-capped Old God (Shath'yar) generator.
- Corruption slider (0-100) and Interface -> AddOns options panel.
