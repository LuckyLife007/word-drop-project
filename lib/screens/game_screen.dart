// ============================================================================
// GAME SCREEN
// ============================================================================
// This is the main gameplay screen — where words fall from the sky and the
// player types answers to catch them before they hit the ground.
//
// STAGE 7 (THIS FILE): Pause — the player can freeze the game mid-run, review
// current progress (level / score / time / lives), then resume or abandon.
// All word fall animations, spawn timer, and stopwatch freeze on pause and
// are accurately restored on resume.
//
// WHAT IS IN THIS STAGE:
//   - Everything from Stages 1–6
//   - _isPaused flag: stops new spawns and input matching while paused
//   - _pauseOverlayController: 500ms ScaleTransition entrance for pause card
//   - _onPausePressed(): freezes falling words + timers, shows pause overlay
//   - _onResume(): restores all controllers, restarts spawn + clock timers
//   - _onEndGame(): exits to Level Selection without saving progress
//   - _buildPauseOverlay(): pause UI card (level/score/time/lives + buttons)
//   - _startSpawnTimer({spawnImmediately}): new named param skips initial spawn
//     on resume so mid-fall words aren't joined by an immediate new spawn
//
// PER DOCUMENTATION:
//
// Section 5.1 — Word Drop Mechanics:
//   - Use AnimationController with Curves.linear for constant velocity
//   - Word widgets are Positioned inside a Stack
//   - Fall distance: effective height = game area height - groundOffset - cardHeight
//
// Section 5.3 — Fall Speed Calculations:
//   - Fall duration from LevelConfig.cardTime (e.g. 30000ms for Level 1)
//
// Section 5.4 — Collision Detection:
//   - Use Animation.addStatusListener to detect AnimationStatus.completed
//
// Section 5.5 — Animation Durations:
//   - Fall: Curves.linear, duration = cardTime
//   - Spawn fade-in: TODO (will be added as polish)
//
// Section 6.2 — Visual Hierarchy for word cards:
//   - "High-contrast cards: white background, dark text"
//   - "Incomplete word in large monospace font (bold, letter-spaced)"
//   - "Clue in smaller italic gray text below"
//
// STAGE ROADMAP (see PROGRESS.md for full details):
//   Stage 1: Static layout — three zones visible and correctly sized
//   Stage 2: Single falling word using AnimationController + Curves.linear
//   Stage 3: Spawn timer + multiple simultaneous words + overlap prevention
//   Stage 4: Input matching — onChanged checks typed text against words
//   Stage 5: Lives + scoring — ground hit deducts life, overlap fix
//   Stage 6: Game Over and Level Complete overlays
//   Stage 7 (THIS): Pause overlay — freezes all animations and timers
//
// CHANGELOG:
//   - Stage 1: Initial creation — static layout, three zones
//   - Stage 2: Added FallingWord class, AnimationController-driven fall,
//              LayoutBuilder for game area dimensions, stopwatch timer
//   - Stage 3: Added spawn timer, overlap prevention, _wordsCompleted counter,
//              _gameAreaWidth tracking, max-10-words cap
//   - Stage 4: Added input matching (_onInputChanged), green flash animation,
//              active score + wordsCompleted increments, GameManager.recordCorrectWord()
//   - Stage 5: Lives system, ground hit red pulse, game over detection,
//              score gold highlight, 2D overlap fix (_gameAreaHeight added)
//   - Stage 5 (pre-Stage-6 fixes): Calculated-valid-range overlap prevention
//              replaces 10-retry approach; score capped at 100 max; level
//              complete detection added (_isLevelComplete + _handleLevelComplete)
//   - Stage 6: Game Over + Level Complete overlays, ScaleTransition entrance
//   - Stage 7: Pause overlay — _isPaused + _pauseOverlayController,
//              _onPausePressed / _onResume / _onEndGame, _buildPauseOverlay,
//              _startSpawnTimer({spawnImmediately}) named parameter
// ============================================================================

import 'dart:async';  // For Timer (used by the stopwatch display updater)
import 'dart:math';   // For Random (used to randomise word x positions)
import 'package:flutter/material.dart';
import '../managers/game_manager.dart';      // Provides the words to display
import '../managers/progress_manager.dart'; // Saves best time + unlocks next level
import '../models/level_config.dart';

// ============================================================================
// FALLING WORD DATA CLASS
// ============================================================================

/// Represents one word currently falling on screen.
///
/// Each FallingWord bundles together:
///   - The text to display (hint pattern + clue + the answer for matching)
///   - Its own AnimationController that drives its fall from top to bottom
///   - A fixed horizontal position (randomised at spawn time)
///
/// WHY a class and not just parallel lists?
/// In Stage 3+ there will be multiple simultaneous falling words. Each needs
/// its own independent controller. Grouping everything into a FallingWord
/// object keeps the state clean:
///   `List<FallingWord> _fallingWords`
/// instead of managing four separate lists that must stay in sync.
class FallingWord {
  /// Unique identifier for this word instance.
  /// Used to find and remove a specific word from _fallingWords.
  final String id;

  /// The partial letter pattern shown on the card (e.g. "B-N-N-").
  /// Chosen randomly from the word's 3 hint patterns at spawn time.
  final String hint;

  /// The descriptive clue shown below the hint (e.g. "Yellow curved fruit").
  /// Chosen independently from the word's 3 clues at spawn time.
  final String clue;

  /// The complete correct answer (e.g. "BANANA").
  /// Used in Stage 4 to check the player's typed input against this word.
  final String answer;

  /// Horizontal position as a fraction of the game area's usable width (0.0–1.0).
  /// Randomised at spawn time so words don't always fall in the same column.
  /// A value of 0.0 means the leftmost valid position; 1.0 = rightmost.
  /// The actual pixel position is: xFraction * (areaWidth - cardWidth).
  final double xFraction;

  /// Drives the word's vertical fall from value 0.0 (top) to 1.0 (ground line).
  ///
  /// - Duration  = widget.level.cardTimeDuration (e.g. 30s for Level 1)
  /// - Curve     = Curves.linear (constant velocity, per Section 5.1)
  /// - Disposed  in _removeWord() when the word leaves the screen
  final AnimationController controller;

  const FallingWord({
    required this.id,
    required this.hint,
    required this.clue,
    required this.answer,
    required this.xFraction,
    required this.controller,
  });
}

// ============================================================================
// GAME SCREEN WIDGET
// ============================================================================

/// The main gameplay screen where words fall and the player types answers.
///
/// Accepts a [LevelConfig] from the Level Selection screen so it can set
/// fall speed, spawn rate, and starting lives without hard-coding values.
class GameScreen extends StatefulWidget {
  /// Configuration for the chosen level (speed, lives, timing).
  final LevelConfig level;

  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// State class for GameScreen.
///
/// WHY TickerProviderStateMixin (not SingleTickerProviderStateMixin)?
/// Multiple AnimationControllers run simultaneously in this screen — one per
/// falling word, plus future controllers for flash/pulse effects.
/// SingleTickerProviderStateMixin crashes if you try to create a second
/// controller with it. TickerProviderStateMixin supports unlimited controllers.
class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ==========================================================================
  // GAME STATE
  // ==========================================================================

  /// Lives remaining this level.
  /// Starts at widget.level.lives (3 for Level 1, up to 7 for Level 5).
  /// Decremented in _onWordHitGround() each time a word reaches the ground.
  late int _lives;

  /// True once all lives are depleted.
  /// Prevents new spawns and input matching. Stage 6 will use this to show
  /// the Game Over overlay; for now it just freezes the game.
  bool _isGameOver = false;

  /// True once the player reaches 100 points (20 correct words).
  /// Prevents new spawns and input matching after the level is won.
  /// When true, the Level Complete overlay is shown over the game screen.
  bool _isLevelComplete = false;

  /// True while the game is paused.
  ///
  /// Set by _onPausePressed() and cleared by _onResume(). While true:
  ///   - New word spawns are blocked (_spawnWord guard)
  ///   - Input matching is blocked (_onInputChanged guard)
  ///   - All falling word controllers are stopped (frozen in place)
  ///   - Spawn timer and stopwatch are cancelled/stopped
  ///   - The Pause overlay card is shown over the game
  bool _isPaused = false;

  /// Points scored this level (0–100). Each correct word = +5 points.
  /// Incremented by 5 in _onInputChanged() on each correct guess.
  int _score = 0;

