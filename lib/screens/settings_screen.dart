// ============================================================================
// SETTINGS SCREEN
// ============================================================================
// This file lets the player change preferences and erase saved progress.
//
// Per documentation Section 2.7, Settings holds:
//   - Sound effects on/off      <-- shown, but DISABLED. See the note below.
//   - Background music on/off   <-- shown, but DISABLED. See the note below.
//   - Vibration on/off          <-- WORKING
//   - Reset progress, with a confirmation dialog   <-- WORKING
//
// WHY 2 SWITCHES ARE DISABLED
// The game has no audio engine and no sound files. assets/audio/ holds only a
// .gitkeep file, and pubspec.yaml lists no audio package. A switch that looks
// live but plays nothing teaches the player that the app is broken. So the 2
// audio rows are visible and greyed out, with 1 line that says why. When the
// sound files arrive, delete the `enabled: false` argument on those 2 rows
// and remove the note. SettingsManager already saves both values.
//
// The master volume and the per-channel volume sliders in Section 2.7 are not
// here for the same reason. A slider with nothing to make louder is worse
// than no slider. Add them with the audio engine.
// ============================================================================

import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';
import '../managers/progress_manager.dart';

/// The preferences screen.
///
/// WHY StatefulWidget?
/// Two reasons, and both need setState():
///   1. The entrance fade.
///   2. A switch must redraw the moment the player moves it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // ANIMATION
  // ==========================================================================

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;

  // ==========================================================================
  // STATE
  // ==========================================================================

  /// True while resetAllProgress() runs.
  ///
  /// WHY WE TRACK IT
  /// The reset writes to storage, which is asynchronous. Without this flag a
  /// fast player could tap "Reset" twice and start 2 overlapping writes.
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _entranceController.forward();

    // SAFETY NET.
    // main.dart loads the settings during the splash screen, so by the time
    // this screen opens the values are real. This call covers the case where
    // someone opens this screen in a test, or from a future deep link, before
    // the splash screen ran.
    if (!SettingsManager().isLoaded) {
      SettingsManager().loadSettings().then((_) {
        // 'mounted' guards against the player leaving during the load.
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  /// Turns vibration on or off.
  ///
  /// The order matters:
  ///   1. setState redraws the switch at once, so it follows the finger.
  ///   2. The manager saves the value in the background.
  ///   3. When the player turns it ON, we buzz one time, so they feel the
  ///      result of their own choice. We do not buzz when they turn it off,
  ///      because a buzz on "off" contradicts the switch.
  Future<void> _onVibrationChanged(bool value) async {
    setState(() {}); // redraw now; the manager holds the real value below
    await SettingsManager().setVibrationEnabled(value);
    if (value) SettingsManager().lightTap();
    if (mounted) setState(() {});
  }

  /// Asks the player to confirm, then erases all saved progress.
  ///
  /// Per Section 2.7: "Clear all saved data with confirmation dialog".
  /// This cannot be undone, so the dialog states the exact loss and the
  /// destructive button is red.
  Future<void> _onResetPressed() async {
    SettingsManager().lightTap();

    // showDialog returns the value that Navigator.pop() passed back.
    // It returns null if the player taps outside the dialog, so we compare
    // against true instead of using the value directly.
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Reset progress?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This erases every best time and locks every level except '
          'Level 1.\n\nYou cannot undo this.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            // false = the player changed their mind
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            // true = go ahead
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F), // red = destructive
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    // The player cancelled, or tapped outside the dialog.
    if (confirmed != true) return;

    // The widget can be gone: the dialog was open for an unknown time.
    if (!mounted) return;

    setState(() => _isResetting = true);

    await ProgressManager().resetAllProgress();

    if (!mounted) return;

    setState(() => _isResetting = false);

    // A heavy buzz marks a destructive action that finished.
    SettingsManager().failure();

    // Tell the player it worked. Without this the screen looks unchanged,
    // because the progress data is not shown on this screen.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress reset. Only Level 1 is open.'),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF764ba2),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      // ================= AUDIO =================
                      _buildGroupTitle('Audio'),

                      _buildSwitchRow(
                        icon: Icons.volume_up_outlined,
                        label: 'Sound effects',
                        value: SettingsManager().soundEnabled,
                        // DISABLED: there is no audio engine. See the file
                        // header. Delete this line when the sounds exist.
                        enabled: false,
                        onChanged: (v) async {
                          await SettingsManager().setSoundEnabled(v);
                          if (mounted) setState(() {});
                        },
                      ),

                      _buildSwitchRow(
                        icon: Icons.music_note_outlined,
                        label: 'Background music',
                        value: SettingsManager().musicEnabled,
                        // DISABLED: same reason as the row above.
                        enabled: false,
                        onChanged: (v) async {
                          await SettingsManager().setMusicEnabled(v);
                          if (mounted) setState(() {});
                        },
                      ),

                      _buildNote(
                        'Audio is not in this build. These 2 controls become '
                        'active when the game has sound files.',
                      ),

                      const SizedBox(height: 18),

                      // ================= FEEDBACK =================
                      _buildGroupTitle('Feedback'),

                      _buildSwitchRow(
                        icon: Icons.vibration_rounded,
                        label: 'Vibration',
                        subtitle: 'A short buzz for a correct word, a lost '
                            'life, and the end of a game.',
                        value: SettingsManager().vibrationEnabled,
                        onChanged: _onVibrationChanged,
                      ),

                      const SizedBox(height: 18),

                      // ================= DATA =================
                      _buildGroupTitle('Data'),
                      _buildResetRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              SettingsManager().lightTap();
              Navigator.of(context).pop();
            },
            tooltip: 'Back to Main Menu',
          ),
          const Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ==========================================================================
  // ROW BUILDERS
  // ==========================================================================

  /// A small heading above a group of rows, such as "Audio".
  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.6,
          color: Colors.white.withValues(alpha: 0.70),
        ),
      ),
    );
  }

  /// One preference row with a switch.
  ///
  /// [enabled] false greys the whole row and blocks the switch. We do that
  /// instead of hiding the row, so the player can see what is planned.
  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
    bool enabled = true,
  }) {
    // One opacity value drives every part of the row, so the disabled state
    // is consistent and easy to change in 1 place.
    final double opacity = enabled ? 1.0 : 0.40;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.25 : 0.14),
        ),
      ),
      child: Opacity(
        opacity: opacity,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),

            // Expanded takes the space between the icon and the switch, so
            // a long subtitle wraps instead of overflowing.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // A null onChanged is how a Flutter Switch shows "disabled".
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF4CAF50), // green = on
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  /// A short explanation line under a group of rows.
  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The destructive "Reset progress" row.
  ///
  /// It uses a red border and red text, not the neutral style of the switch
  /// rows, so the player cannot confuse it with a preference.
  Widget _buildResetRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.55),
        ),
      ),
      child: Material(
        // Material + InkWell give the ripple when the row is tapped.
        // A bare Container has no touch feedback.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          // A null onTap disables the row while the reset is running.
          onTap: _isResetting ? null : _onResetPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFFCDD2), // pale red, readable on the purple
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset progress',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Erase every best time and lock every level except '
                        'Level 1.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                  ),
                ),

                // While the write runs, the arrow becomes a spinner. The
                // reset is normally too fast to see, but on a slow phone
                // this proves the tap registered.
                if (_isResetting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
