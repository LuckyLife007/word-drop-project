# Word Drop Game - Flutter Development Documentation

## 1. Game Overview & Concept

### 1.1 Core Gameplay Mechanics

**Primary Objective**: Players must complete partially hidden words before they fall from the top of the screen to the bottom. Words "fall" with gravity-like animation from sky to ground.

**Input Method**: Players type the complete word using an on-screen keyboard or device keyboard. The game accepts input in real-time and checks for matches against currently falling words.

**Word Completion System**: 

- Each word appears with missing letters (e.g., "ATTENTION" shown as "_TT__T_ON")
- Players must deduce and type the complete word based on:
  - The incomplete letter pattern
  - A descriptive clue (e.g., "What you pay when listening")
- Multiple variations exist for both incomplete patterns and clues per word

**Real-time Matching**: When a player types a complete word that matches any currently falling word, that specific word disappears with positive visual feedback. Input field clears automatically for the next word.

**Failure Conditions**: 

- Words that reach the ground without being correctly guessed result in life loss
- Visual feedback shows words "hitting" the ground with negative animation
- Game ends when all lives are depleted

### 1.2 Target Audience and Platform Requirements

**Primary Audience**: 

- Ages 12+ (vocabulary-dependent)
- Casual gamers seeking quick, engaging word puzzles
- Educational gaming enthusiasts
- Players looking for progressively challenging experiences

**Platform Requirements**:

- **iOS**: Minimum iOS 12.0, optimized for iPhone 8 and newer
- **Android**: Minimum Android API 21 (Android 5.0), optimized for devices with 2GB+ RAM
- **Screen Orientations**: Portrait mode only for consistent gameplay experience
- **Input**: Touch keyboard support, external keyboard compatibility
- **Performance Target**: 60 FPS gameplay, <2 second app launch time

### 1.3 Game Objectives and Win Conditions

**Level Completion**: Each level requires exactly 20 correct word completions to advance:

- Level scoring: 5 points per correct word = 100 points total per level
- Progressive difficulty through timing and word complexity
- No time limits beyond individual word fall times

**Overall Game Victory**: Successfully complete all 5 difficulty levels:

1. **Strolling** (Level 1) - Tutorial pace
2. **Jogging** (Level 2) - Moderate challenge  
3. **Running** (Level 3) - Increased pressure
4. **Bolting** (Level 4) - High-speed challenge
5. **Impossible** (Level 5) - Maximum difficulty

**Performance Tracking**: 

- Fastest completion time per level (measured from level start to 20th correct word)
- Personal best times stored locally
- Level unlock progression saved persistently

**Failure and Recovery**:

- Lives system varies by level (detailed in Section 4)
- Game over when all lives depleted
- Players can restart current level or return to level selection
- No progress lost on failure - unlocked levels remain accessible

### 1.4 Visual Theme and Aesthetic Direction

**Overall Style**: 

- Clean, modern design with playful elements
- Bright, engaging color palette suitable for all ages
- Clear visual hierarchy prioritizing readability and gameplay clarity

**Visual Metaphor**: 

- **Sky Zone**: Top area where words spawn, labeled "SKY"
- **Ground Zone**: Bottom danger area where words "crash," labeled "GROUND"  
- **Falling Motion**: Smooth, physics-inspired downward movement
- **Spatial Design**: Clear vertical gameplay space with distinct zones

**Color Scheme**:

- Background: Gradient blues to purples (sky-like theme)
- Words: High-contrast white/light backgrounds with dark text for maximum readability
- UI Elements: Consistent accent colors for buttons, scores, and feedback
- Feedback Colors: Green for success, red for failure/danger, gold for achievements

**Typography Requirements**:

- **Game Words**: Monospace font (like Courier New) for incomplete letter patterns
- **UI Text**: Clean, readable sans-serif font
- **Descriptions/Clues**: Slightly smaller, italicized text for clear hierarchy
- **Headers/Titles**: Bold, prominent styling for game title and level names

**Animation Philosophy**:

- Smooth, natural feeling movements
- Satisfying feedback for player actions
- Non-distracting but engaging visual effects
- Performance-optimized for consistent 60 FPS

This foundation establishes the core experience that subsequent sections will build upon. The game balances educational value with entertainment, creating an accessible yet challenging word-based arcade experience.

---

## 2. Game Flow & User Experience

### 2.1 App Launch and Main Menu

**Splash Screen**:

- Word Drop logo with brief animation (2-3 seconds)
- Loading indicator for game assets
- Smooth transition to main menu

**Main Menu Interface**:

- **Title**: "Word Drop" prominently displayed at top
- **Primary Action Button**: "Play" - leads to level selection
- **Secondary Options**:
  - "Settings" - audio controls, vibration toggle
  - "How to Play" - tutorial/instructions overlay
  - "About" - credits and version information
- **Visual Elements**: Animated background consistent with sky theme
- **Audio**: Subtle background music loop (can be toggled off)

