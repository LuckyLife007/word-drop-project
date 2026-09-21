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

import 'dart:async'; // For Timer (used by the stopwatch display updater)
import 'package:flutter/material.dart';
import '../managers/game_manager.dart'; // Provides the words to display
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

/// How long a new card takes to fade and scale in, in milliseconds.
/// The countdown starts when this animation ends (REDESIGN.md D26).
const int kCardEntranceMs = 300;

/// How long the red "failed" flash lasts, in milliseconds.
///
/// The flash happens INSIDE the card time, at the end (D13). So the player can
/// answer for `cardTime - kFailFlashMs`, and the card leaves the screen exactly
/// at `cardTime` (D15).
const int kFailFlashMs = 600;

/// The card turns amber when this many seconds are left (REDESIGN.md D25).
const double kWarningSeconds = 5.0;

// ============================================================================
// TIMED CARD DATA CLASS  (REDESIGN.md S3)
// ============================================================================

/// One word card on the grid.
///
/// Each card carries its own word data, its grid position, and the two
/// AnimationControllers that drive it:
///
///   [entrance] — 0.0 to 1.0 over kCardEntranceMs. Fades and scales the card in.
///   [timer]    — 0.0 to 1.0 over the level's cardTime. Drives the seconds
///                number, the bar, the amber warning and the red flash.
///
/// WHY AN AnimationController FOR THE TIMER?
/// A controller gives us three things a plain Timer does not:
///   1. A value between 0.0 and 1.0 that the widget can read on every frame.
///   2. `stop()` and `forward()`, which pause and resume from the same value
///      (REDESIGN.md D22 and D32).
///   3. One status listener that fires when the card time ends.
class TimedCard {
  /// Unique id for this card instance. Used to find and remove it.
  final String id;

  /// The hidden letter pattern shown on the card, for example "B-N-N-".
  final String hint;

  /// The clue shown under the hint, for example "Yellow curved fruit".
  final String clue;

  /// The full answer, for example "BANANA". Stage 4.4 matches against this.
  final String answer;

  /// Which grid position holds this card, 0 to 5 in reading order
  /// (REDESIGN.md S4). A card keeps its position until it is removed.
  final int gridIndex;

  /// Fades and scales the card in over kCardEntranceMs.
  final AnimationController entrance;

  /// Counts the card time down. Value 0.0 = full time left, 1.0 = time over.
  final AnimationController timer;

  /// True once the player has lost a life for this card.
  /// It stops the red flash from taking a second life on the next frame.
  bool lifeLost = false;

  /// Drives the green "correct" flash, and is null until the player answers.
  ///
  /// 500ms in two halves (REDESIGN.md S3 and S9):
  ///   0.0 to 0.5 — the card grows to 1.05 and turns green.
  ///   0.5 to 1.0 — the card fades out. Then it leaves the grid.
  AnimationController? matchFlash;

  /// True once the player has answered this card correctly.
  /// A matched card cannot fail and cannot match a second time.
  bool get isMatched => matchFlash != null;

  TimedCard({
    required this.id,
    required this.hint,
    required this.clue,
    required this.answer,
    required this.gridIndex,
    required this.entrance,
    required this.timer,
  });

