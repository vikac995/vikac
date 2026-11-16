# Build 192 report: drag it with its blobs out

Brief: `tasks/BUILD192.md` (the review chat, 20:18; the owner tried 191 by hand, "we're good"). The app list
moves to 193.

- **The one behaviour change:** the Sidekick can be dragged while its blobs are out.
- **Test kit:** the "dragged by hand with the panel open" check from the 190 S26 run, prepared after it.
  It's small: one check, 13 lines changed, 3 removed.

**Only the preview has run it.** The Sidekick, its menu and the drag are Android's.

## Files changed

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | **The Sidekick's menu:** a drag that begins on the Sidekick, once past the slop, folds the blobs away and is handed to the Sidekick (`handOn`); the menu's window waits for the finger to lift before it goes. **The Sidekick:** `pickUpAt` (picked up where the finger came down). **After the drag:** `reopenWhenStill`. Records: `menuDrags`, `menuFoldMs`, `menuReopens`. A test step `menu`/`dragLens`. |
| `lib/fit/shell.dart` | Part 4: the drag, the tap and the cross with the blobs out. Part 5: the "dragged by hand" check drags toward the middle. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 192, "Drag it with its blobs out", `askedTest = 'button'`; `0.153.0+220`. |
| `DESIGN.md` | §6: dragging the Sidekick with its blobs out. |
| `tasks/BUILD192.md`, `CHANGELOG.md` | The brief; build 192. |
| `releases/prism-build-192.apk` | The build. |

## Dragging the Sidekick with its blobs out

**Why it couldn't be dragged before:** with its blobs out, the Sidekick's menu covers the whole screen,
so every touch goes to the menu. A finger on the Sidekick in the middle of its blobs could only tap
(close them) or hold (its settings). A movement did nothing.

**Now:**
1. **Where it starts:** a touch that comes down on the Sidekick itself, its glass and 6 points round it
   (as the panel's `touchLens`).
2. **Picked up:** once it has moved more than 10 points (the panel's slop), the menu:
   - folds its blobs away with the usual close;
   - hands the touch to the Sidekick, which is picked up where the finger came down (`pickUpAt`: the
     same work as a touch on it, as when its panel is open, 185);
   - passes on every later movement of that finger. So the Sidekick follows the finger 1:1, exactly as
     a normal drag: the top cross shows faintly, it pulls near it, pushing into a side tucks it.
3. **The menu's window stays until the finger lifts,** though its blobs are in. Taken away mid-touch,
   Android would end the drag.
4. **Let go:** it settles as always: to its side, tucked, or sent away on the cross.
5. **Its blobs come out again** once it has been still (watched every 0.05 s, for up to 3 s), round it
   where it is, with the 191 fan and names. They don't come out again if:
   - **it was sent away on the cross:** it's gone;
   - **it ended tucked:** a tucked Sidekick has no fan, and opening one would bring it back out. I agree
     with not reopening here.
6. **A tap and a hold are unchanged:** a tap on it with its blobs out closes them, and nothing comes out
   again. A hold still brings its settings. Neither moves 10 points.
7. **The triangle:** the reopened blobs are the Sidekick's menu opening, so Prism is told as with any
   other (188), and its own blobs close if they're out.

## The tests

**Part 4, new** (with the test's own Sidekick menu out):
1. **"dragged with its blobs out, they fold away within 0.25 s and it is carried 1:1":**
   - a 120-point drag begun on the Sidekick, toward the middle of the screen;
   - its blobs must be all in within 250 ms of it being picked up (`menuFoldMs`, timed on Android's side);
   - it must have moved what was meant, within 24 points (allowing for the 48 points it always keeps
     from the top and bottom).
2. **"once it is still its blobs come out again round it":** its blobs out, opened again exactly once.
3. **"after the drag, its blobs out again clear of each other":** the 191 gap check on the reopened menu.
4. **"a tap on it with its blobs out closes them, and they stay in":** 1.5 s later.
5. **"carried onto the cross with its blobs out, it is sent away and its blobs stay in":** then it's
   brought back, and its blobs opened again for what follows.

**Part 5, the "dragged by hand with the panel open" check** (the 190 S26's 1 of 4, −60 of −120):
- **By reading:** the drag follows the finger 1:1, and the strip isn't involved (the test's drag goes
  into the panel). Let go, the Sidekick rests no nearer than 48 points to the top or the bottom. Dragged
  up from high on the screen, it can only come part of the way.
- **Now:** the check drags toward the middle of the screen, expects what the 48 points allow, and prints
  where it started.

**Test area:** badge 192, "Drag it with its blobs out", `askedTest = 'button'`.

## Results (preview, on the final code; the preview built fresh first)

```
button test:  CHECKS: 81 right, 1 wrong, 1 skipped, of 83 (the usual Android-only miss and phone-only skip)
long test:    CHECKS: 64 right, 3 wrong, of 67 (the usual 3, all "measured: no answer", Android-only)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 192:**
- `Prism build 192`, `0.153.0+220`, built from the final code. Name `Prism`, package `dev.lumen.prism`.
- Its `classes.dex` has `menuFoldMs`, `menuReopens` and the drag's trail lines. Its `libapp.so` has "Prism
  build 192", "Drag it with its blobs out" and the new checks.
- sha256 `4ef3f7e6e4385badc659696441ae58c54db4cc64bb6f4b0ab6a07079f210f51a`, 18,878,922 bytes.
- Link: in the next commit.

## Where I could be wrong

1. **None of it has run on a phone.**
2. **The 10-point slop:** a finger that wobbles more than 10 points while meaning to tap the Sidekick will
   pick it up instead of closing the blobs. It's the same slop as with the panel open (185).
3. **The blobs come out again after up to about 0.6 s of settling** (the glide to the side), not at once
   on let-go. That's the "once it has come to rest" the brief asks for.
4. **A drag that ends tucked leaves the blobs in.** That's my agreement with the brief. If the owner
   expects them back, the Sidekick would have to come out of the side first.

## On the phone

**What to look at:**
- With the Sidekick's blobs out, put a finger on the Sidekick and move it: the blobs fold away at once,
  the Sidekick comes with the finger.
- Let go: it settles at its side, then its blobs fan out again around its new place.
- Drop it on the top cross: it's gone, no blobs.
- Tap it with its blobs out: they close, and stay closed.
