// ============================================================================
// GAME MANAGER
// ============================================================================
// This file defines the GameManager class, which is the central "brain" of our
// word guessing game. It manages:
// 1. Game state (score, level, lives, current word)
// 2. Word selection with hint/clue combination tracking
// 3. Answer checking and scoring
// 4. Level progression
//
// KEY CONCEPTS:
// - This is a "manager" class that coordinates game logic
// - It uses the WordBank to get words but tracks which combinations are used
// - It ensures players don't see the same word/hint/clue combo twice in a session
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
  /// This maps to indices in word.incompleteVersions
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
  /// Example: If hintIndex = 0 and word is BANANA, returns "B-N-N-"
  String get hint => word.getIncompleteVersion(hintIndex);

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
  /// Level determines word difficulty:
  /// - Level 1: 6-letter words
  /// - Level 2: 7-letter words
  /// - Level 3: 8-letter words
  /// - Level 4: 9-letter words
  /// - Level 5+: 10-letter words
  int _currentLevel = 1;

  /// Current score (starts at 0)
  /// Score increases with correct answers and decreases with wrong answers
  int _score = 0;

  /// Number of lives remaining (starts at 3)
  /// Player loses a life for each wrong answer
  /// Game ends when lives reach 0
  int _lives = 3;

  /// The current word being guessed
  /// Null when no active word (e.g., between rounds or game over)
  WordWithCombination? _currentWord;

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
    _lives = 3;
    _currentWord = null;
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
  /// 1. Determines word difficulty based on current level
  /// 2. Selects a random word of that difficulty
  /// 3. Finds an unused hint/clue combination for that word
  /// 4. Marks the combination as used
  /// 5. Returns the word with the selected combination
  ///
  /// Returns null if no words available (should never happen with 100 words)
  WordWithCombination? getNextWord() {
    // STEP 1: Determine word length based on level
    int wordLength = _getLengthForLevel(_currentLevel);

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
      '📝 Selected word: ${_currentWord!.word.word} (combination: $selectedCombination)',
    );
    return _currentWord;
  }

  /// Determines word length based on game level
  ///
  /// Level 1: 6 letters (easiest)
  /// Level 2: 7 letters
  /// Level 3: 8 letters
  /// Level 4: 9 letters
  /// Level 5+: 10 letters (hardest)
  int _getLengthForLevel(int level) {
    switch (level) {
      case 1:
        return 6;
      case 2:
        return 7;
      case 3:
        return 8;
      case 4:
        return 9;
      default:
        return 10; // Level 5 and beyond use 10-letter words
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

    // Return only combinations that haven't been used
    // .where() filters the list, keeping only items where the condition is true
    return allCombinations
        .where((combo) => !usedForWord.contains(combo))
        .toList();
  }

  /// Marks a combination as used for a specific word
  ///
  /// [word] - The word object
  /// [combination] - The combination string (e.g., "0-2")
  void _markCombinationUsed(Word word, String combination) {
    // If this word doesn't have an entry in the map yet, create an empty Set
    if (!_usedCombinations.containsKey(word.word)) {
      _usedCombinations[word.word] = {};
    }

    // Add the combination to the set
    // If it's already there, Set automatically handles the duplicate (no effect)
    _usedCombinations[word.word]!.add(combination);
  }

  /// Resets the word that has the fewest used combinations
  ///
  /// This is a fallback for when all words of a certain length have
  /// exhausted their combinations. We pick the word with the most
  /// available combinations left and reset it.
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
  /// - Advances the level for correct answers
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
    // Award points based on current level
    // Higher levels = more points
    int pointsEarned = _currentLevel * 10;
    _score += pointsEarned;

    print('✅ Correct! +$pointsEarned points (Total: $_score)');

    // Advance to next level (max level 5)
    if (_currentLevel < 5) {
      _currentLevel++;
      print('📈 Level up! Now at level $_currentLevel');
    } else {
      print('🏆 Already at max level!');
    }
  }

  /// Handles logic when player answers incorrectly
  void _handleWrongAnswer() {
    // Deduct points
    int pointsLost = 5;
    _score = (_score - pointsLost).clamp(0, double.infinity).toInt();

    // Lose a life
    _lives--;

    print(
      '❌ Wrong! -$pointsLost points, -1 life (Lives: $_lives, Score: $_score)',
    );

    // Check if game is over
    if (_lives <= 0) {
      print('💀 Game Over!');
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
    print('Score: $_score');
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