### 2.2 Level Selection Screen

**Layout Design**:

- Vertical list of level cards
- Each level card displays:
  - Level number and name (e.g., "Level 1: Strolling")
  - Lock/unlock status with visual indicators
  - Best completion time (if completed previously)
  - Info button for level details

**Level State Management**:

- **Locked Levels**: Grayed out with lock icon, non-interactive
- **Available Level (Current Target)**: Full color, interactive with tap/hover feedback, highlighted and pulsing, with an unlock icon
- **Completed Levels**: Full color, interactive with tap/hover feedback and a checkmark

**Navigation**:

- **Back Button**: Return to main menu
- **Level Tap**: Start selected level immediately or show level preview
- **Info Button**: Brief description of level difficulty and requirements

### 2.3 Tutorial/Onboarding Flow

**First-Time User Experience**:

- Triggered automatically on first app launch
- Skippable for returning users
- Available as "How to Play" from main menu

**Tutorial Sequence**:

1. **Welcome Screen**: Brief game introduction with attractive visuals
2. **Objective Explanation**: "Complete the falling words before they hit the ground"
3. **Lives System**: Explain life loss and game over conditions
4. **Ready to Play**: Direct to Level 1 with encouragement

### 2.4 In-Game Interface Layout

**Header Area (Top 15% of screen)**:

- **Statistics Bar**:
  - Current Score / Target Score (e.g., "45/100")
  - Lives Remaining (red heart icons that turn white when lost)
  - Timer showing elapsed time

**Game Area (Middle 60% of screen)**:

- **Sky Label**: "SKY" indicator at top boundary
- **Falling Word Space**: Clear area for word animation
- **Ground Label**: "GROUND" indicator at bottom boundary
- **Visual Boundaries**: Clear demarcation lines

**Input Area (Bottom 25% of screen)**:

- **Text Input Field**: Large, centered, with clear placeholder text
- **Virtual Keyboard** (if needed): Standard QWERTY layout
- **Pause Button**: Opens game pause overlay

### 2.5 Game Session Flow

**Level Start Sequence**:

1. **Level Introduction**: Brief overlay showing level name and key stats
2. **Countdown**: "3... 2... 1... Go!" with visual countdown
3. **First Word Spawn**: Initial word appears immediately after countdown
4. **Continuous Gameplay**: Words spawn at regular intervals

**During Gameplay**:

- **Real-time Updates**: Score and stats update immediately
- **Visual Feedback**: Instant response to correct inputs only
- **Consistent Timing**: All words within a level spawn and fall at the same pace (timing differs between levels)
- **Audio Feedback**: Sound effects for correct answers and ground impacts

**Mid-Game Events**:

- **Correct Answer**: Word flashes green, dissolves, satisfying sound
- **Word Hits Ground**: Red flash, impact animation, life lost sound
- **Life Lost Warning**: Visual/audio indication when lives are low

**Pause Functionality**:

- **Pause Button**: Stops all falling words and displays overlay
- **Pause Overlay Content**:
  - Game name: "Word Drop"
  - Current level name
  - Score
  - Time spent
  - Lives remaining
  - Options: "Resume Game" and "End Game" (returns to level selection without saving progress)

### 2.6 Level Completion and Transitions

**Level Victory Sequence**:

1. **Immediate Feedback**: "Level Complete!" message with celebration animation
2. **Statistics Display**: 
   - Final score confirmation (100 points)
   - Completion time
   - New best time (if achieved)
3. **Next Level Unlock**: Animation showing next level becoming available
4. **Action Options**:
   - "Continue" to next level
   - "Replay Level" for better time
   - "Level Select" to choose different level

**Level Failure (Game Over) Sequence**:

1. **Game Over Animation**: Final word hitting ground with dramatic effect
2. **Results Screen**:
   - "Game Over" message
   - Final score achieved
   - Level attempted
   - Encouragement message
3. **Recovery Options**:
   - "Try Again" - restart same level
   - "Level Select" - choose different level
   - "Main Menu" - return to start

### 2.7 Settings and Preferences Management

**Audio Settings**:

- **Master Volume**: Overall app volume control
- **Sound Effects**: Toggle on/off with volume slider
- **Background Music**: Toggle on/off with volume slider
- **Vibration**: Haptic feedback toggle for supported devices

**Data Management**:

- **Reset Progress**: Clear all saved data with confirmation dialog

This comprehensive flow ensures smooth user experience from first launch through extended play sessions, with clear navigation and intuitive interactions at every stage.

---

## 3. Word Bank System

### 3.1 Word Database Structure and Organization

**Data Format**: JSON file stored as Flutter asset (`assets/data/word_bank.json`)

**Organizational Structure**:

