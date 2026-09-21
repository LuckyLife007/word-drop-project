// ============================================================================
// WIDGET TEST FILE
// ============================================================================
// Run it with:  flutter test
//
// WHAT THIS FILE COVERS
//   1. The app starts, shows the splash screen, reaches the main menu, and
//      every menu button opens the right screen and comes back.
//   2. Each menu screen shows its own content and its controls behave.
//
// ---------------------------------------------------------------------------
// WHY THE OLD TEST FAILED (BUG-6 in REDESIGN.md)
// The old test called pumpWidget() and then ended at once. The splash screen
// had already started a 1500ms Future.delayed, and the test framework fails a
// test that ends while a timer is still waiting:
//   "A Timer is still pending even after the widget tree was disposed."
//
// THE FIX HAS TWO PARTS:
//   1. Let the clock run inside the test, so the splash screen finishes its
//      wait, navigates, and leaves no timer behind.
//   2. Move the clock in SMALL STEPS. The splash screen loads the word bank
//      from the asset bundle first, and that is real asynchronous work. Each
//      pump() gives it a turn to finish. One big pump() would jump over the
//      moment the load completes, and the 1500ms wait would only start after
//      the test had finished moving the clock.
//
// ---------------------------------------------------------------------------
// WHY ONLY ONE TEST STARTS THE WHOLE APP
//
// WordBank.loadWords() has no cache: it reads assets/data/word_bank.json from
// the asset bundle on every call. The first full app start inside a test file
// completes that read. A second full app start in the same file does not —
// the read never finishes under the test clock, the splash screen stays on
// "Loading...", and every later pumpAndSettle() times out on the spinner.
//
// So exactly 1 test starts the app. It also checks the menu wiring, because
// that check needs a real main menu. Every other test mounts 1 screen on its
// own inside a plain MaterialApp. That is faster, and a failure then points
// at 1 screen instead of at the whole startup path.
//
// ---------------------------------------------------------------------------
// WHY setMockInitialValues IS NECESSARY
//
// The splash screen calls SettingsManager().loadSettings(), and the Settings
// screen reads the same store. A test has no phone storage behind that
// channel. setMockInitialValues installs an empty in-memory store, so every
// read returns null and SettingsManager falls back to its defaults.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_drop/main.dart';
import 'package:word_drop/screens/how_to_play_screen.dart';
import 'package:word_drop/screens/settings_screen.dart';
import 'package:word_drop/screens/about_screen.dart';
import 'package:word_drop/managers/settings_manager.dart';

