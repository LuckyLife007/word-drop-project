// ============================================================================
// GAME MANAGER
// ============================================================================
// This file defines the GameManager class, which is the central "brain" of our
// word guessing game. It manages:
// 1. Game state (score, level, lives, current word)
// 2. Word selection using shuffled per-length queues (no mid-level repeats)
// 3. Hint/clue combination tracking (no same combo shown twice in a session)
// 4. Answer checking and scoring
// 5. Level progression with proper word difficulty within each level
//
// KEY CONCEPTS:
// - This is a "manager" class that coordinates game logic.
// - It uses WordBank to get words, but controls WHICH word is shown and WHEN.
// - Words are served from shuffled queues, not picked randomly each time.
// - This prevents repetition within a level while keeping the order unpredictable.
//
// BUG FIXES IN THIS VERSION (branch: fix/game-logic):
//
//   BUG 1 — Level counter not resetting between levels
//   SYMPTOM: Every word in Level 2 showed "position: 21/20" and was 10 letters.
//   CAUSE:   GameManager is a singleton. When Level 1 ended, _wordCounterWithinLevel
//            was left at 20. Level 2 opened a fresh GameScreen but GameManager
//            was never told to start fresh, so the counter stayed at 20 forever.
//   FIX:     Added startLevel(int levelNumber). GameScreen.initState() must call
//            this immediately, passing the level number from LevelConfig.
//
//   BUG 2 — Same word visible on screen twice simultaneously
//   SYMPTOM: Log showed "LIBRARY" selected at position 7/20, then again at 8/20.
//   CAUSE:   Old code picked randomly; had no knowledge of currently falling words.
//   FIX:     getNextWord() accepts a List<String> activeWords parameter. The
//            selection loop skips any word whose text matches an active one.
//
//   BUG 3 — Same word repeating shortly after it just disappeared
//   SYMPTOM: Sequence like banana -> soccer -> banana -> soccer observed in play.
//   CAUSE:   getNextWord() was fully random. It could legally pick BANANA twice
//            in a row because there was no "exhaust others first" rule.
//   ROOT CAUSE (design): Section 3.2 of the documentation specifies that each
//            level should use SHUFFLED POOLS — words served sequentially from a
//            pre-shuffled queue, not picked fresh randomly each time. The previous
//            code never implemented this.
//   FIX:     Replaced random selection with _wordQueues — a Map<int, List<Word>>
//            where each key is a word length (6-10) and each value is a shuffled
//            queue of all words of that length. startLevel() rebuilds all queues.
//            getNextWord() pops from the front of the appropriate queue.
//            A word can only reappear AFTER every other word of the same length
//            has been served first. See _initWordQueues() and _popFromQueue().
//
// ============================================================================

import 'dart:math';
import '../models/word.dart';
import 'word_bank.dart';

// ============================================================================
// WORD WITH COMBINATION CLASS
// ============================================================================
// This class pairs a Word with specific hint and clue indices.
// It represents "which version" of a word the player will see.

/// Represents a word alongside which specific hint and clue to show.
///
/// Each word has 3 hints and 3 clues, giving 9 possible combinations.
/// This class records which combination (hintIndex + clueIndex) was chosen
/// so that the game can avoid showing the same combination twice.
///
/// EXAMPLE:
///   WordWithCombination(
///     word: Word("BANANA", ...),
///     hintIndex: 0,  // shows hint[0] which is "B-N-N-"
///     clueIndex: 2,  // shows clue[2] which is "Monkey's favorite snack"
///   )
class WordWithCombination {
  /// The full Word object (contains the word string, all hints, all clues).
  final Word word;

  /// Index of which hint to display (0, 1, or 2).
  final int hintIndex;

  /// Index of which clue to display (0, 1, or 2).
  final int clueIndex;

  WordWithCombination({
    required this.word,
    required this.hintIndex,
    required this.clueIndex,
  });

  /// The hint string to actually show on the falling word card.
  /// e.g. "B-N-N-" for BANANA with hintIndex 0.
  String get hint => word.getHint(hintIndex);

