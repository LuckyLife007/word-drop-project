# Word Drop — Redesign: Timed Word Cards

**Branch**: `redesign/timed-word-cards` (created from `master` at `75ea4d4`)
**Started**: September 16, 2026
**Status**: Planning — no code changes yet. All open questions answered on
September 20, 2026 (D1–D34). Next: Plan step 2.

> **Resume here (next session):** all the open questions are answered
> (D1–D34). Start **step 2 of the Plan**: write the new game rules and the
> screen layout in this document. Then step 3 (models and managers).

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
| D20 | 2026-09-20 | **Screen contents above the keyboard (answers C2).** From top to bottom: <br>1. **Header** — stays as it is today: 2 lines (level name in gold, then SCORE · hearts · TIME), about 77px. <br>2. **Card grid** — the 2 × 3 grid from D17. Every card shows its hint, its clue and its countdown. Nothing is hidden and nothing needs a tap. <br>3. **Input row** — `[text field] [+] [Pause]`, about 78px. <br>The SKY label, the GROUND label and the red ground line are removed. <br>**The grid area scrolls when the screen is too small for 6 full cards. On a screen with enough height there is no scrolling and no scroll bar.** | The player must see all the information at all times. Scrolling is only a fallback for small screens, so D17 (2 × 3) and D19 (fixed font sizes) stay unchanged. |
| D21 | 2026-09-20 | **The keyboard cannot close during play (answers C3).** While the grid and the input row are visible, the code keeps the focus on the text field. If the player uses the system Back gesture, or any other action that would close the keyboard, **the game pauses and the pause overlay appears**. The layout therefore never changes size during play. | The cards never jump or change size. A closed keyboard always has one clear meaning: the game is paused. |
| D22 | 2026-09-20 | **Timers follow visibility (answers C3a, and F2).** When the grid and the input row are not visible, **all timers stop**: the card timers, the new-card interval and the game clock. They continue from the same values when play restarts. This applies to the pause overlay, the Game Over and Level Complete overlays, and the app in the background. | The whole game stops together. This also removes BUG-2 (the clock kept counting in the background). |
| D23 | 2026-09-20 | **Scrolling and hidden cards (answers C2a).** <br>• **C2a-1** Scrolling is **manual only**. The grid never scrolls by itself. The player scrolls when the player wants to. <br>• **C2a-2** A card **outside the visible area keeps its countdown**. It can reach zero, flash red and remove a life while the player does not see it. (D22 still applies: the timers stop only when the **whole** grid is hidden, for example during a pause.) <br>• **C2a-3** A **blinking arrow** shows the direction of cards outside the visible area: an up arrow when cards are above, a down arrow when cards are below. Both arrows can show at the same time. | Automatic scrolling moves the grid while the player reads, which is worse than a hidden card. The arrows tell the player where to scroll, so a hidden card is the player's choice, not a surprise. |
| D24 | 2026-09-20 | **The card shows a number and a bar (answers D-1).** <br>• The **seconds number** is on the same line as the hint, at the right end (for example `B-N-N-   12`). <br>• A **4px bar** on the bottom edge of the card gets shorter as the time runs out. <br>• Both turn amber at 5.0s (D25) and the card flashes red at zero (D15). | The number gives the exact value, and the bar gives the value at a glance. With 6 cards the player needs both. |
| D25 | 2026-09-20 | **Amber warning in the last 5 seconds (answers D-2).** At 5.0s the timer number and the timer bar turn amber. The value is the same on every level. The red flash at zero (D3, D15) does not change. | One rule for all 5 levels is easy to learn. The player finds the card in danger without reading 6 numbers. |
| D26 | 2026-09-20 | **The countdown starts after the entrance animation (answers D-3).** A new card fades or scales in over about 300ms. The countdown starts when the card is fully visible. | The player gets the full time T to read and to answer. See the note after the card-count table for the effect on the number of cards. |
| D27 | 2026-09-20 | **No reaction to typed letters (answers E1, keeps the D9 default).** The cards do not change while the player types. No highlight of matching cards, and no dimming of other cards. | Keeps the difficulty of the original design. A highlight lets the player find the word by trying letters. |
| D28 | 2026-09-20 | **Blinking arrow, no count (answers C2b).** <br>• One small arrow on the grid edge, centred: an up arrow above the top row, a down arrow below the bottom row. Both can show at the same time. <br>• It **blinks for as long as cards are outside the visible area** (about 1 second per cycle). <br>• It shows the **direction only**. It does not show how many cards are hidden. <br>• It turns **amber** when a hidden card is in its last 5 seconds (D25), and **red** at zero. | The direction is what the player needs to scroll. The colour still gives the warning for a hidden card, and no number keeps the grid edge narrow. |
| D29 | 2026-09-20 | **Whole seconds on the card (answers D-4).** The number counts 12, 11, 10 ... 1, 0. There is no decimal. The bar (D24) shows the finer detail. | A number that changes 10 times per second on 6 cards is busy and uses more battery. |
| D30 | 2026-09-20 | **"3, 2, 1, Go" countdown (answers F3).** <br>• The countdown runs at the **start of a level**. <br>• The countdown also runs at **every resume**, and the reason for the pause does not matter: the Pause button, the Back gesture (D21), or the app going to the background (D22). <br>• All timers stay stopped during the countdown and start again at "Go". <br>• Derived rule: the keyboard stays open during the countdown (D21), but the game ignores the input until "Go". | The player needs time to see the grid again before the timers run. One rule for all cases is easy to learn and easy to build. |
| D31 | 2026-09-20 | **The card time does not change with word length (answers A6, keeps the D9 default).** Every card in a level gets the same time T from D11. | The difficulty still grows inside a level, because the words get longer (D10/A4) and the time stays the same. It also keeps the card count math (D11) valid. |
| D32 | 2026-09-20 | **A pause is free (answers F5).** The player can pause at any moment, and a pause stops every timer: the card timers, the new-card interval and the game clock. There is **no cost**: no lost life, no lost points, and no time added to the game clock. The resume countdown (D30) also costs no clock time. | The player must be able to stop the game at any moment, for example for a telephone call. A penalty for a pause would punish normal life. |
| D33 | 2026-09-20 | **New tagline (answers G1): "Fill the gaps before the time ends."** It replaces "Complete the words before they fall!" in `main.dart` (splash screen and main menu), `README.md` and the store text. | The old tagline says "fall", which the redesign removes. The new tagline names the two rules: the missing letters and the timer. It uses no idiom, so players with little English understand it. |
| D34 | 2026-09-20 | **The name stays "Word Drop" for now (answers G3).** We decide the final name at Plan step 6, before release. The store check on 2026-09-20 found many games with this name (see the note below this table). | The name is a store-discovery problem, not a design problem, and it does not block the redesign. A rename now would touch the code and all the documents two times. |

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

