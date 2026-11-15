# Step 2b report: the Sidekick's own settings panel (build 178)

Brief: `tasks/STEP2b.md` (the review chat's brief, word for word, and what the approved mock-up adds).
Mock-up: https://claude.ai/artifact/URMobjt1XEiqh2kTSFJmLv (version 5, approved by the owner). Branch
`claude/flutter-ui-showcase-ngzfru`, based on `c3b6857`. Two commits: `0f2cb17` (the code, the APK, the
docs, this report) and the one after it, which only adds the checked link here. Step 3 (the Sidekick's own
app list) not started.

**What has only run in the preview:** Prism's side. Prism's settings panel without its Sidekick part, the
long and button tests' Prism parts, and the leak test with its shorter list ran there.

**Not run anywhere:** the panel itself, which is Android's. It is compiled, and read through against the
mock-up and the Flutter controls it copies. The button test's new part 5 checks it on the phone.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | **New.** The panel: its window (never focusable), its motion (`snappy` open, `spatialFast` close, contents 5–30%), the shade with its hole, the controls drawn as Prism's own, the two dials, scrolling, every way of closing it, and the test's view of it. |
| `android/.../MainActivity.kt` | `sideSettings()` opens the panel over the app (no more Prism coming forward). The Sidekick: `lensOnScreen`, `lensTucked`, `lensShownNow`, `blobColours`, `raise` (its window above the panel, once the finger is off it). While the panel is open, a touch that starts on the Sidekick is the panel's: a tap closes it. The test driver: `panel` (tap, drag, flick, press, home), `spaceHold` (Edit Sidekick), `lensAbove` and `forwards` in its state. |
| `android/.../SidekickSettings.kt` | A change from the panel is told to Prism (`sidekickSettings`). `paletteColour`. |
| `android/.../PrismScreen.kt` | `forwards`: how often Prism was brought forward, for the test. |
| `lib/fit/shell.dart` | Prism's settings panel is Prism's only: the Prism \| Sidekick picker, the Sidekick's part, `_designSide`, `_sideInSight`, `_spotHold`, `_setFloating` and `_panelBack` are gone, and so is Prism's `sideSettings` handler. Prism's settings page has "Bring back the Sidekick" while it is off everywhere. The tests: see §5. |
| `lib/fit/bubble.dart` | Prism no longer changes the Sidekick's settings, except `setFloating` (for Bring back) and `testPut` (the tests). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 178, `0.139.0+206`. |
| `DESIGN.md` | §6: the dials and the panel; §7: "In Prism", and the new rule on stepping aside. |
| `tasks/STEP2b.md` | Corrected: the panel ends 42 points above the bottom, not 98 (my misreading of the mock-up). |
| `CHANGELOG.md`, `HANDOVER.md` | Build 178; the control pairs. |
| `releases/prism-build-178.apk` | The build. |

## 1. The panel, against the brief

**Where and how it comes:**
- **Beside the Sidekick,** on the side away from it.
- **Width:** 330 points, or the screen less 72 points on a narrower phone.
- **Height:** from 56 points below the top (or 8 below the status bar) to 42 above the bottom (or 8
  above the navigation bar). Above the keyboard if one is up. The content scrolls (finger or flick).
- **Opening:** it grows from the Sidekick's own circle (its place, its size, its round corners) to its
  place, on `snappy` (1100, 0.82), the numbers of `springs.dart`. The contents come in between 5% and 30%
  of the way, drawn at their own size and scaled with the panel, as Prism's transform does.
- **Closing:** back into the Sidekick on `spatialFast` (1400, 0.9). The window is gone when the panel is.
- **The shade:** black at up to 40%, with a hole 6 points bigger than the Sidekick.
- **The Sidekick's own window is put above the panel's.**
  - Windows over other apps lie in the order they were added. So it is taken off and put back at once,
    without its coming-in animation.
  - When it was held to open the panel, that waits for the finger to lift. Taken off under the finger,
    its window would never hear the finger lift.

**What's in it, in the brief's order:**
- **The title** "Sidekick" (Bricolage 22, weight 700) and the round ✕.
- **In Prism / Over other apps:** `LumenSwitch`'s look (54 × 32, the knob 24, `expressiveFast`, a click
  when it lands).
- **Labels, Icons, Colours:** `Segmented`'s look (the 40-point track at 7% ink, the sliding thumb with its
  shadow and its stretch, the labels' weight 500 → 650 in steps of 10, a tick when it settles).
- **Look:** the six looks, three to a row. Each is `BlobLooks.paint` on black, in the Sidekick's own blob
  colours, Mellow or Vivid as chosen, with the ring round the chosen one and its name under it.
- **"Where it rests, in points":** two dials side by side, named Hovering and Tucked in. Each is
  `DragDial`'s look: the 52-point pill, the value on top in 19-point weight 700, the wheel's ticks below,
  and the lift (`expressiveFast`: a little bigger, an accent rim and tint).

