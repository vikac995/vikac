# Step 1c report: the lost Sidekick messages, part 4's memory, two small things (build 172)

Asked for by the review of build 171's phone run. Branch `claude/flutter-ui-showcase-ngzfru`, based on
`fb13624`. Step 2 not started. No look or motion changed (Home's date apart: it is now today's).

**What has only run in the preview:** everything. Nothing in this build has run on a phone. The cause
below is a strong explanation, not a proven one. This build is made so that the next phone run
proves it or rules it out, and so that the Sidekick reaches the right Prism either way.

## Files changed

| File | What changed |
|---|---|
| `android/.../MainActivity.kt` | Engines numbered, kept in a list of those alive, with a timed history. Android's line to Prism follows the Prism that comes to the front, and leaves one that is let go. `toPrism()` and `askPrism()` write "sending X to Prism #n" and whether it answered. The test driver answers which engine it was asked in and where the line leads, plus the history at `begin`/`end`. The `memory` step can read native memory again after a garbage collection. |
| `android/.../SidekickMenu.kt` | Tells Prism its keys through `toPrism()`, so each send is written down. |
| `lib/fit/shell.dart` | Prism asks which engine it is, and writes "Prism #n got X" for every Sidekick message. Test: the line check at the start of the Sidekick part, with dependent checks skipped (`heard`, `inPanel`); memory after each step of part 4, with collection; the engine lines at the top of the report. `_spotHold` hides the Sidekick on let-go only if a panel is really open. Button test label: about 14 min. |
| `lib/fit/long_test.dart` | MEMORY BY PART has an "after gc" column. |
| `lib/fit/home_page.dart` | Today's date instead of "Friday 13 November". |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 172, `0.133.0+200`. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 172 entry; the two-Prisms note. |
| `releases/prism-build-172.apk` | The build. |

## The lost messages: what the 171 report shows

**The report contradicts itself, and that points to two Prisms.**
- "Remove over another app" passed, as did "a tap opens its blobs" and "as many blobs as its menu has"
  ([5 shown, 5 in its menu]). For the Sidekick's menu to show the test's blobs (`action:4 …
  screen:0`), Android needs their pictures. Prism sends those only when it is told the keys. So some
  Prism *did* get the `sidekickKeys` that `testPut` sent, and answered it: its reply travels along its
  own line, which works.
- Yet at the next check the test's own Prism still had the owner's list (`app:com.revolut.revolut
  app:com.android.vending …`) in `_sideKeys`. The test's Prism never got it.
- **So a second Prism hears what Android says, and answers it, while the test's Prism hears nothing.**
  - Prism→Android works (every test step).
  - "Prism in front true" is whichever copy of the screen is in front.
  - Change, Add and the settings go to the other Prism. That's why the list, the panel and `_pickBack`
    never show in the test's Prism. It also explains `blobs out true`: the test's tap meant to close
    a list it never had toggled its blobs.
  - The panel then never opened in the test's Prism. The test's own slider steps ended with
    `tellCovered(true)`, and the Sidekick stayed hidden: "there is no lens" for the rest of the round.

**Why two, in one process:**
- There is one `MaterialApp` with `home: const Shell()`. One Dart handler on `lumen/device`. One Kotlin
  place set the line (`configureFlutterEngine`: "the engine made last"). No other engine is made
  anywhere (no plugins).
