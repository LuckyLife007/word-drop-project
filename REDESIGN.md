# Word Drop — Redesign: Timed Word Cards

**Branch**: `redesign/timed-word-cards` (created from `master` at `75ea4d4`)
**Started**: September 16, 2026
**Status**: Building. Decisions D1–D34 and the Specification are complete.
Plan steps 1 to 3 are done, and **stage 4.1 (static layout) is built and tested
on a real phone**. Next: open question I1 (make the sections shorter), then
stage 4.2.

> **Resume here (next session):** Plan steps 1 to 3, **stages 4.1 and 4.2**,
> and the height work of **Group I** are done and tested on a real phone.
> **Next: stage 4.3** — the automatic new-card interval, the waiting card when
> the grid is full, and the "+" button (S5).

---

## What This Document Is

This document records the redesign of Word Drop from "falling words" to
"timed word cards". It has five parts:

1. **Decisions** — what we agreed. Each decision has a number, a date and a reason.
2. **Open questions** — what we must still decide. All are closed.
3. **Specification** — the complete new rules and layout, built from the decisions.
   This is the part to read before you write code.
4. **Plan** — the order of the work.
5. **Bug record** — bugs found in the old design. We check them again after the redesign.

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

**Measured on the phone, 2026-09-20 (stage 4.1 build).** Device: Redmi
23106RN0DA, Android 13, screen 720 × 1600 physical = **360 × 800 logical**.
Numbers read from 3 screenshots (1 screenshot pixel = 0.625 logical pixels).

| Part of the screen | Logical height | My estimate in S2 |
|--------------------|----------------|-------------------|
| Status bar | 37px | ~24px |
| Header (2 lines) | **84px** | 77px |
| **Free height for the grid** | **266px** | 270px on a 390 × 844 phone |
| Input row | **78px** | 78px |
| Keyboard (MIUI, with the tool row) | 290px | ~40% = 320px |
| Navigation bar | ~45px | not counted |

The card renders at exactly **88px**, as `kCardHeight` sets.

**What the grid needs:** 3 cards (264px) + 2 gaps (16px) + top and bottom
padding (16px) = **296px**. The phone gives 266px. **The grid is 30px too
tall.** The screenshots show this: 2 full rows and most of the third row.

**Result after levers 1 and 2 (measured 2026-09-21, same phone, 3 steps):**

| Part | Start | Step 1 | Step 2 | Step 3 (final) |
|------|-------|--------|--------|----------------|
| Header | 84px | 52px (no level name) | 52px | **~55px, level name back** |
| Input row | 78px | 68px | **63px** | 63px |
| Free height for the grid | 266px | 314px | 319px | **~316px** |

The grid needs 296px, so **all 6 positions now fit with the keyboard open**.
Scrolling (D23) and the arrows (D28) stay in the design for phones that are
shorter than this one.

What each step changed:

- **Step 1** — header: the gold level-name line and its 8px gap removed,
  padding 10 → 6. Input row: padding 12/14 → 8/10, buttons 52 → 48px,
  icons 26 → 24, field text 20 → 19, inner padding 14 → 11.
- **Step 2** — input row only: field text 19 → 17, hint 15 → 14, inner padding
  11 → 7, outer padding 8/10 → 6/8, buttons 48 → 42px, icons 24 → 22.
  **Z3 tested the 42px buttons on the phone and reported that they are still
  easy to tap**, so the value stays (see I3).
- **Step 3** — the level name comes back at 11px with a 2px gap; stat labels
  10 → 9px, gap inside a stat block 2 → 1px, numbers 17 → 15px, header padding
  6 → 5px. The name, the labels and the numbers use a tight line box
  (`height: 1.1`), which removes the empty space above and below the letters.

**The Material text field has a minimum height of its own.** It stays about
44px even with 7px of inner padding, so more padding cuts do not make the input
row shorter. Only a different field style would.

**Where 30px can come from (open question I1):**

