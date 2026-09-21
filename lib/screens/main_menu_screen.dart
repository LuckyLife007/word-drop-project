// ============================================================================
// MAIN MENU SCREEN
// ============================================================================
// This file defines the Main Menu - the first screen the player sees after
// the splash/loading screen.
//
// Per documentation Section 2.1, the Main Menu contains:
//   - "Word Drop" title at the top
//   - Play button (leads to level selection)
//   - Settings button (audio controls, vibration toggle)
//   - How to Play button (tutorial/instructions)
//   - About button (credits and version info)
//   - Full-screen sky gradient background
//
// Per Section 6.1, the layout is:
//   - Centered vertical column
//   - Title takes ~40% of screen height
//   - Buttons spaced evenly below
//
// Per Section 6.4, screen transitions use FadeTransition (300ms).
//
// CHANGELOG:
//   - Replaced all .withOpacity() calls with .withValues(alpha:)
//     because .withOpacity() is deprecated in newer Flutter versions.
//   - Wired Play button to navigate to LevelSelectionScreen.
// ============================================================================

import 'package:flutter/material.dart';
import 'level_selection_screen.dart'; // The screen the Play button leads to

// ============================================================================
// MAIN MENU SCREEN WIDGET
// ============================================================================

/// The main menu screen shown after the splash/loading screen.
///
/// WHY StatefulWidget instead of StatelessWidget?
/// We want a subtle animation when this screen first appears - the title and
/// buttons slide/fade in. This requires tracking animation state, which
/// means we need a StatefulWidget.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

