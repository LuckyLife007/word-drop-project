# Word Drop — Development Progress

**Last Updated**: September 21, 2026
**Current Build**: The timed-word-card redesign is complete. The game plays
from end to end on Android, and every bug in the record is closed.
**Branch**: `redesign/timed-word-cards`
**Repository**: https://github.com/LuckyLife007/word-drop-project

---

## What This Document Is

This document tracks the development progress of the Word Drop Flutter game.
It is written to be human-readable and serves as a handoff document — meaning
that anyone (including a future AI assistant) can read this and understand
exactly where the project stands, what decisions were made, and what comes next.

**Read these 3 documents in this order:**

1. `README.md` — what the game is, in 2 minutes.
2. `REDESIGN.md` — **the current rules of the game screen.** 34 decisions, the
   full specification (S1 to S11), the build plan, and the bug record.
3. `word_drop_documentation_1-7.md` — the original design document. Sections 1,
   2.4, 5 and 6 carry a note where the redesign replaced them.

---

## Project Overview

Word Drop is a mobile word puzzle game. Word cards appear with letters missing,
and each card counts down. The player types the full word before the card's
time ends. There are 5 levels, 100 words, 3 hints and 3 clues per word, and a
lives system that grows with the level.

**The tagline is "Fill the gaps before the time ends."**

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

### Testing on a physical Android phone (wireless, no cable)

Tested on 2026-09-20 with a Redmi 23106RN0DA, Android 13.

1. On the phone: turn on **Developer options**, then **USB debugging**, then
   **Wireless debugging** (Android 11 or newer).
2. On the phone: open Wireless debugging, then **Pair device with pairing code**.
   Note the address, the port and the 6-digit code.
3. On the PC: `adb pair <ip>:<pair-port> <code>`
4. On the phone: read **IP address & Port** on the Wireless debugging screen.
   **This port is different from the pairing port.**
5. On the PC: `adb connect <ip>:<port>`, then `flutter run -d <ip>:<port>`.
6. On MIUI the install can fail with `INSTALL_FAILED_USER_RESTRICTED`. Turn on
   **Install via USB** and **USB debugging (Security settings)** in Developer
   options. The same error appears if you tap Cancel on the install request.

### PC problem: "Unable to establish loopback connection" (solved)

**Symptom:** every Android build fails after 3 to 5 seconds with
`java.io.IOException: Unable to establish loopback connection`. `flutter analyze`
and `flutter test` still work, because they do not use Gradle.

**Cause:** Java 21 builds its internal pipe from an **AF_UNIX socket file**, and
it puts that file in the temp folder. Every Java selector needs that pipe, so
Gradle cannot start. On this PC, AF_UNIX connect fails inside `AppData\Local`:

| Folder for the socket file | Result |
|---------------------------|--------|
| `C:\Temp` | OK |
| `C:\Users\<user>` | OK |
| `C:\Users\<user>\AppData\Local` | FAILED — Invalid argument |
| `C:\Users\<user>\AppData\Local\Temp` (the default) | FAILED — Invalid argument |

Plain TCP loopback works, the `afunix` driver runs, and no third-party
antivirus is installed. The block is specific to `AppData\Local`.

**Fix (set on this PC on 2026-09-20):** a user environment variable that moves
that one socket file out of `AppData\Local`:

```
JAVA_TOOL_OPTIONS = -Djdk.net.unixdomain.tmpdir=C:\Temp
```

The folder `C:\Temp` must exist. Every Java program then prints one line,
`Picked up JAVA_TOOL_OPTIONS: ...`, which is normal and harmless.

**To test the PC quickly:** a 3-line Java program that calls `Selector.open()`
fails in the same way when the problem is present.

### PC problem: Gradle memory

`android/gradle.properties` asked for `-Xmx8G` with a 4 GB metaspace. A PC with
8 GB of RAM cannot give that. The value is now `-Xmx1536m` with a 512 MB
metaspace, which is enough for this project.

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
- Fields: `levelNumber`, `name`, `newCardDelay` (ms), `cardTime` (ms), `lives`
- **The 2 timing fields were renamed in the redesign** (REDESIGN.md S10).
  `spawnDelay` became `newCardDelay`, and `fallTime` became `cardTime`.
  The values did not change.