| Lever | Saving | Cost |
|-------|--------|------|
| Header 84px → ~50px: move the level name into the pause overlay | 34px | The level name is not visible during play. |
| Input row 78px → ~64px: buttons 52px → 44px, less padding | 14px | Smaller touch targets. 44px is still above the 48dp guide only with the padding included — measure again. |
| Grid padding 16px → 8px | 8px | Cards sit closer to the screen edges. |
| Card 88px → 80px: clue on 2 lines at 11px | 24px | Hides text on 61 long clues. Contradicts D20. |
| Gap 8px → 6px | 4px | Cards look closer together. |

The first lever alone is enough (34px ≥ 30px). The first three together give
56px, which also covers phones a little shorter than this one.

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
- ~~Test item T1~~ → **Answered on a real phone, 2026-09-20.** Device: Redmi
  23106RN0DA, Android 13, stage 4.1 build. With the keyboard open the player
  sees **2 full rows and part of the third row** (about 5 of the 6 positions).
  The grid scrolls, the manual scroll works, and the position order 0,1 / 2,3 /
  4,5 is correct. **Result: scrolling is the normal case on this phone, not an
  exception.** The blinking arrows (D28, stage 4.5) are therefore needed, not
  optional. The card height of 88px stays.

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

### Group I — Section heights (new, from the device test on 2026-09-20)

- **I1.** Which sections do we make shorter, so that 3 card rows fit with the
  keyboard open? The grid is 30px too tall on the test phone. The table above
  the Open Questions lists 5 levers and what each one saves. **Z3 asked for this
  change after seeing the screenshots.** It is the first item for the next
  session.
- **I2.** Does the level name stay on the game screen? Lever 1 moves it into the
  pause overlay, where the name is already shown.
- **I3.** How small may the `[+]` and Pause buttons become? They are 52px now.
  The Android guide asks for 48dp of touch target.

**Answers, 2026-09-21 (all closed):**

- **I1 → Done in 3 steps** (see the table in the Decisions part). Header
  84px → ~55px, input row 78px → 63px, so the free height for the grid goes
  from 266px to ~316px. The card height (88px), the 3-line clue, the grid
  padding and the gap did **not** change, so no text is hidden.
- **I2 → The level name stays on the game screen.** It was removed in step 1
  and brought back in step 3 at 11px. Z3 asked for it back.
- **I3 → The buttons are 42px.** Z3 tested them on the phone and reported that
  they are still easy to tap. This is below the Android guide of 48dp, so test
  it again with other players or on a smaller phone.
- **I4 → Closed.** The header is not too plain, because the level name is back.

### Group G — Text and documents

- ~~G1 (tagline)~~ → Decided: D33
- ~~G3 (game name)~~ → Decided: D34 (keep "Word Drop" for now; decide at Plan step 6)
- (G2 moved to the Plan, step 6.)

**All open questions are closed**, including Group I (section heights), which
was answered on the phone on 2026-09-21.

---

## Specification (Plan step 2)

Written 2026-09-20 from decisions D1 to D34. This section is the single source
for the build. When this section and an older decision row disagree, this
section wins, and the decision row gets a correction.

### S1. The game in short

1. The game shows word cards in a grid. Each card has a hint, a clue and its
   own countdown.
2. The player types the full word into one input field.
3. A correct word gives 5 points. The card flashes green and goes.
4. A card that reaches zero flashes red and goes. The player loses 1 life.
5. 20 correct words (100 points) complete the level. 0 lives end the game.

### S2. Screen layout

The screen has 4 areas, from top to bottom (D20):

| # | Area | Height | Contents |
|---|------|--------|----------|
| 1 | Header | ~77px, fixed | Level name in gold. Below it: SCORE, hearts, TIME. No change from the code on `master`. |
| 2 | Card grid | All remaining space | 2 columns × 3 rows = 6 positions (D17, D18). |
| 3 | Input row | ~78px, fixed | `[text field] [+] [Pause]` (D14/H1c). |
| 4 | Keyboard | ~40% of the screen | Always open during play (D21). |

Grid geometry:

- Outer padding: 12px left and right, 8px top and bottom.
- Gap between cards: 8px.
- Card width on a 360px screen: (360 − 24 − 8) ÷ 2 = **164px**.
- Card height: **88px** (hint row 22px, gap 4px, clue up to 3 lines at 14px
  line height = 42px, padding 8px + 8px, timer bar 4px).
