// ============================================================================
// MAIN.DART - APP ENTRY POINT
// ============================================================================
// This is the very first file Flutter runs when the app starts.
// It does three things:
//   1. Locks the screen to portrait orientation (per documentation Section 1.2)
//   2. Pre-loads the word bank from the JSON file
//   3. Shows a splash/loading screen, then transitions to the Main Menu
//
// It also declares the app-wide RouteObserver (see section below).
//
// WHY THIS FILE EXISTS:
// Every Flutter app needs a main() function as its starting point.
// Think of it like the "front door" of the app - everything begins here.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for locking screen orientation
import 'managers/word_bank.dart';       // Our word bank loader
import 'screens/main_menu_screen.dart'; // The main menu screen we'll show after loading

// ============================================================================
// ROUTE OBSERVER (app-wide singleton)
// ============================================================================
// A RouteObserver watches every navigation event in the app (pushes, pops,
// replacements) and notifies any screen that has subscribed to it.
//
// HOW IT WORKS:
//   1. We declare it here as a top-level variable so it's accessible from
//      any screen that imports main.dart.
//   2. We pass it to MaterialApp.navigatorObservers below — this wires it
//      into Flutter's Navigator so it receives every route change.
//   3. Screens that need to react to becoming visible again (like
//      LevelSelectionScreen) mixin RouteAware and subscribe to this observer
//      in didChangeDependencies(). When the screen above them is popped,
//      their didPopNext() callback fires and they can call setState().
//
// WHY WE NEED IT (the Level 5 bug):
//   When the player completes Level 4 and taps "Continue", GameScreen calls
//   Navigator.pushReplacement() to replace itself with a fresh Level 5 game.
//   pushReplacement immediately completes Level 4's route, which fires Level
//   Selection's Navigator.push().then() callback — BEFORE Level 5 is even
//   played. When Level 5 is eventually completed and popped, the .then()
//   does NOT fire again (it already completed). Level Selection therefore
//   never rebuilds to show Level 5 as COMPLETED.
//   RouteObserver.didPopNext() fires reliably for ALL pops of the route
//   immediately above — it's the correct solution for this class of problem.
//
// TYPE EXPLANATION:
//   RouteObserver<ModalRoute<void>>:
//   - RouteObserver is generic on the route type it watches.
//   - ModalRoute<void> covers every full-page route (MaterialPageRoute,
//     PageRouteBuilder, etc.), which is what we use throughout the app.
//   - Using <ModalRoute<void>> instead of just <Route<dynamic>> ensures the
//     observer only fires for full-page routes, not popup menus or dialogs.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ============================================================================
// APP ENTRY POINT
// ============================================================================

/// The main() function is where Dart/Flutter starts executing your app.
/// The 'async' keyword means this function can do things that take time
/// (like loading files) without freezing everything else.
void main() async {
  // WidgetsFlutterBinding.ensureInitialized() must be called before doing
  // anything with Flutter's system features (like orientation lock or
  // loading assets). It "wires up" the Flutter framework to the device.
  // Without this line, calling SystemChrome below would crash the app.
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait mode only.
  // The documentation (Section 1.2) specifies portrait-only for consistent gameplay.
  // We do this here at startup so it's enforced from the very first frame.
  // DeviceOrientation.portraitUp = phone held normally, right-side up
  // DeviceOrientation.portraitDown = phone held upside-down (we block this too
  //   so the screen doesn't flip if the player tilts their phone)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Start the Flutter app by running our root widget.
  // runApp() takes a widget and makes it fill the entire screen.
  runApp(const WordDropApp());
}

// ============================================================================
// ROOT APP WIDGET
// ============================================================================

/// WordDropApp is the root of our entire application.
///
/// WHY StatelessWidget?
/// This widget never changes - it just sets up the app's theme and routing.
/// A StatelessWidget is simpler and more efficient when the widget doesn't
/// need to update itself over time.
///
/// Think of this as the "container" that holds everything else.
class WordDropApp extends StatelessWidget {
  const WordDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The name of the app (appears in task switcher on Android)
      title: 'Word Drop',

      // Hide the "DEBUG" banner that Flutter shows in the top-right corner
      // during development. We hide it so screenshots look clean.
      debugShowCheckedModeBanner: false,