  /// The clue string to actually show below the hint on the card.
  /// e.g. "Yellow curved fruit" for BANANA with clueIndex 0.
  String get clue => word.getClue(clueIndex);

  /// Compact string representation used as a Map key for tracking usage.
  /// Format: "hintIndex-clueIndex", e.g. "0-2".
  String get combinationKey => '$hintIndex-$clueIndex';

  @override
  String toString() =>
      'WordWithCombination(${word.word}, hint:$hintIndex, clue:$clueIndex)';
}

// ============================================================================
// GAME MANAGER CLASS
// ============================================================================

/// Manages overall game state and word selection logic for Word Drop.
///
/// SINGLETON PATTERN — why?
/// Because we want exactly ONE game state throughout the app's lifetime.
/// If we created a new GameManager each time a screen opened, state from
/// one screen wouldn't carry over to another. A singleton ensures the same
/// object is always returned no matter where in the app you call GameManager().
///
/// IMPORTANT: Because it's a singleton, it does NOT reset itself when a new
/// GameScreen opens. You MUST call GameManager().startLevel(levelNumber) inside
/// GameScreen.initState() so the manager knows which level is beginning.
class GameManager {
  // ==========================================================================
  // SINGLETON SETUP
  // ==========================================================================

  /// Private constructor — no code outside this file can call GameManager._().
  /// This enforces the singleton: there is no way to accidentally create a second one.
  GameManager._();

  /// The one-and-only instance. Created once when the app starts, never again.
  static final GameManager _instance = GameManager._();

  /// Public factory constructor. Every call to GameManager() returns _instance.
  ///
  /// WHY a factory constructor instead of just a static getter?
  /// A factory constructor lets callers write GameManager() which looks like
  /// creating an object. It's the standard Dart singleton pattern and makes
  /// the code consistent with how Flutter developers expect it to look.
  factory GameManager() => _instance;

  // ==========================================================================
  // DEPENDENCIES
  // ==========================================================================

  /// WordBank singleton — our source of all word data.
  final WordBank _wordBank = WordBank();

  /// Random number generator used for shuffling queues and picking combinations.
  final Random _random = Random();

  // ==========================================================================
  // GAME STATE
  // ==========================================================================

  /// Which level is currently being played (1-5).
  int _currentLevel = 1;

  /// The last word returned by getNextWord().
  /// Null when no word has been served yet this level.
  ///
  /// NOTE: the score and the lives live in GameScreen, not here. This class
  /// owns the words only (REDESIGN.md BUG-7).
  WordWithCombination? _currentWord;

  /// How many words the player has correctly completed in this level (0-19).
  ///
  /// THIS DRIVES WORD LENGTH PROGRESSION within the level:
  ///   Position  0- 3 (words  1- 4) -> 6-letter words
  ///   Position  4- 7 (words  5- 8) -> 7-letter words
  ///   Position  8-11 (words  9-12) -> 8-letter words
  ///   Position 12-15 (words 13-16) -> 9-letter words
  ///   Position 16-19 (words 17-20) -> 10-letter words
  ///
  /// The same pattern repeats for every level; difficulty between levels
  /// comes from faster fall/spawn times, not longer words.
  ///
  /// MUST be reset to 0 by startLevel() at the start of each level.
  int _wordCounterWithinLevel = 0;

