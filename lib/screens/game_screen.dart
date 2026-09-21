// ============================================================================
// GAME SCREEN
// ============================================================================
// This is the main gameplay screen â€” where words fall from the sky and the
// player types answers to catch them before they hit the ground.
//
// STAGE 7 (THIS FILE): Pause â€” the player can freeze the game mid-run, review
// current progress (level / score / time / lives), then resume or abandon.
// All word fall animations, spawn timer, and stopwatch freeze on pause and
// are accurately restored on resume.
//
// WHAT IS IN THIS STAGE:
//   - Everything from Stages 1â€“6
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
// Section 5.1 â€” Word Drop Mechanics:
//   - Use AnimationController with Curves.linear for constant velocity
//   - Word widgets are Positioned inside a Stack
//   - Fall distance: effective height = game area height - groundOffset - cardHeight
//
// Section 5.3 â€” Fall Speed Calculations:
//   - Fall duration from LevelConfig.cardTime (e.g. 30000ms for Level 1)
//
// Section 5.4 â€” Collision Detection:
//   - Use Animation.addStatusListener to detect AnimationStatus.completed
//
// Section 5.5 â€” Animation Durations:
//   - Fall: Curves.linear, duration = cardTime
//   - Spawn fade-in: TODO (will be added as polish)
//
// Section 6.2 â€” Visual Hierarchy for word cards:
//   - "High-contrast cards: white background, dark text"
//   - "Incomplete word in large monospace font (bold, letter-spaced)"
//   - "Clue in smaller italic gray text below"
//
// STAGE ROADMAP (see PROGRESS.md for full details):
//   Stage 1: Static layout â€” three zones visible and correctly sized
//   Stage 2: Single falling word using AnimationController + Curves.linear
//   Stage 3: Spawn timer + multiple simultaneous words + overlap prevention
//   Stage 4: Input matching â€” onChanged checks typed text against words
//   Stage 5: Lives + scoring â€” ground hit deducts life, overlap fix
//   Stage 6: Game Over and Level Complete overlays
//   Stage 7 (THIS): Pause overlay â€” freezes all animations and timers
//
// CHANGELOG:
//   - Stage 1: Initial creation â€” static layout, three zones
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
//   - Stage 7: Pause overlay â€” _isPaused + _pauseOverlayController,
//              _onPausePressed / _onResume / _onEndGame, _buildPauseOverlay,
//              _startSpawnTimer({spawnImmediately}) named parameter
// ============================================================================

import 'dart:async';  // For Timer (used by the stopwatch display updater)
import 'package:flutter/material.dart';
import '../managers/game_manager.dart';      // Provides the words to display
import '../managers/progress_manager.dart'; // Saves best time + unlocks next level
import '../models/level_config.dart';

// ============================================================================
// GRID CONSTANTS  (REDESIGN.md S2 and S4)
// ============================================================================
// All the numbers that set the size of the card grid live here, so one change
// updates the whole screen. The 'k' prefix is the Dart convention for a
// constant.

/// Padding on the left and the right of the grid, in pixels.
const double kGridPaddingH = 12.0;

/// Padding above and below the grid, in pixels.
const double kGridPaddingV = 8.0;

/// The gap between two cards, in pixels. It applies between columns and rows.
const double kGridGap = 8.0;

/// The fixed height of one card, in pixels.
///
/// The parts are: hint row 22px, gap 4px, clue on 3 lines 42px,
/// padding 8px + 8px, and the timer bar 4px (REDESIGN.md S2).
const double kCardHeight = 88.0;

/// The number of grid positions, and therefore the maximum number of cards on
/// the screen at one time (REDESIGN.md D12, D17, D18).
const int kMaxCards = 6;

// ============================================================================
// GAME SCREEN WIDGET
// ============================================================================

