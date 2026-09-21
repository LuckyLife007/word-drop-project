# Word Drop — Flutter Mobile Game

**Fill the gaps before the time ends.**

A word puzzle game. Word cards appear on the screen with letters missing, and
each card counts down. Type the full word before the card's time runs out.

## What This Game Does

The player sees a card with a hidden letter pattern and a clue, for example:

```
I-L-N-                                    26
Tropical vacation spot like Hawaii
████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

The player types `ISLAND`. The card flashes green and gives 5 points.
If the countdown reaches zero first, the card flashes red and the player
loses 1 life.

- Up to 6 cards are on the screen at once, in a fixed 2 × 3 grid.
- A new card appears every few seconds. The pace depends on the level.
- 20 correct words (100 points) complete a level.
- 0 lives end the game.

## Game Features

- **5 levels**: Strolling, Jogging, Running, Bolting, Impossible
- **100 words**: 20 words of each length from 6 to 10 letters
- **300 hints and 300 clues**: 3 of each per word, so the same word looks
  different every time
- **Lives**: 3 on Level 1, up to 7 on Level 5
- **Best times**: the game saves the fastest run for each level
- **A "+" button**: the player can call the next card early

## How a Level Works

| Level | Name | Time per card | New card every | Lives |
|-------|------|---------------|----------------|-------|
| 1 | Strolling | 30 s | 5.0 s | 3 |
| 2 | Jogging | 26 s | 4.5 s | 4 |
| 3 | Running | 22 s | 4.0 s | 5 |
| 4 | Bolting | 18 s | 3.5 s | 6 |
| 5 | Impossible | 15 s | 3.0 s | 7 |

The words get longer inside every level: words 1–4 have 6 letters, 5–8 have 7,
9–12 have 8, 13–16 have 9, and 17–20 have 10.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Target platforms**: Android (the MVP), then iOS and Windows
- **Minimum Android**: API 21 (Android 5.0)
- **Minimum iOS**: iOS 12.0
- **Storage**: `shared_preferences` for the unlocked levels and the best times

## Project Status

The game plays from end to end on Android: cards, countdowns, typing, score,
lives, pause and the 3 end overlays.

**Not built yet**: the How to Play, Settings and About screens; sound;
particles; haptics.

## Design History

The game first dropped words from the top of the screen. That does not work on
a phone: the keyboard takes about half of the height, so the fall area was too
short, and the cards jumped every time the keyboard opened or closed.

`REDESIGN.md` records the change to timed word cards. It holds 34 numbered
decisions, the full specification of the new screen, the build plan, and a bug
record.

## File Structure

```
word_drop/
├── assets/
│   ├── data/
│   │   └── word_bank.json          100 words with hints and clues
│   └── audio/                       for future sound effects
├── lib/
│   ├── main.dart                    app entry point and splash screen
│   ├── models/
│   │   ├── word.dart                one word from the word bank
│   │   └── level_config.dart        the 5 levels and their timing
│   ├── managers/
│   │   ├── word_bank.dart           loads and serves the words
│   │   ├── game_manager.dart        picks the next word for a level
│   │   └── progress_manager.dart    saves unlocks and best times
│   └── screens/
│       ├── main_menu_screen.dart    title and 4 buttons
│       ├── level_selection_screen.dart  the 5 level cards
│       └── game_screen.dart         the card grid and the gameplay
├── test/
│   └── widget_test.dart             checks the app reaches the main menu
├── REDESIGN.md                      decisions, specification, bug record
├── PROGRESS.md                      development progress and handover
└── word_drop_documentation_1-7.md   the full design document
```

## Running It

```bash
flutter pub get
flutter run
```

To run on a phone over Wi-Fi, and to read about 2 Windows build problems and
their fixes, see the "Development Environment" section of `PROGRESS.md`.

---

**Built with**: Claude (Anthropic AI) as a pair programming partner
**Learning focus**: Flutter, game mechanics, mobile layout