  // --------------------------------------------------------------------------
  // WORD QUEUES (fix for Bug 3 — anti-repeat logic)
  // --------------------------------------------------------------------------
  // This is the core of the fix for the banana->soccer->banana problem.
  //
  // Structure: Map<int, List<Word>>
  //   Key   = word length (6, 7, 8, 9, or 10)
  //   Value = a shuffled List<Word> acting as a queue
  //
  // HOW IT WORKS:
  //   When a level starts, _initWordQueues() fills each entry with ALL words
  //   of that length from the WordBank, then shuffles them randomly.
  //
  //   When a word of length N is needed, _popFromQueue(N) takes the FIRST
  //   item from _wordQueues[N] and removes it. The next call gets the next
  //   item, and so on — like drawing from a shuffled deck of cards.
  //
  //   When the queue for a length runs out, _popFromQueue() refills and
  //   reshuffles it automatically before drawing the next word. This means
  //   a word can only come back around AFTER every other word of the same
  //   length has been drawn at least once.
  //
  // WHY this beats random selection:
  //   Random selection has no memory. It can legally pick BANANA three times
  //   in a row because each pick is independent. Queues guarantee exhaust-
  //   before-repeat: BANANA can only reappear after all other words of the
  //   same length have been drawn first.
  //
  // Documentation reference: Section 3.2
  //   "Each level starts with fresh, shuffled pools for all word lengths.
  //    Words are consumed sequentially from shuffled pools.
  //    No word can repeat within a single level session."
  final Map<int, List<Word>> _wordQueues = {};

  // --------------------------------------------------------------------------
  // COMBINATION TRACKING (persists across levels in a session)
  // --------------------------------------------------------------------------
  // Tracks which hint/clue pairs have already been shown for each word.
  //
  // Structure: Map<String, Set<String>>
  //   Key   = word string, e.g. "BANANA"
  //   Value = Set of "hintIndex-clueIndex" strings already used this session
  //           e.g. {"0-0", "1-2"}
  //
  // WHY a Set (not List)?
  //   Sets automatically prevent duplicates and have O(1) membership checks.
  //   "Has this combo been used?" is the most common question, so O(1) matters.
  //
  // WHY persist across levels (not reset on startLevel)?
  //   So the player sees fresh combinations each time they encounter a word,
  //   even if that word appears in multiple levels.
  final Map<String, Set<String>> _usedCombinations = {};

  // ==========================================================================
  // PUBLIC GETTERS
  // ==========================================================================

  int get currentLevel => _currentLevel;
  WordWithCombination? get currentWord => _currentWord;
  int get wordCounterWithinLevel => _wordCounterWithinLevel;

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initialises GameManager at app startup (called from main/splash screen).
  ///
  /// Ensures WordBank is loaded before any word selection can happen.
  Future<void> initialize() async {
    if (!_wordBank.isLoaded) {
      await _wordBank.loadWords();
    }
    resetGame();
    print('GameManager initialized');
  }

  /// Full reset — brings the game back to Level 1, word 0.
  ///
  /// Use this for a "New Game" feature. For starting a specific level,
  /// call startLevel() instead — it's more precise.
  void resetGame() {
    _currentLevel = 1;
    _currentWord = null;
    _wordCounterWithinLevel = 0;
    _wordQueues.clear();
    // _usedCombinations intentionally NOT cleared — combination history
    // persists across attempts so the player sees variety all session.
    print('Game fully reset to Level 1');
  }

  // --------------------------------------------------------------------------
  // FIX FOR BUG 1 + BUG 3 — startLevel()
  // --------------------------------------------------------------------------
  /// Resets GameManager state to begin a specific level from scratch.
  ///
  /// WHEN TO CALL:
  ///   Inside GameScreen.initState(), before any words are spawned:
  ///     GameManager().startLevel(widget.level.levelNumber);
  ///
  /// WHY THIS IS NECESSARY:
  ///   GameManager is a singleton — it lives for the whole app session.
  ///   When a player finishes Level 1 and opens Level 2, a new GameScreen
  ///   widget is created but GameManager is the same object it was during
  ///   Level 1. Without this call, _wordCounterWithinLevel stays at 20,
  ///   _wordQueues still contain leftover Level 1 queue state, and every
  ///   word in Level 2 comes out as a 10-letter word at "position 21/20".
  ///
  /// WHAT IT RESETS:
  ///   - _currentLevel           -> the chosen level number
  ///   - _wordCounterWithinLevel -> 0 (starts counting from word 1 again)
  ///   - _wordQueues             -> freshly shuffled queues for all lengths (Bug 3 fix)
  ///   - _currentWord            -> null
  ///
  /// The score and the lives belong to GameScreen, so they are not reset here.
  ///
  /// [levelNumber] — which level is starting (1-5), from LevelConfig.levelNumber.
  void startLevel(int levelNumber) {
    _currentLevel = levelNumber.clamp(1, 5);
    _wordCounterWithinLevel = 0;
    _currentWord = null;

    // Build fresh shuffled queues for every word length.
    // This is what prevents within-level repetition (Bug 3 fix).
    _initWordQueues();

    print(
      'GameManager: startLevel($_currentLevel) — '
      'queues rebuilt, counter reset to 0',
    );
  }