**Store check for the name, 2026-09-20 (data for D34).** A web search only, not
a trademark search. Google Play also allows two apps with the same name.

| Name | Result |
|------|--------|
| **Word Drop** (current) | Used by many games. Google Play: Random Salad Games, dev.mgtc, "Word Drops" by Kozakura, and "Word Drop – Word Games" (removed 2026-04-24). App Store: "Word Drop Game" by Angel Olivera, "Word Drop – Word Puzzle Game", "Word Drop – Beat Gravity!" by Munns Media. Web: worddropgame.com. Most are falling-tile games, so they are close to the **old** design. |
| **Word Fuse** (first choice on 2026-09-20) | Used by 4 or more Android games (Game Gargoyle, KSDUTT with 500,000+ installs, Epoch Sol, "Word Fuse FREE") and by wordfuse.net. |
| **Tickword** | Used: a word game with a 10-second timer, shown on Hacker News in April 2026. "Tick Tock Word" is also on the App Store. |
| **Gap Race** | **No game found.** The near names (Word Race, Word Rush, Word Fusion) are different games. Best candidate if we rename at Plan step 6. |

**Effect of D26 (added 2026-09-20):** the countdown starts after the ~300ms
entrance animation, so a card holds its position for **T + 0.3s**, not T. The
automatic count is then ceil((T + 0.3) ÷ D): Level 1 gives 7, and Levels 2 to 5
give 6. The limit of 6 comes from the code (D12, D18), and the extra card waits
for a free position (D16).

(History: the first version of this table added the 600ms flash to T, which
gave 7 cards on Level 1. D13 removed that.)

