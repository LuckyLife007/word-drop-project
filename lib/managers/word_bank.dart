// ============================================================================
// WORD BANK MANAGER
// ============================================================================
// This file defines the WordBank class, which is responsible for:
// 1. Loading the word_bank.json file from assets
// 2. Parsing the JSON data into Word objects
// 3. Providing methods to retrieve words (random, by difficulty, etc.)
//
// KEY CONCEPTS:
// - This is a "manager" class - it manages a specific part of our app (the word data)
// - It uses Flutter's asset loading to read files bundled with the app
// - It uses Dart's async/await pattern for loading files (more on this below)
// ============================================================================

import 'dart:convert'; // For JSON encoding/decoding
import 'dart:math'; // For random number generation
import 'package:flutter/services.dart'; // For loading assets
import '../models/word.dart'; // Import our Word model

/// Manages the word bank for the Word Drop game
///
/// This class handles:
/// - Loading words from the JSON asset file
/// - Storing all words in memory
/// - Providing methods to retrieve words (random, filtered by length, etc.)
///
/// SINGLETON PATTERN:
/// We use a singleton pattern here, meaning there's only ONE instance of
/// WordBank in the entire app. This makes sense because we only need to
/// load the word bank once and share it everywhere.
class WordBank {
  // ==========================================================================
  // SINGLETON SETUP
  // ==========================================================================
  // This pattern ensures only one WordBank instance exists in the app

  /// Private constructor - prevents creating instances with WordBank()
  /// The underscore (_) makes this constructor private to this file
  WordBank._();

  /// The single instance of WordBank
  /// This is created once and reused throughout the app
  static final WordBank _instance = WordBank._();

  /// Public factory constructor that always returns the same instance
  ///
  /// Usage: WordBank wordBank = WordBank();
  /// Every time you call WordBank(), you get the SAME object
  factory WordBank() {
    return _instance;
  }

  // ==========================================================================
  // PROPERTIES
  // ==========================================================================

  /// List of all words loaded from the JSON file
  /// Initially empty, populated when loadWords() is called
  /// The underscore (_) makes this private - only accessible within this class
  List<Word> _words = [];

  /// Random number generator for selecting random words
  /// We create this once and reuse it for better performance
  final Random _random = Random();

  // ==========================================================================
  // PUBLIC GETTERS
  // ==========================================================================
  // These provide read-only access to our private data

  /// Returns a copy of all words
  ///
  /// We return a copy (List.from) instead of the original list to prevent
  /// external code from modifying our word list
  List<Word> get allWords => List.from(_words);

  /// Returns the total number of words in the word bank
  int get wordCount => _words.length;

  /// Returns true if words have been loaded, false otherwise
  bool get isLoaded => _words.isNotEmpty;

  // ==========================================================================
  // WORD LOADING
  // ==========================================================================