  // ==========================================================================
  // WORD QUEUES — Private helpers
  // ==========================================================================

  /// Builds a freshly shuffled word queue for every length category (6-10).
  ///
  /// Called by startLevel() so each level starts with a clean, shuffled deck.
  ///
  /// Think of this like shuffling 5 separate decks of cards (one per word
  /// length) at the start of each level. Words are then drawn from the front
  /// of each deck in order, guaranteeing no word repeats until the whole
  /// deck has been dealt.
  void _initWordQueues() {
    _wordQueues.clear();

    // Build a queue for each of the 5 word lengths used in the game (6 to 10).
    for (int length = 6; length <= 10; length++) {
      // Get all words of this length from the WordBank.
      // getWordsByLength() returns a sorted list — we'll shuffle it below.
      List<Word> words = _wordBank.getWordsByLength(length);

      if (words.isEmpty) {
        print('Warning: No words of length $length found in WordBank');
        continue;
      }

      // Copy the list so we don't accidentally shuffle WordBank's own internal
      // list (which other parts of the app might rely on being stable).
      // Then shuffle it randomly so the order is unpredictable each level.
      List<Word> shuffled = List.from(words);
      shuffled.shuffle(_random);

      _wordQueues[length] = shuffled;

      print('Queue for length $length: ${shuffled.length} words ready');
    }
  }

  /// Pops the next word from the queue for a given word length.
  ///
  /// Takes from the FRONT of the queue (index 0) and removes it, just like
  /// drawing a card off the top of a shuffled deck.
  ///
  /// If the queue runs out (all words of this length have been shown), it
  /// automatically refills and reshuffles before drawing the next word.
  /// This is the "cycle through all before repeating" guarantee.
  ///
  /// [length]      — word length needed (6, 7, 8, 9, or 10).
  /// [activeWords] — word strings currently on screen; pop will skip these
  ///                 to prevent showing the same word twice at once (Bug 2 fix).
  ///
  /// Returns null only if WordBank has no words of the requested length at all.
  Word? _popFromQueue(int length, List<String> activeWords) {
    // Ensure the queue exists and is populated.
    // If it's empty, ALL words of this length have been shown once this
    // level. Time to refill and reshuffle for another round.
    if (!_wordQueues.containsKey(length) || _wordQueues[length]!.isEmpty) {
      print('Queue for length $length exhausted — refilling and reshuffling');
      List<Word> allWords = _wordBank.getWordsByLength(length);
      if (allWords.isEmpty) return null; // Nothing in word bank for this length
      allWords = List.from(allWords)..shuffle(_random);
      _wordQueues[length] = allWords;
    }

    List<Word> queue = _wordQueues[length]!;

    // Search for the first word in the queue that is NOT currently on screen.
    //
    // WHY scan instead of just taking index 0?
    // The word at the front of the queue might already be falling on screen.
    // We scan forward to find the first safe word, preserving the queue order
    // for all other words (no skipped words are discarded).
    for (int i = 0; i < queue.length; i++) {
      if (!activeWords.contains(queue[i].word)) {
        // This word is not currently on screen — safe to use.
        // Remove it from the queue at position i and return it.
        return queue.removeAt(i);
      }
    }

    // EDGE CASE: Every word remaining in the queue is currently on screen.
    // This would require as many active words as there are queued words of
    // this length — extremely unlikely with the 10-word cap, but we handle
    // it gracefully. Just take the front word rather than returning null
    // (returning null would silently stop spawning words entirely).
    print(
      'Warning: All queued words of length $length are currently active. '
      'Spawning a duplicate as a last resort.',
    );
    return queue.removeAt(0);
  }

