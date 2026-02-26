// ============================================================================
// GAME SCREEN
// ============================================================================
// This is the main gameplay screen — where words fall from the sky and the
// player types answers to catch them before they hit the ground.
//
// STAGE 3 (THIS FILE): Spawn timer + multiple simultaneous words.
// Words now spawn automatically at regular intervals (LevelConfig.spawnDelay)
// using Timer.periodic. Multiple words can fall at once. New words are placed
// at x positions that don't overlap with existing ones (20px buffer).
//
// WHAT IS IN THIS STAGE:
//   - Everything from Stages 1 & 2
//   - _startSpawnTimer(): starts a Timer.periodic that fires every spawnDelay ms
//   - _wordsCompleted counter: tracks correct guesses (drives word length progression)
//   - _gameAreaWidth field: set by LayoutBuilder, used for pixel-accurate overlap checks
//   - _spawnWord() overlap prevention: up to 10 retries to find a non-overlapping x
//   - Max 10 simultaneous words cap (per Section 5.2)
//   - Timer? _spawnTimer: stored so it can be cancelled on dispose/pause
//
// PER DOCUMENTATION:
//
// Section 5.1 — Word Drop Mechanics:
//   - Use AnimationController with Curves.linear for constant velocity
//   - Word widgets are Positioned inside a Stack
//   - Fall distance: effective height = game area height - groundOffset - cardHeight
//
// Section 5.3 — Fall Speed Calculations:
//   - Fall duration from LevelConfig.fallTime (e.g. 30000ms for Level 1)
//
// Section 5.4 — Collision Detection:
//   - Use Animation.addStatusListener to detect AnimationStatus.completed
//
// Section 5.5 — Animation Durations:
//   - Fall: Curves.linear, duration = fallTime
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
//   Stage 3 (THIS): Spawn timer + multiple simultaneous words + overlap prevention
//   Stage 4:  Input matching — onChanged checks typed text against words
//   Stage 5:  Lives and scoring — ground hit deducts life, correct guess +5pts
//   Stage 6:  Game Over and Level Complete overlays
//   Stage 7:  Pause overlay — freezes all animations and timers
//
// CHANGELOG:
//   - Stage 1: Initial creation — static layout, three zones
//   - Stage 2: Added FallingWord class, AnimationController-driven fall,
//              LayoutBuilder for game area dimensions, stopwatch timer
//   - Stage 3: Added spawn timer, overlap prevention, _wordsCompleted counter,
//              _gameAreaWidth tracking, max-10-words cap
// ============================================================================