  /// How many words the player has correctly guessed this level (0–20).
  ///
  /// This drives word length progression within the level:
  ///   _wordsCompleted 0–3  (words 1–4)  → 6-letter words
  ///   _wordsCompleted 4–7  (words 5–8)  → 7-letter words
  ///   _wordsCompleted 8–11 (words 9–12) → 8-letter words
  ///   _wordsCompleted 12–15             → 9-letter words
  ///   _wordsCompleted 16–19             → 10-letter words
  ///
  /// Incremented in _onInputChanged() each time the player correctly guesses
  /// a word. Also passed to GameManager.recordCorrectWord() so that
  /// getNextWord() returns the right word length for the next spawn.
  int _wordsCompleted = 0;

  /// Elapsed time displayed in the header (e.g. "1:42").
  /// Starts at "0:00" and updates every second once the first word spawns.
  String _timerDisplay = '0:00';

  // ==========================================================================
  // FALLING WORDS
  // ==========================================================================

  /// All words currently on screen, each with their own AnimationController.
  /// Up to 10 simultaneous words (Section 5.2 cap).
  final List<FallingWord> _fallingWords = [];

  /// Per-word match flash controllers, keyed by FallingWord.id.
  ///
  /// When a word is correctly guessed, its fall is paused and an entry is
  /// added here. The controller drives the "correct" card animation:
  ///   0.0–0.5 → scale 1.0 → 1.05, green tint fades IN  (250ms)
  ///   0.5–1.0 → opacity 1.0 → 0.0, word fades OUT       (250ms)
  /// Total: 500ms (per Section 5.5 / Section 6.5).
  ///
  /// On completion the word is removed and the controller is disposed.
  final Map<String, AnimationController> _matchControllers = {};

  /// Per-word ground-hit controllers, keyed by FallingWord.id.
  ///
  /// When a word reaches the ground line without being guessed, an entry is
  /// added here. Drives the 600ms red exit animation (Section 5.5 / 6.5):
  ///   0.0–0.5 → scale 1.0 → 1.05, red tint fades IN   (300ms)
  ///   0.5–1.0 → opacity 1.0 → 0.0, word fades OUT      (300ms)
  ///
  /// On completion the word is removed and the controller is disposed.
  final Map<String, AnimationController> _groundHitControllers = {};

  /// The measured width of the game area in pixels.
  ///
  /// Set by LayoutBuilder during build — not via setState (no rebuild needed).
  /// Used in _spawnWord() for pixel-accurate horizontal overlap checks.
  /// 0.0 until the first build completes (overlap check is skipped if 0).
  double _gameAreaWidth = 0.0;

  /// The measured height of the game area in pixels.
  ///
  /// Set by LayoutBuilder alongside _gameAreaWidth. Used to compute
  /// _maxFallY, which is needed for the Stage 5 y-axis overlap check.
  double _gameAreaHeight = 0.0;

  // ==========================================================================
  // TIMER
  // ==========================================================================

  /// Measures how long the player has been playing since the first word spawned.
  /// Stored so we can stop it on pause/game-over (Stage 7+).
  final Stopwatch _stopwatch = Stopwatch();

  /// Fires once per second to refresh _timerDisplay.
  /// Stored so we can cancel it in dispose() and avoid calling setState()
  /// on a widget that no longer exists.
  Timer? _timerUpdateTimer;

  /// Fires every newCardDelay milliseconds to spawn a new falling word.
  /// Level 1: every 5000ms. Level 5: every 3000ms (per Section 5.2).
  /// Stored so it can be cancelled in dispose() and on pause (Stage 7).
  Timer? _spawnTimer;

  // (Flash animations are per-word — see _matchControllers and
  //  _groundHitControllers above and _buildFallingWordWidget below.)

  /// Drives the brief gold highlight on the score text when a word is matched.
  ///
  /// Cycle: 0.0 → 1.0 (150ms, gold in) then 1.0 → 0.0 (150ms, gold out).
  /// Total visible duration: 300ms (per Section 6.5 "brief gold highlight").
  ///
  /// The score text Color lerps from white to Color(0xFFFFD700) and back.
  late AnimationController _scoreHighlightController;

  /// Drives the Game Over / Level Complete overlay entrance animation.
  ///
  /// ScaleTransition scales the overlay card from 0→1 over 500ms with
  /// Curves.easeOut, making it "pop" into view from the centre of the screen.
  /// (Section 6.4: "Overlay appear: ScaleTransition from center, 500ms, easeOut")
  ///
  /// This single controller is reused for either overlay — only one can ever
  /// be shown at a time since the flags _isGameOver and _isLevelComplete are
  /// mutually exclusive.
  late AnimationController _overlayController;

  /// Drives the Pause overlay entrance animation.
  ///
  /// Identical animation to _overlayController (500ms, Curves.easeOut) but
  /// kept separate so that _overlayController's state is never disturbed by
  /// pause/resume interactions. Reset and re-forwarded each time the player
  /// pauses — supports multiple pause-resume cycles in one session.
  late AnimationController _pauseOverlayController;

  // ==========================================================================
  // LEVEL COMPLETE STATE  (populated in _handleLevelComplete, read by overlay)
  // ==========================================================================

  /// The player's actual completion time in milliseconds (0 until level ends).
  /// Captured the moment the 20th word is matched — used by the overlay to
  /// display the run time and compare against the previous best.
  int _completionTimeMs = 0;

  /// True if this run set a new personal best for this level.
  /// Computed in _handleLevelComplete() BEFORE saveBestTime() is called,
  /// so it reflects the comparison against the OLD record.
  bool _isNewBestTime = false;

  // ==========================================================================
  // INPUT CONTROLLERS
  // ==========================================================================

  /// Controls the text in the answer field.
  /// Used to read the current value and clear it after a correct guess.
  late TextEditingController _textController;

  /// Manages keyboard focus.
  /// Lets us programmatically re-focus the field after a guess is submitted.
  late FocusNode _inputFocusNode;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    // Tell GameManager which level is starting.
    // This resets the word counter, score, lives, and rebuilds the
    // shuffled word queues. Without this call, the singleton carries
    // over stale state from the previous level (Bug 1 + Bug 3 fix).
    GameManager().startLevel(widget.level.levelNumber);

    _lives = widget.level.lives;
    _textController = TextEditingController();
    _inputFocusNode = FocusNode();