  /// Loads all words from the word_bank.json asset file
  ///
  /// ASYNC/AWAIT EXPLANATION:
  /// Loading a file takes time, so we use "async" programming:
  /// - "async" marks this as an asynchronous function
  /// - "await" pauses execution until the file is loaded
  /// - "`Future<void>`" means this returns nothing but takes time to complete
  ///
  /// This prevents the app from freezing while loading the file
  ///
  /// Throws an exception if the file can't be loaded or parsed
  Future<void> loadWords() async {
    try {
      // STEP 1: Load the JSON file from assets
      // rootBundle is Flutter's way of accessing files in the assets folder
      // await pauses here until the file is loaded
      final String jsonString = await rootBundle.loadString(
        'assets/data/word_bank.json',
      );

      // STEP 2: Parse the JSON string into a Dart object (Map)
      // jsonDecode converts the JSON text into Dart data structures
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // STEP 3: Extract the 'words' array from the JSON
      // The JSON has this structure: `{ "words": [ {...}, {...}, ... ] }`
      final List<dynamic> wordsJson = jsonData['words'] as List;

      // STEP 4: Convert each JSON object into a Word object
      // We use .map() to transform each item in the list
      // .toList() converts the result back to a List
      _words = wordsJson.map((json) => Word.fromJson(json)).toList();

      // Success! Log how many words we loaded (helpful for debugging)
      print('✅ WordBank loaded ${_words.length} words successfully');
    } catch (e) {
      // If anything goes wrong, print the error and re-throw it
      // Re-throwing lets the calling code handle the error
      print('❌ Error loading word bank: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // WORD RETRIEVAL METHODS
  // ==========================================================================

  /// Returns a random word from the entire word bank
  ///
  /// Returns null if no words are loaded yet
  ///
  /// HOW IT WORKS:
  /// 1. Check if words are loaded
  /// 2. Generate a random index between 0 and (number of words - 1)
  /// 3. Return the word at that index
  Word? getRandomWord() {
    // If no words loaded, return null
    if (_words.isEmpty) return null;

    // Generate random index: 0 to (_words.length - 1)
    // Example: if we have 100 words, this generates 0-99
    final int randomIndex = _random.nextInt(_words.length);

    // Return the word at the random index
    return _words[randomIndex];
  }

  /// Returns a random word with a specific length
  ///
  /// [length] - The desired word length (6, 7, 8, 9, or 10)
  /// Returns null if no words of that length exist or if no words are loaded
  ///
  /// EXAMPLE:
  /// Word? easyWord = wordBank.getRandomWordByLength(6); // Gets a 6-letter word
  Word? getRandomWordByLength(int length) {
    // STEP 1: Filter words to only those with the specified length
    // .where() keeps only items that match the condition
    // .toList() converts the filtered results to a List
    final List<Word> filteredWords = _words
        .where((word) => word.length == length)
        .toList();

    // STEP 2: If no words match, return null
    if (filteredWords.isEmpty) return null;

    // STEP 3: Pick a random word from the filtered list
    final int randomIndex = _random.nextInt(filteredWords.length);
    return filteredWords[randomIndex];
  }

  /// Returns multiple random words without repetition
  ///
  /// [count] - How many words to return
  /// [length] - Optional: only return words of this length
  /// Returns a list of random words (may be fewer than requested if not enough words available)
  ///
  /// EXAMPLE:
  /// `List<Word>` fiveWords = wordBank.getRandomWords(5); // Get 5 random words
  /// `List<Word>` threeHardWords = wordBank.getRandomWords(3, length: 10); // Get 3 ten-letter words
  List<Word> getRandomWords(int count, {int? length}) {
    // STEP 1: Get the pool of words to choose from
    List<Word> availableWords;

    if (length != null) {
      // If length specified, filter by length
      availableWords = _words.where((word) => word.length == length).toList();
    } else {
      // Otherwise, use all words
      availableWords = List.from(_words);
    }

    // STEP 2: If requesting more words than available, adjust count
    final int actualCount = count > availableWords.length
        ? availableWords.length
        : count;

    // STEP 3: Shuffle the list and take the first 'actualCount' items
    // ..shuffle() modifies the list in place (the .. is called cascade notation)
    availableWords.shuffle(_random);

    // Return the first 'actualCount' items
    return availableWords.sublist(0, actualCount);
  }

  /// Returns all words with a specific length, sorted alphabetically
  ///
  /// [length] - The desired word length
  /// Returns an empty list if no words of that length exist
  ///
  /// EXAMPLE:
  /// `List<Word>` allSixLetterWords = wordBank.getWordsByLength(6);
  List<Word> getWordsByLength(int length) {
    // Filter words by length
    final List<Word> filteredWords = _words
        .where((word) => word.length == length)
        .toList();

    // Sort alphabetically by word
    // The ..sort() modifies the list in place
    // (a, b) => a.word.compareTo(b.word) compares two words alphabetically
    filteredWords.sort((a, b) => a.word.compareTo(b.word));

    return filteredWords;
  }

  /// Returns a breakdown of how many words exist for each length
  ///
  /// Returns a Map where:
  /// - Key = word length `(6, 7, 8, 9, 10)`
  /// - Value = count of words with that length
  ///
  /// EXAMPLE OUTPUT:
  /// `{6: 20, 7: 20, 8: 20, 9: 20, 10: 20}`
  ///
  /// This is useful for showing statistics or ensuring balanced difficulty
  Map<int, int> getWordCountByLength() {
    // Create an empty map to store counts
    Map<int, int> counts = {};

    // Loop through each word
    for (var word in _words) {
      // If this length isn't in the map yet, set it to 0
      counts[word.length] ??= 0;

      // Increment the count for this length
      counts[word.length] = counts[word.length]! + 1;
    }

    return counts;
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Clears all loaded words from memory
  ///
  /// This is useful for testing or if you need to reload words
  void clear() {
    _words.clear();
    print('🗑️ WordBank cleared');
  }

  /// Reloads the word bank from the JSON file
  ///
  /// This clears existing words and loads them fresh from the file
  Future<void> reload() async {
    clear();
    await loadWords();
  }
}
