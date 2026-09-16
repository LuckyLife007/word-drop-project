# Word Drop — Redesign: Timed Word Cards

**Branch**: `redesign/timed-word-cards` (created from `master` at `75ea4d4`)
**Started**: September 16, 2026
**Status**: Planning — no code changes yet

> **Resume here (next session):** answer **C2** (screen contents above the
> keyboard — proposed: header → 2 × 3 grid → input row [field][+][Pause]) and
> **C3** (keyboard closes during play — recommended: (a) cards keep size and
> position; tap grid or field to reopen keyboard). Then Groups D, E1, F2, F3, A6, G.

---

## What This Document Is

This document records the redesign of Word Drop from "falling words" to
"timed word cards". It has four parts:

1. **Decisions** — what we agreed. Each decision has a number, a date and a reason.
2. **Open questions** — what we must still decide.
3. **Plan** — the order of the work, after we make the decisions.
4. **Bug record** — bugs found in the old design. We check them again after the redesign.

Update this document each time we make a decision or finish a step.
When the redesign is complete, the final decisions go into
`word_drop_documentation_1-7.md` and `PROGRESS.md`.

---

## Why We Are Changing the Design

Words that fall from the sky to the ground work on a laptop screen. On
standard mobile devices they do not work well. Testing showed this. Main
causes:

- The on-screen keyboard uses about half of the screen height. The fall area
  becomes very short.
- The game area changes height when the keyboard opens or closes, so the words
  jump.
- There is little horizontal space, so the cards overlap or get cut off.

---

## Guiding Principle

**The redesign changes only how the words are presented on the screen.**
Everything else stays the same as the original design, unless we decide
otherwise here. When a question is not about presentation, the default
answer is "keep the original behaviour" (see D9).

---

## Decisions

| # | Date | Decision | Reason |
|---|------|----------|--------|
| D1 | 2026-09-16 | Words do **not** fall. Word cards appear on the screen, and each card has **its own countdown timer**. | Falling motion does not work well on mobile screens (see above). |
| D2 | 2026-09-16 | If the player types the word before the card's timer reaches zero, the card **flashes green, disappears, and the player gets points**. | Keeps the positive feedback from the old design. |
| D3 | 2026-09-16 | If a card's timer reaches zero, the card **flashes red and disappears**. | Keeps the failure feedback from the old design. |
| D4 | 2026-09-16 | All redesign work happens on the branch `redesign/timed-word-cards`. We merge to `master` only when the work is complete and tested. | Keeps `master` stable. |
| D5 | 2026-09-16 | We fix the bugs from the old design **after** the redesign, not before. We check each bug again, because the redesign can remove some of them. | Prevents work on code that we will delete. |
| D6 | 2026-09-16 | When a card's timer reaches zero, the player **loses 1 life**. This is the same penalty as a word that hit the ground in the old design. There is no score deduction. When lives reach 0, the game ends (Game Over). (Answers A1.) | Keeps the penalty from the original design. |
| D7 | 2026-09-16 | The **lives system stays**. (Answers A2, because D6 needs lives.) | D6 uses lives as the penalty. |
| D8 | 2026-09-16 | The level goal stays: **20 correct words = 100 points** (5 points per word). (Answers A3.) | Same as the original design. |
| D9 | 2026-09-16 | **Guiding principle:** only the presentation of the words changes. All other rules and features stay as in the original design, unless a decision here changes them. | A phone screen with the keyboard open is too small for falling words. The rest of the game design still works. |
| D10 | 2026-09-16 | Kept from the original design because of D9. Change any of these if you want to: <br>• **A4** Word length order in each level: words 1–4 = 6 letters, 5–8 = 7, 9–12 = 8, 13–16 = 9, 17–20 = 10. <br>• **A5** Best completion time for each level stays the performance record. <br>• **B5** Level names stay: Strolling, Jogging, Running, Bolting, Impossible. <br>• **B6** Lives per level stay: 3 / 4 / 5 / 6 / 7. <br>• **E2** No feedback for a wrong word. <br>• **E3** A match needs the full word. The same word is never on the screen twice, so only one card can match. <br>• **F1** Pause stops all card timers, the spawn timer and the clock. Resume continues from the same values. <br>• **F4** Game Over, Level Complete and Pause overlays stay as they are. | D9 |
| D11 | 2026-09-16 | **Starting values** for timing (answers B1 and B2 for now). The card timer uses the old fall time, and the new-card interval uses the old spawn delay. We tune these after testing on a phone. | D9. The old fall time was already "the time the player has to answer". |
| D12 | 2026-09-16 | The code **enforces a maximum number of cards** on the screen. The timing numbers alone do not guarantee it (see the table below D11). The maximum is the number of grid positions (proposed: 6, see B3 and C1). | Timing math, timer drift and the "+" button can all add more cards. |
| D13 | 2026-09-16 | The **600ms red flash happens inside the card's timer**, at the end. It does not add time. A card is on the screen for exactly its timer length. (Detail: D15.) | The total time of a card must stay the same as its timer. |
| D14 | 2026-09-16 | Add a **"+" button** that shows a new card immediately. (Answers H1.) <br>• **H1a** The player can use it **at any time when a grid position is free**. It is disabled when the grid is full. <br>• **H1b** After a manual card, the **automatic interval starts again from zero**. <br>• **H1c** The button is **next to the Pause button**. <br>• **H1d** The Enter key does **not** add a card. <br>• **H1e** **No change to best times** and no progress reset. A best time counts with or without "+". | Removes idle waiting on slow levels. Using "+" is a valid way to get a better time on a replay (for example, Level 1 automatic first, then Level 1 again with "+"). H1d: Enter to add a card can easily confuse the player. |
| D15 | 2026-09-16 | **Red flash detail (answers D13-Q, option a).** The player can answer a card for **T − 0.6s**. Then the countdown shows 0, the card flashes red for the last 0.6s, and the player **loses the life when the flash starts**. The player **cannot answer a red card**. The card disappears at exactly T. | Red always means "failed". The loss of 0.6s of answer time is small (4% of 15s on Level 5). |
| D16 | 2026-09-16 | **Full grid (answers B4).** When the grid is full, the next automatic card **waits**. It appears as soon as a position becomes free. Derived rules: <br>• A waiting card's timer does not start until the card appears. <br>• Only 1 card can wait. The automatic interval stops while a card waits, and starts again from zero when the waiting card appears (same rule as H1b). <br>• "+" stays disabled while the grid is full, so "+" cannot go before a waiting card. | The player never loses a card from the level flow, and the grid never goes over the maximum. |
| D17 | 2026-09-16 | **Layout: a fixed 2 × 3 grid** (2 columns, 3 rows = 6 positions). A card stays in its position until it disappears. (Answers C1.) | Cards cannot overlap, and they do not move when other cards go or when the keyboard opens. Fits the maximum of 6 cards. |
| D18 | 2026-09-16 | **Maximum 6 cards** on the screen, one for each grid position. (Answers B3, value for D12.) | Matches D17. |
| D19 | 2026-09-16 | **Card text uses fixed font sizes** (answers C4, option a). The sizes fit the longest hint (10 characters) and a clue of up to 3 lines. The text shrinks automatically **only** on small phones or with large system text. We do not change the word bank clues. | All cards look the same and are quick to read. The longest clues (54 characters) need 3 lines in a card about 165px wide. |