- Three rows need 3 × 88 + 2 × 8 = **280px**.

**When the grid scrolls.** The free height for the grid is
`screen height − safe areas (~81px) − keyboard (~40%) − header (77px) − input row (78px)`,
which gives `0.60 × screen height − 236`. The grid needs 280px. So the grid
scrolls on every phone with a logical height below about **860px**.

| Device size | Free height | Result |
|-------------|-------------|--------|
| 360 × 640 | 148px | Scrolls. About 1.5 rows are visible. |
| 390 × 844 | 270px | Scrolls a little. About 2.9 rows are visible. |
| 412 × 915 | 313px | No scrolling. |

**This is the cost of the 2-line header (your C2 answer).** Two levers can
remove the scrolling on more phones, if you want them later:

- Move the level name into the pause overlay. The header becomes ~50px, and the
  limit falls from 860px to about 815px.
- Use an 11px clue font with a maximum of 2 lines. The card becomes 74px, three
  rows need 238px, and the limit falls to about 790px. **Warning:** 61 clues are
  longer than 40 characters, so this option hides text. It contradicts D20.

Scrolling rules (D23, D28):

- The player scrolls with a finger. The grid never scrolls by itself.
- A card outside the visible area keeps its countdown. It can fail unseen.
- An up arrow shows above the grid when cards are above the visible area.
- A down arrow shows below the grid when cards are below the visible area.
- Each arrow blinks with a 1000ms cycle for as long as cards are hidden.
- The arrow shows the direction only. It shows no number.
- The arrow is white. It turns amber when a hidden card is in its last 5
  seconds. It turns red while a hidden card shows its red flash.

### S3. The word card

Contents, top to bottom:

1. **Hint row:** the hint pattern on the left (monospace, 18px, bold, letter
   spacing 2), and the **seconds number** on the right (16px, bold, whole
   seconds, D24/D29).
2. **Clue:** italic, 12px, grey, up to 3 lines, centred (D19/D20).
3. **Timer bar:** 4px high, on the bottom edge, full width at the start and
   0 width at the end (D24).

Card states:

| State | Time | Look |
|-------|------|------|
| Entering | 0 to 300ms | Fade 0→1 and scale 0.95→1.0. The countdown does not run (D26). |
| Running | until 5.0s remain | White card. Number and bar in the brand colour `#667eea`. |
| Warning | last 5.0s | Number and bar turn amber `#FFA000` (D25). |
| Failed | last 0.6s | Red flash (D3, D15). The number shows 0. The card cannot be matched. |
| Matched | 500ms | Green tint, scale 1.0→1.05 for 250ms, then fade out for 250ms. |

Card life, for a level card time of T seconds:

| Moment | Event |
|--------|-------|
| 0ms | The card appears in a free grid position and starts its entrance. |
| 300ms | The entrance ends. The countdown starts at T (D26). |
| T − 5.0s | The number and the bar turn amber (D25). |
| T − 0.6s | The player loses 1 life. The red flash starts. The card stops accepting answers (D15). |
| T | The card is removed. Its grid position becomes free. |

A card therefore holds its position for **T + 0.3 s**.

### S4. Grid positions

- The grid has 6 fixed positions. The code numbers them 0 to 5 in reading
  order: top-left, top-right, middle-left, middle-right, bottom-left,
  bottom-right.
- A new card takes the **free position with the lowest number**.
- A card keeps its position until it is removed. Cards never move (D17).
- Empty positions stay empty. The grid does not close the gap.

### S5. How new cards appear

| Source | Rule |
|--------|------|
| Automatic | A new card appears every D seconds (D11). The interval runs only while the game runs. |
| Full grid | When all 6 positions are full, the next card **waits**. It appears when a position becomes free. Its countdown starts then. Only 1 card waits at a time. The interval stops while a card waits, and starts again from zero when the waiting card appears (D16). |
| "+" button | The player adds a card at once. The button is disabled when the grid is full or when a card waits. After a manual card, the interval starts again from zero (D14). |
| Level start | The first card appears after the "3, 2, 1, Go" countdown (D30). |