- Contains the master constant `kAllLevels` — the complete list of all 5 levels
- All values match documentation Section 4.1 exactly:

| Level | Name       | New card every | Time per card | Lives |
|-------|------------|----------------|---------------|-------|
| 1     | Strolling  | 5000ms         | 30000ms       | 3     |
| 2     | Jogging    | 4500ms         | 26000ms       | 4     |
| 3     | Running    | 4000ms         | 22000ms       | 5     |
| 4     | Bolting    | 3500ms         | 18000ms       | 6     |
| 5     | Impossible | 3000ms         | 15000ms       | 7     |

### ✅ Managers (`lib/managers/`)

#### `word_bank.dart`
- Singleton that loads and caches the word bank JSON
- Methods: `loadWords()`, `getRandomWord()`, `getRandomWordByLength()`, `getRandomWords()`, `getWordsByLength()`, `getWordCountByLength()`
- Loads once at startup; stays in memory for the entire app session

#### `game_manager.dart`
- Singleton that serves the words: which level, which position in the level,
  and which hint/clue pair the player has not seen yet
- Anti-repetition on 2 levels: a shuffled queue per word length, so no word
  repeats before the whole deck is dealt, and a record of every hint/clue
  combination used this session
- Word length grows inside every level (words 1–4 are 6 letters, 5–8 are 7
  letters, and so on) per documentation Section 4.2
- Methods: `initialize()`, `resetGame()`, `startLevel()`, `getNextWord()`,
  `recordCorrectWord()`, `printGameState()`
- **The score and the lives are NOT here.** The game screen owns them. This
  class owns the words only (REDESIGN.md BUG-7).

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
- All 4 buttons navigate with a FadeTransition (300ms) through one
  `_openScreen()` helper. The "Coming Soon" snackbar is gone.
- Each button press calls `SettingsManager().lightTap()` for haptic feedback

#### `how_to_play_screen.dart`
- 9 sections that describe the **card** design, taken from REDESIGN.md S1–S9
- A colour key with real colour chips: blue, amber, red, green
- Scrollable, because the rules do not fit a 640px screen

#### `settings_screen.dart`
- Audio group: Sound effects and Background music. **Both disabled**, with a
  note, because `assets/audio/` is empty and there is no audio package. To
  enable: delete `enabled: false` on those 2 rows and remove the note.
- Feedback group: Vibration. Fully working.
- Data group: Reset progress, with a confirmation dialog. Calls
  `ProgressManager().resetAllProgress()`.

#### `about_screen.dart`
- Title, tagline, version pill, what the game is, a facts table, credits
- `kAppVersion` in this file must match `version:` in pubspec.yaml

#### `level_selection_screen.dart`
- Shows all 5 levels as scrollable cards
- Three card states:
  - **Locked**: dark/grey, padlock icon, non-tappable
  - **Available** (unlocked but not completed): bright white, pulsing scale animation, play icon, tappable
  - **Completed**: semi-transparent white, green checkmark, shows best time, tappable
- Back button navigates back to Main Menu
- Loads progress from `ProgressManager` on open; `isLoaded` guard prevents re-reading SharedPreferences over synchronously-updated in-memory values
- Tapping a level navigates to `GameScreen` with a slide-up transition; `.then(() => setState({}))` refreshes card states on return so newly unlocked levels are reflected immediately

#### `game_screen.dart` — the card grid (rebuilt in the redesign)
- 6 fixed positions in a 2 × 3 grid, numbered 0 to 5 in reading order. A card
  keeps its position until it leaves, so cards never move.
- Every card owns 2 animation controllers: a 300ms entrance, and the countdown
  that drives the seconds number, the bar, the amber warning and the red flash.
- A new card every `newCardDelay`. When the grid is full, the next card waits.
  The `+` button shows one at once.
- Typing matches the full word, from 6 characters, in grid order.
- Pause comes from 3 places: the Pause button, the Back gesture (seen as the
  keyboard height falling to 0) and the app going to the background.
- "3, 2, 1, Go" runs at the level start and at every resume.
- The grid scrolls only on a screen too short for 6 cards, and 2 blinking
  arrows then show which way the hidden cards are.
