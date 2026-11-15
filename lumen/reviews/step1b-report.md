# Step 1b report: what the first phone run of the button test found (build 171)

Asked for by the review of step 1 (build 170, accepted): items A to G. Branch
`claude/flutter-ui-showcase-ngzfru`, based on `511605b`. Two commits: `8a69e49` (the code, the APK, the
changelog, the handover, this report) and the one after it, which only adds the checked link here. Step 2 not started. No look or motion changed.

**What has only run in the preview:** everything. Nothing in this build has run on a phone. Every item
that is Android code (C, D's re-asking, E) has only been compiled. Its checks are in the button test's
Sidekick half, which the preview skips.

## Files changed

| File | What changed |
|---|---|
| `lib/fit/shell.dart` | A: a hold on a blob's place is not a hold on the empty space; the blob-menu part of the button test starts each step from a known state and skips what depends on a failed step. B, D, E: new and changed checks. F: memory at each part. G: the progress line's state. |
| `lib/fit/long_test.dart` | `skip()` and SKIPPED lines in the report (the CHECKS line counts them); the MEMORY BY PART table. |
| `lib/fit/main.dart` | B: the Stop button lets the test's touches through, as its own comment always said. G: the progress line and bar in the banner; Stop sits lower while that line shows. |
| `lib/widgets/controls.dart` | `Segmented` takes optional keys for its parts (test only; nothing else changes). |
| `lib/fit/diag.dart` | `progress` notifier; `Prism build 171`. |
| `android/.../MainActivity.kt` | C: a place asked for before the Sidekick's window is on the screen is kept, not dropped. D: `askPrism`, which re-asks Prism until it answers. E: the small menu decides on finger up; a cancelled drag (lens and sheet) never acts. Test driver: `finger(cancel)`, `press` with `cancel`, `menu popSlide`. |
| `pubspec.yaml` | `0.132.0+199`. |
| `tools/preview/test.sh`, `README.md` | Prints SKIPPED lines; the button test now expects 68 of 69. |
| `HANDOVER.md` | Step 1 done (build 170), step 1b here; the expected preview results. |
| `CHANGELOG.md` | Build 171 entry. |
| `releases/prism-build-171.apk` | The build. |

## A. The Prism blob-menu failures

**Cause: the app, set off by a hold during the blobs' flight. The test then missed it.** The 12 phone
misses in part 3 come from one event. Every one of them matches this chain, step by step:

1. "held as the blobs come out": the test taps the button and 60 ms later holds where blob 1 *will*
   be. On the phone, blob 1 was still flying there. The finger landed on the dim behind the blobs,
   whose long-press is the empty space's. When the hold time ran out, **Edit Prism | Add Blob**
   opened. The check only looked at `_menuFor` (null), so it passed. So did "put away", which also
   didn't look.
2. "a hold elsewhere": the hold on blob 1 landed on that menu's full-screen backdrop, an `onTap`-only
   `GestureDetector`, which put it away. No blob menu opened. The hold on blob 3 then reached blob 3
   (there was no backdrop any more): `menu 3`.
3. Change: the hold on blob 2 only put menu 3 away, so there was no Change. Then the tap meant to
   close the list closed the blobs instead, and "sign: back at the blobs" read 0.00 (blobs closed).
4. Remove and Add: holds on closed blobs did nothing (five left). The tap meant to close Add's list
   opened the blobs again.
5. "removing every blob": with the blobs out, four removes left `action:4 empty: ...`. The plus checks
   then failed on that one blob.

**The backdrop question:** a long press on a blob does *not* reach the blob under the small menu's
backdrop. The backdrop is opaque and sits above the blobs in the same `Stack`, so the hit test stops
there, on the phone as in the preview. On the phone, blob 3's hold reached blob 3 because no backdrop
was up at that moment (step 2).

**Why only on the phone:** in the preview the first frame drawn after the tap already has the blobs in
place (it comes about 130 ms later and they overshoot to 108%). So the finger lands on blob 1 itself.
I couldn't reproduce the in-flight moment here, so this explanation rests on the match above, not on
a reproduction.

**App or test?** DESIGN §4: nothing triggers by accident. A finger on a blob's place is holding that
blob, not the empty space. So the app was wrong. `_heldSpace` now does nothing when the finger is
within a blob's reach of a blob's resting place (`_onABlob`: the blob's radius plus 14 points; the plus
counts too). The test was also incomplete. Its two checks now include the empty space's menu, and the
in-flight hold waits until blob 1 has been drawn part of the way out, retrying up to five times, so it
tests that moment on any screen. Its note says how far out the blob was, so the phone's report shows
whether the moment was actually hit.

**Recovery:** each step of part 3 starts with `ready()`, which closes any list or menu, puts the
expected blobs back and opens the blobs. A step's first move (its small menu, the Add part, the list)
is checked once. If it fails, that is reported as wrong, and the step's other checks are reported as
SKIPPED with the reason. Tried on purpose: I forced the Change step's hold to land on the empty space
(a throwaway build, reverted). The result was 1 wrong, 3 skipped, and every step after it right:

```
CHECKS: 64 right, 2 wrong, 3 skipped, of 69
  WRONG  menu: holding a blob brings its small menu  (1 of 5 times)  [before Change: menu null]
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
  SKIPPED  change: the list comes up for that blob, and the button becomes it  [the small menu with Change did not come up]
  SKIPPED  change: closed without choosing, nothing changed and the button is the sign again  [the small menu with Change did not come up]
  SKIPPED  sign: back at the blobs, turned a sixth  [the small menu with Change did not come up]
```

New checks: "menu: with room, Add is there"; "space: a hold on a blob's place is not a hold on the
empty space" (it calls `_heldSpace` at blob 1's place directly, since the preview can't make the
in-flight moment); and the hold check repeated before each step (same name, so it shows as one line,
"all 5 times").

