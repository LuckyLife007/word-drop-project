# Word Drop - Flutter Mobile Game

A word puzzle game where players complete partially hidden words before they fall from the sky to the ground.

## What This Game Does

Players see words falling down the screen with missing letters (like `_TT__T_ON` for "ATTENTION"). They have to:
- Read the incomplete word pattern
- Read a clue (like "What you pay when listening")
- Type the complete word before it hits the ground
- Complete 20 words per level to advance

## Game Features

- **5 Progressive Levels**: From "Strolling" (easy) to "Impossible" (very challenging)
- **100-Word Database**: 20 words each of 6, 7, 8, 9, and 10 letters
- **Lives System**: 3-7 lives depending on level difficulty
- **Speed Scaling**: Words fall faster and spawn more frequently as levels increase
- **Clean UI**: Sky-themed gradient background with clear visual feedback

## Tech Stack

- **Framework**: Flutter (Dart)
- **Target Platforms**: Android (MVP focus), iOS, Windows (future)
- **Minimum Android**: API 21 (Android 5.0)
- **Minimum iOS**: iOS 12.0

## Project Status

🚧 **Currently in MVP Development** 🚧

We're building the Android version first to get a working prototype, then we'll add polish and additional platform support.

## Development Notes

This is a learning project, so all code includes detailed comments explaining:
- Why we chose specific approaches
- How different parts work together
- Flutter/Dart concepts for beginners

## File Structure (Planned)

```
word_drop/
├── assets/
│   ├── data/
│   │   └── word_bank.json      # All game words with patterns and clues
│   └── audio/                   # Sound effects and music (future)
├── lib/
│   ├── main.dart                # App entry point
│   ├── screens/                 # Different game screens
│   ├── models/                  # Data structures (words, levels, etc.)
│   ├── managers/                # Game logic managers
│   └── widgets/                 # Reusable UI components
└── pubspec.yaml                 # Project dependencies
```

## Design Reference

See `word_drop_documentation_1-7.md` for complete game design specifications including:
- Detailed gameplay mechanics
- Level progression system
- UI/UX specifications
- Audio and visual effects plans

## Next Steps

1. ✅ Create project structure
2. ⏳ Set up Flutter project
3. ⏳ Build word bank JSON
4. ⏳ Create basic UI screens
5. ⏳ Implement falling word mechanics
6. ⏳ Add scoring and level progression
7. ⏳ Polish with audio/visual effects

---

**Building with**: Claude (Anthropic AI) as pair programming partner
**Learning Focus**: Flutter development, game mechanics, mobile optimization