- The full rule set is in REDESIGN.md, sections S2 to S8.

### ✅ App Entry Point (`lib/main.dart`)
- Locks orientation to portrait-only at startup (per documentation Section 1.2).
  The lock is skipped on the web, where a browser cannot lock the screen.
- Preloads word bank before showing any UI
- Shows `SplashScreen` first: logo + tagline fade in, loading spinner → checkmark
- Transitions to Main Menu via FadeTransition (300ms) after ~2.3 seconds total
- Root widget renamed from Flutter default `MyApp` to `WordDropApp`
- Declares the app-wide `routeObserver`, so the Level Selection screen can
  refresh when a game screen above it closes

### ✅ Tests (`test/widget_test.dart`)
- One test: the app starts on the splash screen and reaches the main menu.
- It moves the clock forward in 200ms steps. Small steps matter, because the
  word bank load is real asynchronous work and one big jump would skip past it.
- `flutter test` passes.

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
- **One owner for each piece of state**: the game screen owns the score, the
  lives and the end of a level. `GameManager` owns the words. Two copies of the
  same value caused BUG-7.
- **A scroll view inside a `Stack` needs `Positioned.fill`** (BUG-15).
- **Never rewrite a source file with PowerShell `Get-Content`/`Set-Content`**:
  it damages every non-ASCII character (BUG-13).
- **`dart format`**: `game_screen.dart` is formatted with `dart format`. Run it
  after large edits, so the diff stays small for everyone.

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
                                                    ├── "3, 2, 1, Go", then the cards
                                                    ├── [Pause / Back / app to background]
                                                    │      └── Resume Game (3,2,1,Go) / End Game
                                                    ├── [0 lives] Try Again / Level Select / Main Menu
                                                    └── [100 points] Continue / Replay / Level Select
