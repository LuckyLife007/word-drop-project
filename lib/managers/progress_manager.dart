// ============================================================================
// PROGRESS MANAGER
// ============================================================================
// This file handles saving and loading the player's progress to/from the
// device's local storage.
//
// WHAT IT SAVES:
//   - Which levels are unlocked (e.g. levels 1, 2 and 3 unlocked)
//   - Best completion time for each completed level (in milliseconds)
//
// WHY shared_preferences?
// Flutter's 'shared_preferences' package lets us store simple key-value data
// directly on the device (similar to browser localStorage on the web).
// It's the standard solution for saving small amounts of data like settings
// and progress. It works on Android, iOS, and all other Flutter platforms.
//
// We chose shared_preferences over a full database (like SQLite) because our
// data is very simple - just a handful of numbers. A full database would be
// overkill.
//
// SINGLETON PATTERN:
// Like WordBank and GameManager, we use a singleton so there's only ever
// ONE ProgressManager in the entire app. All screens share the same instance.
//
// SOURCE: Documentation Section 4.6 (Level Transition and Unlock System)
//         Documentation Section 1.3 (Performance Tracking - best times)
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// KEY CONSTANTS
// ============================================================================
// These are the string keys used to store/retrieve data in shared_preferences.
// Using constants prevents typos - if you mistype a key, you'd silently save
// to the wrong slot. Constants let the Dart analyser catch mistakes.

/// Key for storing the highest unlocked level number (1-5)
const String _kHighestUnlockedLevel = 'highest_unlocked_level';

/// Key prefix for storing best times. We append the level number.
/// Example: 'best_time_1', 'best_time_2', etc.
const String _kBestTimePrefix = 'best_time_';

// ============================================================================
// PROGRESS MANAGER CLASS
// ============================================================================

/// Manages saving and loading player progress for Word Drop.
///
/// USAGE EXAMPLE:
/// ```dart
/// // Load progress
/// await ProgressManager().loadProgress();
///
/// // Check if a level is unlocked
/// bool canPlay = ProgressManager().isLevelUnlocked(3);
///
/// // Save a new best time after completing level 2
/// await ProgressManager().saveBestTime(levelNumber: 2, timeMs: 95000);
///
/// // Unlock the next level after completing level 2
/// await ProgressManager().unlockLevel(3);
/// ```
class ProgressManager {
  // ==========================================================================
  // SINGLETON SETUP
  // ==========================================================================

  /// Private constructor prevents external instantiation
  ProgressManager._();

  /// The single shared instance
  static final ProgressManager _instance = ProgressManager._();

  /// Factory constructor always returns the same instance
  factory ProgressManager() => _instance;

  // ==========================================================================
  // STATE
  // ==========================================================================

  /// The highest level number the player has unlocked.
  /// Starts at 1 (only Level 1 is available at the beginning).
  /// Source: Documentation Section 4.6 - "Players start with access to Level 1 only"
  int _highestUnlockedLevel = 1;

  /// Best completion times for each level, keyed by level number (1-5).
  /// Values are in milliseconds. A missing entry means the level hasn't been completed.
  /// Example: {1: 85000, 2: 112000} means Level 1 best is 85s, Level 2 best is 112s.
  final Map<int, int> _bestTimes = {};

  /// Whether progress has been loaded from storage yet.
  /// We use this to avoid reading from storage multiple times unnecessarily.
  bool _isLoaded = false;

  // ==========================================================================
  // PUBLIC GETTERS
  // ==========================================================================

  /// The highest level number currently unlocked (1-5)
  int get highestUnlockedLevel => _highestUnlockedLevel;

  /// Whether progress has been loaded from local storage
  bool get isLoaded => _isLoaded;

  // ==========================================================================
  // LOADING PROGRESS
  // ==========================================================================

  /// Loads the player's saved progress from local storage.
  ///
  /// WHO CALLS IT: the Level Selection screen, every time it opens.
  /// The splash screen does NOT call it — the splash screen loads the word
  /// bank only. (This comment said the opposite before: REDESIGN.md BUG-8.)
  ///
  /// If no saved data exists (first time playing), defaults are used:
  ///   - highestUnlockedLevel = 1 (only Level 1 available)
  ///   - No best times (nothing completed yet)
  Future<void> loadProgress() async {
    // SharedPreferences.getInstance() returns the shared_preferences object.
    // 'await' waits for it to be ready before continuing.
    final prefs = await SharedPreferences.getInstance();

    // Load highest unlocked level.
    // getInt() returns null if the key doesn't exist (i.e. first time playing).
    // The '?? 1' means "use 1 if the result is null" - i.e. default to Level 1.
    _highestUnlockedLevel = prefs.getInt(_kHighestUnlockedLevel) ?? 1;

    // Load best times for all 5 levels
    _bestTimes.clear();
    for (int levelNum = 1; levelNum <= 5; levelNum++) {
      final String key = '$_kBestTimePrefix$levelNum';
      final int? savedTime = prefs.getInt(key);

      // Only store if a time was actually saved (null = not completed yet)
      if (savedTime != null) {
        _bestTimes[levelNum] = savedTime;
      }
    }

    _isLoaded = true;
    print(
      '📊 ProgressManager: loaded progress - '
      'highest unlocked: $_highestUnlockedLevel, '
      'best times: $_bestTimes',
    );
  }

