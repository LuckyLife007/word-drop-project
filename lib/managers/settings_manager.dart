// ============================================================================
// SETTINGS MANAGER
// ============================================================================
// This file holds the player's preferences and saves them to the phone.
//
// Per documentation Section 2.7, the Settings screen controls:
//   - Sound effects on/off
//   - Background music on/off
//   - Vibration (haptic feedback) on/off
//   - Reset progress  <-- that one lives in ProgressManager, not here
//
// WHAT WORKS TODAY AND WHAT DOES NOT
//   - vibrationEnabled  : FULLY WORKING. The helper methods below call the
//                         Flutter haptics engine, and the game screen calls
//                         those helpers.
//   - soundEnabled      : SAVED ONLY. There is no audio engine yet.
//   - musicEnabled      : SAVED ONLY. There is no audio engine yet.
//
// The 2 audio flags exist now so that the future audio code has a settled
// place to read from. The Settings screen shows their switches greyed out, so
// no control on screen makes a promise the app cannot keep.
//
// WHY A SINGLETON?
// The same reason as WordBank and ProgressManager: every screen must see the
// same values. If each screen made its own SettingsManager, a change made in
// the Settings screen would not reach the game screen.
// ============================================================================

import 'package:flutter/services.dart'; // HapticFeedback lives here
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the player's preferences and saves them between app runs.
///
/// USAGE:
/// ```dart
/// await SettingsManager().loadSettings();      // once, at app start
/// if (SettingsManager().vibrationEnabled) { ... }
/// await SettingsManager().setVibrationEnabled(false);
/// ```
class SettingsManager {
  // ==========================================================================
  // SINGLETON SETUP
  // ==========================================================================

  /// Private constructor. The underscore stops any other file calling it.
  SettingsManager._();

  /// The one and only instance, made the first time this class is touched.
  static final SettingsManager _instance = SettingsManager._();

  /// The public door. `SettingsManager()` always returns the same object.
  factory SettingsManager() => _instance;

  // ==========================================================================
  // STORAGE KEYS
  // ==========================================================================
  // Each preference needs a unique name inside SharedPreferences. We keep the
  // strings in constants so a typo cannot silently create a second key.

  static const String _kSoundEnabled = 'settings_sound_enabled';
  static const String _kMusicEnabled = 'settings_music_enabled';
  static const String _kVibrationEnabled = 'settings_vibration_enabled';

  // ==========================================================================
  // IN-MEMORY VALUES
  // ==========================================================================
  // Reading from SharedPreferences is asynchronous, and the build() method of
  // a widget cannot wait. So we read every value one time into these fields,
  // and every later read is instant.

  /// Whether short sound effects may play. Default: on.
  /// RESERVED: nothing reads this yet, because there is no audio engine.
  bool _soundEnabled = true;

  /// Whether background music may play. Default: on.
  /// RESERVED: nothing reads this yet, because there is no audio engine.
  bool _musicEnabled = true;

  /// Whether the phone may vibrate. Default: on.
  /// This one is live: the helper methods below obey it.
  bool _vibrationEnabled = true;

  /// True after loadSettings() has read the saved values one time.
  ///
  /// WHY IT MATTERS
  /// Before the first read, the fields above hold the defaults, not the
  /// player's real choice. A screen that opens early can check this flag.
  bool _isLoaded = false;

  // ==========================================================================
  // PUBLIC GETTERS
  // ==========================================================================
  // Read-only doors. Other files can read a value but cannot assign to it.
  // To change a value they must call the matching setter, which also saves it.

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get isLoaded => _isLoaded;

  // ==========================================================================
  // LOADING
  // ==========================================================================

  /// Reads every saved preference from the phone into memory.
  ///
  /// Call this one time, early, before the first screen that reads a value.
  /// main.dart calls it on the splash screen.
  ///
  /// A key that was never written returns null. The `??` operator then gives
  /// the default. So a fresh install starts with everything on.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
    _musicEnabled = prefs.getBool(_kMusicEnabled) ?? true;
    _vibrationEnabled = prefs.getBool(_kVibrationEnabled) ?? true;

    _isLoaded = true;
  }

  // ==========================================================================
  // SETTERS
  // ==========================================================================
  // Each setter does 2 things:
  //   1. Updates the in-memory value at once, so the UI can redraw now.
  //   2. Writes to storage, so the choice survives an app restart.
  //
  // The in-memory update comes first on purpose. The storage write is async
  // and can take a few milliseconds. The player must never see a switch lag
  // behind their finger.

  /// Turns sound effects on or off, and saves the choice.
  /// RESERVED: no audio engine reads this yet.
  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoundEnabled, value);
  }

  /// Turns background music on or off, and saves the choice.
  /// RESERVED: no audio engine reads this yet.
  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicEnabled, value);
  }

  /// Turns vibration on or off, and saves the choice.
  ///
  /// This takes effect at once: the helper methods below read
  /// `_vibrationEnabled` on every call.
  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrationEnabled, value);
  }

  // ==========================================================================
  // HAPTIC HELPERS
  // ==========================================================================
  // The game calls these instead of calling HapticFeedback directly. That way
  // the "is vibration allowed?" test lives in 1 place, not at every call site.
  //
  // WHY 3 DIFFERENT STRENGTHS?
  // Android and iOS give several standard patterns. Using the right strength
  // for the event makes the feedback informative, not only noisy:
  //   - light  : a small confirmation, such as a button press
  //   - medium : a clear event the player caused, such as a correct word
  //   - heavy  : a bad event, such as a lost life
  //
  // Some phones and some Android builds ignore parts of this. A phone with no
  // vibration motor simply does nothing. No error is thrown.

  /// A light tap. Use it for a button press.
  void lightTap() {
    if (!_vibrationEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// A medium tap. Use it for a correct word.
  void success() {
    if (!_vibrationEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// A heavy tap. Use it for a lost life.
  void failure() {
    if (!_vibrationEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// A double heavy tap. Use it for the end of a game.
  ///
  /// There is no "very heavy" pattern, so we send 2 heavy taps with a short
  /// gap. The gap makes the 2 taps feel like 1 deliberate signal instead of
  /// a stutter.
  Future<void> gameOver() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    // Check again: the player could have opened Settings and turned vibration
    // off during the 120ms gap.
    if (!_vibrationEnabled) return;
    await HapticFeedback.heavyImpact();
  }
}
