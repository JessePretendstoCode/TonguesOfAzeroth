# Changelog

All notable changes to Tongues of Azeroth are documented here.

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
