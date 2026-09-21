// ============================================================================
// WIDGET TEST FILE
// ============================================================================
// This test checks that the app starts, shows the splash screen, and reaches
// the main menu.
//
// Run it with:  flutter test
//
// WHY THE OLD TEST FAILED (BUG-6 in REDESIGN.md):
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
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_drop/main.dart';

void main() {
  testWidgets('The app starts on the splash screen and reaches the main menu', (
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

    // Let every entrance animation finish, so no timer is left waiting.
    await tester.pumpAndSettle();
  });
}
