# Build 184 report: the triangle says what a tap will do; the glass, measured

Brief: `tasks/BUILD184.md`, which is `tasks/QUEUE-next-build.md` items 2 and 8, plus the test-area part
2. Prepared on a local branch after 183 and built on the review chat's go (13:44), after both 183 phone
reports.

- **The one behaviour change:** the triangle.
- **The investigation:** the glass, measured.
- **Test-kit only:** the test-area tidy-up.

## Files changed

| File | What changed |
|---|---|
| `lib/fit/shell.dart` | `TapOutcome` and `_tapOutcome()`, the one place that decides what a tap on Prism's button does. `_buttonUp`'s tap does `_doTap(_tapOutcome())`. The new triangle rule (`_signSync` → `_signApply`), the wait during a flick, and the triangle and glass parts of the button test. The test area: the asked-for test first, four tests removed, one line each. |
| `lib/fit/blob_sign.dart` | Petals no longer turns. |
| `lib/fit/long_test.dart` | The "THE GLASS, MEASURED" table. |
| `lib/fit/diag.dart` | Build 184, its date and title. `askedTest = 'button'`, now only 'leak', 'button', 'hour' or 'stability'. |
| `android/.../MainActivity.kt` | The test state adds `chargeUah` and `currentUa`, finer battery figures for the half-minute measurements. |
| `DESIGN.md` | §3: the triangle's spring (`Motions.effects`, 1600, ζ 1) and its rule. |
| `pubspec.yaml` | `0.145.0+212`. |
| `tasks/BUILD184.md`, `CHANGELOG.md` | The brief and the go; build 184. |
| `reviews/shots184/` | The test area at 1.0, 1.3 and 2×. The triangle at rest (up) and with the blobs out (down). |
| `releases/prism-build-184.apk` | The build. |

## Why the triangle seemed to spin past and back (the cause, from 182)

**From `reviews/investigate-sign-spin.md`:**
- **The angle never went past or back.** It went from 0 to π in one move, 0.27° past π, which can't be
  seen.
- **The shape repeats.** The Window triangle is equilateral, and its colour bands stand still behind
  it, so it looks exactly the same every 120°.
- **The point runs the other way, three times as fast.** Turned clockwise, the corner that seems to
  "point" moves three times as far, anticlockwise. Half a turn showed down → right → up → left → down →
  right → up: one and a half rounds of the point, passing "up", its end look, halfway.
  - That read as turning past and swinging back.
  - The frames the review chat took from the owner's video matched the spring frame by frame.
- **There was one real reversal:** with the blobs out, a flick's first movement closed the blobs and
  sent the triangle back towards 0, before the app list sent it forward to π.

**Now (the owner's rule):**
- **It points down exactly when the next tap leaves nothing open.**
- **Each change of what a tap would do turns it clockwise:**
  - a sixth (60°) when the way it points changes;
  - `sameMeaningTurn` (120°, one named constant) when it points the same way.
- **No turn is over 120°,** so it never shows its end look on the way.
- **The angle only grows.** It's never wrapped back (after a million changes it's still exact enough).

## Item 2: the triangle

**`_tapOutcome()`:**
- **It returns one of 10 outcomes:** `openBlobs`, `closeBlobs`, `openSettings`, `closeDrawer`,
  `closeDrawerToBlobs`, `closeDrawerToSettings`, `closeDrawerToBack`, `callGlassHome`, `closePanel`,
  `closePanelToBlobs`.
- **`closesAll`** is true for `closeBlobs`, `closeDrawer`, `closeDrawerToBack`, `callGlassHome` and
  `closePanel`.
- **The cases, as decided:**
  - the app list chosen for a blob: up;
  - chosen for the Sidekick: down;
  - the glass put down: down;
  - a workout sheet: ignored.
- **Where it's used:** `_buttonUp`'s tap acts on it; the sign reads it.
- **Prism's settings panel** still closes itself on a tap anywhere beside it, the button included. The
  outcome for that tap is `closePanel` or `closePanelToBlobs`, which is what the panel does.
- **Holds stay outside it.**

**Two details the tests forced:**
1. **The flick waits.** At a gesture's first movement, the sign is held (`_signHeld`). It's released
   when the finger lifts, and then shows the outcome. So a flick from the blobs never turns it towards
   "closed".
2. **One turn per action.** The sign now settles once, when what is being done has finished (a
   microtask), not at every state on the way.
   - Without it, closing the app list after choosing for a blob passed through "nothing open" before
     the blobs came back.
   - That was two turns at once: 180°. The "no turn over 120°" check caught it in the preview.

