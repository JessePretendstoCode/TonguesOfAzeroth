# Changelog

All notable changes to Tongues of Azeroth are documented here.

## [Unreleased]

## [0.2.25]
- **New: Favorites.** Seventy-odd tongues ship with the addon and a character
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
- **The floating language bar has a star that toggles "scroll only my
  favorites".** It governs every way you cycle -- the bar, the minimap wheel,
  `/ogt next` and `/ogt prev` -- and is on by default, so with favorites set
  they're what you walk through; switch it off to walk everything you've
  learned instead. The star only lights up when you actually have favorites, so
  it never claims a filter is active when there's nothing to filter. Also on
  `/ogt favonly [on|off]`, since the floating bar is optional and the toggle
  would otherwise be unreachable with it hidden.
- **The star and Next buttons beside the language dropdown are gone.** They
  crowded the row and both jobs are better placed elsewhere: favoriting is on
  the dropdown rows themselves, and cycling was already on the floating bar,
  the minimap scroll wheel and `/ogt next`.
- The star is Blizzard's own favorite art -- the one on Auction House searches
  and profession recipes -- rather than a glyph or a bundled texture. Atlas
  names have moved between expansions and the atlas API doesn't exist on the
  older clients we ship for, so the exact art is probed for at runtime and
  falls back to the cooldown starburst, tinted gold, on anything that has
  neither. Where no hollow star is available the filled one is dimmed and
  desaturated instead, which is indistinguishable at 16px.
- **Favorites take over cycling.** Once you've starred anything, `/ogt next`,
  `/ogt prev`, the Next button and the minimap scroll wheel walk your favorites
  instead of everything you've learned; with none starred, nothing changes.
  Unlike the learned-language fallback, favorites aren't filtered by trainer
  progress -- you picked them deliberately. Tongues your race natively speaks
  are still skipped either way.
- The dropdown widget grew two general-purpose features to support this: inert
  section headers, and a right-click action per row that leaves the menu open
  and holds its scroll position.

- **Accent tails are far less frequent, and no longer arrive in clusters.** They
  fired on roughly 26% of messages with nothing stopping two in a row, which is
  what made them feel constant; it's now about 5%, and never twice in a row. The
  gate changed from a bare per-message coin flip to: a minimum three-message gap
  between tails, a higher word-count floor (5, up from 3), and half the chance on
  mid-length lines, so a flourish lands on a sentence with room for it.
- **Tails now fit the sentence they're joining.** A question no longer absorbs a
  statement interjection -- "where's the inn, aye?" was not English -- so only a
  standalone phrase or an emote may follow one. A tail is also skipped when the
  message already uses its wording, which is what stopped "mon" from turning up
  twice in one breath. That check matches whole words, so "monk" isn't read as
  "mon" nor "player" as "aye".
- **Dwarven has three tails instead of one.** Earlier feedback removed ", lad",
  ", ah tell ye" and ", ye ken", leaving ", aye." by itself -- so *every* Dwarven
  flourish was the same word. It's now joined by ", nae doubt." and ", right
  enough.", both gender-neutral, which also gives the no-repeat rule a choice.
- The options preview and `/ogt debug` no longer disturb tail spacing, so
  previewing a line doesn't consume the flourish your next real message would get.
- **New "Interjections" slider** on the Accents tab (and `/ogt accenttails
  <0-100>`) to tune this yourself, from Off through to roughly twice the default
  rate. The minimum gap between tails is deliberately not on the dial -- spacing
  is what stops them clustering, so even the top of the slider won't bring back
  the old run-of-three effect.
- **Troll no longer turns "friend" into "mon" as well as "man".** Two swaps and
  a tail all produced the same word, which is most of why it felt relentless.
  "friend" now uses Patois' own word, "bredren".

