// ============================================================================
// GAME MANAGER
// ============================================================================
// This file defines the GameManager class, which is the central "brain" of our
// word guessing game. It manages:
// 1. Game state (score, level, lives, current word)
// 2. Word selection with hint/clue combination tracking
// 3. Answer checking and scoring
// 4. Level progression with proper word difficulty within each level
//
// KEY CONCEPTS:
// - This is a "manager" class that coordinates game logic
// - It uses the WordBank to get words but tracks which combinations are used
// - It ensures players don't see the same word/hint/clue combo twice in a session
// - FIXED: Now properly implements word length progression WITHIN each level
// ============================================================================

import 'dart:math';
import '../models/word.dart';
import 'word_bank.dart';

// ============================================================================
// WORD WITH COMBINATION CLASS
// ============================================================================
// This class pairs a Word with specific hint and clue indices
// It represents "which version" of a word the player will see

/// Represents a word along with which hint and clue to show
///
/// Since each word has 3 hints and 3 clues, this class specifies
/// WHICH hint (0, 1, or 2) and WHICH clue (0, 1, or 2) to display
///
/// EXAMPLE:
/// WordWithCombination(
///   word: Word("BANANA", ...),
///   hintIndex: 0,  // Show first hint: "B-N-N-"
///   clueIndex: 2,  // Show third clue: "Monkey's favorite snack"
/// )
class WordWithCombination {
  /// The word object containing all data
  final Word word;

  /// Which hint to show (0, 1, or 2)
  /// This maps to indices in word.hints
  final int hintIndex;

  /// Which clue to show (0, 1, or 2)
  /// This maps to indices in word.clues
  final int clueIndex;

  /// Creates a word with combination instance
  WordWithCombination({
    required this.word,
    required this.hintIndex,
    required this.clueIndex,
  });

  /// Gets the hint string to display
  ///
  /// A hint is a hidden letter pattern showing part of the word
  /// Example: If hintIndex = 0 and word is BANANA, returns "B-N-N-"
  String get hint => word.getHint(hintIndex);

  /// Gets the clue string to display
  ///
  /// Example: If clueIndex = 2 and word is BANANA, returns "Monkey's favorite snack"
  String get clue => word.getClue(clueIndex);

  /// Returns the combination as a string for tracking purposes
  ///
  /// Format: "hintIndex-clueIndex"
  /// Example: "0-2" means hint 0, clue 2
  String get combinationKey => '$hintIndex-$clueIndex';

  /// String representation for debugging
  @override
  String toString() {
    return 'WordWithCombination(${word.word}, hint: $hintIndex, clue: $clueIndex)';
  }
}

// ============================================================================
// GAME MANAGER CLASS
// ============================================================================

/// Manages the overall game state and logic for Word Drop
///
/// SINGLETON PATTERN:
/// Like WordBank, we use a singleton to ensure only one game state exists
/// This prevents confusion from multiple game instances
class GameManager {
  // ==========================================================================
  // SINGLETON SETUP
  // ==========================================================================

  /// Private constructor
  GameManager._();

  /// The single instance
  static final GameManager _instance = GameManager._();

  /// Factory constructor returns the singleton instance
  factory GameManager() {
    return _instance;
  }

  // ==========================================================================
  // DEPENDENCIES
  // ==========================================================================

  /// Reference to the WordBank for getting words
  final WordBank _wordBank = WordBank();

  /// Random number generator for selecting combinations
  final Random _random = Random();

  // ==========================================================================
  // GAME STATE PROPERTIES
  // ==========================================================================

  /// Current level (starts at 1)
  /// Level determines spawn rate and fall time:
  /// - Level 1: Slow spawn, long fall time
  /// - Level 2: Faster spawn, shorter fall time
  /// - ...continues to...
  /// - Level 5: Very fast spawn, very short fall time
  ///
  /// Word LENGTH is determined by position within level, NOT by level number
  int _currentLevel = 1;

  /// Current score (starts at 0)
  /// Players earn 5 points per correct word
  /// Score resets when advancing to next level
  int _score = 0;