import 'dart:async';  // For Timer (used by the stopwatch display updater)
import 'dart:math';   // For Random (used to randomise word x positions)
import 'package:flutter/material.dart';
import '../managers/game_manager.dart'; // Provides the words to display
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
  /// - Duration  = widget.level.fallTimeDuration (e.g. 30s for Level 1)
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
  /// Stage 5 will decrement this when a word hits the ground.
  late int _lives;

  /// Points scored this level (0–100). Each correct word = +5 points.
  /// Stage 5 will increment this on correct guesses.
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
  /// Incremented in Stage 4 when the player correctly guesses a word.
  // ignore: unused_field
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

  /// The measured width of the game area in pixels.
  ///
  /// Set by LayoutBuilder during build — not via setState (no rebuild needed).
  /// Used in _spawnWord() for pixel-accurate horizontal overlap checks.
  /// 0.0 until the first build completes (overlap check is skipped if 0).
  double _gameAreaWidth = 0.0;

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

  /// Fires every spawnDelay milliseconds to spawn a new falling word.
  /// Level 1: every 5000ms. Level 5: every 3000ms (per Section 5.2).
  /// Stored so it can be cancelled in dispose() and on pause (Stage 7).
  Timer? _spawnTimer;

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

    _lives = widget.level.lives;
    _textController = TextEditingController();
    _inputFocusNode = FocusNode();

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
        // spawning more at the level's spawnDelay interval.
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

    _textController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  // ==========================================================================
  // WORD SPAWNING
  // ==========================================================================

  /// Spawns a single falling word.
  ///
  /// Stage 2: called once at startup.
  /// Stage 3+: called repeatedly by a Timer.periodic at spawnDelay intervals.
  void _spawnWord() {
    // Ask GameManager for the next word.
    // It picks the correct word length based on how many words the player
    // has already completed in this level (words 1–4 = 6 letters, etc.)
    final wordData = GameManager().getNextWord();
    if (wordData == null) return; // Safety: shouldn't happen with 100 words

    // Create this word's AnimationController.
    // vsync: this — ties the controller to this State's ticker (TickerProviderStateMixin).
    // duration: the fall time from the level config (e.g. 30 000ms for Level 1).
    final controller = AnimationController(
      vsync: this,
      duration: widget.level.fallTimeDuration,
    );

    // Horizontal position — with overlap prevention.
    //
    // WHY overlap prevention?
    // Without it, multiple words can land directly on top of each other,
    // making some cards impossible to read. We try up to 10 random positions
    // and keep the one that's far enough from all existing words.
    //
    // HOW it works:
    //   1. Pick a random xFraction (0.10–0.75 range keeps cards off the edges).
    //   2. Convert xFraction → actual pixel x using _gameAreaWidth.
    //   3. Check against every currently-falling word's pixel x.
    //   4. If any existing word is closer than minSeparation, try again.
    //   5. After 10 failed attempts, use whatever we have (better than blocking).
    //
    // minSeparation = approxCardWidth (190px) + 20px buffer = 210px.
    // This ensures cards don't visually overlap.
    //
    // NOTE: _gameAreaWidth is 0.0 until the first LayoutBuilder build.
    // If it's 0, we skip the check and just use the random fraction as-is
    // (this only affects the very first word which spawns before the first
    // LayoutBuilder measurement; subsequent words are all overlap-checked).
    const double approxCardWidth = 190.0;
    const double overlapBuffer = 20.0;
    const double minSeparation = approxCardWidth + overlapBuffer; // 210px

    double xFraction = 0.10 + Random().nextDouble() * 0.65;

    if (_gameAreaWidth > 0) {
      // usableWidth = the range that xFraction maps over in pixels.
      // It's the game area width minus one card width (so the rightmost card
      // doesn't fall off the right edge).
      final double usableWidth =
          (_gameAreaWidth - approxCardWidth).clamp(1.0, double.infinity);

      for (int attempt = 0; attempt < 10; attempt++) {
        final double candidateX = xFraction * usableWidth;

        // Check whether this candidate overlaps any existing word.
        final bool tooClose = _fallingWords.any((existing) {
          final double existingX = existing.xFraction * usableWidth;
          return (existingX - candidateX).abs() < minSeparation;
        });

        if (!tooClose) break; // Good position found — stop trying

        // Too close — pick a new random fraction and try again.
        xFraction = 0.10 + Random().nextDouble() * 0.65;
      }
      // If all 10 attempts overlapped, we just use the last xFraction.
      // This is better than an infinite loop; rare in practice since spacing
      // is impossible only when the screen is packed to the 10-word cap.
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
    // over the fallTimeDuration at constant (linear) speed.
    controller.forward();

    // Start the stopwatch the first time a word is spawned.
    // The timer only starts when gameplay actually begins.
    if (!_stopwatch.isRunning) {
      _startTimer();
    }
  }

  /// Called when a word's fall animation completes (it reached the ground).
  ///
  /// Stage 2: just removes the word from the screen.
  /// Stage 5: will also deduct a life and check for game over.
  void _onWordHitGround(FallingWord word) {
    _removeWord(word);
    // TODO Stage 5: Deduct 1 life (_lives--) and trigger the red pulse animation.
    // TODO Stage 5: If _lives == 0, show the Game Over overlay.
  }

  /// Removes a word from the screen and disposes its AnimationController.
  ///
  /// Called from:
  ///   - _onWordHitGround (word reached the GROUND without being guessed)
  ///   - Stage 4: when the player types the correct answer
  void _removeWord(FallingWord word) {
    // Dispose the controller before removing from the list.
    // (Disposing after removal is also fine, but this order is cleaner.)
    word.controller.dispose();
    setState(() => _fallingWords.remove(word));
  }

  // ==========================================================================
  // SPAWN TIMER (Stage 3)
  // ==========================================================================

  /// Starts the periodic word spawner.
  ///
  /// Spawns the first word immediately (so the player doesn't wait for
  /// the first tick), then spawns additional words at the level's spawn
  /// delay interval (5000ms for Level 1, 3000ms for Level 5 — Section 5.2).
  ///
  /// WHY spawn immediately first?
  /// Timer.periodic waits for one full interval before the first callback.
  /// That means on Level 1 the player would stare at an empty screen for
  /// 5 seconds before the first word appears. Calling _spawnWord() directly
  /// first gives an instant start.
  ///
  /// WHY cap at 10 words?
  /// Section 5.2 states "maximum 10 simultaneous falling words". Beyond 10
  /// the screen becomes unreadable and performance degrades. The timer still
  /// fires but skips spawning if the cap is already reached.
  void _startSpawnTimer() {
    // Spawn the very first word right now (no wait for first timer tick).
    _spawnWord();

    // Then keep spawning at the level's spawnDelay interval.
    _spawnTimer = Timer.periodic(widget.level.spawnDelayDuration, (_) {
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
  /// Stage 7 will pause all controllers, stop the stopwatch, and show
  /// the pause overlay. For now, just show a placeholder snackbar.
  void _onPausePressed() {
    // TODO Stage 7: for (final word in _fallingWords) { word.controller.stop(); }
    // TODO Stage 7: _stopwatch.stop(); _timerUpdateTimer?.cancel();
    // TODO Stage 7: Show the pause overlay widget over the game.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pause overlay — coming in Stage 7!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }

  /// Called on every keystroke in the answer field.
  /// Stage 4 will check the typed text against all falling words.
  void _onInputChanged(String value) {
    // TODO Stage 4: Compare [value] against every word in _fallingWords.
    // On match: call _removeWord(word), show green flash, +5 score, clear field.
  }

  /// Called when the player presses Enter/Go on the keyboard.
  void _onInputSubmitted(String value) {
    // TODO Stage 4: Same match-check logic as _onInputChanged.
    _textController.clear();
    _inputFocusNode.requestFocus();
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
              // SCORE (left)
              Expanded(
                child: _buildStatBlock(
                  label: 'SCORE',
                  value: '$_score / 100',
                  alignment: CrossAxisAlignment.start,
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
  Widget _buildStatBlock({
    required String label,
    required String value,
    required CrossAxisAlignment alignment,
  }) {
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
            // Store the game area width so _spawnWord() can use it for
            // pixel-accurate overlap checks.
            //
            // WHY direct assignment instead of setState?
            // We only need _gameAreaWidth for arithmetic in _spawnWord() —
            // updating it does NOT require a widget rebuild. Using setState here
            // would cause an extra unnecessary rebuild on every frame that the
            // LayoutBuilder re-runs. Direct field assignment is safe because
            // _spawnWord() always reads _gameAreaWidth at call time, so it
            // always gets the latest value without needing a rebuild cycle.
            _gameAreaWidth = constraints.maxWidth;

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

  /// Builds an AnimatedBuilder that smoothly moves a word card from the top
  /// of the game area down to the ground line.
  ///
  /// [word]        — the data and controller for this specific word instance
  /// [constraints] — pixel dimensions of the game area (from LayoutBuilder)
  ///
  /// WHY AnimatedBuilder?
  /// AnimatedBuilder is Flutter's dedicated tool for animation-driven rebuilds.
  /// It rebuilds ONLY the Positioned wrapper on every animation tick — not the
  /// entire screen. The card itself is passed as [child] and is built once,
  /// then reused each frame (since its content never changes during the fall).
  ///
  /// WHY pass the card as [child] and not build it inside [builder]?
  /// Flutter rebuilds everything inside [builder] on every animation frame
  /// (up to 60 times per second). The card's text, style, and decorations
  /// don't change, so building it inside [builder] would be wasteful.
  /// Passing it as [child] means it's built once and reused — more efficient.
  Widget _buildFallingWordWidget(FallingWord word, BoxConstraints constraints) {
    // Estimated card dimensions. We use fixed estimates here rather than
    // measuring the actual card because:
    //   a) We don't know the card size before it's built
    //   b) The estimates are close enough for positioning
    //   c) Stage 3+ can refine this with GlobalKey measurements if needed
    const double approxCardWidth = 190.0;
    const double approxCardHeight = 70.0;

    // The ground line sits 42px from the bottom of the game area.
    // A word "hits the ground" when its bottom edge reaches this line.
    // So the maximum top position for the card is:
    //   areaHeight - groundLineOffset - cardHeight
    const double groundLineOffset = 42.0;
    final double maxY = (constraints.maxHeight - groundLineOffset - approxCardHeight)
        .clamp(0.0, double.infinity); // clamp prevents negative values on tiny screens

    // X position: xFraction scales across the usable width (area minus card width).
    // clamp(0.0, ...) prevents the card from going off the left edge.
    final double xPos = (word.xFraction * (constraints.maxWidth - approxCardWidth))
        .clamp(0.0, constraints.maxWidth - approxCardWidth);

    return AnimatedBuilder(
      animation: word.controller,

      // The card is built ONCE here and passed as [child].
      // [builder] receives it as its second parameter and wraps it in a
      // Positioned widget whose [top] changes every animation tick.
      child: _buildWordCard(word),

      builder: (context, child) {
        // controller.value: 0.0 = just spawned (top of area)
        //                   1.0 = hit the ground line (maxY position)
        final double yPos = word.controller.value * maxY;

        return Positioned(
          left: xPos,
          top: yPos,
          child: child!, // child! = the pre-built card from above
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