      // ======================================================================
      // THEME
      // ======================================================================
      // ThemeData sets the default visual style for the entire app.
      // We can override specific styles per-widget, but this sets sensible
      // defaults so we're not styling everything from scratch.
      theme: ThemeData(
        // colorScheme defines the set of colors Flutter uses throughout the app.
        // We use deepPurple as our seed color since our background gradient
        // (from the docs) is blue-purple (#667eea to #764ba2).
        // 'fromSeed' generates a harmonious color palette from one base color.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),

        // useMaterial3: true enables the latest Material Design (version 3).
        // This gives us more modern-looking widgets and better defaults.
        useMaterial3: true,

        // Set the default text theme to use white text, since most of our
        // screens have dark gradient backgrounds.
        // We'll override this per-widget where needed.
        textTheme: const TextTheme(
          // displayLarge is used for big titles (like "Word Drop")
          displayLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          // bodyLarge is used for regular text
          bodyLarge: TextStyle(color: Colors.white),
        ),
      ),

      // ======================================================================
      // NAVIGATOR OBSERVERS
      // ======================================================================
      // Observers watch every navigation event (push, pop, replace) in the app.
      // We register our app-wide routeObserver here so that any screen which
      // mixes in RouteAware and subscribes to it gets lifecycle callbacks like
      // didPopNext(). See the routeObserver declaration at the top of this file
      // for the full explanation of why this is needed.
      navigatorObservers: [routeObserver],

      // The first screen to show when the app opens.
      // SplashScreen handles loading the word bank, then navigates to MainMenuScreen.
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================

/// The SplashScreen is shown while the app is loading its assets.
///
/// Per documentation Section 2.1:
/// - Shows "Word Drop" logo with brief animation (2-3 seconds)
/// - Shows a loading indicator while game assets load
/// - Smoothly transitions to the main menu when loading is complete
///
/// WHY StatefulWidget?
/// Unlike StatelessWidget, a StatefulWidget can change over time.
/// The splash screen needs to:
///   - Track whether loading is complete
///   - Animate the logo fading in
///   - Navigate away when done
/// All of these require "state" - data that changes while the widget is alive.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  // Every StatefulWidget needs a createState() method.
  // It creates the companion State object that holds all the changeable data.
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// _SplashScreenState holds all the logic and changeable data for SplashScreen.
///
/// The underscore (_) prefix is Dart's convention for "private" - this class
/// can only be used inside this file.
///
/// 'with SingleTickerProviderStateMixin' adds animation support to this State.
/// Flutter animations need a "ticker" - something that fires every frame (60x/sec).
/// This mixin provides that ticker. We use it to animate the logo fading in.
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // ============================================================================
  // STATE VARIABLES
  // These are the pieces of data that can change and affect what's displayed.
  // ============================================================================

  /// Controls the fade-in animation for the logo and title.
  /// An AnimationController manages timing - it goes from 0.0 to 1.0 over time.
  late AnimationController _fadeController;

  /// The actual animation derived from _fadeController.
  /// CurvedAnimation applies an "easing curve" - in this case, it starts slow
  /// and speeds up (easeIn), which looks more natural than a linear fade.
  late Animation<double> _fadeAnimation;

  /// Tracks whether the word bank has finished loading.
  /// We use this to show the right loading message.
  bool _isLoaded = false;

  // ============================================================================
  // LIFECYCLE METHODS
  // Flutter calls these at specific moments in the widget's life.
  // ============================================================================

  /// initState() is called once when this widget is first created.
  /// Use it for setup that only needs to happen once.
  @override
  void initState() {
    super.initState(); // Always call super.initState() first

    // Set up the fade animation:
    // - vsync: this  →  use THIS widget's ticker (from the mixin we added)
    // - duration: 800ms  →  the logo fades in over 0.8 seconds
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create a curved animation from the controller.
    // Curves.easeIn means: starts slow, ends fast (gentle fade-in effect)
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start the fade-in animation and load the word bank simultaneously.
    // We use _initializeApp() to handle both tasks at once.
    _initializeApp();
  }