**Other details:**
- **The spring:** `Motions.effects` (1600, ζ 1), critically damped, within 2% in about 150 ms, never
  past (DESIGN §3, "snappy").
- **Petals** no longer turns; it does the small shoot-out like the other looks.
- **About ten older checks** that expected fixed angles now check the way it points ("with the blobs out
  it points down (a tap closes them)"). Their names change in the report.

**The tests (preview):**
1. **Real taps in seven states:** at rest, the blobs out, the app list up, the app list up from the
   blobs, Prism's settings from a hold, the blobs being changed, and Prism's settings over the blobs
   being changed. Each tap is checked against what was open after it. All right.
   - **Over the whole button test,** every tap on Prism's button is recorded with the way the triangle
     pointed before it and what was open after. All 30 agree.
2. **Every frame of the test:** never back by more than 0.5°, never past by more than 1°. 257 frames,
   all right.
3. **The largest single turn:** 120°.
4. **A real flick from the blobs** (`Robot.drag`) opens the app list. The triangle went 480° → 596° →
   600°: up 120°, because "blobs out" and "app list up" both point down.
5. **The largest turn in one frame:** a NOTE on the phone; SKIPPED in the preview.

## Item 8: the glass, measured

- **Where:** at the button test's quiet end, about 2½ minutes. No new button.
- **Under each glass level:** the home screen scrolls behind the bar at a steady pace (400 points every
  1.2 s, up and down) for 30 s.
- **Then the magnifying glass alone,** carried about the screen for about 20 s at full quality.

**Recorded for each:**
- frames a second and late frames;
- work per frame (building and drawing): usual, 1 in 20, and worst;
- the processor;
- graphics memory;
- the battery: the level's drop, and the charge used in mAh. Android now reports the charge counter;
  half a minute rarely moves the level.

**The table is "THE GLASS, MEASURED" in the report.**

**The levels are today's styles, as no other way of drawing the bar exists yet:**
- **Frosted ≈ "Event":** still glass, a tint over what is behind, nothing blurred. There's no
  blur-once bar yet: `Look.instance.frost` exists, but the bar doesn't use it.
- **Clear ≈ today's "Frosted":** a live blur at low quality, which skips the bending shader, so no edges.
  Its blur isn't at quarter resolution.
- **Liquid ≈ "Original":** a live blur, bending at the edges, the rim.

**One finding for 185:** the carried magnifying glass follows the glass quality setting today
(`settings.effectiveQuality`). So the owner's "always full quality" rule isn't in the code. The
measurement sets Full for it. Making the rule real is the one-line change planned for 185.

**In the preview the table fills,** but its numbers mean nothing: software drawing, about 10 frames a
second. The phone gives the real ones.

## Test area, part 2 (test-kit only, small)

- **The asked-for test comes first,** right under the badge, green with "TEST THIS ONE". The others
  follow: leak, button, hour-long, stability.
- **Removed:**
  - the short guided "Run the test", with its "Copy test report" and "Start over";
  - the 20-minute long test;
  - the glass settings test;
  - the chat-head battery test.
  
  Their code stays: the hooks, and the preview's `PRISM_GLASS_TEST`. Only the buttons are gone. The
  glass measurement doesn't use the glass test's steps.
- **The two long paragraphs** are replaced by one line inside each button:
  - "About 9 min · unplugged, hands off" (the leak test, which was labelled 11 min);
  - "About 17 min · unplugged, hands off" (the button test, now with the triangle and glass parts);
  - "About an hour · unplugged, silent";
  - "2½ hours · unplugged, silent".
- **"Copy the last report" and "Past reports"** are as before.
- **At 2× text,** the asked-for button has a little more room at the top, so its tag clears the label.
- **Checked at 1.0, 1.3 and 2×** (pictures in `reviews/shots184/`).

## The 183 phone findings (asked for in this report; no fixes in 184)

### 1. The stand-in is never asked for (both phones, every stage)

**What the phones say:** at 6, 12, 25, 50 and 100%, "the panel covers it; the stand-in asked for: no,
drawn: no". The pixel is the panel's colour, or `00000000` at 100%.

**What the code says,** checked against the 183 commit itself:
- **The S25's figures** (density 2.625):
  - the Sidekick's window at [787, 917], 220 × 220 px, so its middle is at (897, 1027) px, or 341.7
    points across;
  - its glass radius `sr` = 110 − 5 dp ≈ 97 px;
  - the open panel's box is 8 to 338 points across, that is 21 to 887 px.
  - The middle lies 10 px beyond the panel's edge, inside the glass, hence the 33-point overlap.
- **At 6%,** the shrinking panel's rectangle runs from about 753 to 988 px, and the middle (897) is
  inside it. `covers(rr)` is the distance from the middle to the rectangle (0) being under `sr` + 2 dp
  (about 102 px), so it's true.
- **At 100%,** the distance is 10 px, still under 102, so true.
- **`onDraw`** calls `standIn(canvas, covers(rr))` after drawing the panel, on every path that draws the
  panel. `standIn` sets `lastAsked = needed && !noStandIn` first, before anything that could fail.
  `noStandIn` is false during "with".
- **`testSample`** computes the same rectangle the same way, and `sampleCovers` came back true.

**So by the code, "asked for" must be yes at every one of these stages. The phones say no.**
- **I couldn't find, by reading, a path that gives no.** The `onDraw` behind the sample did draw the
  panel (its colour is in the pixel), and every way out of `onDraw` after that calls `standIn`.
- **The dark box when closing** fits the phones' answer: the Sidekick isn't drawn above its panel.

**What would settle it, for 185 (where the fix goes, with "under the glass"):**
- record inside `onDraw` itself, during the sample:
  - that it ran, and how many times;
  - the `rr`, `lensX()`/`lensY()`, `sr`, `covers(rr)` and `noStandIn` it saw;
  - each `standIn` call with its `needed`.
- The next phone run then shows which of these isn't what the code says. 185's rewrite (panel clipped
  outside the glass, faint inside, stand-in last) changes this drawing anyway. It should carry these
  records, so its first phone run proves the new drawing.

### 2. The S26's one missed tap ("ignoring yes")

**The Sidekick was tucked into its side when the test tapped it, so the tap only brought it out.**
- `ignoring` is set in exactly one place: a tap whose finger lifts while the Sidekick is tucked
  (`untuck()`). It stays set until the next touch, which is why the report saw "ignoring yes" and
  "tucked no" afterwards.
- **To confirm in that report:** the check's "its last touch" line should read "down at …, tucked …".
- **Why it was tucked at that moment** isn't known from the report. The test should bring it out first,
  for a known state (LESSONS), when this part is next touched.

### 3. The past-reports fixture

**"605 right, 12 wrong, 2026-11-16 12:33" is the check's own fixture,** matching the mock-up's sample on
purpose. It's written into a folder of the test's own:
- `Directory.systemTemp/prism_reports_test_<time>`, through its own `PastReports(tmp)`;
- read back by a new `PastReports(tmp)`;
- and the folder is deleted at the end, in `finally`.

The owner's list is `PastReports.instance` (`files/prism_reports`), which the check never touches. So
the fixture never reaches it.

## Results (preview, on the final code)

```
button test:  CHECKS: 80 right, 1 wrong, 1 skipped, of 82
  WRONG    Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
  SKIPPED  triangle: the largest turn in one frame  [the preview draws a frame only every 120 to 150 ms]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 184:**
- `Prism build 184`, `0.145.0+212`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `chargeUah`. Its `libapp.so` has "Prism build 184", "THE GLASS, MEASURED" and
  `closePanelToBlobs`.
- sha256 `487f70b43ffb4aa1c76879d86c2f994cd0e104078442fbdfce2319cc12c1807b`, 18,797,002 bytes.
- Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/9015d36ec307c1ae8f5aa74f5a2f91cb7277ccb2/lumen/releases/prism-build-184.apk

## Where I could be wrong

1. **The triangle's tests run in the preview, at its slow frames.** On the phone, frames come about 15
   times as often. The per-frame checks (never back, never past) are more demanding there. The spring is
   critically damped, so they should hold.
2. **"One turn per action" assumes an action finishes in one go.** Something that changes what's open
   across two separate moments (a panel's post-frame update, for instance) can still give two turns in
   a row, each at most 120°. The settings from a hold do this: blobs in, then the panel up. It shows as
   one turn in the preview, but on the phone could be two quick ones.
3. **The glass levels are today's styles under new names.** "Frosted" isn't a real blur-once bar yet, so
   its row is the cheapest still glass, not what Frosted will cost.
4. **The stand-in finding.** I couldn't find the cause, and I've said so. The records proposed for 185
   are what will.

## On the phone

**What's new to see:**
- **The triangle:** up at rest. Down with the blobs out, the app list, or Prism's settings. Always
  turning clockwise, briefly.
- **The test area:** the button test first, in green; four tests gone.

**In the button test's report:**
- the triangle's checks;
- "THE GLASS, MEASURED" near the end.
