// ============================================================================
// HOW TO PLAY SCREEN
// ============================================================================
// This file explains the rules of the game to the player.
//
// Per documentation Section 2.3, "How to Play" is reachable from the Main
// Menu and explains the objective, the lives system, and how to start.
//
// IMPORTANT: THIS TEXT DESCRIBES THE CARD DESIGN, NOT THE OLD FALLING WORDS.
// The old documentation says "complete the falling words before they hit the
// ground". REDESIGN.md replaced that design with timed word cards in a grid.
// Every rule below comes from REDESIGN.md sections S1 to S9. If you change a
// rule in the game, change the matching text here.
//
// WHY A FULL SCREEN AND NOT AN OVERLAY?
// The old plan called this an "overlay". The rules need about 9 sections of
// text, which is more than an overlay can hold on a 640px tall phone. A full
// screen with a scroll view shows everything and still returns with 1 tap.
//
// CONVENTIONS USED HERE (same as the other screens):
//   - .withValues(alpha:) instead of the deprecated .withOpacity()
//   - SingleTickerProviderStateMixin for the single entrance animation
//   - FadeTransition, 300ms, for the screen change (Section 6.4)
// ============================================================================

import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

/// The screen that explains the rules.
///
/// WHY StatefulWidget?
/// Only for the entrance fade. The content itself never changes, so nothing
/// else in this file calls setState().
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // ANIMATION
  // ==========================================================================

  /// Drives the entrance fade, 0.0 to 1.0 over 400ms.
  late AnimationController _entranceController;

  /// The eased curve the fade follows. easeOut starts fast and settles gently.
  late Animation<double> _fadeAnimation;

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

    // Play it at once. There is nothing to load first.
    _entranceController.forward();
  }

  @override
  void dispose() {
    // Always dispose a controller, or its ticker keeps running and leaks.
    _entranceController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent, because the Container below paints the gradient.
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          // The same sky gradient as every other screen (Section 6.1).
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // blue-purple
              Color(0xFF764ba2), // deeper purple
            ],
          ),
        ),
        // SafeArea keeps the content clear of the status bar and the gesture
        // bar. Without it the title can sit under the clock.
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),

                // Expanded gives the scroll view all the height that is left.
                // Without it, the ListView has no height and Flutter throws.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _buildIntro(),
                      const SizedBox(height: 16),

                      // ---- 1. THE GOAL (REDESIGN.md S1) ----
                      _buildSection(
                        icon: Icons.flag_rounded,
                        title: 'The goal',
                        lines: const [
                          'Word cards appear in a grid. Each card holds one '
                              'word with letters missing.',
                          'Type the complete word before the card timer '
                              'reaches zero.',
                        ],
                      ),

                      // ---- 2. THE CARD (S3) ----
                      _buildSection(
                        icon: Icons.credit_card_rounded,
                        title: 'What is on a card',
                        lines: const [
                          'The pattern, such as B-N-N-. A dash is a letter '
                              'you must supply.',
                          'The clue, in italic text below the pattern.',
                          'The seconds left, on the right of the pattern.',
                          'The timer bar, on the bottom edge of the card.',
                        ],
                      ),

                      // ---- 3. THE COLOURS (S3 card states) ----
                      _buildSection(
                        icon: Icons.palette_outlined,
                        title: 'What the colours mean',
                        // A colour rule is easier to read as a coloured row
                        // than as a sentence, so this section uses its own
                        // builder instead of plain lines.
                        child: Column(
                          children: [
                            _buildColourRow(
                              const Color(0xFF667eea),
                              'Blue',
                              'The card is running normally.',
                            ),
                            _buildColourRow(
                              const Color(0xFFFFA000),
                              'Amber',
                              'Fewer than 5 seconds are left. Answer it now.',
                            ),
                            _buildColourRow(
                              const Color(0xFFD32F2F),
                              'Red',
                              'The time ended. You lose 1 life.',
                            ),
                            _buildColourRow(
                              const Color(0xFF4CAF50),
                              'Green',
                              'Correct. You gain 5 points.',
                            ),
                          ],
                        ),
                      ),

                      // ---- 4. TYPING (S6) ----
                      _buildSection(
                        icon: Icons.keyboard_alt_outlined,
                        title: 'How to answer',
                        lines: const [
                          'There is one text box. It stays open during play.',
                          'Type the whole word. A part of a word does not '
                              'count.',
                          'Capital letters do not matter.',
                          'A wrong word costs you nothing. There is no '
                              'penalty and no warning.',
                          'A correct word clears the box for the next one.',
                        ],
                      ),

                      // ---- 5. THE "+" BUTTON (S5, D14) ----
                      _buildSection(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'The "+" button',
                        lines: const [
                          'New cards arrive on their own. The "+" button '
                              'brings the next one at once.',
                          'Use it when you are fast and the grid is not full.',
                          'The button turns grey when all 6 places are taken.',
                        ],
                      ),

                      // ---- 6. PAUSE (S8) ----
                      _buildSection(
                        icon: Icons.pause_circle_outline_rounded,
                        title: 'Pause',
                        lines: const [
                          'The game pauses in 3 ways: the pause button, the '
                              'back gesture, or leaving the app.',
                          'Every timer stops. A pause costs no life, no '
                              'points and no clock time.',
                          'When you continue, a "3, 2, 1, Go" countdown gives '
                              'you time to look at the board.',
                        ],
                      ),

                      // ---- 7. SCORE (S7) ----
                      _buildSection(
                        icon: Icons.star_outline_rounded,
                        title: 'Score',
                        lines: const [
                          'Each correct word gives 5 points.',
                          '20 correct words give 100 points and complete the '
                              'level.',
                          'The words get longer as you go: 6 letters at the '
                              'start, 10 letters at the end.',
                          'The game saves your best time for each level.',
                        ],
                      ),

                      // ---- 8. LIVES (S7) ----
                      _buildSection(
                        icon: Icons.favorite_outline_rounded,
                        title: 'Lives',
                        lines: const [
                          'Each card that reaches zero costs 1 life.',
                          'The game ends when no lives are left.',
                          'Level 1 gives 3 lives. Level 5 gives 7.',
                        ],
                      ),

                      // ---- 9. THE ARROWS (S2, D23/D28) ----
                      _buildSection(
                        icon: Icons.swap_vert_rounded,
                        title: 'The blinking arrows',
                        lines: const [
                          'On a small screen the grid is taller than the '
                              'space. Slide it with your finger.',
                          'A blinking arrow shows that cards are hidden above '
                              'or below.',
                          'The arrow turns amber when a hidden card is nearly '
                              'out of time, and red when it fails.',
                        ],
                      ),

                      const SizedBox(height: 8),
                      _buildClosingNote(),
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

  /// The top row: a back arrow, the title, and a spacer that keeps the title
  /// in the middle. This matches the header of the Level Selection screen.
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
              // A light tap confirms the press. It obeys the Settings switch.
              SettingsManager().lightTap();
              Navigator.of(context).pop();
            },
            tooltip: 'Back to Main Menu', // read by screen readers
          ),

          const Expanded(
            child: Text(
              'How to Play',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Balances the width of the IconButton so the title sits centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONTENT BUILDERS
  // ==========================================================================

  /// The short line under the title that sets the scene.
  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // A pale panel on the gradient. 0.15 alpha keeps the gradient visible
        // through it, so the screen still looks like one piece.
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: const Text(
        'Fill the gaps before the time ends.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }

  /// Builds one titled section.
  ///
  /// [lines] is the simple case: each string becomes a bullet.
  /// [child] is the escape hatch for a section that needs its own layout,
  /// such as the colour key. Pass one of the two, not both.
  Widget _buildSection({
    required IconData icon,
    required String title,
    List<String>? lines,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Title row: icon + heading ----
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD700), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ---- Body: either the bullets or the custom child ----
          if (child != null)
            child
          else
            // The spread operator ... puts every built bullet into this list.
            ...?lines?.map(_buildBullet),
        ],
      ),
    );
  }

  /// One bullet line inside a section.
  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A small dot, nudged down so it lines up with the first text line.
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 9),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700), // gold, the accent colour
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.42, // line spacing, so the text breathes
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One row of the colour key: a coloured chip, the colour name, the meaning.
  Widget _buildColourRow(Color colour, String name, String meaning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The chip shows the real colour the game uses, so the player can
          // match what they see on a card.
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                // RichText needs an explicit style: it does not inherit one.
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.42,
                ),
                children: [
                  TextSpan(
                    text: '$name — ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: meaning),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The encouraging line at the end, per Section 2.3 step 4.
  Widget _buildClosingNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Gold tint, so the last panel reads as the reward, not another rule.
        color: const Color(0xFFFFD700).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.55),
        ),
      ),
      child: const Text(
        'That is everything. Start with Level 1: Strolling. '
        'It gives you 30 seconds for each card.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