```json
{
  "6": [
    {
      "word": "BANANA",
      "incomplete": ["B-N-N-", "-A-A-A", "B--AN-"],
      "clues": [
        "Yellow curved fruit",
        "Tropical plant with elongated edible berry", 
        "Monkey's favorite snack"
      ]
    },
    {
      "word": "BRIDGE",
      "incomplete": ["B-I-G-", "-R-D-E", "BR---E"],
      "clues": [
        "Structure that spans a river or valley",
        "Connection over water or gap",
        "Path that links two sides"
      ]
    }
  ],
  "7": [...],
  "8": [...],
  "9": [...],
  "10": [...]
}
```

**Word Bank Specifications**:

- **Total Words**: 100 words (20 per length category)
- **Length Categories**: 6, 7, 8, 9, and 10 letters
- **Variation System**: 3 incomplete patterns and 3 clues per word
- **Content**: Family-friendly vocabulary appropriate for ages 12+
- **Case Sensitivity**: All words stored in uppercase for consistency

### 3.2 Word Selection Algorithms by Letter Count

**Level-Based Word Distribution**: 20 words each level in the following order

- **Words 1-4**: 6-letter words
- **Words 5-8**: 7-letter words  
- **Words 9-12**: 8-letter words
- **Words 13-16**: 9-letter words
- **Words 17-20**: 10-letter words

**Selection Algorithm Implementation**:

```dart
class WordBankManager {
  Map<int, List<WordData>> wordsByLength;
  Map<int, List<WordData>> levelPool;

  void initializeLevel() {
    levelPool.clear();

    // Create shuffled pools for each length category
    for (int length = 6; length <= 10; length++) {
      levelPool[length] = List.from(wordsByLength[length]);
      levelPool[length].shuffle();
    }
  }

  WordData selectWordByLength(int targetLength) {
    if (levelPool[targetLength].isEmpty) {
      throw Exception('No more words available for length $targetLength');
    }
    return levelPool[targetLength].removeAt(0);
  }
}
```

**Anti-Repetition Logic**:

- Each level starts with fresh, shuffled pools for all word lengths
- Words are consumed sequentially from shuffled pools
- No word can repeat within a single level session
- Cross-level repetition is acceptable (different game sessions)

### 3.3 Random Pattern and Clue Selection

**Selection Logic**: Pattern and clue must be selected independently using separate random indices.

```dart
class WordDisplay {
  String completeWord;
  String incompletePattern;
  String clue;

  WordDisplay.fromWordData(WordData data) {
    completeWord = data.word;
    int patternIndex = Random().nextInt(3);
    int clueIndex = Random().nextInt(3);
    incompletePattern = data.incomplete[patternIndex];
    clue = data.clues[clueIndex];
  }
}
```

### 3.4 Random Combination Logic for Word-Clue Pairings

**Combination Generation Process**:

1. **Word Selection**: Choose word based on current level position and length requirement
2. **Pattern Selection**: Randomly select 1 of 3 incomplete patterns
3. **Clue Selection**: Independently randomly select 1 of 3 clues

**Statistical Distribution**:

- Each word has equal probability of selection within its length category
- Each pattern has 33.33% probability of selection
- Each clue has 33.33% probability of selection  
- Total combinations per word: 9 possible variations

**Performance Considerations**:

- Pre-load entire word bank at app startup (~50KB memory footprint)
- Random selection uses Dart's built-in Random() class
- No database queries or file I/O during gameplay
- Selection operations are O(1) after initial shuffle

### 3.5 Data Loading and Caching Strategy

**Asset Loading Process**:

```dart
class WordBankLoader {
  static Map<int, List<WordData>>? _cachedWordBank;

  static Future<Map<int, List<WordData>>> loadWordBank() async {
    if (_cachedWordBank != null) return _cachedWordBank!;

    String jsonString = await rootBundle.loadString('assets/data/word_bank.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);

    Map<int, List<WordData>> wordBank = {};
    jsonData.forEach((length, words) {
      wordBank[int.parse(length)] = (words as List)
          .map((wordJson) => WordData.fromJson(wordJson))
          .toList();
    });

    _cachedWordBank = wordBank;
    return wordBank;
  }
}
```

**Memory Management**:

- Load word bank once at app initialization
- Cache in memory throughout app lifecycle
- No need for disk caching given small dataset size
- Lazy loading not required due to minimal memory impact

**Error Handling**:

- Validate JSON structure on load
- Ensure all required fields present
- Fallback mechanism for corrupted data
- Graceful degradation if word bank fails to load

This word bank system provides robust, efficient word selection with rich variation capabilities while maintaining optimal performance for mobile devices.

---



## 4. Level Progression Mechanics

### 4.1 Five-Level Difficulty Progression System

**Level Structure**: The game features exactly 5 progressive difficulty levels, each with distinct names and mechanical characteristics:

1. **Level 1: "Strolling"** - Introductory/Tutorial pace
2. **Level 2: "Jogging"** - Moderate challenge increase
3. **Level 3: "Running"** - Significant difficulty spike
4. **Level 4: "Bolting"** - High-pressure gameplay
5. **Level 5: "Impossible"** - Maximum difficulty challenge