  // ==========================================================================
  // WORD SELECTION — Public interface
  // ==========================================================================

  /// Returns the next word for the player to guess.
  ///
  /// HOW IT WORKS:
  ///   1. Determines required word length from _wordCounterWithinLevel.
  ///   2. Pops the next word from the shuffled queue for that length,
  ///      skipping any words already on screen (Bug 2 fix).
  ///   3. Finds an unused hint/clue combination for that word.
  ///   4. Marks the combination as used.
  ///   5. Returns the WordWithCombination ready for display.
  ///
  /// [activeWords] — list of answer strings currently falling on screen.
  ///   How to pass it from GameScreen:
  ///     _fallingWords.map((w) => w.answer).toList()
  ///   This prevents the same word appearing twice at once (Bug 2 fix).
  ///
  ///   WHY pass this from GameScreen rather than tracking it inside GameManager?
  ///   GameScreen owns the _fallingWords list. GameManager knows nothing about
  ///   FallingWord objects. Passing data as a parameter keeps each class
  ///   responsible for only its own data — cleaner and easier to test.
  ///
  /// Returns null only if WordBank is empty (should never happen in production).
  WordWithCombination? getNextWord({List<String> activeWords = const []}) {
    // STEP 1: Determine the required word length for this position in the level.
    int wordLength = _getLengthForCurrentPosition();

    // STEP 2: Pop the next word from the shuffled queue for this length.
    //         _popFromQueue handles the active-word skip (Bug 2) and queue
    //         refill when all words have been cycled through (Bug 3).
    Word? selectedWord = _popFromQueue(wordLength, activeWords);

    if (selectedWord == null) {
      // WordBank has no words of this length — something is very wrong.
      print('Error: Could not get a word of length $wordLength from queue');
      return null;
    }

    // STEP 3: Find an unused hint/clue combination for this word.
    List<String> availableCombinations = _getAvailableCombinations(
      selectedWord,
    );

    // Edge case: all 9 combinations for this word have been used this session.
    // This would require seeing the same word at least 9 times — very rare,
    // but we reset gracefully instead of getting stuck.
    if (availableCombinations.isEmpty) {
      print('All 9 combinations used for ${selectedWord.word} — resetting');
      _usedCombinations[selectedWord.word]?.clear();
      availableCombinations = _getAvailableCombinations(selectedWord);
    }

    // STEP 4: Pick a random combination from those still available.
    String selectedCombination =
        availableCombinations[_random.nextInt(availableCombinations.length)];

    // STEP 5: Mark it as used so it won't be picked again this session.
    _markCombinationUsed(selectedWord, selectedCombination);

    // STEP 6: Parse "hintIndex-clueIndex" into two integers.
    // Example: "0-2" splits on "-" to give parts[0]="0", parts[1]="2"
    List<String> parts = selectedCombination.split('-');
    int hintIndex = int.parse(parts[0]);
    int clueIndex = int.parse(parts[1]);

    // STEP 7: Bundle everything into a WordWithCombination and return it.
    _currentWord = WordWithCombination(
      word: selectedWord,
      hintIndex: hintIndex,
      clueIndex: clueIndex,
    );

    print(
      'Selected word: ${_currentWord!.word.word} '
      '(length: $wordLength, position: ${_wordCounterWithinLevel + 1}/20)',
    );

    return _currentWord;
  }