**Change, Remove, Add and the plus, by reading the code:**
- **Change:** `_menuChange` calls `_pickFor(i)`, which opens the list with `_editSlot = i`, the button
  wearing that blob. Choosing calls `_picked`, then `BlobSlots.put(i, key)`. Closing without choosing:
  `_setDrawer(false)` repacks (`_rearrange(_packed())`) and opens the blobs again.
- **Remove:** `_menuRemove` calls `_removeBlob(i)`, then `_rearrange(_packed(without: i), empty: i)`.
  The others close up at once, and the plus comes out if it was the last one.
- **Add:** `_menuAdd` moves a spare empty place to right after the held blob (`_rearrange(order)`), then
  `_pickFor(at)`. Closed without choosing, the repack puts the empty place last again.
- **The plus:** it has its own `onTap: () => _pickFor(i)` (key `plus$i`). Its blob hold returns at
  `_isEmpty(i)`, so it brings no menu.

All four are right. None of this code changed in 170 or 171.

## B. "Prism chosen again"

**Cause: the test's Stop button.** It sits at the top left, at `padding.top + 4 + 44`. On a phone the
status bar pushes it about 40 points lower, to y 88–128, exactly over the Prism half of the settings'
picker (the test tapped about 126,103). Its `Listener` ignores the robot's pointers, but its coloured
box is hit-tested, so the `Stack` stopped there and the tap never reached the picker. The comment
always said "the test's own touches pass it by"; they didn't. The preview has no status bar, so Stop
was above the picker, which is why 170 passed here. The picker and the 80-point offset were fine:
the Prism half is about 172 points wide.

**Fix:** the Stop button's box is under `IgnorePointer`, so the test's touches really go through; a real
finger still reaches the translucent `Listener`. Each half of the picker also has its own key
(`designPrism`, `designSidekick`) and the test taps exactly that. If it ever misses again, its note
says where it tapped and what it found. After the fix, with Stop moved lower for the progress line
(so it lies over the picker here too, as on the phone):
`ok settings: Prism chosen again, the Sidekick's switches go [tapped at 120,103; now Prism, panel open]`.