**Height budget for D20 (measured 2026-09-20).** The header and the input row
use the sizes of the code on `master` at `75ea4d4`. A card needs about 70px
for a hint and a 2-line clue, and about 84px for a 3-line clue. Three rows
with 8px gaps therefore need 216px to 268px.

| Screen | Free height above the keyboard | Grid needs | Result |
|--------|-------------------------------|------------|--------|
| Small phone, 360 × 640 | 640 − 24 (status bar) − 280 (keyboard) − 77 (header) − 78 (input row) = **181px** | 216–268px | **Scrolls** |
| Normal phone, 390 × 844 | 844 − 47 − 34 (home bar) − 336 (keyboard) − 77 − 78 = **272px** | 216–268px | Fits, no scroll |

This is why D20 adds scrolling for small screens. **Test item T1 stays open:**
measure the real free height on a 360 × 640 device, because keyboard height
changes with the keyboard app.

---

## Open Questions

We answer these one group at a time. Move each answer to **Decisions**.

### Group A — Core rules

- ~~A1 · A2 · A3 · A4 · A5~~ → Decided: D6, D7, D8, D10
- ~~A6 (time by word length)~~ → Decided: D31 (no)

### Group B — Timing and difficulty per level

- ~~B1 · B2~~ → Starting values in D11 (tune after testing)
- ~~B5 · B6~~ → Decided: D10
- ~~B3 (maximum cards)~~ → Decided: D18
- ~~B4 (full grid)~~ → Decided: D16

### Group C — Screen layout

- ~~C1 (card positions)~~ → Decided: D17
- ~~C2 (contents above the keyboard)~~ → Decided: D20
- ~~C3 (keyboard opens and closes)~~ → Decided: D21
- ~~C2a-1 · C2a-2 · C2a-3 (scrolling and hidden cards)~~ → Decided: D23
- ~~C2b (arrow details)~~ → Decided: D28
- ~~C4 (text fit)~~ → Decided: D19. Word bank facts that support D19:
  - Hints: 6 to 10 characters.
  - Clues: 300 clues, 9 to 54 characters, average 34. 130 clues are longer than 35 characters, and 61 are longer than 40.
  - A 2-column card is about 165px wide on a normal phone. A clue line holds about 22 to 24 characters at 12px.
- **Test item T1 (updated 2026-09-20):** on a small phone (for example, 360 × 640)
  about 181px of height is free above the keyboard, and 3 rows need 216px to
  268px. Measure this on a real device, because the keyboard height changes with
  the keyboard app. **D20 answers the case where the rows do not fit: the grid
  scrolls.** Test that the scrolling grid, the manual scroll (D23) and the
  blinking arrow (D28) work on that screen.

### Group D — The card timer

- ~~D-1 (timer display)~~ → Decided: D24
- ~~D-2 (low-time warning)~~ → Decided: D25
- ~~D-3 (timer start)~~ → Decided: D26
- ~~D-4 (exactness of the number)~~ → Decided: D29

### Group E — Input and feedback

- ~~E1 · E2 · E3~~ → Decided: D27, D10

### Group F — Pause, lifecycle, and flow

- ~~F1 · F4~~ → Decided: D10
- ~~F2 (app in the background)~~ → Decided: D22 (yes, all timers stop)
- ~~F3 (countdown at level start)~~ → Decided: D30 (also at every resume)
- ~~F5 (cost of a pause)~~ → Decided: D32 (no cost)

### Group H — Manual new card ("+" button)

- ~~H1a · H1b · H1c · H1d · H1e~~ → Decided: D14
- ~~D13-Q (red flash detail)~~ → Decided: D15

### Group G — Text and documents

- ~~G1 (tagline)~~ → Decided: D33
- ~~G3 (game name)~~ → Decided: D34 (keep "Word Drop" for now; decide at Plan step 6)
- (G2 moved to the Plan, step 6.)

**All open questions are now closed.** The next step is step 2 of the Plan:
write the new game rules and the screen layout in this document.

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
| BUG-2 | `game_screen.dart` | No automatic pause when the app goes to the background. The `Stopwatch` keeps counting (best time too long). Animations stop, but the spawn timer keeps adding words. | Yes — **D22** makes all timers stop when the grid is not visible. Check this again after the build. | Open |
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
