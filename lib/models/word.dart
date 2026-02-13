// ============================================================================
// WORD MODEL
// ============================================================================
// This file defines the Word class, which represents a single word in our
// word guessing game. Each Word object contains the complete word, its length,
// incomplete versions (hints), and clues to help players guess it.
//
// KEY CONCEPTS:
// - A "model" is a class that represents data in our app
// - We use models to structure data and make it easy to work with
// - This model corresponds to each word entry in our word_bank.json file
// ============================================================================

/// Represents a single word in the Word Drop game
///
/// Each Word contains:
/// - The complete word to guess (e.g., "BANANA")
/// - The word's length (e.g., 6)
/// - Three incomplete versions showing some letters (e.g., "B-N-N-")
/// - Three clues of varying difficulty to help the player
class Word {
  // ==========================================================================
  // PROPERTIES (the data each Word object holds)
  // ==========================================================================

  /// The complete word that the player needs to guess
  /// Example: "BANANA"
  final String word;

  /// The number of letters in the word
  /// Example: 6
  /// We use this to organize words by difficulty (6-letter words are easier than 10-letter words)
  final int length;

  /// A list of three incomplete versions of the word, showing different letter patterns
  /// Example: ["B-N-N-", "-A-A-A", "B--AN-"]
  /// The dashes (-) represent hidden letters
  /// These serve as hints of increasing helpfulness
  final List<String> incompleteVersions;

  /// A list of three clues that describe the word
  /// Example: ["Yellow curved fruit", "Tropical plant...", "Monkey's favorite snack"]
  /// We'll show these progressively to help the player
  final List<String> clues;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================
  // A constructor is a special function that creates instances of this class
  // The syntax below is Dart's shorthand for assigning all parameters to properties

  /// Creates a new Word instance
  ///
  /// All parameters are required because every word must have:
  /// - A complete word string
  /// - A length
  /// - Three incomplete versions
  /// - Three clues
  Word({
    required this.word,
    required this.length,
    required this.incompleteVersions,
    required this.clues,
  });

  // ==========================================================================
  // JSON CONVERSION METHODS
  // ==========================================================================
  // These methods allow us to convert between JSON data and Word objects
  // This is essential because our word_bank.json file contains JSON data

  /// Creates a Word object from a JSON map
  ///
  /// This is called a "factory constructor" - it's a special type of constructor
  /// that can return an existing instance or create a new one
  ///
  /// Example JSON input:
  /// {
  ///   "word": "BANANA",
  ///   "length": 6,
  ///   "incomplete_versions": ["B-N-N-", "-A-A-A", "B--AN-"],
  ///   "clues": ["Yellow curved fruit", "Tropical plant...", "Monkey's favorite snack"]
  /// }
  ///
  /// This method extracts each field from the JSON and creates a Word object
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      // Extract the 'word' field from JSON and cast it to String
      word: json['word'] as String,

      // Extract the 'length' field from JSON and cast it to int
      length: json['length'] as int,

      // Extract the 'incomplete_versions' array from JSON
      // We use List<String>.from() to convert the JSON array to a Dart List<String>
      incompleteVersions: List<String>.from(
        json['incomplete_versions'] as List,
      ),

      // Extract the 'clues' array from JSON
      // Same process as incomplete_versions
      clues: List<String>.from(json['clues'] as List),
    );
  }

  /// Converts a Word object back to a JSON map
  ///
  /// This is useful if we ever need to:
  /// - Save game progress
  /// - Send data to a server
  /// - Store custom words created by users (future feature)
  ///
  /// Returns a Map that matches our JSON structure
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'length': length,
      'incomplete_versions': incompleteVersions,
      'clues': clues,
    };
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================
  // These methods provide useful functionality for working with Word objects

  /// Returns a string representation of this Word object
  ///
  /// This is helpful for debugging - when you print a Word object,
  /// you'll see a readable description instead of "Instance of 'Word'"
  ///
  /// Example output: "Word(BANANA, 6 letters)"
  @override
  String toString() {
    return 'Word($word, $length letters)';
  }

  /// Checks if this word matches a player's guess
  ///
  /// The comparison is case-insensitive, so "banana", "BANANA", and "BaNaNa"
  /// all match the word "BANANA"
  ///
  /// [guess] - The player's guess to check
  /// Returns true if the guess matches the word (ignoring case)
  bool matchesGuess(String guess) {
    // Convert both strings to uppercase before comparing
    // This ensures "banana" matches "BANANA"
    return word.toUpperCase() == guess.toUpperCase();
  }

  /// Gets a specific clue by index (0, 1, or 2)
  ///
  /// This is a convenience method to safely access clues
  ///
  /// [index] - Which clue to get (0 = first, 1 = second, 2 = third)
  /// Returns the clue at the specified index, or an empty string if index is invalid
  String getClue(int index) {
    // Check if the index is valid (between 0 and 2, inclusive)
    if (index >= 0 && index < clues.length) {
      return clues[index];
    }
    // If index is out of bounds, return empty string as a safe default
    return '';
  }

  /// Gets a specific incomplete version by index (0, 1, or 2)
  ///
  /// Similar to getClue, but for incomplete versions
  ///
  /// [index] - Which incomplete version to get (0, 1, or 2)
  /// Returns the incomplete version at the specified index, or empty string if invalid
  String getIncompleteVersion(int index) {
    if (index >= 0 && index < incompleteVersions.length) {
      return incompleteVersions[index];
    }
    return '';
  }
}