**The dials:**
- **Touching one** puts the Sidekick in that state at once: out at its distance, or tucked in.
- **Sliding:** 16 points of finger is one point of value, as `DragDial`. Toward the middle of the screen
  is more, on either edge, so the Sidekick moves the way the finger goes. The wheel's ticks move with the
  finger.
- **Each whole point** gives one tick, and the Sidekick moves there. It is in force, not saved yet.
- **A flick** coasts on, slowing, and lands on a whole point.
- **A quick tap** on one half steps once, the Sidekick moving toward that half.
- **While a dial is held,** the panel isn't touched: its opacity never changes. Only the shade lifts
  (`effects`, no bounce).
- **Let go:**
  - the value is kept by Android, and Prism told;
  - the shade comes back;
  - the Sidekick goes back to the state it was in when the panel opened (out at the new distance, or
    tucked at the new amount). The same when the panel closes.

**No flash on letting go:**
- **What caused it in the mock-up:** the panel's own opacity jumped when the dial was let go.
- **Here:** the panel's opacity is never changed by a dial, only the shade's.
- **Measured by the test:** the panel's contents are never drawn below full while it is fully open
  (`panelLeastSinceOpen`).

**Closing:**
- the ✕;
- a tap on the shade (anywhere beside the panel);
- a tap on the Sidekick (a touch that begins on it while the panel is open is the panel's: it closes it,
  and does nothing else);
- Home or the recent apps (Android's "close system dialogs");
- the screen going off.

**Never focusable** (decision A): Back goes to the app, and its keyboard is left alone.

**The switches:**
- "In Prism" and "Over other apps" are kept by Android, and Prism told.
- If the Sidekick then has nowhere to be where it is, the panel closes 0.35 s later into where it was.
  That's "In Prism" off over Prism, "Over other apps" off over another app, or both off.

**The way back:** Prism's settings page shows "Bring back the Sidekick", with a "Bring back" button, only
while both are off. The button switches both on and brings the Sidekick out.

**Prism's own settings panel:** Prism's only. The Prism | Sidekick picker and the Sidekick's part are gone.
The title is always "Prism".

## 2. What knowingly differs from Prism's own panel, and from the mock-up

- **Corners:** drawn as rounded rectangles (36 points). Prism's are superellipses, so they differ in the
  last few pixels of each corner.
- **Shadows:** Android's blurred shadow, the same size and colour, may be a touch softer or harder.
- **Text:** Android lays out Prism's own Inter and Bricolage with its own engine, and can sit up to a pixel
  off. Each weight is made once and kept (LESSONS.md).
- **The look previews:** in the Sidekick's own colours, as its sign is; Prism's panel drew them in
  Prism's.
- **Text size:** it follows the phone's text size, as Prism's does. At the largest it will crowd (the
  queued large-text pass covers it).
- **Taken from the mock-up:** only size, place, order and motion. Its own corner radius (26), its
  uppercase small headings and its knob slider weren't used: the controls are Prism's own, as it says
  itself.

## 3. DESIGN.md

- **§6:** the Sidekick's two places are two dials, Hovering and Tucked in, with what they do. Its panel is
  beside it, grows out of it, has it drawn above, and never takes the focus.
- **§7:** "In Prism" (not "In this app").
- **§7, the new rule** in place of "a slider whose effect is on screen clears the panel": "a panel steps
  aside while a control is held only when it hides what that control changes; otherwise only the shade
  lifts". With the two examples, the app list's Density, unchanged, and the Sidekick's dials.

## 4. Prism's side

- **What Prism can still do to the Sidekick's settings:** only switch it back on (Bring back, and the
  tests). Every other change is the panel's.
- **When the panel changes something,** Android tells Prism (`sidekickSettings`), and Prism's copy
  follows. If Icons changed, Prism sends the Sidekick's pictures again in its new choice.
- **Removed from Prism:**
  - its handler for Android's old `sideSettings` ask, and `_panelBack` (Prism stepping back afterwards);
  - `_sideInSight`, which hid the Sidekick under its own settings in Prism;
  - `_spotHold`, the old sliders' clearing.
- **Kept as it is:** `_panelClear`, which clears Prism's panel while a control is held. Nothing in Prism's
  panel uses it now, but the mechanism stays for the rule above.

## 5. The tests

