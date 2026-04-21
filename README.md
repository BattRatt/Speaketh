# Speaketh
**v1.0** — Roleplay Language Addon for World of Warcraft
*By BattRatt*

---

This addon is inspired by Tongues, which I've noticed has been broken for some time. I initially wanted to create something similar, but thought there could be so much more. And so, Speaketh was created. This addon contains several lore-accurate languages and dialects based off of Blizzard's language tables used in game.

---

## Features

### Languages & Translation
- **20+ built-in languages** — Common, Orcish, Thalassian, Darnassian, Taurahe, Dwarvish, Gnomish, Forsaken, Zandali, Draenei, Goblin, Shath'Yar, Draconic, Demonic, Nerubian, Nazja, Shalassian, Vrykul, Vulpera, Gilnean, and Pandaren
- **Custom languages** — create your own language from a pool of words you define
- **Custom language sharing** — generate a compact import code for any custom language and share it with other players; they paste the code in and the language is added to their addon instantly

### Dialects
- **Built-in dialects** — Gilnean, Troll, and more, applied on top of any active language
- **Drunk dialect** — four levels of drunkenness (Sober, Tipsy, Drunk, Smashed) that slur and distort your speech
- **Custom dialects** — build your own accent using word-swap rules

### Fluency
- **Per-language fluency (0–100%)** — the higher your fluency, the more of your speech comes through clearly to other Speaketh users
- **Passive learning** — optionally gain fluency over time just by hearing a language spoken
- **Other players decode at their own fluency level** — two listeners can hear the same message very differently depending on how well each of them knows the language

### Multiplayer
- **Works across party, raid, guild, and whisper** — other Speaketh users decode your speech at their own fluency level, while players without the addon see only the scrambled text
- **Works in /say and /yell** — even players not in your group can understand you if they have the addon and know the language
- **Players without the addon are never affected** — they simply see the translated text as written, just like normal language scrambling in WoW

### Other
- **Passthrough words** — define words that are never translated regardless of language, useful for character names and in-game terms
- **Minimap button** — access your language and settings at a glance
- **Floating language HUD** — a small draggable label showing your active language

---

## Installation

1. Download and unzip `Speaketh.zip`
2. Place the `Speaketh` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/Speaketh
   ```
3. Launch WoW or type `/reload`
4. Enable **Speaketh** in the AddOns list on the character select screen

---

## Slash Commands

| Command | Description |
|---|---|
| `/sp` or `/speaketh` | Open the help screen |
| `/sp options` | Open the settings panel |
| `/sp window` | Open the Speak Window |
| `/sp <language>` | Switch to a language (e.g. `/sp orcish`) |
| `/sp none` | Disable translation |
| `/sp cycle` | Cycle to your next known language |
| `/sp dialect <name>` | Set a dialect (e.g. `/sp dialect troll`) |
| `/sp drunk <0-3>` | Set drunkenness level |
| `/sp share <language>` | Generate an import code for a custom language |
| `/sp import <code>` | Import a custom language from a code |
| `/sp list` | List all languages and your fluency in each |

---

## Attributions

Speaketh's language word tables are derived from data compiled in the community addons **Tongues** and **ShathYar**. See `LICENSE.txt` for full details.

World of Warcraft® is a registered trademark of Blizzard Entertainment, Inc. Speaketh is an unofficial fan addon and is not affiliated with or endorsed by Blizzard Entertainment.

---

## License

MIT License — see `LICENSE.txt` for full terms.
