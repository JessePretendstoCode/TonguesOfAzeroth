# Tongues of Azeroth

A World of Warcraft roleplay addon that transforms your chat into the languages and
dialects of Azeroth, in the style of the classic *Tongues* addon. Speak **70+ languages**
— from the eldritch **Old God (Shath'yar)** tongue and the playable-race languages to
beast, elemental, and faction tongues — or drop the language and speak plain English with
a **spoken accent** (Dwarven, Troll, Pirate, and more). There's even a **Wordle-style
language trainer** to earn fluency and decode what others say.

**Runs on every client** — 3.3.5a (Wrath, incl. Project Ascension), Classic (Vanilla /
Cata / Mists), and Retail — from a single install. A feature-detected compatibility layer
(`Compat.lua`) adapts the UI and chat APIs to whichever client it loads on.

The playable-race languages use **Blizzard's own in-game language parser word lists**
(documented on Wowpedia / Warcraft Wiki) — the same word tables the game uses to mask
speech you can't understand. Each word you type is replaced by a word of the *same
letter-length* from that language's list, so output length matches input length and the
result looks authentically like the real in-game language.

Translation is **deterministic**: the same word in the same language always produces the
same output, so sentences stay internally consistent and any two people running the addon
generate identical text.

---

## Features

- **70+ languages & dialects** — the 11 core playable-race/Old God languages plus dozens
  of generated tongues: beasts & creatures (Wolf, Bear, Serpent, Cat, Bird, Raptor…),
  factions (Dark Iron, Gilnean, Goblin, Ogre, Vrykul, Furbolg…), and elemental/eldritch
  (Kalimag, Titan, Draconic, Nerubian, Nazja, Ethereal…). Troll and Elf sub-dialects share
  their parent tongue's sound, so `Amani`, `Gurubashi`, and `Drakkari` all sound like Troll.
- **Accents** — instead of translating, flavor your *English* with a spoken dialect:
  Dwarven ("I cannae do this, aye!"), Troll ("da voodoo, mon."), Orcish, Darnassian,
  Draenei, Tauren, Forsaken, Pandaren, Goblin, Gilnean, Vrykul, and Pirate. Each has its
  own strength slider so you can go subtle or thick.
- **Language Trainer ("Decipher")** — a Wordle-style minigame for learning languages. Pick
  a language, solve daily-style word puzzles, climb **reputation ranks**, and build
  **fluency %** shown on live progress bars. Solving words unlocks partial decoding of that
  language even before you're fully fluent.
- **Strength slider (0–100)** — control *how much* of your text is translated. `0` leaves
  your text untouched (and lets accents through); `100` fully translates it. In between,
  words convert deterministically, one by one, as you raise the level.
- **Channel filters** — choose which chat types are translated/accented when you speak and
  scanned when you listen (Say, Yell, Whisper, Party, Raid, etc.).
- **Learned Languages** — mark dialects you understand; when another Tongues of Azeroth
  user speaks one, you see a second line showing the original meaning (emote or whisper
  style). Fluency earned in the trainer is shown per language.
- **Minimap button** for one-click access, plus a standalone draggable window (with
  Back/Close navigation) for clients without a native options tree (e.g. Project Ascension).
- **In-game configuration** (Interface → AddOns on 3.3.5a; the Settings panel on modern
  clients), with a live preview.
- **Slash commands** for quick control.
- Punctuation, numbers, spacing, and links are preserved — only words are transformed.
- Pure Lua, **no external libraries**; portable widgets render identically on old and new clients.

---

## Installation

1. Copy the `TonguesOfAzeroth` folder into your client's AddOns folder:
   ```
   World of Warcraft\Interface\AddOns\
   ```
2. The folder must be named `TonguesOfAzeroth` and contain `TonguesOfAzeroth.toc` plus
   `Compat.lua`, `Language.lua`, `Accent.lua`, `Core.lua`, `Whispers.lua`, `Game.lua`, and
   `UI.lua`. (The extra
   `TonguesOfAzeroth_Mainline.toc` / `_Vanilla.toc` / etc. let modern clients pick the
   right interface version; the old 3.3.5a client just reads the base `.toc`.)
3. Launch the game and enable **Tongues of Azeroth** on the character-select AddOns list
   (on 3.3.5a, tick **Load out of date AddOns** if needed).
4. In game, type `/ogt`, or open the options (Interface → AddOns on 3.3.5a; Settings →
   AddOns on modern clients).

---

## Languages

| ID            | Language                    | Flavour                          |
|---------------|-----------------------------|----------------------------------|
| `oldgod`      | Old God (Shath'yar)         | Eldritch, apostrophe-heavy       |
| `orcish`      | Orcish                      | Guttural, hard-edged             |
| `darnassian`  | Darnassian (Night Elf)      | Flowing, soft                    |
| `dwarven`     | Dwarven                     | Hard, stony                      |
| `gnomish`     | Gnomish                     | Clipped, technical               |
| `thalassian`  | Thalassian (Blood/High Elf) | Sharp, regal                     |
| `zandali`     | Zandali (Troll)             | Rhythmic                         |
| `taurahe`     | Taur-ahe (Tauren)           | Earthy, open vowels              |
| `draenei`     | Draenei                     | Airy, long vowels                |
| `gutterspeak` | Gutterspeak (Forsaken)      | Raspy, clipped                   |
| `demonic`     | Demonic (Eredun)            | Harsh, dark                      |

> The playable-race languages use the authentic in-game parser word lists. Note that this
> parser is cosmetic — even in the real game it does not perform true translation, so the
> output is not "real" Darnassian/Orcish/etc., just Blizzard's own same-length word
> substitution. **Old God (Shath'yar)** has no in-game parser list, so it is produced by a
> length-capped syllable generator.

**Plus 60+ generated tongues and dialects.** On top of the core word-list languages above,
Tongues of Azeroth ships dozens of *generated* languages, each with its own phonetic style:

- **Beasts & creatures:** Wolf, Bear, Bat, Boar, Serpent, Cat, Seal, Bird, Ravenspeech,
  Stag, Orca, plus hunter-pet dialects (Raptor, Chimaera, Crocolisk, Core Hound, Spider,
  Scorpid, Wasp, Sporebat, Turtle…).
- **Peoples & factions:** Common, Dark Iron, Gilnean, Goblin, Ogre (Ogri'zhan), Furbolg,
  Tuskarr, Vrykul, Pandaren, Sprite (Faerie), Sylvan, Moonkin, Trentish.
- **Elemental, eldritch & ancient:** Kalimag (Elemental), Titan, Draconic, Nerubian
  (+ Qiraji / Silithid), Nerglish (Murloc), Nazja (Naga), Ethereal, Undead.
- **Sub-dialects** that share a parent's sound: Troll variants (Amani, Gurubashi, Drakkari),
  Sindassi & Shalassian (Thalassian), Eredun (Demonic), Forsaken (Gutterspeak), and more.

All of them appear in the config dropdown and in `/ogt list`.

---

## Commands

| Command                     | Description                                             |
|-----------------------------|---------------------------------------------------------|
| `/ogt`                      | Open the config panel (Interface → AddOns)              |
| `/ogt on` / `/ogt off`      | Enable / disable auto-translate                         |
| `/ogt toggle`               | Toggle auto-translate                                   |
| `/ogt lang <id>`            | Set the language (e.g. `/ogt lang orcish`)              |
| `/ogt list`                 | List all language IDs (marks the active one)            |
| `/ogt learned`              | List languages you understand                           |
| `/ogt strength <0-100>`   | Set the translation strength                            |
| `/ogt accent [on\|off\|<id>\|list]` | Speak in a dialect accent (e.g. `/ogt accent dwarf`) |
| `/ogt accentstrength <0-100>` | Set accent thickness                                  |
| `/ogt game`                 | Open the "Decipher" language trainer minigame           |
| `/ogt minimap`              | Show / hide the minimap button                          |
| `/ogt say <text>`           | Say one translated line (ignores the on/off toggle)     |
| `/ogt yell <text>`          | Yell one translated line                                |
| `/ogt p <text>`             | Preview a translation (only you see it)                 |
| `/ogt help`                 | Show the command list                                   |

Aliases: `/oldgod`, `/tongues`.

---

## Configuration

Open **Interface → AddOns → Tongues of Azeroth** (or type `/ogt`).

**General tab**

- Toggle **auto-translate in chat**.
- Choose the **Language** from the dropdown.
- Set **Strength** with the slider.
- Enable **Channels** for outgoing translate and learned decode.
- **Preview** any text and watch it re-translate live.

**Learned Languages tab**

- Check each dialect you understand.
- Pick **decode display style** (emote or whisper-colored line).
- See your **fluency** (rank + %) per language on live progress bars.
- When someone speaks that language via Tongues of Azeroth, you see their
  translated line in chat plus a second line: `"translated" → "original"`.

**Accents tab**

- Toggle **Speak with an accent**, choose an accent, and set its **strength**.
- Accents rewrite your English into a dialect rather than a language. Auto-translate
  takes precedence, so turn it off (or set Language strength to `0%`) to hear your accent.
- Live preview shows exactly how your speech will read.

**Language Trainer ("Decipher")**

- A Wordle-style word puzzle. Pick the language you're learning, guess the daily-style
  word, and earn **fluency** and **reputation ranks** for that language.
- Fluency unlocks partial decoding of that language even before you're fully fluent.

Settings are stored **per character** (`SavedVariablesPerCharacter`).

When auto-translate is on, only the **channel types you enable** in the config
panel are converted. Defaults match the previous all-on behaviour (Say, Yell,
Party, Raid, Guild, Whisper, Channel, etc.; Emote off).

---

## Extending

**Add a whole new parser language** — register it in `Language.lua` with a `words` table
indexed by letter count (`words[n]` = list of words used for `n`-letter source words):

```lua
register("kalimag", {
    name = "Kalimag (Elemental)",
    words = {
        { "A", "O", "U" },                 -- 1-letter words
        { "Ak", "Ro", "Th" },              -- 2-letter words
        { "Aka", "Gron", "Reth" },         -- 3-letter words
        -- ...add buckets up to length 12+ as desired...
    },
})
```

**Add a generated language** (no fixed word list) — provide a `generator` instead of
`words`:

```lua
register("myeldritch", {
    name = "My Tongue",
    generator = {
        apostrophe = 0.25,          -- chance of stitching syllables with '
        onsets = { "", "k", "th" }, -- keep pieces short to keep words short
        nuclei = { "a", "o", "uu" },
        codas  = { "", "r", "th" },
    },
})
```

Either way it appears automatically in `/ogt list` and the config dropdown. You can also add
an optional `dict = { ["word"] = "override" }` table to force specific word mappings (this
takes priority over the parser/generator).

---

## How it works

- **Parser languages:** each word is replaced with a word of the *same letter-length* from
  the language's authentic word list, chosen by a hash of the word (`hash % bucketSize`). If
  no bucket exists for that length, the next shorter bucket is used (Blizzard caps lookups at
  18 letters). This keeps output length ≈ input length.
- **Old God:** a seeded syllable generator builds a word up to the source word's length, so
  it stays roughly the same size.
- Both are fully deterministic (seeded from the word + language ID): same input → same
  output, always.
- The strength level acts as a deterministic per-word gate, so raising it reveals more
  translated words in a stable order.
- **Learned** decoding builds reverse maps from common vocabulary plus words you and
  others translate at runtime. Rare or unusual words may not decode.
- Nothing communicates with the server or other addons; outgoing text is transformed
  before `SendChatMessage` sends it. Learned decode adds a client-side annotation line
  only you see.

---

## Notes & limitations

- WoW's chat has a **255-character limit**. Translations are longer than the source text, so
  output is trimmed to fit.
- This does **not** hook WoW's real in-game language system (Orcish/Common are server-side);
  it substitutes your text client-side, exactly like the original *Tongues* addon.

---

## Compatibility

One download runs on all current clients via version-suffixed TOCs + `Compat.lua`:

| Client | Interface | TOC |
|--------|-----------|-----|
| 3.3.5a (Wrath / Project Ascension) | `30300` | `TonguesOfAzeroth.toc` (base) |
| Wrath Classic | `30405` | `TonguesOfAzeroth_Wrath.toc` |
| Cataclysm Classic | `40402` | `TonguesOfAzeroth_Cata.toc` |
| Mists of Pandaria Classic | `50504` | `TonguesOfAzeroth_Mists.toc` |
| Classic Era (Vanilla) | `11509` | `TonguesOfAzeroth_Vanilla.toc` |
| Retail (Midnight) | `120007` | `TonguesOfAzeroth_Mainline.toc` |

Modern interface numbers only affect the "out of date" flag and are easy to bump; the base
`30300` TOC is what the old 3.3.5a client loads.

---

## Support

This addon is free and always will be. If it added some flavor to your roleplay and you'd
like to say thanks, you can leave a tip — entirely optional:

- **Ko-fi:** https://ko-fi.com/jessemods
- **GitHub Sponsors:** use the **Sponsor** button at the top of the repo.

Donations support development only; they never unlock features (the addon has no paywalls
and shows no in-game donation prompts, per Blizzard's add-on policy).