  /// Number of lives remaining (starts at 3 for Level 1)
  /// Lives increase with each level:
  /// - Level 1: 3 lives
  /// - Level 2: 4 lives
  /// - Level 3: 5 lives
  /// - Level 4: 6 lives
  /// - Level 5: 7 lives
  ///
  /// Player loses 1 life when a word hits the ground
  /// Game ends when lives reach 0
  int _lives = 3;

  /// The current word being guessed
  /// Null when no active word (e.g., between rounds or game over)
  WordWithCombination? _currentWord;

  /// Tracks which word number we're on within the current level (0-19)
  ///
  /// IMPORTANT: This tracks position WITHIN the level, not across all words
  /// Think of it as: "This is word #N of 20 in the current level"
  ///
  /// Examples:
  /// - Word 1 of any level = _wordCounterWithinLevel = 0
  /// - Word 2 of any level = _wordCounterWithinLevel = 1
  /// - Word 20 of any level = _wordCounterWithinLevel = 19
  ///
  /// This counter is used to determine word difficulty progression:
  /// - Counter 0-3 (Words 1-4): 6 letters (easiest)
  /// - Counter 4-7 (Words 5-8): 7 letters
  /// - Counter 8-11 (Words 9-12): 8 letters
  /// - Counter 12-15 (Words 13-16): 9 letters
  /// - Counter 16-19 (Words 17-20): 10 letters (hardest)
  ///
  /// Resets to 0 when advancing to the next level
  ///
  /// WHY WE NEED THIS:
  /// According to documentation, each level should have the SAME word
  /// progression pattern (6→7→8→9→10 letters). The difficulty comes from:
  /// 1. Faster spawn rates between levels (timing)
  /// 2. More lives to compensate (balancing)
  /// NOT from using different word lengths for different levels
  int _wordCounterWithinLevel = 0;

  // ==========================================================================
  // COMBINATION TRACKING
  // ==========================================================================
  // This is the key feature that prevents showing the same word/hint/clue
  // combination twice in a session

  /// Tracks which combinations have been used for each word
  ///
  /// Structure:
  /// {
  ///   "BANANA": {"0-0", "0-2", "1-1"},  // These combos already shown
  ///   "GUITAR": {"2-1"},
  /// }
  ///
  /// Key = word (e.g., "BANANA")
  /// Value = Set of combination strings (e.g., "0-0" = hint 0, clue 0)
  ///
  /// We use a Set (not List) because:
  /// - Sets don't allow duplicates
  /// - Checking if a combo exists is faster with Sets
  final Map<String, Set<String>> _usedCombinations = {};

  // ==========================================================================
  // PUBLIC GETTERS (READ-ONLY ACCESS TO STATE)
  // ==========================================================================

  /// Gets the current level
  int get currentLevel => _currentLevel;

  /// Gets the current score
  int get score => _score;

  /// Gets remaining lives
  int get lives => _lives;

  /// Gets the current word (null if no active word)
  WordWithCombination? get currentWord => _currentWord;

  /// Gets which word we're on within the current level (0-19)
  /// This is primarily for UI purposes
  int get wordCounterWithinLevel => _wordCounterWithinLevel;

  /// Checks if the game is over (no lives left)
  bool get isGameOver => _lives <= 0;

  // ==========================================================================
  // GAME INITIALIZATION
  // ==========================================================================

  /// Initializes the game manager
  ///
  /// This should be called when the app starts, after WordBank is loaded
  /// It resets the game state to starting values
  Future<void> initialize() async {
    // Make sure WordBank is loaded
    if (!_wordBank.isLoaded) {
      await _wordBank.loadWords();
    }

    // Reset game state
    resetGame();

    print('🎮 GameManager initialized');
  }

  /// Resets the game to starting state
  ///
  /// Call this to start a new game after game over
  void resetGame() {
    _currentLevel = 1;
    _score = 0;
    _lives = 3;  // Level 1 always starts with 3 lives
    _currentWord = null;
    _wordCounterWithinLevel = 0;  // Reset word counter to beginning
    
    // Note: We do NOT clear _usedCombinations here
    // Combinations persist for the entire session (until app is closed)

    print('🔄 Game reset to starting state');
  }

  /// Clears all used combinations
  ///
  /// This is separate from resetGame because we want combinations to persist
  /// across multiple game attempts in the same session
  ///
  /// Call this only when you want a completely fresh start
  /// (e.g., when implementing a "Clear History" feature)
  void clearCombinationHistory() {
    _usedCombinations.clear();
    print('🗑️ Combination history cleared');
  }

