# Step 2b fix report: the panel that closed by itself (build 179)

Brief: `tasks/STEP2b-fix.md`. Branch `claude/flutter-ui-showcase-ngzfru`, based on `58cc217`. Two commits: `b3c0414` (the code, the APK, the
changelog, the brief, this report) and the one after it, which only adds the checked link here. Fix only.

**What was seen** (two of the owner's screen recordings of 178): held, the panel opens fully, stays about
0.6–1.0 s after the finger lifts, then closes back into the Sidekick by itself. The keyboard of the app
underneath stayed up.

**What is known, and what isn't:**
- **Not known yet:** the owner's flight recorder from those attempts hasn't come. Every close in 178 wrote
  its reason, so the recorder would have named which one.
- **What I did:** as the brief says for that case, fixed all three possible causes defensively, and made
  every close say exactly why. The next phone run names the cause whichever it is.

**What has only run in the preview:** the Prism side's test check compiles and is skipped there (it needs
Android). Everything changed here is Android's: compiled, not run.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickPanel.kt` | The close-system-dialogs listener closes the panel only for `homekey`, `recentapps`, `lock` and `dream` (and the screen going off). Any other reason, or none, is written in the recorder and the panel stays open. The switch check runs only after a switch tap and says which. A tap beside it says where. |
| `android/.../MainActivity.kt` | `raise` writes "put above its own settings panel" and when. A touch on the Sidekick within 400 ms of that is not taken as a tap that closes the panel (it is written in the recorder). A tap that does close it says how long it was. |
| `lib/fit/shell.dart` | The button test's new check (below). |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 179, `0.140.0+207`. |
| `tasks/STEP2b-fix.md` | The brief. |
| `CHANGELOG.md` | Build 179. |
| `releases/prism-build-179.apk` | The build. |

## The three causes, and what each fix does

1. **The close-system-dialogs listener** (the likeliest, from the code).
   - **In 178:** it closed the panel on every `ACTION_CLOSE_SYSTEM_DIALOGS`, whatever its `reason`.
     Android and One UI send it for "assist", "globalactions", "voiceinteraction" and others, and some
     with no reason at all.
   - **Now:** only "homekey", "recentapps", "lock" (the phone locking) and "dream" (the screen saver)
     close it, plus the screen going off. Everything else is written as "Sidekick: its own settings stay
     open: Android said "close system dialogs" (reason)".
   - **What could go wrong:** if One UI's Home gesture sends no reason, Home would no longer close the
     panel. The panel would then stay open over Prism, which is the home screen, and the recorder would
     show "(no reason given)".
2. **The raise** (the Sidekick's window taken off and put back on top, once the finger lifts).
   - **Read again:** nothing that hides the Sidekick, nor anything "covered", "taken off the screen",
     "front" or "outside", runs when its window is put back. Its view has no detach handling, and its
     attach handling skips its entrance when raised.
   - **Hypothesis (a) of the brief:** the one way the raise could close the panel is a touch that the
     re-added window took as a tap on the Sidekick. Such a touch within 400 ms of the raise is no longer
     a tap: it is written in the recorder instead.
3. **The switch check.**
   - **In 178:** it was only ever scheduled from a switch tap, so it couldn't run on opening.
   - **Now:** it is explicit. It closes only if, 350 ms after the tap, the Sidekick has nowhere to be:
     both switches off, or it is gone from where it is. It also says which switch did it.

## The new check (button test, part 5, phone only)

"Still open 1.5 s after the hold is let go, never closed, the Sidekick above it, the panel unchanged".
After the test's hold, and 0.9 s more:
- the panel is open;
- it has opened exactly once;
- its last close reason is the same as before the hold, so it hasn't closed since;
- the Sidekick is above it;
- its contents were never drawn below full;
- the shade is at 40%.

**A caveat:** the test hands its touches straight to the views. A cause that comes from Android's own
touch dispatch can't happen in the test; only the owner's hand shows it. The broadcast (cause 1) is the
system's, and can happen in the test.

## Where I could be wrong

1. **It may be none of the three.**
   - The recorder will show either "stay open: Android said …" (cause 1, now harmless), or a close with a
     reason I haven't foreseen.
   - Please send the recorder after a hold on 179, whether it stays open or not.
2. **Home on One UI may send no reason.** If so, Home stops closing the panel (see cause 1). That's
   visible in the recorder, and easy to add once the reason is known.
3. **The 400 ms after the raise.** A real tap on the Sidekick that soon after letting go of the hold is
   now ignored. That is far quicker than a person taps again, but it is a guess at the window.

## Results (preview, on the final code)

```
button test:  CHECKS: 67 right, 1 wrong, of 68
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **First runs, while the APK was building beside them:** one extra flick-timing miss each ("a flick up
  opens the app list, and not the settings"; "a slower flick up is still the app list"). Both were clean
  when run alone right after, as HANDOVER.md says to check. This build changes nothing in Prism but one
  Android-only test check.
- **Analyser:** the same 4 old notes. Kotlin compiles.

**Build 179:** `Prism build 179`, `0.140.0+207`, built from the final code. NAME-OK. The new recorder lines are in
its `classes.dex`, and the new check in its `libapp.so`. sha256
`9872353b32d9932cbd016d8ebe64bc95f41fd8d874b4423421773ab75eb2016f`, 18,665,722 bytes. Link:
https://github.com/vikac995/vikac/raw/b3c0414231ece8596f817d7f61acac47c4496daf/lumen/releases/prism-build-179.apk
(pinned to `b3c0414`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. Install 179.
2. Hold the Sidekick, let go, and wait. The panel should stay open. Then close it with the ✕.
3. Send the flight recorder right after.
4. Then the button test.

## Build 180: the same fix, made exactly as the brief says

- **Why:** the review's message of 00:13 (sent while 179 was being built) asks for close on "homekey"
  or "recentapps" only, and for the panel's age in every close line. 179 also closed on "lock" and
  "dream", and gave no age.
- **What changed in 180** (`SidekickPanel.kt` only):
  - Only "homekey" and "recentapps" close it, plus the screen going off. "lock" and "dream" are now
    written in the recorder and leave it open; locking turns the screen off, which closes it anyway.
  - Every close writes "Sidekick: its own settings closing, N ms after they opened: why" when it begins.
  - It writes "… gone, N ms after they opened (why)" when its window is removed.
- **Checked:** Kotlin compiles; the preview button test gives 67 of 68 (the Android-only miss). The long
  test isn't re-run: Prism's code is unchanged from 179 but for its build number.
- **Build 180:** `Prism build 180`, `0.141.0+208`. NAME-OK; "ms after they opened" is in its
  `classes.dex`. sha256 `238255a523073a8f3f37866052aca4cbfead1abce410d76d13ad2623b44db2c6`, 18,665,722
  bytes. Link: https://github.com/vikac995/vikac/raw/7cf04560fe58bf7a269d31b11db219af33336119/lumen/releases/prism-build-180.apk
(pinned to `7cf0456`). Checked after the push: it answers 200, and the downloaded file has the same
sha256 as the one built.

**For the owner:** install 180 rather than 179. Then as above: hold, let go, wait, close with the ✕, send
the recorder, then the button test.