The word for each card comes from `GameManager().getNextWord(activeWords: ...)`.
`activeWords` holds the answers of all cards on the screen, so the same word
cannot appear two times at once.

### S6. Input and matching

- One text field, always focused during play (D21).
- `TextCapitalization.characters`, `autocorrect: false`,
  `enableSuggestions: false`. No change from the code on `master`.
- The code checks the input on every change, and also on Enter.
- The shortest word is 6 letters, so the code skips the check below 6
  characters. (The code on `master` uses 4.)
- A match needs the **full word**, without case and without outside spaces
  (D10/E3).
- The code checks the cards in grid order and stops at the first match. Only
  one card can match, because the same word is never on the screen two times.
- A card in the Failed or Matched state cannot match.
- A wrong word gives **no feedback and no penalty** (D10/E2, D27).
- After a match, the code clears the field and keeps the focus.

### S7. Score, lives and the end of a level

- A correct word gives **5 points**, and the code calls
  `GameManager().recordCorrectWord()`.
- The score display is capped at 100.
- 20 correct words complete the level: the game saves the best time, unlocks
  the next level, and shows the Level Complete overlay.
- A red card removes **1 life** (D6).
- 0 lives end the game and show the Game Over overlay.
- The 3 overlays do not change (D10/F4).

### S8. Pause, resume and the app lifecycle

Pause starts in 3 ways:

1. The player presses the Pause button.
2. The player uses the system Back gesture, or any other action that would
   close the keyboard (D21).
3. The app goes to the background (D22).

While paused:

- All card countdowns stop.
- The new-card interval stops.
- The game clock stops.
- The pause overlay covers the grid.
- A pause costs nothing: no life, no points, no clock time (D32).

Resume always runs the **"3, 2, 1, Go"** countdown (D30):

- "3", "2" and "1" each show for 800ms. "Go" shows for 600ms. Total: 3.0s.
- All timers stay stopped until "Go".
- The keyboard stays open during the countdown, and the game ignores the input.
- The same countdown runs at the start of a level.

### S9. Values per level

| Level | Name | Card time T | New card every D | Lives | Words |
|-------|------|-------------|------------------|-------|-------|
| 1 | Strolling | 30s | 5.0s | 3 | 20 |
| 2 | Jogging | 26s | 4.5s | 4 | 20 |
| 3 | Running | 22s | 4.0s | 5 | 20 |
| 4 | Bolting | 18s | 3.5s | 6 | 20 |
| 5 | Impossible | 15s | 3.0s | 7 | 20 |

Word length by position in the level does not change (D10/A4, D31): words 1–4
have 6 letters, 5–8 have 7, 9–12 have 8, 13–16 have 9, and 17–20 have 10.

Animation times:

| Event | Time |
|-------|------|
| Card entrance | 300ms |
| Green match flash | 500ms (250ms grow and tint, 250ms fade) |
| Red fail flash | 600ms, inside T (D13) |
| Score gold highlight | 300ms |
| Arrow blink cycle | 1000ms |
| Start and resume countdown | 3000ms |
| Screen change | 300ms fade |

### S10. Code changes

Removed from `game_screen.dart`:

- The `FallingWord` class and the fall `AnimationController`.
- `_spawnWord()` x-position and overlap code, `_maxFallY`, `_onWordHitGround()`.
- The SKY label, the GROUND label, the ground line and `_buildZoneLabel()`.
- `_buildFallingWordWidget()` and its `Positioned` layout.

New in `game_screen.dart`:

- A `TimedCard` class: `id`, `hint`, `clue`, `answer`, `gridIndex`, `state`,
  and one `AnimationController` with `duration = T`.
  The controller value 0.0→1.0 drives the bar, the number
  (`T × (1 − value)`), the amber point and the red point.
- A 6-position grid widget inside a scroll view.
- The 2 blinking arrows.
- The "+" button in the input row.
- The "3, 2, 1, Go" overlay.
- `WidgetsBindingObserver` for the background pause (D22).

Kept without change: the header, the 3 overlays, the input field, the score
highlight, the hearts, the clock, and the whole of `ProgressManager`.