  // ==========================================================================
  // WORD SELECTION WITH COMBINATION TRACKING
  // ==========================================================================

  /// Gets the next word for the player to guess
  ///
  /// This method:
  /// 1. Determines word difficulty based on POSITION within level
  /// 2. Selects a random word of that difficulty
  /// 3. Finds an unused hint/clue combination for that word
  /// 4. Marks the combination as used
  /// 5. Returns the word with the selected combination
  ///
  /// Returns null if no words available (should never happen with 100 words)
  WordWithCombination? getNextWord() {
    // STEP 1: Determine word length based on POSITION WITHIN LEVEL
    // This is the FIX: we now use _wordCounterWithinLevel instead of _currentLevel
    int wordLength = _getLengthForCurrentPosition();

    // STEP 2: Try to find a word with available combinations
    Word? selectedWord;
    List<String> availableCombinations = [];

    // We'll try up to 20 times to find a suitable word
    // This handles edge cases where many words have exhausted combinations
    for (int attempt = 0; attempt < 20; attempt++) {
      // Get a random word of the appropriate difficulty
      selectedWord = _wordBank.getRandomWordByLength(wordLength);

      // If WordBank couldn't provide a word, return null
      if (selectedWord == null) {
        print('❌ No words available for length $wordLength');
        return null;
      }

      // Check what combinations are available for this word
      availableCombinations = _getAvailableCombinations(selectedWord);

      // If this word has available combinations, use it!
      if (availableCombinations.isNotEmpty) {
        break;
      }

      // Otherwise, try another word
    }

    // STEP 3: If no word has available combinations, reset the most-used word
    // This is a fallback for when all words have been exhausted
    if (availableCombinations.isEmpty) {
      print(
        '⚠️ All combinations exhausted, resetting least-recently-used word',
      );
      _resetLeastUsedWord(wordLength);
      // Try one more time
      selectedWord = _wordBank.getRandomWordByLength(wordLength);
      if (selectedWord == null) return null;
      availableCombinations = _getAvailableCombinations(selectedWord);
    }

    // STEP 4: Pick a random combination from the available ones
    String selectedCombination =
        availableCombinations[_random.nextInt(availableCombinations.length)];

    // STEP 5: Mark this combination as used
    _markCombinationUsed(selectedWord!, selectedCombination);

    // STEP 6: Parse the combination string into hint and clue indices
    // "0-2" -> hintIndex: 0, clueIndex: 2
    List<String> parts = selectedCombination.split('-');
    int hintIndex = int.parse(parts[0]);
    int clueIndex = int.parse(parts[1]);

    // STEP 7: Create and return the WordWithCombination
    _currentWord = WordWithCombination(
      word: selectedWord,
      hintIndex: hintIndex,
      clueIndex: clueIndex,
    );

    print(
      '📝 Selected word: ${_currentWord!.word.word} (length: $wordLength, position: ${_wordCounterWithinLevel + 1}/20)',
    );
    return _currentWord;
  }

  /// Determines word length based on POSITION WITHIN THE CURRENT LEVEL
  ///
  /// This is the FIXED version - it uses word position, not level number
  ///
  /// Each level has 20 words with this progression:
  /// - Position 0-3 (Words 1-4): 6 letters (easiest)
  /// - Position 4-7 (Words 5-8): 7 letters
  /// - Position 8-11 (Words 9-12): 8 letters
  /// - Position 12-15 (Words 13-16): 9 letters
  /// - Position 16-19 (Words 17-20): 10 letters (hardest)
  ///
  /// This pattern repeats identically for ALL 5 levels.
  /// The difficulty difference between levels comes from:
  /// - Timing (spawn rate and fall time)
  /// - Lives available
  /// NOT from word length
  int _getLengthForCurrentPosition() {
    // Use _wordCounterWithinLevel (0-19) to determine length
    if (_wordCounterWithinLevel < 4) {
      return 6;  // Position 0-3: 6-letter words
    } else if (_wordCounterWithinLevel < 8) {
      return 7;  // Position 4-7: 7-letter words
    } else if (_wordCounterWithinLevel < 12) {
      return 8;  // Position 8-11: 8-letter words
    } else if (_wordCounterWithinLevel < 16) {
      return 9;  // Position 12-15: 9-letter words
    } else {
      return 10;  // Position 16-19: 10-letter words
    }
  }