**D11 starting values:**

| Level | Name | Card timer (old fall time) | New card every (old spawn delay) | Lives |
|-------|------|----------------------------|----------------------------------|-------|
| 1 | Strolling  | 30s | 5.0s | 3 |
| 2 | Jogging    | 26s | 4.5s | 4 |
| 3 | Running    | 22s | 4.0s | 5 |
| 4 | Bolting    | 18s | 3.5s | 6 |
| 5 | Impossible | 15s | 3.0s | 7 |

**Maximum cards on the screen (updated 2026-09-16):** the timing does **not**
guarantee a maximum. If the player answers no cards, a card is on the screen
for exactly its timer T (D13: the red flash is inside T). A new card comes
every D seconds. The count reaches **ceil(T ÷ D)**. When T ÷ D is a whole
number, it can be 1 more for a moment, because a card goes and a card comes
at the same time.

| Level | T ÷ D | Max cards (automatic only) |
|-------|-------|----------------------------|
| 1 | 30 ÷ 5.0 = 6.00 | 6, or 7 for a moment |
| 2 | 26 ÷ 4.5 = 5.78 | 6 |
| 3 | 22 ÷ 4.0 = 5.50 | 6 |
| 4 | 18 ÷ 3.5 = 5.14 | 6 |
| 5 | 15 ÷ 3.0 = 5.00 | 5, or 6 for a moment |

Timer drift, the app in the background (BUG-2), and the "+" button (D14) can
add more cards. **So the code enforces the maximum (D12).**

(History: the first version of this table added the 600ms flash to T, which
gave 7 cards on Level 1. D13 removed that.)

---

## Open Questions

We answer these one group at a time. Move each answer to **Decisions**.

### Group A — Core rules

- ~~A1 · A2 · A3 · A4 · A5~~ → Decided: D6, D7, D8, D10
- **A6.** Does a card's timer length change with the word length (longer words = more time)? (New question: the old design had no equivalent. Default under D9: no, all cards in a level get the same time.)

### Group B — Timing and difficulty per level

- ~~B1 · B2~~ → Starting values in D11 (tune after testing)
- ~~B5 · B6~~ → Decided: D10
- ~~B3 (maximum cards)~~ → Decided: D18
- ~~B4 (full grid)~~ → Decided: D16

### Group C — Screen layout

- ~~C1 (card positions)~~ → Decided: D17
- **C2.** What does the area above the keyboard contain? (Header, cards, input field.) The SKY and GROUND labels and the red ground line no longer apply.
- **C3.** Does the layout stay the same when the keyboard opens and closes?
- ~~C4 (text fit)~~ → Decided: D19. Word bank facts that support D19:
  - Hints: 6 to 10 characters.
  - Clues: 300 clues, 9 to 54 characters, average 34. 130 clues are longer than 35 characters, and 61 are longer than 40.
  - A 2-column card is about 165px wide on a normal phone. A clue line holds about 22 to 24 characters at 12px.
