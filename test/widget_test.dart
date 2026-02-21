// ============================================================================
// WIDGET TEST FILE
// ============================================================================
// This file contains automated tests for our app's widgets.
//
// Flutter auto-generates this file when you create a new project.
// It originally referenced 'MyApp' (the default demo class name),
// but we renamed our root widget to 'WordDropApp' in main.dart,
// so we need to update this reference.
//
// WHAT ARE TESTS?
// Tests are code that checks other code works correctly.
// You run them with: flutter test
// They help catch bugs before you deploy the app to real users.
//
// For now, this file just contains the default smoke test:
// it checks that the app starts and renders without crashing.
// We'll add more meaningful tests as the game grows.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

// Import our actual root widget (WordDropApp, not the old MyApp)
import 'package:word_drop/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build the root widget and trigger a frame
    // This checks the app can start without throwing any errors
    await tester.pumpWidget(const WordDropApp());

    // If we get here without an exception, the test passes.
    // We don't assert anything specific yet because the splash screen
    // starts an async loading process that's tricky to test at this stage.
    // More detailed tests will be added as the game develops.
  });
}