  /// Gets all available (unused) combinations for a word
  ///
  /// Returns a list of combination strings like ["0-0", "1-2", "2-1"]
  /// representing hint/clue pairs that haven't been shown yet
  List<String> _getAvailableCombinations(Word word) {
    // All 9 possible combinations
    // Format: "hintIndex-clueIndex"
    const List<String> allCombinations = [
      '0-0', '0-1', '0-2', // Hint 0 (A) with clues 0, 1, 2
      '1-0', '1-1', '1-2', // Hint 1 (B) with clues 0, 1, 2
      '2-0', '2-1', '2-2', // Hint 2 (C) with clues 0, 1, 2
    ];

    // Get the set of used combinations for this word
    // If no combinations used yet, this will be an empty set
    Set<String> usedForWord = _usedCombinations[word.word] ?? {};

    // Filter: return only combinations NOT in the used set
    // allCombinations.where(...) keeps only unused combinations
    return allCombinations.where((combo) => !usedForWord.contains(combo)).toList();
  }

  /// Marks a specific combination as used
  ///
  /// This prevents the same hint/clue pair from being shown again in this session
  void _markCombinationUsed(Word word, String combination) {
    // Initialize the set for this word if it doesn't exist yet
    _usedCombinations.putIfAbsent(word.word, () => {});

    // Add this combination to the word's used set
    _usedCombinations[word.word]!.add(combination);
  }

  /// Resets combinations for the least-used word
  ///
  /// This is a fallback when all words have exhausted their combinations.
  /// We pick the word with the most available combinations left and reset it.
  void _resetLeastUsedWord(int wordLength) {
    // Get all words of the specified length
    List<Word> wordsOfLength = _wordBank.getWordsByLength(wordLength);

    if (wordsOfLength.isEmpty) return;

    // Find the word with the most remaining combinations
    Word? leastUsedWord;
    int maxAvailableCombos = 0;

    for (var word in wordsOfLength) {
      int availableCount = _getAvailableCombinations(word).length;
      if (availableCount > maxAvailableCombos) {
        maxAvailableCombos = availableCount;
        leastUsedWord = word;
      }
    }

    // Reset this word's combinations
    if (leastUsedWord != null) {
      _usedCombinations[leastUsedWord.word]?.clear();
      print('♻️ Reset combinations for: ${leastUsedWord.word}');
    }
  }

  // ==========================================================================
  // ANSWER CHECKING AND SCORING
  // ==========================================================================

  /// Checks if the player's guess is correct
  ///
  /// [guess] - The player's answer
  /// Returns true if correct, false if wrong
  ///
  /// This method also:
  /// - Updates the score
  /// - Handles lives for wrong answers
  /// - Advances the word counter
  bool checkAnswer(String guess) {
    // Safety check: make sure there's a current word
    if (_currentWord == null) {
      print('❌ No current word to check against');
      return false;
    }

    // Check if the guess matches the word (case-insensitive)
    bool isCorrect = _currentWord!.word.matchesGuess(guess);

    if (isCorrect) {
      // CORRECT ANSWER
      _handleCorrectAnswer();
    } else {
      // WRONG ANSWER
      _handleWrongAnswer();
    }

    return isCorrect;
  }

  /// Handles logic when player answers correctly
  void _handleCorrectAnswer() {
    // Award 5 points (fixed, not variable by level)
    const int pointsPerWord = 5;
    _score += pointsPerWord;

    // Increment word counter
    _wordCounterWithinLevel++;

    print('✅ Correct! +$pointsPerWord points (Total: $_score)');

    // Check if level is complete (20 correct words = 100 points)
    if (_wordCounterWithinLevel >= 20) {
      _advanceToNextLevel();
    }
  }