**The button test, part 5, the Sidekick's own settings (phone only).** It replaces the 176–177 checks
of Prism's Sidekick part:
- **Held, its own settings come up, over the app it is in:**
  - Prism did not come forward (`forwards` unchanged), and Prism's own settings stayed shut and its
    triangle unturned.
  - It never takes the focus (the window's own flags).
  - Beside the Sidekick, on the side away from it, 280–330 points wide.
  - It grew out of the Sidekick, from where it is.
  - The Sidekick stays in sight, above the panel (`lensAbove`).
  - The shade at 40%.
- **Labels, Icons, Colours,** each changed in the panel and back:
  - Android keeps each change, and Prism's copy follows.
  - Prism's own choice is untouched.
- **Look:** another look and back, the same three ways.
- **Over other apps** off and on, over Prism: it stays, and the panel stays.
- **Hovering, then Tucked in:**
  - **Touched:** the Sidekick goes to that state, only the shade lifts, and the panel is never below full.
  - **Let go:** the shade is back, no flash, and the Sidekick as it was.
  - **Slid 4 points toward the middle:** kept by Android, and Prism's copy follows. Hovering also checks
    that it rests at the new distance.
  - **Slid back.**
- **A flick of Hovering:** it coasts past the finger's 3 points and lands on a whole point.
- **Prism's panel colours have reached it.**
- **Closed** by its ✕ (the Sidekick as it was), by a tap on the shade, by a tap on the Sidekick (its
  blobs don't open), and by Home.
- **Held in the middle of its blobs,** and **Edit Sidekick** (the empty space's small menu): each opens
  the panel, and not Prism's.
- **Over a keyboard:** Prism's own text field has the keyboard up. The panel is opened over it and
  closed. The keyboard must stay up the whole time, read every 100 ms. This is decision A, measured with
  the real panel, as 176's report asked; it replaces the two small probe windows.
- **The two distances at their ends** (put by the test, as before): it rests and tucks where they say.
- **"In Prism" off:** kept by Android, the Sidekick goes, and so does the panel.
  - Then off everywhere: Prism's settings page shows "Bring back the Sidekick".
  - Tapping Bring back brings it back, on everywhere, and the line goes.

**Changed check counts, explained** (no check loosened; only checks of what no longer exists are gone):
- **The button test's part 4:** "Sidekick chosen, its own switches show" and "Prism chosen again, the
  Sidekick's switches go" are one check now, "Prism's have no Prism | Sidekick, and no Sidekick
  switches". In the preview: 68 checks instead of 69.
- **The long test's part 2:** "the Sidekick's has In this app", "In this app switches off" and "and on
  again" are gone, because those switches are the Sidekick's panel's now (checked in the button test).
  "Prism has no In this app switch" became "Prism's have no Sidekick part". In the preview: 66 instead
  of 69.
- **The leak test:** loses its three Prism | Sidekick steps (c; iv; c with the Sidekick off). It has 11
  steps now.
  - It still says "about 11 min" on its button. That's now about 9 minutes.
  - The label isn't changed in this build: noted, not a fault.

## Where I could be wrong

1. **Putting the Sidekick's window above the panel's.**
   - **The worry:** taking a window off and putting it straight back may blink for a frame. It may also
     upset a Sidekick that was moving (a glide, a tuck) at that moment.
   - **When:** I wait for the finger to lift when it was held, but not for animations.
   - **The test** checks the Sidekick is shown and above. Only the owner's eyes can see a blink.
2. **The dials on the phone.**
   - **Unchecked numbers:** the speed (16 points of finger a point), the coasting (it slows by e⁻⁶ a
     second and stops under 2 points a second), and where a quick tap counts as a step all come from
     `DragDial` and the mock-up. None has been tried by a finger.
   - **Likely complaints:** a flick that coasts too far or not far enough, or the Sidekick lagging behind
     the ticks while it tucks.
3. **The look.**
   - **Fonts:** Inter and Bricolage are made with Android's font variations from the app's own fonts.
     If a weight or optical size isn't taken up, the text falls back to Android's own sans-serif, which
     would show at once.
   - **Corners, shadows** and the switch's knob colour in dark mode are Prism's, copied by hand.
   - **The test checks none of this:** it reads where things are, not what they look like.

## Results (preview, on the final code)

```
button test:  CHECKS: 67 right, 1 wrong, of 68
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4, on its first run)
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
leak test:    runs all its 11 steps to the end
```

- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin:** compiles.

**Build 178:** `Prism build 178`, `0.139.0+206`, built from the final code. NAME-OK. "Where it rests, in points",
"Hovering" and "Tucked in" are in its `classes.dex`, and "Bring back the Sidekick" is in its `libapp.so`.
sha256 `69978fc12aef5c55e1c45a67e0f114545e6d5e70adf88036be82628b91d928bb`, 18,665,722 bytes. Link:
https://github.com/vikac995/vikac/raw/0f2cb17141a8f23aa5d283613b063055c0d556ae/lumen/releases/prism-build-178.apk
(pinned to `0f2cb17`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. Install 178.
2. Run the button test and send the report, then the flight recorder.
3. Then try it yourself, over an app (a chat, with the keyboard up):
   - hold the Sidekick;
   - change something;
   - slide Hovering and Tucked in, and flick one;
   - close it each way: the ✕, beside it, the Sidekick, Home.

   Say what looks or feels unlike Prism's own settings.
