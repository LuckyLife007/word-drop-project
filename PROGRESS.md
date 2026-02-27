# Word Drop — Development Progress

**Last Updated**: February 27, 2026
**Current Build**: Game Screen Stages 1–7 complete + 3 post-launch bug fixes (double-dispose, Level 5 stale card, missing recordCorrectWord)
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
- Loads progress from `ProgressManager` on open; `isLoaded` guard prevents re-reading SharedPreferences over synchronously-updated in-memory values
- Tapping a level navigates to `GameScreen` with a slide-up transition; `.then(() => setState({}))` refreshes card states on return so newly unlocked levels are reflected immediately

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
                                            └── [Level tap] SlideUp (400ms) → GameScreen
                                                    └── [Game Over] Try Again / Level Select / Main Menu
                                                    └── [Level Complete] Continue / Replay / Level Select
                                                    └── [Pause] Resume Game / End Game
```

---

## What Comes Next

### ✅ Game Screen — All 7 Stages Complete

**Stage 1 — Static layout** ✅
- Header (top): score display, heart icons for lives, level name in gold, timer
- Game area (middle): Stack with SKY label (top), red ground line, GROUND label (bottom)
- Input area (bottom): autofocused TextField (uppercase, no autocorrect) + Pause button
- Level Selection now navigates to GameScreen with a slide-up transition

**Stage 2 — Single falling word** ✅
- `FallingWord` class: bundles hint/clue/answer + its own `AnimationController`
- `_spawnWord()`: asks `GameManager` for a word, creates controller, starts fall after 400ms delay (keyboard settle time)
- `LayoutBuilder` inside game area: measures exact pixel dimensions for positioning
- `AnimatedBuilder` + `Positioned`: moves word card from top to ground line at constant speed (`Curves.linear`)
- `addStatusListener`: detects when animation completes → `_onWordHitGround()` removes word
- `Stopwatch` + `Timer.periodic`: elapsed-time display counts up once first word spawns

**Stage 3 — Spawn timer + multiple words** ✅
- `_startSpawnTimer()`: spawns first word immediately, then `Timer.periodic` fires at `spawnDelayDuration` intervals
- Maximum 10 simultaneous words on screen (per Section 5.2) — timer skips spawn if cap is reached
- `_gameAreaWidth`: set by `LayoutBuilder` via direct field assignment (no setState), used for pixel-accurate overlap checks
- Overlap prevention in `_spawnWord()`: up to 10 retries to find an x position with ≥210px separation from all existing words (190px card + 20px buffer)
- `_wordsCompleted` counter added: tracks correct guesses 0–20, drives word-length progression in Stage 4

**Stage 4 — Input matching** ✅
- `_onInputChanged()`: live check every keystroke; length guard ≥4 chars (Section 6.3), normalises to uppercase
- `_onInputSubmitted()`: also triggers match check (Section 6.3: "Enter key: trigger check via onSubmitted")
- Match found: fall frozen, score +5, `_wordsCompleted++`, `GameManager.recordCorrectWord()`, field cleared + refocused instantly
- Per-word exit animation (Section 5.5 / 6.5): 500ms — scale 1.0→1.05 + green tint in (0–250ms), then opacity 1.0→0.0 fade out (250–500ms); word removed on completion
- `_matchControllers` map: one `AnimationController` per matched word (supports simultaneous exits)
- `// ignore` annotations removed from `_score` and `_wordsCompleted` (both now actively used)

**Stage 5 — Lives and scoring** ✅
- **Overlap fix**: `_spawnWord()` now checks x AND y — only blocks a position if both axes would overlap; skips spawn cycle if no valid position found (screen full)
- `_gameAreaHeight`: captured by LayoutBuilder, used to compute `_maxFallY` getter for y-overlap threshold
- `_onWordHitGround()`: deducts life, triggers per-word 600ms red exit animation (scale 1.0→1.05, red tint in, then opacity→0 fade)
- `_groundHitControllers` map: mirrors `_matchControllers` — one per ground-hit word, disposed + removed on completion
- `_isGameOver` flag: set when `_lives` reaches 0; guards `_spawnWord()` and `_onInputChanged()` from running
- `_handleGameOver()`: cancels spawn + clock timers, freezes all falling words, placeholder snackbar (Stage 6 will add real overlay)
- `_scoreHighlightController`: 150ms forward + 150ms reverse = 300ms gold flash on score text after correct guess (Section 6.5)
- `_buildStatBlock()` updated with optional `highlightController` param — score stat uses it, timer stat doesn't