    // 150ms per direction × 2 = 300ms total gold-flash cycle (Section 6.5).
    _scoreHighlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // 500ms ScaleTransition for the Game Over / Level Complete overlay card.
    // Section 6.4: "Overlay appear: ScaleTransition from center, 500ms, easeOut".
    // Starts at 0 (invisible) and is only forwarded when the overlay is shown.
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 500ms ScaleTransition for the Pause overlay card.
    // Same animation style as _overlayController. Kept separate so pause/resume
    // cycles don't affect the terminal (game over / level complete) overlay state.
    // reset() is called in _onResume() so it's ready for the next pause cycle.
    _pauseOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Spawn the first word after the first frame has been fully rendered.
    //
    // WHY addPostFrameCallback?
    // We need to wait for:
    //   1. The widget tree to build (so LayoutBuilder has measured the game area)
    //   2. The keyboard to start animating up (autofocus triggers this on frame 0)
    //
    // The 400ms Future.delayed on top gives the keyboard animation (~300ms on
    // most devices) time to complete before we spawn the first word.
    // Without this delay, the game area is still changing size as the keyboard
    // slides up, which can cause the first word to start in the wrong position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        // Start the spawn timer instead of a single spawn.
        // _startSpawnTimer() spawns the first word immediately, then keeps
        // spawning more at the level's newCardDelay interval.
        if (mounted) _startSpawnTimer();
      });
    });
  }

  @override
  void dispose() {
    // Cancel the clock timer first to stop any pending setState() calls.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Dispose every falling word's AnimationController.
    // Each controller holds a reference to this State's ticker provider.
    // If we don't dispose them, Flutter will print errors and leak resources.
    for (final word in _fallingWords) {
      word.controller.dispose();
    }
    _fallingWords.clear();

    // Cancel the word spawn timer so no more words are spawned after disposal.
    // Without this, the timer could fire and try to call setState() or create
    // AnimationControllers after the State has been torn down.
    _spawnTimer?.cancel();

    // Dispose any match-flash controllers that are mid-animation.
    // If the player backs out during a 500ms word flash, we must clean up.
    for (final ctrl in _matchControllers.values) {
      ctrl.dispose();
    }
    _matchControllers.clear();

    // Dispose any ground-hit controllers that are mid-animation.
    for (final ctrl in _groundHitControllers.values) {
      ctrl.dispose();
    }
    _groundHitControllers.clear();

    _scoreHighlightController.dispose();
    _overlayController.dispose();
    _pauseOverlayController.dispose();
    _textController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  // ==========================================================================
  // WORD SPAWNING
  // ==========================================================================

  /// The maximum y pixel value a falling word can reach (ground line position).
  ///
  /// Mirrors the maxY calculation in _buildFallingWordWidget so that
  /// _spawnWord() can do an accurate y-axis overlap check without needing
  /// LayoutBuilder's constraints at spawn time.
  ///
  /// Returns 0 if _gameAreaHeight hasn't been set yet (before first build).
  double get _maxFallY {
    const double approxCardHeight = 70.0;
    const double groundLineOffset = 42.0;
    return (_gameAreaHeight - groundLineOffset - approxCardHeight)
        .clamp(0.0, double.infinity);
  }

  /// Spawns a single falling word.
  ///
  /// Stage 2: called once at startup.
  /// Stage 3+: called repeatedly by a Timer.periodic at newCardDelay intervals.
  void _spawnWord() {
    // Don't spawn new words after game over, level complete, or while paused.
    if (_isGameOver || _isLevelComplete || _isPaused) return;

    // Pass the answers of all currently falling words to GameManager.
    // This prevents the same word appearing on screen twice at once (Bug 2 fix).
    // .map() converts each FallingWord object to just its answer string.
    // .toList() turns the result into a plain List<String>.
    final wordData = GameManager().getNextWord(activeWords: _fallingWords.map((w) => w.answer).toList(),);
    if (wordData == null) return; // Safety: shouldn't happen with 100 words

    // Create this word's AnimationController.
    // vsync: this — ties the controller to this State's ticker (TickerProviderStateMixin).
    // duration: the fall time from the level config (e.g. 30 000ms for Level 1).
    final controller = AnimationController(
      vsync: this,
      duration: widget.level.cardTimeDuration,
    );

    // OVERLAP PREVENTION — CALCULATED VALID RANGE APPROACH
    //
    // PREVIOUS APPROACH (Stage 3 → Stage 5 2D check with 10 random retries):
    //   Even with the x+y check, random retries cannot GUARANTEE finding a
    //   valid position when one clearly exists. On crowded screens, retries
    //   often fail needlessly and spawn cycles are wasted.
    //
    // NEW APPROACH — calculate which x ranges are guaranteed overlap-free:
    //   1. Start with the full valid pixel range: [0, usableWidth]
    //   2. For each existing word that is near the TOP (y < minYClearance):
    //      subtract its blocked zone [existingX - minXSep, existingX + minXSep]
    //      from the current list of valid ranges (range-subtraction algorithm)
    //   3. If any valid ranges remain, pick a uniformly random pixel within
    //      them and convert back to an xFraction
    //   4. If no valid ranges remain, skip this spawn cycle (screen is full)
    //
    // WHY this is better than the retry approach:
    //   - O(n) — one pass over existing words, not up to 10 passes each
    //   - Deterministic — if a valid position exists we ALWAYS find it
    //   - Uniform distribution — every valid pixel is equally likely
    //
    // RANGE SUBTRACTION:
    //   For a range (a, b) blocked by zone (lo, hi):
    //     No overlap (blockHi <= a OR blockLo >= b): keep (a, b) intact
    //     Left fragment:  (a, blockLo) — kept only if blockLo > a
    //     Right fragment: (blockHi, b) — kept only if blockHi < b
    const double approxCardWidth = 190.0;
    const double approxCardHeight = 70.0;
    const double overlapBuffer = 20.0;
    const double minXSeparation = approxCardWidth + overlapBuffer;  // 210px
    const double minYClearance  = approxCardHeight + overlapBuffer; // 90px

    // xFraction is computed below; default 0.5 is overwritten in both branches.
    double xFraction = 0.5;

    if (_gameAreaWidth > 0) {
      final double usableWidth =
          (_gameAreaWidth - approxCardWidth).clamp(1.0, double.infinity);
      final double maxFallY = _maxFallY;

      // Step 1: start with the entire horizontal range as valid.
      List<(double, double)> validRanges = [(0.0, usableWidth)];

      // Step 2: for each word that is still near the top, subtract the zone
      // around it from the valid ranges.
      for (final existing in _fallingWords) {
        final double existingY = (maxFallY > 0)
            ? existing.controller.value * maxFallY
            : 0.0;

        // Words that have already fallen past minYClearance from the top can
        // safely share an x column with the new word — their y gap means they
        // will never visually collide (all words fall at the same speed).
        if (existingY >= minYClearance) continue;

        final double existingX = existing.xFraction * usableWidth;
        final double blockLo = existingX - minXSeparation;
        final double blockHi = existingX + minXSeparation;

        // Subtract (blockLo, blockHi) from every current valid range segment.
        final List<(double, double)> newRanges = [];
        for (final (double a, double b) in validRanges) {
          if (blockHi <= a || blockLo >= b) {
            // Blocked zone does not intersect this range — keep it intact.
            newRanges.add((a, b));
            continue;
          }
          // Left fragment: the portion of (a, b) that sits left of the block.
          if (blockLo > a) newRanges.add((a, blockLo));
          // Right fragment: the portion of (a, b) that sits right of the block.
          if (blockHi < b) newRanges.add((blockHi, b));
        }
        validRanges = newRanges;

        // Early exit: no valid position remains anywhere on screen.
        if (validRanges.isEmpty) break;
      }

      // Step 4: all horizontal space is blocked — skip this spawn cycle.
      // The spawn timer will try again at the next interval.
      if (validRanges.isEmpty) return;

      // Step 3: pick a uniformly random pixel across all remaining valid segments.
      // Compute the total valid length, choose a random offset within it, then
      // walk the segments to find which one the offset falls inside.
      final double totalValid = validRanges.fold(
        0.0,
        (double sum, (double, double) r) => sum + (r.$2 - r.$1),
      );

      double offset = Random().nextDouble() * totalValid;
      double candidateX = 0.0;
      for (final (double a, double b) in validRanges) {
        final double segLen = b - a;
        if (offset <= segLen) {
          candidateX = a + offset;
          break;
        }
        offset -= segLen;
      }

      xFraction = candidateX / usableWidth;

    } else {
      // _gameAreaWidth not yet measured (before first LayoutBuilder build).
      // Accept any position — only happens for the very first spawn.
      xFraction = 0.10 + Random().nextDouble() * 0.65;
    }

    final word = FallingWord(
      // microsecondsSinceEpoch gives a unique ID for each spawned word
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      hint: wordData.hint,     // e.g. "B-N-N-"
      clue: wordData.clue,     // e.g. "Yellow curved fruit"
      answer: wordData.word.word, // e.g. "BANANA"
      xFraction: xFraction,
      controller: controller,
    );

    // Listen for animation completion = word has reached the ground line.
    // AnimationStatus.completed fires when controller.value reaches 1.0.
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // mounted check: this callback can fire after the widget is disposed
        if (mounted) _onWordHitGround(word);
      }
    });

    // Add the word to the list and trigger a rebuild so it appears on screen.
    setState(() => _fallingWords.add(word));

    // Start the fall animation. The word will move from value 0.0 to 1.0
    // over the cardTimeDuration at constant (linear) speed.
    controller.forward();

    // Start the stopwatch the first time a word is spawned.
    // The timer only starts when gameplay actually begins.
    if (!_stopwatch.isRunning) {
      _startTimer();
    }
  }

  /// Called when a word's fall animation completes (it reached the ground).
  ///
  /// Deducts a life, triggers the 600ms red exit animation, then checks
  /// for game over. The word is NOT removed immediately — it stays on screen
  /// for the duration of the red pulse so the player can see what hit.
  void _onWordHitGround(FallingWord word) {
    // Don't count ground hits after game over, level complete, or while paused.
    // (Multiple words may finish their fall simultaneously — only process
    // ones where the game is still actively running.)
    // Note: _isPaused should never trigger this path because _onPausePressed()
    // calls word.controller.stop() on all falling words, preventing completion
    // events from firing. This guard is a defensive safety net.
    if (_isGameOver || _isLevelComplete || _isPaused) {
      _removeWord(word);
      return;
    }

    // Deduct one life and update the hearts display.
    setState(() {
      if (_lives > 0) _lives--;
    });

    // Trigger the 600ms red exit animation, then remove the word.
    // The controller is registered in _groundHitControllers so
    // _buildFallingWordWidget can apply the red tint + scale + fade.
    final groundCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _groundHitControllers[word.id] = groundCtrl;

    groundCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          groundCtrl.dispose();
          _groundHitControllers.remove(word.id);
          _removeWord(word);
        }
      }
    });

    // setState to register the controller before starting, so
    // _buildFallingWordWidget picks it up on the next frame.
    setState(() {});
    groundCtrl.forward();

    // Check for game over AFTER deducting the life.
    if (_lives <= 0) {
      _handleGameOver();
    }
  }

  /// Called when all lives reach zero.
  ///
  /// Called when all lives reach zero.
  ///
  /// Stops all running timers, freezes all falling animations, then triggers
  /// the Game Over overlay (Stage 6) which slides in from the centre of the
  /// screen and offers "Try Again", "Level Select", and "Main Menu" buttons.
  void _handleGameOver() {
    // Don't trigger game over if the level was already completed.
    // Edge case: a word could finish falling at the exact frame that the
    // 20th word is matched. Level Complete takes priority over Game Over.
    if (_isLevelComplete) return;

    _isGameOver = true;

    // Stop the spawn timer — no more new words.
    _spawnTimer?.cancel();
    _spawnTimer = null;

    // Stop the clock.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Freeze all currently falling words in place.
    for (final word in _fallingWords) {
      if (!_groundHitControllers.containsKey(word.id) &&
          !_matchControllers.containsKey(word.id)) {
        word.controller.stop();
      }
    }

    // Rebuild to show the overlay (which is gated on _isGameOver in build()),
    // then animate the card from scale 0→1 over 500ms (Section 6.4).
    if (mounted) {
      setState(() {}); // _isGameOver already true — this makes the overlay appear
      _overlayController.forward();
    }
  }

  /// Called when the player correctly guesses all 20 words (score reaches 100).
  ///
  /// Stops the spawn timer and clock, freezes any still-falling words, then
  /// saves the player's best time and unlocks the next level via ProgressManager.
  ///
  /// Captures the completion time and best-time info, saves progress via
  /// ProgressManager, then triggers the Level Complete overlay (Stage 6)
  /// which shows the time, a "New Record!" badge if applicable, and navigation
  /// buttons: "Continue" (next level), "Replay Level", "Level Select".
  ///
  /// WHY freeze words instead of letting them fall?
  /// Once the level is won there is no gameplay reason to watch remaining words
  /// hit the ground. Freezing them keeps the screen clean and signals clearly
  /// that the level has ended.
  void _handleLevelComplete() {
    _isLevelComplete = true;

    // Stop the spawn timer — no new words should appear after winning.
    _spawnTimer?.cancel();
    _spawnTimer = null;

    // Stop the clock — elapsed time is now the player's final completion time.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Freeze all still-falling words in place.
    // Words already mid-animation (matched green / ground hit red) keep playing.
    for (final word in _fallingWords) {
      if (!_groundHitControllers.containsKey(word.id) &&
          !_matchControllers.containsKey(word.id)) {
        word.controller.stop();
      }
    }

    // Capture best-time info BEFORE saving so we know if this run set a
    // new record. ProgressManager.saveBestTime() updates _bestTimes in memory
    // synchronously, so checking after the call would always look like a tie.
    final int elapsedMs = _stopwatch.elapsed.inMilliseconds;
    final int? previousBest =
        ProgressManager().getBestTime(widget.level.levelNumber);

    _completionTimeMs = elapsedMs;
    _isNewBestTime = previousBest == null || elapsedMs < previousBest;

    // Save best time and unlock the next level.
    //
    // Both calls are fire-and-forget async — we don't need to await them
    // before showing the overlay. ProgressManager.saveBestTime() only writes
    // if this run was faster than the player's existing best. unlockLevel()
    // is a no-op if the next level is already unlocked or this is Level 5.
    //
    // unawaited() (from dart:async) is explicit that the discard is intentional,
    // suppressing the discarded_futures lint warning.
    unawaited(
      ProgressManager().saveBestTime(
        levelNumber: widget.level.levelNumber,
        timeMs: elapsedMs,
      ),
    );
    if (widget.level.levelNumber < 5) {
      unawaited(ProgressManager().unlockLevel(widget.level.levelNumber + 1));
    }

    // Rebuild to show the overlay, then animate the card in (Section 6.4).
    if (mounted) {
      setState(() {}); // _isLevelComplete already true — overlay now in tree
      _overlayController.forward();
    }
  }

  /// Removes a word from the screen and disposes its AnimationController.
  ///
  /// Called from:
  ///   - _onWordHitGround animation completion (red exit done)
  ///   - _matchControllers animation completion (green exit done)
  void _removeWord(FallingWord word) {
    // Dispose the fall controller. (Match/ground controllers are disposed
    // by their own status listener before _removeWord is called.)
    word.controller.dispose();
    setState(() => _fallingWords.remove(word));
  }

  // ==========================================================================
  // SPAWN TIMER (Stage 3)
  // ==========================================================================

  /// Starts the periodic word spawner.
  ///
  /// [spawnImmediately] controls whether one word is spawned right now before
  /// the first timer tick fires:
  ///   - true (default): used on initial game start — the player shouldn't
  ///     stare at an empty screen for a full newCardDelay interval.
  ///   - false: used when resuming from pause — words from before the pause
  ///     are already mid-fall, so we just restart the periodic timer without
  ///     injecting an extra word at resume time.
  ///
  /// Timer.periodic always waits for one full interval before the first
  /// callback fires. On Level 1 that would be a 5 s empty screen — the
  /// [spawnImmediately: true] path solves this without needing a one-shot
  /// timer stacked on top of the periodic one.
  ///
  /// WHY cap at 10 words?
  /// Section 5.2 states "maximum 10 simultaneous falling words". Beyond 10
  /// the screen becomes unreadable and performance degrades. The timer still
  /// fires but skips spawning if the cap is already reached.
  void _startSpawnTimer({bool spawnImmediately = true}) {
    // Optionally spawn one word right now, before the first timer tick.
    if (spawnImmediately) _spawnWord();

    // Then keep spawning at the level's newCardDelay interval.
    _spawnTimer = Timer.periodic(widget.level.newCardDelayDuration, (_) {
      if (!mounted) return; // Widget disposed — stop safely

      // Section 5.2: cap at 10 simultaneous words on screen.
      if (_fallingWords.length < 10) {
        _spawnWord();
      }
    });
  }

  // ==========================================================================
  // TIMER
  // ==========================================================================

  /// Starts the stopwatch and the display-update timer.
  ///
  /// Called once when the first word spawns.
  /// The display refreshes every second: "0:01", "0:02", "1:05", etc.
  void _startTimer() {
    _stopwatch.start();
    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return; // Don't call setState if widget is gone

      final Duration elapsed = _stopwatch.elapsed;
      final int minutes = elapsed.inMinutes;
      final int seconds = elapsed.inSeconds % 60; // remainder after full minutes

      // padLeft(2, '0') ensures single-digit seconds get a leading zero.
      // e.g. 65 seconds → 1:05 not 1:5
      setState(() {
        _timerDisplay = '$minutes:${seconds.toString().padLeft(2, '0')}';
      });
    });
  }

  // ==========================================================================
  // GAME ACTIONS
  // ==========================================================================

  /// Called when the player taps the Pause button.
  ///
  /// Freezes all active falling word animations, stops the spawn timer and
  /// stopwatch, then shows the Pause overlay card with current level stats.
  ///
  /// Per documentation Section 5.6 / 6.6:
  ///   - All timers and animations pause/freeze on tapping pause
  ///   - Overlay shows: level name, score, time spent, lives remaining
  ///   - "Resume Game" restores everything; "End Game" exits without saving
  void _onPausePressed() {
    // Don't allow pausing after the game has already ended or been won.
    if (_isGameOver || _isLevelComplete) return;

    _isPaused = true;

    // Stop the spawn timer so no new words appear while paused.
    _spawnTimer?.cancel();
    _spawnTimer = null;

    // Freeze the stopwatch — elapsed time must be preserved across pause/resume.
    // Dart's Stopwatch.stop() does NOT reset the elapsed value; it just stops
    // accumulating time. Calling start() later resumes from the same point.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Freeze all currently falling words in place at their current y position.
    // Words already mid-match-animation or mid-ground-hit are left alone —
    // they are nearly off screen and stopping them mid-animation looks jarring.
    for (final word in _fallingWords) {
      if (!_matchControllers.containsKey(word.id) &&
          !_groundHitControllers.containsKey(word.id)) {
        word.controller.stop();
      }
    }

    // Dismiss the keyboard — the player can't type while paused.
    _inputFocusNode.unfocus();

    // Show the pause overlay: _isPaused = true puts it in the Stack, then
    // animate the card in from scale 0→1 (same 500ms easeOut as other overlays).
    setState(() {}); // _isPaused is now true → overlay widget enters the tree
    _pauseOverlayController.forward();
  }

  /// Called when the player taps "Resume Game" in the Pause overlay.
  ///
  /// Dismisses the overlay, restores all frozen falling word animations,
  /// and restarts both the spawn timer (without an immediate extra spawn —
  /// existing words are mid-fall) and the stopwatch display timer.
  void _onResume() {
    // Reset the pause controller to 0 so it's ready for the next pause cycle.
    // (If we didn't reset, the next forward() call would be a no-op because
    // the controller would already be at its maximum value of 1.0.)
    _pauseOverlayController.reset();

    _isPaused = false;

    // Resume all word fall animations from where they were stopped.
    // Skip words in matchControllers or groundHitControllers — those were NOT
    // paused (they were nearly finished) and calling forward() on a controller
    // that is still running or already at 1.0 would be incorrect.
    for (final word in _fallingWords) {
      if (!_matchControllers.containsKey(word.id) &&
          !_groundHitControllers.containsKey(word.id)) {
        word.controller.forward();
      }
    }

    // Restart the clock from where it stopped.
    // Dart's Stopwatch.start() on a stopped (not reset) watch resumes from
    // the existing elapsed time — so the display updates continuously.
    // _startTimer() also creates a fresh Timer.periodic for the display update
    // (the old one was cancelled by _onPausePressed).
    _startTimer();

    // Restart the periodic spawn timer WITHOUT an immediate spawn.
    // Existing words are already mid-fall on screen — we only want the
    // timer to resume generating new words at the normal spawn interval.
    _startSpawnTimer(spawnImmediately: false);

    // Re-focus the input field so the player can type immediately on resume.
    _inputFocusNode.requestFocus();

    setState(() {}); // _isPaused is now false → overlay removed from Stack
  }

  /// Called when the player taps "End Game" in the Pause overlay.
  ///
  /// Exits the game WITHOUT saving any progress for this run.
  /// Pops this GameScreen, returning to LevelSelectionScreen.
  ///
  /// WHY no progress save?
  /// The player chose to abandon the level mid-run. Saving a partial score
  /// would be misleading — only fully completed runs count toward best times.
  void _onEndGame() {
    Navigator.pop(context);
  }

  /// Called on every keystroke in the answer field.
  ///
  /// Compares the current typed text against every falling word's answer.
  /// On a match the word freezes, plays a 500ms green flash + scale-up +
  /// fade-out animation (per Section 6.5), then is removed. Score is
  /// updated immediately and the input field is cleared right away so the
  /// player can start typing the next word without waiting for the animation.
  ///
  /// Per Section 6.3: "Real-time checking: On onChanged, check input
  /// length >=4 and match against falling words (clear field on match)."
  ///
  /// WHY iterate a COPY of _fallingWords?
  /// setState() called inside can trigger rebuilds. List.from() gives us a
  /// stable snapshot to iterate without ConcurrentModificationError.
  ///
  /// WHY skip words already in _matchControllers?
  /// A word in _matchControllers is mid-animation — already matched. We
  /// must not match it again (which would double-score or double-remove).
  void _onInputChanged(String value) {
    // No matching after game over, level complete, or while paused.
    if (_isGameOver || _isLevelComplete || _isPaused) return;

    // Normalise: uppercase and strip stray whitespace.
    // TextCapitalization.characters already forces uppercase, but we
    // normalise defensively to make comparisons reliable.
    final String typed = value.toUpperCase().trim();

    // Section 6.3: skip checks for very short input (no word is < 4 letters).
    if (typed.length < 4) return;

    // Snapshot the list before iterating (avoids ConcurrentModificationError
    // if setState is called while we're still in the loop).
    for (final FallingWord word in List<FallingWord>.from(_fallingWords)) {
      // Skip words already mid-match-animation.
      if (_matchControllers.containsKey(word.id)) continue;

      // Skip words already mid-ground-hit animation.
      //
      // WHY: When a word's fall reaches the ground, _onWordHitGround() creates a
      // groundCtrl animation and stores it in _groundHitControllers. The word
      // stays in _fallingWords for the 600ms red-flash duration. Without this
      // guard, a player who types the answer during that 600ms window would pass
      // the _matchControllers check (no entry yet) and trigger _onInputChanged to
      // create a second matchCtrl for the same word. Both groundCtrl and matchCtrl
      // call _removeWord() on completion, which tries to dispose word.controller
      // twice — crashing with "AnimationController.dispose() called more than once".
      if (_groundHitControllers.containsKey(word.id)) continue;

      if (typed == word.answer) {
        // ── CORRECT GUESS ──────────────────────────────────────────────────

        // Freeze the fall so the word stops moving during its exit animation.
        word.controller.stop();

        // Update score and completed-word counter immediately (don't wait
        // for the animation to finish — the player should see points now).
        //
        // WHY clamp to 100?
        // Guards against an edge case where two match events arrive in the same
        // frame near the end of the level, which would otherwise push the score
        // to 105/100. Clamping ensures the display always shows "100 / 100".
        setState(() {
          _score = (_score + 5).clamp(0, 100);
          _wordsCompleted++; // Drives word-length progression via GameManager
        });

        // Tell GameManager to advance its internal word-length counter so
        // the next getNextWord() call returns the right length word.
        GameManager().recordCorrectWord();

        // Detect level completion: 20 correct words = 100 pts = level done.
        // _handleLevelComplete() stops timers, freezes remaining words, saves
        // the best time, and unlocks the next level. The green exit animation
        // on this (potentially last) word still plays through to completion.
        if (_wordsCompleted >= 20) {
          _handleLevelComplete();
          // No need to break — the break below still fires, and _isLevelComplete
          // will guard against any further matches in the same onChanged call.
        }

        // Trigger the gold score highlight in the header (Section 6.5:
        // "brief gold highlight on score text, 300ms opacity tween").
        // Reset first in case a previous highlight is still fading out.
        _scoreHighlightController.reset();
        _scoreHighlightController.forward().then((_) {
          if (mounted) _scoreHighlightController.reverse();
        });

        // Clear the input field immediately so the player can start typing
        // the next word while the animation is still playing.
        // clear() triggers onChanged("") which returns early at length < 4.
        _textController.clear();
        _inputFocusNode.requestFocus();

        // ── PER-WORD FLASH ANIMATION (Section 5.5 / 6.5) ──────────────────
        // 500ms total:
        //   0.0–0.5 (250ms): scale 1.0→1.05, green tint fades IN
        //   0.5–1.0 (250ms): opacity 1.0→0.0, card fades OUT
        //
        // We create one AnimationController per matched word (not a shared
        // controller) so multiple words can animate simultaneously if the
        // player is fast enough to match two words in quick succession.
        final matchCtrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        );
        _matchControllers[word.id] = matchCtrl;

        // When the 500ms animation completes, clean up and remove the card.
        matchCtrl.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              matchCtrl.dispose();
              _matchControllers.remove(word.id);
              _removeWord(word);
            }
          }
        });

        // Trigger the animation — _buildFallingWordWidget watches
        // _matchControllers to apply the scale + tint + fade.
        setState(() {}); // Force rebuild so _buildFallingWordWidget detects the new match
        matchCtrl.forward();

        // Only one word can match per keystroke — stop checking.
        break;
      }
    }
  }

  /// Called when the player presses Enter/Go on the keyboard.
  ///
  /// Per Section 6.3: "Enter key: Trigger check via onSubmitted."
  /// Runs the same match logic as _onInputChanged. This covers the case
  /// where the player types quickly and taps Enter before onChanged fires,
  /// or simply prefers to confirm with Enter rather than rely on live-match.
  ///
  /// After the check (match or no match), always clears and refocuses —
  /// Enter is treated as "submit this attempt, start the next one".
  void _onInputSubmitted(String value) {
    // Delegate to the same matching logic used by onChanged.
    _onInputChanged(value);

    // Always clear + refocus after Enter, even if no match was found.
    // (If a match WAS found, _onInputChanged already cleared the field,
    // so calling clear() again is harmless.)
    _textController.clear();
    _inputFocusNode.requestFocus();
  }

  // ==========================================================================
  // OVERLAY NAVIGATION  (Stage 6)
  // ==========================================================================

  /// Formats a duration in milliseconds as "M:SS" (e.g. 95000ms → "1:35").
  ///
  /// Mirrors the format used by ProgressManager.getFormattedBestTime() so
  /// time values are displayed consistently across the app.
  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000; // integer division — drops sub-seconds
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    // padLeft(2, '0') ensures "1:05" not "1:5".
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns an encouraging message for the Game Over overlay based on score.
  ///
  /// The message becomes more positive as the score gets higher, to motivate
  /// the player to try again based on how close they were to winning.
  String _getEncouragementMessage() {
    if (_score == 0) return 'Every champion was once a beginner!';
    if (_score <= 20) return "You're just warming up!";
    if (_score <= 40) return "You're getting the hang of it!";
    if (_score <= 60) return 'More than halfway — try again!';
    if (_score <= 80) return 'So close! One more attempt!';
    return "Almost there — you've got this!";
  }

  /// Restarts the current level in a fresh GameScreen instance.
  ///
  /// pushReplacement pops this GameScreen and immediately pushes a new one
  /// at the same stack position, so the back button still returns to
  /// LevelSelectionScreen.
  void _onTryAgain() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        // Build a brand new GameScreen for the same level.
        // initState() will reinitialise GameManager and reset all counters.
        pageBuilder: (_, _, _) => GameScreen(level: widget.level),
        // Simple fade transition — matches the rest of the app.
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Starts the next level (Level Complete overlay only).
  ///
  /// kAllLevels is 0-indexed, so kAllLevels[levelNumber] is the level AFTER
  /// the current one (e.g. levelNumber=1 → index 1 = Level 2).
  /// This is safe because _onContinue is only shown when levelNumber < 5.
  void _onContinue() {
    final LevelConfig nextLevel = kAllLevels[widget.level.levelNumber];
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GameScreen(level: nextLevel),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Returns to LevelSelectionScreen by popping this GameScreen off the stack.
  ///
  /// Navigation stack: MainMenuScreen → LevelSelectionScreen → GameScreen.
  /// A single pop returns to the level list.
  void _onGoToLevelSelect() {
    Navigator.pop(context);
  }

  /// Returns all the way to MainMenuScreen by popping until the root route.
  ///
  /// popUntil with route.isFirst pops both GameScreen and LevelSelectionScreen,
  /// landing back on MainMenuScreen at the bottom of the stack.
  void _onGoToMainMenu() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ==========================================================================
  // OVERLAY WIDGETS  (Stage 6)
  // ==========================================================================

  /// The Game Over overlay card.
  ///
  /// Shows the final score, level name, and an encouragement message, then
  /// offers three navigation buttons: Try Again, Level Select, Main Menu.
  ///
  /// Entry animation: ScaleTransition driven by _overlayController (0→1, 500ms,
  /// Curves.easeOut) so the card "pops in" from the centre of the screen.
  Widget _buildGameOverOverlay() {
    return Container(
      // Semi-transparent black backdrop dims the frozen game beneath.
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          // Animated scale from 0 to 1 — creates the "pop in" effect.
          scale: CurvedAnimation(
            parent: _overlayController,
            curve: Curves.easeOut,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink-wrap to content
                children: [
                  // ── ICON ──────────────────────────────────────────────────
                  const Icon(
                    Icons.heart_broken_rounded,
                    color: Color(0xFFE53935), // Red
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // ── TITLE ─────────────────────────────────────────────────
                  const Text(
                    'GAME OVER',
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF333333),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 22.0),

                  // ── STATS ─────────────────────────────────────────────────
                  _buildOverlayStatRow('Level', widget.level.name),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Score', '$_score / 100'),
                  const SizedBox(height: 18.0),

                  // ── ENCOURAGEMENT MESSAGE ─────────────────────────────────
                  // Changes based on score — the closer the player was to 100,
                  // the more motivating the message (see _getEncouragementMessage).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FA), // Faint purple tint
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      _getEncouragementMessage(),
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF555555),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // ── BUTTONS ───────────────────────────────────────────────
                  // Try Again is the primary CTA (most likely action).
                  _buildOverlayButton(
                    'Try Again',
                    onPressed: _onTryAgain,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 10.0),
                  _buildOverlayButton(
                    'Level Select',
                    onPressed: _onGoToLevelSelect,
                  ),
                  const SizedBox(height: 10.0),
                  _buildOverlayButton(
                    'Main Menu',
                    onPressed: _onGoToMainMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The Level Complete overlay card.
  ///
  /// Shows the score (always 100/100), the player's completion time, and a
  /// "New Record!" badge in gold if this run beat the previous best time.
  ///
  /// Buttons:
  ///   Levels 1–4: Continue (next level), Replay Level, Level Select
  ///   Level 5 (final): No "Continue" — instead offers Replay and Main Menu
  ///
  /// Entry animation: same ScaleTransition as the Game Over overlay.
  Widget _buildLevelCompleteOverlay() {
    // Level 5 is the final level — "Continue" doesn't exist, and we show
    // a special "YOU WIN!" title and a Main Menu button instead.
    final bool isLastLevel = widget.level.levelNumber == 5;

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _overlayController,
            curve: Curves.easeOut,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ICON ──────────────────────────────────────────────────
                  Icon(
                    // Trophy for full game clear; checkmark for standard completion
                    isLastLevel ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                    color: const Color(0xFFFFD700), // Gold (#FFD700 per Section 1.4)
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // ── TITLE ─────────────────────────────────────────────────
                  Text(
                    isLastLevel ? 'YOU WIN!' : 'LEVEL COMPLETE!',
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF333333),
                      letterSpacing: 1.5,
                    ),
                  ),

                  // Sub-title only for the final level
                  if (isLastLevel) ...[
                    const SizedBox(height: 4.0),
                    const Text(
                      'All 5 levels conquered!',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22.0),

                  // ── STATS ─────────────────────────────────────────────────
                  _buildOverlayStatRow('Score', '100 / 100'),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Time', _formatTime(_completionTimeMs)),
                  const SizedBox(height: 8.0),

                  // Best time row — shows "New Record!" badge in gold if this
                  // run beat the previous best, otherwise shows the existing best.
                  if (_isNewBestTime)
                    _buildNewBestBadgeRow()
                  else
                    _buildOverlayStatRow(
                      'Best',
                      // getBestTime now reflects the just-saved value (or the
                      // existing best if this run was slower than the prior best).
                      _formatTime(
                        ProgressManager().getBestTime(widget.level.levelNumber) ??
                            _completionTimeMs,
                      ),
                    ),
                  const SizedBox(height: 28.0),

                  // ── BUTTONS ───────────────────────────────────────────────
                  // Levels 1-4: Continue to next level is the primary CTA.
                  // Level 5: No "Continue" — Replay becomes the primary CTA.
                  if (!isLastLevel) ...[
                    _buildOverlayButton(
                      'Continue',
                      onPressed: _onContinue,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 10.0),
                    _buildOverlayButton(
                      'Replay Level',
                      onPressed: _onTryAgain,
                    ),
                    const SizedBox(height: 10.0),
                    _buildOverlayButton(
                      'Level Select',
                      onPressed: _onGoToLevelSelect,
                    ),
                  ] else ...[
                    // Final level complete — offer replay + menu options.
                    _buildOverlayButton(
                      'Replay Level',
                      onPressed: _onTryAgain,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 10.0),
                    _buildOverlayButton(
                      'Level Select',
                      onPressed: _onGoToLevelSelect,
                    ),
                    const SizedBox(height: 10.0),
                    _buildOverlayButton(
                      'Main Menu',
                      onPressed: _onGoToMainMenu,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PAUSE OVERLAY WIDGET  (Stage 7)
  // ==========================================================================

  /// The Pause overlay card.
  ///
  /// Shows the player's current progress (level name, score, elapsed time,
  /// and lives remaining) while the game is frozen, then offers two buttons:
  ///   - "Resume Game" (primary): restores all animations and timers
  ///   - "End Game"   (outlined): exits to Level Selection without saving
  ///
  /// Entry animation: ScaleTransition driven by _pauseOverlayController
  /// (0→1, 500ms, Curves.easeOut) — identical style to the other overlays
  /// (Section 6.4: "Overlay appear: ScaleTransition from center, 500ms, easeOut").
  Widget _buildPauseOverlay() {
    return Container(
      // Semi-transparent black backdrop dims the frozen game beneath.
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          // Animated scale from 0 to 1 — creates the "pop in" effect.
          scale: CurvedAnimation(
            parent: _pauseOverlayController,
            curve: Curves.easeOut,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 32.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink-wrap to content
                children: [
                  // ── APP NAME ────────────────────────────────────────────────
                  // Small muted label above the icon anchors the overlay to
                  // the game brand — helpful context when the screen is frozen.
                  const Text(
                    'WORD DROP',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFAAAAAA), // Muted gray
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),

                  // ── ICON ──────────────────────────────────────────────────
                  const Icon(
                    Icons.pause_circle_filled_rounded,
                    color: Color(0xFF764ba2), // Deep purple (app accent colour)
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // ── TITLE ─────────────────────────────────────────────────
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF333333),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 22.0),

                  // ── STATS ─────────────────────────────────────────────────
                  // Shows the player's live progress so they can decide whether
                  // to resume or cut the run short.
                  _buildOverlayStatRow('Level', widget.level.name),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Score', '$_score / 100'),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Time', _timerDisplay),
                  const SizedBox(height: 8.0),
                  // Lives: "remaining / total" — e.g. "2 / 3" for Level 1
                  _buildOverlayStatRow(
                    'Lives',
                    '$_lives / ${widget.level.lives}',
                  ),
                  const SizedBox(height: 28.0),

                  // ── BUTTONS ───────────────────────────────────────────────
                  // Resume is the primary CTA — most players pause briefly
                  // and want to continue without thinking about it.
                  _buildOverlayButton(
                    'Resume Game',
                    onPressed: _onResume,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 10.0),
                  // End Game exits to Level Select without saving. Secondary
                  // action — outlined style signals it is the destructive option.
                  _buildOverlayButton(
                    'End Game',
                    onPressed: _onEndGame,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // OVERLAY HELPER WIDGETS  (Stage 6)
  // ==========================================================================

  /// A single label + value row inside an overlay card.
  ///
  /// Label is muted gray (left), value is dark bold (right).
  /// Used for: Level name, Score, Time, Best time.
  Widget _buildOverlayStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15.0,
            color: Color(0xFF888888), // Muted gray label
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  /// The "New Record!" badge row shown instead of the normal Best row when the
  /// player beats their previous best time.
  ///
  /// Displays a star icon + time + "New Record!" all in gold (#FFD700).
  Widget _buildNewBestBadgeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Best',
          style: TextStyle(
            fontSize: 15.0,
            color: Color(0xFF888888),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFD700), // Gold
              size: 16.0,
            ),
            const SizedBox(width: 4.0),
            Text(
              // Show the new best time (= the time just achieved).
              '${_formatTime(_completionTimeMs)}  New Record!',
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700), // Gold
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A full-width button for use inside an overlay card.
  ///
  /// [isPrimary] = true  → filled purple ElevatedButton (main CTA)
  /// [isPrimary] = false → outlined button (secondary actions)
  Widget _buildOverlayButton(
    String label, {
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                // Deep purple matches the app's header gradient bottom colour.
                backgroundColor: const Color(0xFF764ba2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 2,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF764ba2),
                side: const BorderSide(color: Color(0xFF764ba2), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 15.0),
              ),
            ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset: true (default) — Flutter automatically shrinks
      // the scaffold when the software keyboard appears, keeping the input field
      // visible. LayoutBuilder inside _buildGameArea() measures the actual
      // remaining height, so word positions are always correct relative to the
      // current game area size (even after the keyboard has resized things).
      backgroundColor: Colors.transparent,

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // Blue-purple (top)
              Color(0xFF764ba2), // Deep purple (bottom)
            ],
          ),
        ),

        child: SafeArea(
          // Stack lets us layer the Game Over / Level Complete overlays on top
          // of the main game content without disrupting the Column's layout.
          child: Stack(
            children: [
              // ALL GAME CONTENT — fills the full SafeArea via Positioned.fill.
              // This ensures the Column always occupies the same space regardless
              // of whether an overlay is currently showing on top of it.
              Positioned.fill(
                child: Column(
                  children: [
                    // HEADER: level name, score, lives hearts, timer
                    _buildHeader(),

                    // GAME AREA: words fall here (Expanded = fills remaining space)
                    Expanded(child: _buildGameArea()),

                    // INPUT AREA: text field + pause button
                    _buildInputArea(),
                  ],
                ),
              ),

              // GAME OVER OVERLAY (Section 2.6 / 6.4)
              // Appears when lives hit 0. ScaleTransition animates the card
              // from scale 0→1 over 500ms with Curves.easeOut so it "pops in"
              // from the centre. Semi-transparent backdrop dims the game below.
              if (_isGameOver)
                Positioned.fill(child: _buildGameOverOverlay()),

              // LEVEL COMPLETE OVERLAY (Section 2.6 / 6.4)
              // Appears when the player correctly guesses all 20 words.
              // Same entry animation as the Game Over overlay.
              if (_isLevelComplete)
                Positioned.fill(child: _buildLevelCompleteOverlay()),

              // PAUSE OVERLAY (Section 6.6)
              // Appears when the player taps the Pause button mid-game.
              // All falling word animations and timers are frozen while shown.
              // "Resume Game" restores the game; "End Game" exits without saving.
              if (_isPaused)
                Positioned.fill(child: _buildPauseOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  /// Header bar: level name (gold) above a row of [Score | ❤️ Hearts | Timer].
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level name in gold (Section 6.2: #FFD700)
          Text(
            widget.level.displayLabel, // e.g. "Level 1: Strolling"
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFD700),
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SCORE (left) — wrapped in AnimatedBuilder for the gold highlight
              Expanded(
                child: _buildStatBlock(
                  label: 'SCORE',
                  value: '$_score / 100',
                  alignment: CrossAxisAlignment.start,
                  highlightController: _scoreHighlightController,
                ),
              ),

              // LIVES HEARTS (centre — flex: 2 gives more room for 7 hearts)
              Expanded(
                flex: 2,
                child: Center(child: _buildLivesHearts()),
              ),

              // TIMER (right)
              Expanded(
                child: _buildStatBlock(
                  label: 'TIME',
                  value: _timerDisplay,
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A labelled two-line stat block (small label above a larger value).
  ///
  /// [highlightController] — optional. When provided the value text briefly
  /// turns gold (Color(0xFFFFD700)) as the controller animates 0→1→0.
  /// Used on the score block to give a 300ms gold flash on correct guesses
  /// (Section 6.5: "Brief gold highlight on score text, 300ms opacity tween").
  Widget _buildStatBlock({
    required String label,
    required String value,
    required CrossAxisAlignment alignment,
    AnimationController? highlightController,
  }) {
    // Value text color: white normally, lerps to gold while highlight plays.
    Widget valueText(Color color) => Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        );

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.60),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        // Wrap in AnimatedBuilder only when a highlight controller is provided.
        // The TIME stat uses this widget too and has no highlight animation.
        if (highlightController != null)
          AnimatedBuilder(
            animation: highlightController,
            builder: (context, _) {
              // Lerp: white (at controller.value=0) → gold (at 1.0).
              final Color color = Color.lerp(
                Colors.white,
                const Color(0xFFFFD700), // gold
                highlightController.value,
              )!;
              return valueText(color);
            },
          )
        else
          valueText(Colors.white),
      ],
    );
  }

  /// A row of heart icons: red = life remaining, white outline = life lost.
  ///
  /// Example — Level 1 (3 lives total), 1 lost: ❤️ 🤍 🤍
  Widget _buildLivesHearts() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.level.lives, (index) {
        // Fill hearts from left to right: first _lives hearts are red, rest white
        final bool isAlive = index < _lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Icon(
            isAlive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isAlive
                ? const Color(0xFFFF4444)            // Bright red
                : Colors.white.withValues(alpha: 0.35), // Faded white
            size: 18, // Small enough for 7 hearts (Level 5) to fit in one row
          ),
        );
      }),
    );
  }

  // ==========================================================================
  // GAME AREA
  // ==========================================================================

  /// Builds the falling-word play area.
  ///
  /// Uses LayoutBuilder to measure the available pixel space, then builds a
  /// Stack containing the SKY/GROUND labels and all active falling words.
  Widget _buildGameArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),

        // LayoutBuilder provides [constraints] — the exact width and height of
        // this Container. We use these to:
        //   - Calculate the fall distance: constraints.maxHeight - groundOffset - cardHeight
        //   - Keep words within horizontal bounds: constraints.maxWidth - cardWidth
        //
        // WHY LayoutBuilder instead of MediaQuery?
        // MediaQuery gives the full screen size. LayoutBuilder gives THIS
        // widget's size — which is what we actually need for positioning words.
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Capture game area dimensions for _spawnWord() overlap checks.
            // Direct assignment (not setState) — no rebuild needed, just
            // arithmetic values read next time _spawnWord() is called.
            _gameAreaWidth = constraints.maxWidth;
            _gameAreaHeight = constraints.maxHeight;

            return Stack(
              // clipBehavior: Clip.hardEdge keeps word cards inside the game area
              // container (they won't visually bleed into the header or input area).
              clipBehavior: Clip.hardEdge,
              children: [
                // ----------------------------------------------------------
                // SKY LABEL (top)
                // ----------------------------------------------------------
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildZoneLabel('SKY', isGroundLabel: false),
                  ),
                ),

                // ----------------------------------------------------------
                // GROUND LINE — thin red line showing the danger boundary.
                // Words that cross this line trigger a "ground hit" event.
                // Positioned 42px from the bottom (above the GROUND label).
                // ----------------------------------------------------------
                Positioned(
                  bottom: 42,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // ----------------------------------------------------------
                // GROUND LABEL (bottom)
                // ----------------------------------------------------------
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildZoneLabel('GROUND', isGroundLabel: true),
                  ),
                ),

                // ----------------------------------------------------------
                // FALLING WORD CARDS
                // Each FallingWord in _fallingWords gets its own animated
                // Positioned widget. The list is spread into the Stack's
                // children using the ... (spread) operator.
                // ----------------------------------------------------------
                ..._fallingWords.map(
                  (word) => _buildFallingWordWidget(word, constraints),
                ),

                // (Correct-guess flash is per-word — see _buildFallingWordWidget
                //  which applies scale + green tint + fade-out to matched cards.)
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the zone label badge (SKY = blue/white, GROUND = red).
  Widget _buildZoneLabel(String text, {required bool isGroundLabel}) {
    final Color bgColor = isGroundLabel
        ? Colors.red.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.15);

    final Color borderColor = isGroundLabel
        ? Colors.red.withValues(alpha: 0.50)
        : Colors.white.withValues(alpha: 0.35);

    final Color textColor = isGroundLabel
        ? const Color(0xFFFF6B6B)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 2.5,
        ),
      ),
    );
  }

  // ==========================================================================
  // FALLING WORD WIDGET
  // ==========================================================================

  /// Builds an animated word card, handling two states:
  ///
  /// FALLING (normal): the card moves from top to ground line driven by
  ///   [word.controller] (Curves.linear, constant velocity).
  ///
  /// MATCHED (exit animation): triggered when the player correctly types
  ///   the word. The fall is frozen at its current y position, and a 500ms
  ///   exit animation plays (per Section 5.5 / Section 6.5):
  ///     0–250ms: scale 1.0 → 1.05, green tint fades in
  ///     250–500ms: opacity 1.0 → 0.0 (card fades out)
  ///   After completion, _removeWord() is called to clean up.
  ///
  /// [word]        — data + fall controller for this word instance
  /// [constraints] — pixel dimensions of the game area (from LayoutBuilder)
  Widget _buildFallingWordWidget(FallingWord word, BoxConstraints constraints) {
    const double approxCardWidth = 190.0;
    const double approxCardHeight = 70.0;
    const double groundLineOffset = 42.0;

    final double maxY = (constraints.maxHeight - groundLineOffset - approxCardHeight)
        .clamp(0.0, double.infinity);

    final double xPos = (word.xFraction * (constraints.maxWidth - approxCardWidth))
        .clamp(0.0, constraints.maxWidth - approxCardWidth);

    // ── MATCHED EXIT ANIMATION ──────────────────────────────────────────────
    final AnimationController? matchCtrl = _matchControllers[word.id];
    if (matchCtrl != null) {
      // The fall controller was stopped on match — use its frozen value for y.
      final double frozenY = word.controller.value * maxY;

      // The card widget is built once and reused across all animation frames.
      // We use a Stack inside the AnimatedBuilder to overlay the green tint
      // on top of the card content without rebuilding the card itself.
      final Widget card = _buildWordCard(word);

      return AnimatedBuilder(
        animation: matchCtrl,
        child: card,
        builder: (context, child) {
          final double t = matchCtrl.value; // 0.0 → 1.0 over 500ms

          // Scale: 1.0 at t=0, eases up to 1.05 by t=0.5, holds at 1.05.
          // Curves.easeOut applied to the first half (0..0.5 mapped to 0..1).
          final double scaleFraction = Curves.easeOut.transform(
            (t * 2.0).clamp(0.0, 1.0),
          );
          final double scale = 1.0 + 0.05 * scaleFraction;

          // Opacity: full (1.0) during first half, fades to 0 in second half.
          final double opacity =
              t < 0.5 ? 1.0 : 1.0 - ((t - 0.5) * 2.0).clamp(0.0, 1.0);

          // Green tint overlay alpha: ramps up to 50% opacity in first half,
          // then fades with the card (automatically, via the Opacity wrapper).
          final double greenAlpha = (t * 2.0).clamp(0.0, 1.0) * 0.50;

          return Positioned(
            left: xPos,
            top: frozenY,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  children: [
                    child!, // The word card (built once above)
                    // Green tint layered over the card face
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(
                            alpha: greenAlpha,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // ── GROUND HIT EXIT ANIMATION (Section 5.5 / 6.5) ──────────────────────
    // Mirrors the match animation but RED and 600ms duration:
    //   0.0–0.5 (300ms): scale 1.0 → 1.05, red tint fades IN  (impact pulse)
    //   0.5–1.0 (300ms): opacity 1.0 → 0.0, card fades OUT
    final AnimationController? groundCtrl = _groundHitControllers[word.id];
    if (groundCtrl != null) {
      // Word has reached the ground — use maxY as its frozen y position.
      // (Fall animation completed at value=1.0, so it's at the ground line.)
      final Widget card = _buildWordCard(word);

      return AnimatedBuilder(
        animation: groundCtrl,
        child: card,
        builder: (context, child) {
          final double t = groundCtrl.value; // 0.0 → 1.0 over 600ms

          // Scale: eases up to 1.05 in the first half, holds thereafter.
          final double scaleFraction = Curves.easeOut.transform(
            (t * 2.0).clamp(0.0, 1.0),
          );
          final double scale = 1.0 + 0.05 * scaleFraction;

          // Opacity: full in first half, fades to 0 in second half.
          final double opacity =
              t < 0.5 ? 1.0 : 1.0 - ((t - 0.5) * 2.0).clamp(0.0, 1.0);

          // Red tint ramps up to 60% opacity in first half.
          final double redAlpha = (t * 2.0).clamp(0.0, 1.0) * 0.60;

          return Positioned(
            left: xPos,
            top: maxY, // frozen at ground line
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: redAlpha),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // ── NORMAL FALLING WORD ─────────────────────────────────────────────────
    // The card is built ONCE and passed as [child] to avoid rebuilding it on
    // every animation frame. Only the Positioned top value changes per tick.
    return AnimatedBuilder(
      animation: word.controller,
      child: _buildWordCard(word),
      builder: (context, child) {
        final double yPos = word.controller.value * maxY;
        return Positioned(
          left: xPos,
          top: yPos,
          child: child!,
        );
      },
    );
  }

  /// Builds the visual word card: hint pattern + descriptive clue.
  ///
  /// Per Section 6.2:
  ///   - White/near-white background, dark text (high contrast)
  ///   - Hint: large monospace font, bold, letter-spaced
  ///   - Clue: smaller, italic, grey
  Widget _buildWordCard(FallingWord word) {
    return Container(
      // maxWidth prevents long 10-letter hints from overflowing the game area.
      // The card shrinks to fit shorter hints, up to this maximum.
      constraints: const BoxConstraints(maxWidth: 210),

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min, // Card height = exactly its content
        children: [
          // HINT PATTERN
          // Section 6.2: "Monospace font, bold, letter-spaced"
          // e.g. "B - N - N -" for BANANA
          Text(
            word.hint,
            style: const TextStyle(
              fontFamily: 'monospace', // Courier New or system monospace
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              letterSpacing: 3.0,
            ),
          ),

          const SizedBox(height: 4),

          // CLUE
          // Section 6.2: "Descriptions/Clues: slightly smaller, italicised"
          // e.g. "Yellow curved fruit"
          Text(
            word.clue,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INPUT AREA
  // ==========================================================================

  /// Input zone: autofocused text field + pause button.
  ///
  /// Per Section 6.3:
  ///   - autofocus: true (keyboard opens immediately)
  ///   - TextCapitalization.characters (forces uppercase to match word bank)
  ///   - No autocorrect / no suggestions (they interfere with gameplay)
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // TEXT INPUT FIELD
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.center,
                onChanged: _onInputChanged,
                onSubmitted: _onInputSubmitted,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                  letterSpacing: 2.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Type the word...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.withValues(alpha: 0.55),
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // PAUSE BUTTON
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: IconButton(
              onPressed: _onPausePressed,
              icon: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 26,
              ),
              tooltip: 'Pause Game',
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
