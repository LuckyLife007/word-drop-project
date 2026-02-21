# Word Drop — Development Progress

**Last Updated**: February 21, 2026. 22:50 PM UTC  
**Current Build**: Commit `4c72c06` — Splash, Main Menu, Level Selection  
**Repository**: https://github.com/LuckyLife007/word-drop-project

---

## What This Document Is

This document tracks the development progress of the Word Drop Flutter game.
It is written to be human-readable and serves as a handoff document — meaning
that anyone (including a future AI assistant) can read this and understand
exactly where the project stands, what decisions were made, and what comes next.

The full game design specification lives in `word_drop_documentation_1-7.md`.
This progress document does not replace that — it references it.

---

## Project Overview

Word Drop is a mobile word puzzle game where words fall from the top of the
screen with missing letters. The player must type the complete word before it
hits the ground. There are 5 difficulty levels, 100 words in the database, and
a lives system that varies by level.

**Target platforms**: Android (MVP focus), iOS, Windows (future)  
**Framework**: Flutter / Dart  
**Minimum Android**: API 21 (Android 5.0)

---

## Development Environment

- **IDE**: VS Code
- **Flutter SDK**: Stable channel
- **Dart SDK**: ^3.11.0
- **Version control**: Git + GitHub
- **Testing done on**: Chrome (web), Windows desktop, physical Android device, virtual Android device

---

## What Has Been Built

### ✅ Project Scaffolding
- Flutter project created with Android, iOS, macOS, Windows, and Web platform support
- `pubspec.yaml` configured with assets and dependencies
- Folder structure established: `lib/models/`, `lib/managers/`, `lib/screens/`

### ✅ Word Bank (`assets/data/word_bank.json`)
- 100 words total: 20 words at each of 5 lengths (6, 7, 8, 9, 10 letters)
- Each word has 3 hint patterns (partial letter patterns, e.g. `B-N-N-`) and 3 clues
- JSON key used for hint patterns: `"hints"` (note: was originally `"incomplete_versions"` in the JSON but was manually corrected to match the Dart model)
- Loaded into memory once at app startup, never reloaded during gameplay

### ✅ Data Models (`lib/models/`)

#### `word.dart`
- Represents a single word entry from the word bank
- Fields: `word` (String), `length` (int), `hints` (List), `clues` (List)
- Methods: `fromJson()`, `matchesGuess()`, `getHint(index)`, `getClue(index)`

#### `level_config.dart`
- Represents the settings for one difficulty level
- Fields: `levelNumber`, `name`, `spawnDelay` (ms), `fallTime` (ms), `lives`
- Contains the master constant `kAllLevels` — the complete list of all 5 levels
- All values match documentation Section 4.1 exactly:

| Level | Name       | Spawn Delay | Fall Time | Lives |
|-------|------------|-------------|-----------|-------|
| 1     | Strolling  | 5000ms      | 30000ms   | 3     |
| 2     | Jogging    | 4500ms      | 26000ms   | 4     |
| 3     | Running    | 4000ms      | 22000ms   | 5     |
| 4     | Bolting    | 3500ms      | 18000ms   | 6     |
| 5     | Impossible | 3000ms      | 15000ms   | 7     |

### ✅ Managers (`lib/managers/`)

#### `word_bank.dart`
- Singleton that loads and caches the word bank JSON
- Methods: `loadWords()`, `getRandomWord()`, `getRandomWordByLength()`, `getRandomWords()`, `getWordsByLength()`, `getWordCountByLength()`
- Loads once at startup; stays in memory for the entire app session

#### `game_manager.dart`
- Singleton that tracks game state: current level, score, lives, current word
- Handles word selection with anti-repetition logic (tracks used hint/clue combinations per session)
- Implements word length progression within each level (words 1–4 are 6 letters, 5–8 are 7 letters, etc.) per documentation Section 4.2
- Methods: `initialize()`, `resetGame()`, `getNextWord()`, `checkAnswer()`, `advanceLevel()`
- Contains a `TODO` for victory screen (to be wired up when the game screen is built)

#### `progress_manager.dart`
- Singleton that saves/loads player progress using the `shared_preferences` package
- Saves: highest unlocked level number, best completion time per level (in milliseconds)
- Methods: `loadProgress()`, `isLevelUnlocked()`, `isLevelCompleted()`, `getBestTime()`, `getFormattedBestTime()`, `unlockLevel()`, `saveBestTime()`, `resetAllProgress()`
- `resetAllProgress()` is ready for the Settings screen "Reset Progress" feature
- On first run: Level 1 is unlocked, no best times exist (correct starting state confirmed in testing)

### ✅ Screens (`lib/screens/`)

#### `main_menu_screen.dart`
- Full-screen sky gradient background (`#667eea` → `#764ba2`)
- Entrance animation: title slides in from above, buttons fade in after
- Buttons: PLAY (primary, white pill), How to Play / Settings / About (secondary, outlined)
- PLAY navigates to Level Selection with a FadeTransition (300ms)
- How to Play / Settings / About show "Coming Soon" snackbar (screens not yet built)

#### `level_selection_screen.dart`
- Shows all 5 levels as scrollable cards
- Three card states:
  - **Locked**: dark/grey, padlock icon, non-tappable
  - **Available** (unlocked but not completed): bright white, pulsing scale animation, play icon, tappable
  - **Completed**: semi-transparent white, green checkmark, shows best time, tappable
- Back button navigates back to Main Menu
- Loads progress from `ProgressManager` on open
- Tapping a level currently shows a "Coming Soon" snackbar (game screen not yet built)