  /// Handles app initialization: starts the animation and loads the word bank.
  ///
  /// WHY 'async'?
  /// Loading the word bank from a file takes a moment. Using async/await means
  /// Flutter can keep the UI responsive while loading happens in the background,
  /// instead of freezing until the file is read.
  Future<void> _initializeApp() async {
    // Start the logo fade-in immediately (don't wait for loading to finish)
    _fadeController.forward();

    // Load the word bank from assets/data/word_bank.json
    // 'await' pauses this function until loading completes,
    // but the rest of the app (including the animation) keeps running.
    await WordBank().loadWords();

    // Mark loading as complete so the UI can update
    // setState() tells Flutter "something changed, please redraw"
    if (mounted) {
      // 'mounted' checks the widget is still on screen before calling setState.
      // This prevents errors if the user somehow navigated away during loading.
      setState(() {
        _isLoaded = true;
      });
    }

    // Wait for a minimum display time so the splash screen doesn't flash
    // away instantly on fast devices. The docs say 2-3 seconds total.
    // We already spent ~0.8s on the fade-in, so we wait ~1.5s more.
    await Future.delayed(const Duration(milliseconds: 1500));

    // Navigate to the Main Menu screen.
    // We check 'mounted' again because the delay above means time has passed.
    if (mounted) {
      _navigateToMainMenu();
    }
  }

  /// Navigates from the splash screen to the main menu.
  ///
  /// We use a FadeTransition as specified in Section 6.4 (300ms for menus).
  /// PageRouteBuilder lets us define a custom transition animation.
  void _navigateToMainMenu() {
    Navigator.of(context).pushReplacement(
      // PageRouteBuilder lets us customize the transition animation
      PageRouteBuilder(
        // How long the transition animation takes (docs: 300ms for menus)
        transitionDuration: const Duration(milliseconds: 300),

        // pageBuilder defines WHAT screen to navigate to
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainMenuScreen(),

        // transitionsBuilder defines HOW the transition looks
        // 'animation' goes from 0.0 to 1.0 during the transition
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // FadeTransition makes the new screen fade in
          // This matches Section 6.4: "FadeTransition (300ms) for menus"
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// dispose() is called when this widget is permanently removed from the screen.
  /// Always dispose AnimationControllers to free up memory.
  /// Forgetting this causes memory leaks - the animation keeps running in the background.
  @override
  void dispose() {
    _fadeController.dispose(); // Free animation resources
    super.dispose();           // Always call super.dispose() last
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  /// build() describes what this widget looks like.
  /// Flutter calls this every time it needs to draw (or redraw) the widget.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the default white/grey background - we'll paint our own
      backgroundColor: Colors.transparent,

      body: Container(
        // Fill the entire screen with our sky gradient background.
        // This matches the color palette in Section 6.2:
        // "LinearGradient from #667eea (top) to #764ba2 (bottom)"
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,    // Gradient starts at the top
            end: Alignment.bottomCenter,   // Gradient ends at the bottom
            colors: [
              Color(0xFF667eea), // Blue-purple (top of sky)
              Color(0xFF764ba2), // Deep purple (bottom of sky)
            ],
          ),
        ),

        // Center everything on screen
        child: Center(
          // FadeTransition makes everything inside fade in using our animation
          child: FadeTransition(
            opacity: _fadeAnimation,

            child: Column(
              // Center children vertically within the column
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ============================================================
                // GAME TITLE
                // ============================================================
                // Section 6.2 specifies: "Large (~48sp), bold sans-serif,
                // centered with subtle shadow"
                const Text(
                  'Word Drop',
                  style: TextStyle(
                    fontSize: 56,                   // Large, prominent title
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    // Subtle text shadow for depth (mentioned in docs)
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Color(0x66000000), // Semi-transparent black
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                    // Letter spacing makes the title feel more "game-like"
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: 12), // Space between title and tagline

                // Tagline - small subtitle under the title
                const Text(
                  'Complete the words before they fall!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xCCFFFFFF), // White with 80% opacity
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 60), // Space before loading indicator

                // ============================================================
                // LOADING INDICATOR
                // ============================================================
                // Show a spinner while loading, change to a checkmark when done.
                // This gives the player visual feedback that something is happening.
                if (!_isLoaded)
                  // CircularProgressIndicator is Flutter's built-in loading spinner
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3, // Thinner than default, looks more elegant
                  )
                else
                  // Once loaded, show a checkmark so the player knows it's ready
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF4CAF50), // Green (success color from docs)
                    size: 40,
                  ),

                const SizedBox(height: 16),

                // Loading status text
                Text(
                  _isLoaded ? 'Ready!' : 'Loading...',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xCCFFFFFF), // White with 80% opacity
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}