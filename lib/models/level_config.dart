// ============================================================================
// LEVEL CONFIG MODEL
// ============================================================================
// This file defines the LevelConfig class, which holds all the settings for
// a single difficulty level, and the master list of all 5 levels in the game.
//
// WHY A SEPARATE FILE?
// Both the Level Selection screen (to display level info) and the Game screen
// (to know how long a card lives, etc.) need this data.
// By defining it once here, we avoid duplicating it in multiple places.
// This follows the DRY principle: "Don't Repeat Yourself."
//
// SOURCE: The values come from documentation Section 4.1. The FIELD NAMES come
// from REDESIGN.md, decision D11 and section S10.
//
// REDESIGN NOTE (2026-09-20, Plan step 3):
// The game no longer drops words from the sky. Each word now sits on a card
// with its own countdown (REDESIGN.md, D1). Two fields were renamed so the
// names describe what they really control. THE VALUES DID NOT CHANGE (D11):
//
//   OLD NAME              NEW NAME               MEANING NOW
//   fallTime          ->  cardTime               how long a card stays before it fails
//   spawnDelay        ->  newCardDelay           how long until the next card appears
//   fallTimeDuration  ->  cardTimeDuration       the same value as a Duration
//   spawnDelayDuration -> newCardDelayDuration   the same value as a Duration
// ============================================================================

/// Holds all configuration data for one difficulty level.
///
/// Think of this as a "settings card" for each level. When the game screen
/// needs to know how long a word card lives, how often a new card appears, or
/// how many lives to give the player, it reads from this object.
class LevelConfig {
  // ==========================================================================
  // PROPERTIES
  // ==========================================================================

  /// The level number (1 through 5)
  /// Used to identify the level and determine unlock order.
  final int levelNumber;

  /// The display name of the level (e.g. "Strolling", "Jogging")
  /// Shown on the Level Selection screen and in-game header.
  final String name;

  /// How many milliseconds pass between one new card and the next.
  /// Lower = cards arrive faster = harder.
  /// Example: 5000 means a new card appears every 5 seconds.
  ///
  /// The interval only runs while the game runs. It stops during a pause, and
  /// it stops while a card waits for a free grid position.
  /// Source: REDESIGN.md D11, D16 and section S5. Was `spawnDelay`.
  final int newCardDelay;

  /// How many milliseconds a card stays on the screen before it fails.
  /// Lower = less time to answer = harder.
  /// Example: 30000 means the player has 30 seconds for that card.
  ///
  /// IMPORTANT DETAIL (REDESIGN.md D15): the player can answer for
  /// cardTime - 600ms. The last 600ms are the red "failed" flash, and the
  /// player loses the life when that flash starts.
  /// Source: REDESIGN.md D11, D13, D15 and section S3. Was `fallTime`.
  final int cardTime;

  /// How many lives the player starts with on this level.
  /// Higher levels give more lives to compensate for increased difficulty.
  /// A card that reaches zero removes 1 life (REDESIGN.md D6).
  /// Source: Documentation Section 4.4 and REDESIGN.md D10/B6.
  final int lives;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================

  /// Creates a LevelConfig. All fields are required.
  const LevelConfig({
    required this.levelNumber,
    required this.name,
    required this.newCardDelay,
    required this.cardTime,
    required this.lives,
  });

  // ==========================================================================
  // CONVENIENCE GETTERS
  // ==========================================================================

  /// Returns the full display label shown on the level card.
  /// Example: "Level 1: Strolling"
  String get displayLabel => 'Level $levelNumber: $name';

  /// Returns newCardDelay as a Duration object (easier to use with Flutter timers)
  Duration get newCardDelayDuration => Duration(milliseconds: newCardDelay);

  /// Returns cardTime as a Duration object (easier to use with AnimationController)
  Duration get cardTimeDuration => Duration(milliseconds: cardTime);

  /// String representation for debugging
  @override
  String toString() {
    return 'LevelConfig(level: $levelNumber, name: $name, '
        'newCardDelay: ${newCardDelay}ms, cardTime: ${cardTime}ms, '
        'lives: $lives)';
  }
}

// ============================================================================
// ALL LEVEL CONFIGURATIONS
// ============================================================================
// This is the master list of all 5 levels.
// Values come directly from documentation Section 4.1, and REDESIGN.md D11
// keeps every value unchanged for the redesign.
//
// WHY A TOP-LEVEL CONSTANT?
// 'const' means this list is created once at compile time and never changes.
// It's more efficient than creating it every time a screen loads.
// 'final' means the variable itself can't be reassigned.
//
// Any file that imports this file can access kAllLevels.
// The 'k' prefix is a Dart convention for constants.

/// The complete list of all 5 levels in the game, in order.
/// Index 0 = Level 1 (Strolling), Index 4 = Level 5 (Impossible).
const List<LevelConfig> kAllLevels = [
  // --------------------------------------------------------------------------
  // LEVEL 1: STROLLING
  // Very slow pace. New card every 5 seconds. 30 seconds per card.
  // 3 lives (fewest, but pace is very forgiving).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 1,
    name: 'Strolling',
    newCardDelay: 5000,  // New card every 5 seconds
    cardTime: 30000,     // 30 seconds to answer that card
    lives: 3,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 2: JOGGING
  // Slightly faster. New card every 4.5 seconds. 26 seconds per card.
  // 4 lives (+1 to compensate for increased difficulty).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 2,
    name: 'Jogging',
    newCardDelay: 4500,
    cardTime: 26000,
    lives: 4,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 3: RUNNING
  // Moderate pressure. New card every 4 seconds. 22 seconds per card.
  // 5 lives.
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 3,
    name: 'Running',
    newCardDelay: 4000,
    cardTime: 22000,
    lives: 5,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 4: BOLTING
  // High pressure. New card every 3.5 seconds. 18 seconds per card.
  // 6 lives.
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 4,
    name: 'Bolting',
    newCardDelay: 3500,
    cardTime: 18000,
    lives: 6,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 5: IMPOSSIBLE
  // Maximum difficulty. New card every 3 seconds. Only 15 seconds per card.
  // 7 lives (most lives to compensate for extreme difficulty).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 5,
    name: 'Impossible',
    newCardDelay: 3000,
    cardTime: 15000,
    lives: 7,
  ),
];