/// The main gameplay screen. Word cards sit in a grid and count down, and the
/// player types the answers.
///
/// Accepts a [LevelConfig] from the Level Selection screen so it can set the
/// card time, the new-card interval, and the starting lives without
/// hard-coding values.
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
/// Multiple AnimationControllers run simultaneously in this screen â€” one per
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
  ///
  /// The ignore is temporary: stage 4.4 writes this field again.
  // ignore: prefer_final_fields
  int _score = 0;

  /// How many words the player has correctly guessed this level (0â€“20).
  ///
  /// This drives word length progression within the level:
  ///   _wordsCompleted 0â€“3  (words 1â€“4)  â†’ 6-letter words
  ///   _wordsCompleted 4â€“7  (words 5â€“8)  â†’ 7-letter words
  ///   _wordsCompleted 8â€“11 (words 9â€“12) â†’ 8-letter words
  ///   _wordsCompleted 12â€“15             â†’ 9-letter words
  ///   _wordsCompleted 16â€“19             â†’ 10-letter words
  ///
  /// Incremented in _onInputChanged() each time the player correctly guesses
  /// a word. Also passed to GameManager.recordCorrectWord() so that
  /// getNextWord() returns the right word length for the next card.
  ///
  /// The ignores are temporary: stage 4.4 writes and reads this field again.
  // ignore: prefer_final_fields, unused_field
  int _wordsCompleted = 0;

  /// Elapsed time displayed in the header (e.g. "1:42").
  /// Starts at "0:00" and updates every second once the first word spawns.
  String _timerDisplay = '0:00';

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
  Timer? _newCardTimer;

  // (Flash animations are per-word â€” see _matchControllers and
  //  _groundHitControllers above and _buildFallingWordWidget below.)

  /// Drives the brief gold highlight on the score text when a word is matched.
  ///
  /// Cycle: 0.0 â†’ 1.0 (150ms, gold in) then 1.0 â†’ 0.0 (150ms, gold out).
  /// Total visible duration: 300ms (per Section 6.5 "brief gold highlight").
  ///
  /// The score text Color lerps from white to Color(0xFFFFD700) and back.
  late AnimationController _scoreHighlightController;

  /// Drives the Game Over / Level Complete overlay entrance animation.
  ///
  /// ScaleTransition scales the overlay card from 0â†’1 over 500ms with
  /// Curves.easeOut, making it "pop" into view from the centre of the screen.
  /// (Section 6.4: "Overlay appear: ScaleTransition from center, 500ms, easeOut")
  ///
  /// This single controller is reused for either overlay â€” only one can ever
  /// be shown at a time since the flags _isGameOver and _isLevelComplete are
  /// mutually exclusive.
  late AnimationController _overlayController;

  /// Drives the Pause overlay entrance animation.
  ///
  /// Identical animation to _overlayController (500ms, Curves.easeOut) but
  /// kept separate so that _overlayController's state is never disturbed by
  /// pause/resume interactions. Reset and re-forwarded each time the player
  /// pauses â€” supports multiple pause-resume cycles in one session.
  late AnimationController _pauseOverlayController;

  // ==========================================================================
  // LEVEL COMPLETE STATE  (populated in _handleLevelComplete, read by overlay)
  // ==========================================================================

  /// The player's actual completion time in milliseconds (0 until level ends).
  /// Captured the moment the 20th word is matched â€” used by the overlay to
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

    // 150ms per direction Ã— 2 = 300ms total gold-flash cycle (Section 6.5).
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

    // STAGE 4.1 — no timers yet.
    //
    // The old design started a spawn timer here, which dropped words down the
    // screen. The redesign replaces that with word cards in a fixed grid, and
    // each card holds its own countdown (REDESIGN.md D1).
    //
    // The card engine arrives in the next stages:
    //   Stage 4.2 — one card with a working countdown  (REDESIGN.md S3)
    //   Stage 4.3 — the automatic interval and the "+" button (S5)
    //   Stage 4.6 — the "3, 2, 1, Go" countdown at start and resume (S8)
    //
    // This stage only proves the layout: 6 grid positions, the scroll view,
    // the header and the input row.
  }

  @override
  void dispose() {
    // Cancel the clock timer first to stop any pending setState() calls.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Cancel the new-card timer so no card is created after disposal.
    // Without this, the timer could fire and try to call setState() or create
    // AnimationControllers after the State has been torn down.
    // (Stage 4.3 starts this timer. Stage 4.1 never starts it.)
    _newCardTimer?.cancel();

    // STAGE 4.2 will add: dispose the AnimationController of every card in
    // _cards, because each card owns one countdown controller.

    _scoreHighlightController.dispose();
    _overlayController.dispose();
    _pauseOverlayController.dispose();
    _textController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  /// Called when all lives reach zero.
  ///
  /// Called when all lives reach zero.
  ///
  /// Stops all running timers, freezes all falling animations, then triggers
  /// the Game Over overlay (Stage 6) which slides in from the centre of the
  /// screen and offers "Try Again", "Level Select", and "Main Menu" buttons.
  /// The ignore is temporary: stage 4.2 calls this when a card fails and the
  /// lives reach 0.
  // ignore: unused_element
  void _handleGameOver() {
    // Don't trigger game over if the level was already completed.
    // Edge case: a word could finish falling at the exact frame that the
    // 20th word is matched. Level Complete takes priority over Game Over.
    if (_isLevelComplete) return;

    _isGameOver = true;

    // Stop the new-card timer — no more new cards.
    _newCardTimer?.cancel();
    _newCardTimer = null;

    // Stop the clock.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // STAGE 4.2 will add: stop the countdown controller of every card in
    // _cards, so the grid freezes behind the overlay (REDESIGN.md D22).

    // Rebuild to show the overlay (which is gated on _isGameOver in build()),
    // then animate the card from scale 0â†’1 over 500ms (Section 6.4).
    if (mounted) {
      setState(() {}); // _isGameOver already true â€” this makes the overlay appear
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
  /// The ignore is temporary: stage 4.4 calls this at the 20th correct word.
  // ignore: unused_element
  void _handleLevelComplete() {
    _isLevelComplete = true;

    // Stop the new-card timer — no new card should appear after winning.
    _newCardTimer?.cancel();
    _newCardTimer = null;

    // Stop the clock — elapsed time is now the player's final completion time.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // STAGE 4.2 will add: stop the countdown controller of every card in
    // _cards, so the grid freezes behind the overlay (REDESIGN.md D22).

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
    // Both calls are fire-and-forget async â€” we don't need to await them
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
      setState(() {}); // _isLevelComplete already true â€” overlay now in tree
      _overlayController.forward();
    }
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
      // e.g. 65 seconds â†’ 1:05 not 1:5
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

    // Stop the new-card timer so no card appears while paused.
    _newCardTimer?.cancel();
    _newCardTimer = null;

    // Freeze the stopwatch — elapsed time must be preserved across pause/resume.
    // Dart's Stopwatch.stop() does NOT reset the elapsed value; it just stops
    // accumulating time. Calling start() later resumes from the same point.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // STAGE 4.2 will add: stop the countdown controller of every card, so the
    // whole grid freezes. A pause costs the player nothing (REDESIGN.md D32).

    // Dismiss the keyboard — the player can't type while paused.
    _inputFocusNode.unfocus();

    // Show the pause overlay: _isPaused = true puts it in the Stack, then
    // animate the card in from scale 0â†’1 (same 500ms easeOut as other overlays).
    setState(() {}); // _isPaused is now true â†’ overlay widget enters the tree
    _pauseOverlayController.forward();
  }

  /// Called when the player taps "Resume Game" in the Pause overlay.
  ///
  /// Dismisses the overlay, restores all frozen falling word animations,
  /// and restarts both the spawn timer (without an immediate extra spawn â€”
  /// existing words are mid-fall) and the stopwatch display timer.
  void _onResume() {
    // Reset the pause controller to 0 so it's ready for the next pause cycle.
    // (If we didn't reset, the next forward() call would be a no-op because
    // the controller would already be at its maximum value of 1.0.)
    _pauseOverlayController.reset();

    _isPaused = false;

    // STAGE 4.2 will add: start the countdown controller of every card again,
    // from the same value.
    // STAGE 4.6 will add: run the "3, 2, 1, Go" countdown BEFORE the timers
    // start again. This happens at every resume (REDESIGN.md D30).

    // Restart the clock from where it stopped.
    // Dart's Stopwatch.start() on a stopped (not reset) watch resumes from
    // the existing elapsed time — so the display updates continuously.
    // _startTimer() also creates a fresh Timer.periodic for the display update
    // (the old one was cancelled by _onPausePressed).
    _startTimer();

    // STAGE 4.3 will add: start the new-card interval again, without an
    // immediate card.

    // Re-focus the input field so the player can type immediately on resume.
    _inputFocusNode.requestFocus();

    setState(() {}); // _isPaused is now false â†’ overlay removed from Stack
  }

  /// Called when the player taps "End Game" in the Pause overlay.
  ///
  /// Exits the game WITHOUT saving any progress for this run.
  /// Pops this GameScreen, returning to LevelSelectionScreen.
  ///
  /// WHY no progress save?
  /// The player chose to abandon the level mid-run. Saving a partial score
  /// would be misleading â€” only fully completed runs count toward best times.
  void _onEndGame() {
    Navigator.pop(context);
  }

  /// Called on every keystroke in the answer field.
  ///
  /// STAGE 4.1 — this does nothing yet.
  ///
  /// Stage 4.4 builds the real matching logic (REDESIGN.md S6):
  ///   - Start checking at 6 characters. The shortest word has 6 letters.
  ///   - Compare the typed text with the answer of every card on the grid.
  ///   - Check the cards in grid order, and stop at the first match.
  ///   - Skip a card in the Failed (red) or Matched (green) state.
  ///   - On a match: +5 points, a 500ms green flash, clear the field.
  ///   - On a wrong word: no feedback and no penalty (D10/E2, D27).
  void _onInputChanged(String value) {
    // No matching after game over, level complete, or while paused.
    if (_isGameOver || _isLevelComplete || _isPaused) return;

    // Stage 4.4 adds the card matching here.
  }

  /// Whether the "+" button can add a card right now (REDESIGN.md D14/H1a).
  ///
  /// STAGE 4.1: always false, because the card engine does not exist yet.
  /// Stage 4.3 returns true when a grid position is free, the game runs, and
  /// no card is waiting.
  bool get _canAddCard => false;

  /// Called when the player taps the "+" button.
  ///
  /// STAGE 4.1: never called, because _canAddCard is false.
  /// Stage 4.3 adds one card at once and restarts the interval from zero.
  void _onAddCardPressed() {
    // Stage 4.3 adds the behaviour here.
  }

  /// Called when the player presses Enter/Go on the keyboard.
  ///
  /// Per Section 6.3: "Enter key: Trigger check via onSubmitted."
  /// Runs the same match logic as _onInputChanged. This covers the case
  /// where the player types quickly and taps Enter before onChanged fires,
  /// or simply prefers to confirm with Enter rather than rely on live-match.
  ///
  /// After the check (match or no match), always clears and refocuses â€”
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

  /// Formats a duration in milliseconds as "M:SS" (e.g. 95000ms â†’ "1:35").
  ///
  /// Mirrors the format used by ProgressManager.getFormattedBestTime() so
  /// time values are displayed consistently across the app.
  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000; // integer division â€” drops sub-seconds
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
    if (_score <= 60) return 'More than halfway â€” try again!';
    if (_score <= 80) return 'So close! One more attempt!';
    return "Almost there â€” you've got this!";
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
        // Simple fade transition â€” matches the rest of the app.
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Starts the next level (Level Complete overlay only).
  ///
  /// kAllLevels is 0-indexed, so kAllLevels[levelNumber] is the level AFTER
  /// the current one (e.g. levelNumber=1 â†’ index 1 = Level 2).
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
  /// Navigation stack: MainMenuScreen â†’ LevelSelectionScreen â†’ GameScreen.
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
  /// Entry animation: ScaleTransition driven by _overlayController (0â†’1, 500ms,
  /// Curves.easeOut) so the card "pops in" from the centre of the screen.
  Widget _buildGameOverOverlay() {
    return Container(
      // Semi-transparent black backdrop dims the frozen game beneath.
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          // Animated scale from 0 to 1 â€” creates the "pop in" effect.
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
                  // â”€â”€ ICON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const Icon(
                    Icons.heart_broken_rounded,
                    color: Color(0xFFE53935), // Red
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // â”€â”€ TITLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                  // â”€â”€ STATS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _buildOverlayStatRow('Level', widget.level.name),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Score', '$_score / 100'),
                  const SizedBox(height: 18.0),

                  // â”€â”€ ENCOURAGEMENT MESSAGE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Changes based on score â€” the closer the player was to 100,
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

                  // â”€â”€ BUTTONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
  ///   Levels 1â€“4: Continue (next level), Replay Level, Level Select
  ///   Level 5 (final): No "Continue" â€” instead offers Replay and Main Menu
  ///
  /// Entry animation: same ScaleTransition as the Game Over overlay.
  Widget _buildLevelCompleteOverlay() {
    // Level 5 is the final level â€” "Continue" doesn't exist, and we show
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
                  // â”€â”€ ICON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Icon(
                    // Trophy for full game clear; checkmark for standard completion
                    isLastLevel ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                    color: const Color(0xFFFFD700), // Gold (#FFD700 per Section 1.4)
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // â”€â”€ TITLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                  // â”€â”€ STATS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  _buildOverlayStatRow('Score', '100 / 100'),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Time', _formatTime(_completionTimeMs)),
                  const SizedBox(height: 8.0),

                  // Best time row â€” shows "New Record!" badge in gold if this
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

                  // â”€â”€ BUTTONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Levels 1-4: Continue to next level is the primary CTA.
                  // Level 5: No "Continue" â€” Replay becomes the primary CTA.
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
                    // Final level complete â€” offer replay + menu options.
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
  /// (0â†’1, 500ms, Curves.easeOut) â€” identical style to the other overlays
  /// (Section 6.4: "Overlay appear: ScaleTransition from center, 500ms, easeOut").
  Widget _buildPauseOverlay() {
    return Container(
      // Semi-transparent black backdrop dims the frozen game beneath.
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          // Animated scale from 0 to 1 â€” creates the "pop in" effect.
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
                  // â”€â”€ APP NAME â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Small muted label above the icon anchors the overlay to
                  // the game brand â€” helpful context when the screen is frozen.
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

                  // â”€â”€ ICON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const Icon(
                    Icons.pause_circle_filled_rounded,
                    color: Color(0xFF764ba2), // Deep purple (app accent colour)
                    size: 52.0,
                  ),
                  const SizedBox(height: 10.0),

                  // â”€â”€ TITLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                  // â”€â”€ STATS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Shows the player's live progress so they can decide whether
                  // to resume or cut the run short.
                  _buildOverlayStatRow('Level', widget.level.name),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Score', '$_score / 100'),
                  const SizedBox(height: 8.0),
                  _buildOverlayStatRow('Time', _timerDisplay),
                  const SizedBox(height: 8.0),
                  // Lives: "remaining / total" â€” e.g. "2 / 3" for Level 1
                  _buildOverlayStatRow(
                    'Lives',
                    '$_lives / ${widget.level.lives}',
                  ),
                  const SizedBox(height: 28.0),

                  // â”€â”€ BUTTONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Resume is the primary CTA â€” most players pause briefly
                  // and want to continue without thinking about it.
                  _buildOverlayButton(
                    'Resume Game',
                    onPressed: _onResume,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 10.0),
                  // End Game exits to Level Select without saving. Secondary
                  // action â€” outlined style signals it is the destructive option.
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
  /// [isPrimary] = true  â†’ filled purple ElevatedButton (main CTA)
  /// [isPrimary] = false â†’ outlined button (secondary actions)
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
      // resizeToAvoidBottomInset: true (default) — Flutter shrinks the scaffold
      // when the keyboard appears, so the input row stays visible. The card
      // grid takes the height that is left, and it scrolls when 6 cards need
      // more height than that (REDESIGN.md S2, D20).
      //
      // The keyboard stays open for the whole game (D21), so the grid keeps one
      // size during play. Stage 4.6 adds the pause that D21 requires when the
      // player closes the keyboard.
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
              // ALL GAME CONTENT â€” fills the full SafeArea via Positioned.fill.
              // This ensures the Column always occupies the same space regardless
              // of whether an overlay is currently showing on top of it.
              Positioned.fill(
                child: Column(
                  children: [
                    // HEADER: level name, score, lives hearts, timer
                    _buildHeader(),

                    // CARD GRID: 6 fixed positions (Expanded = all free space)
                    Expanded(child: _buildCardGrid()),

                    // INPUT AREA: text field + "+" button + pause button
                    _buildInputArea(),
                  ],
                ),
              ),

              // GAME OVER OVERLAY (Section 2.6 / 6.4)
              // Appears when lives hit 0. ScaleTransition animates the card
              // from scale 0â†’1 over 500ms with Curves.easeOut so it "pops in"
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

  /// Header bar: level name (gold) above a row of [Score | â¤ï¸ Hearts | Timer].
  /// HEIGHT (REDESIGN.md open question I1, lever 1, and I2):
  ///   Start:  84px — 20px padding, gold level name (17px), 8px gap,
  ///           stat row (37px), 1px border.
  ///   Step 1: 52px — the level name was removed.
  ///   Step 2 (asked by Z3): the level name comes BACK, but everything is
  ///           smaller: name 13 → 11px, gap under the name 8 → 2px, stat
  ///           label 10 → 9px, gap inside the stat block 2 → 1px, stat value
  ///           17 → 15px, outer padding 6 → 5px. About 60px.
  ///
  /// The grid needs 296px and still has more than that, so the name costs
  /// the player nothing.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
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
          // LEVEL NAME in gold (Section 6.2: #FFD700).
          // Smaller than before: 11px with a 2px gap under it.
          Text(
            widget.level.displayLabel, // e.g. "Level 1: Strolling"
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFD700),
              letterSpacing: 1.0,
              height: 1.1, // tight line box, so the name costs little height
            ),
          ),

          const SizedBox(height: 2),

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
  /// [highlightController] â€” optional. When provided the value text briefly
  /// turns gold (Color(0xFFFFD700)) as the controller animates 0â†’1â†’0.
  /// Used on the score block to give a 300ms gold flash on correct guesses
  /// (Section 6.5: "Brief gold highlight on score text, 300ms opacity tween").
  Widget _buildStatBlock({
    required String label,
    required String value,
    required CrossAxisAlignment alignment,
    AnimationController? highlightController,
  }) {
    // Value text color: white normally, lerps to gold while highlight plays.
    //
    // HEIGHT: the value was 17px with a 2px gap under a 10px label.
    // It is now 15px with a 1px gap under a 9px label, and both lines use a
    // tight line box (height: 1.1). This is REDESIGN.md I1, asked by Z3.
    Widget valueText(Color color) => Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
          ),
        );

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.60),
            letterSpacing: 1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 1),
        // Wrap in AnimatedBuilder only when a highlight controller is provided.
        // The TIME stat uses this widget too and has no highlight animation.
        if (highlightController != null)
          AnimatedBuilder(
            animation: highlightController,
            builder: (context, _) {
              // Lerp: white (at controller.value=0) â†’ gold (at 1.0).
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
  /// Example â€” Level 1 (3 lives total), 1 lost: â¤ï¸ ðŸ¤ ðŸ¤
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
  // CARD GRID  (Stage 4.1 — REDESIGN.md S2 and S4)
  // ==========================================================================

  /// Builds the card grid: 2 columns × 3 rows = 6 fixed positions.
  ///
  /// LAYOUT RULES (REDESIGN.md S2):
  ///   - 12px padding left and right, 8px top and bottom.
  ///   - 8px gap between cards.
  ///   - Card height is fixed at kCardHeight (88px).
  ///   - Card width = (screen width − 24 − 8) ÷ 2. This gives 164px on a
  ///     360px screen, which matches the clue measurements in D19.
  ///
  /// WHY A SCROLL VIEW?
  /// Three rows need 3 × 88 + 2 × 8 = 280px. A phone with a logical height
  /// below about 860px has less free height than that when the keyboard is
  /// open. On those phones the grid scrolls (D20).
  ///
  /// The player scrolls with a finger. The grid NEVER scrolls by itself (D23).
  /// Stage 4.5 adds the 2 blinking arrows that show hidden cards (D28).
  ///
  /// POSITIONS (S4):
  /// The 6 positions are numbered 0 to 5 in reading order:
  ///   0 = top-left      1 = top-right
  ///   2 = middle-left   3 = middle-right
  ///   4 = bottom-left   5 = bottom-right
  /// A card holds its position until it is removed. Cards never move (D17).
  ///
  /// STAGE 4.1 shows an empty box in every position, so we can measure the
  /// real layout on a device. Stage 4.2 puts a real card in position 0.
  Widget _buildCardGrid() {
    return SingleChildScrollView(
      // The physics let the player scroll even when all 6 cards fit, which
      // keeps the feel the same on every screen size.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: kGridPaddingH,
        vertical: kGridPaddingV,
      ),
      child: Column(
        children: [
          // 3 rows. Each row holds 2 positions.
          for (int row = 0; row < 3; row++)
            Padding(
              // A gap under every row except the last one.
              padding: EdgeInsets.only(bottom: row < 2 ? kGridGap : 0),
              child: Row(
                children: [
                  Expanded(child: _buildEmptySlot(row * 2)),
                  const SizedBox(width: kGridGap),
                  Expanded(child: _buildEmptySlot(row * 2 + 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds one empty grid position.
  ///
  /// This is a placeholder for Stage 4.1 only. It shows the position number
  /// so we can check the grid order (S4) on a real device. Stage 4.2 replaces
  /// it with the real card widget.
  ///
  /// [index] — the position number, 0 to 5.
  Widget _buildEmptySlot(int index) {
    return Container(
      height: kCardHeight,
      decoration: BoxDecoration(
        // A faint box: visible enough to measure, quiet enough to ignore.
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          '$index',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
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
  /// HEIGHT (REDESIGN.md open question I1, lever 2):
  ///   Step 1 (2026-09-21): 78px → 68px. Padding 12/14 → 8/10, buttons
  ///   52px → 48px, icons 26 → 24, field text 20 → 19, inner padding 14 → 11.
  ///   Step 2 (2026-09-21, asked by Z3): 68px → about 57px. Field text
  ///   19 → 17, hint 15 → 14, inner padding 11 → 7, outer padding 8/10 → 6/8,
  ///   buttons 48px → 42px, icons 24 → 22.
  ///
  /// WARNING: 42px is below the Android guide of 48dp for a touch target.
  /// Test the "+" and Pause buttons on a phone. Raise the value again if they
  /// are hard to hit during play (REDESIGN.md I3).
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                  letterSpacing: 2.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Type the word...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.withValues(alpha: 0.55),
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 7,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // "+" BUTTON — shows one new card at once (REDESIGN.md D14).
          //
          // STAGE 4.1: the button is always disabled, because no cards exist
          // yet. Stage 4.3 connects it, with these rules (S5):
          //   - It works when a grid position is free (H1a).
          //   - It is disabled when the grid is full, or when a card waits.
          //   - After a manual card, the automatic interval starts again
          //     from zero (H1b).
          // It sits next to the Pause button, as H1c requires.
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
              // null onPressed makes Flutter draw the button as disabled.
              onPressed: _canAddCard ? _onAddCardPressed : null,
              icon: Icon(
                Icons.add_rounded,
                color: _canAddCard
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                size: 22,
              ),
              tooltip: 'Add a card now',
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              padding: const EdgeInsets.all(8),
            ),
          ),

          const SizedBox(width: 8),

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
                size: 22,
              ),
              tooltip: 'Pause Game',
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }
}