### ✅ App Entry Point (`lib/main.dart`)
- Locks orientation to portrait-only at startup (per documentation Section 1.2)
- Preloads word bank before showing any UI
- Shows `SplashScreen` first: logo + tagline fade in, loading spinner → checkmark
- Transitions to Main Menu via FadeTransition (300ms) after ~2.3 seconds total
- Root widget renamed from Flutter default `MyApp` to `WordDropApp`

### ✅ Tests (`test/widget_test.dart`)
- Updated to reference `WordDropApp` (was broken after rename from `MyApp`)

---

## Dependencies

| Package              | Version  | Purpose                                      |
|----------------------|----------|----------------------------------------------|
| `flutter`            | SDK      | Core framework                               |
| `cupertino_icons`    | ^1.0.8   | iOS-style icons                              |
| `shared_preferences` | ^2.3.3   | Saving level progress locally on the device  |
| `flutter_lints`      | ^6.0.0   | Code quality linting (dev only)              |

---

## Known Decisions and Conventions

- **`.withValues(alpha:)` instead of `.withOpacity()`**: Flutter deprecated `.withOpacity()` in favour of `.withValues(alpha:)` to avoid colour precision loss. All colour transparency in this project uses `.withValues()`.
- **Singleton pattern**: `WordBank`, `GameManager`, and `ProgressManager` are all singletons. This means only one instance exists in the entire app, which prevents multiple conflicting game states.
- **`late` keyword**: Used for `AnimationController` variables that can't be initialised in the constructor but are guaranteed to be set in `initState()` before they're ever used.
- **`mounted` check**: Always checked before calling `setState()` after an async gap (e.g. after `await` or `Future.delayed`). This prevents errors if the widget was removed from the screen while waiting.
- **`TickerProviderStateMixin` vs `SingleTickerProviderStateMixin`**: Single is used when a screen has one AnimationController. The multi version is used when a screen needs two or more (e.g. Level Selection uses one for entrance animation and one for the pulse loop).
- **Comment style**: All code has detailed comments explaining what each line does and *why* it was written that way. This is intentional for learning purposes and must be maintained in all future code.

---

## Current App Flow (Working)

```
App Launch
    └── SplashScreen (loads word bank, shows logo, ~2.3s)
            └── FadeTransition (300ms)
                    └── MainMenuScreen
                            └── [PLAY] FadeTransition (300ms)
                                    └── LevelSelectionScreen
                                            └── [Back] returns to MainMenuScreen
                                            └── [Level tap] → "Coming Soon" (game screen pending)
```

---

## What Comes Next

### 🔲 Game Screen (next priority)

This is the most complex screen in the app. It will be built in stages:

**Stage 1 — Static layout**
Get the three zones on screen with correct proportions (no movement yet):
- Header (top 15%): score display, heart icons for lives, level name
- Game area (middle 60%): empty Stack with SKY label at top, GROUND label at bottom
- Input area (bottom 25%): TextField, autofocused, uppercase

**Stage 2 — Single falling word**
- AnimationController with `Curves.linear` animating a word card from top to bottom
- Word card displays the hint pattern (monospace font) and clue (italic, smaller)
- Fall duration driven by `LevelConfig.fallTime`

**Stage 3 — Spawn timer + multiple words**
- `Timer.periodic` spawning new words at `LevelConfig.spawnDelay` intervals
- Random x-position with overlap prevention (20px minimum buffer)
- Maximum 10 simultaneous words on screen (per documentation Section 5.2)

**Stage 4 — Input matching**
- `onChanged` callback checks input against all currently falling words
- Match found: word removed, green flash animation (500ms), input cleared, score +5
- No match: no feedback, player keeps typing

**Stage 5 — Lives and scoring**
- Word reaches ground: red pulse animation (600ms), life deducted, word removed
- Lives display updates (hearts turn from red to white as lost)
- Score updates in header

**Stage 6 — Game Over and Level Complete overlays**
- Lives reach 0: Game Over overlay (score, "Try Again" / "Level Select" / "Main Menu")
- Score reaches 100: Level Complete overlay (time, best time if new record, "Continue" / "Replay" / "Level Select")
- Level Complete triggers `ProgressManager.unlockLevel()` and `saveBestTime()`

**Stage 7 — Pause**
- Pause button in input area
- Overlay: level name, score, time, lives, "Resume" / "End Game"
- All timers and animations pause/resume correctly

### 🔲 After the Game Screen
Once the game screen is complete and tested, remaining screens are:
- How to Play overlay (tutorial, triggered from Main Menu)
- Settings screen (audio toggles, reset progress)
- About screen (credits, version)

### 🔲 Polish (later)
- Sound effects and background music (`audioplayers` package)
- Particle effects for correct guesses and ground hits
- Haptic feedback
- Level intro countdown ("3... 2... 1... Go!")

---

## File Structure (Current State)

```
word_drop/
├── assets/
│   ├── data/
│   │   └── word_bank.json          ✅ 100 words
│   └── audio/                       ⏳ empty, for future sounds
├── lib/
│   ├── main.dart                    ✅ app entry, splash screen
│   ├── models/
│   │   ├── word.dart                ✅ Word data model
│   │   └── level_config.dart        ✅ LevelConfig + kAllLevels
│   ├── managers/
│   │   ├── word_bank.dart           ✅ loads/caches word bank
│   │   ├── game_manager.dart        ✅ game state logic
│   │   └── progress_manager.dart    ✅ saves/loads progress
│   └── screens/
│       ├── main_menu_screen.dart    ✅ main menu UI
│       ├── level_selection_screen.dart ✅ level list UI
│       └── game_screen.dart         🔲 not yet built
├── test/
│   └── widget_test.dart             ✅ updated for WordDropApp
└── pubspec.yaml                     ✅ dependencies configured
```

---

*This document should be updated after each significant commit.*