## C. The tuck at 8 points (Android)

**Cause: the first value a held slider sends was dropped.** Under a panel the Sidekick is hidden, and
hiding removes its window (`refresh` → `remove`). Holding the tuck slider (`_spotHold('tuck', true)`)
shows it again as a new window and asks for the tucked place. The test then sets 8 at once. Both
requests reach `Dot.showSpot` before the new window is attached, and `showSpot` returned without
doing anything when `!isAttachedToWindow`. At 40 the request came 1.1 s later, when the window was
attached, so it worked. The distance slider passed only because its part of the test waits 700 ms
after the hold. The values were never the problem: 8 is inside the `coerceIn(6f, 40f)` range.

**Fix:** a request that comes before the window is attached is kept (the latest only) and done by
`post`, which Android runs once the view is attached. The 8–40 range is unchanged. Only compiled.

## D. The round trip over another app

**Found, and fixed:** Change, Add and holding the Sidekick bring Prism forward, then send the request
220 ms later, once, with no answer expected. If Prism's screen was being made again (Android
re-creates it after taking memory back, which the handover says happens often), the request reached
a Flutter side that wasn't listening yet, and was lost: Prism came forward and nothing else happened.
That fits the owner's "takes me back to Prism", but I can't confirm it was the cause. `askPrism` now
sends with an answer expected and asks again every 250 ms, up to 12 times (about 3 s), until Prism
answers. It is used for `sidekickChoose` and `sideSettings`.

The step-back path itself reads right: `_pickBack` comes from `back` (`!foreground` on Android), and
`_setDrawer(false)` calls `toBack` (`moveTaskToBack`) both after choosing and after closing.

**New checks** (Sidekick half, over the stand-in app; skipped with a reason if there is none):
1. Change brings Prism forward with its list (Prism in front, list up for the Sidekick, set to step
   back).
2. Change chosen: Prism is no longer in front, Android keeps `action:0` in that place, and it is
   shown.
3. Change closed without choosing: Prism is back behind the app, nothing changed.
4. Add: the same three, with the new blob right after the held one.

Each trip starts with `leave` and ends with Prism having stepped back. A failed trip skips its second
check and brings Prism back.

## E. The Sidekick's small menu and cancelled touches

1. **Small menu:** on finger up, the part under the finger (worked out the same way as on finger
   down) must be the part it came down on. If so, it acts (the old 14-dp movement rule is gone); if
   not, nothing happens and the small menu stays. Down beside the menu and up beside it still puts it
   away. New check: "pressed on Remove and let go on Change, nothing is done and the small menu stays"
   (a new driver step, `popSlide`).
2. **Cancel:** `letGo(up = false)` now returns early. There is no put-back among Prism's blobs, no
   timer place, no tuck, no throw, and so no `leaving`. The cross falls and the lens glides back to
   `startX/startY`, or tucks into its side again if it was pulled out of one (`homeTucked`). This
   covers both `letGo` call sites, the lens and the second-finger `Reach`. The workout sheet: on
   CANCEL while pulling, it only `settle()`s, with no pull down or up. New check: "carried to the
   bottom and the touch cancelled, it is not dismissed and goes back where it began" (`press` with
   `cancel: true`; `finger()` sends ACTION_CANCEL instead of UP).

## F. Native memory

**Not found yet; nothing changed blind.**
- **New in 170, checked by reading:**
  - `sidekickPictures` doesn't decode again on each change. Prism caches each PNG (`_markPngs`,
    `_imagePngs`), so the same key sends the same bytes.
  - Android's `blobOf` decodes only when a key's bytes hash differently from its cached ones. That
    cache is per key, capped at 48 entries, and the button test uses about six keys.
- **Also not a cause:**
  - The app list re-reads the phone's app names each time it opens, but it reuses every tile and
    picture it already has.
  - The full-screen snapshot (`lastFrame`) is reused at the same size.