  /// Determines the required word length based on position within the level.
  ///
  /// The length progression is identical across all 5 levels:
  ///   Words  1- 4 (counter  0- 3) -> 6 letters
  ///   Words  5- 8 (counter  4- 7) -> 7 letters
  ///   Words  9-12 (counter  8-11) -> 8 letters
  ///   Words 13-16 (counter 12-15) -> 9 letters
  ///   Words 17-20 (counter 16-19) -> 10 letters
  ///
  /// Difficulty between levels is expressed by timing (faster spawn/fall),
  /// NOT by showing harder words. The word pattern is the same for every level.
  int _getLengthForCurrentPosition() {
    if (_wordCounterWithinLevel < 4) return 6;
    if (_wordCounterWithinLevel < 8) return 7;
    if (_wordCounterWithinLevel < 12) return 8;
    if (_wordCounterWithinLevel < 16) return 9;
    // Positions 16-19 (and technically anything >=16 as a safety net,
    // though startLevel() always resets the counter before it gets that far).
    return 10;
  }

  // ==========================================================================
  // COMBINATION TRACKING — Private helpers
  // ==========================================================================

  /// Returns all 9 possible "hintIndex-clueIndex" combinations for a word,
  /// filtered to only those NOT already used in this session.
  List<String> _getAvailableCombinations(Word word) {
    // All 9 possible combinations for any word (3 hints x 3 clues = 9 total).
    const List<String> allCombinations = [
      '0-0', '0-1', '0-2', // hint 0 paired with each of the 3 clues
      '1-0', '1-1', '1-2', // hint 1 paired with each of the 3 clues
      '2-0', '2-1', '2-2', // hint 2 paired with each of the 3 clues
    ];

    // Retrieve the set of already-used combinations for this word.
    // If the word has never been shown, this will be an empty set.
    Set<String> usedForWord = _usedCombinations[word.word] ?? {};

    // Return only the combinations NOT in the used set.
    return allCombinations
        .where((combo) => !usedForWord.contains(combo))
        .toList();
  }

  /// Records a hint/clue combination as used so it won't be selected again.
  void _markCombinationUsed(Word word, String combination) {
    // putIfAbsent creates the Set for this word if one doesn't exist yet.
    // Then we add the combination string to that set.
    _usedCombinations.putIfAbsent(word.word, () => {});
    _usedCombinations[word.word]!.add(combination);
  }

  // ==========================================================================
  // WORD COUNTER
  // ==========================================================================

  /// Advances the word-position counter after the player answers correctly.
  ///
  /// GameScreen calls this on every match. The counter decides the word length
  /// of the NEXT card, which GameScreen cannot work out by itself:
  ///   words 1-4   → 6 letters   (counter 0-3)
  ///   words 5-8   → 7 letters   (counter 4-7)
  ///   words 9-12  → 8 letters   (counter 8-11)
  ///   words 13-16 → 9 letters   (counter 12-15)
  ///   words 17-20 → 10 letters  (counter 16-19)
  ///
  /// GameScreen owns the score, the lives and the end of a level. This class
  /// owns only the words. Keeping the two apart stops the double counting that
  /// BUG-7 described in REDESIGN.md.
  void recordCorrectWord() {
    _wordCounterWithinLevel++;
    print(
      '📝 GameManager: word counter advanced to $_wordCounterWithinLevel/20',
    );
  }

  // ==========================================================================
  // DEBUGGING
  // ==========================================================================

  /// Prints a full snapshot of the current game state to the console.
  /// Call GameManager().printGameState() anywhere while debugging.
  void printGameState() {
    print('=' * 50);
    print('GAME STATE');
    print('Level: $_currentLevel | Position: $_wordCounterWithinLevel/20');
    print('Current Word: ${_currentWord?.word.word ?? 'None'}');
    print('\nWORD QUEUE SIZES (words remaining before a repeat):');
    for (int len = 6; len <= 10; len++) {
      int remaining = _wordQueues[len]?.length ?? 0;
      print('  Length $len: $remaining words remaining in queue');
    }
    int totalCombos = _usedCombinations.values.fold(
      0,
      (sum, set) => sum + set.length,
    );
    print(
      '\nCombination history: '
      '${_usedCombinations.length} words, $totalCombos combos used this session',
    );
    print('=' * 50);
  }
}