- **Test item T1:** on a small phone (for example, 360 × 640), only about 190px of height is free above the keyboard. Test that 3 rows of cards fit. If they do not fit, we change D17 or D19.

### Group D — The card timer

- **D-1.** How does the card show its timer? Options: number of seconds, a progress bar, a ring around the card, or a combination.
- **D-2.** Does the card change (colour, shake, pulse) when little time remains? If yes, at what point?
- **D-3.** Does the timer start when the card starts to appear, or after its entrance animation ends?

### Group E — Input and feedback

- ~~E2 · E3~~ → Decided: D10
- **E1.** When the player types, do we highlight cards that match the typed letters so far? (New question. Default under D9: no.)

### Group F — Pause, lifecycle, and flow

- ~~F1 · F4~~ → Decided: D10
- **F2.** Does the game pause automatically when the app goes to the background? (Proposed: yes. This also fixes BUG-2.)
- **F3.** Do we add the "3, 2, 1, Go" countdown at level start now? (It is in the original design but was never built.)

### Group H — Manual new card ("+" button)

- ~~H1a · H1b · H1c · H1d · H1e~~ → Decided: D14
- ~~D13-Q (red flash detail)~~ → Decided: D15

### Group G — Text and documents

- **G1.** New tagline. The current tagline is "Complete the words before they fall!".
- **G3.** Does the name "Word Drop" still fit?
- (G2 moved to the Plan, step 6.)

---

## Plan

The plan becomes detailed after we answer the open questions. Proposed order:

1. Answer the open questions (Groups A → G).
2. Write the new game rules and the screen layout in this document.
3. Change the models and the managers (`LevelConfig`, `GameManager`).
4. Build the new game screen in stages, with a test on a mobile device after each stage.
5. Check each bug in the bug record again. Fix the bugs that still exist.
6. Update `README.md`, `PROGRESS.md`, `word_drop_documentation_1-7.md` (sections 1, 2.4, 5, 6) and the widget test.
7. Test the full game on mobile devices. Then merge to `master`.

---

## Bug Record (from the review on 2026-09-16, commit `75ea4d4`)

Bugs use the prefix `BUG-` so they do not mix with question IDs.
Check each bug again after the redesign. Set **Status** to one of:
`Open` · `Fixed` · `No longer applies`.

| # | Area | Bug | Probably affected by redesign? | Status |
|---|------|-----|-------------------------------|--------|
| BUG-1 | `game_screen.dart` | If the player pauses in the first ~400ms, `_startSpawnTimer()` makes a spawn timer while paused. On resume, a second timer starts. The first timer never stops, so words spawn twice as fast. | Yes — spawn logic will change. The same risk can come back in the new code. | Open |
| BUG-2 | `game_screen.dart` | No automatic pause when the app goes to the background. The `Stopwatch` keeps counting (best time too long). Animations stop, but the spawn timer keeps adding words. | Partly — the new card timers have the same risk. | Open |
| BUG-3 | `game_screen.dart` | The layout uses a card width of 190px, but a card can be 210px wide. Wide cards at the right edge lose up to 20px. A clue on two lines makes a card taller than the 70px that the overlap check uses. | Yes — card placement will change. | Open |
| BUG-4 | `assets/data/word_bank.json` | Two hints do not match their words: `PROFESSOR` → `P----ES-OR` (letter 6 must be `S`); `PLAYGROUND` → `PLA---R-U-` (letter 7 must be `O`). | No | Open |
| BUG-5 | `pubspec.yaml` | `assets/audio/` is in the asset list, but Git does not store the empty folder. A fresh clone fails `flutter test` and builds. | No | Open |
| BUG-6 | `test/widget_test.dart` | The smoke test fails: the splash screen's 1500ms `Future.delayed` is still pending when the test ends. | No | Open |
| BUG-7 | `game_manager.dart` | Unused duplicate logic: `_score`, `_lives`, `checkAnswer()`, `_handleCorrectAnswer()`, `_handleWrongAnswer()`, `_advanceToNextLevel()`. The game screen does not use them. | Maybe — `GameManager` will change. | Open |
| BUG-8 | `main.dart` | Wrong comments: the splash screen does not load progress (Level Select does), and the orientation comment says upside-down portrait is blocked (the code only sets `portraitUp`). | No | Open |
| BUG-9 | `PROGRESS.md` | Names a method `advanceLevel()` that does not exist. | Yes — `PROGRESS.md` will be rewritten. | Open |
| BUG-10 | `game_manager.dart` | 2 analyzer info notes: unnecessary string interpolation at lines 641 and 658. | Maybe | Open |

### Features in the old design document that are not built

For reference only. Decide in the open questions if they stay in scope:
How to Play, Settings and About screens; audio; particles; haptics; the
"3, 2, 1, Go" countdown; spawn fade-in; heart shake on life loss; the level
info button; fall speed that changes with screen height (no longer applies).
