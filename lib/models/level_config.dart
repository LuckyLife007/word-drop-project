// ============================================================================
// LEVEL CONFIG MODEL
// ============================================================================
// This file defines the LevelConfig class, which holds all the settings for
// a single difficulty level, and the master list of all 5 levels in the game.
//
// WHY A SEPARATE FILE?
// Both the Level Selection screen (to display level info) and the future
// Game screen (to know how fast words should fall, etc.) need this data.
// By defining it once here, we avoid duplicating it in multiple places.
// This follows the DRY principle: "Don't Repeat Yourself."
//
// SOURCE: All values come directly from documentation Section 4.1.
// ============================================================================

/// Holds all configuration data for one difficulty level.
///
/// Think of this as a "settings card" for each level. When the game screen
/// needs to know how fast to spawn words or how many lives to give the player,
/// it reads from this object.
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

  /// How many milliseconds between each new word spawning.
  /// Lower = faster = harder.
  /// Example: 5000 means a new word appears every 5 seconds.
  /// Source: Documentation Section 4.1 and 5.2
  final int spawnDelay;

  /// How many milliseconds a word takes to fall from top to bottom.
  /// Lower = faster fall = less time to answer = harder.
  /// Example: 30000 means the word takes 30 seconds to fall completely.
  /// Source: Documentation Section 4.1 and 5.3
  final int fallTime;

  /// How many lives the player starts with on this level.
  /// Higher levels give more lives to compensate for increased difficulty.
  /// Source: Documentation Section 4.4
  final int lives;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================

  /// Creates a LevelConfig. All fields are required.
  const LevelConfig({
    required this.levelNumber,
    required this.name,
    required this.spawnDelay,
    required this.fallTime,
    required this.lives,
  });

  // ==========================================================================
  // CONVENIENCE GETTERS
  // ==========================================================================

  /// Returns the full display label shown on the level card.
  /// Example: "Level 1: Strolling"
  String get displayLabel => 'Level $levelNumber: $name';

  /// Returns spawnDelay as a Duration object (easier to use with Flutter timers)
  Duration get spawnDelayDuration => Duration(milliseconds: spawnDelay);

  /// Returns fallTime as a Duration object (easier to use with AnimationController)
  Duration get fallTimeDuration => Duration(milliseconds: fallTime);

  /// String representation for debugging
  @override
  String toString() {
    return 'LevelConfig(level: $levelNumber, name: $name, '
        'spawnDelay: ${spawnDelay}ms, fallTime: ${fallTime}ms, lives: $lives)';
  }
}

// ============================================================================
// ALL LEVEL CONFIGURATIONS
// ============================================================================
// This is the master list of all 5 levels.
// Values come directly from documentation Section 4.1.
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
  // Very slow pace. New word every 5 seconds. 30 seconds to answer.
  // 3 lives (fewest, but pace is very forgiving).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 1,
    name: 'Strolling',
    spawnDelay: 5000,   // New word every 5 seconds
    fallTime: 30000,    // 30 seconds to fall from top to bottom
    lives: 3,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 2: JOGGING
  // Slightly faster. New word every 4.5 seconds. 26 seconds to answer.
  // 4 lives (+1 to compensate for increased difficulty).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 2,
    name: 'Jogging',
    spawnDelay: 4500,
    fallTime: 26000,
    lives: 4,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 3: RUNNING
  // Moderate pressure. New word every 4 seconds. 22 seconds to answer.
  // 5 lives.
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 3,
    name: 'Running',
    spawnDelay: 4000,
    fallTime: 22000,
    lives: 5,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 4: BOLTING
  // High pressure. New word every 3.5 seconds. 18 seconds to answer.
  // 6 lives.
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 4,
    name: 'Bolting',
    spawnDelay: 3500,
    fallTime: 18000,
    lives: 6,
  ),

  // --------------------------------------------------------------------------
  // LEVEL 5: IMPOSSIBLE
  // Maximum difficulty. New word every 3 seconds. Only 15 seconds to answer.
  // 7 lives (most lives to compensate for extreme difficulty).
  // --------------------------------------------------------------------------
  LevelConfig(
    levelNumber: 5,
    name: 'Impossible',
    spawnDelay: 3000,
    fallTime: 15000,
    lives: 7,
  ),
];