**Stage 5 (pre-Stage-6 fixes)** ✅
- **Calculated-valid-range overlap prevention**: `_spawnWord()` now computes which x ranges are guaranteed clear instead of blind random retries (O(n), deterministic, uniform distribution); replaces the earlier 10-retry approach
  - Algorithm: start with `[(0.0, usableWidth)]`, subtract each near-top word's blocked zone `[existingX ± minXSeparation]`, pick a random pixel from what remains
  - Skips spawn cycle if no valid ranges remain (screen truly full)
- **Score cap**: `_score` is now clamped to 100 (`(_score + 5).clamp(0, 100)`) — prevents "105/100" display
- **Level complete detection**: `_onInputChanged()` checks `if (_wordsCompleted >= 20)` after each correct guess and calls `_handleLevelComplete()`
- `_isLevelComplete` flag: mirrors `_isGameOver` — guards `_spawnWord()`, `_onInputChanged()`, and `_onWordHitGround()` once the level is won
- `_handleLevelComplete()`: cancels spawn + clock timers, freezes falling words, saves best time via `ProgressManager.saveBestTime()`, unlocks next level via `ProgressManager.unlockLevel()`, placeholder snackbar (Stage 6 will add real overlay)
- `_handleGameOver()` guards against firing if `_isLevelComplete` is already true (edge case: last word hits ground same frame as 20th word is matched — Level Complete wins)

**Stage 6 — Game Over and Level Complete overlays** ✅
- `_overlayController`: single 500ms `AnimationController` driving a `ScaleTransition` (0→1, `Curves.easeOut`) shared by both overlays (only one can ever show at once); initialized in `initState`, disposed in `dispose`
- `_completionTimeMs` + `_isNewBestTime`: captured in `_handleLevelComplete()` BEFORE calling `saveBestTime()` so the "New Record!" badge reflects the correct comparison
- **`build()` Stack refactor**: `SafeArea` child changed from a bare `Column` to a `Stack` with `Positioned.fill(Column(...))` at the bottom and the two conditional overlays on top
- **Game Over overlay** (`_buildGameOverOverlay()`): white card on 65% black backdrop; shows level name, score, encouragement message; buttons: "Try Again" (primary), "Level Select", "Main Menu"; `_getEncouragementMessage()` varies text based on score
- **Level Complete overlay** (`_buildLevelCompleteOverlay()`): white card on 65% black backdrop; shows score (100/100), time, best time or "⭐ New Record!" badge in gold; buttons Levels 1–4: "Continue" (primary), "Replay Level", "Level Select"; Level 5 ("YOU WIN!"): "Replay Level" (primary), "Level Select", "Main Menu"; trophy icon for Level 5, checkmark for others
- Helper widgets: `_buildOverlayStatRow()`, `_buildNewBestBadgeRow()`, `_buildOverlayButton()` (primary = filled purple, secondary = outlined)
- Navigation methods: `_onTryAgain()` / `_onContinue()` use `Navigator.pushReplacement` + fade transition; `_onGoToLevelSelect()` uses `Navigator.pop`; `_onGoToMainMenu()` uses `Navigator.popUntil(isFirst)`
- `_handleGameOver()` / `_handleLevelComplete()` doc comments updated (no longer reference snackbar placeholders)