`LevelConfig` (`lib/models/level_config.dart`):

- The 2 fields get new names: `fallTime` → `cardTime`, `spawnDelay` →
  `newCardDelay`. The values do not change (D11).
- `fallTimeDuration` → `cardTimeDuration`, `spawnDelayDuration` →
  `newCardDelayDuration`.
- `level_selection_screen.dart` uses `fallTime` in the card subtitle
  ("Xs per word"). Update it in the same step.

`GameManager`: no change to the public methods. `startLevel()`,
`getNextWord(activeWords:)`, `recordCorrectWord()` and `checkAnswer()` all
still fit. BUG-7 (unused duplicate logic) is still open.

### S11. Points to confirm during the build

These are small details. I propose an answer for each. Correct any of them
when you see the build.

1. A new card takes the free position with the lowest number (S4). The other
   option is a random free position.
2. The clue uses 3 lines and the card is 88px high (S2). Test T1 must show
   that this is readable on a real phone.
3. The input check starts at 6 characters (S6), not 4.
4. The seconds number shows `0` during the red flash (S3).
5. The arrow is white, and it changes colour with the state of the hidden
   card (S2).

---

## Plan

1. ~~Answer the open questions (Groups A → G).~~ **Done 2026-09-20 (D1–D34).**
2. ~~Write the new game rules and the screen layout in this document.~~
   **Done 2026-09-20 — see the Specification section above.**
3. ~~Change the models and the managers.~~ **Done 2026-09-20.**
   `LevelConfig` now uses `cardTime` and `newCardDelay` (with
   `cardTimeDuration` and `newCardDelayDuration`). The values did not change.
   `level_selection_screen.dart` and `game_screen.dart` use the new names.
   `GameManager` needed no change, as section S10 says. `flutter analyze`
   reports only the 2 known notes of BUG-10.
4. **Next:** build the new game screen in stages. Test on a mobile device after
   each stage.

   | Stage | Content | Specification |
   |-------|---------|---------------|
   | 4.1 | ~~Static layout: header, 6 empty grid positions in a scroll view, input row with the `[+]` and Pause buttons. No timers.~~ **Done 2026-09-20.** The falling-word engine was removed in this stage, not in 4.7, so the file holds no dead code between stages. **Test T1 is open: measure the grid on a real phone.** | S2, S4 |
   | 4.2 | ~~One card with a working countdown: number, bar, amber at 5.0s, red flash, life loss, removal.~~ **Done and tested on the phone 2026-09-21.** All 4 states confirmed on a Level 1 card (30s): blue and counting, amber at 5.0s, red card with `0` at 0.6s with 1 life lost, then removal at exactly 30s and the position became free. | S3 |
   | 4.3 | Automatic new cards, the waiting card, the limit of 6, and the `[+]` button. | S5 |
   | 4.4 | Input matching, green flash, score, and the end of a level. | S6, S7 |
   | 4.5 | Manual scrolling and the 2 blinking arrows. | S2 |
   | 4.6 | Pause from all 3 sources, and the "3, 2, 1, Go" countdown at start and at every resume. | S8 |
   | 4.7 | Check the 3 overlays and confirm the 5 points in S11. (The dead-code removal moved to stage 4.1.) | S10, S11 |
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
| BUG-11 | startup (web build) | An uncaught `AssertionError` appears in the browser console during start, **before** the word bank loads. It happens in `main()` or in the engine start, not in the game screen. The app then runs correctly. Found on 2026-09-20 with `flutter run -d web-server` in debug mode. The cause is not identified. The orientation lock in `main.dart` is the first suspect, because a browser on a desktop cannot lock the screen orientation. **Checked on Android on 2026-09-20: the phone log shows no assertion and no exception, so this is a web-only problem.** | No | Open (web only) |

### Features in the old design document that are not built

For reference only. Decide in the open questions if they stay in scope:
How to Play, Settings and About screens; audio; particles; haptics; the
"3, 2, 1, Go" countdown; spawn fade-in; heart shake on life loss; the level
info button; fall speed that changes with screen height (no longer applies).
