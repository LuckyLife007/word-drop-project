// ============================================================================
// LEVEL SELECTION SCREEN
// ============================================================================
// This screen shows all 5 levels as a scrollable list of cards.
// The player can see which levels are locked, available, or completed,
// and tap an unlocked level to start playing.
//
// PER DOCUMENTATION:
//
// Section 2.2 - Layout:
//   - Vertical list of level cards
//   - Each card: level number + name, lock/unlock/checkmark icon, best time
//   - Three visual states: Locked (grey), Available (coloured, pulsing), Completed (colour + checkmark)
//   - Back button to return to Main Menu
//
// Section 4.6 - Unlock logic:
//   - Only Level 1 unlocked at start
//   - Progress persists across sessions
//
// Section 6.1 - Layout details:
//   - ListView of Card widgets with elevation
//
// Section 6.4 - Transitions:
//   - FadeTransition (300ms) used when navigating here from Main Menu
// ============================================================================

import 'package:flutter/material.dart';
import '../managers/progress_manager.dart';
import '../models/level_config.dart';

// ============================================================================
// LEVEL SELECTION SCREEN WIDGET
// ============================================================================

/// Screen showing all 5 levels for the player to choose from.
///
/// WHY StatefulWidget?
/// This screen needs to:
///   1. Load progress from storage when it opens (async operation)
///   2. Run a continuous pulsing animation on the "available" level card
///   3. Potentially refresh after returning from a game session
/// All of these require state management.
class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

/// State for LevelSelectionScreen.
///
/// We use TWO animation mixins here:
///   - TickerProviderStateMixin (note: not Single-) because we need TWO
///     AnimationControllers: one for the entrance animation, one for the
///     continuous pulse on the available level card.
///
/// WHY TickerProviderStateMixin instead of SingleTickerProviderStateMixin?
/// SingleTicker only supports ONE AnimationController at a time.
/// We need two simultaneous animations, so we use the multi-ticker version.
class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with TickerProviderStateMixin {

  // ==========================================================================
  // ANIMATION CONTROLLERS
  // ==========================================================================

  /// Controls the screen entrance animation (content fades in when screen opens)
  late AnimationController _entranceController;
  late Animation<double> _entranceFadeAnimation;

  /// Controls the pulsing glow/scale effect on the currently available level.
  /// This animation loops forever (repeats back and forth).
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ==========================================================================
  // STATE
  // ==========================================================================

  /// Whether we've finished loading progress from storage.
  /// We show a loading indicator until this is true.
  bool _progressLoaded = false;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    // --- Entrance animation: content fades in when screen opens ---
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entranceFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    // --- Pulse animation: the "available" level card gently pulses ---
    // Duration of 900ms per pulse cycle looks natural and not distracting
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // The pulse animates a scale value between 1.0 (normal) and 1.03 (slightly enlarged)
    // This creates a subtle "breathing" effect
    _pulseAnimation = Tween<double>(
      begin: 1.0,  // Normal size
      end: 1.03,   // Slightly enlarged (3% bigger)
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // repeat(reverse: true) means: grow to 1.03, then shrink back to 1.0, then repeat
    // This creates a smooth in-out pulsing effect
    _pulseController.repeat(reverse: true);

    // Load saved progress, then start the entrance animation
    _loadProgress();
  }