  /// Advances to the next level
  ///
  /// Resets score and word counter, increases lives, updates level
  void _advanceToNextLevel() {
    if (_currentLevel < 5) {
      _currentLevel++;
      _score = 0;  // Reset score for new level
      _wordCounterWithinLevel = 0;  // Reset word counter
      
      // Update lives for new level
      // Level 1: 3, Level 2: 4, Level 3: 5, Level 4: 6, Level 5: 7
      _lives = 2 + _currentLevel;

      print('📈 Level up! Now at Level $_currentLevel');
      print('🛡️ Lives reset to $_lives for this level');
    } else {
      // Already at level 5 (last level)
      print('🏆 Game Victory! Completed all 5 levels!');
      // TODO: Show victory screen when UI is implemented
    }
  }

  /// Handles logic when player answers incorrectly
  void _handleWrongAnswer() {
    // Lose a life
    _lives--;

    print(
      '❌ Wrong! -1 life (Lives: $_lives, Score: $_score)',
    );

    // Check if game is over
    if (_lives <= 0) {
      print('💀 Game Over! Failed at Level $_currentLevel');
    }
  }

  // ==========================================================================
  // MULTI-WORD GAME INTERFACE
  // ==========================================================================

  /// Records that the player correctly guessed a falling word.
  ///
  /// Called from the game screen each time a falling word card is matched
  /// by the player's typed input. Advances the internal word-length
  /// progression counter so the NEXT call to [getNextWord()] returns a
  /// word of the appropriate difficulty.
  ///
  /// Word-length progression (resets every level):
  ///   Correct words 1–4  → next word 6 letters
  ///   Correct words 5–8  → next word 7 letters
  ///   Correct words 9–12 → next word 8 letters
  ///   Correct words 13–16→ next word 9 letters
  ///   Correct words 17–20→ next word 10 letters
  ///
  /// WHY not call checkAnswer()?
  /// checkAnswer() checks the player's guess against [_currentWord], which
  /// is the LAST word returned by getNextWord(). In a multi-word game there
  /// are many words falling simultaneously — [_currentWord] doesn't reliably
  /// represent the word that was just matched. We do our own matching in
  /// the game screen and only call this method to advance the counter.
  ///
  /// WHY not trigger _advanceToNextLevel() here?
  /// Level completion is handled by the game screen's Stage 6 overlay logic.
  /// Calling _advanceToNextLevel() here would reset the word counter and
  /// confuse the game screen's own completion check.
  void recordCorrectWord() {
    if (_wordCounterWithinLevel < 20) {
      _wordCounterWithinLevel++;
    }
  }

  // ==========================================================================
  // STATISTICS AND DEBUGGING
  // ==========================================================================

  /// Gets statistics about combination usage
  ///
  /// Returns a map with information like:
  /// {
  ///   "totalWordsUsed": 15,
  ///   "totalCombinationsUsed": 42,
  ///   "mostUsedWord": "BANANA",
  ///   "mostUsedWordCount": 7
  /// }
  Map<String, dynamic> getCombinationStats() {
    int totalWordsUsed = _usedCombinations.length;
    int totalCombinationsUsed = 0;
    String mostUsedWord = '';
    int maxCombinations = 0;

    // Calculate totals and find most-used word
    _usedCombinations.forEach((word, combos) {
      totalCombinationsUsed += combos.length;
      if (combos.length > maxCombinations) {
        maxCombinations = combos.length;
        mostUsedWord = word;
      }
    });

    return {
      'totalWordsUsed': totalWordsUsed,
      'totalCombinationsUsed': totalCombinationsUsed,
      'mostUsedWord': mostUsedWord,
      'mostUsedWordCount': maxCombinations,
    };
  }

  /// Prints current game state (useful for debugging)
  void printGameState() {
    print('='.padRight(50, '='));
    print('GAME STATE');
    print('='.padRight(50, '='));
    print('Level: $_currentLevel');
    print('Words Completed This Level: $_wordCounterWithinLevel/20');
    print('Score This Level: $_score/100');
    print('Lives: $_lives');
    print('Current Word: ${_currentWord?.word.word ?? 'None'}');
    print('Game Over: $isGameOver');

    var stats = getCombinationStats();
    print('\nCOMBINATION STATS:');
    print('Total words used: ${stats['totalWordsUsed']}');
    print('Total combinations used: ${stats['totalCombinationsUsed']}');
    print(
      'Most used word: ${stats['mostUsedWord']} (${stats['mostUsedWordCount']} times)',
    );
    print('='.padRight(50, '='));
  }
}