```

---

## The Redesign: Timed Word Cards (September 2026)

The first build dropped words from the top of the screen. It worked on a
laptop and failed on a phone:

- The keyboard takes about half of the screen height, so the fall area was
  very short.
- The game area changed height when the keyboard opened or closed, so the
  words jumped.
- There was little width, so cards overlapped or were cut off.

**The redesign keeps every rule of the game and changes only how the words are
shown.** Words no longer fall. Each word sits on a card in a fixed grid, and
each card counts down on its own.

`REDESIGN.md` is the full record: 34 numbered decisions, a complete
specification of the new screen (sections S1 to S11), the build plan, and the
bug record. Read it before changing the game screen.

### What the redesign changed

| Part | Before | Now |
|------|--------|-----|
| Words | Fall from the top at a constant speed | Sit on cards in a 2 × 3 grid and never move |
| Time limit | The fall time | A countdown on every card, shown as a number and a bar |
| Failure | The word touches the ground | The countdown reaches zero: red flash, −1 life |
| Screen | SKY and GROUND labels, a red ground line | Header, card grid, input row |
| New words | A spawn timer with overlap checks | An interval, a waiting card when the grid is full, and a `+` button |
| Keyboard | Opened and closed freely | Stays open; closing it pauses the game |
| Pause | The Pause button | The Pause button, the Back gesture, or the app going to the background |
| Level start | Words appear at once | "3, 2, 1, Go", which also runs at every resume |

### How it was built (7 stages, all tested on a Redmi 23106RN0DA)

| Stage | What it added |
|-------|---------------|
| 4.1 | The static grid and the input row. The falling engine was deleted here. |
| 4.2 | One card with a working countdown: number, bar, amber, red, life loss |
| 4.3 | The automatic interval, the waiting card, and the `+` button |
| 4.4 | Typing, matching, the green flash, the score, the end of a level |
| 4.5 | The 2 blinking arrows for cards outside the visible area |
| 4.6 | Pause from all 3 sources, and the "3, 2, 1, Go" countdown |
| 4.7 | Clean-up, the overlay checks, and the small details in S11 |

### Screen heights (measured on the test phone, 360 × 800 logical)

The grid needs 296px for 3 rows of cards. The first build left only 266px, so
the third row was cut off. Making the header and the input row shorter freed
50px:

| Part | Before | Now |
|------|--------|-----|
| Header | 84px | ~55px (smaller text, tight line boxes, less padding) |
| Input row | 78px | 63px (smaller field text and 42px buttons) |
| Free height for the grid | 266px | ~316px |

All 6 cards now fit with the keyboard open. On a shorter phone the grid
scrolls, and the 2 arrows show where the hidden cards are.

### Bugs found and fixed during the redesign

All 15 bugs in the REDESIGN.md record are closed. The ones worth remembering:

- **A Stack hides scrolling.** A plain child of a `Stack` gets loose
  constraints, so a `SingleChildScrollView` grows to its content and stops
  scrolling. It needs `Positioned.fill`.
- **The Back gesture does not change the focus.** Android closes the keyboard
  before the key reaches the app, and Flutter keeps the focus on the field.
  The keyboard HEIGHT is the signal, read in `didChangeMetrics()`.
- **An overlay must not assume a free screen.** The Game Over card overflowed
  by 73px, because the keyboard was still open. The end handlers now close the
  keyboard, and every overlay sits in a scroll view.
- **Never rewrite a source file with PowerShell `Get-Content`/`Set-Content`.**
  It reads UTF-8 as Windows-1252 and damages every accented character. Use the
  editor, or `awk`/`sed` through Bash.
- 2 word-bank hints did not match their words. A script now checks all 300.

---


## What Comes Next

### 🔲 Before a release
- **Decide the final name.** "Word Drop" describes falling words, which the
  game no longer has, and a store search finds many games with that name. The
  check on 2026-09-20 found "Gap Race" free. REDESIGN.md D34 holds the
  decision, and the store-check table sits above the Open Questions.
- **Change `applicationId`** from `com.example.word_drop`. The Play Store
  refuses anything that starts with `com.example`.
- **Add a real signing config.** The release build still uses the debug keys.

### ✅ The 3 menu screens are built
- How to Play, Settings and About all open from the Main Menu.
- `lib/managers/settings_manager.dart` is new: it saves the 3 preferences and
  holds the haptic helpers.
- 6 widget tests cover the 3 screens and the menu wiring.

#### `lib/widgets/particle_burst.dart` ✅
- A shower of 16 dots that flies out from the middle of a card, 700ms long
- GREEN for a correct word, RED for a failed card
- Drawn by a `CustomPainter`, so 16 dots cost about the same as 1 widget
- No asset file, so it adds nothing to the APK
- Each burst uses its own random seed, so no 2 bursts look the same
- Each grid place owns a `ValueNotifier<List<_Burst>>`. A burst therefore
  rebuilds 1 cell, not the whole screen. **Do not go back to `setState`**:
  measured on the device, that rebuilt all 6 cards 2 times for each burst.

### 🔲 Polish (later)
- **Sound effects and background music.** BLOCKED: `assets/audio/` holds only
  a `.gitkeep`, and pubspec.yaml lists no audio package. The work is not code
  first, it is files first. When the files exist: add `audioplayers`, build an
  `AudioManager` that reads `SettingsManager().soundEnabled` and
  `.musicEnabled`, then enable the 2 disabled rows in the Settings screen.
- A short animation when a card takes a free position

### ⚠️ Frame rate: what we saw on 2026-09-21, and what to do next

Test phone: Redmi 23106RN0DA, Android 13, 720x1600, 60Hz screen.
Every number below comes from a **debug** build, which is the slow one.

#### Rule 1: do not use `dumpsys gfxinfo` on this app

It measures the Android view system (HWUI). Flutter draws into a
`SurfaceView` and goes around HWUI, so the numbers describe an almost empty
view tree, not the game. It reported "25.19% janky frames", and a 40-second
run of the real game recorded only 17 frames in it. Both numbers are
meaningless here.

Use one of these instead:

- `flutter run --profile` with DevTools. This is the correct tool.
- A quick check on the device, reading the Flutter surface counter:
  `adb logcat -d | grep BufferQueueProducer | grep word_drop`

#### Rule 2: the phone itself changes the result

Measurements taken the same day, same phone, same build type:

| When | Build | Battery | CPU | Frames per second | Worst frame |
|------|-------|---------|-----|-------------------|-------------|
| Early session | no particles | 44% | cool | **58-60** | 17-19 ms |
| Late session  | particles OFF | 29% | 47.5°C | **39-57**, about 44 median | 48-67 ms |
| Late session  | particles ON  | 29% | 47.5°C | **37-46**, about 40 median | 47-84 ms |

Read the 2 late rows against each other, not against the early row.

- The same code with no particles fell from 58-60 fps to about 44 fps with
  **no code change at all**. That drop belongs to the phone, not to the app.
- `dumpsys thermalservice` reported status 0 (no throttling) and
  `settings get global low_power` returned 0. So this is vendor behaviour
  that Android does not report. Do not trust those 2 checks to tell you the
  phone is healthy.
- The honest cost of the particles is the difference between the 2 late
  rows: about **4 fps, or 10%, in a debug build**.

#### The test to run next, on a rested phone

Do this when the battery is above 80% and the phone has been idle and cool
for at least 30 minutes. Do not run it at the end of a long session.

1. Charge to 80% or more. Check: `adb shell dumpsys battery | grep level`.
2. Check the phone is cool, under about 35°C:
   `adb shell dumpsys thermalservice | grep Temperature`
3. Build the release APK. A debug build is 3 to 10 times slower on the UI
   thread, so it cannot answer the question:
   `flutter build apk --release`
4. Install it: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
5. Play Level 1 for 60 seconds with a full grid of 6 cards, and let some
   cards fail so the red bursts run.
6. Read the frame rate:
   `adb logcat -d | grep BufferQueueProducer | grep word_drop`
7. Repeat steps 3 to 6 with the 2 `_startBurst(...)` calls in
   `game_screen.dart` commented out. That is the only fair way to price the
   particles: measure both builds within a few minutes of each other, at the
   same battery level and the same temperature.
8. Write the result into this table. Then test Level 5, which is the worst
   case: 15-second cards and 7 lives, so more cards fail and more bursts run
   at the same time.

**What to do with the answer.** If the release build holds above 55 fps, the
particles are free and no work is needed. If it does not, the known costs to
attack, in order, are in `lib/screens/game_screen.dart`:

1. `_buildTimedCard()` rebuilds the hint text and the clue text on every
   animation frame. Text layout is the most costly step in a Flutter frame.
   Move the unchanging parts into the `child:` parameter of the
   `AnimatedBuilder`, which Flutter builds once and reuses.
2. There is no `RepaintBoundary` around a card, so a repaint of 1 card can
   force the paint of the whole grid.
3. The card draws a blurred `boxShadow` and clips with `Clip.antiAlias` on
   every frame.

None of these were worth doing on 2026-09-21, because the app held 58-60 fps
on a healthy phone. Do not start this work without a measurement that shows
a real problem.

---

## File Structure (Current State)

```
word_drop/
├── assets/
│   ├── data/
│   │   └── word_bank.json          ✅ 100 words, all 300 hints checked
│   └── audio/
│       └── .gitkeep                 ✅ keeps the folder in Git (BUG-5)
├── lib/
│   ├── main.dart                    ✅ app entry, splash screen, routeObserver
│   ├── models/
│   │   ├── word.dart                ✅ one word from the word bank
│   │   └── level_config.dart        ✅ the 5 levels (cardTime, newCardDelay)
│   ├── managers/
│   │   ├── word_bank.dart           ✅ loads and caches the word bank
│   │   ├── game_manager.dart        ✅ serves the words (no score, no lives)
│   │   └── progress_manager.dart    ✅ saves unlocks and best times
│   └── screens/
│       ├── main_menu_screen.dart    ✅ title and 4 buttons
│       ├── level_selection_screen.dart ✅ the 5 level cards
│       └── game_screen.dart         ✅ the card grid and all the gameplay
├── test/
│   └── widget_test.dart             ✅ splash screen to main menu; passes
├── REDESIGN.md                      ✅ decisions, specification, bug record
├── PROGRESS.md                      ✅ this file
├── word_drop_documentation_1-7.md   ✅ the original design document
└── pubspec.yaml                     ✅ dependencies configured
```

## Health of the Build (2026-09-21)

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues |
| `flutter test` | Passes |
| `flutter build apk --debug` | Builds |
| Played on a Redmi 23106RN0DA, Android 13 | Level 1 finished at 100/100 in 1:44 |

---

*This document should be updated after each significant commit.*