  /// Loads saved progress and triggers the entrance animation when done.
  Future<void> _loadProgress() async {
    await ProgressManager().loadProgress();

    // Only update the UI if this widget is still on screen
    if (mounted) {
      setState(() {
        _progressLoaded = true;
      });
      // Start the fade-in entrance animation
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    // Always dispose AnimationControllers to avoid memory leaks
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  /// Called when the player taps an unlocked level card.
  /// [level] - The level configuration for the tapped card.
  void _onLevelTapped(LevelConfig level) {
    // TODO: Navigate to GameScreen(level: level) once it's built.
    // For now, show a snackbar confirming the tap works.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${level.displayLabel}... (Game screen coming soon!)'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4CAF50), // Green = positive action
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      body: Container(
        // Same sky gradient used throughout the app (Section 6.2)
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

              // ==============================================================
              // HEADER: Back button + title
              // ==============================================================
              _buildHeader(),

              // ==============================================================
              // LEVEL LIST (or loading indicator)
              // ==============================================================
              Expanded(
                child: _progressLoaded
                    ? _buildLevelList()      // Show levels once loaded
                    : _buildLoadingState(),  // Show spinner while loading
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  /// Builds the header bar with a back button and "Select Level" title.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          // Back button - returns to the Main Menu
          // Using IconButton gives a proper touch target (48dp minimum, per docs Section 6.1)
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            // Navigator.pop() removes this screen and returns to the previous one
            // This is the correct way to go "back" in Flutter navigation
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back to Main Menu', // Accessibility label
          ),

          // Expanded pushes the title to fill the remaining width
          const Expanded(
            child: Text(
              'Select Level',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Empty SizedBox to balance the Row (keeps title centred)
          // Without this, the title would be off-centre because the back button
          // takes up space on the left but nothing balances it on the right.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOADING STATE
  // ==========================================================================

  /// Shows a spinner while progress is being loaded from storage.
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 3,
      ),
    );
  }

  // ==========================================================================
  // LEVEL LIST
  // ==========================================================================

  /// Builds the scrollable list of 5 level cards.
  Widget _buildLevelList() {
    return FadeTransition(
      opacity: _entranceFadeAnimation,

      // ListView.builder efficiently builds only the cards currently on screen.
      // For 5 items this doesn't matter much, but it's good practice.
      child: ListView.builder(
        // Padding around the list so cards don't touch screen edges
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),

        itemCount: kAllLevels.length, // 5 levels

        itemBuilder: (context, index) {
          final LevelConfig level = kAllLevels[index];

          // Determine this card's state based on saved progress
          final bool isCompleted = ProgressManager().isLevelCompleted(level.levelNumber);
          final bool isUnlocked = ProgressManager().isLevelUnlocked(level.levelNumber);

          // The "available" level is the lowest unlocked but not yet completed level.
          // This is the one that gets the pulsing highlight.
          // A level is "available" (highlighted) if it's unlocked but not yet completed.
          // Exception: completed levels are also playable, just not pulsing.
          final bool isAvailable = isUnlocked && !isCompleted;

          return Padding(
            // Space between cards
            padding: const EdgeInsets.only(bottom: 14.0),
            child: _buildLevelCard(
              level: level,
              isUnlocked: isUnlocked,
              isCompleted: isCompleted,
              isAvailable: isAvailable,
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // LEVEL CARD
  // ==========================================================================

  /// Builds a single level card with the appropriate visual state.
  ///
  /// Three states (per Section 2.2):
  ///   - LOCKED:    Grey, lock icon, non-tappable
  ///   - AVAILABLE: Full colour, pulsing, unlock/play icon, tappable
  ///   - COMPLETED: Full colour, checkmark icon, best time shown, tappable
  ///
  /// [level]       - The level data to display
  /// [isUnlocked]  - Whether this level can be played
  /// [isCompleted] - Whether this level has been beaten at least once
  /// [isAvailable] - Whether this is the "current target" level (pulsing highlight)
  Widget _buildLevelCard({
    required LevelConfig level,
    required bool isUnlocked,
    required bool isCompleted,
    required bool isAvailable,
  }) {
    // -------------------------------------------------------------------------
    // Determine visual properties based on card state
    // -------------------------------------------------------------------------

    // Card background colour
    // - Locked: semi-transparent dark (greyed out)
    // - Available: semi-transparent white (bright, stands out)
    // - Completed: semi-transparent white (slightly less bright than available)
    final Color cardColor = !isUnlocked
        ? Colors.black.withValues(alpha: 0.25)        // Locked: dark grey
        : isAvailable
            ? Colors.white.withValues(alpha: 0.92)    // Available: near-white
            : Colors.white.withValues(alpha: 0.75);   // Completed: slightly muted

    // Icon shown on the right side of the card
    final IconData statusIcon = !isUnlocked
        ? Icons.lock_rounded              // Locked: padlock
        : isCompleted
            ? Icons.check_circle_rounded  // Completed: green checkmark
            : Icons.play_circle_rounded;  // Available: play button

    // Icon colour
    final Color iconColor = !isUnlocked
        ? Colors.white.withValues(alpha: 0.4)  // Locked: faded white
        : isCompleted
            ? const Color(0xFF4CAF50)           // Completed: green (success colour from docs)
            : const Color(0xFF667eea);          // Available: our brand blue-purple

    // Level name text colour
    final Color textColor = !isUnlocked
        ? Colors.white.withValues(alpha: 0.5)  // Locked: faded
        : const Color(0xFF333333);             // Unlocked: dark (Section 6.2: "#333 text")

    // Border styling - available level gets a coloured glow border
    final BoxBorder? cardBorder = isAvailable
        ? Border.all(color: const Color(0xFF667eea), width: 2.5)
        : null;

    // -------------------------------------------------------------------------
    // Build the card widget
    // -------------------------------------------------------------------------

    // If this is the available (pulsing) level, wrap it in a ScaleTransition
    // to create the pulsing effect. Otherwise, just return the card as-is.
    Widget card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
        // Glow effect for the available level using a box shadow
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),

      // -----------------------------------------------------------------------
      // Card content (InkWell gives tap feedback on unlocked cards)
      // -----------------------------------------------------------------------
      child: Material(
        color: Colors.transparent, // Don't paint over our container colour
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          // Only respond to taps if the level is unlocked
          onTap: isUnlocked ? () => _onLevelTapped(level) : null,

          // Rounded corners for the tap ripple effect to match the card shape
          borderRadius: BorderRadius.circular(16),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),

            child: Row(
              children: [

                // --------------------------------------------------------------
                // LEVEL NUMBER BADGE (left side)
                // --------------------------------------------------------------
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    // Locked levels get a grey badge; unlocked get a coloured one
                    color: !isUnlocked
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFF667eea).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${level.levelNumber}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: !isUnlocked
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF667eea),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // --------------------------------------------------------------
                // LEVEL NAME + DETAILS (centre, expands to fill space)
                // --------------------------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Level label: "Level 1: Strolling"
                      Text(
                        level.displayLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Subtitle row: shows best time, or a status message
                      _buildCardSubtitle(
                        level: level,
                        isUnlocked: isUnlocked,
                        isCompleted: isCompleted,
                        isAvailable: isAvailable,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // --------------------------------------------------------------
                // STATUS ICON (right side: lock / play / checkmark)
                // --------------------------------------------------------------
                Icon(statusIcon, color: iconColor, size: 32),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap the available (current target) card in ScaleTransition for the pulse
    if (isAvailable) {
      card = ScaleTransition(
        scale: _pulseAnimation,
        child: card,
      );
    }

    return card;
  }

  // ==========================================================================
  // CARD SUBTITLE
  // ==========================================================================

  /// Builds the subtitle line shown below the level name.
  ///
  /// Shows different content depending on the card's state:
  ///   - Locked:    "Complete the previous level to unlock"
  ///   - Available: "Tap to play! • X lives • Words fall in Ys"
  ///   - Completed: "Best: M:SS  •  Tap to replay"
  Widget _buildCardSubtitle({
    required LevelConfig level,
    required bool isUnlocked,
    required bool isCompleted,
    required bool isAvailable,
    required Color textColor,
  }) {
    // Subtitle text colour is always slightly lighter than the main label
    final Color subtitleColor = textColor.withValues(
      alpha: isUnlocked ? 0.65 : 0.45,
    );

    if (!isUnlocked) {
      // LOCKED state
      return Text(
        'Complete the previous level to unlock',
        style: TextStyle(fontSize: 12, color: subtitleColor),
      );
    }

    if (isCompleted) {
      // COMPLETED state - show best time
      final String? bestTime = ProgressManager().getFormattedBestTime(level.levelNumber);
      return Text(
        bestTime != null ? 'Best: $bestTime  •  Tap to replay' : 'Tap to replay',
        style: TextStyle(fontSize: 12, color: subtitleColor),
      );
    }

    // AVAILABLE state - show quick summary of level challenge
    // fallTime is in milliseconds; dividing by 1000 gives seconds
    final int fallSeconds = level.fallTime ~/ 1000;
    return Text(
      'Tap to play!  •  ${level.lives} lives  •  ${fallSeconds}s per word',
      style: TextStyle(fontSize: 12, color: subtitleColor),
    );
  }
}