void main() {
  // setMockInitialValues talks to the test binding, so the binding must exist
  // before setUp() runs. testWidgets() would create it, but setUp() runs
  // first, so we create it here.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // A clean, empty store for every test, so one test cannot leave a saved
    // value behind that changes the result of the next one.
    SharedPreferences.setMockInitialValues({});

    // SettingsManager is a singleton, so it keeps the values from the last
    // test. Reading the fresh empty store puts every preference back to its
    // default before the next test looks at it.
    await SettingsManager().loadSettings();
  });

  /// Mounts one screen on its own, with no splash screen and no word bank.
  Future<void> mountScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  // ==========================================================================
  // 1. STARTUP AND MENU WIRING
  // ==========================================================================

  testWidgets('The app starts, reaches the menu, and every button works', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WordDropApp());

    // ---- The splash screen is the first thing the player sees ----
    expect(find.text('Word Drop'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // ---- Move the clock forward in small steps ----
    // The whole splash sequence is about 2.3 seconds: an 800ms logo fade, the
    // word bank load, a 1500ms minimum display time and a 300ms fade to the
    // menu. 30 steps of 200ms give 6 seconds, which is plenty.
    for (int step = 0; step < 30; step++) {
      if (find.text('PLAY').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }

    // ---- The main menu shows its 4 buttons ----
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Let every entrance animation finish before the first tap.
    await tester.pumpAndSettle();

    // ---- Each button opens its screen, and the back arrow returns ----
    // We check a heading that belongs only to the opened screen. Checking the
    // button words again would pass even if nothing opened.
    //
    // Each expected heading must sit near the TOP of its screen. The test
    // viewport is only 600px tall, and a ListView does not build the items
    // below the fold, so a heading further down would be missing here even
    // though the screen opened correctly.
    for (final entry in <String, String>{
      'How to Play': 'The goal', // only on the rules screen
      'Settings': 'Reset progress', // only on the settings screen
      'About': 'The game', // only on the about screen
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: '${entry.key} did not open its screen',
      );

      await tester.tap(find.byTooltip('Back to Main Menu'));
      await tester.pumpAndSettle();
      expect(
        find.text('PLAY'),
        findsOneWidget,
        reason: '${entry.key} did not return to the menu',
      );
    }
  });

  // ==========================================================================
  // 2. HOW TO PLAY
  // ==========================================================================

  testWidgets('How to Play describes the card rules, not falling words', (
    WidgetTester tester,
  ) async {
    await mountScreen(tester, const HowToPlayScreen());

    // These 2 are above the fold on the 600px test viewport.
    expect(find.text('The goal'), findsOneWidget);
    expect(find.text('What is on a card'), findsOneWidget);

    // The rest are further down. scrollUntilVisible drags the list in small
    // steps until the target is built, then stops. We use it instead of a
    // fixed drag distance, because a fixed distance breaks as soon as anyone
    // adds a line of text above the target.
    for (final heading in <String>[
      'What the colours mean',
      'How to answer',
      'The "+" button',
      'Pause',
      'Score',
      'Lives',
      'The blinking arrows',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        200, // pixels to drag on each attempt
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(heading), findsOneWidget, reason: 'missing: $heading');
    }
  });

  // ==========================================================================
  // 3. SETTINGS
  // ==========================================================================

  testWidgets('Settings shows 2 disabled audio rows and a live vibration row', (
    WidgetTester tester,
  ) async {
    await mountScreen(tester, const SettingsScreen());

    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Background music'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Reset progress'), findsOneWidget);

    // A Switch with a null onChanged is how Flutter shows "disabled".
    // The 2 audio rows must stay disabled until the game has sound files.
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, 3);
    expect(switches[0].onChanged, isNull, reason: 'Sound effects: disabled');
    expect(switches[1].onChanged, isNull, reason: 'Background music: disabled');
    expect(switches[2].onChanged, isNotNull, reason: 'Vibration: live');
  });

  testWidgets('The vibration switch changes the saved setting', (
    WidgetTester tester,
  ) async {
    await mountScreen(tester, const SettingsScreen());

    // A fresh store means the default, which is on.
    expect(SettingsManager().vibrationEnabled, isTrue);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();

    // The manager holds the new value, and the switch shows it.
    expect(SettingsManager().vibrationEnabled, isFalse);
    final after = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(after[2].value, isFalse);
  });

  testWidgets('Reset progress asks before it erases anything', (
    WidgetTester tester,
  ) async {
    await mountScreen(tester, const SettingsScreen());

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();

    // The dialog must state the loss and offer a way out.
    expect(find.text('Reset progress?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel closes the dialog and erases nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsNothing);
  });

  // ==========================================================================
  // 4. ABOUT
  // ==========================================================================

  testWidgets('About shows the version and the credits', (
    WidgetTester tester,
  ) async {
    await mountScreen(tester, const AboutScreen());

    // kAppVersion must match the version: line in pubspec.yaml. This check
    // fails if someone raises the pubspec version and forgets this screen.
    expect(find.text('Version $kAppVersion'), findsOneWidget);
    expect(find.text('The game'), findsOneWidget);

    // Facts and Credits sit below the fold on the 600px test viewport.
    for (final heading in <String>['Facts', 'Credits']) {
      await tester.scrollUntilVisible(
        find.text(heading),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(heading), findsOneWidget, reason: 'missing: $heading');
    }
  });
}