- **New language: Eldre'Thalassian, the tongue of the Skyborne** -- the new race
  in WoW: Forever -- as `/ogt lang skyborne`. Blizzard wrote no parser word list
  for them (the race's listed languages are Darnassian plus Common or Orcish by
  faction), so unlike the other playable-race tongues this one comes from a
  syllable generator, as Old God (Shath'yar) does. It is deliberately not an
  alias of Darnassian: the shen'dorei fled Eldre'Thalas after the War of the
  Ancients and spent ten thousand years sealed in Skywall, the same span over
  which Thalassian split from the same root, so they get their own sound. The
  pools stay recognisably elven -- liquid consonants, the "quel" and "shen"
  roots, apostrophes on longer words -- over airier vowels and the sibilants of
  their wind-spirit patrons.
- Because it is its own language rather than a dialect, trainer fluency in it is
  earned separately and does not come with Darnassian.
- **It leads the language list** rather than sitting seventy entries down the
  dropdown, since it's the one most people are looking for at the moment. Old
  God (Shath'yar) is now second, but is still the default and still what the
  ambient whispers key off. Every list in the addon reads from the same order,
  so `/ogt list`, cycling and the Learned tab all match the dropdown.

- **The addon list now shows a scroll instead of a red question mark.** None of the
  TOC files declared an icon, so the client fell back to its placeholder. All of
  them now set `## IconTexture:` to the parchment scroll `INV_Scroll_03`, a
  built-in icon that exists on every flavor we ship. Note that the field arrived in
  patch 10.1.0, so the Wrath TOC (interface `30405`) still ignores it.
- The minimap button uses that same scroll, so the two match. It reads from one
  `ICON` constant in `UI.lua` now rather than repeating the path per call site.

## [0.2.24]
- **Dropped support for the 2010-era 3.3.5a client** (Project Ascension and
  similar private servers), which has shut down. The base `TonguesOfAzeroth.toc`
  no longer declares interface `30300`; it now mirrors retail and serves purely as
  a fallback for any client that has no matching flavor TOC. If you still need a
  3.3.5a build, 0.2.23 remains available and works.
- **Removed the code paths that existed only for that client.** The legacy
  `InterfaceOptions_AddCategory` registration branch is gone, along with the
  now-unread `Compat.isLegacy` / `Compat.isModern` flags and a `math.randomseed`
  workaround for custom clients that stripped it. Nothing that serves a live
  client was touched: the portable widgets stay (they exist to dodge retail's
  removed `UIDropDownMenu` and template churn), and so does the standalone
  window, which is what the Language Trainer has always opened in.
- The base TOC now loads the bundled libraries like every other flavor, so the
  minimap button goes through LibDBIcon everywhere.
- Documentation no longer claims 3.3.5a support, and the README's stale "no
  external libraries" line is corrected -- LibDBIcon has shipped since 0.2.19.

## [0.2.23]
- **Support for World of Warcraft: Forever.** Forever is its own game type
  (`camelot`) rather than a retail patch, so the addon now ships a
  `TonguesOfAzeroth_Camelot.toc` built for interface `16001`. Without it a Forever
  client fell back to the retail TOC and flagged the addon as far out of date,
  because Forever numbers its builds `1.60.x` even though it runs Midnight's API.
- **Fixed UI taint on Forever.** The check for "does this client use the secure
  chat pipeline?" compared the interface number against `120000`. Forever reports
  `16001`, so it failed that test, took the legacy path and overwrote the global
  `SendChatMessage` -- reintroducing exactly the taint fixed in 0.2.16, where
  opening the Character frame or Game Menu throws "attempt to compare a secret
  number value". The check now detects `issecretvalue` instead, which ships with
  the secure chat pipeline itself, so Forever is handled correctly and 3.3.5a and
  the Classic flavors keep the hook they still need.
- Corrected the author name in the TOC files, which still read a placeholder.

## [0.2.22]
- **Accents now keep working inside instances.** The instance auto-disable added
  in 0.2.20 switched off *everything*, accents included -- so an accent simply did
  nothing in a raid or dungeon. Translation genuinely has to pause there, because
  Blizzard blocks addons from reading incoming chat and nobody's client can decode
  encoded speech; but an accent is ordinary English that needs no decoding and
  works fine in an instance, so it was being suppressed as collateral damage. The
  pause is now scoped to translation only. The wording follows suit: the entry
  notice and the options heads-up both say translation is paused and accents still
  work, and the checkbox now reads "Pause translation during instances".
- **Accents now work while speaking Common.** 0.2.20 made Common (and Low Common)
  read as plain speech, but the outgoing pipeline still treated "translation is
  switched on" as translation having claimed the line -- so with Common selected it
  translated the message into exactly itself and returned, and the accent never
  ran. A translation that changes nothing now falls through to the accent. This
  also covers the other no-op case: a short line where no word had a mapping yet at
  low fluency. Picking a real tongue still takes precedence over the accent, as
  before, since accents are meant to flavor English.
- **`/ogt debug` now reports which branch handles your chat.** A new `SAY path=`
  line reads `language`, `accent`, or `none (sent exactly as typed)`, so "it's
  switched on but nothing happens" takes one command to pin down instead of
  guesswork.
## [0.2.21]
- **Fixed plain English being rewritten and tagged as a language.** Chat from
  players who don't even run ToA could be partially rewritten and stamped with a
  tag like `[Gilnean (Codespeak)]`. The cause: for every incoming line ToA tried a
  speculative word-by-word decode against each language you had learned, and an
  ordinary English word can coincidentally be some generated language's encoding
  of a *different* word -- so real sentences got "decoded" into nonsense. Using
  "Learn all" made it far worse, since every extra learned tongue added more
  chances to collide. Decoding now requires proof the line really is encoded:
  either an exact cached mapping (delivered by the sender's addon-sync or your own
  round-trip, whose keys plain English cannot match) or a recognized `[Language]`
  tag -- and when there is a tag, only that one tongue is tried. Untagged,
  uncached lines are left exactly as sent. `/ogt decode` still tries every
  language on request.
- **The `[Language]` tag is now always on.** It is the signal other players'
  clients rely on to know a line is encoded and which tongue it is in, so it is no
  longer a setting that can be switched off (turning it off silently stopped
  others from decoding you). The "Prefix messages with [Language]" checkbox is
  gone, and a saved setting that had it off is corrected on load. The **fluency
  prefix** stays optional: keep "Show fluency in tag" ticked for
  `[Broken Orcish]`, untick it for a plain `[Orcish]`. `/ogt tag on|off` now
  toggles that prefix.
- **Decoding performance.** Ranking candidate words used a linear scan of the
  whole common-word list, and it was called from inside sort comparators -- so
  ranking a single word was quadratic, which is what made busy chat lag once you
  had languages learned. That lookup is now a prebuilt O(1) rank table, the
  per-comparison bonus is resolved once up front instead of on every comparison,
  and decoded words are memoized per language (invalidated only when that
  language's reverse map actually gains a mapping). Decode results are unchanged.
- **Options panel alignment.** Removing the tag checkbox left the checkboxes below
  it indented a step too far left; they line up again.
## [0.2.20]
- **Auto-disable during instances (and re-enable on leaving).** Blizzard blocks
  addons from reading chat during boss fights, so ToA can't translate or decode
  there. New option **"Automatically disable during instances"** (on by default)
  cleanly switches ToA off when you enter an instance and turns it back on when
  you leave -- so you never send text others can't decode, and it's obvious this
  is a game restriction, not a bug. You get a short on-screen + chat notice on
  entry and exit. A persistent note at the top of the options panel explains the
  boss-fight limitation. Toggle with the checkbox or `/toa autodisable on|off`.
- **Fixed a Retail (Midnight, 12.0) error on incoming chat.** On modern retail,
  chat text and sender names from other players can arrive as protected "secret"
  values (notably inside instances) that addons aren't allowed to read -- ToA was
  throwing `attempt to compare ... a secret string value` when it tried to decode
  them. ToA now detects secret values (`issecretvalue`) and skips them cleanly:
  such messages are shown exactly as the game delivers them (they can't be
  decoded), and everything else works as before. No effect on older clients.
- **Hide languages your race already speaks.** New option (on by default, under
  the main panel) that removes the tongues your character natively knows in-game
  from ToA's language lists -- the speak dropdown, the Learned Languages tab, and
  the Language Trainer. A Human no longer sees Common, an Orc no longer sees
  Orcish, a Zandalari Troll no longer sees Zandali (or Orcish), and so on for
  every race. Speaking a language your race already knows is handled by WoW
  itself, so ToA now focuses on the tongues you *can't* already speak. Detected
  from WoW's own known-language list by locale-independent language ID, so it
  works on every client language and every race. `/ogt lang` still knows every
  language, and you can turn the option off if you'd rather see the full list.
- **Removed the duplicate "Troll" language.** Zandali *is* the trolls' racial
  tongue, so the separate "Troll (Zandali)" entry was just a redundant copy of
  "Zandali (Troll)" and has been dropped for everyone. The tribal flavors --
  Amani, Gurubashi and Drakkari -- remain, so trolls still get those but no
  longer see Zandali twice (and, with race-hiding on, don't see Zandali at all).
  Anyone previously speaking/learning the old "Troll" entry is moved to Zandali.
- **Common now reads as plain speech.** Speaking the Common tongue no longer
  substitutes words -- since everyone in Azeroth understands Common, it's sent
  as your normal text instead of looking garbled to other players. (Low Common
  behaves the same.)
- **OOC text in (parentheses) is never transformed.** Anything inside `( ... )`
  is left exactly as typed for both accents and language translation, so
  out-of-character asides read normally.
- **Per-channel accent toggles.** The Accents tab now has its own channel grid,
  independent of the main panel's channels, so you can keep your accent on for
  say/yell while turning it off for raid/party (or any other channel). The
  Accents tab is scrollable so everything fits.
- **Accent on emotes now covers `/e` *and* inline `*actions*`.** The **"Also
  apply accent to emotes"** option (off by default) governs both `/emote` lines
  and asterisk-wrapped `*actions*` in normal chat: off leaves them as plain
  speech, on gives them the accent too. (The `/e` half of this option now
  actually works -- previously it never fired.)
- **Dwarven accent cleanup.** Removed the ill-fitting `", ye ken?"` sentence tail
  (following `", lad."` and `", ah tell ye."` in earlier passes). The Dwarven
  accent now only adds the natural, gender-neutral `", aye."` flourish.
- **Performance.** The per-message database migration check now latches once it's
  done instead of re-validating ~40 settings on every chat line, and the language
  list used for decoding is cached instead of rebuilt for every message received.
- **Main options panel now scrolls.** The main settings page is wrapped in a
  scroll region with a slim scrollbar (mouse-wheel too), so the layout -- right
  down to the live preview -- always stays inside the options window instead of
  spilling past the bottom, and the spacing is roomier again. The scrollbar only
  appears when the content is taller than the window.

## [0.2.19]
- **Minimap button now uses LibDBIcon.** On modern clients the button is driven by
  the standard LibDBIcon library (bundled), so it's placed exactly like every other
  addon's button -- reliably *outside* the ring -- and can be collected/auto-hidden
  by minimap-button managers (SexyMap, etc.). Genuine 3.3.5a (Ascension) keeps the
  built-in dependency-free button.
- **Floating bar: right-click language menu.** Right-clicking the floating language
  bar now opens a scrollable menu of *every* language (grouped, with your active one
  highlighted) plus quick Auto-translate and Open-settings entries -- instead of
  opening the full window.
- **Learn all / Reset all.** New buttons at the top of the Learned Languages list to
  instantly master, or wipe, every language at once (each behind a confirmation).
- **Quieter chat.** Cycling languages (minimap scroll, floating bar, `/toa next|prev`)
  no longer spams a line into chat on every switch.

## [0.2.18]
- **Yapper compatibility.** Yapper replaces the chat edit box and sends through
  its own pipeline, so our normal intercepts never saw its messages. We now hook
  into Yapper's official public API (`YapperAPI` `PRE_SEND` filter), so text you
  type in Yapper is translated/accented just like the default edit box. Taint-free
  (uses Yapper's supported API -- no Blizzard globals touched).
- **Minimap button sits outside the ring now.** The position is derived from your
  actual minimap size (and shape) instead of a fixed radius, so it no longer lands
  *inside* the minimap on larger/scaled setups.
- **New floating language bar.** An optional, draggable HUD (in the spirit of the
  old Tongues button) that shows your active language and fluency at a glance:
  left-click cycles your learned languages, scroll cycles too, shift-click toggles
  auto-translate, right-click opens settings. Off by default; enable it (and lock
  its position) under the main options. It's a plain frame -- no taint.

## [0.2.17]
- **Actually fixed the Retail taint error** (confirmed via the client's taint
  log). The real culprit was registering our confirmation/import dialogs in
  Blizzard's global `StaticPopupDialogs` table -- on Midnight (12.0+), touching
  that table taints it, and the Game menu / Esc handler reading it then faulted
  on the player frame's protected health value (`attempt to compare a secret
  number value`). Our dialogs now use a self-contained frame that never touches
  any Blizzard global, so opening the Character frame or pressing Esc is clean.
  (The 0.2.16 `SendChatMessage` change is still correct and stays in.)

## [0.2.16]
- **Fixed a taint error on Retail (12.0+/Midnight).** Opening the Character frame
  or the Game menu could throw `attempt to compare a secret number value
  (execution tainted by 'TonguesOfAzeroth')`. On Midnight, overwriting the global
  `SendChatMessage` leaks taint into Blizzard's secure chat/UI pipeline. We now
  rely solely on the taint-safe `OnEditBoxPreSendText` event for typed chat on
  Retail and never replace the global there (older clients that lack that event
  are unaffected and keep working as before). A full client restart clears any
  taint left over from a previous session.

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