**Linear Progression**: Levels must be completed sequentially. Players cannot access higher levels until they complete the current level requirement (100 points = 20 correct words).

**Level Configuration System**:
    final Map<int, LevelConfig> levelConfigurations = {
      1: LevelConfig(
        name: "Strolling",
        spawnDelay: 5000,  // milliseconds between word spawns
        fallTime: 30000,   // milliseconds for word to fall completely
        lives: 3
      ),
      2: LevelConfig(
        name: "Jogging", 
        spawnDelay: 4500,
        fallTime: 26000,
        lives: 4
      ),
      3: LevelConfig(
        name: "Running",
        spawnDelay: 4000,
        fallTime: 22000,
        lives: 5
      ),
      4: LevelConfig(
        name: "Bolting",
        spawnDelay: 3500,
        fallTime: 18000,
        lives: 6
      ),
      5: LevelConfig(
        name: "Impossible",
        spawnDelay: 3000,
        fallTime: 15000,
        lives: 7
      )
    };

### 4.2 Progressive Word Length System

**Word Distribution Per Level**: Each level contains exactly 20 words distributed across 5 length categories in a fixed pattern:

* **Words 1-4**: 6-letter words
* **Words 5-8**: 7-letter words
* **Words 9-12**: 8-letter words
* **Words 13-16**: 9-letter words
* **Words 17-20**: 10-letter words

**Implementation Logic**:
    class LevelWordManager {
      int currentWordIndex = 0;
      int getRequiredWordLength() {
        if (currentWordIndex <= 3) return 6;      // Words 1-4
        if (currentWordIndex <= 7) return 7;      // Words 5-8
        if (currentWordIndex <= 11) return 8;     // Words 9-12
        if (currentWordIndex <= 15) return 9;     // Words 13-16
        return 10;                                // Words 17-20
      }
      void onWordCompleted() {
        currentWordIndex++;
        // Check for level completion at word 20
        if (currentWordIndex >= 20) {
          completeLevel();
        }
      }
    }

**Progressive Challenge Philosophy**:

* Start each level with shorter, more manageable words
* Gradually increase word length as player builds confidence
* End each level with longest words as the ultimate test
* This pattern repeats identically across all 5 levels

### 4.3 Dynamic Timing Adjustments Per Level

**Spawn Rate Acceleration**: Word spawn intervals decrease progressively across levels:

* **Level 1 (Strolling)**: 5.0-second intervals - very manageable pace
* **Level 2 (Jogging)**: 4.5-second intervals - slight pressure increase
* **Level 3 (Running)**: 4.0-second intervals - moderate challenge
* **Level 4 (Bolting)**: 3.5-second intervals - challenging timing
* **Level 5 (Impossible)**: 3.0-second intervals - high-pressure gameplay

**Fall Speed Acceleration**: Time available per word decreases systematically:

* **Level 1**: 30 seconds per word - ample thinking time
* **Level 2**: 26 seconds per word - comfortable but focused
* **Level 3**: 22 seconds per word - requires quick thinking
* **Level 4**: 18 seconds per word - challenging decisions
* **Level 5**: 15 seconds per word - demanding quick recognition

**Cumulative Difficulty**: Both spawn rate AND fall speed increase simultaneously, creating a challenging but achievable difficulty progression that allows players time to process clues and type responses.

### 4.4 Lives System Scaling with Difficulty

**Compensatory Lives System**: As levels become more challenging, players receive additional lives to balance the increased difficulty:
    Map<int, int> livesPerLevel = {
      1: 3, // Lowest lives for easiest level
      2: 4, // +1 life as spawn rate increases
      3: 5, // +1 life as both timing factors intensify
      4: 6, // +1 life for high-pressure timing
      5: 7  // Maximum lives for maximum difficulty
    };

**Design Philosophy**:

* More lives compensate for faster, more challenging gameplay
* Prevents excessive frustration on higher levels
* Maintains challenge while ensuring progression is achievable
* Lives lost carry the same penalty regardless of level (word hits ground)

**Lives Display**: Always show current lives remaining with red heart icons that turn white when lost, positioned in the header area for constant visibility.

### 4.5 Score Requirements and Progression Gates

**Universal Scoring System**:

* **Points Per Word**: 5 points for each correctly completed word
* **Level Target**: 100 points required to complete any level
* **Word Requirement**: Exactly 20 correct words needed per level (20 × 5 = 100)
* **No Bonus Scoring**: No additional points for speed, word length, or remaining lives

**Progression Gate Logic**:
    class LevelProgressionManager {
      int currentScore = 0;
      static const int POINTS_PER_WORD = 5;
      static const int LEVEL_TARGET_SCORE = 100;
      static const int WORDS_PER_LEVEL = 20;
      void onWordCompleted() {
        currentScore += POINTS_PER_WORD;
        if (currentScore >= LEVEL_TARGET_SCORE) {
          if (isLastLevel()) {
            triggerGameVictory();
          } else {
            unlockNextLevel();
            showLevelCompletionSequence();
          }
        }
      }
    }