  // ==========================================================================
  // QUERYING PROGRESS
  // ==========================================================================

  /// Returns true if the given level number is unlocked (playable).
  ///
  /// A level is unlocked if its number is <= the highest unlocked level.
  /// Example: if highestUnlockedLevel = 3, then levels 1, 2, 3 are unlocked.
  ///
  /// Source: Section 4.6 - "Each completed level unlocks the next level permanently"
  bool isLevelUnlocked(int levelNumber) {
    return levelNumber <= _highestUnlockedLevel;
  }

  /// Returns true if the given level has been completed (has a recorded best time).
  bool isLevelCompleted(int levelNumber) {
    return _bestTimes.containsKey(levelNumber);
  }

  /// Returns the best completion time for a level in milliseconds.
  /// Returns null if the level hasn't been completed yet.
  int? getBestTime(int levelNumber) {
    return _bestTimes[levelNumber];
  }

  /// Returns the best time formatted as a readable string (e.g. "1:23").
  /// Returns null if the level hasn't been completed.
  ///
  /// Format: "M:SS" (minutes:seconds, seconds always 2 digits)
  /// Examples: 65000ms → "1:05", 90000ms → "1:30", 600000ms → "10:00"
  String? getFormattedBestTime(int levelNumber) {
    final int? timeMs = _bestTimes[levelNumber];
    if (timeMs == null) return null;

    // Convert milliseconds to total seconds (drop sub-second precision)
    final int totalSeconds = timeMs ~/ 1000; // ~/ is integer division in Dart

    // Split into minutes and remaining seconds
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;

    // Pad seconds to always show 2 digits (e.g. "5" becomes "05")
    // padLeft(2, '0') adds a leading zero if the string is shorter than 2 chars
    final String paddedSeconds = seconds.toString().padLeft(2, '0');

    return '$minutes:$paddedSeconds';
  }

  // ==========================================================================
  // SAVING PROGRESS
  // ==========================================================================

  /// Unlocks a level and saves to local storage.
  ///
  /// Call this when the player completes a level to unlock the next one.
  /// If the given level is already unlocked, nothing changes.
  ///
  /// [levelNumber] - The level to unlock (1-5)
  ///
  /// Source: Section 4.6 - "Each completed level unlocks the next level permanently"
  Future<void> unlockLevel(int levelNumber) async {
    // Only update if this is actually a new unlock
    if (levelNumber > _highestUnlockedLevel) {
      _highestUnlockedLevel = levelNumber;

      // Save to device storage so it persists after the app is closed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHighestUnlockedLevel, _highestUnlockedLevel);

      print('🔓 ProgressManager: unlocked Level $levelNumber');
    }
  }

  /// Saves a best time for a completed level.
  ///
  /// Only saves if the new time is better than the existing best time
  /// (i.e. a faster completion time wins).
  ///
  /// [levelNumber] - Which level was completed (1-5)
  /// [timeMs]      - Completion time in milliseconds
  ///
  /// Source: Section 1.3 - "Fastest completion time per level... Personal best times stored locally"
  Future<void> saveBestTime({
    required int levelNumber,
    required int timeMs,
  }) async {
    // Check if this is a new best (or the first completion)
    final int? existingBest = _bestTimes[levelNumber];
    final bool isNewBest = existingBest == null || timeMs < existingBest;

    if (isNewBest) {
      _bestTimes[levelNumber] = timeMs;

      // Persist to device storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_kBestTimePrefix$levelNumber', timeMs);

      print(
        '⏱️ ProgressManager: new best time for Level $levelNumber: '
        '${getFormattedBestTime(levelNumber)}',
      );
    }
  }

  // ==========================================================================
  // RESET (for Settings screen "Reset Progress" feature)
  // ==========================================================================

  /// Resets all progress to the initial state (Level 1 only, no best times).
  ///
  /// This is used by the "Reset Progress" option in Settings.
  /// Source: Section 2.7 - "Reset Progress: Clear all saved data with confirmation dialog"
  Future<void> resetAllProgress() async {
    _highestUnlockedLevel = 1;
    _bestTimes.clear();

    final prefs = await SharedPreferences.getInstance();

    // Remove all our saved keys from storage
    await prefs.remove(_kHighestUnlockedLevel);
    for (int levelNum = 1; levelNum <= 5; levelNum++) {
      await prefs.remove('$_kBestTimePrefix$levelNum');
    }

    print('🗑️ ProgressManager: all progress reset');
  }
}