**Stage 7 — Pause** ✅
- `_isPaused` flag: guards `_spawnWord()`, `_onInputChanged()`, and `_onWordHitGround()` while paused
- `_pauseOverlayController`: dedicated 500ms `AnimationController` (separate from `_overlayController`) — supports multiple pause-resume cycles without resetting the terminal overlay state
- `_onPausePressed()`: sets `_isPaused = true`, cancels spawn timer, stops stopwatch + display timer, freezes all falling word controllers (skipping any mid-match or mid-ground-hit animations), unfocuses keyboard, then `setState` + `_pauseOverlayController.forward()`
- `_onResume()`: `_pauseOverlayController.reset()`, clears `_isPaused`, calls `word.controller.forward()` for all paused words, restarts stopwatch via `_startTimer()`, restarts spawn timer via `_startSpawnTimer(spawnImmediately: false)`, refocuses keyboard, `setState`
- `_onEndGame()`: `Navigator.pop(context)` — exits to Level Select with no progress saved
- `_buildPauseOverlay()`: white card on 65% black backdrop; shows "WORD DROP" label, pause icon, "PAUSED" title; stat rows for Level / Score / Time / Lives; buttons "Resume Game" (primary purple), "End Game" (outlined)
- `_startSpawnTimer({bool spawnImmediately = true})`: new named parameter — `false` on resume so no extra word is injected; `true` (default) preserves original initial-start behaviour
- `build()` Stack: `if (_isPaused) Positioned.fill(child: _buildPauseOverlay())` added after Game Over and Level Complete overlays

---

## Bug Fixes (Post-Stage-7)

### ✅ Fix 1 — Double `AnimationController.dispose()` crash
**Symptom**: `AnimationController.dispose() called more than once` exception in debug log after completing a level.
**Root cause**: A word mid-ground-hit animation (stored in `_groundHitControllers`, still present in `_fallingWords`) could still be matched by player input. `_onInputChanged`'s loop skipped `_matchControllers` words but NOT `_groundHitControllers` words. This created both a `groundCtrl` and a `matchCtrl` for the same word; both completed and each called `_removeWord()`, double-disposing `word.controller`.
**Fix** (`game_screen.dart`): Added `if (_groundHitControllers.containsKey(word.id)) continue;` in `_onInputChanged`'s match loop immediately after the existing `_matchControllers` check.

### ✅ Fix 2 — Level 5 card not refreshing to "completed" on Level Selection return
**Symptom**: After completing Level 5 and pressing "Level Select", all other levels showed correct state but Level 5 still appeared as "available" (not completed/best-time shown).
**Root cause**: `Navigator.push().then()` on Level Selection fires when the pushed route is popped OR when `pushReplacement` replaces it. When the player hits "Continue" from Level 4, `pushReplacement` replaces Level 4's route with Level 5 — this immediately fires Level Selection's `.then()` callback (before Level 5 is played). When Level 5 is later completed and popped, there is no `.then()` watching it. Level Selection never rebuilds, so Level 5 keeps showing the state it had from the premature `.then()` callback.
**Fix**:
- `main.dart` — added top-level `routeObserver = RouteObserver<ModalRoute<void>>()` and registered it in `MaterialApp(navigatorObservers: [routeObserver])`.
- `level_selection_screen.dart` — mixed in `RouteAware`; subscribed in `didChangeDependencies()` and unsubscribed in `dispose()`; overrode `didPopNext()` to call `setState(() {})`. This fires reliably for ALL pops of the route above Level Selection, regardless of how that route arrived.

### ✅ Fix 3 — Missing `GameManager.recordCorrectWord()` (compile error)
**Symptom**: `flutter analyze` reported `The method 'recordCorrectWord' isn't defined for the type 'GameManager'`.
**Root cause**: Stage 4 added a call to `GameManager().recordCorrectWord()` in `_onInputChanged` (to advance the word-length counter so `getNextWord()` returns the correct word length), but the method was never implemented in `game_manager.dart`.
**Fix** (`game_manager.dart`): Added `void recordCorrectWord()` as a thin public method that only increments `_wordCounterWithinLevel`. GameScreen manages its own `_score` and `_wordsCompleted`; this method advances only the counter GameScreen cannot track itself without duplicating GameManager's internal logic.

---

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
│       └── game_screen.dart         ✅ Stages 1–7 — layout, fall, spawn, match, lives, overlays, pause
├── test/
│   └── widget_test.dart             ✅ updated for WordDropApp
└── pubspec.yaml                     ✅ dependencies configured
```

---

*This document should be updated after each significant commit.*