**Level Completion Requirements**:

* **Standard Levels (1-4)**: Advance to next level automatically upon reaching 100 points
* **Final Level (5)**: Trigger complete game victory sequence
* **Failure Condition**: Lose all lives before reaching 100 points → Game Over, restart current level

**No Partial Progress**: Level progress does not carry over. Each level starts fresh at 0 points, and failure requires complete level restart.

### 4.6 Level Transition and Unlock System

**Sequential Unlock Mechanism**:

* Players start with access to Level 1 only
* Each completed level unlocks the next level permanently
* Completed levels remain accessible for replay
* No level can be skipped or unlocked early

**Level Completion Sequence**:

1. **Achievement Recognition**: "Level Complete!" message with celebration animation
2. **Statistics Display**: Final score confirmation, completion time
3. **Unlock Animation**: Visual indication of next level becoming available
4. **Progression Choice**: Options to continue to next level, replay current level, or return to level selection

**Persistent Progress**: Level unlocks are saved locally and persist across app sessions. Players never lose access to previously unlocked levels.

This progression system creates a balanced difficulty curve that challenges players while providing clear advancement milestones and fair compensation for increased challenge through the lives system.

---

## 5. Game Physics & Timing

### 5.1 Word Drop Mechanics and Physics

**Core Movement System**: Words appear at the top of the game area (the "SKY" zone) and descend vertically toward the bottom (the "GROUND" zone) with a smooth, linear animation at uniform velocity, matching the HTML prototype's constant speed without acceleration.

**Implementation Guidelines**:

- Use Flutter's `AnimationController` with a linear curve (`Curves.linear`) for downward movement to ensure constant velocity.
- Position words randomly along the x-axis while preventing overlap: Maintain a list of active word positions and widths; calculate available slots and select a non-overlapping left position via `left = Random().nextDouble() * (screenWidth - wordWidgetWidth)`, retrying if overlap detected (check against existing words' x-ranges with a minimum 20px buffer).
- Word widgets should be absolutely positioned within a `Stack` widget representing the game container.
- Maintain a constant vertical path; no horizontal drift or rotation unless for visual effects (see Section 7).
- Handle multiple simultaneous falling words (up to 5-10 in higher levels) without performance degradation.
- Account for screen layout: The falling area occupies the space above the input container (bottom 25% for keyboard/input field), using approximately middle 60% of total height, with header at top 15%.

**Physics Parameters**:

- Velocity: Constant, calculated as distance / fallTime (see 5.3).
- No acceleration or initial velocity variation; uniform motion throughout.

**Edge Cases**:

- Screen resizing/orientation changes: Pause and reposition words proportionally.
- Device performance: Cap at 60 FPS; use `TickerMode` to disable animations on low-end devices if needed.
- Overlap prevention: If no non-overlapping slot found after 10 retries, slightly adjust existing words or delay spawn (rare due to screen width).

### 5.2 Spawn Timing Configurations Per Level

**Spawn System**: New words spawn at regular intervals based on level difficulty, starting immediately after level countdown. Use Dart's `Timer.periodic` for scheduling.

**Level-Specific Configurations**: Reference the `levelConfigurations` map from Section 4.1:

- **Strolling (Level 1)**: Spawn every 5000ms.
- **Jogging (Level 2)**: Spawn every 4500ms.
- **Running (Level 3)**: Spawn every 4000ms.
- **Bolting (Level 4)**: Spawn every 3500ms.
- **Impossible (Level 5)**: Spawn every 3000ms.

**Implementation Logic**:

```dart
class GameTimerManager {
  Timer? spawnTimer;
  void startSpawning(LevelConfig config, Function spawnWord) {
    spawnWord();  // Initial word immediately
    spawnTimer = Timer.periodic(Duration(milliseconds: config.spawnDelay), (_) {
      if (gameState.isRunning) {
        spawnWord();
      }
    });
  }
  void stopSpawning() {
    spawnTimer?.cancel();
  }
}
```

- Pause timer during game pause or level completion.
- Ensure no more than a maximum of 10 active words to prevent overcrowding (though levels are tuned to avoid this).
- Integrate overlap check into `spawnWord()` to ensure new words don't overlap with existing ones.

### 5.3 Fall Speed Calculations

**Speed Determination**: Fall speed is level-dependent, calculated to complete the descent in the specified `fallTime` while accounting for screen height.

**Base Calculation**:

- Total distance: Effective falling height = `screenHeight * 0.6 - wordHeight` (middle 60% game area above input/keyboard, minus word height for buffer).
- Velocity: Constant `distance / (fallTime / 1000)` pixels per second.

**Level-Specific Fall Times** (from Section 4.1):

- **Strolling**: 30000ms (slow, ample time).
- **Jogging**: 26000ms.
- **Running**: 22000ms.
- **Bolting**: 18000ms.
- **Impossible**: 15000ms (fast, high pressure).

**Adaptive Scaling**:

- Normalize for different device screens: `fallDuration = baseFallTime * (actualScreenHeight / referenceHeight)`, where referenceHeight = 800px (iPhone 8 baseline).
- Test on various devices to ensure consistent perceived speed.

### 5.4 Collision Detection (Word Reaching Ground)

**Detection Mechanism**: Trigger "ground hit" when the bottom of a word (y-position + wordHeight) reaches or exceeds the ground boundary.

**Implementation Approaches**:

- **Animation Listener**: Use `Animation.addStatusListener` to detect `AnimationStatus.completed`.

- **Position Monitoring**: In Flame, use `onCollision` with a ground component; in vanilla Flutter, check position in a `Ticker` callback.
  
  ```dart
  void monitorWordPosition(WordWidget word) {
  word.animation.addListener(() {
    if (word.position.y + word.height >= groundY) {
      handleGroundHit(word);
    }
  });
  }
  ```

- Upon detection: Remove word after brief delay, deduct life, play impact animation/sound.

**Boundary Definition**:

- Ground Y: `screenHeight * 0.75` (bottom of middle 60% area + buffer, above input/keyboard).
- Tolerance: +10px to account for frame timing.

### 5.5 Animation Duration Specifications

**Primary Animations**:

- **Fall Animation**: Duration = level fallTime; Curve = `Curves.linear`.
- **Spawn Fade-In**: 300ms ease-in opacity from 0 to 1.
- **Correct Guess**: 500ms flash (green scale-up and fade-out).
- **Ground Hit**: 600ms red pulse (scale 1.05 → 1.0, color shift) before removal.

**Performance Requirements**:

- All animations at 60 FPS using `vsync` providers.
- Batch updates in a single `AnimatedBuilder` where possible.
- Test on low-end devices: Fall back to simpler animations if needed.

This section provides precise specifications for implementing responsive, engaging physics and timing, ensuring consistent behavior across devices while building on the prototype's foundation.

---

## 6. User Interface Design

### 6.1 Screen Layouts and Responsive Design

**Overall App Structure**: Use a `Scaffold` widget as the base for all screens, with persistent elements like the app bar for navigation where appropriate. All layouts must be responsive to different screen sizes and densities on iOS and Android devices, using `MediaQuery` for dynamic sizing and `LayoutBuilder` for conditional rendering.

**Key Screen Layouts**:

- **Main Menu Screen**: Centered vertical column with title (40% height), primary buttons (Play, Settings, etc.) spaced evenly. Background: Full-screen gradient (blue-purple sky theme).
- **Level Selection Screen**: `ListView` of level cards, each a `Card` widget with elevation, showing name, status icons (lock/checkmark), and best time. Responsive: On wider screens (tablets), use `GridView` for 2-column layout.
- **In-Game Screen**: Divided vertically:
  - **Header (Top 15%)**: Row of stats (Score: X/100, Lives: hearts, Level: name in gold).
  - **Game Area (Middle 60%)**: `Stack` for falling words, with "SKY" label at top (absolute positioned, rounded white badge) and "GROUND" label at bottom.
  - **Input Area (Bottom 25%)**: Centered `TextField` with placeholder, above the device's virtual keyboard when focused. Ensure game area resizes dynamically when keyboard appears (use `MediaQuery.viewInsets.bottom` to adjust padding).
- **Pause Overlay**: Semi-transparent `ModalBarrier` with centered dialog showing stats and buttons.
- **Level Complete/Game Over Screens**: Full-screen overlays with animations, centered content, and action buttons.

**Responsive Guidelines**:

- Use relative sizing: e.g., `SizedBox(height: MediaQuery.of(context).size.height * 0.15)` for header.
- Support portrait only; lock orientation via `SystemChrome.setPreferredOrientations`.
- Test on various resolutions: iPhone SE (small), Pixel 8 (medium), iPad (large) – scale fonts/icons with `TextScaler`.
- Accessibility: Ensure minimum touch target sizes (48x48dp), high contrast ratios (>4.5:1).

### 6.2 Visual Hierarchy and Information Display

**Hierarchy Principles**: Prioritize gameplay elements with size, color, and position. Use whitespace for separation; bold key info.

**Core Elements**:

- **Title/Headers**: Large (3em equivalent, ~48sp), bold sans-serif font, centered with subtle shadow.
- **Stats Display**: Medium font (1.2em, ~20sp), evenly spaced in header row.
- **Falling Words**: High-contrast cards (white background, dark text) with incomplete word in large monospace font (1.5em, bold, letter-spaced), clue in smaller italic gray text below.
- **Labels (SKY/GROUND)**: Bold, rounded badges with shadow, positioned outside game boundaries.
- **Overlays**: Dark semi-transparent background, white text, green accents for positive (complete), red for negative (over).

**Color Palette** (from Section 1.4):

- Background: LinearGradient from #667eea (top) to #764ba2 (bottom).
- Words/UI: rgba(255,255,255,0.9) background, #333 text.
- Accents: Green (#4CAF50) for success, Red (#FF0000) for failure, Gold (#FFD700) for levels/achievements.
- Ensure dark mode compatibility: Invert colors if system dark theme detected.

**Typography**:

- System font fallback: sans-serif (e.g., Roboto on Android, San Francisco on iOS).
- Monospace for patterns: 'Courier New' or equivalent (e.g., 'monospace' in Flutter).
- Scale with device settings for accessibility.

### 6.3 Input Handling and Keyboard Optimization

**Input System**: Use `TextField` with `autofocus: true` during gameplay, uppercase conversion (`TextCapitalization.characters`), and no autocorrect/spellcheck to match prototype.

**Keyboard Optimization**:

- Virtual keyboard: QWERTY layout, light theme for visibility.
- Real-time checking: On `onChanged`, check input length >=4 and match against falling words (clear field on match).
- Enter key: Trigger check via `onSubmitted`.
- External keyboard support: Handle hardware keyboards for tablets.
- Touch gestures: Tap falling word to highlight/focus (optional for hints).
- Accessibility: Voice input compatible; screen reader labels for stats/words.

**Edge Cases**:

- Keyboard dismissal: Only on pause or level end.
- Input validation: Trim whitespace, ignore case.

### 6.4 Animation Specifications and Transitions

**Transition Philosophy**: Smooth, non-intrusive animations at 60 FPS for delight without distraction.

**Key Transitions**:

- **Screen Navigation**: FadeTransition (300ms) for menus; SlideTransition (400ms) for level start.
- **Overlay Appear**: ScaleTransition from center (500ms, Curves.easeOut).
- **Button Presses**: Scale down/up (200ms) with haptic feedback.

**In-Game Animations** (build on Section 5):

- **Word Spawn**: Fade in (300ms) at top.
- **Word Fall**: PositionAnimation linear (fallTime duration).
- **Level Intro/Complete**: Confetti particles or scale-in text (800ms).

**Implementation**: Use `AnimatedBuilder` or `ImplicitlyAnimatedWidget`; integrate with Flame if used for game loop.

### 6.5 Visual Feedback Systems (Correct/Incorrect Responses)

**Correct Response**:

- Matching word: Green flash (500ms, scale 1.05, opacity pulse), then fade out.
- Score update: Brief highlight in header.

**Incorrect/Neutral**:

- No feedback for mistypes (to avoid distraction); input remains for correction.

**Failure Feedback**:

- Ground hit: Red pulse (600ms, color shift to red, scale 1.05), then remove.
- Life loss: Heart icon shake (300ms) and fade to white.

**System-Wide**:

- Use consistent colors: Green success, Red failure.
- Accessibility: Pair with haptics/sounds (Section 7).
- Performance: Limit simultaneous animations to 5.

This section ensures a polished, intuitive UI that enhances the core gameplay while maintaining mobile optimization and accessibility.

---

## 7. Audio & Visual Effects

### 7.1 Sound Effects Library and Triggers

**Audio Integration Philosophy**: Incorporate subtle, non-intrusive sound effects to enhance immersion without overwhelming the player. All audio should be optional and respect user preferences (see Section 2.7). Use high-quality, short clips (<5 seconds) optimized for mobile playback to minimize latency and battery impact.

**Required Sound Effects Library**: Store audio assets in `assets/audio/` directory. Recommended formats: MP3 for Android, AAC for iOS (use cross-platform WAV for simplicity). Key effects include:

- **Success Sound**: Pleasant chime or "pop" for correct word completion (e.g., `success_chime.wav` – 0.5s uplifting tone).
- **Failure Sound**: Low thud or "crash" for word hitting ground (e.g., `ground_impact.wav` – 0.8s muffled impact).
- **Life Loss Warning**: Tense alert when lives < 2 (e.g., `low_lives_alert.wav` – 1s pulsing tone).
- **Level Start/Complete**: Fanfare jingle (e.g., `level_complete.wav` – 2s celebratory melody).
- **Button Click**: Soft click for UI interactions (e.g., `button_click.wav` – 0.2s subtle tap).
- **Word Spawn**: Gentle whoosh (optional, e.g., `word_spawn.wav` – 0.3s subtle entry sound).

**Implementation with Audioplayers Package**: Add `audioplayers: ^latest` to `pubspec.yaml`. Pre-load effects for low-latency playback.

```dart
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioPlayer _player = AudioPlayer();
  static bool soundEnabled = true;  // From user settings

  static Future<void> playSound(String assetPath) async {
    if (!soundEnabled) return;
    await _player.play(AssetSource(assetPath), volume: 0.8);
  }

  static void preloadSounds() {
    // Pre-cache all sounds at app init to reduce first-play latency
    _player.setSource(AssetSource('audio/success_chime.wav'));
    // Repeat for other assets
  }
}
```

**Trigger Logic**:

- **Correct Word**: Call `AudioManager.playSound('audio/success_chime.wav')` immediately after match confirmation.
- **Ground Hit**: Trigger `AudioManager.playSound('audio/ground_impact.wav')` on collision detection.
- **UI Events**: Play `button_click.wav` on button taps (e.g., pause, resume).
- **Volume Control**: Tie to settings slider (0-100%), applying to `_player.volume`.
- **Performance Note**: Limit concurrent plays to 3; use low-priority for overlapping sounds.

### 7.2 Background Music and Audio Loops

**Music Design**: Use calming, loopable tracks that match the sky-themed aesthetic – ambient electronic with subtle melodies to maintain focus during gameplay. Tracks should be 1-2 minutes long for seamless looping without repetition fatigue.

**Music Library**:

- **Main Menu/Level Select**: Upbeat, welcoming loop (e.g., `menu_music.mp3` – optimistic synths).
- **In-Game**: Level-specific variations increasing in tempo (e.g., `level_1_music.mp3` slow ambient → `level_5_music.mp3` intense pulse).
- **Victory/Game Over**: Short stingers overriding loop (e.g., `victory_jingle.mp3` – 5s triumphant).

**Implementation**:

```dart
class BackgroundMusicManager {
  static final AudioPlayer _bgPlayer = AudioPlayer();
  static bool musicEnabled = true;  // From settings
  static String? currentTrack;

  static Future<void> playBackgroundMusic(String assetPath) async {
    if (!musicEnabled || currentTrack == assetPath) return;
    await _bgPlayer.stop();
    await _bgPlayer.play(AssetSource(assetPath), volume: 0.4, mode: PlayerMode.mediaPlayer);
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    currentTrack = assetPath;
  }

  static void pauseMusic() {
    _bgPlayer.pause();
  }

  static void resumeMusic() {
    if (musicEnabled && currentTrack != null) {
      _bgPlayer.resume();
    }
  }

  static void stopMusic() {
    _bgPlayer.stop();
    currentTrack = null;
  }
}
```

**Flow Integration**:

- **App Launch**: Start `menu_music.mp3` on main menu.
- **Level Start**: Transition to level-specific track with fade-out/in (use volume tween over 1s).
- **Pause**: Call `pauseMusic()`; resume on unpause.
- **Settings Toggle**: If disabled, stop immediately; save preference.
- **Cross-Fade Logic**: For level changes, gradually reduce volume to 0, start new track, increase to target volume.

### 7.3 Particle Effects and Animations

**Particle System**: Enhance visual feedback with lightweight particles for engagement. Use `flutter_particles` or custom `Canvas` drawing for efficiency.

**Key Particle Effects**:

- **Correct Word**: Green sparkles bursting from word position (20-50 particles, 0.5s duration, upward velocity).
- **Ground Hit**: Red dust cloud at impact (30 particles, radial spread, 0.8s fade).
- **Level Complete**: Gold confetti rain from top (100 particles, 2s, random colors/velocities).
- **Spawn Effect**: Subtle blue glow fade-in around new word (10 particles, orbiting).

**Implementation Example** (using `AnimatedBuilder` for custom particles):

```dart
class ParticleEffect extends StatefulWidget {
  final Offset position;
  final Color color;
  // Other params...

  @override
  _ParticleEffectState createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _controller.forward().then((_) => setState(() {}));  // Auto-remove after
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Draw particles based on progress
        // Use CustomPaint for rendering
        return CustomPaint(painter: ParticlePainter(_controller.value, widget.color));
      },
    );
  }
}
```

**Integration**: Overlay particles in game `Stack`; trigger on events (e.g., add to list on correct guess, remove after animation).

### 7.4 Visual Feedback for Game Events

**Event-Specific Feedback** (build on Sections 5 and 6):

- **Correct Guess**: Word scales up 1.05x, green tint, fade-out (500ms `TweenAnimationBuilder`).
- **Ground Hit**: Red flash, slight shake (300ms `Transform.translate` with sine offset).
- **Life Loss**: Hearts pulse red (200ms), one fades to white.
- **Score Update**: Brief gold highlight on score text (300ms opacity tween).
- **Level Transition**: Full-screen fade with particle confetti.

**Consistency**: Use `Curves.easeInOut` for most; limit durations <1s. Test for motion sensitivity.

### 7.5 Accessibility Considerations for Audio

**Inclusive Design**:

- **Toggle Options**: Separate toggles for music, effects, and haptics in settings.
- **Haptic Feedback**: Use `HapticFeedback` as audio alternative (e.g., `mediumImpact()` for success).
- **Volume Defaults**: Start at 50%; respect system volume.

This section enhances the sensory experience while maintaining accessibility and performance, building on the core visuals from earlier sections.

---