/// State class for MainMenuScreen.
///
/// 'with SingleTickerProviderStateMixin' gives us animation ticker support.
/// We use it for the entrance animation where the title and buttons
/// gently fade/slide into view.
class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================================
  // ANIMATION SETUP
  // ============================================================================

  /// Controls the overall entrance animation timing (0.0 → 1.0)
  late AnimationController _entranceController;

  /// The title slides DOWN slightly while fading in (top → center effect)
  late Animation<Offset> _titleSlideAnimation;

  /// The buttons fade in slightly after the title
  late Animation<double> _buttonsFadeAnimation;

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();

    // The entrance animation plays over 600ms when the screen opens
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Title slides in from slightly above (offset y = -0.3 → 0.0)
    // Offset values are in fractions of the widget's size, not pixels.
    // Offset(0, -0.3) means "start 30% above your normal position"
    _titleSlideAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.3), // Start slightly above
          end: Offset.zero, // End at normal position
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOut, // Decelerates as it settles into place
          ),
        );

    // Buttons fade in slightly delayed (start at 40% through the animation)
    // This creates a "title first, then buttons" effect
    _buttonsFadeAnimation =
        Tween<double>(
          begin: 0.0, // Fully transparent
          end: 1.0, // Fully opaque
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            // Interval(0.4, 1.0): don't start until 40% of animation is done
            curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
          ),
        );

    // Play the entrance animation as soon as this screen is shown
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose(); // Free animation resources
    super.dispose();
  }

  // ============================================================================
  // NAVIGATION METHODS
  // ============================================================================

  /// Navigates to the Level Selection screen.
  /// Called when the player taps the "Play" button.
  void _onPlayPressed() {
    // Navigator.of(context).push() adds a new screen on top of the current one.
    // Unlike pushReplacement (used in the splash screen), push() keeps the
    // Main Menu underneath - this means the player can tap the back arrow on
    // the Level Selection screen to return here.
    Navigator.of(context).push(
      PageRouteBuilder(
        // How long the transition animation takes (docs: 300ms for menus)
        transitionDuration: const Duration(milliseconds: 300),

        // Which screen to navigate to
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LevelSelectionScreen(),

        // FadeTransition matches Section 6.4: "FadeTransition (300ms) for menus"
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Opens the Settings screen.
  /// Called when the player taps the "Settings" button.
  void _onSettingsPressed() {
    // TODO: Navigate to SettingsScreen once it's built.
    _showComingSoon('Settings');
  }

  /// Opens the How to Play overlay.
  /// Called when the player taps the "How to Play" button.
  void _onHowToPlayPressed() {
    // TODO: Show HowToPlayOverlay once it's built.
    _showComingSoon('How to Play');
  }

  /// Opens the About screen.
  /// Called when the player taps the "About" button.
  void _onAboutPressed() {
    // TODO: Navigate to AboutScreen once it's built.
    _showComingSoon('About');
  }

  /// Helper to show a temporary "Coming Soon" message for unbuilt screens.
  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName - Coming Soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF764ba2),
      ),
    );
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,

      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // Blue-purple (top of sky)
              Color(0xFF764ba2), // Deep purple (bottom of sky)
            ],
          ),
        ),

        // BUG-14 FIX (REDESIGN.md): on a short screen the menu overflowed by
        // 3.2 pixels, because the title took a fixed 40% of the WHOLE screen
        // and the buttons need about 286px under it.
        //
        // Two changes fix it:
        //   1. The title height is measured from the space the menu really
        //      has (LayoutBuilder), not from the whole screen, and it never
        //      goes below 140px.
        //   2. The menu sits in a scroll view. On a very short screen, or
        //      with large system text, the player scrolls instead of seeing
        //      a yellow overflow bar.
        // IntrinsicHeight lets the buttons stay centred in the space that is
        // left on a normal screen.
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ======================================================
                        // TITLE AREA (~40% of the menu height, per Section 6.1)
                        // ======================================================
                        SizedBox(
                          height: (constraints.maxHeight * 0.40).clamp(
                            140.0,
                            double.infinity,
                          ),

                          child: SlideTransition(
                            position: _titleSlideAnimation,

                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Main game title
                                  // Section 6.2: "Large (~48sp), bold, centered with subtle shadow"
                                  const Text(
                                    'Word Drop',
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 12.0,
                                          color: Color(0x66000000),
                                          offset: Offset(2.0, 3.0),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  const Text(
                                    'Fill the gaps before the time ends.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Color(0xCCFFFFFF),
                                      fontStyle: FontStyle.italic,
                                      letterSpacing: 0.5,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Decorative divider line
                                  Container(
                                    width: 80,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      // .withValues(alpha:) is the modern replacement
                                      // for the deprecated .withOpacity()
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ==============================================================
                        // BUTTONS AREA (remaining ~60% of screen)
                        // ==============================================================
                        Expanded(
                          child: FadeTransition(
                            opacity: _buttonsFadeAnimation,

                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40.0,
                              ),

                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // PRIMARY BUTTON: PLAY (Section 2.1: "Primary Action Button")
                                  _buildPrimaryButton(
                                    label: 'PLAY',
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: _onPlayPressed,
                                  ),

                                  const SizedBox(height: 16),

                                  // SECONDARY BUTTONS (Section 2.1)
                                  _buildSecondaryButton(
                                    label: 'How to Play',
                                    icon: Icons.help_outline_rounded,
                                    onPressed: _onHowToPlayPressed,
                                  ),

                                  const SizedBox(height: 12),

                                  _buildSecondaryButton(
                                    label: 'Settings',
                                    icon: Icons.settings_outlined,
                                    onPressed: _onSettingsPressed,
                                  ),

                                  const SizedBox(height: 12),

                                  _buildSecondaryButton(
                                    label: 'About',
                                    icon: Icons.info_outline_rounded,
                                    onPressed: _onAboutPressed,
                                  ),

                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUTTON BUILDERS
  // ============================================================================
  // Helper methods so we don't repeat styling code. DRY principle.

  /// Builds the large primary "Play" button.
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28, color: const Color(0xFF667eea)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
            letterSpacing: 2.0,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF667eea),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  /// Builds a secondary menu button (outlined, transparent background).
  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.60),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}
