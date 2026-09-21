// ============================================================================
// ABOUT SCREEN
// ============================================================================
// This file shows the version, what the game is, and the credits.
//
// Per documentation Section 2.1, "About" holds "credits and version
// information".
//
// WHY THE VERSION IS A CONSTANT HERE
// Flutter cannot read the version out of pubspec.yaml at run time without an
// extra package (package_info_plus). Adding a package for 1 string is not
// worth the build weight, so the value lives in kAppVersion below.
//
// WARNING: kAppVersion must match the `version:` line in pubspec.yaml.
// Change both together, or this screen tells the player a lie.
// ============================================================================

import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

/// The version shown on this screen.
///
/// KEEP IN SYNC WITH pubspec.yaml -> version: 1.0.0+1
/// The part before the "+" is the version people read. The part after it is
/// the build number, which only the app stores use, so it is left out here.
const String kAppVersion = '1.0.0';

/// The screen with the version and the credits.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // ANIMATION
  // ==========================================================================

  late AnimationController _entranceController;
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

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
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
                      _buildLogoBlock(),
                      const SizedBox(height: 18),

                      // ---- What the game is ----
                      _buildCard(
                        icon: Icons.extension_outlined,
                        title: 'The game',
                        body:
                            'Word Drop is a word puzzle. Cards appear with a '
                            'word that has letters missing, a clue, and a '
                            'countdown. You type the complete word before the '
                            'countdown ends.\n\n'
                            'There are 5 levels. Each one gives you less time '
                            'for each card and sends cards more often.',
                      ),

                      // ---- Facts ----
                      _buildFactsCard(),

                      // ---- Credits ----
                      _buildCard(
                        icon: Icons.people_outline_rounded,
                        title: 'Credits',
                        body:
                            'Design and code: Lucky Uche.\n'
                            'Word bank: 100 words with 3 patterns and 3 clues '
                            'for each word.\n'
                            'Built with Flutter and Dart.',
                      ),

                      // ---- Thanks ----
                      _buildThanksCard(),
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
              'About',
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
  // CONTENT
  // ==========================================================================

  /// The title block: the game name, the tagline, and the version.
  Widget _buildLogoBlock() {
    return Column(
      children: [
        const SizedBox(height: 10),

        // The same title treatment as the Main Menu, at a smaller size.
        Text(
          'Word Drop',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Fill the gaps before the time ends.',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),

        const SizedBox(height: 14),

        // The version pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Text(
            'Version $kAppVersion',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  /// A plain card: icon, heading, one block of text.
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String body,
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD700), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  /// The facts card: a small table of label and value pairs.
  ///
  /// A table reads faster than a paragraph for numbers, so this card does not
  /// reuse _buildCard().
  Widget _buildFactsCard() {
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
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFFFD700),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Facts',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Each value here must agree with kAllLevels in level_config.dart
          // and with the word bank file.
          _buildFactRow('Levels', '5'),
          _buildFactRow('Words in the bank', '100'),
          _buildFactRow('Word length', '6 to 10 letters'),
          _buildFactRow('Words to finish a level', '20'),
          _buildFactRow('Points for each word', '5'),
          _buildFactRow('Card places on screen', '6'),
        ],
      ),
    );
  }

  /// One label and value line inside the facts card.
  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        // spaceBetween pushes the label left and the value right, so every
        // value lines up on the right edge.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// The closing card, in the gold accent colour.
  Widget _buildThanksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.55),
        ),
      ),
      child: const Text(
        'Thank you for playing.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