- **Measured in the preview** (new "process" column = `ProcessInfo.currentRss`; three rounds, parts 1–4;
  parts 5–6 need Android): flat, 434 → 450 → 454 → 461, 457 … 463, 472 … 458 MB. So Prism's Dart side
  and its app logic don't grow there. The preview draws in software, so this says nothing about the
  phone's GPU drawing or Android's side.
- **Left as candidates, phone only:**
  - **The Sidekick part.** Its window is removed and made anew every time a panel covers and uncovers
    it (several times a round), and each opening of its blobs makes a new full-screen menu window. But
    window buffers count as "graphics", which was flat.
  - **Flutter's GPU drawing on the phone.** Its CPU-side caches count as "native".
- **New in the report:** MEMORY BY PART, memory at the start of each part of each round (native,
  graphics, java, total, the process, Prism's pictures). The next phone run will show which part the
  growth happens in.

## G. Progress

**Under the banner** while the long test or the button test runs: "Round 2 of 3 · part 2 of 6 · about
4 min left" and a 180×3-point bar that fills. It is seen in a screenshot of the preview.
- **How it is worked out:** from the part number in each announcement, over the time the rounds have
  taken so far.
- **When it changes:** only when a part starts, so nothing ticks during the long test's still
  measurements.
- **Outside the rounds:** before them it says "Getting ready"; after them, "After the rounds", with
  the announcement's own "about N min" where there is one.
- **Prism only, test only:** the line is null outside a test. Stop moves 40 points lower while the line
  shows.

## Results (preview, on the final code; the APK is built from the same code)

```
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
long test, second run:  CHECKS: 65 right, 4 wrong, of 69
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open: measured  [no answer (MissingPluginException(...))]
  WRONG  blobs out: measured  [no answer (MissingPluginException(...))]
  WRONG  app list open: measured  [no answer (MissingPluginException(...))]
```

- **The button test's total** went from 63 to 69: four repeats of the hold check, plus the two new
  checks in part 3.
- **The long test's first run** also missed the three "hold, then carry" timing checks, which the
  handover says to run again before believing. The second run didn't.
- **Three rounds of the button test** (to read memory): 202 of 203.
- **Analyser:** the same 4 old notes. `dart format` is clean.
- **Kotlin:** `compileReleaseKotlin` gives no errors.

**Build 171:** `Prism build 171`, `0.132.0+199`. Built from the final code (the APK is newer than every
source change) with `ORG_GRADLE_PROJECT_fit=1 flutter build apk --release --target-platform android-arm64
-t lib/fit/main.dart`. NAME-OK. Its Android code has the new `askPrism` (its "did not answer" line is
found in `classes.dex`). sha256 `a196de270b22f1c8f339d19f7916967a26f3db17356109227f5b7f5203206f98`,
18,583,722 bytes. Link: https://github.com/vikac995/vikac/raw/8a69e49c75126c9df82496fc459892a2163ffb29/lumen/releases/prism-build-171.apk
(pinned to `8a69e49`, the commit that added the APK). Checked after the push: it answers 200,
18,583,722 bytes, and the downloaded file has the same sha256 as the one built.

## For the owner to try on the phone

1. Install build 171, run the button test (4 rounds), and send the report. Look for: no WRONG lines
   in parts 3 and 4; the new Sidekick checks; the MEMORY BY PART table; the progress line during the
   test.
2. Hold the Sidekick for its settings, hold the "Tucked in" slider and drag it all the way left: it
   should tuck with a thin sliver showing.
3. Over WhatsApp: hold a Sidekick blob, Change, choose something. You should be back in WhatsApp with
   the new blob in the Sidekick. Do it again and close the list without choosing: back in WhatsApp,
   nothing changed. Then the same with Add.
4. On a Sidekick blob's small menu, press Remove, slide onto Change and let go: nothing happens.