  /// Disposes every controller this card owns.
  /// Call this when the card leaves the screen.
  void dispose() {
    entrance.dispose();
    timer.dispose();
    matchFlash?.dispose();
  }
}

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
  ///
  /// The ignore is temporary: stage 4.4 writes this field again.
  // ignore: prefer_final_fields
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
  /// getNextWord() returns the right word length for the next card.
  ///
  /// The ignores are temporary: stage 4.4 writes and reads this field again.
  // ignore: prefer_final_fields, unused_field
  int _wordsCompleted = 0;

  /// Elapsed time displayed in the header (e.g. "1:42").
  /// Starts at "0:00" and updates every second once the first card appears.
  String _timerDisplay = '0:00';

  // ==========================================================================
  // CARDS  (Stage 4.2 — REDESIGN.md S3, S4)
  // ==========================================================================

  /// Every card on the grid right now. Never more than kMaxCards (D12, D18).
  /// The list order does not matter: each card knows its own gridIndex.
  final List<TimedCard> _cards = [];

  /// Counter used to build a unique id for each card.
  int _cardSerial = 0;

  /// True while one card waits for a free grid position (REDESIGN.md D16).
  ///
  /// The interval stops while a card waits, so only 1 card can wait. The
  /// waiting card appears as soon as a position becomes free, and the
  /// interval then starts again from zero.
  bool _cardWaiting = false;

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

    // STAGE 4.3 — start the level: one card at once, then one every
    // newCardDelay (REDESIGN.md S5, D11).
    //
    // WHY WAIT FOR THE FIRST FRAME AND 400ms?
    // The keyboard opens by itself (autofocus) and it takes about 300ms to
    // slide up. The grid changes height while that happens. We wait so the
    // first card appears on a screen that has stopped moving.
    //
    // Stage 4.6 puts the "3, 2, 1, Go" countdown in front of this (D30).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _startNewCardTimer(spawnNow: true);
      });
    });
  }

  @override
  void dispose() {
    // Cancel the clock timer first to stop any pending setState() calls.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Cancel the new-card timer so no card is created after disposal.
    // Without this, the timer could fire and try to call setState() or create
    // AnimationControllers after the State has been torn down.
    // (Stage 4.3 starts this timer. Stage 4.2 never starts it.)
    _newCardTimer?.cancel();

    // Dispose the 2 controllers of every card still on the grid.
    // A controller that is not disposed keeps a ticker alive and leaks memory.
    for (final card in _cards) {
      card.dispose();
    }
    _cards.clear();

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
  // ==========================================================================
  // CARD ENGINE  (Stage 4.2 — REDESIGN.md S3, S4, S5)
  // ==========================================================================

  /// Returns the free grid position with the lowest number, or null when the
  /// grid is full (REDESIGN.md S4).
  int? _firstFreeIndex() {
    for (int i = 0; i < kMaxCards; i++) {
      final bool taken = _cards.any((c) => c.gridIndex == i);
      if (!taken) return i;
    }
    return null;
  }

  /// Returns the card in a grid position, or null when the position is empty.
  TimedCard? _cardAt(int index) {
    for (final card in _cards) {
      if (card.gridIndex == index) return card;
    }
    return null;
  }

  /// Puts one new card on the grid.
  ///
  /// STEPS:
  ///   1. Stop if the game is over, won or paused, or if the grid is full.
  ///   2. Ask GameManager for the next word. It picks the right word length
  ///      for this position in the level, and it never gives a word that is
  ///      already on the screen.
  ///   3. Build the two controllers and add the card to the grid.
  ///   4. Play the entrance, then start the countdown (D26).
  ///
  /// Stage 4.3 calls this from the automatic interval and from the "+" button.
  void _spawnCard() {
    if (_isGameOver || _isLevelComplete || _isPaused) return;

    final int? slot = _firstFreeIndex();
    if (slot == null) return; // grid full — D16 makes the next card wait

    // The answers already on the screen, so the same word cannot appear twice.
    final List<String> activeWords = _cards.map((c) => c.answer).toList();

    final WordWithCombination? next = GameManager().getNextWord(
      activeWords: activeWords,
    );
    if (next == null) return; // word bank empty — should never happen

    final entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kCardEntranceMs),
    );

    final timer = AnimationController(
      vsync: this,
      duration: widget.level.cardTimeDuration,
    );

    final card = TimedCard(
      id: 'card_${_cardSerial++}',
      hint: next.hint,
      clue: next.clue,
      answer: next.word.word,
      gridIndex: slot,
      entrance: entrance,
      timer: timer,
    );

    // WATCH THE COUNTDOWN.
    // The listener runs on every frame while the timer moves. It only acts at
    // the moment the red flash begins: the player loses 1 life there (D15).
    timer.addListener(() {
      // A matched card is already leaving, so it must never fail (S6).
      if (!mounted || card.lifeLost || card.isMatched) return;
      if (_remainingMs(card) <= kFailFlashMs) {
        _onCardFailed(card);
      }
    });

    // WATCH THE END.
    // The card leaves the screen exactly at cardTime (D15).
    timer.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _removeCard(card);
      }
    });

    setState(() => _cards.add(card));

    // Start the clock on the first card of the level.
    if (!_stopwatch.isRunning) _startTimer();

    // The countdown starts only when the card is fully visible (D26).
    entrance.forward().whenComplete(() {
      if (mounted && !_isPaused && !_isGameOver && !_isLevelComplete) {
        timer.forward();
      }
    });
  }

  /// Milliseconds left on a card's countdown.
  ///
  /// The controller value runs 0.0 to 1.0 over the level's card time, so the
  /// time left is `cardTime × (1 − value)`.
  int _remainingMs(TimedCard card) {
    final int total = widget.level.cardTime;
    return (total * (1.0 - card.timer.value)).round();
  }

  /// Called once per card, at the moment its red flash starts (D15).
  ///
  /// The player loses 1 life here, not when the card disappears. The card
  /// then shows red for the last 600ms and cannot be answered any more.
  void _onCardFailed(TimedCard card) {
    if (card.lifeLost) return;
    card.lifeLost = true;

    setState(() {
      if (_lives > 0) _lives--;
    });

    if (_lives <= 0) _handleGameOver();
  }

  /// Removes a card from the grid and frees its position.
  ///
  /// If a card was waiting for a free position (D16), it appears here at once,
  /// and the automatic interval starts again from zero.
  void _removeCard(TimedCard card) {
    setState(() => _cards.remove(card));
    card.dispose();

    if (_cardWaiting && !_isPaused && !_isGameOver && !_isLevelComplete) {
      _cardWaiting = false;
      _spawnCard();
      // Same rule as the "+" button (H1b): after an out-of-order card, the
      // interval counts again from zero.
      _startNewCardTimer();
    }
  }

  // ==========================================================================
  // NEW-CARD INTERVAL  (Stage 4.3 — REDESIGN.md S5, D14, D16)
  // ==========================================================================

  /// Starts (or restarts) the automatic new-card interval.
  ///
  /// [spawnNow] puts one card on the grid before the first tick. The level
  /// start uses it, so the player does not wait a full interval for the first
  /// card. Every other caller leaves it false.
  ///
  /// The old timer is always cancelled first, so the interval counts from zero
  /// every time. That is what D14/H1b and D16 require after a manual card or
  /// after a waiting card appears.
  void _startNewCardTimer({bool spawnNow = false}) {
    _newCardTimer?.cancel();

    if (spawnNow) _spawnCard();

    _newCardTimer = Timer.periodic(widget.level.newCardDelayDuration, (_) {
      if (!mounted) return;

      // The interval does nothing while the game is not running.
      if (_isPaused || _isGameOver || _isLevelComplete) return;

      // FULL GRID (D16): the next card waits instead of being lost.
      // The interval stops here, so only 1 card can ever wait.
      if (_firstFreeIndex() == null) {
        setState(() => _cardWaiting = true);
        _newCardTimer?.cancel();
        _newCardTimer = null;
        return;
      }

      _spawnCard();
    });
  }

  /// Stops the countdown of every card, and the entrance animations too.
  /// Used by pause, game over and level complete (REDESIGN.md D22, D32).
  void _freezeAllCards() {
    for (final card in _cards) {
      card.timer.stop();
      card.entrance.stop();
    }
  }

  /// Starts every card's countdown again from the same value (D22).
  ///
  /// A card that was still in its entrance animation finishes the entrance
  /// first, and only then starts its countdown, exactly as D26 requires.
  void _resumeAllCards() {
    for (final card in _cards) {
      if (card.entrance.isCompleted) {
        card.timer.forward();
      } else {
        final TimedCard c = card;
        c.entrance.forward().whenComplete(() {
          if (mounted && !_isPaused && !_isGameOver && !_isLevelComplete) {
            c.timer.forward();
          }
        });
      }
    }
  }

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

    // Freeze every card behind the overlay (REDESIGN.md D22).
    _freezeAllCards();

    // Close the keyboard.
    //
    // The keyboard stays open for the whole game (D21), but the game has ended
    // here, so the player cannot type any more. The overlay also needs the
    // full screen height: with the keyboard open it overflowed by 73px on the
    // test phone, and the lower buttons were cut off.
    _inputFocusNode.unfocus();

    // Rebuild to show the overlay (which is gated on _isGameOver in build()),
    // then animate the card from scale 0→1 over 500ms (Section 6.4).
    if (mounted) {
      setState(
        () {},
      ); // _isGameOver already true — this makes the overlay appear
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

    // Freeze every card behind the overlay (REDESIGN.md D22).
    _freezeAllCards();

    // Close the keyboard, for the same reason as in _handleGameOver():
    // the level is won, so the player cannot type, and the overlay needs the
    // full screen height.
    _inputFocusNode.unfocus();

    // Capture best-time info BEFORE saving so we know if this run set a
    // new record. ProgressManager.saveBestTime() updates _bestTimes in memory
    // synchronously, so checking after the call would always look like a tie.
    final int elapsedMs = _stopwatch.elapsed.inMilliseconds;
    final int? previousBest = ProgressManager().getBestTime(
      widget.level.levelNumber,
    );

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
      final int seconds =
          elapsed.inSeconds % 60; // remainder after full minutes

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

    // Stop the new-card timer so no card appears while paused.
    _newCardTimer?.cancel();
    _newCardTimer = null;

    // Freeze the stopwatch — elapsed time must be preserved across pause/resume.
    // Dart's Stopwatch.stop() does NOT reset the elapsed value; it just stops
    // accumulating time. Calling start() later resumes from the same point.
    _timerUpdateTimer?.cancel();
    _stopwatch.stop();

    // Freeze every card. A pause costs the player nothing (D22, D32).
    _freezeAllCards();

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

    // Start every card's countdown again, from the same value (D22).
    _resumeAllCards();
    // STAGE 4.6 will add: run the "3, 2, 1, Go" countdown BEFORE the timers
    // start again. This happens at every resume (REDESIGN.md D30).

    // Restart the clock from where it stopped.
    // Dart's Stopwatch.start() on a stopped (not reset) watch resumes from
    // the existing elapsed time — so the display updates continuously.
    // _startTimer() also creates a fresh Timer.periodic for the display update
    // (the old one was cancelled by _onPausePressed).
    _startTimer();

    // A card that was waiting during the pause (D16) appears now, because a
    // position may have become free before the pause.
    if (_cardWaiting && _firstFreeIndex() != null) {
      _cardWaiting = false;
      _spawnCard();
    }

    // Start the new-card interval again, counting from zero, and WITHOUT an
    // extra card: the cards from before the pause are still on the grid.
    _startNewCardTimer();

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

  /// Called on every keystroke in the answer field (REDESIGN.md S6).
  ///
  /// RULES:
  ///   - The check starts at 6 characters, because the shortest word in the
  ///     word bank has 6 letters.
  ///   - A match needs the FULL word. Case and outside spaces do not matter.
  ///   - The cards are checked in grid order, and the first match wins. The
  ///     same word is never on the grid twice, so only one card can match.
  ///   - A card in the Failed (red) or Matched (green) state is skipped.
  ///   - A wrong word gives no feedback and no penalty (D10/E2, D27).
  void _onInputChanged(String value) {
    // No matching after game over, level complete, or while paused.
    if (_isGameOver || _isLevelComplete || _isPaused) return;

    // Normalise: uppercase and remove outside spaces. The field already forces
    // uppercase, but we normalise again so the comparison is reliable.
    final String typed = value.toUpperCase().trim();

    // The shortest word has 6 letters, so shorter input cannot match.
    if (typed.length < 6) return;

    // Check the positions in grid order: 0, 1, 2, 3, 4, 5 (S6).
    for (int i = 0; i < kMaxCards; i++) {
      final TimedCard? card = _cardAt(i);
      if (card == null) continue;

      // A red card cannot be answered (D15), and a green card is already won.
      if (card.lifeLost || card.isMatched) continue;

      if (card.answer == typed) {
        _onCardMatched(card);
        return; // only one card can match
      }
    }
  }

  /// Handles a correct answer (REDESIGN.md S7).
  ///
  /// STEPS:
  ///   1. Stop the card's countdown, so it cannot fail during the flash.
  ///   2. Add 5 points, count the word, and tell GameManager, so the next
  ///      card uses the right word length.
  ///   3. Flash the score gold for 300ms.
  ///   4. Clear the field and keep the keyboard, so the player types on.
  ///   5. Play the 500ms green flash, then remove the card.
  ///   6. At 20 correct words the level is complete.
  void _onCardMatched(TimedCard card) {
    // 1. The card is won: freeze its countdown.
    card.timer.stop();

    // 2. Score and counters.
    // The score is capped at 100. Two matches in the same frame near the end
    // of a level would otherwise show "105 / 100".
    setState(() {
      _score = (_score + 5).clamp(0, 100);
      _wordsCompleted++;
    });
    GameManager().recordCorrectWord();

    // 3. Gold highlight on the score (Section 6.5, 300ms).
    _scoreHighlightController.reset();
    _scoreHighlightController.forward().then((_) {
      if (mounted) _scoreHighlightController.reverse();
    });

    // 4. Clear the field for the next word. The keyboard stays open (D21).
    _textController.clear();
    _inputFocusNode.requestFocus();

    // 5. The green flash. One controller per card, so two cards can flash at
    //    the same time if the player answers quickly.
    final flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    card.matchFlash = flash;

    flash.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _removeCard(card);
      }
    });

    setState(() {}); // show the flash on the next frame
    flash.forward();

    // 6. 20 correct words = 100 points = level complete (D8).
    if (_wordsCompleted >= 20) _handleLevelComplete();
  }

  /// Whether the "+" button can add a card right now (REDESIGN.md D14/H1a).
  ///
  /// It is false when:
  ///   - the game is paused, over or won;
  ///   - the grid is full;
  ///   - a card is already waiting for a free position (D16), because "+"
  ///     must never go before that card.
  bool get _canAddCard =>
      !_isPaused &&
      !_isGameOver &&
      !_isLevelComplete &&
      !_cardWaiting &&
      _firstFreeIndex() != null;

  /// Called when the player taps the "+" button (REDESIGN.md D14).
  ///
  /// It shows one card at once, and the automatic interval then counts again
  /// from zero (H1b). The player uses this to remove idle waiting on the slow
  /// levels, and a faster best time earned this way is valid (H1e).
  void _onAddCardPressed() {
    if (!_canAddCard) return;
    _spawnCard();
    _startNewCardTimer();
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
    final int totalSeconds =
        ms ~/ 1000; // integer division — drops sub-seconds
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
      // The overlay scrolls if the screen is short (for example while the
      // keyboard is still sliding away). Without this the card overflows.
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
      // The overlay scrolls if the screen is short (for example while the
      // keyboard is still sliding away). Without this the card overflows.
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                        isLastLevel
                            ? Icons.emoji_events_rounded
                            : Icons.check_circle_rounded,
                        color: const Color(
                          0xFFFFD700,
                        ), // Gold (#FFD700 per Section 1.4)
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
                      _buildOverlayStatRow(
                        'Time',
                        _formatTime(_completionTimeMs),
                      ),
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
                            ProgressManager().getBestTime(
                                  widget.level.levelNumber,
                                ) ??
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
      // The overlay scrolls if the screen is short (for example while the
      // keyboard is still sliding away). Without this the card overflows.
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                        color: Color(
                          0xFF764ba2,
                        ), // Deep purple (app accent colour)
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
                      _buildOverlayButton('End Game', onPressed: _onEndGame),
                    ],
                  ),
                ),
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
          style: TextStyle(fontSize: 15.0, color: Color(0xFF888888)),
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
              child: Text(label, style: const TextStyle(fontSize: 15.0)),
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
              // ALL GAME CONTENT — fills the full SafeArea via Positioned.fill.
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
              // from scale 0→1 over 500ms with Curves.easeOut so it "pops in"
              // from the centre. Semi-transparent backdrop dims the game below.
              if (_isGameOver) Positioned.fill(child: _buildGameOverOverlay()),

              // LEVEL COMPLETE OVERLAY (Section 2.6 / 6.4)
              // Appears when the player correctly guesses all 20 words.
              // Same entry animation as the Game Over overlay.
              if (_isLevelComplete)
                Positioned.fill(child: _buildLevelCompleteOverlay()),

              // PAUSE OVERLAY (Section 6.6)
              // Appears when the player taps the Pause button mid-game.
              // All falling word animations and timers are frozen while shown.
              // "Resume Game" restores the game; "End Game" exits without saving.
              if (_isPaused) Positioned.fill(child: _buildPauseOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  /// Header bar: level name (gold) above a row of [Score | hearts | Timer].
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
              Expanded(flex: 2, child: Center(child: _buildLivesHearts())),

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
  /// Example — Level 1 (3 lives total), 1 lost: 2 red hearts, 1 empty heart
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
                ? const Color(0xFFFF4444) // Bright red
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
                  Expanded(child: _buildGridPosition(row * 2)),
                  const SizedBox(width: kGridGap),
                  Expanded(child: _buildGridPosition(row * 2 + 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds one grid position: the card in it, or an empty box.
  ///
  /// [index] — the position number, 0 to 5.
  Widget _buildGridPosition(int index) {
    final TimedCard? card = _cardAt(index);
    if (card == null) return _buildEmptySlot();
    return _buildTimedCard(card);
  }

  /// Builds an empty grid position: a faint box that holds the space open.
  ///
  /// The empty box keeps the grid steady. A position that a card left stays
  /// where it is, and the other cards never move (REDESIGN.md D17).
  Widget _buildEmptySlot() {
    return Container(
      height: kCardHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
    );
  }

  // ==========================================================================
  // THE WORD CARD  (Stage 4.2 — REDESIGN.md S3)
  // ==========================================================================

  /// Builds one word card with its live countdown.
  ///
  /// WHAT THE PLAYER SEES (S3):
  ///   - Top row: the hint pattern on the left, the seconds number on the right.
  ///   - Middle: the clue, italic, up to 3 lines.
  ///   - Bottom edge: a 4px bar that gets shorter as the time runs out.
  ///
  /// COLOURS:
  ///   - Normal: the brand blue-purple #667eea.
  ///   - Last 5.0 seconds: amber #FFA000 (D25).
  ///   - Last 0.6 seconds: red. The card body turns red too, the number shows
  ///     0, and the player has already lost the life (D15).
  ///
  /// WHY AnimatedBuilder?
  /// It rebuilds only this card on every animation frame. The rest of the
  /// screen, including the other cards, is left alone.
  Widget _buildTimedCard(TimedCard card) {
    return AnimatedBuilder(
      // Listen to every controller this card owns: the entrance, the
      // countdown, and the green flash when the player has answered.
      animation: Listenable.merge([
        card.entrance,
        card.timer,
        if (card.matchFlash != null) card.matchFlash!,
      ]),
      builder: (context, _) {
        final int remainingMs = _remainingMs(card);
        final bool isMatched = card.isMatched;
        final bool isFailed = !isMatched && remainingMs <= kFailFlashMs;
        final bool isWarning =
            !isFailed && !isMatched && remainingMs <= (kWarningSeconds * 1000);

        // The seconds number. It never shows a negative value, and it shows 0
        // during the red flash (S11 point 4).
        final int secondsLeft = isFailed
            ? 0
            : ((remainingMs - kFailFlashMs) / 1000).ceil().clamp(0, 9999);

        // The timer colour follows the state.
        final Color timerColor = isFailed
            ? const Color(0xFFD32F2F) // red
            : isWarning
            ? const Color(0xFFFFA000) // amber
            : const Color(0xFF667eea); // brand blue-purple

        // GREEN FLASH (S3, 500ms in two halves):
        //   first half  — the card grows to 1.05 and the green fades in
        //   second half — the card fades out, then it leaves the grid
        final double flashValue = card.matchFlash?.value ?? 0.0;
        final double greenAmount = isMatched
            ? (flashValue / 0.5).clamp(0.0, 1.0)
            : 0.0;
        final double matchFade = isMatched && flashValue > 0.5
            ? 1.0 - ((flashValue - 0.5) / 0.5)
            : 1.0;
        final double matchScale = isMatched ? 1.0 + (0.05 * greenAmount) : 1.0;

        // The card body: green when answered, red during a failure, white
        // otherwise. A player who is looking at another card still sees it.
        final Color cardColor = isMatched
            ? Color.lerp(
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFC8E6C9), // light green
                greenAmount,
              )!
            : isFailed
            ? const Color(0xFFFFCDD2) // light red
            : Colors.white.withValues(alpha: 0.95);

        // How much of the bar is left, 1.0 at the start and 0.0 at the end.
        final double barFraction = (1.0 - card.timer.value).clamp(0.0, 1.0);

        // ENTRANCE: fade 0→1 and scale 0.95→1.0 over kCardEntranceMs (D26).
        final double entranceValue = card.entrance.value;

        return Opacity(
          opacity: entranceValue * matchFade,
          child: Transform.scale(
            scale: (0.95 + (0.05 * entranceValue)) * matchScale,
            child: Container(
              height: kCardHeight,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMatched
                      ? const Color(0xFF4CAF50) // green (success colour)
                      : isFailed
                      ? const Color(0xFFD32F2F) // red
                      : Colors.white.withValues(alpha: 0.35),
                  width: (isMatched || isFailed) ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // clipBehavior keeps the timer bar inside the rounded corners.
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---- HINT + SECONDS ----
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  card.hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5,
                                    color: Color(0xFF333333),
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$secondsLeft',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: timerColor,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 3),

                          // ---- CLUE ----
                          Expanded(
                            child: Text(
                              card.clue,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---- TIMER BAR (bottom edge) ----
                  SizedBox(
                    height: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: barFraction,
                        child: Container(color: timerColor),
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