- So the other Prism is a second `MainActivity` with its own `FlutterEngine`, alive at the same time.
- `MainActivity` is `singleTask` with `taskAffinity=""` and is Prism's HOME activity. Android keeps a
  home activity's task (activity type *home*) apart from a launch of the same activity by an ordinary
  intent (activity type *standard*): the app icon, recents, and Prism's own explicit intents
  (`openPrism()`, the test's `front`). A standard launch does not reuse the home task. It makes a
  second task with a second instance, so two engines.
- This is Android behaviour I know of, not something I could see here.
- **It fits:**
  - the owner's "takes me back to Prism" (a new Prism started cold, the request lost before 171's
    re-asking);
  - Change/Add having worked by hand at some point (owner's list became revolut + vending);
  - the test's Prism knowing that list (it started after the edits);
  - the test never stalling. Part 3 waits for drawn frames, so the test's Prism was on screen in
    every round's parts 1–3; the other copy is the one behind.

**Not proven.** The flight recorder export was asked for; the review chat is forwarding it. Lines
like "Prism's screen made again …" at the time of the owner's edits would confirm it.

## What build 172 does

1. **Android's line to Prism follows the Prism on screen.**
   - Each `MainActivity.onStart` points the line at its own engine ("it came to the front").
   - `cleanUpFlutterEngine` moves the line to another live engine (or to none) if it led to the one
     being let go.
   - With one Prism this changes nothing. With two, the Prism you can see is the one the Sidekick
     talks to. In the test that is the test's Prism, at least until a Sidekick step brings the other
     one forward.
2. **Proof, both ends, on the next run.**
   - Every engine is numbered. Its making, letting go and the line's moves are kept with their times
     in a list of their own (not limited like the flight recorder's 400 lines). The test report prints
     them at the top: "PRISM'S ENGINES: n made, m alive; the test ran in #x; the line led to #y".
   - Android writes "sending X to Prism #n" and "Prism #n answered X" (or "did not answer", or
     nothing: it went to a Prism that is gone) for `sidekickKeys`, `sidekickChoose` and `sideSettings`.
     Prism writes "Prism #n got X", and "this Prism is engine #n" when it starts.
   - The test's first Sidekick check is new: "Android's line to Prism leads to this Prism, the one
     running the test", with both numbers.
3. **One miss, not twenty.** If that line check fails, every check that needs Android to reach this
   Prism is reported SKIPPED with both engine numbers:
   - the keys check;
   - Change and Add (the list comes up, chosen, closed, Prism's blobs);
   - the four round trips;
   - "held, its settings come up" and "held in the middle of its blobs".

   If the Sidekick's settings don't come up, the checks that need the panel are SKIPPED ("its settings
   did not come up"): hidden under it, the slider clearing it, let go, under Prism's settings.
4. **A missed `sideSettings` can't leave the Sidekick hidden.**
   - In the app, only real panels hide it (`PanelWatch` counts them).
   - The one exception was `_spotHold(..., false)`, which said "hidden" on letting go of a slider
     whether or not a panel was open. Only the test does that without a panel, and that is what left
     it hidden.
   - It now hides only if a panel is really open (`!on && PanelWatch.instance.anyOpen`).

**Not done, proposed:** stopping the second copy from being made at all. Prism's explicit launches
would bring the existing screen's task forward (`moveTaskToFront` with its task id, which needs the
`REORDER_TASKS` permission) instead of starting it by intent. That changes how Prism comes forward
everywhere. I'd rather the next run first confirms there are two.

## Part 4's native memory

- **Part 4 is "the settings":**
  - hold the button for Prism's settings;
  - Labels Hide, then Show;
  - a two-finger swipe's place, which opens the app list, closed without choosing (the settings
    come back);
  - Sidekick chosen, then Prism;
  - the settings closed.
- **From 171's table:**
  - Native grows +51, +41, +34, +37 MB inside part 4, and about +18 MB between part 6 and the next
    round's part 1. It is never given back.
  - Graphics is flat (557–592) and Java is small. The "process" drops of about 200 MB are the trims
    while Prism is behind another app (part 5 leaves Prism).
- **What part 4 does that parts 1–3 don't:**
  - Prism's settings panel, which hides the Sidekick and so removes its windows, and makes them anew
    when the panel closes. Part 5 does that several times too without growth, so the windows are
    unlikely.
  - Labels changed, which re-sends the Sidekick's names, look and pictures: no decoding (same bytes).
  - The settings drawn by the phone's GPU (the six look previews, shadows). The preview draws in
    software, and over parts 1–4 Prism's whole process stays flat there (434–472 MB in 171's three
    rounds; again flat in 172's run: 448 → 453 → 462 → 456 → 460 → 462 across part 4's steps).
- **No cause found that I can show, so nothing fixed.**
- **Two new readings settle it on the next run:**
  - memory after each step of part 4 ("settings open", "labels hidden and shown", "a swipe's list, and
    back", "Sidekick, then Prism, chosen", "settings closed");
  - at every reading, native again after a forced Java garbage collection ("after gc").

  If it drops after collection, it is memory Java objects hold outside Java (pictures, shaders) not
  yet collected, not a leak. If not, the step that grows is the one to look at.
- **A second engine (above) would also cost about this much, once.** Not per round, so it can't
  explain the steady growth.

## Small

1. The menu label: "Run the button test (about 14 min, hands off)". The phone took 14 min 12 s.
2. Home's kicker is worked out from today's date when Home is drawn, same style: "Sunday 15 November".
   (No timer: it is right whenever Home is drawn.)

## Results (preview, on the final code)

```
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test, second run:  CHECKS: 65 right, 4 wrong, of 69
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
```

- **The long test's first run** also missed the three "hold, then carry" timing checks, which the
  handover says to run again before believing (the same happened with 171). The rerun didn't miss
  them.
- **The Sidekick part's new checks don't run in the preview**, so the preview's total is unchanged.
- **One button test run was lost** to the preview's virtual screen having died ("cannot open
  display"). It was restarted and the run repeated.
- **Analyser:** the same 4 old notes. **Kotlin** compiles.

**Build 172:** `Prism build 172`, `0.133.0+200`, built from the final code. NAME-OK. The new line-
following code is in its `classes.dex`. sha256
`b4d921f471382fb00397b1e93a94d6d565a28cf4741d4636e8a047e20499b3ff`. It is 18,583,722 bytes, the same as
171 by coincidence of padding; the checksum differs. Link: LINK_RESULT

## For the owner on the phone

1. Install 172 and run the button test. Send the report (its top now has "PRISM'S ENGINES") and,
   right after, the flight recorder ("Send what just happened").
2. Before running it, it helps to know how Prism was opened: from the home button, the app icon, or
   recents.
