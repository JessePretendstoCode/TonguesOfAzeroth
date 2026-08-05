# Tongues of Azeroth

A World of Warcraft roleplay addon that translates your outgoing chat into the fictional
languages of Azeroth, in the style of the classic *Tongues* addon. Includes the eldritch
**Old God (Shath'yar)** tongue plus the major playable-race languages.

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

- **11 languages**, each with its own phonetic "feel" and a small lore-inspired dictionary.
- **Strength slider (0–100)** — control *how much* of your text is translated. `0` leaves
  your text untouched; `100` fully translates it. In between, words convert
  deterministically, one by one, as you raise the level.
- **Channel filters** — choose which chat types are translated when you speak and
  scanned when you listen (Say, Yell, Whisper, Party, Raid, etc.).
- **Learned Languages** — mark dialects you understand; when another Tongues of
  Azeroth user speaks one, you see a second line showing the original meaning
  (emote or whisper style).
- **In-game configuration** (Interface → AddOns on 3.3.5a; the Settings panel on modern
  clients), with a live preview.
- **Slash commands** for quick control.
- Punctuation, numbers, spacing, and links are preserved — only words are translated.
- Pure Lua, **no external libraries**; portable widgets render identically on old and new clients.

---

## Installation

1. Copy the `TonguesOfAzeroth` folder into your client's AddOns folder:
   ```
   World of Warcraft\Interface\AddOns\
   ```
2. The folder must be named `TonguesOfAzeroth` and contain `TonguesOfAzeroth.toc` plus
   `Compat.lua`, `Language.lua`, `Core.lua`, `Whispers.lua`, and `UI.lua`. (The extra
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

---

## Commands

| Command                     | Description                                             |
|-----------------------------|---------------------------------------------------------|
| `/ogt`                      | Open the config panel (Interface → AddOns)              |
| `/ogt on` / `/ogt off`      | Enable / disable auto-translate                         |
| `/ogt toggle`               | Toggle auto-translate                                   |
| `/ogt lang <id>`            | Set the language (e.g. `/ogt lang orcish`)              |
| `/ogt list`                 | List all language IDs (marks the active one)            |
| `/ogt strength <0-100>`   | Set the translation strength                            |
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
- When someone speaks that language via Tongues of Azeroth, you see their
  translated line in chat plus a second line: `"translated" → "original"`.

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

- **GitHub Sponsors:** use the **Sponsor** button at the top of the repo.

_(A Ko-fi / PayPal tip jar may be added here later.)_

Donations support development only; they never unlock features (the addon has no paywalls
and shows no in-game donation prompts, per Blizzard's add-on policy).
