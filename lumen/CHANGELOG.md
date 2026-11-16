# Lumen changelog

## Prism, build 180 (16 November 2026)

**File:** `releases/prism-build-180.apk`

Needs Play Protect paused to install. Can be installed over build 179. **Install this one rather than 179.**

**Build 179 made exactly as the review asked:** the review's brief, sent while 179 was being built, differs from it in two small ways. Nothing else changes.

- **Only Home and the recent apps** (and the screen going off) close the Sidekick's panel now. 179 also closed it when the phone locked or the screen saver came on; locking turns the screen off, which closes it anyway.
- **Every close says how long the panel had been open,** in milliseconds, in the flight recorder: "its own settings closing, N ms after they opened: why".

**Checked:** it compiles, both sides; in my preview: the button test, 67 of 68 (the Android-only miss). Not re-run: the long test, since Prism's own code is unchanged from 179 but for its build number.
**Not checked:** on a phone.

## Prism, build 179 (16 November 2026)

**File:** `releases/prism-build-179.apk`

Needs Play Protect paused to install. Can be installed over build 178.

**The Sidekick's panel closed by itself** about a second after you let go of the hold that opened it (your two recordings, over Prism and over the Claude app). This build is that fix, and nothing else.

- **What could close it by itself:** the panel closes when Android announces "close system dialogs". In 178 it believed every such announcement meant Home or the recent apps. Android, and Samsung's One UI, send it for many other reasons too, some when windows change. Now only Home, the recent apps, the phone locking and the screen saver close it. Every other announcement is written in the flight recorder, with its reason, and the panel stays open.
- **Two more guards,** in case the cause is one of them instead:
  - A touch arriving on the Sidekick in the instant it is put back on top of the panel no longer counts as a tap that closes it.
  - The check that closes the panel when a switch leaves the Sidekick nowhere to be now runs only after a switch is tapped.
- **Every close now says exactly why** in the flight recorder: which announcement and its reason, where a tap beside it was, how long a tap on the Sidekick was.
- **The button test now checks** that the panel opened by holding the Sidekick is still open 1.5 seconds after the finger lifts, never closed meanwhile, with the Sidekick on top and the panel unchanged.

**Checked:** it compiles, both sides; in my preview: the button test, 67 of 68 (the miss is the Android-only measurement); the long test, 62 of 66 with the usual 4 misses (each first run beside the APK build missed one flick-timing check more; both clean when run alone).
**Not checked:** on a phone. Which of the three it was, only your flight recorder can say: after a hold, look for "Sidekick: its own settings stay open: Android said ..." or the line that closed it.

## Prism, build 178 (15 November 2026)

**File:** `releases/prism-build-178.apk`

Needs Play Protect paused to install. Can be installed over build 177.

**Your phone run of 177: 537 right, 0 wrong.** This build is the Sidekick's own settings, as in the mock-up you approved.

- **The Sidekick has its own settings panel now,** over whatever app you're in. Prism doesn't come forward, and its triangle doesn't turn.
  - **To open it:** hold the Sidekick; or hold it in the middle of its open blobs; or choose Edit Sidekick (hold the empty space round its blobs).
  - **Where it sits:** beside the Sidekick, on the side away from it, nearly full height. It grows out of the Sidekick and goes back into it, on the same springs as Prism's settings. The app behind is shaded, except where the Sidekick is, and the Sidekick stays on top.
  - **What's in it:** In Prism and Over other apps; Labels, Icons, Colours; the six looks, three to a row; and "Where it rests": two dials side by side, **Hovering** and **Tucked in**.
  - **The dials:**
    - Touch one and the Sidekick goes to that position at once.
    - Slide and it moves the way your finger moves, on either side of the screen. One small tick for each point. A flick coasts on and stops on a whole point.
    - While you slide, the panel stays exactly as it is and only the shade lifts, so you see the Sidekick over your app.
    - Let go: the shade comes back, without a flicker, and the Sidekick goes back to how it was (out, or tucked in) at the new distance.
  - **To close it:** the ✕, a tap beside it, a tap on the Sidekick, Home, or the screen going off.
  - **Back:** it never takes the focus, so Back goes to the app you're in, and that app's keyboard is never closed by it.
- **Prism's own settings are Prism's alone:** the Prism | Sidekick choice is gone, and so is the Sidekick's part.
- **If you switch the Sidekick off everywhere,** there's nothing left to hold. Prism's settings page then shows "Bring back the Sidekick", and only then.
- **What might look a little different from the mock-up:** the panel is drawn by Android, copying Prism's own pickers, switches, colours and type. Corners, shadows and text can differ by a pixel or so from Prism's own panel. The look previews are in the Sidekick's own colours. The first switch is now called "In Prism".

**Checked:** it compiles, both sides; in my preview: the button test, 67 of 68 (one check fewer: Prism's settings no longer have a Prism | Sidekick choice to test); the long test, 62 of 66 (three checks of the old Sidekick switches in Prism's settings are gone: they are the Sidekick's own panel's now), with the usual 4 misses; the leak test runs to the end.
**Not checked:** on a phone. The panel is Android's own, so none of it has run anywhere yet. The button test's part 5 checks it on your phone; please run it and send the report. Then try it yourself over an app with the keyboard up.

## Prism, build 177 (15 November 2026)

**File:** `releases/prism-build-177.apk`

Needs Play Protect paused to install. Can be installed over build 176.

**Your phone run of 176:** the Sidekick took over its settings correctly, and all 11 of their new checks passed. The keyboard measurement decided Back: the Sidekick's own panel will never take the focus, so another app's keyboard is never closed by it. Back goes to that app, as with the Sidekick's blobs today. But 68 checks went wrong in the Sidekick half. This build fixes the two causes, and nothing else.

- **Holding one of the Sidekick's blobs could bring up its neighbour's menu.** (A real fault, not only the test's.)
  - **When:** the Sidekick rests near the top or the bottom of the screen, so its fan of blobs doesn't fit and is pressed against the edge. The blobs then come close together.
  - **Why:** a touch was given to the first blob near enough, not the nearest one. Change, Remove or Add then went to the wrong blob.
  - **Now:** the nearest blob (or the nearest name) wins.
  - **Checked** on a copy of the layout, for every height on both sides, with labels on and off: every blob's middle now picks that blob. Before, about 50 heights on each side went wrong.
  - **Still to design, not changed:** near the corners the blobs can sit almost on top of each other. How the fan should look there changes what you see, so it waits for a mock-up.
- **The button test left Prism's settings open,** and everything after it failed.
  - **Why:** my new checks in 176 scrolled the settings down to the looks. The ✕ and Prism | Sidekick were then out of sight, and the test's taps landed on the panel itself.
  - **Now:** the test scrolls back up first. Closing always brings the ✕ into sight. If the settings still don't close, that counts as WRONG, and the test closes them anyway, so the checks after it start with nothing open.
- **A safety net:** whenever Prism's settings close, the Sidekick is shown again unless another panel is still open.
- **The test report** now says, at the blob-hold check, where the Sidekick was and where each of its blobs sat.

**Checked:** it compiles, both sides; in my preview: the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses; the blob fix on a copy of the layout at every height.
**Not checked:** on a phone: the fix to the blobs and the test's Sidekick half both run only there.

## Prism, build 176 (15 November 2026)

**File:** `releases/prism-build-176.apk`

Needs Play Protect paused to install. Can be installed over build 175.

**Your leak test on 175: the cause is proven and the fix holds.** Step 2 begins: the Sidekick's own settings. **Nothing should look different in this build.**

- **The Sidekick keeps its own settings now,** not Prism.
  - **Which ones:** In this app, Over other apps, the two distances, Labels, Icons, Colours and Look.
  - **The move:** the first time 176 starts, the Sidekick reads what Prism had kept for it and keeps it from then on. Prism then deletes its old copies. Everything should be exactly as you left it.
  - **What hasn't changed:** you still change them in Prism's settings, under Prism | Sidekick → Sidekick. Prism now passes each change to the Sidekick, which keeps it. Its own panel comes in the next build, once you've decided where it sits.
- **Icons is now each one's own.** Until now, Icons Prism | Regular was one choice shared by Prism's blobs and the Sidekick's. Now the Sidekick's part of the panel changes only the Sidekick's, and Prism's part only Prism's. Both start as the shared one was.
- **One difference you may notice later:** a Sidekick whose Labels, Colours or Look you had never chosen used to follow Prism's. From now on it keeps what it shows today, even if you change Prism's.
- **Prism passes its panel colours to the Sidekick** (light and dark), ready for the Sidekick's own panel.
- **The rest timer** still follows "In this app" and "Over other apps", exactly as before.
- **A measurement in the button test** (it runs by itself, part 5):
  - **Why:** the Sidekick's own panel can either hear Back or never touch another app's keyboard, perhaps not both. This finds out which on your phone.
  - **What happens:** you'll see a small text field appear under the test banner and the keyboard come up for a few seconds. That's the test.
- **The font guard made complete:** along with the boldness (175), the two other font settings Prism uses, optical size and width, are now drawn in steps. Nothing you see changes.

**Checked:** it compiles, both sides; in my preview: the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. The move, the settings kept by the Sidekick and the keyboard measurement all run only there. The button test checks each of them; please run it and send the report.

## Prism, build 175 (15 November 2026)

**File:** `releases/prism-build-175.apk`

Needs Play Protect paused to install. Can be installed over build 174.

**Your leak test on 174 found it.** Labels Hide/Show and Prism | Sidekick each kept about 15–17 MB a time, for good. Opening and closing things kept nothing.

- **The cause:** a word whose boldness changes while it moves.
  - **Where:** the two-way pickers' labels (Show | Hide, Prism | Sidekick, and every other two-way choice) get bolder or lighter as the thumb slides under them. So do the tab bar's labels as the light slides from one page to another.
  - **Why that costs memory:** every boldness Prism draws a word at becomes a font of its own. The phone's text engine makes it the first time and keeps it as long as Prism runs. A boldness that changes on every frame made a new font on every frame: dozens a move on a phone that redraws its screen 90 or 120 times a second, each one kept.
  - **How bad in real use:** every change of page did it, however you got there: a tab, sliding along the tab bar, a blob or a swipe that opens a page, the timer, Back to Home. That alone could add up to the 1 GB you saw, and Android closing Prism in the background.
- **The fix:** every boldness is now drawn in steps of 10. There are at most a few dozen, each made once and kept.
  - **What might look different:** the labels' boldness now changes in about 15 small steps during the slide instead of smoothly. The colour still changes smoothly. I don't expect you can see it, but please look at Show | Hide in Prism's settings and at the tab bar while changing page.
  - **Nothing else changes:** every other boldness in Prism was already a step of 10.
- **The leak test, again, to prove it on the phone** ("Run the leak test (about 11 min, hands off)"):
  - Labels and Prism | Sidekick again, which should now keep nothing, and Home to Train and back.
  - A word drawn at a new boldness 30 times, the old way, on purpose, so the phone shows what each one cost. Then the same the new way, which should keep nothing.
  - Labels and Prism | Sidekick with one part left out each time: Prism's messages to Android, the Sidekick's "covered" message, the six look previews, the pickers' slide. Also Labels with the settings closed, the settings redrawn with nothing changed, and both with the Sidekick switched off. If anything still grows, one of these names it.
  - The report now also says how many frames each repeat drew. In my preview a Labels change draws about 3 frames, on your phone about 30, which is why my preview never showed this.
  - Not in it any more: the app list, the blobs, the Sidekick's blobs and the solid glass, which 174 showed keep nothing.

**Checked:** in my preview: the leak test runs; the old-way word grows about 2.9 MB a repeat and keeps it, the new way and every other step keep nothing; the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. How many frames a move draws there, what each font costs there, and whether Labels, Prism | Sidekick and changing page now stay flat: only your run can say.

## Prism, build 174 (15 November 2026)

**File:** `releases/prism-build-174.apk`

Needs Play Protect paused to install. Can be installed over build 173.

**Your phone run of 173: 485 right, 0 wrong, with one Prism the whole time.** Step 1 is closed.

**This build only adds a test. Prism itself works exactly as in 173.**

- **The leak test** (new, in the testing panel: "Run the leak test (about 8 min, hands off)").
  - **Why:** in 173, nothing we count grew, yet memory still grew wherever Prism's settings panel changed.
  - **What it does:** it takes a few everyday steps and does each one 20 times, reading memory before and after every 5. The steps: Prism's settings opened and closed; Labels Hide/Show; Prism | Sidekick and back; the app list opened and closed; the blobs opened and closed; the Sidekick's blobs opened and closed. Labels and Prism | Sidekick are then done again with the glass made solid ("reduce transparency"), and again with the Sidekick switched off. Both are put back afterwards, whatever happens.
  - **What the report shows:** for each step, how much the first 5 repeats added, and how much each repeat added after that. A step that leaks shows in the second number.
- **The tests themselves no longer grow.** The button test used to keep the timing of every frame it saw (25,000 by the end); now it keeps only the frames its report uses. The report's numbers are the same.

**Checked:** it compiles, both sides; in my preview: the leak test runs (5 min 8 s; without Android only the "process" column has numbers, and after the first 5 repeats no step adds memory there, every slope between −0.8 and +1.1 MB, which is noise); the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. The leak test's native and graphics readings, and its Sidekick step, run only there.

## Prism, build 173 (15 November 2026)

**File:** `releases/prism-build-173.apk`

Needs Play Protect paused to install. Can be installed over build 172.

**Your phone run of 172: 485 right, 0 wrong.** Step 1 is proven on the phone. The run also showed two copies of Prism at once, as suspected. The first copy was made when Prism was opened, and the second 5 seconds later.

- **Only ever one Prism now.**
  - **How the second copy was made:** you opened Prism one way (the app icon or the installer's "Open"), then went home with the Home gesture. Android keeps the screen it opens as the home screen apart from the same screen opened any other way, so the Home gesture made a second one.
  - **From Prism's side:** every way Prism brings itself forward (the Sidekick, the timer, the sheets, the test) now moves the one Prism screen forward instead of starting it again. If no Prism screen is alive, it starts as the home screen, so the Home gesture finds that same one.
  - **From outside:** the app icon and the installer's "Open" go through a small invisible step that does the same.
  - **The rest:** should Android make a second screen all the same, one of the two is closed at once (the home one stays). The test report's engine list should now say "1 made".
- **Memory:**
  - The second copy wasn't the main cost: with one copy, memory still grows about 57 MB a round, at the same steps.
  - Pictures, decoders and text that Prism makes and doesn't need any more are now let go at once, instead of whenever Prism next cleans up its own memory.
  - The test report counts what each store of pictures and text is holding at every step, on both sides. The next run names the one that grows.
- **One thing that looks different:** Prism's app icon is now a different part of Prism. If you have Prism's icon on another launcher's screen, it may need adding again. Your home screen is Prism itself, so this shouldn't matter.

**Checked:** it compiles, both sides; in my preview: the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. Bringing Prism forward, the icon, the Home gesture and the memory counts on Android's side all run only there.

## Prism, build 172 (15 November 2026)

**File:** `releases/prism-build-172.apk`

Needs Play Protect paused to install. Can be installed over build 171.

**Your phone run of 171:** Prism's blob menu, the settings picker and the smallest tuck all came out right in all four rounds. One new problem: in the Sidekick part, nothing the Sidekick told Prism reached the Prism that was running the test. That's why Change, Add and its settings "failed".

- **The likely cause: two copies of Prism at once.**
  - Prism is your home screen. Android keeps the home-screen copy of Prism separate from a copy opened any other way (the app icon, recents, or the Sidekick bringing Prism forward). So two copies, each with its own engine, can be alive at the same time.
  - The Sidekick always talked to the copy made last. If that wasn't the one on screen, what it said went to the other one. This also fits "it takes me back to Prism and nothing happens".
  - I haven't proven it yet: it can only be seen on the phone.
- **What this build does about it:**
  - The Sidekick now always talks to the copy of Prism that is on screen, and never to one that is gone. With only one copy, nothing changes.
  - Every copy is numbered. The flight recorder writes which copy each message was sent to and whether it answered. The button test's report lists every copy made, with times, and checks that the Sidekick talks to the copy running the test.
  - Next run settles it.
- **The Sidekick stayed hidden** for the rest of a round after its settings failed to open. Nothing hides it now unless a panel really is open.
- **The test:** if the Sidekick isn't talking to the test's Prism, or its settings didn't open, that's reported once as wrong. The checks that depend on it are listed as SKIPPED instead of failing one after another.
- **Memory:** native memory grew about 40 MB a round during part 4 of the button test (Prism's settings). The cause isn't found yet, and nothing changed blind. The report now reads memory after each step of part 4, and again after Java's garbage is collected. That shows which step it is, and whether the memory is really kept or just not yet given back.
- **Home** shows today's date (it said "Friday 13 November").
- **The button test's label** says about 14 minutes, which is what it takes.

**Checked:** it compiles, both sides; in my preview: the button test, 68 of 69 (the miss is the Android-only measurement); the long test, 65 of 69 with the usual 4 misses (a first run also missed the three "hold, then carry" timing checks; the rerun did not).
**Not checked:** on a phone. Everything about the copies of Prism and the Sidekick runs only on Android.

## Prism, build 171 (15 November 2026)

**File:** `releases/prism-build-171.apk`

Needs Play Protect paused to install. Can be installed over build 170.

**What the first phone run of the button test found, fixed.** Nothing should look or move differently.

- **Holding a blob while the blobs are still flying out.** If your finger landed on a blob's place a moment before the blob got there, Prism took it as a hold on the empty space round the blobs and opened **Edit Prism | Add Blob**. Now a hold on a blob's place never opens that menu. That one moment is what made 12 of the 13 misses in your report: the test didn't notice the menu, and every step after it was one step out.
- **The Sidekick at its smallest tuck (8 points)** didn't tuck. When you hold one of its sliders, the Sidekick appears again as a new window. The first place the slider asked for came before that window was on the screen, and was dropped. It is now done as soon as the window is there. A person holding the slider without moving it saw the same.
- **Editing the Sidekick over another app.** Change and Add bring Prism forward and then ask it for its list. If Prism's screen was still being made (which happens after Android has taken memory back), that ask was lost: Prism came forward and nothing else happened. The Sidekick now asks again until Prism answers, for up to about three seconds. The same goes for holding the Sidekick for its settings. This may be what you saw ("takes me back to Prism"), but I can't be sure.
- **The Sidekick's small menu** now acts on the part under your finger when you let go, and only if that's where you pressed. Pressing Remove and sliding onto Change does nothing now.
- **A drag that Android cancels** (rather than your finger letting go) no longer dismisses the Sidekick, tucks it or acts on the timer. It goes back to where the drag began. The workout sheet does the same.

**The tests.**
- **The button test now recovers.** Each part starts from a known state. If one step goes wrong, the checks that depend on it are listed as SKIPPED, with why, instead of failing one after another.
- **"Prism chosen again"** missed on the phone because the red Stop button sat over the Prism half of the picker (the status bar pushes it lower) and caught the test's tap. Its own label said the test's touches pass it by; now they really do.
- **New checks:**
  - Over another app: Change and Add, once choosing and once closing the list. Each time Prism must step back to that app, and the Sidekick must show what was chosen.
  - The small menu: pressed on one part, let go on another.
  - A cancelled drag to the cross.
  - The hold on a blob's place.
- **Memory by part:** the report has a new table with memory at the start of each part of each round, so we can see where the native memory grows.
- **Progress:** while the long test or the button test runs, the banner shows the round, the part and about how many minutes are left, with a thin bar. It changes only when a new part starts; nothing ticks in between.

**Native memory (186 → 279 MB in your report):**
- **Not found yet, nothing changed blind.**
- **170's new picture path is not the cause:** nothing is decoded again.
- **In my preview, Prism's own side stays flat over three rounds.** That covers the parts that run there, which is everything but the Sidekick.
- **The new table** will show which part it grows in on the phone.

**Checked:** it compiles, both sides; in my preview: the button test, 68 of 69, the one miss being the Android-only measurement (69 checks now: each step checks its own first move, and there are new checks); the long test, 65 of 69 with the usual 4 misses (a first run also missed the three "hold, then carry" timing checks, the run after did not); the button test with a step made to go wrong on purpose (1 wrong and 3 skipped, and every step after it right); three rounds of the button test (202 of 203).
**Not checked:** on a phone. The tuck, the round trip over another app, the small menu, the cancelled drag and the Sidekick's checks all run only on Android. The phone's moment of a blob still flying out can't be reproduced in my preview, whose first drawn frame already has the blobs in place.

## Prism, build 170 (15 November 2026)

**File:** `releases/prism-build-170.apk`

Needs Play Protect paused to install. Can be installed over build 169.

**The Sidekick has its own menu now (step 1 of 4 of separating it from Prism).** Nothing should look or move differently: this build moves where the Sidekick's blobs are kept.

- **Where it is kept:** the Sidekick's list of blobs is kept and saved by the Sidekick itself, on Android (a new small part of its code, `SidekickMenu.kt`). Prism keeps only its own list. Before, Prism held both and switched between them, which is how the Add and Remove mix-ups happened.
- **Your Sidekick keeps the blobs it had.** The first time build 170 starts, the Sidekick's list is moved over once: its own saved list if it had one, otherwise a copy of Prism's (which is what it showed). After that the old copy in Prism is deleted.
- **Remove on a Sidekick blob** is done by the Sidekick alone. Prism is not asked and not brought forward, and Prism's own menu is not touched.
- **Dragging the Sidekick's blobs into a new order** is done by the Sidekick alone.
- **Change and Add on a Sidekick blob** still open Prism's app list (the Sidekick gets its own list in step 3), but only to choose from: the choice is sent back, and the Sidekick puts it in its own list (Change: in that place; Add: right after the blob you held; Add Blob: at the end). Afterwards Prism's own blobs do not open, and Prism goes back behind the app you were in, as before.
- **Two small differences you may notice, both from the task:** while Prism's app list is up only to choose for the Sidekick, Prism's triangle no longer turns half a turn; and after choosing, Prism's own blobs no longer come out.
- Prism still draws the Sidekick's pictures: the Sidekick tells Prism which blobs it has, and Prism sends back the name, colour and picture of each, one way.
- **Removed from Prism's code:** the Sidekick's list and the switching between the two lists (`_side`, `side`, `sideOwn`, `sideAt`, `show(side:)`, `sideAsMain`, `putSideAll`, `_sideFile` in `apps.dart`; `_sideKey`, `_pickSide`, `_showMenu(side:)`, the `editSlot`, `sideRemove` and `blobOrder` handlers' list editing in `shell.dart`), and the "Prism | Sidekick" and "Same as Prism" switches of the old edit screen, which could no longer be reached.
- **The button test** checks the new arrangement on the Sidekick: the list is the Sidekick's own; Remove (done over another app where it can) changes only the Sidekick's list and leaves that app in front; Change and Add put the choice only in the Sidekick's list; Prism's list is the same before and after. The test now uses a list of its own for the Sidekick and puts yours back afterwards (until now it reset your Sidekick to Prism's blobs).

**Checked:** it compiles, both sides; a second, separate read of the code (it found four rare cases, for example the test resetting a menu that had not been moved yet; all fixed); in my preview, on the final code: the button test, 62 of 63 (the one miss is a measurement only Android can make; a first run also missed the flick timing check, the run after did not); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. Everything about the Sidekick runs only on Android, so the move of your list, Remove, Change, Add and dragging on the Sidekick have not run anywhere yet. The button test's Sidekick half cannot run in my preview.

**Please try:** before installing, note which blobs your Sidekick shows; after installing, check it shows the same ones. Then the steps in `reviews/step1-report.md`, and the button test.

## Prism, build 169 (15 November 2026)

**File:** `releases/prism-build-169.apk`

Needs Play Protect paused to install. Can be installed over build 168.

- **An empty menu no longer strips the button.** With every blob removed, Prism's button fell back to a bare "+" and the Sidekick drew nothing at all (dark glass), because both take their colours from the blobs. With nothing in the menu they now keep their chosen look, drawn in the light's own colours. The "+" to add a blob is still there when the blobs are opened.

**Checked:** it compiles, both sides; in my preview, Prism's button with an empty menu.
**Not checked:** on a phone; the Sidekick with an empty menu (Android only). The automatic tests were not run again: this changes only what colours the sign is drawn with.

## Prism, build 168 (15 November 2026)

**File:** `releases/prism-build-168.apk`

Needs Play Protect paused to install. Can be installed over build 167.

**The Sidekick's sliders: the real cause, fixed.** When a slider was grabbed, the panel fades everything else away. To leave that one slider alone, my code changed how it sat in the panel, which made it anew under the finger: the drag was lost the moment it began, the panel half-faded and flickered back. Now the slider keeps its place and only what is round it fades. In my preview the panel clears fully and the slider follows the drag.

**The empty space round the blobs.**
- **In Prism:** hold the empty space while the blobs are out, and a small menu comes up: **Edit Prism | Add Blob** (Add Blob in green, there while there is room). Add Blob opens the list for the first free place, at the right of the others. Edit Prism opens Prism's settings.
- **On the Sidekick:** the same on the empty space round its blobs: **Edit Sidekick | Add Blob**.
- (An unpublished version of this had a third item, "Sidekick". That was my misreading and is gone.)

**Prism's settings open and close exactly as the app list does.** Not an imitation with its own timing any more: the same two springs (the quick one with a hint of give to open, the quick one to close), the same growth out of the button and back into it, the contents fading at the same points. Every way of closing (the X, a tap beside it, a tap on the button, back) closes it at that speed.

**Checked:** it compiles, both sides; in my preview: the slider dragged with the panel clear, the empty space's menu; the button test's Prism half, 62 of 63 (the one miss is a measurement only Android can make), with new checks for the empty space's menu; the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone; the Sidekick's "Edit Sidekick | Add Blob" (Android only).

**Not in this build, on purpose:** the back button closing the Sidekick's blobs while a keyboard stays open (you asked me to explain first), and the glass against the app list (the doubled buzz). Both are explained in my message.

**Still to do:** the Sidekick's settings over whatever app you are in.

## Prism, build 167 (15 November 2026)

**File:** `releases/prism-build-167.apk`

Needs Play Protect paused to install. Can be installed over build 166.

**The button test.** A hands-off test of Prism's button and the Sidekick, about 7 minutes (four rounds, then a minute of nothing being touched).
- **How to start it:** hold any blob, tap Change (or Add), and the first thing in the list is **Button test**. Tapping it starts the test and puts nothing in the blob's place. It is also in the frame-rate panel's list of tests.
- **What it does:** taps, quick taps, presses just short of a hold, holds, trembling holds, a finger that moves first, flicks; the settings opened and closed every way (button, X, back, five times quickly); a blob's small menu, Change, Add and Remove, every blob removed and the plus, a blob dragged at once. On the Sidekick: its menu, its small menu (Change, Remove, Add), held for its settings (closed and with its blobs out), moved first, let go low at the side, carried to the bottom, its two distances at their ends, an emptied menu. After each part it checks that nothing was left behind: no panel, no small menu, no list, no glass out, the sign turned the right way.
- At the end, "Copy report" and paste it here.

**Found by the test, and fixed:** removing the last blob left its "+" inside the button until the blobs were next opened. It now comes out at once.

**From your recordings:**
- **The bar's rim at either end:** touching near an end made the tab glass swell past the end of the bar, so its magnifying edge lay over the bar's rim and bent it. The tab glass now always stays inside the bar's ends.
- **The triangle opening and closing the app list:** it was turning half way in about a tenth of a second, which read as a jump. It now takes about a fifth, and still stops without swinging past.
- **The settings now grow out of the button and go back into it**, on the same spring as the app list, instead of sliding up from the bottom.
- **The Sidekick under its own settings:** in 163 I kept it in sight while its settings were open; your recording shows it then lay over the panel's switches and could take their taps. It is hidden again under any panel, and shown only while you hold one of its two sliders (the panel clears then).
- **The keyboard in WhatsApp:** opening the Sidekick's blobs took the keyboard's focus and closed it. The blobs' window no longer takes focus, so a keyboard stays open. (The back button, while its blobs are out, now goes to the app underneath; a tap beside the blobs still closes them.)

**Checked:** it compiles, both sides; the button test's Prism half in my preview, 55 of 56 (the one miss is a measurement only Android can make); the long test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone. The button test's Sidekick half runs only on Android, so this is the first time it will run at all: some of its checks may be wrong about what is right, and I will read them with that in mind.

**Still to do:** the Sidekick's settings shown over whatever app you are in (Android drawing its own panel).

## Prism, build 166 (15 November 2026)

**File:** `releases/prism-build-166.apk`

Needs Play Protect paused to install. Can be installed over build 165.

- **Labels is a glass picker now**, like every other two-way choice in the settings: "Labels", then Show | Hide. One for Prism and one for the Sidekick, as before.

**Looked into, not fixed yet:** the bar's left rim going faint while the tab glass is pulled to the right. Measured frame by frame in your recording, nothing changes on the bar except the touch dot; in your screenshots the difference is clear. The bar itself does not move or stretch, and its glass settings do not switch during a drag in Original mode. I could not make it happen in my preview (which is in the light theme).

**Checked:** it compiles; the automatic test, 64 of 69: the usual 4 misses and "a slower flick up is still the app list", a timing check in my slow preview that has missed now and then before. The labels checks pass with the new picker.
**Not checked:** on a phone.

## Prism, build 165 (15 November 2026)

**File:** `releases/prism-build-165.apk`

Needs Play Protect paused to install. Can be installed over build 164.

**The looks, tidied.**

- **Triangle is gone; Window stays.** Since build 162 the two worked the same way. Window is the simpler of the two in the code and is the look a new phone starts with. If you had Triangle chosen, you now have Window.
- **Bands, Clear and Lined are gone.** If one of them was chosen, you now have Window.
- All four are removed completely, on both sides: their drawing, the band-cutting they shared, and the cog's special case for Triangle. Nothing of them is left in the code. Six looks remain: Pearls, Petals, Lotus, Beam, Halo, Window.
- **Pearls, reworked.** The pearls are about half as large again and stand in a wider arc above the white point, so the look fills the glass and sits in its middle, as the others do. Each pearl is lit from above, with a small highlight and a little shade underneath.
- **The black ground under a Vivid look** is no longer a flat black disc: it is a touch lighter in the middle and deepest at the rim, so the glass has depth. This is for every look that has it, Pearls included.

**The thick tinted rim on the button.**

- The black under the glass used to stop four fifths of the way out, with a hard edge. Between it and the glass's rim was a wide tinted band, and the hard inner circle gave the eye a second circle to judge the triangle against. The black now runs out almost to the rim and melts away there. Only the rim's own thin light is left, and there is no inner circle.

**Checked:** it compiles, both sides; in my preview: the six looks in the settings, Pearls on the button, the button without its inner circle; the automatic test, 65 of 69 with the usual 4 misses.
**Not checked:** on a phone; the Sidekick's Pearls (Android only).

## Prism, build 164 (15 November 2026)

**File:** `releases/prism-build-164.apk`

Needs Play Protect paused to install. Can be installed over build 163.

- **The List-mode pinch no longer jumps at the end.** The list was quietly keeping the phone's status-bar height as space at its top, which the change of density did not know about: the apps arrived about that much higher than the list, then snapped down. The list no longer has that space (the panel is well below the status bar anyway), so they land exactly where the list is. The first row of the list also starts a little higher than before because of this.
- **An emptied menu shows one "+" blob.** Remove every blob from Prism's menu or the Sidekick's and a single "+" stands in the middle; a tap on it opens the list to add one.

**Checked:** it compiles, both sides; the automatic test, 65 of 69 with the usual 4 misses. (A first run had 3 more misses, the "hold, then carry" checks that depend on timing in my slow preview, as in build 160; the run after had none.)
**Not checked:** on a phone; the Sidekick's "+" (Android only); the List pinch with real fingers.

## Prism, build 163 (15 November 2026)

**File:** `releases/prism-build-163.apk`

Needs Play Protect paused to install. Can be installed over build 162.

**Blobs: removing and adding, reworked as you described.**

- **Remove:** the others close up round the middle at once. No plus is left behind.
- **Add (green):** a third choice in a held blob's small menu, there whenever the menu has room (fewer than five). It opens the list titled "Add", and what you choose goes right after the blob you held; the ones after it move along. Close the list without choosing and nothing changes.
- The same on the Sidekick: its held-blob menu has Change, Remove and, when there is room, Add.

**The button's settings.**

- **No cog any more.** Holding the button turns the triangle half a turn, as the app list does, and it turns back when the settings close.
- **The settings sit above the button**, which stays in sight below them, and a tap on the button closes them.
- **The cog that stayed** (your screenshot): the settings' flag could outlive the panel. Now the panel's absence always wins, and opening the settings puts the blobs away first.
- **The triangle popping back when the settings closed:** the cog it came from was drawn a quarter larger than the triangle, so the triangle appeared smaller at the very end. They now match. (With no cog, this no longer happens in any case.)
- **The turning settles without overshoot**, for the app list and the settings: it turns and stops. That was the "spins too much".

**The Sidekick.**

- **Holding the Sidekick while its blobs are out** now opens its settings, as holding it closed does.
- **No more jump to the Train page.** Prism was being brought forward the way the workout timer brings it, which goes to Train. It now comes forward on whatever page it was on.
- **Smooth sliders:** "Distance from the edge" and "Tucked in, how much shows" no longer have stops. Any distance, from touching the edge to 36 points away, and from 8 to 40 points showing.
- **No more blinking while sliding:** the Sidekick was taken off the screen and put back each time a slider was grabbed and let go. While its own settings are open it now stays on screen, so you see it move.

**Holding is a little quicker:** 15% shorter than Android's own hold time, the same for every hold in Prism and on the Sidekick.

**Checked:** it compiles, both sides; in my preview: the settings above the button with the triangle turned; the automatic test, 65 of 69 with the usual 4 misses. It has new checks for: remove closing up the others in the middle; Add putting the new blob right after the held one; no Add when there are five; the triangle turning half way for settings and back; the settings above the button; a tap on the button closing them.
**Not checked:** on a phone. Everything on the Sidekick is Android only.

**Next:** the Sidekick's settings drawn over whatever app you are in, so editing it never leaves that screen; a "+" blob when a menu is emptied; a calmer pinch in List mode.

## Prism, build 162 (15 November 2026)

**File:** `releases/prism-build-162.apk`

Needs Play Protect paused to install. Can be installed over build 161.

**Triangle and Petals now work the way Window does: the colours stand still, the shape turns over them.**

- **Triangle:** its light now always comes in from below the glass and fans upward, and stays there. The triangle turns over that fan, so its left is always the warm end and its right the cool end, whichever way it points. At rest it points down into the white light, as before.
- **Petals:** each petal is now a window onto Window's upright bands. The petals turn; the bands do not. Where petals overlap the colour is deeper, which keeps them readable.
- **Both on the Sidekick as well.**
- **The other looks** (Pearls, Lotus, Beam, Bands, Clear, Lined, Halo) do not turn in Prism, so their colours were already still there. On the Sidekick every look leans toward the middle of the screen, the way the blobs open. I left that lean as it is. If you want those looks to keep their colours still on the Sidekick too, say so and I will do the same for each.

**Checked:** it compiles, both sides; in my preview, Triangle and Petals at rest, with the blobs out and with the app list open (the colours hold their places in all three); the automatic test, 62 of 66 with the usual 4 misses.
**Not checked:** on a phone; the Sidekick's versions (Android only).

## Prism, build 161 (15 November 2026)

**File:** `releases/prism-build-161.apk`

Needs Play Protect paused to install. Can be installed over build 160.

**The triangle is centred in the glass, whichever way it points.**

- **What was wrong:** with the blobs out, the triangle turns 60°, and a triangle turned 60° looks exactly like one turned 180°, pointing up. But the small nudge that keeps it off the rim was worked out from how far it had turned, not from how it looks. At 60° that pushed it up and to the right; in your recordings it sat about 9 points high and 3 to the right. In the app list (180°) the nudge was right, which is the only state I had checked.
- **Now:** the nudge is worked out from where its three corners actually are on screen, so it is the same at rest, with the blobs out and with the app list open, and it moves smoothly while it turns. Its middle as the eye sees it sits in the middle of the glass: most of the way from its own centre to the middle of its outline.
- **The Sidekick** gets the same centring for Triangle and Window. Before, it had no nudge at all.

**Checked:** it compiles, both sides; in my preview, the button at rest, with the blobs out and with the app list open: the triangle sits in the same place in all three. The automatic test: 61 of 66, the usual 4 misses and one more, "a slower flick up is still the app list". That one depends on timing in my slow preview and has missed now and then before (build 154). This build changes only how the triangle is drawn, nothing a finger does.
**Not checked:** on a phone, and the Sidekick's triangle (Android only).

## Prism, build 160 (15 November 2026)

**File:** `releases/prism-build-160.apk`

Needs Play Protect paused to install. Can be installed over build 159.

**The Sidekick's two places, chosen with sliders.**

- In the Sidekick's settings (hold the Sidekick, or hold Prism and choose Sidekick) there are two new sliders: **Distance from the edge** (how far it rests from the side of the screen, from touching it to 32 points away; it was 8) and **Tucked in, how much shows** (from a sliver of 8 points to 38; it was 22).
- **While you drag either slider, the panel goes clear** (only that slider stays) and the Sidekick goes to the place you are choosing, at the side it is on: out at its resting place, or tucked in. It moves with each step. Let go and the panel comes back; the choice is kept.
- The same stop slider as the app list's Density.

**A quieter way to dismiss the Sidekick.**

- Picking the Sidekick up no longer brings up the big X at the bottom. Nothing shows while you move it around.
- Only once you carry it into the bottom quarter of the screen does a small, thin ring with a little × fade in, clearer the lower you go. Over it, the ring opens out round the Sidekick and takes Prism's colour; let go there and it is dismissed, as before.
- It also pulls less far than the big X did, so a Sidekick put low on the screen is not caught by accident.
- The workout timer keeps its X and its two places beside it, unchanged.

**Checked:** it compiles, both sides; in my preview: the two sliders in the Sidekick's settings and the panel clearing while one is dragged; the automatic test, 62 of 66 with the usual 4 misses. (A first run had 3 more misses, all from the robot's "hold, then carry" being a hair too quick for the hold; the run after it had none. That check depends on timing in my slow preview.)
**Not checked:** on a phone. The Sidekick moving with the sliders, and the new way out at the bottom, are Android only and have not run anywhere yet.

**Not done yet, from your earlier message:** every look keeping its colours still as Window does.

## Prism, build 159 (15 November 2026)

**File:** `releases/prism-build-159.apk`

Needs Play Protect paused to install. Can be installed over build 158.

**A calmer pinch, in both layouts.**

- **Nothing flies across the grid any more.** An app that stays in its row slides along it to its new place. An app that goes to another row fades where it was and comes up where it now is. Before, those apps flew diagonally over all the others, which was most of the busyness.
- **The grid only leans with your fingers.** It follows them a third of the way, not one-to-one, so the whole screen no longer swells and shrinks under a pinch. The ticks and the steps come at the same finger distances as before.
- **No bounce when you let go.** It comes to rest and stays. At the largest and smallest size the give is half what it was.
- **Quicker off the mark, softer at the end** (three tenths of a second, starting fast).
- **List mode:** near the end of the list, the apps are now sent to where the list will truly be, so there is no jump when they arrive.

**Checked:** it compiles; the automatic test in my preview, 62 of 66 with the usual 4 misses (the pinch checks right).
**Not checked:** on a phone, and I have not seen this in motion: my preview draws too slowly to judge movement. Your two recordings are what I worked from. One thing I could not explain from them: the Pages recording still shows two grids laid over each other, which is how builds 153 to 155 changed size, not 156 or later. If that recording was made on build 157 or 158, please tell me, because then something on the phone differs from my preview.

## Prism, build 158 (15 November 2026)

**File:** `releases/prism-build-158.apk`

Needs Play Protect paused to install. Can be installed over build 157.

**The new way to change things, the same for Prism and the Sidekick.**

*Holding a blob*
- **A small menu comes up beside it: Change and Remove.** The blob lifts a little and the others stand back. You can let go; the menu stays. A tap anywhere else puts it away.
- **Keep holding and move:** the menu goes and the blob comes along, to be put in another place.
- **Change** opens the list titled "Change" with the blob's name. While it is up, the centre button is that blob: the sign draws in and the blob grows out of it, and goes back when you have chosen. The list also has a red **Remove**.
- **Remove** leaves a **plus** in the blob's own seat; the others do not move over. A tap on the plus opens the same list, titled "Add".
- **On the Sidekick** it is the same menu, beside the blob, over whatever app you are in. Change brings Prism forward on the list and steps back afterwards. A removed blob shows as a plus there too, and a tap on it adds one. (After Remove the Sidekick's menu closes; the plus is there the next time it opens.)

*Holding the button itself*
- **Hold the closed Prism button:** its settings, with Prism chosen. **Hold the Sidekick:** the same settings with Sidekick chosen (Prism comes forward for it and steps back when you close them). **A tap on the Sidekick** still opens its blobs.
- The panel is titled Prism or Sidekick. New in it: **Show labels**, a switch, one for each of the two. "In this app" and "Over other apps" show only for the Sidekick. Prism's **two-finger swipes** are a row of four: tap one to say what it does; the list it opens has Remove to clear it, and then the settings come back.
- While the settings are open the button is the cog.

*Gone*
- The old edit screen (red minuses and pencils, the floating Prism | Sidekick picker, the swipes across the top) can no longer be reached. Its code is still in the app, unused; I will take it out in a build of its own once you are happy with the new way.

*Hold or glass*
- A finger still for Android's hold time is a hold, and nothing after that turns it into the glass. A finger that moves first is the glass or a flick, as before. The glass now starts a little sooner (after 8 points of movement, was 10; sideways or down it lifts after 16, was 22). The flick up for the app list is judged as before.

**Checked:** it compiles, both sides; in my preview: the small menu, the plus left in the seat, the Change list with the button as the blob, the new settings panel; the automatic test, 62 of 66 with the usual 4 misses.
**Changed in the test:** the checks for the old edit screen are replaced by checks of the new way: the menu on a hold, Change, Remove, the plus in its seat, Add, Remove from the list, a trembling finger, a blob moved at once, held-then-carried, settings on holding the closed button (and that neither the glass nor the blobs came out), labels, the Sidekick's switches, the swipes set from the settings. The check for making a two-finger swipe on the old edit screen is gone with that screen.
**Not checked:** on a phone. Everything on the Sidekick (its small menu, the plus, hold for settings, Prism stepping back) is Android only and has not run anywhere yet. Whether the hold and the glass ever get confused under a real thumb can only be judged on the phone.

**Still to come, from your last message:** all looks keeping their colours still as Window does, and a calmer pinch (List mode first).

## Prism, build 157 (15 November 2026)

**File:** `releases/prism-build-157.apk`

Needs Play Protect paused to install. Can be installed over build 156.

**Hold a blob to change it. Everywhere, one move.**

- **In Prism:** hold a finger still on a blob and its app list comes up at once, to choose what goes in its place. Close the list without choosing and the blobs are back out as they were; choose, and they come back out with the new one.
- **On the Sidekick:** hold a finger still on one of its blobs and Prism comes forward with the app list for that blob, in the Sidekick's own menu. Choose (or close the list) and Prism steps back to the app you were in. Before, a hold only put the blobs in edit mode, and a second tap opened Prism on the shared edit screen.
- **The same wait in both:** Prism now uses Android's own hold time, the one the Sidekick has always used (the one you said is right), instead of Flutter's.
- **When it does not trigger:** a finger that moves before the wait is a drag, never a hold, however long it then stays. A finger that only trembles a pixel or two still counts as held. Not while the blobs are flying out or back in, not while the app list is already up, not while a blob is being dragged.
- **Removing, reordering, setting the two-finger swipes, names on or off:** still there, one step away. Hold the centre button while the blobs are out, as before.

**Checked:** it compiles, both sides; the automatic test in my preview, 60 of 64 with the usual 4 misses. It has 4 new checks, all right: a hold opens that blob's list; closing it leaves the blobs out as they were; a trembling finger still counts as a hold on the right blob; a blob moved at once is a drag with no list.
**Changed in the test:** the checks that used a hold on a blob to start edit mode now hold the centre button, which still starts it. The check "held and then dragged, the first is now the last" tested the old hold-then-drag and is replaced by the new checks above; dragging while in edit mode is still checked, both ways.
**Not checked:** on a phone. The Sidekick side (Prism coming forward, then stepping back to the app you were in) is Android only and cannot run in my preview.

## Prism, build 156 (15 November 2026)

**File:** `releases/prism-build-156.apk`

Needs Play Protect paused to install. Can be installed over build 155.

**A calmer change of density.** In your recordings, each change of size laid the old grid over the new one and faded it away. For a moment every icon was there twice, in two places, which is what was hard on the eyes.

- **Now each app travels.** When the size changes, by pinch or by the Density slider, every app glides from its old place to its new one and grows or shrinks on the way. Its name goes with it. Nothing is ever drawn twice. It takes about a third of a second and eases in and out.
- Apps that come into view fade in as they arrive; apps that leave the view fade out as they go.
- During a pinch, the grid still follows your fingers as before; the gliding happens at each tick, from where the grid was under your fingers.
- For the battery: the gliding is drawn only while it runs. Before and after, the grid is the same single picture it always was. The picture of the old grid that build 153 kept is gone.

**Checked:** it compiles, both sides; in my preview: a frame caught mid-change shows each app once, between its old and new place; the automatic test, 56 of 60 with the usual 4 misses, the three pinch checks right.
**Not checked:** on a phone, and how it feels at 120 Hz. My preview draws slowly, so I saw single frames, not the motion.

## Prism, build 155 (15 November 2026)

**File:** `releases/prism-build-155.apk`

Needs Play Protect paused to install. Can be installed over build 154.

- **Names, again.** The centre button is **Prism**. The side one is **Sidekick**. In the Blob panel, Design is Prism | Sidekick; while changing the menus the picker is Prism | Sidekick and the reset is "Same as Prism"; the action you can give to a swipe or a place in the menu is "Sidekick".
- **The Sidekick action pulls it out when it is tucked in.** If the Sidekick is already on screen but tucked into the side, using the action brings it out to where it rests at that side, with a tick, as a tap on it would. Brought out for the very first time by the action, it also starts out, not tucked. When it comes back by itself in the next app you open, it stays as you left it.

**Checked:** it compiles, both sides.
**Not checked:** on a phone. The Sidekick coming out is Android only and cannot run in my preview. The automatic test was not run again: only labels changed on the side it covers.

## Prism, build 154 (15 November 2026)

**File:** `releases/prism-build-154.apk`

Needs Play Protect paused to install. Can be installed over build 153.

- **The "Prism" action (was "Side blob") now brings it out.** The cause: an old switch in Settings, "The lens is a container (new)", was off on your phone, and with it off the side Prism was never shown at all, by the action or otherwise. That switch chose between the older floating lens, which took the look of the app on it, and the newer one, which is always the same glass and holds the menu. The older one went away with hand-placed blobs, so the switch is removed and it is always the newer one.
- **The cog goes back to the sign at the same unhurried pace it should come from it.** In the code the reshaping was already the same both ways, drawn from one number, but it ran in about an eighth of a second, which reads as a swap. It now takes about twice as long, both ways.

**Checked:** it compiles, both sides; the automatic test in the preview: 56 of 60 with the usual 4 misses (a first run had one more miss, a timing check about the flick; the second run did not).
**Not checked:** on a phone. Both changes are about things my preview cannot show well: the side Prism is Android only, and I have not judged the cog's pace by eye. If the cog still does not look like a reshaping on the way back, a short recording would show me what differs.

## Prism, build 153 (15 November 2026)

**File:** `releases/prism-build-153.apk`

Needs Play Protect paused to install. Can be installed over build 152.

**Pinch the app list to change its density.**

- **Two fingers on the app list:** together for more apps across, apart for fewer and larger. The grid follows the fingers, clicks once (a tick) as it passes each size, and settles with a small spring when you let go. It works in both layouts, Pages and List. The choice is saved, the same one the Density slider sets.
- **At the largest and the smallest size** the grid gives a little under the fingers and comes back: there is nothing further to go to.
- **A pinch does nothing else.** While two fingers are down, and until both have left, no app is opened, no page is turned and the list does not scroll.
- **The Density slider now moves the grid the same way:** the old grid zooms and fades into the new one instead of jumping.
- **The app that was first in view stays in view** when the size changes (before, the slider could leave you on another page).
- How it is done, for the battery: the old grid is kept as one picture for about a fifth of a second and thrown away; nothing runs when the grid is at rest.

**Names.** The side one is now **Prism**; the centre piece (the magnifying glass and its menu) is **Glass**.

- In the Blob panel: Design is **Glass | Prism** (was Main button | Side blob).
- While changing the menus: the picker is **Glass | Prism**, and "Same as main" is **Same as Glass**.
- The action you can give to a swipe or a place in the menu is called **Prism** (was Side blob).
- The switch "In Prism" is now **In this app**, so that it is not mistaken for the side Prism.

**The flight recorder now says why Android closed Prism.** Your report from build 152 shows all of Prism starting afresh three times in two minutes, once after only 5 seconds away, and I could not tell from it whether that was memory or a crash. From this build, each time all of Prism starts afresh, the next line is Android's own record of why it ended last time: short of memory, a crash, closed by hand, and so on, with how much memory it held.

**Checked:** it compiles, both sides; in my preview: the slider leaves the right grid with the same first app; the automatic test, which now pinches the app list both ways (3 new checks, all right): 56 of 60 with the usual 4 misses.
**Not checked:** on a phone. I have not seen the zoom itself in motion (my screenshot missed it), nor the renamed labels on screen (they are plain text changes). The pinch with real fingers, how the zoom looks at 120 Hz, and the "why it was closed" line (Android only) have not been seen by me.

## Prism, build 152 (15 November 2026)

**File:** `releases/prism-build-152.apk`

Needs Play Protect paused to install. Can be installed over build 151.

- **"Side blob" comes after Prism's five own actions** in the choices (Workout, Log food, Scan, Weigh-in, Timer, then Side blob, then the pages), not first. Those five are used most. It also keeps the automatic test true: one of its checks taps the first choice and expects Workout, and in build 151 that check failed for that reason alone.

**Checked:** it compiles; the automatic test in the preview, back to 53 of 57 with the usual 4 misses.
**Not checked:** on a phone.

## Prism, build 151 (15 November 2026)

**File:** `releases/prism-build-151.apk`

Needs Play Protect paused to install. Can be installed over build 150.

- **"Side blob" is an action you can give to a swipe or to a place in the menu.** It is the first of the choices when you change a blob or set a two-finger swipe. Used, it brings the side Blob out where it was last left, even if you had sent it away. If Prism has not yet been allowed over other apps, it takes you to Android's screen for that; if both "In Prism" and "Over other apps" are off, it can go nowhere and there is a thud.
- In the side Blob's own menu a blob given "Side blob" is left out: there it would do nothing.

**Checked:** it compiles, both sides; in my preview: "Side blob" among the choices for a blob; the automatic test in the preview.
**Not checked:** on a phone: the side Blob coming out when the action is used cannot run in my preview.

**Housekeeping:** this machine's disk filled up during build 150. I removed my own old screenshots and logs, and the copies on this machine of the files for builds 1 to 130. Those builds are all still in the repository and their download links still work (checked for build 100).

## Prism, build 150 (15 November 2026)

**File:** `releases/prism-build-150.apk`

Needs Play Protect paused to install. Can be installed over build 149.

**The side Blob's menu can be its own.**

- **It starts as the main button's menu, and costs nothing until you want it.** Change the main menu and both change. The first time you change something in the side Blob's menu, it becomes a set of its own.
- **One place to change both.** While the blobs are being changed in Prism, a new picker above them, **Main button | Side blob**, says whose menu is out. Everything works as before on the one that is chosen: tap a blob to change it, the red minus to take it out, drag to reorder, an empty place to add. Done changing, the blobs out of the button are the main button's again.
- **"Same as main"** appears beside the picker once the side Blob has a set of its own: a tap makes its menu the main button's again.
- **From the side Blob itself:** hold a blob in its menu and they wear their edit marks, as before; a tap on one now brings Prism up changing the side Blob's menu (not the main one's), with the app list open to choose for that place. Dragging them into a new order in the side Blob's menu reorders the side Blob's menu only.
- The two-finger swipes are still one set: they belong to Prism, not to either menu.
- The flight recorder's settings now say what the side menu holds and which design each of the two wears.

**Checked:** it compiles; in my preview: the picker on the edit screen; with Side blob chosen, a blob taken out left the side menu with four and an empty place, the main menu still had its five, "Same as main" appeared, and the side menu was still its own after Prism was started again; the automatic test in the preview.
**Not checked:** on a phone. The side Blob's menu showing its own set, and the two ways in from it (tap while changing, drag to reorder), cannot run in my preview: they use the same messages to and from Android as before, now carrying the side menu.

## Prism, build 149 (15 November 2026)

**File:** `releases/prism-build-149.apk`

Needs Play Protect paused to install. Can be installed over build 148.

- **A design each for the main button and the side Blob.** In the Blob panel, a new picker, **Design: Main button | Side blob**, says which of the two you are choosing for. The Colours (Mellow, Vivid) and the Look below it then show and change that one's. Until something is chosen for the side Blob, it wears what the main button wears. (Icons, Prism or Regular, is still one choice for both: it is about the blobs in the menu, not the sign.)

**Checked:** it compiles; in my preview: the panel with the new picker; with Side blob chosen it showed the side Blob's own colours and look, a look chosen there was saved for the side Blob only, and the main button kept its own; the automatic test in the preview.
**Not checked:** on a phone. The side Blob itself wearing its own design I could not see (it only exists on Android): the same two messages tell it as before, now with the side Blob's values.

## Prism, build 148 (15 November 2026)

**File:** `releases/prism-build-148.apk`

Needs Play Protect paused to install. Can be installed over build 147.

- **The glass is less tinted.** Its wash of Prism's colour is under half what it was, and the glow at its foot is halved, so the black under it shows through clearly.
- **Every look works as the triangle does.** On Prism's button no look has a disc of its own any more. Under the glass each one is set in the glass's black; as the glass is lifted the black goes with it and the shape is left alone (the pearls, the petals, the bands and their prism); when the glass has landed back the black fades in again. Mellow or Vivid changes only the colours. (Turning is still the triangles' and Petals' alone.)
- **The looks in the Blob panel are shown on that same black.**
- **The Vivid background:** the white line across the top of the colour bands is gone, and the grey halftone dots are far fainter, close to the ground's own colour.

**Checked:** it compiles; in my preview: Window, Pearls and Bands under the glass and with the glass lifted, the Look row in the panel; the automatic test in the preview (run before the two changes to the background, which are two lines).
**Not checked:** on a phone. Lifted from under the glass, Pearls' white point is faint on a light page: look at whether each look reads well alone on both a dark and a light background.

## Prism, build 147 (15 November 2026)

**File:** `releases/prism-build-147.apk`

Needs Play Protect paused to install. Can be installed over build 146.

- **The black no longer pops in when the glass comes back**, from your recording. It was tied straight to where the glass was, and the glass is set back in its place all at once as it lands, so the black came back all at once too. Now it has a fade of its own: as the glass is lifted it goes quickly; as the glass comes back it waits until the glass has landed and then comes in gently, over about a quarter of a second, while the glass settles.

**Checked:** it compiles; in my preview: the glass coming back, a quarter, half and three quarters of a second after it was let go, and after it settled (no black as it lands, the black in once it has); the automatic test in the preview.
**Not checked:** on a phone.

## Prism, build 146 (15 November 2026)

**File:** `releases/prism-build-146.apk`

Needs Play Protect paused to install. Can be installed over build 145.

- **Black under the glass.** While the magnifying glass rests on the prism (Triangle and Window), the prism is set in black: the glass's own darkness. As the glass is lifted away the black goes with it, fading out over the first moment of the lift, and the triangle is left alone; as the glass comes back, the black comes back with it.
- **The triangle sits in the middle, and a little larger.** An inscribed triangle's tip touches the edge of its circle, so it looked as if it sat on the bar's bottom border. It is now drawn lifted away from its tip and about 6% larger. The lift follows the way it points, so it stays in the middle when it turns. Becoming the cog, it lets the lift go as the cog forms.

**Checked:** it compiles; in my preview: Window mellow and vivid at rest, turned with the blobs out, a moment into the glass being lifted, and lifted; the automatic test in the preview.
**Not checked:** on a phone, and the fade in motion. The floating blob is drawn as before (its triangle is not lifted yet).

## Prism, build 145 (15 November 2026)

**File:** `releases/prism-build-145.apk`

Needs Play Protect paused to install. Can be installed over build 144.

- **The glass is larger than the bar is tall.** The bar is 66 points high; the glass was 64 across, and in build 144 73, which only just cleared it. Now it is 80 across, plainly larger, rising past the bar at the top and at the foot. The blob under it keeps its size.

**Checked:** it compiles; in my preview: the bar with the larger glass; the automatic test in the preview.
**Not checked:** on a phone. The button's place for touches is still its old 64 points; the glass outside that does not take touches.

## Prism, build 144 (15 November 2026)

**File:** `releases/prism-build-144.apk`

Needs Play Protect paused to install. Can be installed over build 143.

- **The triangle is its full size again, and the glass over it is larger**, as you meant it. In build 139 the blob was made smaller inside the same glass. Now the blob (the triangle, or any look) is back to the size it had, and the magnifying glass is drawn about a seventh larger, so it rises just past the top edge of the bar and lies over the blob with a little room all round. Lifted away, the glass leaves the blob at that same size.
- **The glass and the coloured triangle are the centre piece**: a phone with nothing chosen yet starts on Window. (A look chosen before stays chosen.)

**Checked:** it compiles; in my preview: the button mellow and vivid, and with the glass lifted; the automatic test in the preview.
**Not checked:** on a phone. The button's place for touches is as it was; the glass drawn past it does not take touches there.

## Prism, build 143 (15 November 2026)

**File:** `releases/prism-build-143.apk`

Needs Play Protect paused to install. Can be installed over build 142.

- **The cog follows the look**, and Vivid. It used to be one sweep of the colours round it, whatever the look. Now it is a window cut in the shape of a cog onto the look itself, on the look's own ground (black when vivid): Window's cog shows the same upright bands standing still; Triangle's the light fanned from its corner, the fan opening wider as the triangle becomes the cog; Beam's, Bands', Clear's and Lined's the bands and the white prism; Pearls', Petals', Lotus' and Halo's their own pearls, petals and rings. The triangle still reshapes into it, corner by corner; the others fade into it.

**Checked:** it compiles; in my preview: the cog of Window, Triangle, Bands and Pearls, mellow and vivid, and of Window a moment into the change; the automatic test in the preview.
**Not checked:** on a phone, and the change in motion.

## Prism, build 142 (15 November 2026)

**File:** `releases/prism-build-142.apk`

Needs Play Protect paused to install. Can be installed over build 141.

- **A new background pattern: Vivid.** In Prism's settings, under Background, choose Pattern or Both, and then Vivid (after Ripples, Contours, Arcs and Weave). Black by night, white by day, and the light's own six colours at full strength:
  - **blocks:** six upright bands rising from the foot on the left, each a step lower than the last, with a thin line where the staircase begins;
  - **circles:** a target of the six colours, ring inside ring, off the top right corner, and a blue half disc rising from the foot on the right;
  - **dots:** a halftone field on the right, the dots growing toward its middle and shrinking away from it, and three small colour dots beside the bands.
  Like the other patterns it keeps low down and to the corner, clear of titles and of the numbers on the cards, and it is drawn once into a picture, so it costs no more than they do. With "Both", the glowing orbs are left out: they do not belong to this one. It pairs with the Blob's Vivid colours.

**Checked:** it compiles; in my preview: Home in dark and light, and Train in dark, with Vivid; the automatic test in the preview.
**Not checked:** on a phone, and how it sits behind every page and sheet. Tell me what is too loud or in the way.

## Prism, build 141 (15 November 2026)

**File:** `releases/prism-build-141.apk`

Needs Play Protect paused to install. Can be installed over build 140.

- **The side Blob steps aside while a panel is open in Prism**, from your recording. It is drawn by Android over everything, panels too, so a tap meant for the panel reached it (and it closed the app list behind the panel). Now, while any panel or sheet of Prism's is open, the side Blob is not on the screen, and it is back in its spot when the panel closes. Over other apps nothing changes.
- **The app list's settings panel closes when the app list does**, whichever way the app list closes.
- **The same glass picker for every two-way choice**, as you asked. In the app list's panel: **Icons** (Prism, Regular) and **Layout** (Pages, List) in place of the two switches. In the Blob panel: **Icons** (Prism, Regular) and **Colours** (Mellow, Vivid). "In Prism" and "Over other apps" stay switches: each is on or off of its own.

**Checked:** it compiles, both sides; in my preview: both panels with the new pickers; the automatic test in the preview.
**Not checked:** on a phone. The side Blob stepping aside cannot run in my preview (it only exists on Android).

## Prism, build 140 (15 November 2026)

**File:** `releases/prism-build-140.apk`

Needs Play Protect paused to install. Can be installed over build 139.

- **No black disc behind the triangles**, from your screenshot. In Triangle and Window the triangle is the blob, so nothing is drawn behind it now: not the black of Vivid, not the dark ground of Mellow. Vivid changes only their colours. Lifted from under the glass, they are the triangle alone, as Triangle always was. (The other looks keep their disc: there it is what the blob is.)
- **Triangle no longer has a coloured glow behind it.** It tinted the glass a little, and lifted from under the glass it showed as a pale green disc.
- The same on the floating blob.

**Checked:** it compiles, both sides; in my preview: Triangle mellow and vivid, under the glass and lifted, Window vivid under the glass and lifted; the automatic test in the preview.
**Not checked:** on a phone.

## Prism, build 139 (15 November 2026)

**File:** `releases/prism-build-139.apk`

Needs Play Protect paused to install. Can be installed over build 138.

- **A Vivid switch for every look**, in the Blob panel, above the looks. On: black glass, colours at full strength. Off: mellow, as before. The looks of light (Beam, Bands, Clear, Lined, Halo, Triangle, Window) take the light's own six colours when vivid; the looks of your blobs (Pearls, Petals, Lotus) keep your blobs' colours, at full strength, so they still show your blobs. The previews in the panel follow the switch.
- **Vivid, Vivid Triangle and Vivid Window are gone as looks**: the switch is them now. If one of them was chosen, it becomes the switch on with Clear, Triangle or Window.
- **The magnifying glass is plainly larger than the blob under it.** On Prism's button the blob is now about three fifths of the glass across, on a dark ground of its own (black when vivid), with the glass's light lying over it. Lifted away, the glass leaves the blob alone, the same size, as it was under the glass.
- The floating blob wears the switch too. (It is still all glass: the blob fills it.)

**Checked:** it compiles, both sides; in my preview: Window, Bands and Pearls mellow and vivid on the button, Window with the glass lifted, the panel with the switch and the looks vivid; the automatic test in the preview.
**Not checked:** on a phone, and the floating blob's drawing of it not at all.

## Prism, build 138 (15 November 2026)

**File:** `releases/prism-build-138.apk`

Needs Play Protect paused to install. Can be installed over build 137.

- **Two new looks: Vivid Triangle and Vivid Window.** Triangle and Window on black glass, in the light's own six colours at full strength (the same as Vivid's), not your blobs'. The Look row is thirteen; the longer names take two lines.
- **Only the triangles and Petals turn.** Triangle, Vivid Triangle, Window, Vivid Window and Petals turn on Prism's button as before: a sixth of a turn with the blobs out, half a turn with the app list up. All the others stay pointing up, and as the blobs or the app list open they give a bouncy shot: the sign jumps up a little out of its place, a little larger, and springs back past it once. (A first try at your idea: easy to change.) Choosing a look while something is open takes it up at once.
- **The prism larger and set back**, in Beam, Bands, Clear, Lined and Vivid: half as large again, and further down in the glass, so its two lower corners nearly touch the rim. The white beam into it is shorter, and the colours have more of the glass.
- On the floating blob every look still leans toward where the blobs will come out, as before.

**Checked:** it compiles; in my preview: Beam, Bands, Vivid, Vivid Triangle and Vivid Window on Prism's button, Vivid Window turned with the blobs out (the colours where they were), the Look row with all thirteen; the automatic test in the preview.
**Not checked:** on a phone. The shot is over in a fraction of a second and my preview takes still pictures, so I have not seen it in motion.

## Prism, build 137 (15 November 2026)

**File:** `releases/prism-build-137.apk`

Needs Play Protect paused to install. Can be installed over build 136.

- **Window's colours really stand still now.** In build 135 the field behind the triangle was lit from one point at the foot of the glass and fanned out from there. It did not move, but as the triangle turned, its corners came over different parts of the fan (red at the top left before, red at the bottom left after), and that read as the colours turning with it. Now the field is upright bands, one for each blob, from the left of the glass to the right, with an even light from above. Whichever way the triangle points, its left shows the same colour and its right the same colour.
- **No ring when the glass is lifted.** While the magnifying glass is carried away, the button's place shows the sign alone, as if the glass had been picked up off it, with no circle around it.

**Checked:** it compiles; in my preview: Window at rest, with the blobs out, with the app list up, and with the glass lifted (the colours in the same place in all four); the automatic test in the preview.
**Not checked:** on a phone, and the turn in motion.

## Prism, build 136 (15 November 2026)

**File:** `releases/prism-build-136.apk`

Needs Play Protect paused to install. Can be installed over build 135.

- **The sign becomes the cog, in its own colours.** While the blobs are being changed, the cog used to appear, white, as the sign shrank away. Now, in Triangle and Window, the triangle's own outline reshapes into the cog: its corners draw in and the teeth grow out, the hole opens in the middle, and the colours go once round it. In the other looks the sign draws in and the same colourful cog grows out of its middle. It turns as it comes, as before, and still shows itself off the first three times. With no blobs at all it is the plain white cog.

**Checked:** it compiles; in my preview: the cog in Triangle (also a moment into the change), Pearls and Vivid; the automatic test in the preview.
**Not checked:** on a phone, and the change in motion (my preview takes still pictures). The cog's colours are your blobs', in every look, Vivid included.

## Prism, build 135 (15 November 2026)

**File:** `releases/prism-build-135.apk`

Needs Play Protect paused to install. Can be installed over build 134.

- **A new look: Window.** The same triangle as Triangle, turning the same way, but as a window: the colours behind it stand still, a field of their own that fills the glass and is lit from its foot. The triangle turning shows another part of the same field. (In Triangle, the colours are part of the triangle and turn with it.) The Look row is eleven.

**Checked:** it compiles; in my preview: Window on Prism's button at rest, with the blobs out, and with the app list up: the colours are in the same place in all three.
**Not checked:** on a phone, and the floating blob's drawing of it not at all. One thing you will see, which follows from the idea: a triangle turned a sixth of the way and one turned half way are the same shape, so with the colours standing still, "blobs out" and "app list up" look alike in this look. In Triangle they differ because the colours turn too.

## Prism, build 134 (15 November 2026)

**File:** `releases/prism-build-134.apk`

Needs Play Protect paused to install. Can be installed over build 133.

**The prism is always there**, as you put it.

- **The glass lifts, the prism stays.** While the magnifying glass is carried away from the button, the button's place used to be an empty ring. Now the Blob's sign stays in that ring: only the glass went.
- **The sign turns, and never becomes an X.** With the blobs out it turns a sixth of a turn to the right (for the Triangle, until its top left corner points up). With the app list up it turns half way round. A tap on it still closes what is open, as the X did. With no blobs at all the button shows the plus, which turns into a cross with the blobs out, as before.
- **While the blobs are being changed** the sign still draws in to the cog, and comes back after.
- **A new look: Vivid.** Black glass and the full rainbow at full strength, cut clean, with the white prism and beam. Its six colours are the light's own, not your blobs': the same however many blobs there are. (No white shine on this one: it greyed the black.) The Look row is ten.

**Checked:** it compiles; in my preview: the Triangle on the button at rest, turned with the blobs out, turned half way with the app list up; Vivid and Bands on the button; the automatic test in the preview, 53 of 57, the usual 4 misses.
**Not checked:** on a phone. In my preview I did not see the glass lifted with the sign staying (my preview cannot hold a drag for a picture), nor the turn in motion. On the floating blob Vivid is drawn by Android's own code, which I could not see at all.

## Prism, build 133 (15 November 2026)

**File:** `releases/prism-build-133.apk`

Needs Play Protect paused to install. Can be installed over build 132.

**The side Blob: two ways into the same menu.** As you decided: the floating blob is only ever the Blob itself, it comes back with the next app you open, and "Launch and follow" is gone.

- **The Blob at the side is always the Blob's sign, and a tap opens the same menu Prism's button opens.** With "In Prism" and "Over other apps" both on, it is in the same spot in Prism and over every other app. With one of them off, it is only where the other allows.
- **Sent away, it comes back with the next app you open from Prism, in the spot it was in.** Over other apps you send it away by dropping it on the cross, as before.
- **In Prism you send it away by dropping it on Prism's own button: the two fuse.** No cross is shown there. The Blob is pulled onto the button as it comes near, shrinks into it, and the button takes it in with one small gulp and a thud. It works the same whichever look is chosen.
- **Its spot is kept**, through Android closing Prism and from one day to the next. The very first time it starts tucked into the right side.
- **Nothing of an app's is put in it any more.** A blob dragged out of the menu and let go, or dropped on the button, goes back to its place (in Prism's menu and in the floating one). Before, that made it that app's own floating blob.
- **"Launch and follow" is gone from the Blob panel.** Two switches decide everything.
- **Bands, Clear and Lined have the white shine round the prism that Beam has.**

**What I did not do, on purpose.** The code for putting a blob out to float is still in Prism, switched off at its two entrances, not yet deleted: the flight of the blob to the side, the lens taking it, its return among the others. It is long and tangled with what does still run, and taking it out blind in the same build as this change would have been the riskiest thing I could do. Once you have seen the side Blob work, removing it is its own build.

**The long test** on the phone was changed with it: its part 7 (535 lines of checks on a blob put out to float) is replaced by checks on the side Blob (there in Prism; in the same spot over another app; gone when sent away, in Prism too; back with the next app opened). The battery test's "a blob" is now the side Blob.

**Checked:** it compiles, both sides; the automatic test in my preview, 53 of 57: the usual 4 misses, and 3 checks fewer than before because the removed switch's are gone.
**Not checked:** on a phone, and none of this can run in my preview: the side Blob only exists on Android. It is written from reading the code. Please try, in this order, and send "what just happened" if any of it is off:
1. Open Prism: the Blob is at the side, as the sign. Tap it: the menu opens from there.
2. Open an app from Prism: the Blob is in the same spot. Swipe between apps, open the task manager: still the sign, still there.
3. Go back to Prism: still there, same spot.
4. In Prism, drag it to the button: it fuses. It stays away. Open an app: it is back where it was.
5. Over an app, drop it on the cross: gone. Open another app from Prism: back where it was.
6. Drag a blob out of the menu and let go: it goes back to its place.
7. The timer, during a rest: unchanged, I expect, but it shares this code, so look at it once.

## Prism, build 132 (15 November 2026)

**File:** `releases/prism-build-132.apk`

Needs Play Protect paused to install. Can be installed over build 131.

**The floating blob: one rule in place of guessing.** From your recordings (the WOOX icon in the task manager, and the flash of it on the way home), and a read through all of the code that decides what the blob is, shows, and does on a tap.

- **A blob that came along with an app (Launch and follow) is the Blob sign for as long as it is on the screen, and a tap on it opens the blobs.** Always: over any app, in the task manager, however you change apps, and for the moment it is still there as Prism comes back. Before, it had to know which app was in front to decide between the sign and the app's icon, and Android leaves gaps in that knowledge (a swipe between apps, the task manager, the home gesture). Each gap was one of the bugs you sent. Now it does not need to know, so there is nothing for it to get wrong, and for this blob nothing looks at which app is in front at all: no checks after touches, no cost.
- **It comes up as the sign from its first frame.** There was one more place the app's icon showed for a moment: the blob's arrival drew the app's own blob shrinking into the glass. A blob coming up as the sign now fades in as one piece.
- **In its menu, a tap on the blob itself just closes the menu** (it has nowhere of its own to go).
- **A blob you put down yourself** still works the other way, on purpose: it is the app's icon everywhere and the sign in its own app. For it, the checking is tighter:
  - it tells the task manager (nothing changes while you are in it, so no flicker) from another home screen (no app is in front);
  - after a touch it now looks three times over about three seconds, not once, because opening an app can take longer than the touch that asked for it;
  - going home no longer wipes what it knew before Prism is actually in front.
- The flight recorder now notes what Android says when you go home or open the task manager, and each time Prism learns a different app is in front.

**Two more looks, as you asked:** **Clear** (the bands with nothing between them) and **Lined** (the bands with a very thin white line between them). Bands keeps its dark lines. The Look row is now nine.

**Checked:** it compiles; in my preview: Bands, Clear and Lined on Prism's button; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone. None of the floating blob's behaviour can be run in my preview (it only exists on Android): the changes above come from reading the code and from your recordings and reports, and are not proven until you see them. What I read, and what I did not, is in my message.

## Prism, build 131 (15 November 2026)

**File:** `releases/prism-build-131.apk`

Needs Play Protect paused to install. Can be installed over build 130.

**The light looks, built: Beam, Bands, Halo, Triangle.**

- **Beam**, as you asked: the prism is drawn low in the glass, the white beam into it is short, and the colours have the rest of the glass, wide, out to the edge, melting into one another.
- **Bands**, your concept: the same light through the same prism, cut clean. Each colour is a flat band with a dark line between it and the next, the bands are seen paler through the prism, and the prism is drawn bold. (Ours is its own drawing: in round glass, in your blobs' colours, and it turns. It is not a copy of the album cover.)
- **Halo:** white light in the middle, the rim of the glass split into a piece for each blob, a small white prism in the centre.
- **Triangle:** the prism as large as the glass allows, made of light: white at the corner the light comes in by, the colours fanned across the far side.
- In these four the blobs' colours are put in rainbow order, so they read as light.
- **Rays is gone:** these replace it. The Look row is now seven, on two lines: Pearls, Petals, Lotus, Beam, Bands, Halo, Triangle.
- All seven now fill the glass in the same proportion on Prism's button and on the floating blob (before, the floating blob drew them a little small).

**Easy to take out, as you asked.** Each look is now one drawing and one line in a list, in a file of its own: `lib/fit/blob_sign.dart` for Prism's button and `android/.../BlobLooks.kt` for the floating blob. To remove a look, delete its line and its drawing in each of the two files; nothing else in Prism knows the looks by name, and a phone that had the removed one chosen falls back to the first. The steps are written at the top of both files. Moving them out took 179 lines from the large Android file, and the old fan's drawing is deleted from Prism's side too.

**Checked:** it compiles; in my preview: all seven in the Look row, and Beam, Bands, Halo, Triangle and Pearls on Prism's button; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone, and the floating blob's drawing not at all (it only exists on Android, and it was written a second time there): compare it with the button's. A choice made in build 126 to 130 is not carried over; it starts at Pearls.

## Prism, build 130 (15 November 2026)

**File:** `releases/prism-build-130.apk`

Needs Play Protect paused to install. Can be installed over build 129.

- **A fourth look: Lotus.** The petals that opened from one foot are back, as a lotus: pointed petals in your blobs' colours, the middle one tallest and in front, its neighbours behind, with a soft white glow where they meet. Large: it nearly fills the glass. The colours have the same softening as Petals. It opens the way the blobs do, so on the floating blob it leans as the other looks do.
- The Blob panel's Look row now has four: Pearls, Rays, Petals, Lotus.

**Checked:** it compiles; in my preview: the Lotus on Prism's button and in the Look row.
**Not checked:** on a phone, and the floating blob not at all (it only exists on Android). With one or two blobs the lotus has one or two petals: look at whether that still reads as a lotus to you.

## Prism, build 129 (15 November 2026)

**File:** `releases/prism-build-129.apk`

Needs Play Protect paused to install. Can be installed over build 128.

- **The flight recorder's report ends with your note.** "YOUR NOTE:" is now the last line, and is there even when left empty, so more can be typed after it once pasted.
- **Opening Prism from its own app list no longer makes a blob of Prism.** Your report shows it three times at 01:20 ("follow dev.lumen.prism"). Launch and follow now leaves Prism itself out.

**Checked:** it compiles.
**Not checked:** on a phone.

**What your report (build 127) showed, with nothing changed for it yet:**
- **Both kinds of restart happen.** 01:21:13, after 42 seconds in Claude: "all of Prism started afresh": Android closed Prism entirely. 01:22:27, after 37 seconds away: "Prism's screen made again: Prism itself had kept running": Android took only the screen. No crash either time. Prism was at 867 MB, 572 MB of it graphics. This is the memory problem, and it is the first thing to fix.
- **Frames:** in most stretches 3 to 10 of every 100 frames were late on the S26, the worst usually 20 to 30 ms (one refresh is 8.3 ms at 120 Hz). Steady, not getting worse, but not clean.

## Prism, build 128 (15 November 2026)

**File:** `releases/prism-build-128.apk`

Needs Play Protect paused to install. Can be installed over build 127.

- **The floating blob's icon the wrong way round, from your recording** (Claude's icon in Claude, the sign in Gallery). You change apps by swiping along the foot of the screen, and Android tells Prism nothing of that, so its note of which app is in front went stale and stayed one app behind. Now the blob is told whenever the screen is touched somewhere else (only that it was, not where or what), and a little after the touching stops Prism takes one look at which app is in front. No touch, no look: a phone lying still asks nothing. This needs usage access, which your last report shows Prism has.
- **The Fan is gone.** Three looks are left: Pearls (now where it starts), Rays, Petals.
- **Petals, as you asked:** much larger, nearly filling the glass, as a full flower round the middle; the colours a little softer; the white point always in the very middle, smaller and quieter, with a faint glow.
- Rays is unchanged for now: it is being thought out again from the start.

**Checked:** it compiles; in my preview: the three looks in the Blob panel, the new Petals on Prism's button; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone, and the floating blob not at all (it only exists on Android). The thing to try: swipe between two apps a few times with a blob out, and see that it is the sign in its own app and the app's icon elsewhere, within about a second each time. If it is wrong, "Send what just happened" will now show a line each time Prism looked.

## Prism, build 127 (15 November 2026)

**File:** `releases/prism-build-127.apk`

Needs Play Protect paused to install. Can be installed over build 126.

- **The floating blob no longer changes its icon a moment after it appears, from your recording.** A blob that comes along with an app (Launch and follow) came up wearing the app's icon, and changed to the Blob sign about a second later. For that second Prism was still in front while the app opened, and the blob only counted itself "in its own app" once Prism had left the screen. Now it counts from the first moment, so it comes up as the sign and stays so. (In your recording this is the red of the Notes icon in the tucked blob's edge, gone a second later.)
- **The flight recorder now says why Prism started again.** Your report shows "Prism started" twice (01:14:45 and 01:15:54), each after a short time in another app. The recorder could not say whether all of Prism had been closed, or only its screen had been taken away by Android while Prism kept running. From this build it says which, and notes when the screen is taken down. No crash was recorded either time.

**Checked:** it compiles.
**Not checked:** on a phone, and not in my preview (the floating blob only exists on Android).

**Still open, and it matters:** those two restarts. Prism was at 776 MB when you sent the report, 535 MB of it graphics. The next report from this build will show which kind of restart it is; either way, cutting graphics memory stays the first stability job.

## Prism, build 126 (15 November 2026)

**File:** `releases/prism-build-126.apk`

Needs Play Protect paused to install. Can be installed over build 125.

**The Blob's sign: four looks to choose from, step 1 of 2.**

- **A "Look" row in the Blob panel** (the cog while the blobs are being changed). Four small previews, each drawn as it will really be, in your own blobs' colours: **Fan** (today's stems and dots, still where it starts), **Pearls** (a white point, Prism, with your blobs around it as small lit pearls that throw their colour into the glass), **Rays** (white light into a prism, a ray out in each blob's colour), **Petals** (the colours laid over one another). A tap chooses one, at once.
- **The look is worn in both places:** on Prism's button, and on the floating blob while it is in its own app. Both are drawn from the same numbers.
- **The floating blob's sign moves less, and more slowly.** It no longer points exactly at where the blobs open. It leans that way: at most about 38 degrees at the very top or foot of the screen, hardly at all through the middle, and it drifts round after the blob has moved (about two and a half times slower than build 125). Still drawn only while it turns.
- Each look adapts to 1 to 5 blobs. With no blobs the button shows the plus, as before.

**Step 2, once you have chosen:** for the chosen look, the ring on a blob that has news, the hollow mark for the app you are in, and the pearls (or rays, or petals) becoming the blobs as they open.

**Checked:** it compiles; in my preview: each of the three new looks on Prism's button, the Look row with its four previews and the choice marked; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone. The floating blob's looks I could not see at all (it only exists on Android): they are the same drawing written a second time, so look for any difference between the button's sign and the floating blob's. How the slower turning feels is yours to judge.

## Prism, build 125 (15 November 2026)

**File:** `releases/prism-build-125.apk`

Needs Play Protect paused to install. Can be installed over build 124.

From your recording and the flight recorder (00:45:55, "thinks nothing is in front" while you were in Claude):

- **The floating blob no longer turns back into the app's icon after the recent apps.** Prism keeps a note of which app it opened, to know whether the blob is in its own app. Opening the recent apps (the task manager) wiped that note, on purpose, because from there you can go anywhere. So back in Claude, the blob showed Claude's icon until a tap reminded it. Now the note is kept: most often you come straight back to the same app.
- **Where Prism has usage access, it looks instead of guessing.** After the recent apps it checks which app you landed in (every second and a half, for at most 18 seconds, stopping as soon as it knows), and it checks once more at the moment you tap the blob. So a tap does the right thing even if you changed apps in a way Prism was not told of. Without usage access it keeps the last app it opened.
- **The Blob sign turns smoothly.** As the blob is dragged, the sign follows the direction the blobs will come out in a glide instead of jumping. It is drawn again only while it is still turning; at rest nothing runs.

**Checked:** it compiles.
**Not checked:** on a phone, and not in my preview (the floating blob only exists on Android). You have not given Prism usage access yet (the card on Home says so), so on your phone it will use the kept note. That fixes coming back to the same app. Its known limit without usage access: go from Claude, through the recent apps, into another app, and the Claude blob there shows the Blob sign and a tap opens the blobs, not Claude. With usage access that case is right too. Allowing it on the Home card is worth it for this.

## Prism, build 124 (15 November 2026)

**File:** `releases/prism-build-124.apk`

Needs Play Protect paused to install. Can be installed over build 123.

- **The bottom bar losing its blur around sheets, from your recording.** The cause was in Prism's own code, on purpose: while a quick sheet (Log food, Weigh-in) was up, the bar gave up its real glass for a cheap clear one with no blur, to save work, and took it back only about half a second after the sheet had closed. In that half second, and as the sheet came up, what was behind the bar showed through sharp. Now the bar gives up its glass only while the sheet is all the way up and hides the bar completely, and is glass again the moment the sheet starts down. The swap can no longer be seen.

**Checked:** it compiles; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone, and I did not see it in my preview either. Two things to look for. One: the very start of a sheet closing, where the glass comes back on; if that first moment hitches, say so and the bar will simply keep its glass all the time. Two: whether the bar still goes sharp at other times. There is one more way it can: with glass style on Auto, Prism falls back to cheaper glass when frames run slow, and the cheapest bar is clear, not blurred. If you see it sharp with no sheet involved, use "Send what just happened" right after: the recorder notes which glass was in use.

## Prism, build 123 (15 November 2026)

**File:** `releases/prism-build-123.apk`

Needs Play Protect paused to install. Can be installed over build 122.

- **The density slider no longer disappears, from your two recordings.** While it is dragged, everything else in the panel clears, but the slider itself stays solid, on a small ground of its own, with its name. And a plain tap on the slider just goes to that stop: nothing clears. Only a drag does.
- **The ring in the app list always holds the cog**, on every page and in the scrolling list. The page number is gone (the ring and the letters in the heading say where you are). The one exception: while an app is being chosen for a blob, there are no settings to open, so the page number stays there.
- **The cog turns as you move through the list**, like a gear rolling along it: one tooth for each page (following the finger during the swipe) or each row scrolled. It moves only when the list does.
- Noted for later, in `PRISM.md`: tooltips on every option and switch, with a record of what testers tap and how they set things up.

**Checked:** it compiles; in my preview: the slider held (it stays, the rest clears), a tap on the slider (nothing clears, the stop changes and is saved); the automatic test in the preview: 56 of 60, the usual 4 misses. One run in between missed two blob-dragging checks instead; the run after did not, and that code was not changed, so I take it for my slow preview's timing. Say if dragging blobs to reorder them misbehaves on the phone.
**Not checked:** on a phone. The cog turning I did not see in motion.

## Prism, build 122 (15 November 2026)

**File:** `releases/prism-build-122.apk`

Needs Play Protect paused to install. Can be installed over build 121.

- **Density, in the app list's settings (the cog).** A slider with four stops: 3, 4, 5 or 6 apps across. 4 is where it starts. Rows follow from the height of the screen; tiles and names get smaller as more fit (names shrink less than tiles, to stay readable). It works the same in pages and in the scrolling list. While the slider is held, the panel and its shade fade nearly away (0.16 s) so the list behind is seen changing, with a tick at each stop; let go and the panel comes back. The choice is saved when you let go.
- **The app list closing, from your recording.** Part way down, the icons were dropped and a bare grey slab went on shrinking into the button. Now the icons stay in the panel all the way, and the whole panel dissolves into the button over the last stretch.
- **The cog on the button shows itself off, the first three times you change the blobs.** It comes round a further quarter turn and settles, and one glint runs once round the button's edge. 0.7 s, then nothing moves. From the fourth time on it comes in as before.
- A floating blob in its own app (build 121): the sign is shown exactly when a tap opens the blobs. Both use one check, so they cannot disagree.

**Checked:** it compiles; in my preview: the list at 3, 5 and 6 across, the slider in the panel, the panel see-through while the slider is held; the automatic test in the preview, 56 of 60, the usual 4 misses.
**Not checked:** on a phone. The cog's turn and glint I did not see run (it is over in 0.7 s; my preview takes still pictures). The closing I did not see in motion either. At 6 across with long app names on a narrow phone, names may be cut short: look for that.

## Prism, build 121 (14 November 2026)

**File:** `releases/prism-build-121.apk`

Needs Play Protect paused to install. Can be installed over build 120.

- **A floating blob in its own app shows the Blob sign.** When the app a blob stands for is already open (Bose in Bose, Claude in Claude), a tap on the blob opens the blobs, not the app. It now looks like that: the white stems with a dot in each blob's colour, as on Prism's button, instead of the app's icon. Apps whose icon looked like something else (Bose Connect's is a white plus) no longer confuse. The same goes for a blob of a Prism page while that page shows.
- **It points the way the blobs come out:** into the screen from the side it is on, turned down when it is high and up when it is low.
- It changes as soon as Prism knows you are in that app or have left it.

**Checked:** it compiles.
**Not checked:** on a phone, and not in my preview (the floating blob only exists on Android). The direction is worked out roughly the way the menu lays the blobs out, so it may be a few degrees off from where they actually land. If Prism wrongly thinks you are in the app (you left it from the recent apps another way), the blob shows the sign, and a tap opens the blobs: the same as the tap already did.

## Prism, build 120 (14 November 2026)

**File:** `releases/prism-build-120.apk`

Needs Play Protect paused to install. Can be installed over build 119.

- **The app list opens faster.** It used a bouncy spring that overshot by about 5% and took about a third of a second. It now uses a stiffer one: about 1% overshoot, settled in roughly half the time. Closing is unchanged.
- **Every bottom panel moves the same way.** Before: Weigh-in (and the other quick sheets) slid up quickly; the Apps panel faded in place; the Blob panel faded with a small rise; Prism's settings slid up from the very bottom of the screen. Now the Apps, Blob and settings panels all slide up by their own height in 0.26 s, like Weigh-in. Weigh-in itself is unchanged.
- **The ring at the top of the app list is always accurate.** In the scrolling list it now follows the list exactly as you scroll: how much of the list you have seen. Switching between paged and scrolling re-aims it.
- **The cog and the page number in the ring cross-fade** with a slight scale (0.18 s), instead of snapping. Only the small ring is redrawn.
- **Less text.** The explanations under the Apps and Blob panel switches are gone. In Prism's settings, the "prototype" line is gone, and "Glass style" lost its long explanation.

**Checked:** it compiles; in my preview (screenshots of the app list ring while scrolled, the Apps panel); the automatic test in the preview: 56 of 60 right, the 4 misses are the usual ones (3 need Android, 1 is a preview timing artefact).
**Not checked:** on a phone. How the new opening speed feels is yours to judge.

## Prism, build 119 (14 November 2026)

**File:** `releases/prism-build-119.apk`

Needs Play Protect paused to install. Can be installed over build 118.

From your recording of the scrolling app list:
- **No more names without icons at the top.** Where the list stopped part way through a row, the top showed a strip of names with their icons cut away. Going to a letter now lands exactly on its row (build 118 left a slice of the row before, which made this more likely), and the fade at the top is deeper, so a part of a row dissolves instead of showing bare names. The bubble and the letter in the heading say where you are.
- **No scrollbar.** A grey scrollbar ran down the right edge, over the letters. Gone: the letters are the scrollbar.
- **A deeper fade at the foot** too.

**Checked:** it compiles; in my preview.
**Not checked:** on a phone.

## Prism, build 118 (14 November 2026)

**File:** `releases/prism-build-118.apk`

Needs Play Protect paused to install. Can be installed over build 117.

**The scrolling app list, made for everyday use.** From the practice of the best launchers and the phones' own lists:
- **The letter beside the thumb.** While a finger is on the letters, the letter under it shows large in a round bubble just to its left, where the thumb does not cover it, in Prism's colour.
- **A wave on the letters.** The letters near the finger swell and lean out toward it, so a thumb can pick one out on a narrow strip; the one under it is in Prism's colour.
- **The letter in the heading.** While the list is scrolled by hand, the heading says which letter is at the top.
- **Where it lands.** Going to a letter leaves a little of the row before it in sight, so where you are in the alphabet stays clear. The first app of the letter still jumps once, with a tick for each new letter.
- **Soft edges.** Rows fade in at the top of the list and out at its foot instead of being cut off.
- **The finger is taken a little wider** than the letters are drawn, so they are easier to hit.

**What it costs:** while a finger is on the letters only the letters and the bubble are redrawn; the list is moved, not rebuilt. The edges are plain shades, not blur.

**Checked:** it compiles; in my preview, a slide down the letters with the bubble, the wave and the jump, and the heading's letter after.
**Not checked:** on a phone.

## Prism, build 117 (14 November 2026)

**File:** `releases/prism-build-117.apk`

Needs Play Protect paused to install. Can be installed over build 116.

**What the flight recorder found** (your report from build 113):
- **Why the magnifying glass was stuck:** holding the button starts the changing of the blobs; the finger then moved, and the glass came out; on letting go, Prism saw "this was the hold that started the changing" and did nothing more. Now a hold that has started the changing never brings the glass out, and if it were ever out on letting go, it goes home. (Build 114's guard already caught it; this removes the cause.)
- **Android closed Prism twice in thirteen minutes** while you were in other apps: "Prism started" at 22:04 and again at 22:09, two minutes after you opened Claude.
- **Very likely why:** Prism held 943 MB, and 596 MB of it was graphics memory: what the graphics chip holds for the glass and the background. That is the next thing to bring down.

**The glass settings test now also measures:**
- **The apps' own icons** (setting K): the same movements with the app list and the blobs showing the apps' own icons, beside Prism's.
- **Memory under every setting:** a second table, for each setting, of Prism's memory in all, what the graphics chip holds, the engine's own, and Prism's own pictures. This shows which of the glass effects holds the most memory, so it can be brought down where it costs least to the look.
- About 20 minutes now.

**Checked:** it compiles; in my preview the long test.
**Not checked:** on a phone.

## Prism, build 116 (14 November 2026)

**File:** `releases/prism-build-116.apk`

Needs Play Protect paused to install. Can be installed over build 115.

**The app list as a scrolling list.** Behind the app list's cog, a new switch: "Scrolling list". On, the pages give way to one list of every app that scrolls, with the letters down its right side.
- **The letters:** a tap on one, or a finger sliding along them, takes the list to that letter at once. The letter under the finger lights in Prism's colour, and the first app of that letter (the one whose first letter is coloured) jumps, once. A small tick with each new letter.
- **Taps** open apps, and choose them for a blob, as on the pages.
- **What it costs:** rows are made only as they scroll into view, and each is drawn as one picture, as the pages are. The cog stays in the ring while the list scrolls.
- Off, the pages are as they were. The choice is kept.

**Checked:** it compiles; in my preview, the list, a tap on S, and a slide down the letters with Bank jumping at B and the list following to M.
**Not checked:** on a phone; the jump at full speed.

## Prism, build 115 (14 November 2026)

**File:** `releases/prism-build-115.apk`

Needs Play Protect paused to install. Can be installed over build 114.

- **A two-finger swipe moves nothing but itself.** One finger always lands a moment before the other, and in that moment it began to scroll the page, so Home was pulled down as the notifications came. Prism now notes where every page's list is when a finger comes down; when a second lands and it is a two-finger swipe, each list is put back exactly where it was, at once.
- **With Android's buttons at the foot of the screen**, the page no longer shows through, clear, below the bar and behind the buttons. The same shade that lets content fade under the clock at the top now does the same at the foot, deep enough to reach under the buttons. It is a plain shade, not a blur: it costs nothing.

**Checked:** it compiles; in my preview the long test.
**Not checked:** on a phone, with buttons or without.

## Prism, build 114 (14 November 2026)

**File:** `releases/prism-build-114.apk`

Needs Play Protect paused to install. Can be installed over build 113.

- **Fixed: the magnifying glass could be left out, stuck.** In your recording it stayed over "Today's list", with its explanation up, while you scrolled, opened the blobs and the app list. Prism now counts every finger on the screen: a quarter of a second after the last one leaves, the glass is either put down on something with things to do, or it goes home, and no card is left lit up. If that ever has to step in, the flight recorder notes it, so we learn what led there.
- **Colour strength: Soft, Balanced, Vivid.** Under the colours in Prism's settings. It changes how strong every colour is, the accent and the background lights alike. **Balanced is now the starting point**, a step calmer than before; Vivid is how Prism was until now.
- **Prism icons, set separately.** The app list's choice is behind its cog; the blobs' choice is in the Blob panel. Both start with Prism's icons.
- **The glass settings test.** A new button, "Run the glass settings test (about 15 min)". The same movements (switching tabs, scrolling, the blobs, the app list, the magnifying glass over the cards) under each of ten settings, each changed on its own from a starting point: glass quality Medium and Low; glass style One at a time, Frosted and Event; background lights off; the Pattern background; reduce transparency; and all of the cheapest together. Twice over. The report ends with a table: for each, frames a second, the share late, how long drawing a frame takes (mostly the graphics chip's work) and the slowest one in twenty, laying it out, and Prism's share of the processor, each beside the starting point. Your own settings are put back afterwards.

**Checked:** it compiles.
**Not checked:** on a phone; the colours by eye; the glass test's table, which was still being made in my slow preview.

## Prism, build 113 (14 November 2026)

**File:** `releases/prism-build-113.apk`

Needs Play Protect paused to install. Can be installed over build 112.

- **"Prism icons" is in the Blob panel too**, under "Launch and follow". It is the same switch as behind the cog in the app list: one choice, shown in both places.
- **It now covers the blobs.** Off, a blob holding an app shows the app's own icon, filling the circle, among Prism's blobs and as the floating chat head. Blobs that are Prism's own actions and pages keep their look.

**What it costs:** nothing more than before: the same icons the app list already fetched, shown in a few more places.

**Checked:** it compiles; in my preview the switch is in the panel.
**Not checked:** on a phone, where the apps' own icons are.

## Prism, build 112 (14 November 2026)

**File:** `releases/prism-build-112.apk`

Needs Play Protect paused to install. Can be installed over build 111.

**The flight recorder.** Prism now quietly keeps the last few hundred things that happened, on its own side and on Android's:
- what was done (pages, the blobs, the app list, the glass, the swipes, sheets, the workout);
- the floating blob and timer: shown, taken away, tapped and what it decided, apps opened and which way, the menu, tucked, dropped on the cross, the timer paused, counting up, closed, launch and follow;
- slow frames: how many, the worst, and what was on the screen;
- Prism in front and out of sight, Android asking for memory back, errors in the code, a crash, and Prism being started again (so a close by Android shows).

**"Send what just happened"**, at the top of the test tools in Prism's settings: an optional "What happened?" and Copy. What is copied: your note, the build, the phone, every setting, the memory and battery now, and everything noted in the last 15 minutes, in time order. Paste it here, with a video or without.

**What it costs:** a line in memory for each thing; it is written to a file only when Prism leaves the screen, or crashes. Slow frames are found in the frame times Flutter hands over anyway, only while something is drawn. Idle, it does nothing. Nothing leaves the phone unless you copy it.

**Checked:** both sides compile; in my preview, a copied report.
**Not checked:** on a phone.

## Prism, build 111 (14 November 2026)

**File:** `releases/prism-build-111.apk`

Needs Play Protect paused to install. Can be installed over build 110. Asks for one new permission, which you give on Android's own screen: usage access.

**Screen time on Home.** A card at the bottom of Home: how long the screen was in use today, how many times the phone was unlocked, and the three apps used longest, each with a bar.
- **Until usage access is given** the card says so, with a button that opens Android's screen for it. Back in Prism, the card fills in.
- **How it is worked out:** from Android's own record of which app was in front when, since midnight. The time with the screen off is not counted; Prism itself (the home screen) is left out.
- **What it costs:** it is read when Home comes on screen, at most once a minute, off the main thread. Nothing runs in the background and nothing is kept.
- The magnifying glass explains it like any other card.

**Checked:** both sides compile; in my preview the card shows made-up figures.
**Not checked:** on a phone, or how close its figures are to Samsung's Digital Wellbeing (they are worked out the same way, and may differ by a few minutes). Whether Google Play asks for a declaration for usage access: not yet looked up properly.

## Prism, build 110 (14 November 2026)

**File:** `releases/prism-build-110.apk`

Needs Play Protect paused to install. Can be installed over build 109.

- **A cog in the app list.** On the first page, the ring at the top right shows a cog instead of "1". A tap on it opens the app list's own settings. On the other pages it is the page number, as before. (Not while choosing what goes in a blob.)
- **"Prism icons", on or off.** On: every app in Prism's look, as until now. Off: every app with its own icon, as the phone has it, in the same tile shape. Only one of the two is held at a time: the apps' own icons are fetched the first time (a second or two), kept on disk after that, and let go again when Prism's are chosen. The choice is kept.
- The blobs keep Prism's look either way.

**Checked:** it compiles; in my preview the cog shows on the first page.
**Not checked:** on a phone, where the apps' own icons are fetched.

## Prism, build 109 (14 November 2026)

**File:** `releases/prism-build-109.apk`

Needs Play Protect paused to install. Can be installed over build 108.

**Stability first.** A home screen has to be there all day. The first steps:

- **Prism gives memory back.** When Android says memory is short, and whenever Prism has been out of sight for two minutes, it lets go of every picture it can make again (cached pictures, and the pictures it prepared for the chat head). Android closes the apps that hold most when memory is short; this makes Prism one of the last.
- **Where the memory goes, round by round.** The round-by-round table now splits Prism's memory into what the graphics chip holds for it, the engine's own, Java's, the code, the rest, and how much of it is pictures Prism made (the apps' icons and the cache). This is to find what made it grow from 777 to 921 MB across your runs, instead of guessing.
- **The floating blob opens its app from Prism's own screen when Prism is in front.** In every phone run, a tap on the floating blob holding an app reached it and it tried to open the app, and the app did not come. Android allows an app to be opened from Prism's own screen without question; from a floating window it can refuse without saying so. Over another app it still opens from the floating window. The report now says which way it was opened, or why it could not be.

**Checked:** both sides compile; in my preview the long test, and the round-by-round table with the new columns.
**Not checked:** on a phone. Whether giving memory back lowers the figure, and whether the app now opens from the blob, are for the next run to show.

## Prism, build 108 (14 November 2026)

**File:** `releases/prism-build-108.apk`

Needs Play Protect paused to install. Can be installed over build 107.

**The 2½-hour stability test.** A new button: "Run the 2½-hour stability test (silent)". The long test fifteen times over, then the still stretches at two minutes each. Silent, like the hour-long one. What it is for: whether smoothness, memory and heat hold up over a long session. It uses roughly a third of a battery, with the screen on throughout; start it full.

**In every report:**
- **Frames a second while things moved**, beside what the screen can do (120 on both your phones). Pauses between movements are left out, so it is the rate of the movement itself.
- **Round by round** (when there is more than one round): for each round, minutes in, frames, frames a second, the share late, the slowest frame, Prism's memory, the battery and the phone's temperature. If anything drifts as time goes on, it shows there.

**Checked:** it compiles; in my preview a two-round run writes the round-by-round table.
**Not checked:** on a phone.

## Prism, build 107 (14 November 2026)

**File:** `releases/prism-build-107.apk`

Needs Play Protect paused to install. Can be installed over build 106.

**Reports that set two phones side by side.**
- **Which phone:** the top of every report now names the phone, its chip, its Android, its refresh rate, its memory, and about how much its battery holds when full (worked out from the battery's own count).
- **A summary:** just under that, a few numbers for the whole run: of all the frames Prism made while things moved, how many were late and how many took longer than a refresh; how long a frame's work usually took, and the slowest one in twenty, in a hundred, and the slowest of all; the same for the floating lens; and Prism's share of the processor at rest with nothing floating.

The tests themselves are as they were. Run the hour-long test on each phone with the same brightness, unplugged, to compare them.

**Checked:** it compiles; in my preview the summary is written.
**Not checked:** on a phone.

## Prism, build 106 (14 November 2026)

**File:** `releases/prism-build-106.apk`

Needs Play Protect paused to install. Can be installed over build 105.

- **The battery test begins with a blob on the screen.** It began with "nothing floating", the reference with no chat head on purpose, so for the first two and a half minutes there was nothing to see over the other app, and it looked as if the test was not working. Each round now goes: a blob, the timer, both, nothing. The line at the top says "nothing floating, on purpose" for those steps (it is seen only when Prism is in front).

**Checked:** it compiles.
**Not checked:** on a phone.

## Prism, build 105 (14 November 2026)

**File:** `releases/prism-build-105.apk`

Needs Play Protect paused to install. Can be installed over build 104: your settings stay.

**The tests set themselves up.** At the start every test now checks the settings and sets right whatever would spoil a reading, and puts everything back at the end:
- the frame-rate readout off (it draws all the time);
- glass style and glass quality to Auto;
- the blob allowed in Prism and over other apps;
- "Launch and follow" off.

What it changed is written at the top of the report under "SET FOR THE TEST", below your own settings.

**And checks what it cannot set:**
- *Not allowed over other apps:* Android's screen for it is opened, and the report says so. The battery test stops there, since it has nothing to measure.
- *Charging:* the test says so for four seconds, and the report says in capitals that the current readings mean nothing.

**Checked:** it compiles; in my preview the long test sets and puts back the frame-rate readout.
**Not checked:** on a phone.

## Prism, build 104 (14 November 2026)

**File:** `releases/prism-build-104.apk`

Needs Play Protect paused to install. Can be installed over build 103: your settings stay.

- **Every test report begins with your settings** as they were when the test began: colour, background, theme, the frame-rate readout, haptics, reduce transparency, background lights, glass style (and, on Auto, which it had settled on), glass quality, the four switches below them, the blob's three switches, labels, what was floating, the five blobs and the four swipes.
- **"Launch and follow" is put back as you had it** after a test. Until now the long test left it off, whatever it had been.
- **The battery test switches "Launch and follow" off while it measures** and puts it back afterwards, so nothing floats that the test did not put there.

**Checked:** it compiles; in my preview the long test's report begins with the settings.
**Not checked:** on a phone.

## Prism, build 103 (14 November 2026)

**File:** `releases/prism-build-103.apk`

Needs Play Protect paused to install.

- **Fixed: the tests still used Settings as "another app".** Prism reads the list of the phone's apps only when the app list is first opened, and the test looked for Calculator, Clock or Chrome before that, found none, and fell back to Settings, which hides the chat head. The test now reads the list first. If it still finds none of them, the note says how many apps it did see.

**Checked:** it compiles; in my preview the Prism half of the long test.
**Not checked:** on a phone.

## Prism, build 102 (14 November 2026)

**File:** `releases/prism-build-102.apk`

Needs Play Protect paused to install.

**Why the blob was never seen over another app in the tests.** The tests used Android's own Settings as "another app", and Settings hides every floating window of every other app, so that nothing can cover its switches. The blob was there, and hidden. So the earlier readings of "a blob floating, Settings in front" measured a blob that was not on the screen, and the steps with "the lens holding an app" were done over Settings too. The tests now use an ordinary app that is on the phone: Calculator, Clock or Chrome, the first of those found. The report says which.

**The chat-head battery test.** A new button in the test tools: "Run the chat-head battery test (about 35 min)". With that app in front it measures four states: nothing floating, a blob, the timer, and a blob and the timer together. Each is measured three times for two and a half minutes, the four taken in turn, so that the battery's own drift falls on all alike. The report sums it up in one table: the phone's current for each, the difference from nothing floating with how sure that difference is, Prism's share of the processor, how often the floating things were drawn, and whether Android had them on the screen. The timer is measured with a rest running, its busiest.

- The four pairs added to the long test in build 101 move here; the long test is back to about 20 minutes.

**Checked:** it compiles; in my preview the long test's Prism half. The battery test cannot run in my preview (nothing can float there).
**Not checked:** on a phone. Whether Android reports a window hidden by Settings as hidden: I believe so and have not seen it.

## Prism, build 101 (14 November 2026)

**File:** `releases/prism-build-101.apk`

Needs Play Protect paused to install. **The build for the second test run.**

After the first full run on a phone (build 100: 121 of 129 right):

- **The note field is no longer behind the keyboard.** The report panel rises above it while you type.
- **What a blob left floating costs, measured properly.** Four times, Settings in front for 90 seconds with nothing floating, then 90 seconds with a blob floating, one after the other, so the battery's own drift falls on both alike. About 12 minutes more.
- **The lens says what it was touched with.** Six of the eight wrong checks were the lens holding an app: three taps on it drew nothing and a hold had no answer. The report now gives, for each, where the touch came down, where the lens was, whether it was tucked, roaming or not yet shown, and what it then did (opened its app, opened its menu, or tried to and could not). That tells a fault in the lens from a fault in the test.
- **The test taps the timer's controls in their own place.** The tap on pause did nothing; it was very likely aimed by the window's place on the screen, which Android can shift.
- **"At the height it was put down"** allows 10 where it allowed 6 (it was 6 off: not to be seen).

**Checked:** it compiles; in my preview the Prism half of the test.
**Not checked:** on a phone.
**Still to look into:** Prism was using 777 MB of memory four minutes in. That is a lot, and Android closes apps that use a lot when they are out of sight.

## Prism, build 100 (14 November 2026)

**File:** `releases/prism-build-100.apk`

Needs Play Protect paused to install. **This is the build to test.**

- **A Stop button while a test runs.** Red, at the top left, under the line that says what the test is doing. A tap stops the test where it is: the step it was on finishes its touch (no finger is left down), everything is put back as it was, and the report comes up with what it had found so far, headed "STOPPED BY YOU while it was at:" and the step. Only a real finger presses it; the test's own touches pass it by.
- **A note of your own.** The report panel, finished or stopped, has a field "What did you see?". What you write goes at the end of the report, as "NOTE FROM YOU", in what Copy copies and in "Copy the last report" afterwards.
- **The test no longer pulls the notifications down.** Android let Prism pull them down but not put them away again, so on your phone they stayed open over the rest of the test. Whether the two-finger swipe down opens them is for you to see.
- (A first upload of this build, at commit 035327b, was made by mistake from an unfinished change and still called itself build 99. This one replaces it.)

**Checked:** in my preview: the test started, Stop pressed part way; it stopped, put everything back and showed the report, stopped, with the note field and the step it was on. It compiles.
**Not checked:** on a phone.

## Prism, build 99 (14 November 2026)

**File:** `releases/prism-build-99.apk`

Needs Play Protect paused to install. **This is the build to test.**

**Tidied**
- The spring that moved the rest bar, which is gone, was still being run each time a rest began or ended. Removed.
- The three things Android's compiler pointed at in Prism's own code are put right. It now compiles with none.
- Nothing else was found left over: Prism's side has no unused code by its own checker.

**The flick, again**
- A slow flick up could still wake the magnifying glass. A finger still on its way up, even slowly, is now given a little longer (to a fifth of a second) before it is taken for a carry; one that has stopped is a carry at once, as before.

**The tests now also check**
- *Prism's side:* the button's sign is the cog while the blobs are being changed and not otherwise; one empty place stands in the middle; a flick for the app list wakes neither the glass nor a card at any moment.
- *On a phone only:* whether this phone lets the notifications be pulled down (they are put away again at once).
- *Launch and follow:* an app opened from Prism brings its blob along as a guest, tucked; Prism's own floating blob is untouched; back in Prism the guest is gone.
- *Two floating things:* a blob and the timer on the screen at once, each its own.
- *The blob's size:* asked to be very large, it is a tenth over at most.
- *The timer's places:* dropped on pause it stands and is back where it was picked up; dropped there again it goes on; dropped on count up it counts up and is still there.
- *The timer's controls:* made large it has them under it; a tap on pause and it stands, again and it goes on; made small they are gone.
- *The cross:* the timer is closed and stopped; a new rest brings it back; the buzz still comes.

**Checked:** it compiles with no warnings of Prism's own. In my preview the Prism half ran: 54 or 55 of 59. Three cannot be right there (power). The check on the flick is wrong there and I measured why: my preview draws nothing for a tenth of a second in the middle of the robot's flick, so Prism sees a finger that has stopped. On a phone the finger is reported every 8 ms. "A slower flick" was wrong in one run of three for the same reason, as it has been before.
**Not checked:** on a phone, anything. Every new check on Android's side has never run; some will be wrong because the check is, not Prism.

## Prism, build 98 (14 November 2026)

**File:** `releases/prism-build-98.apk`

Needs Play Protect paused to install.

- **A floating blob can no longer be made large.** Stretched with two fingers it gives about a tenth and stops there, with the click that says it will go no further. One that was left large by an earlier build comes back to that size the next time it appears. This is what the two recordings showed: with a finger on the floating blob and another moving a blob in the menu, the two fingers were read as a stretch, the blob grew to fill the screen, and stayed that size for every blob put down afterwards.
- **The timer can still be made as large as the screen.**

**Checked:** it compiles.
**Not checked:** on a phone. The stretch itself is still read from two fingers of which one may be elsewhere on the menu; it now gives a tenth at most, but I have not stopped it being read.

## Prism, build 97 (14 November 2026)

**File:** `releases/prism-build-97.apk`

Needs Play Protect paused to install.

**The timer's own places to be dropped on, and its own controls.**

- **Picked up small, the timer has three places at the foot of the screen:** pause on the left, the cross in the middle, and a stopwatch with an arrow up on the right. It is pulled onto whichever it is nearest, and that one lights up.
  - **The cross stops the timer and takes it off the screen.** Nothing goes on running behind. (It used to hide it for that workout while the rest went on.) To keep it running out of the way, push it into a side instead. A new rest, or "Timer" from the blobs, brings it back.
  - **Pause:** the timer stands, and flies back to where it was picked up from. Dropped there again, it goes on; the sign is then the one for going on.
  - **Count up:** it counts up from nothing, and flies back to where it was picked up from.
- **Large, the timer carries the same three under it,** in the same order: pause, the cross, count up. They are there while it lies still and go the moment it is touched. Where there is no room under it they sit over it. A tap does what dropping it there would.
- **Large, only the cross is at the foot,** as large and as easy to hit as it was.
- "Large" is from a little over twice its smallest size. Resize it past that and the controls come; back under it and the three places return.
- The blob's cross is as it was.

**Also**
- The button's sign: the X no longer begins to unfold before the fan has finished folding, so the two are never seen on top of one another.

**Checked:** it compiles; the Prism half of the long test in my preview.
**Not checked:** on a phone, any of it. All of this is on Android's side and has never run. The signs for pause and count up are drawn by hand and I have not seen them.

## Prism, build 96 (14 November 2026)

**File:** `releases/prism-build-96.apk`

Needs Play Protect paused to install.

- **The button's sign is one drawing that changes shape.** It used to be three pictures faded into one another. Now, as the blobs come out, the fan folds into its own foot: the stems shorten, the dots shrink and pale to white, and the foot rises to the middle of the button. Out of that point the X unfolds, turning as it comes, and swings a hair past its size before it settles. Closing, the same in reverse. While the blobs are being changed the X turns on and shrinks away as the cog turns in. It rides on the same springs as the blobs, so it follows them exactly and can be turned back half way.
- **Fixed: a quick swipe up for the app list woke the magnifying glass for a moment.** A card lit up with its explanation for a frame before the app list came. The glass is no longer given to a finger that is, at that very moment, going upward fast: that is a flick. A carry upward is slower and gets the glass as before; a fast one gets it the moment it slows; and nothing is held back beyond a quarter of a second. Going sideways or down is unchanged.
- **The drop that flies home is dark glass, not a yellow blob.** It is drawn in the button's own dark tone, lit from above, with a bright line round its upper edge: two fills and a line, nothing that costs. Let go as a pill, it still starts from the pill's colour.

**Checked:** in my preview: the long test's dry run, with every check on the glass and the app list right, the flick among them; the sign looked at as the fan, the X and the cog.
**Not checked:** on a phone. The sign in motion: my preview is too slow to show the in-between frames. The flying drop: I did not catch it in a picture.

## Prism, build 95 (14 November 2026)

**File:** `releases/prism-build-95.apk`

Needs Play Protect paused to install.

**The timer is a floating thing of its own.** There are now two: the blob, and the timer. Both can be on the screen at once.

- **The blob is only ever a blob.** A workout starting no longer takes it over, and a rest ending no longer hands it back.
- **The timer is only ever the timer.** It appears when a rest or a workout is on and goes when it is over. A tap opens its sheet. It has no menu.
- **They are the same code, used twice,** so they behave alike in every way: dragged, thrown, resting at a side, pushed into a side, pulled out, resized, dropped on the cross, and every buzz. Each has its own place, its own size and its own cross.
- **The timer starts lower down the side than the blob,** so they are not on top of one another. Nothing yet keeps them apart if you put one on the other yourself.
- Dropped on the cross, the timer is closed for that workout only; the rest goes on, and its buzz still comes. Going to the workout page brings it back.
- The blob's own menu still opens the workout's sheet from "Workout".
- **Either one arrives with a short bounce:** a little small, just past its size, and back, in under a fifth of a second. It can be touched from the first moment. A blob being put down from Prism does not bounce: it has to be exactly where the blob was.
- **The tests** ask the timer what they used to ask the one lens while a rest was running.

**Checked:** it compiles. In my preview, the Prism half of the long test.
**Not checked:** on a phone, any of it. This is the largest change to Android's side so far and none of it has run. It was done by making the whole floating part twice over, not by rewriting it, which is why I think it is likelier to work than not; but expect faults, and tell me what you see.

## Prism, build 94 (14 November 2026)

**File:** `releases/prism-build-94.apk`

Needs Play Protect paused to install.

- **Fixed: the magnifying glass, flying home, showed the old plus for a moment.** The drop that flies back drew a plus as it landed. It now draws the button's own sign, the one it is about to become. Nothing else in Prism still draws the old plus (the plus in an empty place and the "add" button on the food sheet are meant).
- **The rest bar is gone from the workout page.** The rest is timed by the floating timer alone.
- **"Timer" starts a timer.** Its sheet's button used only to close the sheet. It now starts a rest of that length, counted by the floating timer.
- **The battery reading every ten seconds is gone.** It was a leftover from development that woke the phone for as long as Prism was on screen. One reading is taken when Prism comes on screen.

**Checked:** in my preview, the long test's dry run.
**Not checked:** on a phone. Without the bar, a rest can only be seen and changed on the floating timer: with floating switched off in both places there is nothing to see it by.
**Still to come from the list:** the timer as a floating thing of its own beside the blob, and the short bounce as either appears.

## Prism, build 93 (14 November 2026)

**File:** `releases/prism-build-93.apk`

Needs Play Protect paused to install.

- **The button's sign, tidied.** No dot at the foot: the white stems now meet in a point. The stems are slimmer. With fewer blobs the stems open wider and the dots are larger, so two blobs are an open V with two large dots, not a thin bunch, and one blob is a single large dot on a short stem. The order and the colours are still the menu's; the spread is the sign's own.

**Checked:** looked at in my preview with five, four, three, two and one blob.
**Not checked:** on a phone, with real app colours.

## Prism, build 92 (14 November 2026)

**File:** `releases/prism-build-92.apk`

Needs Play Protect paused to install.

- **"Launch and follow"**, a third switch in the Blob panel, off as Prism starts. With it on, an app opened from Prism (from a blob, the app list, a two-finger swipe, or the chat head's own menu) brings its blob along as the chat head, tucked at the side it was last at.
- **It is a guest, a sixth blob.** It need not be one of the five, and the five are never changed by it. Whatever was floating before (or nothing) is kept aside and is back as soon as Prism is in front again. Open another blob from its menu and that app's blob takes its place.
- **Dropped on the cross, nothing floats.** Dragged into it from the menu by hand, a blob is yours and no longer a guest.
- Switching it on switches "Over other apps" on; switching that off switches it off. Only apps are followed, not Prism's own pages or actions.
- **Which build this is** is now written in Prism's settings, beside "Testing".

**Checked:** it compiles on both sides. In my preview the switch is in the panel and goes on and off; the long test's dry run.
**Not checked:** on a phone, and none of the following itself: it is all on Android's side and has never run. Expect faults.

## Prism, build 91 (14 November 2026)

**File:** `releases/prism-build-91.apk`

Needs Play Protect paused to install.

- **The panel behind the cog has a round X in its corner** that closes it. A tap outside it, and back, still close it too.
- **The panel is called "Blob"**, where it said "Floating elements".

**Checked:** looked at in my preview; the long test's dry run, which now closes the panel by its X.
**Not checked:** on a phone.

## Prism, build 90 (14 November 2026)

**File:** `releases/prism-build-90.apk`

Needs Play Protect paused to install.

- **The button's sign is a small picture of the menu it opens.** One stem for each blob that would come out, all from one point at the foot. Each stem is a hair at the foot and thickens on the way up, and ends in a round dot of that blob's colour, standing where that blob will stand. Take a blob away, put one down as the chat head, change one or move one, and the sign changes with it. With three or fewer the dots are larger. With none, it is a plus.
- Dots, not arrowheads: they are the blobs in small, and five of them stay clear of one another where five arrowheads did not.

**Checked:** looked at in my preview with five, four and three blobs, dark and light.
**Not checked:** on a phone. Real app colours: two neighbouring apps of a similar colour will give two similar dots.

## Prism, build 89 (14 November 2026)

**File:** `releases/prism-build-89.apk`

Needs Play Protect paused to install.

- **The fan of arrows is drawn in Prism's own weight.** Its lines are as heavy and as round-ended as the X it turns into and the signs on the tabs, and the side arrows lean out low and wide, the way the blobs themselves spread from the button. In build 88 it was a thin line drawing that did not sit with the rest.

**Checked:** looked at in my preview beside the tabs and the X.
**Not checked:** on a phone.

## Prism, build 88 (14 November 2026)

**File:** `releases/prism-build-88.apk`

Needs Play Protect paused to install.

- **The button's sign is a fan of three arrows, not a plus.** One arrow straight up, one bending out to each side, from one point: what the button does. It is drawn by Prism in its own line, not taken from a picture. With the blobs or the app list out it is the X; while the blobs are being changed it is the cog. The three change into one another with a short fade and swell; the plus used to turn into the X.

**Checked:** looked at in my preview, closed and open; the long test's dry run.
**Not checked:** on a phone; how the change between the three signs looks in motion.

## Prism, build 87 (14 November 2026)

**File:** `releases/prism-build-87.apk`

Needs Play Protect paused to install.

- **While the blobs are being changed, the X in the button becomes a cog.** The separate cog above the button is gone. A tap on the button then opens the floating elements' panel. The changing is ended by a tap beside the blobs, or by back; the button no longer ends it, since it no longer shows an X.
- Holding the button while the blobs are out still starts the changing.

**Checked:** in my preview: looked at; the long test's dry run.
**Not checked:** on a phone.

## Prism, build 86 (14 November 2026)

**File:** `releases/prism-build-86.apk`

Needs Play Protect paused to install.

- **The empty places are always centred.** The first blob taken away goes to the middle of the screen. The next joins it and the two stand centred side by side, the first sliding over to make room; and so on up to five. When one is given something and goes back down, the rest close up around the middle. They used to keep fixed spots, so one alone could stand off to a side.

**Checked:** looked at in my preview with one, two and three taken away.
**Not checked:** on a phone; how the slide looks in motion.

## Prism, build 85 (14 November 2026)

**File:** `releases/prism-build-85.apk`

Needs Play Protect paused to install.

- **An empty place has a plus in it, and no pencil.** The plus is the same white as the ring. This is so for an empty blob out in the middle and for a swipe that does nothing. A tap on it still asks what to put there.

**Checked:** looked at in my preview.
**Not checked:** on a phone.

## Prism, build 84 (14 November 2026)

**File:** `releases/prism-build-84.apk`

Needs Play Protect paused to install. One new permission, granted without asking: "expand status bar", for pulling the notifications down.

**Two-finger swipes.** Anywhere in Prism with nothing open, two fingers moved together do what that swipe has been given.

- **As Prism starts:** down pulls the notifications down; up opens the scanner; left and right do nothing.
- **Set up where the blobs are changed.** Hold a blob or the X: across the top are the four swipes, each drawn as a blob is, showing what it does or an empty ring, with two arrows under it for which way. Make the swipe there, or tap its place, and the same list as for a blob comes up, titled with the swipe, with "Notifications" added at the front. The red minus leaves a swipe doing nothing.
- **A swipe can be** the notifications, any of Prism's actions, any of its pages, or any app.
- **One finger is untouched.** With one finger down the swipes take no part at all. When a second finger comes down, the first is taken away from whatever it was doing, so nothing scrolls or is pressed under a swipe.
- **Not while** the blobs are out (unless they are being changed), the app list or a sheet is up, the magnifying glass is out, or a blob is in the hand.
- Kept in a file of its own; costs nothing while nothing is touched.

**Checked:** in my preview, by the robot with two pretend fingers: a tap on a swipe's place asked what it should do; what was chosen was kept; the minus cleared it; a swipe made while changing asked what it should do; two fingers up with nothing open opened the scanner; a swipe given nothing did nothing. All the earlier checks were still right (48 of 51; the three wrong are power figures that cannot be measured there).
**Not checked:** on a phone, any of it. **The notifications in particular:** Android has no public way to pull them down; this uses the one home screens have long used, and I do not know that Samsung's Android 16 still allows it. If it does not, the swipe gives a dull buzz and nothing else. Starting a swipe at the very top or bottom edge of the screen is Android's, not Prism's.

## Prism, build 83 (14 November 2026)

**File:** `releases/prism-build-83.apk`

Needs Play Protect paused to install.

- **The cog stands on its own, clear of the X.** It was on the button's corner. It is now up and to the right of the button with a gap between them, and it is its own thing to tap: it answers on itself and a little around itself, never on the button. A tap on the X is always the X and ends the changing.
- **Blobs can be dragged into another order while they are being changed.** A drag there only rearranges: the others make room, and let go anywhere, even far from them, the blob sits in the seat kept open for it. It never floats and never goes into the button from there. A tap is still the pencil or the minus.
- **Held, then dragged without letting go.** Holding a blob starts the changing; moving on from that hold now takes the blob along.
- **The same in the chat head's own menu:** while its blobs are being changed they can be dragged into another order, and a hold can carry straight on into a drag. There a blob dragged clear no longer goes into the lens while they are being changed.
- **The tests:** held-then-dragged, dragged while changing, and dragged away and let go.

**Checked:** in my preview: the cog's place was looked at; a tap on it opened its panel; a tap on the X ended the changing. The long test's dry run: 41 of 44, the three wrong being power figures that cannot be measured there. The three new order checks were right.
**Not checked:** on a phone. The chat head menu's part is Android's and only compiles.

## Prism, build 82 (14 November 2026)

**File:** `releases/prism-build-82.apk`

Needs Play Protect paused to install.

- **The pencil and the red minus are a little larger.** The round mark goes from 25 to 28 across, the sign inside it grows by about a fifth, and its shadow is a touch stronger. They sit one step further out on the blob's corner, so no more of the blob is covered than before.
- **The cog on the X is larger than the blobs' marks:** 34 across where it was 25, its sign half as large again. It hangs further over the button's corner, clear of the X. While it is worn, the button answers a little beyond its own edge, so that every part of the cog can be tapped. A tap on the X itself still ends the changing.
- **The pencils in the chat head's own menu** are the same size and in the same place as in Prism.
- Where a tap counts as the minus, and where as the cog, moved with them.

**Checked:** in my preview, with the dark purple look: the marks and the cog were looked at; a tap on the cog opened its panel, a tap on the X ended the changing with the blobs still out, a tap on a minus took that blob away. The long test's dry run there: 38 of 41, the three wrong being the power figures that cannot be measured there.
**Not checked:** on a phone. The chat head menu's pencils are drawn on Android's side and were not seen at all.

## Prism, build 81 (14 November 2026)

**File:** `releases/prism-build-81.apk`

Needs Play Protect paused to install.

- **The magnifying glass, once put down, can be dragged off again.** Put down on a card it becomes the pill with that card's button. Until now a drag on the pill did nothing. Now a drag picks it up from where it lies and it is carried as it is from the button: it rides above the finger, opens over the cards it passes, stays where it is let go over something with a button, and goes home from anywhere else. A tap on the pill still presses its button; a tap beside it still sends it home. The same buzz as when it leaves the button.
- **The page counter in the app list changes colour more from page to page.** The ring went a little darker and nine degrees round the colour wheel between the first page and the last; it now goes twenty-two. With the orange accent the first page is orange and the last a red-orange. It is one number and can go either way.
- **The tests:** the long and hour-long tests now put the glass down on a card, drag it from there to another card, and drag it off to nothing.

**Checked:** in my preview the robot put the glass down on "Today's workout", dragged it from there to "Calories", where it stayed, then dragged it off and it went home; a flick up was still the app list afterwards. The counter's colours were looked at on the first and the last page (light theme, orange).
**Not checked:** on a phone. How the pick-up feels under a finger, and how the counter's colours read on your dark theme.

## Prism, build 80 (14 November 2026)

**File:** `releases/prism-build-80.apk`

Needs Play Protect paused to install (for the counts on icons; nothing new is asked of Android in this build).

- **A tap on the chat head, when you are already in its app, opens its menu.** Until now that tap reopened the app you were looking at, which did nothing. Now: somewhere else, a tap takes you to the app, as before; in the app, a tap opens the menu with your other blobs. A hold still opens the menu anywhere.
- **How it knows where you are, with no permission.** Prism is the home screen, so it opens most apps itself: from a blob, the app list, the chat head and the chat head's menu. Each time it notes which. It knows when it is in front itself. It is told when you head for the recent apps, from where you may come back to any app, and forgets. If the counts on icons are switched on, it also sees when a notification is tapped, and whose. Nothing watches and nothing is looked up: it only remembers what it did.
- **When it is wrong, it costs one tap.** If you got into the app some way Prism did not see, the first tap reopens the app, which does nothing, and from then on Prism knows: the next tap opens the menu. If you left the app some way Prism did not see, a tap opens the menu where you wanted the app: a tap on the chat head itself, in the middle of its own menu, closes the menu and goes to the app.
- **The same for one of Prism's own pages in the chat head:** on that page, a tap opens the menu; anywhere else, it goes to the page.
- **The tests check it:** the chat head tapped from Prism opens its app; tapped again there, it opens its menu; a tap on it in the middle of the menu closes the menu; back in Prism, a tap opens the app again.

**Checked:** it compiles.
**Not checked:** on a phone. This is all on Android's side. The long and hour-long tests now exercise it and will say whether it holds.

## Prism, build 79 (14 November 2026)

**File:** `releases/prism-build-79.apk`

Needs Play Protect paused to install.

**The hour-long test.** A second button under the long test: "Run the hour-long test (overnight, silent)". It is the long test done four times over, then the still stretches at three minutes each where the long test has one. It makes no buzz, here or from Android. About an hour.

- **The report is kept.** After every round, and at the end, it is written down. Whenever Prism's settings are next opened, the last report is at the bottom of the test tools with "Copy the last report". A test that was cut short leaves what it had found, marked UNFINISHED.
- **Repeats are combined.** A check made in every round is one line: right all four times, or wrong so many times of four, with what was found. Frames from the same stretch in every round are counted together.
- **Memory** is written down after each round, to see whether it grows with use.

**More of the blobs, in both tests**

- A blob that is an app: tapped, the app opens; Prism can be brought back.
- That app as the floating lens: tapped, its app opens and **the lens stays on the screen over it**; held there, its menu opens over the other app; a tap in it on one of Prism's pages brings Prism to the front on that page; dropped on the cross, nothing floats.
- Android's own Settings stands in for "an app" throughout: it is on every phone and nothing in it is touched.

**Checked:** it compiles. In my preview two rounds of the Prism half ran from start to finish: 69 of 73 checks right. Three of the four cannot be right there (power, with nothing to measure it), and the fourth, a slow flick, was right in one round of the two: my preview is too slow to flick reliably. The kept report and its Copy button are there in the settings.
**Not checked:** on a phone. None of Android's half has ever run, the app steps included.

## Prism, build 78 (14 November 2026)

**File:** `releases/prism-build-78.apk`

Needs Play Protect paused to install.

**The long test.** In Prism's settings, under the test tools: "Run the long test (about 20 min, hands off)". The app drives all of itself with a finger that is not there, checks after each step that things are as they should be, keeps how every frame was made while things move, and at the end sits still in one state after another and writes down what each costs. One report at the end, with a Copy button.

- *Prism's side:* every page and scrolling them; the blobs opening and closing; changing them by holding a blob and by holding the X; ending that by the X and by a tap beside them; labels off and on; the red minus, the empty place, "Add a blob" and the new blob joining; the pencil and "Replace"; the cog and its two switches; dragging a blob to another seat and back; the app list, its pages, closing it; the magnifying glass over every card, and a flick still being the app list; the sheets; ticking a set.
- *The floating lens, driven on Android's side with the same touch events a finger sends:* a blob put down in the open, and put down past the edge; the lens carried, thrown to each side, let go a little past the edge, pushed into the side and tapped out again; its own menu opened by a hold, changed, reordered, a blob dragged from it into the lens; the lens dragged back among Prism's blobs; a blob shot from the button; the lens dropped on the cross; "In Prism" switched off and on; the workout's timer floating, how often it is drawn, its sheet opened, closed by back and by a touch outside; and the buzz at the end of a rest with no lens on the screen.
- *Power:* a minute each of Home, the blobs out, the app list open, a blob floating, a rest running in the floating timer and its sheet open; and, with Android's Settings in front, nothing floating, a blob floating, a rest running, and the timer between sets. For each: the phone's current, Prism's share of the processor, how many frames Prism made and how often the lens was drawn.
- During the test the five blobs are Prism's own five actions, so that nothing opens another app. Your blobs, their labels, what was floating and the two switches are put back afterwards. Android's Settings will open four times and Prism will come back by itself.
- What it cannot do: see the screen. It knows when the lens was drawn and where it is, not what the glass looked like on the way. A one-frame flash would not be caught by it.

**Also in this build**

- **"Hide labels" / "Show labels"**, where it said "names".
- **While the blobs are being changed, a tap on the X ends that; only a tap on the cog opens its panel.**
- **The magnifying glass goes home** when you change page or open the app list, and a tap on the place it lives calls it home. It used to stay where it was put, over a different page.
- **A flick up that starts slowly is the app list again.** Since build 76 the glass could come out on such a flick. How fast the finger is going is now counted from when it began to move, not from when it came down.
- **All of the red minus can be tapped.** The part that hangs over the blob's corner did not answer.

**Checked:** it compiles. In my preview the long test ran its Prism half from start to finish three times: 34 of its 38 checks there came out right; three cannot (there is nothing to measure power with on a computer) and the fourth is the slow flick, which my preview is too slow to perform. Its first two runs found a fault in the test itself (how its finger picked a blob up), since put right.
**Not checked:** on a phone, and none of Android's half has ever run. Expect the first report to show some steps as "NOT DONE" or "WRONG" for reasons that are the test's fault and not the app's; that is what the first run is for.

## Prism, build 77 (14 November 2026)

**File:** `releases/prism-build-77.apk`

Needs Play Protect paused to install. A review of the code written for the floating lens, the blobs and the counts, against Android's and Flutter's own guidance on drawing, timers and overlay windows, plus two things asked for meanwhile.

**Less work for the same picture**

- **The floating timer is drawn when it has changed enough to see.** During a rest it was drawn 15 times a second whether or not anything had moved. The ring's head moves about a pixel in a sixth of a second on a 90 second rest, so that is when it is drawn now, and whenever the number changes: about 6 times a second on that rest, fewer on a longer one, never more than before. Between sets it is drawn on the second, so the number changes on time.
- **Nothing is made while the blobs are being drawn.** Every blob had a new colour gradient made for it on every frame, in the lens and in its menu: with five blobs moving that is six hundred a second, which is the kind of thing that makes an animation hitch. There is now one gradient for each colour, made once.
- **A blob's picture is made into a file once.** Each time the blobs were sent to Android (one put down, one put back, their order, their names) all of their pictures were made into files again by Prism and read back in again by Android. That happened at the very moment a blob is put down. Each picture is now made once and kept on both sides.
- **The open sheet sets a text only when it is a different text.** It was setting the same texts four times a second, each of which lays the text out and draws it again.
- **The lens's colours are not remade when its window changes size**, which since build 72 happens at the start and end of every throw.
- **The app list is not drawn again for a notification while it is closed.**

**A buzz that could go missing**

- **The buzz when a rest ends no longer depends on the lens.** It was given by the lens as it drew itself. With the lens closed on the cross, or switched off for where you are in "Floating elements", there was no buzz at all. It is now planned when the rest starts, for the moment it ends, lens or no lens.

**Taken out**

- The ring a blob wore in the lens's menu while it was also in the lens. That blob has not been in the menu since build 68, so the ring could never show.
- Comments that described things since taken out.
- Already taken out on the way here: the lens stepping aside for its own app and the listening that brought it back (72), the bar being swapped for a stand-in under the app list (71), the app list's own dim (70), the line of text over the blobs (73).

**Asked for meanwhile**

- **The + button is dark glass, like the timer.** The bright buttons are the ones that simply do something; this one opens things out, and now looks like the lens it is the home of: nearly black with a breath of Prism's colour, a lit rim, and a glow at its foot. The app list grows out of it in that tone, and the magnifying glass returns to it in that tone.
- **Back folds the floating sheet away.** The sheet (the timer and sets, weigh-in, log food) now takes the back button while it is open, so back closes it and does nothing to the app or to Prism underneath. The cost: while the sheet is open, a keyboard that was up in the app underneath goes down. In the lens's own menu, back now ends the changing first, as in Prism.

**Checked:** it compiles, with one compiler warning in the whole Android file (a harmless one). Nothing is declared and never used on either side; every message sent between Prism and Android has someone to receive it. In my preview: processor use with nothing touched is still none on Home, with the blobs out, while changing them, with the app list open and on the Train page; the + button in both a dark and a light theme, as + and as X, and under the app list.
**Not checked:** on a phone. In particular: how often the floating timer is now drawn, the buzz at the end of a rest with no lens showing, and back on the floating sheet.

**Left in on purpose, and worth a decision:**
- The older lens (the one that takes on the look of what is pinned), behind the switch "The lens is a container (new)". Everything since build 64 was built for the container; the older one has none of it and is the largest piece of code that is no longer exercised. Build 63 is kept as a zip in `backups/`.
- The test tools: the battery and frame journal, the on-screen figures, the automatic test. They cost a reading every ten seconds while Prism is on screen.
- The picture of Prism taken each time it is left, shown for an instant when you come back so that the screen does not flash.

## Prism, build 76 (14 November 2026)

**File:** `releases/prism-build-76.apk`

Needs Play Protect paused to install. It contains everything up to build 75.

- **The magnifying glass comes out of the button sooner.** Dragging up from the +, it used to wait 0.2 s before lifting off, so that a flick up for the app list was not mistaken for it. Now it lifts as soon as an upward drag is plainly not a flick: once the finger has gone a little way (24 points) and is taking its time over it. At an unhurried pace that is well under a tenth of a second. If the finger simply rests and then moves, it lifts after 0.14 s (it was 0.2 s). Sideways and downward drags lift as before.
- **The flick up for the app list is kept.** A fast flick never lifts the glass. A slower one that does lift it for an instant still opens the app list, if the finger left within about a third of a second of coming down.

**What to look for:**
- Drag up from the + at your usual pace: the glass should be out almost as you start.
- Flick up from the +, fast and not so fast: the app list should still open every time. If a flick now brings out the glass instead, tell me roughly how fast you flicked.

**Checked:** it compiles. In my preview: an upward drag lifts the glass, and a quick flick opens the app list. My preview cannot reproduce a finger's timing, so how much sooner it feels is for you to judge.
**Not checked:** on a phone.

## Prism, build 75 (14 November 2026)

**File:** `releases/prism-build-75.apk`

Needs Play Protect paused to install. It contains builds 72, 73 and 74.

- **Without names the blobs are spread wider.** They sat nearer the button, which also brought them nearer each other. They are now spread further round by as much as they are nearer, so the gap between one blob and the next is what it is with names. The chat head's own menu does the same.
- **A tap beside the blobs ends the changing first.** While the blobs are being changed, a tap anywhere else (the page, the bar) takes the marks away and leaves the blobs out. A second tap closes them, as always. Back does the same.

**What to look for:**
- Hide the names: the outer blobs should come down nearly to the bar, with even gaps.
- While changing, tap the page: marks gone, blobs still out.

**Checked:** it compiles. In my preview: the spacing with and without names, with the marks on.
**Not checked:** on a phone, including the chat head's own menu with the wider spread.

## Prism, build 74 (14 November 2026)

**File:** `releases/prism-build-74.apk`

Needs Play Protect paused to install, like 71 to 73. It contains builds 72 and 73.

- **A red minus on each blob while they are being changed**, at the top left, opposite the pencil. A tap on it takes the blob away. Its place becomes empty: a plain white outline that goes to the middle of the screen, while the blobs that are left close ranks, the same way they do when one is dragged out.
- **Empty places wait in the middle of the screen**, each with a pencil. Each of the five places has its own fixed spot in a row there, so nothing ever shuffles over. They are an outline and nothing else: nothing in them moves or is redrawn. They are shown only while the blobs are being changed; otherwise the menu simply has fewer blobs.
- **A tap on an empty place gives it something.** The list opens as "Add a blob". What you choose appears in the middle and comes down to join the others, in the seat that place has in the row. Several can be taken away and given back one by one.
- The chat head's own menu shows only the blobs there are.

Also in this build, from 72 and 73, for anyone coming from 71: the chat head stays on the screen when its own app opens; the second icon on letting go and the stutter at the edge are dealt with; the cog on the X and "Floating elements"; holding the X; the line of text removed.

**What to look for:**
- Hold a blob or the X, tap a red minus: the blob should become an outline and go to the middle while the rest move together.
- Close the blobs and open them again: fewer blobs, no outline.
- Hold again, tap the outline, choose something: it should appear in the middle and come down into the row.
- Tap the chat head to open its app: the chat head should still be there.

**Checked:** it compiles. In my preview: the minus and pencil on every blob, a blob taken away and the rest closing ranks, the outline in the middle only while changing, "Add a blob", and the new blob ending in the row with the choice kept after closing. My preview draws too slowly to show the flight itself; I saw it in the middle and then in its seat.
**Not checked:** on a phone.
**Not done:** the chat head's own menu has no minus. A place a blob was taken from keeps its position in the row, so a new one joins there, not at the end.

## Prism, build 73 (14 November 2026)

**File:** `releases/prism-build-73.apk`

Like 71 and 72, it needs Play Protect paused to install. It contains build 72, which was never installed on its own.

- **A cog on the X while the blobs are being changed.** The same white mark the blobs wear, with a cog. A tap on the button then opens "Floating elements", where they may be seen: "In Prism" and "Over other apps". Both are on to start with. The choice is kept.
  - *In Prism* off: they are not shown over Prism, except while the blobs are out, so that one can still be dragged back among them.
  - *Over other apps* off: they are gone as soon as Prism is left, and back when you return.
  - Both off: nothing floats. What was floating is a blob in the menu again, a blob dragged out goes back to its place, and the button does not offer to take one.
- **Holding the X does what holding a blob does.** With the blobs out, hold the X: the marks appear on the blobs and the cog on the X.
- **"Tap a blob to change it" is gone.** "Hide names" sits where it was.
- While the blobs are being changed, a tap on the X is for the cog, so it no longer closes them. A tap beside the blobs, or back, ends the changing.

**What to look for:**
- Hold the X with the blobs out: pencils and cog. Tap the X: the panel with the two switches.
- Switch "In Prism" off and close the blobs: the chat head should go. Open the blobs: it should be back, and it should go back into the row when dragged there.
- Switch "Over other apps" off and open another app: no chat head there.

**Checked:** it compiles. In my preview: holding the X, the cog, the panel and its switches, the choice being kept, and the edit state without the line of text.
**Not checked:** on a phone. What the two switches do to the chat head itself is on the Android side and unseen. The chat head's own menu (the one around it in other apps) has no cog.

## Prism, build 72 (14 November 2026)

**File:** `releases/prism-build-72.apk`

Like build 71, it needs Play Protect paused to install (the counts on icons).

From your recordings of build 71 and the frame you picked out.

- **The second icon that showed for a split second is gone at its cause.** In your frame there are two WhatsApp blobs: the one under your finger and one higher up, where the lens used to rest. The higher one was the lens. It was made at its usual place, told to move to where you put the blob, and then shown. Android moves a window a frame or two after it is told to, so for one frame the lens was shown where it had been. Now the lens is made where the blob is, and is not moved at all. (It was not the old hold-to-float code, which is gone, but your frame is what found it.)
- **The stutter when the lens comes away from the edge has the same cause, and is dealt with the same way.** I measured the lens's position in every frame of your clip: while it slid back in, some frames it barely moved and the next it moved double. Moving a window is not in step with the screen. So when the lens travels by itself (thrown, going to a side, tucking away), its window now stays still: it is made, once, to cover the whole of the way, and the lens is drawn at its place inside it frame by frame, which is in step. At the end the window is the lens's own size again. While you drag it, it still follows your finger as before.
- **The lens stays when its own app opens.** It used to step aside while its app was in front and come back when you left. Now it stays where it is: from it, any other blob is a hold away. To be rid of it, drop it on the cross or push it into a side. The code that hid it, and the listening for the app being left, are removed.

**A consequence to know about:** for the fraction of a second that the lens is travelling by itself, a tap in the strip of screen it is travelling through is not passed to the app underneath. A tap on the lens itself still catches it.

**What to look for:**
- Put a blob down anywhere, several times: there should be one icon only, at every moment.
- Throw the lens, and let it go a little past a side: its movement should be even. Watch the very start and the very end of a throw. If the lens jumps for one frame there, the window and the drawing are not changing together on your phone, and I need to know.
- Tap the lens to open its app: the lens should still be there, and holding it should open its menu.
- Catch the lens while it is still moving: it should stop under your finger and follow it.

**Checked:** it compiles. Nothing else: all of this is on the Android side, which my preview cannot run.
**Not checked:** on a phone. The stutter fix rests on Android changing a window's size and its picture in the same frame. Your two-finger resize has relied on the same thing since build 65 without a visible jump, which is why I expect it to hold, but it is an expectation. Build 71 is the fallback.

## Prism, build 71 (14 November 2026)

**File:** `releases/prism-build-71.apk`

**This build needs Play Protect paused to install**, because the counts on icons are back and they need Android's leave to read notifications. Build 70 is the one without them.

From your recordings and messages after build 70.

- **A carried blob stops at the side of the screen.** It goes no further than the place the lens rests, however far the finger goes, with a small tick when it gets there. Let go there, it is the lens at once: nothing appears half off the screen and nothing travels back in.
- **Putting a blob down no longer swaps pictures.** Before, the full-size blob was replaced in one frame by the smaller one inside the lens, squashed for a moment. Now the lens first draws exactly the blob you put down, the same size in the same place, and tells Prism when it is on the screen. Only then does Prism take its own away. After that the glass comes in around it and the blob comes down to its size inside. If it was put down away from a side it then goes straight to the nearer one, with no spring.
- **A thrown lens comes to rest without going past its place.** The spring was set a little loose, so it overshot the side slightly and came back. It is now set exactly so that it cannot.
- **Putting the chat head back among the blobs is a hand-over too.** Prism draws the blob where the lens is, at the size it had in the lens, says so, and only then does the lens go. The blob grows to its own size on the way to its seat.
- **The chat head's own menu closes when you leave.** It held the screen's focus, so going to the recent apps did not close it. It now listens, only while it is open, for Android's announcement that you are heading for the home screen or the recent apps, and it closes when Prism is left.
- **Drag to reorder in the chat head's own menu.** The same rule as in Prism: carried over the others they make room and letting go seats it; carried clear of them it goes into the lens. The order is kept in Prism.
- **"Hide names" while changing the blobs.** After holding a blob, a white button above the blobs hides or shows the names under them. Without names the blobs sit a little nearer the button (156 instead of 178). The chat head's own menu follows. The choice is kept.
- **The bar is the same bar under the app list.** In the real glass style the bar was swapped for a flat stand-in while the app list was open, an old saving of mine, and swapped back half a second after it closed. That was the remaining difference. It keeps its glass now.
- **Counts on icons are back**, as in build 67: on tiles in the app list, on blobs, and on the lens. Switch them on in Prism's settings ("Notification counts on icons"), which opens Android's screen for it. New: however many notifications come and go, Prism counts once, 0.4 s later, and it does not look at all at ones that only report progress (a download, music playing), which can change many times a second.
- **The workout clock runs only during a workout.** The Train page counted seconds from the moment it was first shown, for as long as Prism lived, workout or not. It now starts with the first set and stops when the workout is stopped. The time shown before a workout starts therefore stands still.

**What to look for:**
- Carry a blob to the side and past it: it should stop at the side. Let go: no movement, no squash.
- Put a blob down in the middle of the screen: one picture throughout, the glass arriving around it, then a straight slide to the side.
- Open the chat head's menu and go to the recent apps: the menu should be gone.
- Counts: after allowing them, an app with notifications should show a number on its tile and blob. If Android says the setting is restricted, open Prism's page in Android's app settings, tap the three dots at the top right and choose "Allow restricted settings", then try again.
- Blobs, app list, blobs: the bar should not change.

**Checked:** it compiles. In my preview: the blob stopping at the side; the "Hide names" button, the blobs moving in, and that surviving a close and reopen; counts drawn on tiles (made-up numbers); the bar identical, pixel for pixel, under blobs and app list in both glass styles. Measured there, processor use with nothing touched: none on Home, with the blobs out, while changing them, with the app list open, and on the Train page (which was using some every second before this build).
**Not checked:** anything on a phone. All of the Android side is unseen: the hand-overs in both directions, the menu closing on leaving, reordering in the chat head's menu, and the counts, which have never run on a phone at all (build 67 never installed). Whether Play Protect, switched back on later, objects to an app already installed, I do not know.

## Prism, build 70 (14 November 2026)

**File:** `releases/prism-build-70.apk`

From your three messages after build 68.

- **Hold any blob and all of them can be changed.** Every blob gets a small pencil mark and a line above says "Tap a blob to change it". A tap on one brings up the list to choose from ("Replace ..."); after choosing you are back at the blobs, still changing, so you can do the next one. Back, the X, or a tap beside the blobs ends it. While changing, blobs cannot be dragged or used. The floating lens's own menu does the same: hold a blob there, the marks appear, a tap on one opens Prism to choose.
- **Drag a blob among the others to move it.** As you carry it over the row the others make room where it would sit; let go and it sits there. The new order is kept, and the lens's own menu shows the same order. Carried clear of the row (about a blob's width above or below it) the others close ranks and letting go makes it the chat head, as before. On the button it is still shot to the side.
- **Drag the chat head back into the row to put it away.** While Prism's blobs are out, carry the floating lens over them: they make room, and letting go puts it back as an ordinary blob in that seat. It is then no longer a chat head. Dropping it on the cross still does the same without choosing a seat. If the lens is also holding a workout, only the blob goes back and the workout's lens stays.
- **The bottom bar no longer flickers between the blobs and the app list.** In your recording the bar was bright with the blobs out and dimmed under the app list, so it changed twice each time you went from one to the other. There is now one dim for both, over the page and the bar alike. This means the bar is now dimmed while the blobs are out, which it was not before.

**What to look for:**
- Hold a blob: pencil marks on all five. Tap one, choose something, and you should be back at the blobs with the marks still on.
- Drag a blob sideways along the row: the others should move over under your finger, before you let go.
- With a chat head floating, open the blobs and drag the chat head down into the row: a seat should open for it, and on letting go it should travel into that seat. Watch the moment of letting go: the lens fades as Prism's blob takes over, and that hand-over is the part I could not see.
- Go blobs, app list, blobs: the bar should stay the same the whole way.

**Checked:** it compiles, and the file asks only for vibration and drawing over other apps. In my preview: the pencil marks and the "Replace" list; reordering by dragging, with the others making room, and the order still there after closing and opening; a blob carried clear still becomes the chat head; a put-back played by hand (the seat opening and the blob ending in it); the bar the same under blobs and app list.
**Not checked:** anything on a phone. In particular everything on the Android side is unseen: the lens being handed back to Prism, the marks in the lens's own menu, and whether the lens's position lines up with Prism's seats on your screen.
**Not done:** dragging to reorder inside the lens's own menu (the one that opens around the chat head in other apps). There a drag still only puts a blob into the lens.

## Prism, build 69 (14 November 2026)

**File:** `releases/prism-build-69.apk`

From the recording of build 68.

- **A blob put down stays where you put it.** It was carried on by whatever movement your hand still had when you let go, which is why the lens appeared above the spot. Now only a real flick carries it. Otherwise it is seen where you put it, and a moment later slides to the nearer side at that height.
- **A tap during the closing no longer opens the app.** When the lens was dropped on the cross it shrank out of sight but was still there for the rest of the animation, so a tap in that spot was a tap on the lens. Now it takes no touch from the moment it is dropped, and is off the screen 0.15 s later. A tap there goes to what is underneath.
- **The closing is shorter and quieter.** 0.38 s (it was 0.9 s). The ring that went out is gone; the cross gives once, slightly, and sinks a short way.
- **The cross can no longer be in the way of touches.** Its window sat at the bottom middle of the screen the whole time a lens was floating, unseen. Android refuses touches on an app that lies under another app's window of that kind, so taps there in other apps may have been lost. I have not seen that happen on your phone; it follows from how the window was set up. The window now counts for nothing except while a lens is being carried.

**What to look for:**
- Put a blob down and hold your hand still as you let go: the lens should be exactly there.
- Drop the lens on the cross and tap the + at once: the blobs should open; nothing else.

**Checked:** it compiles.
**Not checked:** on a phone.

## Prism, build 68 (14 November 2026)

**File:** `releases/prism-build-68.apk`

**Build 67 could not be installed.** It asked Android for leave to read notifications, for the counts on icons. Google Play Protect blocks any app installed from a file that asks for that ("App blocked to protect your device"). So the counts are taken out again, all of them: the request, the switch in settings, and the numbers on tiles, blobs and the lens. This build asks for nothing new, and installs like the ones before 67. Counts on icons are only possible for an app installed from a store.

Everything else from build 67 is here (tap, drag and hold on the blobs; Prism's pages among the choices; the timer as its own control; the usage permission removed), plus:

- **The blobs that are left close ranks.** Drag a blob clear of the others and the rest move over at once, evenly around the middle; bring it back and they make room again. While a blob floats as the lens it is out of the menu, which then holds four. When the lens is dropped on the cross, the blob is back among them. The lens's own menu does the same, and shows only the blobs that are not in the lens.

**What to look for:**
- That it installs.
- Drag a blob out slowly: the others should move over as it leaves, not when you let go.
- Open the blobs while one is floating: four, with no gap.

**Checked:** it compiles, and the file asks only for vibration and drawing over other apps. In my preview: the others closing ranks during a drag, and four blobs afterwards.
**Not checked:** on a phone, including whether Play Protect now lets it through. The request it objected to is gone, which is the only thing that changed between 66 (installed) and 67 (blocked) in what the app asks for.

## Prism, build 67 (14 November 2026)

**File:** `releases/prism-build-67.apk`

**Cannot be installed:** Google Play Protect blocks it, because of the notification counts. Build 68 is this build without them.

**The blobs: three gestures, each with one meaning.**
- **Tap** a blob: use it.
- **Drag** a blob and put it down anywhere: it floats there as the lens, then does what any lens does when let go (it carries on with a flick and settles at the nearer side). Put down close to its own place, it goes back. Dropped on the button, or flicked at it, the button still shoots it out to the side.
- **Hold** a blob: change it. The app drawer comes up as "Replace ...". Its top row holds Prism's own actions and Prism's own pages (Home, Train, Food, Progress); it slides sideways. Below are all the apps. Tap what you want and you are back at the blobs.
- The X only closes again. Holding it no longer does anything; the marks and the line of text from build 66 are gone.
- The floating lens's own menu follows the same three: tap uses, a blob dragged out of its place goes into the lens, a held blob brings Prism up to change it.

**Notification counts.** A small number on an app, in the colour opposite the app's own so it stands out against its icon. On tiles in the app drawer, on app blobs (in Prism and in the lens's menu), and on the lens when it holds an app. Android only allows this once you turn on **Notification counts on icons** in Prism's settings and allow Prism on the screen that opens. After that Android tells Prism when a notification comes or goes; Prism never looks for them, so nothing runs in between.

**The timer in the tall sheet is its own control.**
- **Tap it:** pause, and again to carry on. Paused, the time dims and stands still, on the lens too.
- **Hold it** (or tap the line under it): for a few seconds the row under it offers Count up / Count down, Start over, and Switch off.
- **Switched off:** no time is shown anywhere; the lens shows which set you are on ("2/3"). A tap on the empty ring switches it back on. No rest starts while it is off.
- A line says this once, until you have held the timer.

**Removed:** the "Pinned app returns when you leave it" switch, its permission and the code that checked which app was in front. Your test showed the lens comes back without it.

**What to look for:**
- Put a blob down in the middle of the screen, and flick one toward a side: whether it lands under your finger and travels from there.
- The numbers: whether they match what the notification shade shows.
- Pause on the timer, then look at the lens.

**Checked:** it compiles. In my preview: holding a blob opens "Replace ..."; dragging one away closes the blobs and keeps it; the numbers on drawer tiles and blobs (with made-up counts); the picker's row with actions and pages.
**Not checked:** on a phone. Placing a blob as the lens, the notification listener, and the timer controls are written blind.

## Prism, build 66 (14 November 2026)

**File:** `releases/prism-build-66.apk`

- **The bar shows what passes under it, in the cheap glass style too.** On a phone where "Auto" had settled on the cheap style, the bar painted a picture of the background and so hid everything that scrolled under it (the water drops on Food went behind it and were gone). The cheap style is now clear glass: a tint over whatever is really behind it, with the rim and the light of glass. Things pass under it and are seen passing. It costs nothing: it is one see-through shape. Real glass (Auto when the phone keeps up, and Orig.) still softens and bends what is behind; the cheap style shows it sharp and dimmed.
- **Flick a blob to make it float.** With the blobs out, drag one onto the button in the middle and let go, or flick it at the button. The button takes it in, holds it for a moment and shoots it out to the side on a thread, where it lands as the floating lens (and the lens gives a little as it catches it). Let go anywhere else and the blob goes back to its place. Holding a blob still puts it in the lens as before.
- **Hold the X to change the blobs.** With the blobs out, hold the X: each blob gets a small mark and a line says "Tap a blob to change it". Tap one and the app drawer comes up as "Replace ...", with Prism's own five actions along the top and every app below. Tap what you want: it takes that place, and you are back at the blobs, still editing. The X or back ends it. Any place can now hold an action or an app, and the choice is kept.
- **After resizing the lens, the finger that stays down keeps dragging it.** Whichever of the two that is.
- **"Stop workout" in the tall sheet,** under the timer. It takes two taps (the second within three seconds), so a passing thumb cannot do it. With the workout stopped its timer stops floating and nothing of it is left running.
- **The tall sheet only where it fits.** With a keyboard up there is no room for it, so it becomes the small one.
- **Sheets are fully solid.** Faint traces of the app behind showed through them.

**What to look for:**
- Food: scroll the water drops under the bar. You should see them through it, in either glass style.
- The flick: whether the blob lands exactly on the lens or beside it, and whether the catch feels right or too much.
- Holding the X: whether 0.45 s feels right.

**Checked:** it compiles. In my preview: the clear bar, dragging a blob onto the button, and the whole editing flow (hold the X, tap a blob, choose a replacement, back at the blobs).
**Not checked:** on a phone. The hand-over from the flying blob to the floating lens, dragging on after a resize, and "Stop workout" are written blind.

## Prism, build 65 (14 November 2026)

**File:** `releases/prism-build-65.apk`

Three fixes, before anything new.

- **A tucked lens follows your finger at once.** Pull it and it is being dragged from that moment, coming under your finger within a fifth of a second. Before, the first touch only made it slide out by itself. A tap on it still brings it out to rest at that side. How it is built changed too: tucked, the lens really sits past the edge, and a strip along that edge (76 wide, there only while the lens is tucked) is its handle.
- **A pinned app's lens comes back when you leave the app, with no permission.** When you head for the home screen or the recent-apps list, Android announces it; Prism now listens for that, only while the lens is hidden in its app, and shows the lens at that moment. Nothing runs in between. The "Pinned app returns when you leave it" switch and its permission are still there as a second way; if this works for you without them, I will remove both.
- **With the blobs out, a tap anywhere on the bar closes them.** It no longer changes the page.

**What to look for:**
- Pin an app, tap the lens, then swipe up to the recent-apps list: the lens should be there as the list appears. This is the part I am least sure of on a Samsung with swipe gestures.
- Pull the tucked lens out slowly and quickly, from the middle of the strip and from its far end.

**Checked:** it compiles. The bar closing the blobs, in my preview.
**Not checked:** on a phone.

## Prism, build 64 (14 November 2026)

**File:** `releases/prism-build-64.apk`

The new version of the floating lens: a container. Build 63 is kept as the fallback in three ways: a switch in Prism's settings (**The lens is a container (new)**; off is the lens exactly as it was in build 63), the file `releases/prism-build-63.apk`, and the source in `backups/prism-build-63-source.zip`.

- **The lens is always the same glass button, in your colour.** It no longer turns into the thing pinned to it. What you put in it sits inside as its blob, smaller, with the glass around it. The blob hangs back slightly when you move the lens and comes to rest in the middle.
- **Hold the lens and the blob menu opens out of it,** with the click the button in Prism gives when held. These are the same blobs, on the same spring, in the same fan as in Prism, turned to face into the screen from wherever the lens is. It works over any app and in Prism.
  - **Tap a blob:** it is done once. Its app opens, or (Log food, Weigh-in, a workout that is on) its sheet opens right there. What is in the lens does not change.
  - **Hold a blob:** it goes into the lens with a thud, and replaces what was there. Holding the one already in the lens takes it out.
  - **Without lifting:** hold the lens, slide onto a blob, let go. That uses the blob in one movement.
  - A tap anywhere else, or the back button, closes the menu.
- **A workout and something in the lens at the same time is now a stack.** The workout's timer lies on top while a workout is on. What you put in the lens waits underneath, and a small dot of its colour on the rim says so. Drop the timer on the cross and what is underneath shows. Drop that on the cross and it is taken out. Opening the workout page puts the timer back on top. In build 63 the workout kept the lens to itself, so pinning something during a workout showed nothing.
- Tapping the lens does what it shows: the timer opens the workout's sheet, a blob does what the blob is. That is unchanged.

**What to look for:**
- Hold the lens at the right edge, at the left edge, near the top and near the bottom: the fan should turn so that every blob and its name is on the screen.
- Whether the menu looks and moves like the one in Prism. It is drawn a second time on the Android side with the same numbers; I cannot see either on a real screen.
- Put something in the lens during a workout: the dot should appear on the rim.
- The back button with the menu open.

**Checked:** it compiles, the Android code included.
**Not checked:** on a phone. The menu, the container's look and the stack are new and written blind.

## Prism, build 63 (14 November 2026)

**File:** `releases/prism-build-63.apk`

Two fixes on the version as it stands, before anything new is tried on it.

- **The bar is clear glass.** The lights in the background keep their shape as they pass behind the bar. Before, the bar blurred them into a wash of colour and then darkened that, so a light seemed to stop at the bar's edge. This holds in both glass styles:
  - **Event (still glass):** it costs nothing. The background is softened once, lightly, and the bar shows the part of that picture that lies behind it, bent a little at its rim.
  - **Auto and Orig. (real glass):** it costs what it cost before. The bar does the same work on every frame as it did, with a smaller blur.
  - What still differs: real glass also shows cards scrolling under the bar; still glass shows only the background.
- **Two fingers resize the lens.** One finger on the lens, a second anywhere on the screen; move them apart or together. It goes from its usual size (84) to the width of the screen less a small margin, and clicks at either end. The lens stays where it is while you do it and settles at the nearer side when you let go.
  - Past about one and a half times its usual size it also says what the time is (above it) and which set you are on (below it).
  - It keeps the size you gave it, also after the phone restarts.
  - On an open sheet's corner it is always its usual size, and goes back to yours when the sheet closes.

**What to look for:**
- The bar over a light on Home and Train: you should see the light's edge run through the bar.
- Resizing: whether the second finger is caught wherever it lands. If it lands in the same instant as the first, it may still reach the app underneath.
- Whether the lens jumps at the moment a resize begins or ends.

**Checked:** it compiles. The bar in my preview, in dark orange, dark blue and light orange, in both glass styles.
**Not checked:** on a phone. The resize is new touch code written blind. I cannot measure the real glass bar's cost here; it should be the same or slightly less, and the test report will say.

## Prism, build 62 (14 November 2026)

**File:** `releases/prism-build-62.apk`

From the recording of build 61: the floating sheet and the lens no longer bounce, and the small sheet says which set it is.

- **Small sheet to tall sheet (and back) is one movement.** Before, the contents were swapped in one go, Android slid the new sheet into place by itself, and the lens chased it on a spring. Now the top edge of the glass travels to its new place, what was on the sheet fades out early and the new contents come up after, and the "Set done" button does not move at all. The lens stays on the corner as the corner moves. The arrow bends over to its other side; it does not flip.
- **Opening and closing are short and quiet.** The sheet comes up a short way and is solid almost at once (it used to cross a third of the screen while half see-through). Closing is a small drop and a quick fade. A sheet that is closing keeps showing what it showed when you let it go.
- **The lens glides to the sheet's corner and back** in one even movement. A thrown lens still coasts with the throw, then settles without bouncing back. Pressing it, its appearing, and its "rest over" pulse no longer overshoot.
- **No arrow on the lens while a sheet is open.** It keeps showing the timer (or the pinned thing). Tapping it still folds the sheet away.
- **The small sheet says which set it is.** "Set 1 of 3" is larger and white, and under it is a bar with one segment per set: green for done, your colour for the one in hand, faint for the rest. The short first segment is the warm-up. It is the same bar the workout page draws for its exercises.
- **In the tall sheet,** when a rest starts or ends, the "+15 s" and "Skip" line appears or goes with the timer sliding to its new place; the sheet no longer jumps.
- **The lens can be tucked into the side.** Drag it into the left or right edge until it ticks, and let go: it slides away and leaves a sliver about 17 wide. Its touch area stays the full width of the lens (84), which is well past the phone's swipe-from-the-edge zone. Touch it anywhere there and it comes back out; that first touch only brings it out, the next tap uses it.
- **Touching the lens at the edge is not a "back" swipe.** The lens now tells Android that touches on it are its own, tucked or not.
- **A pinned app's lens can come back the moment you leave that app** (the recent-apps screen counts). Android only allows this with "usage access", so it is off until you turn on **Pinned app returns when you leave it** in Prism's settings and allow Prism on the screen that opens. While the lens is hidden in its app, Prism then looks three times a second at which app is in front, and stops as soon as the lens is back. Without the permission it behaves as before: the lens returns when Prism is next on screen.
- **Left alone:** the cross and the swallow when the lens is dropped on it.

**What to look for:** switching between the small and the tall sheet. The button should stay perfectly still and the top edge should travel in one go. If the sheet still slides or jumps at the start or the end of that movement, Android is not doing what I asked of it on your phone, and a recording will show me which part.

**Checked:** it compiles, the Android code included.
**Not checked:** on a phone. How the sheet is drawn and resized was rebuilt for this, and the tuck and the return-on-leave check are new; none of it has run on a real device. Whether Samsung's recent-apps screen is reported as "another app in front" is the part I am least sure of.

## Prism, build 61 (14 November 2026)

**File:** `releases/prism-build-61.apk`

- **"Set done" is back on the button**, with the numbers: "Set done · 77 kg × 7". (Build 59 had cut it to the numbers alone.)
- **The pull bar is wider:** about 62 across, where build 60's arrow was 36 and the old grey bar was 42. It is in your colour, with a slight bend at the middle: toward the top on the small sheet, toward the bottom on the tall one.
- Otherwise the same as build 60.

**Checked:** it compiles, the Android code included.
**Not checked:** on a phone.

## Prism, build 60 (14 November 2026)

**File:** `releases/prism-build-60.apk`

From your two screenshots of the sheet over another app. Includes builds 58 and 59 below.

**How to fold the sheet back into the lens is now on screen.**

- **The lens no longer disappears when the sheet opens.** It moves to the sheet's top right corner and shows an arrow pointing down, in your colour. Tap it and the sheet folds away; the lens goes back to where it was.
- So it is one thing with one rule: tap the lens to open, tap the lens to close. Pulling the sheet down and touching outside it still work.
- If the sheet grows, shrinks or moves, the lens follows its corner.

**It is clearer that the small sheet can be pulled up.**

- The grey bar at the top is now a shallow arrow in your colour: pointing up on the small sheet (there is more above), pointing down on the tall one.
- When the small sheet arrives, the arrow lifts once.
- Tapping the arrow still changes size.

**The sheet and the keyboard (an attempt).** In your second screenshot the sheet lay on top of the keyboard. I have asked Android to treat the sheet as something a keyboard belongs above, and to keep the sheet clear of it, so that with a keyboard up the sheet should sit on top of the keyboard and not over it.

**What to look for**
1. Open the sheet: is the lens on its corner with a down arrow, and does a tap on it fold the sheet?
2. Is the up arrow on the small sheet enough of a cue?
3. Open a keyboard in any app, then open the sheet. Where does it go?

**Checked:** it compiles, the Android code included.
**Not checked:** on a phone, any of it. The keyboard change in particular is from Android's documentation and I am not sure of it: if it works, the sheet rides above the keyboard; if it half works, the keyboard may cover the sheet. Either way you can type, which you could not before. Tell me what you see.

## Prism, build 59 (14 November 2026)

**File:** `releases/prism-build-59.apk`

Three changes to the floating sheet, from your screenshot of it over the Food page. This build also contains everything in build 58 below (pinning, the lens on every page, themed sheets, the new close).

- **Much less see-through.** The sheet was about 88 % solid and the page behind it ("Snacks", "Water", the drops) showed through as clutter, because it cannot blur what is underneath. It is now about 98 % solid.
- **"Open Prism" is named for where it goes, and hidden when you are there.** In the workout sheet it now says **Open workout**, and it is not shown at all on Prism's own workout page. In a pinned sheet (weigh-in, food) it says **Open in Prism** and is shown only outside Prism.
- **The button at the bottom is just the numbers:** "77 kg × 7". No "Set done".

**Checked:** it compiles, the Android code included.
**Not checked:** on a phone.

## Prism, build 58 (14 November 2026)

**File:** `releases/prism-build-58.apk`

**Fixes from your last recording (the floating workout behaving unpredictably)**

- **The lens no longer disappears on the workout page.** That was my decision in build 56 and it was wrong: it made the lens come and go as you changed tabs. It is now on every page of Prism and over every app, in the same place.
- **"Set done" always folds the sheet away.** Before, it folded the small sheet but left the tall one open. One rule now: logging a set closes the sheet and the lens shows the rest.
- **The sheets follow Prism's theme.** Your Prism was in light mode and the floating sheet was dark. Sheets are now light in light mode and dark in dark mode, with your colour. The lens itself stays dark glass, so it reads over any app.

**New: pin something from the blob menu so it floats over the phone**

- **Long-press a blob** (centre button, then hold one of the icons). It gets a bright ring: that one is pinned. Long-press it again to let it go. The first time, Prism takes you to Android's "Appear on top" screen if that is not yet allowed.
- **The pinned thing becomes a lens** in its own colour with its own picture, floating over Prism and over other apps, with the same dragging, throwing and closing as the workout lens. Nothing in it moves or runs while it is just floating.
- **Tap it and it does what it is:**
  - **Weigh-in:** a sheet opens in place, over whatever app you are in, with one wide dial in tenths of a kilo and "Save". Same sheet behaviour as the workout: pull down or touch outside to close.
  - **Log food:** a sheet opens in place with the usual meals, one tap each.
  - **An app** (when the blobs show apps): it opens that app and the lens gets out of the way. It is back the next time Prism is on screen.
  - **Workout, Scan, Timer:** these open in Prism for now (see below).
- **One lens at a time.** During a workout the workout has the lens; the pinned one returns when the workout is done.
- **To unpin:** drop the lens on the cross, or long-press the blob again.

**A better way to close a lens.** Drop it on the cross and it falls in. The cross takes the lens's colour, swallows, jiggles wider-taller-wider the way the centre button does when the drop lands on it, sends out one ring, and sinks off the bottom of the screen, with one thud. A flick down the middle does the same.

**All sheets are now one piece of code,** so the workout sheet and the pinned sheets arrive, lean, settle and leave identically.

**What is not possible, and what is not built yet**
- **Running Instagram (or any other app) inside a floating window is not possible** for a normal app. Android only lets the system itself do that, which is how Samsung's own pop-up view works. So an app pin is a shortcut, as you suggested for the fallback.
- **An app pin comes back when you return to Prism,** not when you go straight from that app to another one. Prism cannot see which app is in front without a further permission ("usage access") and regular checking, which costs battery. Say if you want that trade.
- **Scan does not float yet.** Scanning in Prism is still a placeholder, so there is nothing real to float. A floating scanner is possible, but it is its own piece of work: the camera permission, a notification that Android requires while a camera runs over other apps, a barcode reader, and somewhere to look the code up. I would build it as the next step if you want it.

**What to look for**
1. The lens during a workout: same place on every Prism page, the workout page included.
2. Long-press a blob: ring, and a lens in that blob's colour when you leave Prism (and inside Prism).
3. Pin Weigh-in, open another app, tap the lens: the dial sheet should open over that app. Save, and check the weight in Prism.
4. Drop a lens on the cross and watch the close. Is it satisfying? Too long, too short?
5. In light mode, is the sheet light now?

**Checked:** it all compiles, the Android code included. In my preview, long-pressing a blob gives it the ring and the pin is remembered.
**Not checked:** everything Android-side in this build: the pinned lens and its picture, the pinned sheets, the swallow animation, light sheets, the lens on the workout page. The parts from builds 56 and 57 that your recording showed working (lens, small sheet, dials, physics) have been restructured, so they could have picked up new faults. A recording is the fastest way for me to see them.

## Prism, build 57 (14 November 2026)

**File:** `releases/prism-build-57.apk`

**A System option for the theme.** Round button on Home: the "Dark" switch is now a row, **System / Light / Dark**.

- **System** follows the phone: if your phone is in dark mode, so is Prism, and it changes when the phone changes.
- System is the default for a fresh install. Your choice is remembered with the rest of the look.
- Every generated colour and background has a light and a dark version, so all nine colours and all backgrounds follow.

**The same behaviour and the same clicks everywhere.** You set the rule that an element behaves the same, predictable way wherever it appears. I went through the floating workout against Prism's own workout page and fixed what differed:

- **Logging a set, +15 s and Skip gave two clicks from the floating sheet** (one from the sheet, one from Prism doing the work). Now Prism does the thing and gives its one click, exactly as on its own page.
- **The end of a rest buzzed twice** when the lens was on screen (the lens and Prism both). Now it is one buzz: from the lens where the lens is, from the workout page where it is not.
- **The Haptics switch** in settings now also silences the floating lens, sheet and dials. Before, they ignored it.
- **Reps moved in half steps on Prism's page** when you slowed down, and in whole steps in the floating sheet. Half a rep is not a thing, so both are whole steps now, and a dial only changes to fine steps where finer steps exist.
- "Skip rest" in the sheet is now "Skip", as on the page.

The rule is written at the top of `PRISM.md`, with the product line you gave: "an app designed to keep you on track and get out of your way."

**What to look for**
- Theme: set System and change your phone between light and dark mode. Prism should follow without a restart.
- Light mode itself: I saw it properly for the first time in my preview. Tell me what looks wrong in it on your phone.
- Floating sheet: one click per action now, the same as on the workout page. Turn Haptics off and the lens and dials should go quiet too.

**Checked:** in my preview: the Theme row; System follows the machine (light there); choosing Dark switches at once and the next launch starts dark; it compiles with the Android code.
**Not checked:** on a phone. All haptics, since my preview has no vibration. The floating parts from build 56 are still untested on your phone, and this build changes their clicks.

## Prism, build 56 (14 November 2026)

**File:** `releases/prism-build-56.apk`

**The floating workout, redesigned around how you used it in your recordings.**

What the recordings showed: the lens and the panel work on your phone. You dragged the lens to the bottom middle to close it and it sprang back. The panel opened wherever the lens was, often high on the screen. And when you went home to Prism, the lens vanished.

**One thing, three sizes, on one up-and-down axis**

- **Lens:** a glance. The timer.
- **Small sheet:** tap the lens. The current set on two dials, and **Set done**.
- **Tall sheet:** swipe the small sheet up (or tap its grabber). A large timer, every set of the exercise with its own dials and tick, **+15 s**, **Skip rest**, **Open Prism**.
- Swipe down to go back a size: tall to small, small to lens. A touch outside the sheet also folds it to the lens.
- The sheet opens in the size you last used.

**The sheet is always at the bottom of the screen**, wherever the lens is, because that is where a thumb reaches with the phone in one hand.

**Closing the lens:** pick it up and a cross appears at the bottom middle. Drag the lens near it and it is pulled on, with a click; let go and it is gone. A flick down toward the middle throws it there. It comes back when you open Prism's workout page.

**It stays when you go home.** The lens now floats over Prism too, in the same spot, and over the app switcher. It is absent in one place only: Prism's own workout page, because that page is what the lens stands for. Leave that page and the lens is back where you left it.

**The same dials as in Prism.** Drag sideways and the number turns under your thumb with a click per step. Slow down and weight changes to half-kilo steps, with a different click. A tap on either half of a dial nudges it one step. An up-or-down drag that starts on a dial still moves the sheet.

**Count up or count down.** Tap the timer, in the sheet or on Prism's workout page, to switch. Counting down shows the rest that is left; counting up shows how long you have rested, with the ring filling. Either way it says GO and buzzes when the rest is over. The choice is remembered.

**Other details**
- "Set done" shows what it will log ("Set done · 80 kg × 8"). In the small sheet it folds away after logging; in the tall sheet it stays open.
- The lens keeps the spot you left it in, across apps and across Prism.

**What to look for**
1. Drop the lens on the cross: does it catch and close? Does a flick down the middle do it too?
2. Tap the lens: is the sheet in reach of your thumb? Swipe up for the tall one, down, and down again.
3. The dials: do they feel like the ones in Prism? Can you still swipe the sheet down when your finger starts on a dial?
4. Tap the timer to switch counting. Check Prism's workout page shows the same mode.
5. Go home to Prism mid-workout: is the lens still there, in the same place? Does it leave on the workout page and return after?

**Checked:** everything compiles, the Android code included. In my preview, Prism's own rest timer counts down, switches to counting up on a tap, and remembers it.
**Not checked:** all of the floating part of this build. The lens and panel from build 54 are proven on your phone, but the cross, the bottom sheet, both sizes, the dials, the swipes and the lens over Prism are new Android code that has never run. Expect rough edges in layout and feel; a recording like the last ones is the fastest way for me to fix them.
**How I arrived at this:** not from new research. It follows patterns people already know: chat heads (drag to a cross at the bottom), picture-in-picture (it is gone on the page it belongs to), bottom sheets (grow, shrink, swipe away), and keeping controls in the lower third for one-handed use.
**Limits:** still no blur or bending of what is underneath. The workout is still the made-up bench press; moving to the next exercise from the sheet is not there yet. The tall sheet is as tall as its content (about three quarters of the screen), not a fixed full screen.

## Prism, build 55 (13 November 2026)

**File:** `releases/prism-build-55.apk`

- **The drawer's progress ring deepens slightly toward the end.** On the first page it is your colour as chosen; by the last page it is about a fifth darker and a touch toward its deeper neighbour (amber leans to orange). The change is gradual across the pages.
- Otherwise the same as build 54.

**What to look for:** compare the ring on page 1 and on the last page. Noticeable but subtle, or too little?

**Checked:** it compiles.
**Not checked:** on a phone, or in my preview.

## Prism, build 54 (13 November 2026)

**File:** `releases/prism-build-54.apk`

**The workout floats over other apps.** The lens from build 53 is no longer only a rest timer: it is the workout itself, usable without leaving the app you are in.

**When it shows.** From the first set you touch until the last one is ticked, whenever Prism is not on screen. When the workout is done it is gone, and nothing is left running.

**The lens**
- **Counts down during a rest:** the ring runs down, the last ten seconds take your colour, then GO with a swell and a buzz.
- **Counts up otherwise:** the time since your last set, with a small bead going round once a minute like a second hand.
- **Clearer glass:** more of the app underneath shows through, and light gathers at the bottom edge in your colour, as in a thick lens.
- **Real throw physics:** it follows your finger, and when you let go it carries on with the speed you gave it and springs to the nearer side, overshooting slightly and settling. A flick sends it across the screen. Throw it off the bottom to put it away until you next open Prism.

**Tap the lens: the set opens right there**, as a glass panel over the app underneath.
- The timer, large, with what it is counting ("rest left" or "since your last set").
- The exercise and which set.
- **Weight** and **reps**, each with a minus and a plus (2.5 kg and 1 rep per tap), sized for one thumb.
- **Set done:** logs the set with those numbers, starts the rest, and the panel folds back into the lens, now counting down.
- **Open Prism** takes you to the workout page.
- A touch anywhere outside folds the panel away.

What you log from the panel is the same as logging in Prism: open Prism afterwards and the set is ticked with the numbers you chose.

**Battery.** Nothing exists outside a workout. During one, the lens redraws about fifteen times a second while a rest runs down and once a second while counting up; the panel refreshes four times a second while open. With the screen off, nothing is drawn at all. There is no background service.

**To switch it on (once):** round button on Home, **Workout floats over other apps**, allow "Appear on top".

**What to look for**
- The basics first: does the lens appear when you leave Prism mid-workout? Does it count?
- Tap it: does the panel open, do the steppers work, does "Set done" start the rest and tick the set in Prism?
- Throw it around: does the physics feel right, or too loose or too stiff?
- Over TikTok or a chat: can you still use the app underneath everywhere except under the lens?

**Checked:** it compiles, including the Android code; in my preview the workout page still ticks sets, starts the rest and changes weights as before.
**Not checked:** anything that floats. None of the Android code has ever run: the lens, the physics, the panel, logging from it. I have not had confirmation that builds 52 or 53 worked on your phone either, so if nothing appears at all, tell me that first; it changes where I look.
**Limits:** it cannot blur or bend the app underneath (Android offers blur only for a whole rectangular window, which would show as a blurred square around the round lens). It is tinted clear glass. The workout itself is still the made-up bench press with four sets.

## Prism, build 53 (13 November 2026)

**File:** `releases/prism-build-53.apk`

**The floating rest timer, as a small glass lens.** (The timer itself arrived in build 52; this is its look.)

- **See-through glass.** The disc is tinted and translucent, so the app underneath shows through it, darker toward the lower right and lighter where the light enters at the top left, with a breath of your chosen colour in it.
- **A rim lit from above** and a soft highlight lying across the top half, like the lens in Prism.
- **The countdown is a ring** in your colour with a bright bead at its head. It moves smoothly, not in one-second steps.
- **The time** sits in the middle in steady digits. In the last ten seconds it takes your colour, as a nudge.
- **When the rest is over** the lens fills with your colour, says GO, swells once and buzzes.
- **It arrives with a small bounce**, gives when pressed, and after a drag it settles against the nearer side of the screen, out of the way. Dropping it at the bottom edge still puts it away.
- A little larger than before, so it is easy to hit between sets.

**What it cannot do:** blur or magnify the app underneath. Android does not let one app see another app's screen, so this is tinted clear glass, not frosted or bending glass.

**Cost:** it now redraws about fifteen times a second while counting (it was four), so the ring moves smoothly. It is a small circle drawn by Android; I expect the cost to be negligible, but it is not measured. It still draws nothing once it says GO.

**What to look for**
- Does it read as glass over a bright app (a white chat) and over a dark one? Is the time always legible?
- Is the size right, and does settling against the side feel natural?
- Everything from build 52 still applies: does it appear, count, and bring you back on a tap?

**Checked:** it compiles.
**Not checked:** all of it. This is Android-only drawing code that has never run, and I have not seen a single frame of it. If it looks wrong, a screenshot tells me everything.

## Prism, build 52 (13 November 2026)

**File:** `releases/prism-build-52.apk`

**The rest timer floats over other apps.**

- Finish a set on Train, so the rest starts. Leave Prism for any app. A small round countdown appears over that app: the time left in the middle, a ring running down around it, in your chosen colour.
- **Tap it** and you are back in Prism on the workout page, ready to log the next set.
- When the rest is over it turns solid in your colour, says **GO**, and gives one buzz.
- **Drag it** anywhere on screen. **Drop it at the bottom edge** to put it away until the next rest.
- It disappears by itself when you return to Prism, and it never shows if no rest is running.

**To switch it on (once):** round button on Home, **Rest timer floats over other apps**. That opens Android's own screen; allow "Appear on top" for Prism and come back. The switch shows on once Android has it.

**Cost:** the countdown is drawn by Android itself, not by Prism's drawing engine. It redraws a 64-point circle four times a second while counting and not at all once it says GO. No background service and no permanent notification.

**The rest timer itself** now works from the moment the rest ends, where it used to count down second by second. So it stays correct while Prism is off screen.

**What to look for**
- Does the countdown appear when you leave during a rest, and does a tap bring you to the workout page?
- Does it keep counting, or freeze after a while? (If Android puts Prism to sleep in the background the number would stop. I expect it not to, but this is the main thing I cannot know from here.)
- Skip or finish the rest inside Prism, then leave: nothing should float.

**Checked:** it compiles and the app runs normally in my preview, where the timer on Train still counts down, adds 15 s and skips as before.
**Not checked:** the floating countdown, at all. It is Android-only code that has never run: the permission screen, appearing, counting, dragging, the tap back, and GO. If the app crashes when you leave it during a rest, switch the permission off in Android's settings and tell me.

## Prism, build 51 (13 November 2026)

**File:** `releases/prism-build-51.apk`

- **The bar is real glass again by default.** In build 49 I made the cheap "still glass" the default bar. Your recording showed the cost of that plainly: the blue water drops on Food vanish behind the bar instead of showing through it, and showing what is underneath is the point of the bar. The default is back to Auto (real glass, which blurs and bends whatever scrolls under it).
- Still glass stays where nothing moves behind it: the cards on Home (only the background is behind them), and the bar while the drawer or a sheet covers the page.
- "Event" in the Glass style row is still there if you ever want the cheaper bar.

**Checked:** it compiles; the change is one default value.
**Not checked:** on a phone.

## Prism, build 50 (13 November 2026)

**File:** `releases/prism-build-50.apk`

- **Fixed: the ring around the chosen colour was cut off** at the left edge of the settings sheet. The row of colours now has room at both ends.
- Otherwise the same as build 49.

**Checked:** in my preview the ring around the first colour is whole.
**Not checked:** on a phone.

## Prism, build 49 (13 November 2026)

**File:** `releases/prism-build-49.apk`

**The cheap glass, improved, and used where it does the most.**

What still glass is: the background is a still picture, so it is blurred once and kept. A piece of still glass shows the part of that blurred copy lying behind it. Nothing is blurred while you use the app.

What is new:

- **It now looks like glass, not like a blurred photo.** A band just inside the rim shows the picture slightly enlarged, as the curved edge of a pane does. Light is caught along the top. The rim is brightest at the top and fades down the sides.
- **The cards on Home are panes of it.** Each card shows the softened colours and pattern of whatever part of the background is behind it, and that changes as the card scrolls over orbs and lines. This is the frosted look from your reference pictures.
- **The lens around the selected tab is clear glass again.** It shows the background behind it enlarged by about a fifth, sharp, not frosted, and it travels with the tab.
- **It is the default bar.** In my side-by-side it was nearly indistinguishable from the real glass bar, so the default glass style is now Event (still glass). **Orig.** in the same row is the real glass bar, if you prefer it.

**What is different from real glass:** page content scrolling under the bar is hidden by it, not blurred through it. With Orig. it is blurred through.

**Two things here could cost something, and should be measured**
- Home's cards are now redrawn while you scroll, so that their glass shows the right part of the background. Until now Home scrolling was the cheapest thing in the app (0 % slow frames).
- The bar draws two pictures and a ring where it drew one flat colour.

Please run the test (about three minutes). The rows to compare with your build 44 report: "scroll Home" (was 0.6 to 1.9 % slow), and the Event setting as a whole (was 3.3 % slow, 0.3 % late).

**What to look for**
- Home: do the cards read as frosted glass over the background? Is the text on them still easy to read?
- Scroll Home slowly over an orb: the colour inside a card should stay lined up with the orb behind it. If it slides or jumps, tell me.
- The bar: does it still look like the bar you liked? Switch between Event and Orig. to compare.
- Train, Food and Progress are not yet done this way; their rows are as before.

**Checked:** in my preview: Home in amber with orbs and with arcs, cards frosted and lined up with the background, also after scrolling; the bar with its magnifying tab lens.
**Not checked:** on a phone; the cost; light mode; other colours; and the lining-up of cards while a card is pressed or while the page slides in from another tab.

## Prism, build 48 (13 November 2026)

**File:** `releases/prism-build-48.apk`

**Four patterns, drawn with care.** Round button on Home: choose Background "Pattern" or "Both" and a second row appears.

- **Ripples:** rings spreading from where the lights are, each a little further from the last and a little fainter, as on water, over a fine grain of dots.
- **Contours:** thirty lines like the height lines on a map or wind on sand. Each follows the one before but drifts, and they swell low on the left where the large light is.
- **Arcs:** a few large plain shapes, each part of a circle, overlapping like cut paper, tied together by thin rings.
- **Weave:** two sets of fine straight lines at slightly different slants. Where they cross they make slow bands of their own, like silk held to the light. Nothing is drawn to make the bands; they come from the crossing.

Each takes its colours from your chosen hue, and "Both" lays the orbs on top. All of it is still one picture made once. Patterns are made at a higher sharpness than orbs alone, because fine lines need it.

**Patterns on the cards.** Cards now let a little more of the background through (about 28 %, was 21 %) and have a slightly brighter edge, so the pattern carries across them and each reads as a pane.

**The bar: unchanged, as you asked.** The translucent glass bar stays exactly as it is.

**Glass that costs nothing, for the moments the bar used to go flat.** Your tests showed real glass on the bar costs about 0.9 ms a frame. The low-cost answer to "the colours reflecting beautifully":

- The background is a still picture, so it is blurred once and the blurred copy is kept.
- A piece of "still glass" shows the part of that copy that lies behind it, with the same tint and softness as the real bar and a lit rim.
- It is used wherever the bar was a flat solid colour before: under the drawer, under sheets, and in the Event style. In those moments the bar now keeps its colour.
- The one difference from real glass: page content scrolling under it is hidden, not blurred through it. And the small lens around the selected tab is a plain highlight, not a magnifier.

**What to look for**
- The four patterns in a few colours, with and without orbs. Which do you like, which not? Are any too faint (Contours was the quietest in my preview) or too loud?
- Open the drawer: the bar underneath should now keep its colour instead of going dark grey.
- Glass style "Event": compare the bar with "Orig.". In my preview they were nearly indistinguishable. If they are on your phone too, Event could become the default and the cost of the bar disappears.

**Checked:** in my preview: Ripples and Arcs in amber, Contours in blue, Weave in violet, on the Home page in dark mode; the real bar and the still-glass bar side by side over the same background.
**Not checked:** on a phone; light mode; patterns on the other pages; whether Event with still glass is as cheap as Event was before (it should be: one picture drawn, nothing blurred), which the test will show.

## Prism, build 47 (13 November 2026)

**File:** `releases/prism-build-47.apk`

**A look you choose, generated by rules, not picked from ready-made themes.**

Round button on Home. At the top of the sheet:

- **Colour:** nine hues. You choose only the hue.
- **Background:** Flow (the glowing orbs), Pattern (rings and a fine grain of dots), or Both.

From those two choices the app works out everything else:

- **The accent**, at a brightness that suits that hue. Yellow and green are bright by nature, blue and red are not, so each is taken near its own natural brightness instead of being forced to one level.
- **Text on the accent:** dark on a bright accent, white on a deep one.
- **The ground and surfaces:** near-black with a breath of the chosen colour, so the whole app leans the same way. Light mode gets its own version.
- **What the background shades through:** always the two neighbouring hues, one deeper and one lighter. Amber goes from deep orange to yellow; blue from indigo to sky.
- **Glass tint, card tint, the ring, the centre button:** all follow.

**Why this is lighter than themes, not heavier**
- Nothing is shipped or loaded: no theme files, no pictures.
- It is worked out once, when you change a choice. The background is drawn into one picture; after that it is plain colours and that one picture, exactly as before.
- Your choice is saved with the app's own files, so it survives restarts and cache clear-outs.

**Also in this build**
- **Fixed: the drawer's opening and closing looked broken half-way** (from your recording). The grid stayed full size and was cut off by the panel's edge as the panel shrank. The grid now grows and shrinks with the panel as one piece, out of the button and back into it.
- The settings sheet now scrolls, since it has grown past one screen.

**What to look for**
- Try every colour with each background. Is there any combination that looks wrong or is hard to read? That is the test of the rule; a screenshot of a bad one is what I need.
- Pattern: the dots are faint on dark. Enough, or should the pattern be bolder?
- Drawer: open and close it a few times. Clean now?

**Checked:** in my preview: blue with pattern, green with both, pink with flow, red with pattern, on the Home page in dark mode; the drawer opening and closing with the grid intact; and the nine swatches after the brightness rule.
**Not checked:** on a phone; light mode; the other three pages in colours other than amber. The cost should be unchanged because nothing is drawn per frame, but I have not measured it.

## Prism, build 46 (13 November 2026)

**File:** `releases/prism-build-46.apk`

**A new look, after your reference pictures: amber, glowing orbs, and glass that has something to show.**

- **The accent is amber** (between orange and yellow), where it was coral. Coral was close to another product's colour; amber is Prism's own. Text and icons on amber are near-black, because white on amber is hard to read.
- **The background is three glowing orbs on near-black**, orange deepening to yellow like lit spheres: a large one low on the left, one off the top right corner, a small one low on the right. They replace the faint coloured washes.
- **They are placed for the glass.** The large orb sits behind the bar, so the bar and the small lens that rides in it bend and blur real colour. The carried lens magnifies them when it passes over. The corner orb stays clear of titles and of the numbers you read.
- **Cards let about a fifth of the background through**, so each card is tinted by whatever glows behind it.
- **It is still one picture, made once.** No orb is drawn per frame, so this should cost what the old background cost: nothing measurable. The picture is a little sharper than before (made at 40 % of the screen, was 25 %).
- Light mode has its own version: the same orbs on warm off-white, with a slightly deeper amber.

**What to look for**
- Does it have the feeling of your references?
- Readability: on Train, Food and Progress some text sits directly on an orb. In my preview it was all readable, with the grey labels on Progress ("Most reps", "Biggest session") the weakest. Tell me what you cannot read comfortably.
- The centre button and "Continue" are now amber with dark text. Right, or too yellow?
- Light mode: I changed it but only looked at dark.

**Checked:** in my preview: all four pages in dark mode and the glass bar over the orbs.
**Not checked:** on a phone; light mode; the drawer and the sheets over the new background; and the cost, which I expect to be unchanged but have not measured. Run the test if you want that confirmed: the "Full glass" row should still be about 4.0 ms per frame.
**Honest limit:** the cards are see-through, not frosted. In your references the glass panels blur what is behind them. Blurring behind every card would bring back the cost we just removed from the bar, several times over. There is a cheap way to get true frosted cards from a still background, and I can build it next if you like this direction.

## Prism, build 45 (13 November 2026)

**File:** `releases/prism-build-45.apk`

**A cleaner return from other apps.**

- In your recording, as an app shrinks away on the home gesture, Prism behind it is a dark empty screen for a moment before its contents appear. The cause: Android throws away the surface an app draws on once the app is out of sight, and until the app has drawn a new frame the window shows only its plain background.
- Now, just before Prism leaves the screen, it copies its last frame and makes that picture the window's background. On return, that picture is what shows under the shrinking app, until the first real frame takes over.
- Cost: one copy of the screen each time you leave Prism, and about 10 MB of memory held for the picture. Nothing runs while you are away.
- A known side effect: if you left with the drawer open and come back with the home gesture, you will briefly see the drawer (the picture) and then it closing, because the home button closes it.

**Two fixes from your build 44 report**

- **Closing a sheet or the drawer stuttered on full glass** (14 late frames in 3 sheet closes; it was 6). That was my change in build 41: the bar goes solid under a sheet, and I turned its glass back on at the very start of the closing animation. Turning glass on costs one slow frame, and it landed in the middle of the movement. The glass now comes back half a second later, when nothing is moving.
- **The battery section's "screen still" figure was wrecked by single readings of several amps** at the start of a session. Readings above 3 A are now left out.

**Forgiving touch areas when logging a set** (from your recording on the Train page)

- The kg dial, the reps dial and the tick looked the same before, but only the drawn shape answered. Around them was dead space: 10 above and below each control, a gap between the two dials, and a margin beside the tick. In your recording several touches landed in exactly those places and did nothing.
- Now the whole row is controls. Each dial answers across the full height of its row and up to the middle of the gap between them. The tick answers across the whole right end of the row, about 66 wide and 72 tall where it was 48 by 48.
- Nothing looks different. Only what counts as a hit has grown.

**Background:** the two lights I added in build 42 came out redder on your phone than I intended. Both are now yellower and slightly weaker.

**What to look for**
- Home gesture from an app: is Prism's content there under the shrinking app, with no empty dark moment?
- Train page, one hand, quickly: do the dials and the tick catch your thumb now? If something still misses, tell me where your thumb was.
- Close a sheet and the drawer on full glass: smooth? About half a second after closing, the bar changes from solid back to glass; tell me if you notice it.

**Checked:** it compiles; in my preview sheets and the drawer open and close as before, the set rows look unchanged, and a tap beside the tick registers.
**Not checked:** the return picture. It is Android-only code that has never run. If Prism misbehaves on return (wrong picture, a flash, anything stuck), tell me and go back to build 44. The app-opening animation from build 42 is also still unconfirmed: in your recording I could not tell whether apps grow from their tile or slide in.

## Prism, build 44 (13 November 2026)

**File:** `releases/prism-build-44.apk`

Lettering in the drawer.

- **App names are a little larger and a little lighter** (size 14.2 from 13.5; weight 570 from 660).
- **The coloured initial is lighter too, but larger than the letters after it** (size 16, weight 720 from 900). It now stands out by size and colour, not by heaviness.

**What to look for:** do the names read more easily? Does the larger initial look deliberate, like a small drop capital, or does it sit awkwardly on the line? Do long names still fit on two lines?

**Checked:** in my preview, with made-up apps.
**Not checked:** on a phone, and with your longest real app names.

## Prism, build 43 (13 November 2026)

**File:** `releases/prism-build-43.apk`

Making opening apps and coming back feel as immediate as it can.

- **A tile answers the instant your finger lands.** It gives slightly, lightens, and you feel a tick, all on touch-down. Before, nothing happened until you lifted your finger, and Android's own "is this a tap or a drag?" wait can add up to a tenth of a second on top.
- **Prism is allowed to come back before the other app has finished leaving.** This is the setting the system's own home screen uses for the home gesture. Without it, Android waits for the app you are leaving to finish pausing first.
- **Prism is kept as one single task** and Android is told it does not need to rebuild Prism's state if it had to drop it. Both are standard for home screens.
- **Coming back is now measured.** The report has a line "back to Prism" with the frames right after you return, so I can see what the return costs.

**What to look for**
- Touch a tile and hold: it should react before you lift. Start a drag from a tile: the press should let go as the drag begins.
- Home gesture from another app: is Prism there faster than before?
- After a few trips to other apps and back, copy the report; the "back to Prism" line is what I want.

**Checked:** in my preview a pressed tile shrinks and lightens while held and returns on release.
**Not checked:** the two Android settings. They are documented and widely used, but I cannot run Android here, so their effect on your phone is unmeasured. The opening animation from build 42 is also still unverified.
**A limit worth knowing:** how long an app takes to appear after the tap is mostly that app's own start-up time, which Prism cannot change. What Prism controls is how fast it reacts to the tap and how fast it is back.

## Prism, build 42 (13 November 2026)

**File:** `releases/prism-build-42.apk`

**Background**
- **The background lights are on by default.** Your build 40 report measured them at no cost (4.1 ms per frame with and without).
- **Two warm lights added:** an amber glow low in the middle and an orange one off the right edge. They are part of the same picture that is made once and then only shown, so they add nothing per frame.

**Opening other apps**
- **An app now opens out of the thing you tapped.** From the drawer it grows out of its tile; from the blob menu, out of its blob. Before, it slid in from the side, which is Android's generic transition and says nothing about where the app came from.
- **Android is told where the tap was** (the tile's place on screen). This is what home screens are expected to send, and some apps and the system use it for their own opening animation.
- **The app comes back as you left it.** Launches now use the same instruction a home screen uses: bring the app's existing task forward, do not start it again.
- Unchanged, and already the standard behaviour: the home button returns to Prism's Home page with everything closed; the back button from an app returns to where you were, drawer still open on the same page; Prism draws nothing and runs no timers while another app is in front.

**The test**
- It now compares only the thing that was measured to matter: **the bar as glass** against **the bar solid**. Everything else, background lights included, is the same in both. It takes about three minutes.

**What to look for**
- Background: is the warmth right, or too much? Does anything on the pages get harder to read over it?
- Open an app from the drawer and from a blob: does it grow from the right place?
- Come back with the back gesture, then with the home gesture. Is Prism there instantly both times?

**Checked:** it compiles; the background shows in my preview.
**Not checked:** the opening animation, at all. My preview has no Android, so this is written from the documented way of doing it and has never run. If apps stop opening, or open from the wrong place, tell me and go back to build 41 meanwhile. The colours of the lights also look different in my preview than on your phone, so I cannot judge the warmth.
**What I cannot do:** the animation when an app closes back into its icon. Android reserves that for the system's own home screen; other home apps get a plain fade.

## Prism, build 41 (13 November 2026)

**File:** `releases/prism-build-41.apk`

- **Coloured initials are more noticeable.** Same hue as the app's tile, but brighter, stronger and heavier, so they stand out from the plain names next to them.
- **The bar goes solid while the drawer or a sheet is open.** Your build 40 report showed that turning pages in the drawer was 10 to 16 % slow with the glass bar and 1 to 2 % without it. The bar sits dimmed under the drawer, and its glass was being blurred again on every frame for something nobody is looking at. It turns back to glass when the drawer or sheet closes.

**What to look for**
- Initials: noticeable enough now? Any that are hard to read?
- When the drawer or a sheet opens, the bar changes from glass to solid at that instant. It is dimmed a moment later, but tell me if you catch the change.

**Checked:** in my preview: the brighter initials, and the bar solid under the open drawer.
**Not checked:** on a phone. Whether page turns are faster is for your next report: compare "drawer page" under Full glass with this report's 10.4 %.

## Prism, build 40 (13 November 2026)

**File:** `releases/prism-build-40.apk`

- **The drawer morph is 4 % stronger** than build 39, as asked: corners soften and the outline leans very slightly more.
- **The test now measures what the background lights cost.** It runs the app twice on full glass, once with the lights off and once with them on, doing exactly the same things both times. The difference between the rows "Full glass" and "Full glass + lights" is the cost of the background.
- **The test now includes the app drawer.** In the automatic part the app flicks the drawer open, drags forward two pages and back one, and closes it, under every setting.
- The test now runs four settings: Full glass, Full glass + lights, Event, No glass. "One at a time" and "Frosted" were dropped from the test because your earlier reports showed they change almost nothing; both are still in settings.

**How to measure the background:** round button on Home, **Run the test**, hands off for about three and a half minutes, then use it for a minute when it says "your turn". Paste the report. You do not need to switch the lights on yourself: the test does it and puts your setting back afterwards.

**Just to look at it:** the same sheet has the switch **Background lights**.

**Checked:** in my preview the automatic part opens the drawer, turns pages forward and back, closes it and carries on.
**Not checked:** the full test from start to finish with the new steps, and anything on a phone. The only earlier measurement of the lights is from build 11: 4.1 ms per frame with them and 4.1 ms without, so I expect a small difference, but that was before the drawer existed.

## Prism, build 39 (13 November 2026)

**File:** `releases/prism-build-39.apk`

- **An even smaller change of shape in the drawer morph.** The corners now soften by about a third (it was nearly three quarters) and the outline leans about eleven degrees and comes back (it was a full quarter turn). At the halfway point a tile is still clearly a squircle, just a slightly softer one, slightly tilted.

**What to look for:** is this calm enough? If it is now too little to notice, tell me and I will find the point between this and build 38.

**Checked:** in my preview I held a drag halfway and looked at the still.
**Not checked:** on a phone, or in motion.

## Prism, build 38 (13 November 2026)

**File:** `releases/prism-build-38.apk`

**A much milder morph in the drawer.** The cookie with waves is gone.

- As you drag, each tile's corners soften most of the way toward round, and the shape turns a quarter turn while they do. Each corner arrives exactly where the next corner was, so the tile ends as the same squircle it began as.
- At the halfway point a tile is a soft, nearly round shape. There are no waves or points anywhere in the movement.
- The marks and names do not turn; only the outline does. Colour, marks, names and following the finger are unchanged.

**What to look for**
- Is it calm enough with twenty tiles doing it at once?
- Does the quarter turn read as a gentle roll, or is it barely noticeable? I can make the corners soften less so the turn shows more, or more so it shows less.

**Checked:** in my preview I held a drag part-way: soft, nearly round tiles turned slightly, no waves.
**Not checked:** on a phone, or in motion. A turn is hard to judge from a still.

## Prism, build 37 (13 November 2026)

**File:** `releases/prism-build-37.apk`

- **The initial that marks a new letter is now in the app's own tile colour**, not orange. It is nudged about a quarter of the way toward the text colour, because tile colours are chosen to sit behind white marks and some would be too dark to read as text on their own.

**What to look for:** is every coloured initial readable, especially on blue and purple apps? Does it still work as an index now that the initials are different colours?

**Checked:** in my preview, with made-up apps.
**Not checked:** on a phone with your real tile colours.

## Prism, build 36 (13 November 2026)

**File:** `releases/prism-build-36.apk`

- **A coloured initial marks where each letter starts in the drawer.** The first app of every new letter has its first letter in the accent colour and slightly bolder. The other apps of that letter are plain. Down a page, the orange initials read as an index.
- Nothing else moves: no extra element, no extra space.

**What to look for:** can you jump to a letter by scanning for the orange initials? Is the orange strong enough against the tile colours next to it, or too strong?

**Checked:** in my preview, with made-up apps: the first app of each letter has an orange initial and the rest do not.
**Not checked:** on a phone, and with names that start with a digit or symbol.

## Prism, build 35 (13 November 2026)

**File:** `releases/prism-build-35.apk`

Icon engine fixes, from your screenshot of the C to G page.

- **Tone-on-tone icons (eKupi).** Its letter is a slightly different red on red. The engine looked for a mark that is very different from the ground, found none, treated the icon as a picture and then calmed it, which left almost nothing. Now "different" is judged against how much the icon varies at all, so a faint mark is found and cut out in white like any other logo.
- **Small marks (Drive).** Some apps supply an outline that only fills the middle of its picture. Every outline is now trimmed to what is actually drawn, so all marks fill their tile alike.
- **Stray arcs in corners (Copilot).** The rounding of an icon's own corners was being picked up as part of the mark. Corners are now left out.
- **Flat pictures** that stay pictures get their light and dark pulled apart before calming, so they do not wash out.
- Every app is worked out again once after this update, so the first open of the drawer takes a moment.
- The report's battery section now also lists the raw readings exactly as the phone gave them, so I can check the unit and sign.
- Includes build 34's drawer speed-ups.

**What to look for**
- eKupi: a white "e" on red. Drive: a triangle the size of the other marks. Copilot: no arcs in the corners.
- Did anything that looked right before get worse? The new rule for faint marks could, in principle, pick up a soft gradient as a mark on some icon. A screenshot of any page that looks off is enough.

**Checked:** in my preview, on a made-up tone-on-tone icon like eKupi's: it now cuts out as a clear white letter. The McDonald's test icon lost its corner arcs. The moj ZET and Muay Thai test icons came out as before.
**Not checked:** on your real icons, including eKupi, Drive and Copilot themselves. I have not seen Drive's outline, so the size fix is from reasoning.

## Prism, build 34 (13 November 2026)

**File:** `releases/prism-build-34.apk`

Performance work on the drawer, from your build 32 report (the first report with the drawer in it).

**What the report showed**
- Opening the drawer was the worst thing in the app: 20 % of frames slow, 26 late over seven opens, single frames of 14 to 28 ms against a budget of 8.3.
- Closing was second: 5.4 % slow, 9 late.
- Turning pages was acceptable: 6.1 % slow, 4 late over 49 turns.
- All of it was drawing, not my code deciding what to show.

**What I changed**
- **Opening and closing.** The grid used to fade in and out. A fade means the whole grid is drawn to a separate surface and blended, on every frame of the animation. Now the grid is simply uncovered by the growing panel's own edge. It looks nearly the same and removes that surface entirely.
- **The grid keeps its own finished picture.** Opening, closing and the ring no longer make it redraw.
- **Page turns.** Because every tile changes together, one outline is now worked out per frame and reused for all twenty, where it used to be worked out twenty times. Names dim per row (five small surfaces) where they used to dim one by one (twenty).
- **Only picture tiles are trimmed to their outline.** A white mark never reaches the edge, so it does not need it.

**Two things the report exposed that were wrong**
- **The automatic glass style stepped down to Event because of the drawer.** The drawer's slow frames were counted as evidence that the phone cannot afford the glass bar, which they are not. Frames with the drawer up are no longer counted, and the automatic style starts again from Original after this update.
- **The battery section printed a conclusion from ten readings** ("drawing costs about -743 mA"), which is noise, not a result. It now needs twenty readings of each kind before it says anything.

**What to look for**
- Does the drawer open and close the same as before to your eye? The contents now rise with the panel and are not faded in.
- After a few opens and page turns, copy the report. The lines to compare are "drawer open", "drawer close" and "drawer page".
- The glass bar should be back (Auto on Original).

**Checked:** in my preview the drawer looks the same at rest, mid-drag and after a page turn.
**Not checked:** whether it is actually faster. That is exactly what your next report will say; I expect opening and closing to improve most.

## Prism, build 33 (13 November 2026)

**File:** `releases/prism-build-33.apk`

- **App names in the drawer change as mildly as possible.** A name no longer disappears and reappears. During a drag it dims, switches to the new name at its dimmest point, and comes back up. It never reaches zero.
- **Names are a touch darker** (about 16 % toward the background), so they sit back slightly behind the tiles.

**Light mode is still there:** round button on Home, the **Dark** switch at the top. Turn it off for light mode.

**What to look for**
- Is the name change quiet enough now? At the dimmest point the name is at about a fifth of its normal strength.
- Is the darker text still easy to read at a glance?
- Light mode: have a look at the drawer and tell me what looks wrong. I have only glanced at it.

**Checked:** in my preview, in light mode: the drawer at rest, and held mid-drag (names dimmed but still visible, no overlap).
**Not checked:** on a phone, or in motion. In light mode "a touch darker" actually makes the names slightly lighter grey, because the change is toward the background; tell me if you want it the other way there.

## Prism, build 32 (13 November 2026)

**File:** `releases/prism-build-32.apk`

- **No dot in the middle of the drawer morph.** The old mark draws in and is gone, the tile is plain colour while it changes shape, and the new mark grows in at the end.
- **Fixed: a short flick still turned the button into the lens** (from your recording: the button lifted for a moment and dropped back). My rule treated any small movement as "slow", and slow meant "carry". Now a carry needs real evidence: the finger has been down for a fifth of a second, or has gone a fair way sideways or down. A short quick nudge lifts nothing.
- **A shorter flick opens the drawer.** It needed 46 of upward travel; now 26. A nudge shorter than that counts as a tap.

**What to look for**
- Short flicks, long flicks, lazy flicks: each should open the drawer with no glass and no drop coming home.
- Slow drag upward: the lens should lift after a brief moment and catch up with your finger.
- Drawer morph: is the plain-colour middle calm enough?

**Checked:** it compiles and passes analysis.
**Not checked:** I did not preview this build. Both changes are small edits to code I previewed in builds 30 and 31, but the flick timing can only be judged with a real thumb.

## Prism, build 31 (13 November 2026)

**File:** `releases/prism-build-31.apk`

**A flick no longer wakes the lens.**

- Before, the button turned into glass the instant it moved. During an upward flick it magnified and highlighted cards for a moment before the drawer opened.
- Now the button waits to see what the movement is. A quick upward movement stays a plain button. It only lifts off as the lens once the movement is clearly a carry: slow, sideways or downward, or held for about a fifth of a second.
- So a flick opens the drawer with no glass, no magnifying and no cards lighting up. That removes glass drawing from exactly the moment the drawer starts to animate.
- A normal slow drag lifts the lens as before. A fast upward drag that you keep holding becomes the lens after about a fifth of a second.

**What to look for**
- Flick up: the drawer should open with nothing else happening on the way.
- Lens: drag up slowly as usual. Does it still lift when you expect? If the lens now feels late to appear, tell me.
- If you drag upward quickly and hold, the lens should catch up to your finger.

**Checked:** in my preview a quick upward movement opens the drawer, and a slow drag lifts the lens.
**Not checked:** on a phone. The line between "flick" and "carry" is a speed (about 0.7 of a point per millisecond) that I chose by reasoning; real thumbs may need it adjusted.

## Prism, build 30 (13 November 2026)

**File:** `releases/prism-build-30.apk`

**A quieter centre during the drawer morph.** In build 29 the old and new marks lay on top of each other for most of the drag, so every tile centre was a tangle. My proposal, now built:

- **The mark morphs through one shared shape: a small dot.** As you start to drag, the old mark draws in and becomes a white dot. The dot holds while the tile changes shape and colour. Near the end, the new mark grows out of the dot.
- So the centre never holds two things at once, and at the halfway point every tile on the page looks the same: a soft cookie with one dot.
- **Names** follow the same timing: the old name is gone before the new one starts, so two names never overlap.
- Shape, colour, and following the finger are unchanged from build 29.

**What to look for**
- Is the centre calm now? Does the dot read as the mark "passing through", or as a separate thing appearing?
- The names are blank for the middle fifth of the drag. Is that fine, or do you miss them?

**Checked:** in my preview I held a drag at three points: early (old mark still clear), a third of the way (mark almost gone, dot arriving), and halfway (one clean dot per tile, nothing else).
**Not checked:** on a phone, in motion, or with real marks and picture icons. The last change (names never overlapping) went in after the preview.

## Prism, build 29 (13 November 2026)

**File:** `releases/prism-build-29.apk`

**The drawer morph, simplified to exactly this:** squircle, to a soft cookie, back to squircle, while the colour goes from one app's to the next.

- **The shape** in the middle is a cookie with six shallow waves: fewer and softer than the seven-wave cookie in the Shape morph room. At the halfway point the tile is fully that shape.
- **The colour** goes straight from one to the other. No darkening, no brightening, no flash.
- Everything else from build 28 stays: it follows your finger, reverses if you drag back, and the whole page changes together.

**What to look for:** is the cookie soft enough, and is six waves right? Does the colour change look plain and calm now?

**Checked:** in my preview I held a drag halfway with a five-wave version: the colours were halfway between the two apps with no brightness change, but five waves read as a pentagon. I changed it to six shallower waves and did not preview that last change.
**Not checked:** on a phone, and in motion.

## Prism, build 28 (13 November 2026)

**File:** `releases/prism-build-28.apk`

**The drawer's morph now follows your finger.** Build 26's version played by itself once triggered, flashed bright colours halfway and rippled too hard, which looked like a glitch. This replaces it.

- **It moves with the drag, in real time.** Drag a little and the tiles morph a little. Drag back and they return. Stop and they hold.
- **Let go** past a third of the way, or with a flick, and it completes. Let go earlier and it goes back.
- **Keep dragging** and page after page goes by under your finger, about 120 of travel per page.
- **The whole page changes together.** No row-after-row delay.
- **Colours dip darker in the middle**, never brighter. They go straight from one app's colour to the next and are about a third darker at the halfway point.
- **The ripple is gentler** (under a third of the full cookie shape).
- At the first and last page a drag outward does nothing.
- The ring follows the drag too.

**What to look for**
- Does the morph feel attached to your finger?
- Darkness in the middle: right, too much, or too little?
- Is 120 of travel per page comfortable, or should a page take less dragging?

**Checked:** in my preview I held a drag halfway (tiles darker, gently rippled, marks mid-dissolve), dragged back (page restored exactly), completed a drag (next page), and made a short drag (reverted).
**Not checked:** on a phone, and how it feels in motion.

## Prism, build 27 (13 November 2026)

**File:** `releases/prism-build-27.apk`

**Drawer tiles: smaller and softer.**

- Tiles are about 10 % smaller (61 instead of 68), which gives each one more air and lets the name stand out.
- The shape is a softer squircle: fuller corners and less flat side than before. It now sits between the round blobs and the rectangular cards, so it reads as related to both.
- The mark inside is scaled to match.
- The page-turn morph starts from and returns to this new shape.

**What to look for:** does the tile shape feel like it belongs with the blobs and cards? Too soft, too boxy, or right? Is the size right now?

**Checked:** in my preview, with made-up apps: the new shape and size.
**Not checked:** on a phone with real marks inside the smaller tile.

## Prism, build 26 (13 November 2026)

**File:** `releases/prism-build-26.apk`

**The drawer's page turn is now a morph, not a swap.**

- Nothing shrinks, fades out or pops in. Each tile stays at full size, in place.
- The squircle's outline ripples slightly (the same shape morph as the Shape morph room in Lumen) and settles back to a squircle.
- The colour slides around the colour wheel to the next app's colour, the short way round, so it stays vivid the whole time and never passes through grey.
- The mark dissolves into the next mark in place. The name does the same, timed so two names are never both readable at once.
- The row-after-row delay is much smaller, so the page changes nearly together and reads as one calm movement.

**What to look for**
- Is the ripple the right amount? I set it to less than half of the full "cookie" shape.
- Does the dissolve of the marks look clean, or ghostly?
- Is it calmer than before without feeling slow? It takes about 0.4 seconds.

**Checked:** in my preview I froze a page turn exactly halfway: the outlines ripple, the tiles are full size, and both marks are visible mid-dissolve. My first version went grey halfway and showed two overlapping names; after fixing both I froze it again and the colours stay vivid and only one name is readable.
**Not checked:** on a phone, and the motion itself.

## Prism, build 25 (13 November 2026)

**File:** `releases/prism-build-25.apk`

- **Fixed: the Weight card on Home opened Facebook, and the Calories card opened WhatsApp.** Those cards (and the lens buttons "Log weight" and "Log food") were wired to "the fourth blob" and "the second blob". Since build 18 the blobs hold apps, so the cards launched whatever app sat in that slot. They are now wired to Prism's own actions directly and open the Weigh-in and Log food sheets whatever the blobs show.
- Includes build 24: bigger, bolder, two-line app names in the drawer.

**What to look for:** tap the Weight card and the Calories card on Home, and use the lens on both. Each should open its sheet.

**Checked:** in my preview, tapping the Weight card with app blobs switched on opens the Weigh-in sheet.
**Not checked:** on a phone.

## Prism, build 24 (13 November 2026)

**File:** `releases/prism-build-24.apk`

- **App names in the drawer are bigger and bolder** (13.5 instead of 12.5, and clearly heavier), because the tiles no longer look like the icons you know and the name has to do more of the finding.
- **Long names now wrap onto a second line** instead of being cut off ("Marshall Bluetooth" and not "Marshall Bluet…").
- Rows are slightly taller to make room. On your phone that should still be five rows.

**What to look for:** can you find an app by name at a glance now? Is it five rows per page still?

**Checked:** in my preview, with made-up apps: the names are larger and heavier and the rows still fit.
**Not checked:** on a phone, and how real long names wrap.

## Prism, build 23 (13 November 2026)

**File:** `releases/prism-build-23.apk`

**Fewer grey tiles in the drawer.**

- The engine now accepts a much smaller amount of colour as the icon's colour: half a percent of the picture is enough (it was three percent), paler colours count, and a colour spread over two neighbouring hues is treated as one. A small coloured mark on a white or black icon now gives the tile its colour.
- Icons that truly have no colour (black, white, grey) no longer all turn slate. Each gets one of Prism's own hues, always the same one for the same app, held visibly quieter than a real brand colour so the two kinds do not get confused.
- Every app is worked out again once after this update, so the first open of the drawer takes a moment.

**A ring instead of dots.**

- The row of dots at the top (which suggested swiping sideways) is replaced by a ring like the others in Prism, with the page number inside. It fills as you go through the apps: full means the last page.
- You can now swipe up/down or left/right; both turn the page. Up or left is forward.
- The ring leans in the direction you are pulling before the page turns, then springs to its new place.

**What to look for**
- Which tiles are still grey or the wrong colour? A screenshot is enough.
- Do the quiet made-up colours on colourless icons (Settings, Uber, Revolut and similar) look right, or would you prefer those to stay neutral?
- Ring: does it read as "how far through" at a glance? Is the lean while pulling pleasant or distracting?

**Checked:** in my preview, with made-up apps: the ring shows and fills, and a sideways swipe turns the page.
**Not checked:** the new colour rules on your real icons. I tuned them from reading your recording, where I counted about ten grey tiles across seven pages; I have not seen the result.

## Prism, build 22 (13 November 2026)

**File:** `releases/prism-build-22.apk`

**Prism can be your home screen.**

- After installing, press the home button. Android asks which home app to use: choose **Prism**, then **Always**. If it does not ask: Settings, Apps, Choose default apps, Home app, Prism.
- **To go back to Samsung's home screen at any time:** the same setting, choose One UI Home. Nothing is lost; your Samsung layout is untouched.
- The home button now brings you to Prism's Home page and closes anything open (drawer, sheet, lens, blobs).
- The back button no longer leaves Prism, because a home screen has nowhere further back to go. It still closes things one step at a time.

**The diary.** Prism now keeps notes by itself between tests, and they survive restarts.

- Each time Prism leaves the screen it writes one line: how long it was up, frames drawn, late and slow frames, battery level, and the action that cost the most.
- **Errors in the code are caught and written down** with where they happened and how often. Until now these were lost.
- It does nothing while Prism is off screen: no timers, no wake-ups. About two weeks of use are kept.

**The battery meter.**

- While Prism is on screen, it reads the battery every ten seconds: level, how fast it is draining, whether it is charging, temperature, and screen brightness.
- Readings are sorted into "screen still" and "screen moving" (by how many frames were drawn in those ten seconds). The difference between the two is what drawing costs, which is the part Prism can change.
- Readings on the charger are left out.

**All of it is in the same report.** Copy test report (or run the test) now ends with three new sections: DIARY, BATTERY, ERRORS. No test is needed for them; just use the phone and copy the report whenever you like.

**What to look for**
- As a home screen it is bare: no wallpaper, no widgets, no notification dots, no search, and the fitness data is still made up. Tell me what you miss first.
- After a day: copy the report and send it. The BATTERY section needs a few minutes of use off the charger before it says anything.

**Checked:** in my preview the diary line is written and the three sections appear in the report.
**Not checked:** on a phone: being chosen as the home app, the home button, and every battery reading. Samsung phones report drain in a different unit from most others; the report says which unit it assumed, so I can tell if the numbers are off by a thousand.

## Prism, build 21 (13 November 2026)

**File:** `releases/prism-build-21.apk`

**The app drawer.** Flick the centre button upward (a quick, short swipe up). The round button widens and rises into a panel holding all your apps.

- Every app is a large squircle in its own colour, pulled into Prism's palette, with its mark in white.
- The grid does not scroll. Swipe up or down inside it and the page turns in place: each tile stays where it is, its colour slides into the next app's colour, the old mark shrinks away and the new one grows in. Rows change one after another in the direction of your swipe. A long swipe turns several pages.
- The top shows which letters you are on and a dot per page. Tap a tile to open the app.
- To close: tap the button (now an X), tap outside the panel, or press back.

**The icon engine.** Nothing about any app is drawn by hand or shipped with Prism. The engine runs inside the app on the icons that are on the phone:

- It runs when the drawer is opened. First it asks Android only for the list of apps and when each last changed, which is quick.
- For apps it has seen before, it reads the finished result from disk.
- Only new or updated apps are worked out: outline, cut-out, or picture, as in build 20. The result is saved.
- **Pictures** (icons that cannot be simplified) are now kept as pictures, filling the squircle, but calmed toward the palette: a little less vivid, extremes pulled in, and a light wash of their own colour.
- The first line of the test report now says how many apps were found, how many of each kind, how many were worked out and how many read from disk, and how long it took.

**What to look for**
- First open: tiles show letters for a moment, then fill in with marks. How long does that take? The second open should be immediate.
- Page turn: is it smooth, and is the row-after-row order right, or should all tiles change together?
- Which icons look wrong? The kind (outline / cut-out / picture) matters to me: a screenshot of a bad page is the best report.
- Flicking: does a normal lens drag ever open the drawer by mistake, or does the flick fail to register?

**Checked:** in my preview, with made-up apps: the flick opens the drawer, the panel grows from the button, the grid lays out six rows of four, a swipe turns the page, the X closes it.
**Not checked:** on a phone, and nothing with real icons in the drawer: reading 140 apps, the disk memory, calmed pictures, the speed of the first run. The page turn I have only seen as before and after, not in motion.

## Prism, build 20 (13 November 2026)

**File:** `releases/prism-build-20.apk`

A rule for every icon, so no app can look out of place on a blob. Each icon is tried in this order:

1. **Outline.** If the app supplies its own one-colour outline (most big apps do), that outline is shown in white. This is what Claude, WhatsApp, Instagram and Facebook already used.
2. **Cut-out.** If not, the app looks at the icon's edge. If the edge is one plain colour (the icon's ground), everything that differs from it is kept and turned white, and the ground is dropped. A logo on a plain square becomes a clean white mark.
3. **Coin.** If the edge is not one colour, or the mark covers almost nothing or almost everything, the icon is a picture and cannot be simplified. The real icon is shown as a small round coin in the middle of the blob.

The blob's colour follows the same order: the ground's colour if it has one, otherwise the mark's colour, otherwise the icon's main colour, and always pulled into Prism's palette as before. Icons with no colour at all become slate.

- **moj ZET added as a fifth blob**, as the test case: it has no outline and a plain square icon. It is found by its name on your home screen.
- The top of the test report now lists how each blob was made and its colour, so I can see what your phone actually did.

**What to look for**
- moj ZET: a white ZET mark on a blue that sits with the other blobs. If it shows a letter Z, the app was not found by name; tell me.
- Do the five still read as one family?

**Checked:** in my preview I fed the rule four icons cropped from your screenshot: moj ZET and Mi Fitness and McDonald's became clean white marks on matched colours; the Muay Thai picture correctly fell back to a coin. In a separate dry run on twelve icons from the screenshot, ten cut out cleanly and two (Moj Studenac, Muay Thai) fell back to coins.
**Not checked:** on a phone. The real icon files differ from screenshot crops (true transparent corners, higher quality), which should help, but I have not seen it. Finding moj ZET by name is untested. No animation changes in this build.

## Prism, build 19 (13 November 2026)

**File:** `releases/prism-build-19.apk`

Tighter, more liquid motion, from your notes on build 18.

- **The drop has no tail.** It appears small under your thumb (not above it), swells in the first stretch of the way, and travels home as one shape, pulled slightly long and thin by its own speed.
- **The landing is shorter and hits harder.** It arrives still moving, squashes more (about twice as much as before), and settles in roughly a third of the time.
- **The menu blobs shoot out faster**, and the gap between the leftmost and the rightmost is about half what it was (18 ms per blob instead of 38).

**What to look for**
- Does the drop appear exactly under your thumb?
- Landing: is the squash now enough, and is it over quickly enough? If it reads as a glitch rather than a hit, say so.
- Blobs: is the left-to-right order still just visible, or gone?

**Checked:** it compiles, passes analysis, and stills in my preview of the drop in flight.
**Not checked:** the motion. My preview cannot show it, and these are all timing changes. The numbers are my best judgement and may need another round.

## Prism, build 18 (13 November 2026)

**File:** `releases/prism-build-18.apk`

- **The blob menu opens real apps:** Claude, WhatsApp, Instagram, Facebook. Tap a blob and the app launches. If one is not installed, its blob shows the first letter and tapping it gives a dull thud.
- **Each blob takes its colour from the app's own icon, kept inside Prism's palette.** The app reads the icon, finds the colour it is mostly made of (white, black and grey do not count), keeps that hue, then holds how vivid and how bright it is to the same band as Prism's own blobs, so white on top reads equally on every one. An icon with no real colour becomes slate.
- **The picture on the blob** is the app's own one-colour outline in white, where the app supplies one (the same outline Android uses for themed icons). Otherwise the real icon is shown small in the middle.
- **Round button on Home, "Blobs open real apps"** switches back to Prism's fitness actions. The test switches to the fitness actions by itself while it runs, so the robot cannot open other apps, and switches back after.

**What to look for**
- Do all four blobs look like they belong together and to the rest of the app? Which, if any, looks off?
- Is each one still recognisable as its app at a glance?
- White outline or small real icon: tell me which apps got which, and which you prefer.

**Checked:** in my preview, with stand-in colours and letters: four blobs, colours in one family, tapping does not crash.
**Not checked:** everything that needs a phone: reading the real icons, the white outlines, the colour taken from the real icon, and launching. If a blob shows a letter although the app is installed, tell me which.

## Prism, build 17 (13 November 2026)

**File:** `releases/prism-build-17.apk`

Morphing animations, from your notes on build 16.

- **The drop no longer grows at the bottom.** That was a deliberate "pool" I added; it read as the button appearing twice. Removed. The drop now simply travels the whole way.
- **It starts nearer your finger and smaller.** The glass rides above the finger and is large; the drop used to inherit both. It now begins lower and at about three quarters of the size.
- **It lands like a droplet.** On arrival the button jiggles: wider, taller, wider, dying away. A faster arrival jiggles more.
- **The blob menu shoots out.** Blobs leave one after another, left to right. Each starts tiny, grows as it travels, stays tied to the button by a thread of its own colour that thins and snaps on arrival, and bounces back a little at its resting place.

**What to look for**
- Drop: is the starting point right now, or still too high? Is the jiggle the right amount, or too much or too little?
- Blobs: does the bounce at the top read as liquid, or as a glitch? Is one-after-another too slow when you are in a hurry?

**Checked:** stills in my preview: the menu opens with tiny blobs growing, and the drop starts lower and lands on the button.
**Not checked:** any of the motion. The jiggle and the threads I have not seen at all, only compiled.

## Prism, build 16 (13 November 2026)

**File:** `releases/prism-build-16.apk`

- **The lens comes home as a drop of colour, not as glass.** The moment you let go or dismiss it, the glass is gone. A flat blob in the colour it had (the card's colour if it was a pill, otherwise the button's orange) travels back to the bar, stretching along its path with a short tail. It shifts to the button's orange on the way, pours into a pool that grows where the button lives, the plus draws itself in, and the button lands with a small bounce.
- No glass, blur or shadow is drawn during the return, so those frames are as cheap as the app gets.

**What to look for**
- Does the drop read as one liquid shape, or can you see separate circles in the tail?
- Is the landing a clean hand-over to the button, or is there a visible pop in size or position?
- Speed: too slow, too fast, or right?
- Grab the button again while the drop is still flying: it should become the lens at once.

**Checked:** in my preview the shape, colour change and landing play as described.
**Not checked:** on a phone. My preview draws about seven frames a second, so I have seen stills of this animation, never the motion.

## Prism, build 15 (13 November 2026)

**File:** `releases/prism-build-15.apk`

- **New glass style: Auto, now the default.** The app starts on Original. While you use it, it watches its own frames in blocks of 480 (about four seconds of movement). If more than 15 % of a block is over budget, it switches the bar to Event (solid bar; lens and rest timer stay glass) and remembers that for next launch. It goes back up to Original only if there is clear headroom, and at most once, so it cannot flicker between the two.
- The settings row is now **Auto / Orig. / One / Frost / Event**. Choosing any of the four fixed styles turns Auto off. **Orig.** is the full revert.
- The top of the test report says which style is in use and how many times Auto stepped down.

**What to expect on your S26:** nothing visible. Your phone ran Original at 6.9 % over budget, well under the 15 % line, so Auto should stay on Original. If the bar ever turns solid by itself, the report's action list will say "auto: stepped down" with the percentage; send it to me.

**Not checked:** I cannot make a phone slow on demand, so the step-down has never actually fired. The 15 % line is my judgement from your numbers, not something tested on an S24. Auto does nothing during the test itself.

## Prism, build 14 (13 November 2026)

**File:** `releases/prism-build-14.apk`

- **Fixed: the lens waking cards on its way home** (from your recording). After you let go or dismiss it, the lens flies back to the bar as a plain button. It no longer highlights or explains the cards it passes over.

**What to look for:** park the lens on the workout card, tap elsewhere to dismiss it, and watch the Weight card as the lens passes: it should stay still.

**Not checked:** on a phone, and not in my preview either; this is a two-line change from reading your recording.

## Prism, build 13 (13 November 2026)

**File:** `releases/prism-build-13.apk`

Four glass styles to compare, switchable at any time. **Original is the default and is exactly how build 12 looked.**

Round button on Home, **Glass style**:

- **Original.** The bar and its riding lens are always glass.
- **One (one at a time).** Only one moving piece of glass at once. While you carry the lens the bar turns solid; while the bar's small lens slides between tabs it is a plain highlight and turns back to glass when it stops.
- **Frosted.** The bar still blurs what is behind it but no longer bends it: one drawing pass instead of two. The small lens and the carried lens are unchanged.
- **Event.** The bar is solid always. Only the carried lens and the rest timer are glass.

The test now runs: Full glass (Original), One at a time, Frosted, Event, No glass. Medium, Low and the lights were dropped from the test because your reports showed they differ by 0.2 ms or less; they are still in settings.

**To revert fully:** choose Original. Nothing else changed in this build, and every earlier build is still downloadable.

**What to look for**
- One: does the bar changing as you lift the lens read as a glitch or as intentional? Does the small lens popping back to glass after a tab switch catch your eye?
- Frosted: put Food or Progress behind the bar and scroll. Can you tell it from Original at all?
- Event: does the app still feel like itself?

**Checked:** in my preview each style renders as described, at rest and with the lens out.
**Not checked:** on a phone, and I have no S24. Whether any style is actually faster is exactly what the test will say. Tab switches and sheets, the biggest cost in your reports, are not fixed in this build.

## Prism, build 12 (13 November 2026)

**File:** `releases/prism-build-12.apk`

The test made more trustworthy, after comparing the robot's half with yours in the build 11 report.

- **The robot's finger now moves once per screen refresh** and ends scrolls with a flick, so lists coast as they do under a real finger. Before, it moved on its own timer, which left refreshes with nothing to draw and made scrolling look worse than it is.
- **"Late" is stricter.** A missed refresh counts only if a slow frame came just before it. Missed refreshes with no slow frame are no longer counted as stutter.
- **Each frame is charged to the right action.** Frame times reach the app in batches up to a second late; they are now matched to actions by their own timestamps instead of by arrival time.
- **A warm-up pass that is not recorded**, so one-off first-time costs no longer land on Full glass just because it runs first.
- **The robot covers more:** all four screens (arrive, flick down, flick back), ticking a set on Train, tabs a second time quickly, blobs twice, Weigh-in twice and Log food, the lens over every Home card twice.
- **New in the report:** a grid with one row per action and one column per setting, for the robot and for you, including how long the screen kept drawing after each action (battery).

**How to run it:** same as before. Round button on Home, **Run the test**. It now takes about 5 minutes: roughly 3.5 hands off, then 70 seconds of you.

**Checked:** in my preview the robot did every step under every setting and the grid filled in.
**Not checked:** on a phone. In particular the "kept drawing" times and the new late rule only mean something at real frame rates; my preview draws a frame in about 140 ms.

## Prism, build 11 (13 November 2026)

**File:** `releases/prism-build-11.apk`

The test now runs itself first, then hands over to you. One tap, one report.

- **Part 1, automatic (about a minute).** The app drives itself with the same touch events a finger sends: every tab, the blobs open and closed, the Weigh-in sheet opened and dismissed, Home scrolled down and back, and the lens carried over every card on Home. It repeats that exact script under each of the five glass settings, so every build is measured on identical actions.
- **Eight seconds hands off**, to check nothing draws while idle.
- **Part 2, you (14 seconds per setting).** As before, with the checklist in the banner. This is the real-finger data.
- **One report.** Rows starting `auto` are the robot, rows starting `you` are yours. The report appears by itself at the end.
- **Fixed: the dot left on the calorie ring** in Food when the value drops to zero (from your recording). The ring now fades out as it empties instead of leaving its rounded end behind.

**How to run it:** round button on Home, **Run the test**. Put the phone down while the banner says "Hands off". When it says "your turn", use the app until the report appears, tap **Copy report**, paste it to me.

**What to look for:** during part 1, the app should visibly move by itself. If it sits still or gets stuck with something open, tell me at which setting.

**Checked:** in my preview the robot switched tabs, opened the blobs and the sheet, scrolled and carried the lens under all five settings, and the report had both `auto` and `you` rows.
**Not checked:** on a real phone. Tap positions are computed from the layout, not hard-coded, but your screen is the first real one to run it. I also could not reproduce your zero-ring recording frame by frame; the fix is from reading the drawing code.

## Prism, build 10 (13 November 2026)

**File:** `releases/prism-build-10.apk`

The guided test and its report, improved from what the first two reports could not tell me.

- **A three-second countdown** before recording starts, so the first setting is not short-changed while the settings sheet closes.
- **A checklist in the banner.** Each setting should be tested on the same five things: switch tabs, open the blobs, carry the lens, open a sheet, scroll. The banner's second line lists what is still to do for the current setting and says "All covered" when done. Last time each setting saw different actions, so the settings were not strictly comparable.
- **A hands-off step at the end** (8 seconds). Nothing is touched and the report says how many frames were drawn. A screen left alone should draw nothing; anything more is a battery leak.
- **Battery level, heat and power saving**, read at the start and at the end. A hot phone or power saving slows drawing, which would otherwise look like a regression.
- **Compared with your last run.** The phone remembers the previous guided run; the next report shows late frames, over-budget frames and average draw time per setting next to the earlier values and names the build they came from.
- **First time against every time after.** Each line in "where it stutters" now shows the worst frame the first time the action happened and the worst on repeats. A slow first and fast repeats means a one-off warm-up, not something to redesign.
- **Why it was slow.** Each line says BUILD (working out what to show, which is my code) or DRAW (painting: glass, shadows, size).
- **Coverage section**: for each setting, which of the five things were missed.

The test now takes about 81 seconds: 3 to get ready, 5 settings of 14, and 8 hands off.

### What to test

Run the guided test and follow the banner's "Still to do" line under each setting. This run stores the baseline; the one after it will show the comparison.

### Not checked

- Run in the Linux preview at 2 seconds a step: the countdown, checklist, hands-off step, coverage and first/later columns all appeared. Battery and heat need the phone, and showed blank there. The comparison needs two runs on the same device and was not seen.

## Prism, build 9 (13 November 2026)

**File:** `releases/prism-build-9.apk`

From the owner's guided-test report (Galaxy S26, 120 Hz). Frames that reached the screen late: Full glass 1.9 %, Medium 1.1 %, Low 0.9 %, No glass 0.5 %. The lens over Home's cards and tab changes led the list.

- **The lens no longer rebuilds the whole app when it crosses onto a card.** Each crossing redid every page, the bar and the blobs; that is the "BUILD 8 to 10 ms" in the slow frames. Now only the lens layer changes.
- **Pages are their own layer.** Sliding a page in on a tab change moves a finished picture; before, the page was repainted on every frame of the slide.
- **The round button on Home is solid.** As glass it scrolled with the page, so its backdrop changed every frame and Home ran three pieces of glass where other pages ran two. Home was the slowest screen (18.9 % of frames over budget on Full).
- **The report ranks by late frames**, the ones a person can see, and says so at the top. "Over budget" stays as a second column.

### What to test

Run the guided test again the same way. Compare with build 8: the "lens on ..." lines and the "tab ..." lines should have fewer late frames, and Home on Full glass should be closer to the other pages.

### Not checked

- Nothing here was measured; these are three causes read from the report. The next report is the check.

## Lumen build 23 (13 November 2026)

**File:** `releases/lumen-build-23.apk`

### R56 Widget stacks: a second stack, and editing

- **Two stacks.** The first turns up and down as before. A new one below it turns left and right, with the next widgets peeking out on the right and the dots underneath.
- **Hold a stack to edit it.** It unfolds in place into a list, one row per widget in order:
  - drag a row's handle to reorder (the first row is the widget on top);
  - the minus removes a widget;
  - "Add" chips put in any widget that is not in the stack yet;
  - a switch for "Turn by itself through the day";
  - Done folds it back into a stack.
- A stack with nothing in it shows "Empty stack. Tap to add widgets."
- The four time-of-day buttons from build 21 are gone; the switch now lives in the editor.

### What to test

1. Swipe each stack. Is sideways or up-and-down the more natural way to turn a stack on a page that itself scrolls up and down?
2. Hold a stack, reorder, remove one, add one, Done. The stack should show the new order.
3. Remove everything from a stack.

### Not checked

- Linux preview only: one sideways swipe, and opening the editor. Reordering, removing, adding and the empty stack were not tried.

## Lumen build 22 and Prism build 8 (13 November 2026)

**Files:** `releases/lumen-build-22.apk`, `releases/prism-build-8.apk`

### Lumen 22: R55 Morphing drawer shows your real apps

- On the phone the drawer now lists the apps actually installed, in alphabetical order, with their real icons and names. Each icon is cut to the morphing outline, so the outline still changes shape while one icon fades into the next. Tap an icon to open that app.
- A "Real / Made up" button switches back to the 72 drawn ones.
- Lumen asks Android which apps can be opened from a home screen. It needs no permission prompt for that; nothing leaves the phone.

### Prism 8: a guided test, and a report that points at the cause

- **Guided test.** Round button on Home, then "Run the guided test (70 s)". Keep using the app. Every 14 seconds it switches setting by itself: Full glass, Medium glass, Low glass, No glass, Full glass with background lights. A small blue banner says which one is running and counts down. At the end it puts your settings back and shows the report with a Copy button.
- **The report is ordered by what to fix.**
  1. *By setting*: frames, the share over budget, the share late, average build and draw time, worst frame.
  2. *Where it stutters, worst first*: each line is "setting | screen > action" (for example "Full glass | home > sheet Weigh-in") with how many times it happened, frames over budget, the worst frame, and average build and draw time.
  3. *By screen* under each setting, with frames per second and the 95th percentile.
  4. *Slow frames*: each one with the time, how long it took, whether BUILD (working out what to show) or DRAW (painting it) was the slower half, the setting, the screen and the action it followed.
- **The recorder costs almost nothing.** Per frame it adds a few numbers to two running totals; it makes no text and allocates nothing unless a frame was actually slow. The banner updates once a second.

### What to test

1. Lumen R55 with your real apps: do icons load, does tapping open the app, and is the morph still pleasant with real icons?
2. Prism: run the guided test while doing a bit of everything (tabs, blobs, each sheet, lens over the cards, scrolling), then send the report.

### Not checked

- Real apps cannot be tried in the Linux preview at all: listing, icons and opening are untested.
- The guided test was run in the preview at 2 seconds a step; the report came out right and the settings were restored.

## Lumen, build 21 (13 November 2026)

Two experiments in a new home section, "Launcher ideas" (56 examples in total). Prism is unchanged (build 7).

**Files:** `releases/lumen-build-21.apk`

- **R55 Morphing drawer.** An app drawer that does not scroll. The grid of 24 stays where it is; swipe up or down and each icon turns into the one a page further on. Its outline changes shape, its colour blends, the picture and the name swap. The change runs as a wave, top row first, and follows the finger; let go and it settles on the nearest page. One tick per row that turns over. 72 made-up apps in alphabetical order, with a marker on the right and "A to H · 1 to 24 of 72" underneath.
- **R56 Widget stack.** Several widgets sharing one place. Swipe up or down on the stack to turn to the next; the edges of the others show underneath, and dots show how many there are. "Turn by itself" lets the stack turn to what fits the time of day (the four buttons stand in for the clock).

### What to test

1. R55: drag slowly and watch one row. Then flick. Is it delightful, or does it make an app harder to find than scrolling would? That is the real question for this idea.
2. R55: the frame-rate readout during a drag. All 24 icons redraw every frame.
3. R56: swipe through the four widgets; try the times of day.

### Not checked

- Linux preview only: one drag on each. Flicks, haptics and frame rate are untested.

## Prism, build 7 (13 November 2026)

**File:** `releases/prism-build-7.apk`

- **Weigh-in uses the big ruler** from Lumen R23, with the large number above it, in place of the small dial.
- **Sheets are solid, not glass.** The owner reported that opening the weigh-in sheet is costly. It blurred and bent a third of the screen. Glass is now only on the bar, its lens, the carried lens, the rest timer and the round button.
- **The back button is handled.** It closes whatever opened last (sheet, then lens, then blobs), then goes to Home, and only leaves the app from Home with nothing open. The rules are a table in `PRISM.md`.
- **The report says which action causes stutters.** Two new parts:
  - *Actions, worst first*: every action (each tab, blobs, each sheet, lens lifted, lens on a card, scroll, set tick, food add, habit, back) with how many times it happened, how many frames followed it, how many of those ran over budget, the worst single frame and the average.
  - *Slow frames*: each frame that took more than one and a half refreshes, with the time, how long it took split into build and draw, what was on screen, and the action it followed.
- **`PRISM.md` now lists the kit**: the twelve elements Prism may use and which four are glass.

### What to test

1. Start over, then do each thing a few times: switch tabs, open and close the blobs, open each sheet, carry the lens over the cards, scroll, press back in each state. Copy the report.
2. Back button: with a sheet open, with the blobs open, with the lens put down, on Train, on Home.

### Not checked

- Linux preview only: the weigh-in sheet with the ruler, and the new report sections (they filled in correctly). The back button cannot be pressed in the preview, so its behaviour is untested.

## Prism, build 6 (13 November 2026)

**File:** `releases/prism-build-6.apk`

- **The lens is in Prism.** Drag the button and it lifts off the bar as the magnifying glass from Lumen R51. Home's four cards swell as it approaches and a card names and explains each one.
- **Over something you can act on, the glass becomes a pill with real actions.** Today's workout: Continue (goes to Train). Calories: Log food (opens the food sheet). Weight: Log weight (opens the weigh-in sheet). Let go and the pill stays; tap it to do the thing. Today's list only explains, so the glass stays round there and goes home when you let go.
- A tap on the button still opens the five blobs.
- The test report now has a `+lens` scene and logs which card the lens was on and which action was used.

Any page can offer itself to the lens by wrapping a piece in `LensTarget` (`lib/fit/lens.dart`): a title, one sentence, a colour, and optionally actions. Only Home does so far.

### What to test

1. Drag the button over each Home card. Does each explain itself and, where it should, turn into a pill?
2. Let go on Weight and tap "Log weight"; save a weight.
3. Copy a test report after using the lens for a while: the `home+lens` row shows what the glass costs while it is carried.

### Not checked

- Only the Linux preview: the lens over Weight, the pill, and tapping it to open the weigh-in sheet. The other three cards, and letting go over empty space, were not tried.
- Frame rate with the lens carried. It is the largest piece of refracting glass in the app.

## Prism, build 5 (13 November 2026)

**File:** `releases/prism-build-5.apk`

From the owner's test report on a Galaxy S26 (120 Hz, 8.3 ms per frame): drawing averaged 3.1 to 4.5 ms, 2 to 5 % of frames were late, each screen had a rare spike of 33 to 58 ms, and the app drew about 10,800 frames in 2 h 43 min.

- **Battery: the workout clock no longer redraws a page nobody is looking at.** It redrew the whole Train page once a second on every tab. It still keeps time, but only redraws while Train is showing.
- **Tab changes are lighter.** The page used to fade in, which makes the phone draw the whole page into a separate layer first; this is the likely source of the 33 to 58 ms spikes. It now only slides 14 px.
- **The report says more.** Per scene: how long it was showing, frames per second, and late frames as a percentage. A new "battery" line gives frames per second overall and how much of the time the screen was completely still.

### What to test

1. Start over, use the app for a minute, copy the report. The worst "draw max" on tab changes should be well under 33 ms.
2. Leave Prism open on Home for a few minutes without touching it, then copy: Home should show almost no new frames.

## Prism, build 4 (13 November 2026)

**File:** `releases/prism-build-4.apk`

- **Plain background by default.** The owner's recordings of build 3 showed 119 to 120 frames a second most of the time, with dips to about 101 to 116. The coloured lights are now off unless you turn on "Background lights" in the settings sheet; the background is one flat colour, the cheapest thing a phone can draw.
- **Glass steps down by itself.** On "Auto", if frames are being missed, the glass drops from Full to Medium to Low instead of dropping frames. This existed in Lumen but was never switched on in Prism.
- **A test report you can copy.** Prism now records every frame and files it under what was on screen: `home`, `train`, `train+rest`, `food`, `progress`, with `+blobs` or `+sheet` when those are open. Two ways to copy it:
  - the round button on Home, then **Copy test report**; or
  - with the frame-rate readout on, **tap the readout**.
  The report has the phone model, Android version, chip, screen and refresh rate, the glass setting and what it is actually running at, and for each scene: frames drawn, frames that arrived late, and the time spent building and drawing them (average, 95th percentile, worst). It ends with the last sixty things you did, with times. **Start over** clears it.

### How to use it

1. Open the settings sheet and tap Start over.
2. Use the app as you normally would for a minute: switch tabs, scroll, open the blobs, tick a set.
3. Copy the report and paste it to me.

### Not checked

- The report was read back in the Linux preview and has the right shape. The phone model line needs the Android side, so it showed "unknown device" there; on the phone it should name the device.
- Whether the plain background removes the remaining dips.

## Prism, build 3 (13 November 2026)

**File:** `releases/prism-build-3.apk`

The made-up numbers now agree with each other:

- **Workout order.** Home crossed out bench press yet said "Continue with bench press", and Train called bench press exercise 2. Now: 1) Overhead press is done, 2) Bench press is next, "1 of 5 done".
- **Estimated best.** Progress said 80 kg for one rep while the heaviest set was 80 × 8, which is about 100 kg. Bench is now 100, squat 130 (from 110 × 6), deadlift 150 (from 130 × 5).
- **Period switch.** Month, 3 months and Year changed today's best. Now today's best stays put and only the history behind it changes.
- **Bests per lift.** Squat and deadlift showed bench's bests; each lift has its own now.
- **Food in one place.** The Food page and the quick "Log food" sheet kept separate lists. Both now add to the same meals, so Home, Food and the sheet always agree. "Burned 320", which no total used, is gone.

## Prism, build 2 (13 November 2026)

**File:** `releases/prism-build-2.apk`

From the owner's screen recordings of build 1:

- **Frame rate.** Build 1 ran at about 65 frames a second on a 120 Hz screen whenever anything moved (and about 80 with glass off), so the glass was not the main cost. The likely cause was the wallpaper: each soft light was about a hundred see-through circles, repainted every frame. It is now drawn once, at a quarter of the screen size, and shown stretched. Not measured on the phone yet.
- **Stripes in the wallpaper** are gone (same change), and it is a little darker.
- **The clock and the page title collided** when scrolling. A soft fade now sits under the status bar.
- **"KCAL LEFT" read wrong past the goal.** It now says "KCAL OVER" in red.

## Prism, build 1 (13 November 2026)

A new, separate app: **Prism**, a fitness app prototype in the Lumen design. It installs next to Lumen. Lumen itself is unchanged (still build 20). See `PRISM.md`.

**Files:** `releases/prism-build-1.apk`, `releases/prism-source-build-1.zip` (the whole project: Lumen and Prism share their code)

- **A glass bar with a riding lens.** Four tabs (Home, Train, Food, Progress) in one piece of glass. A lens sits on the current tab and slides to the next with a stretch; a tab brightens as the lens reaches it. Slide a finger along the bar and the lens follows; let go and it settles on the nearest tab.
- **The button in the middle** is one flat colour. A tap splits it into five blobs on springs: Workout (goes to Train), Log food, Scan, Weigh-in, Timer.
- **Quick actions open as a glass sheet** over whatever page you are on. Log food lists three recent foods, one tap each. Weigh-in is a thumb dial and Save. Both change the numbers on Home.
- **Home:** today's workout with its first exercises listed, calories left, weight, and today's list with done or skip.
- **Train:** the workout-in-progress screen with thumb dials. Ticking a set brings up the rest timer as a glass pill floating above the bar.
- **Food** and **Progress:** the day's food, and a chart you can run a finger along.
- **Glass is used sparingly:** only on things that float (bar, lens, the round button on Home, rest timer, sheet). Content is solid.
- The frame-rate readout is off by default; turn it on from the round button at the top of Home.

### What to test on the phone

1. The bar: tap between tabs and watch the lens travel. Then slide a finger along the bar.
2. Does the glass read as glass over the wallpaper and over the cards as you scroll Home under the bar?
3. Tap the button, pick Weigh-in, turn the dial, save. Home should show the new weight and tick "Morning weigh-in".
4. On Train, tick a set. The rest timer should rise above the bar as glass.
5. Turn on the frame-rate readout (round button on Home) and scroll each page.
6. Light mode, from the same sheet.

### Not checked

- Only the Linux preview (mouse, software rendering). I saw all four pages, the lens on each tab, the blobs, the food sheet, and the rest timer. Not tried: sliding along the bar, the weigh-in and timer sheets, the settings sheet, light mode, done and skip on the list.
- How the glass looks on the phone, frame rate, haptics.
- Not in this build: the lens from R51, and any editing.

## Build 20 (13 November 2026)

Three new examples (54 in total) and one fix. Nothing was removed.

**Files:** `releases/lumen-build-20.apk`, `releases/lumen-source-build-20.zip`

### Fixed

- **R47 Demo video: the loop never played.** The clock that drives it was created but never started, so the figure stood still and the cue never changed. My mistake, present since build 15; it now runs.

### New: R52 Lens with blobs (in "The centre button")

A variation on R51, kept separate so both can be compared. Drag the button onto a widget and rest there for 0.3 s: that widget's actions bud out of the glass as blobs on springs, the same kind the button makes. The glass then holds still and the point above your thumb picks: slide onto a blob (it swells, with a tick) and let go to run it. Pull well away and the blobs fold back and the glass follows you again. Over things with no actions it only explains, as in R51.

### New: a "Play" section with two small games, drawn from scratch

Both use a creature I drew in code (a round body, eyes that look around, a mouth, a tuft). No images, no borrowed characters.

- **R53 Treat toss.** A catching game where nothing is captured. A shy creature hops about; you flick a treat upward so it arrives where the creature is. It counts one heart; land it while the creature is mid-jump, mouth open, and it counts two ("Perfect!"). Five hearts and it trusts you: it comes close, smiles, confetti. "Find another" brings the next of four.
- **R54 Card pack.** Swipe across the top of a foil pack to tear it (it ticks as the foil gives). The cards rise out and the pack falls away. Tap a card to turn it over, tap again to keep it; kept cards line up at the bottom. The rim of the stack glows in the colour of the rarity that is coming, the best card is always last, better cards get a moving band of light, and Epic or Legendary gets confetti. Five cards a pack, always at least one Rare.

### What to test on the phone

1. R53: is the flick strength natural? I tuned it by arithmetic, not by hand: a medium upward flick should land at the creature's height. Tell me if treats fall short or sail over.
2. R53: can you time a throw for the jump? Is "two hearts for mid-jump" readable without the instructions?
3. R54: does tearing feel like tearing? Does the glow before a good card build anticipation or spoil the surprise?
4. R52 against R51: which way of getting to a widget's actions do you prefer?
5. R47: the figure should now be moving.

### Not checked

- Only the Linux preview (mouse, software rendering). I saw: the creature hopping and opening its mouth; the pack tearing, cards rising, a card turning over; R52's blobs appearing, one being picked and run.
- **I could not make a throw register with the mouse**, so in R53 the flight, the catch, the hearts and the win are untested. This is the least verified thing in the build.
- Not tried: keeping all five cards and "Open another"; the confetti; R52's fold-back when pulling away.
- Haptics and frame rate throughout. Both games redraw every frame while open.

## Build 19 (13 November 2026)

**Files:** `releases/lumen-build-19.apk`, `releases/lumen-source-build-19.zip`

### Changed: R51 Button and lens, the lens changes shape when there is something to do

The lens now says what kind of thing it is over by its own shape, before you read anything.

- **Round and clear: just looking.** Over something that only has an explanation (the four bar spots, the blobs) it is the round magnifying glass, as before.
- **A coloured pill: something to do.** Over a widget with actions the glass stretches sideways into a pill, takes the widget's colour, stops magnifying, and the actions are written inside it: "Log weight | History". There is a second, firmer tick as it changes. Moving off the widget lets it spring back to round.
- **Let go on a pill** and it stays where it is. It is now the buttons: tap one half to run that action. Tap anywhere else and it flows back into the round button on the bar. You can also drag it away again.
- The card above the lens is now only the name and the sentence; the buttons that were in the card in build 18 are gone, because the lens carries them.

Confirmed on the phone by the owner: the picture inside the glass is the right way up (it was upside down only in my preview).

### What to test on the phone

1. Drag from a bar spot (round) up onto a widget (pill) and back. Is the change of shape readable at a glance? Is the spring on the stretch right, or too lively?
2. Let go on the pill and tap one half. Is it obvious the pill is now two buttons?
3. Kcal left has two actions, Weigh-in has one: compare the wide and the narrow pill.
4. Sweep quickly across all five widgets: the pill changes colour and words each time. Too busy?

### Not checked

- Only the Linux preview (mouse). I tried: round over a bar spot, pill over Weight, let go, tap "Log weight". Not tried: dragging the pill away after putting it down, the one-action pills, quick sweeps.
- Haptics and frame rate. The pill is a wider piece of glass than the round lens, so if frames are missed anywhere it will be while the pill is showing.

## Build 18 (13 November 2026)

**Files:** `releases/lumen-build-18.apk`, `releases/lumen-source-build-18.zip`

### Changed: R51 Button and lens, the lens can be put down

The lens now has two outcomes when you let go, depending on what it is over.

- **Something you can act on** (the five widgets). While you pass over it, the card shows its actions as outlined buttons and the line "Let go here to use these". Let go, and the lens stays where it is as glass, settles onto the widget, and the card stays open with the buttons filled in and pressable. Kcal left: Log food, Scan. Weight: Log weight, History. Weigh-in: Log now. Protein shake: Add to today. Today's list: Add a habit.
- **Something that only has an explanation** (the four bar spots, the blobs), or empty space. Nothing changes: the card is information only, and letting go sends the lens home.

While the lens is put down:

- Tap a button on the card: the action opens as a small window and the lens goes home.
- Tap the lens, or anywhere else: the lens goes home.
- Drag the lens: you pick it up from where it is and carry on exploring.

### What to test on the phone

1. Drag onto the Weight widget and let go. Does the lens staying put feel deliberate, or like it got stuck?
2. Are the outlined-then-filled buttons enough to tell "passing over" from "put down"?
3. Put it down, then pick it up again from where it sits and move to another widget.
4. Let go over a bar spot or a blob: it should go home as before.
5. Still open from build 17: is the picture inside the glass the right way up?

### Not checked

- Only the Linux preview (mouse). I tried: hover, put down, press an action. I did not try picking the lens up again from where it was put down, or tapping it to send it home; those are untested.
- Haptics, frame rate, and whether the thumb covers the card's buttons at the moment you let go.

## Build 17.1 (13 November 2026)

**File:** `releases/lumen-build-17.1.apk`

- R51 Button and lens: the magnifying glass is 12 % larger (96 to 107.5 across). Nothing else changed; the distance at which things react and the height it rides above the thumb are the same.

## Build 17 (13 November 2026)

One new example at the top of "The centre button": R51, the button revised. R50 (the version built from the brief) is kept below it. 51 examples in total.

**Files:** `releases/lumen-build-17.apk`, `releases/lumen-source-build-17.zip`

### New: R51 Button and lens

One button, two jobs.

- **Tap.** The button stays one flat colour. It splits into five solid coloured blobs on an arc, the design from R21, now with the spring mechanics: each blob has its own spring, stretches along its flight, goes slightly past its place and settles; the middle one leaves first and each step outward starts 14 ms later; the button recoils. Closing is quick and does not bounce. Tap a blob to run it.
- **Drag.** After 10 px of movement the button lifts off the bar and becomes glass: the same refracting, magnifying glass as room 1. It rides 62 px above the thumb so the thumb does not hide it, and leaves an empty ring on the bar where it lives.
- **It explains as it goes.** Everything on screen reacts to how close the glass is, continuously: a widget starts to swell and lift from 64 px away and is fully raised when the glass is on it. Once the glass is properly over something, a card appears beside it with its name and one sentence about what it does, with a tick. Move on and the card changes; nothing waits for you to let go. It works on the five widgets, the four bar spots, and the blobs when they are open (tap first, then drag).
- **Let go** and the glass springs home and is a flat button again.

### What to test on the phone

1. Tap: do the blobs feel right now? This is the "Balanced" spring from R50 (stiffness 950, damping 0.62).
2. Drag the button slowly toward the Weight widget and watch it swell before you arrive. Is 64 px the right distance, or should things react sooner or later?
3. Sweep across several widgets quickly. Do the cards keep up, and is one tick per thing right or too much?
4. Tap to open the blobs, then drag the button over a blob.
5. **Look inside the glass.** In my preview the picture inside it is upside down. I believe that comes from the graphics mode my preview uses, which your phone does not, but I cannot confirm it. If the magnified picture is upside down on the phone, tell me; it is a one-line fix.
6. The frame-rate readout while dragging.

### Not checked

- Only the Linux preview (software rendering, mouse, about 15 frames a second). Not checked: how the glass looks on the phone, whether the magnified picture is the right way up, frame rate while dragging, haptics, and whether a thumb covers the explanation card near the top of the screen.
- R51 has no editing; R50 shows that.

## Build 16 (13 November 2026)

One new example, in its own home section "The centre button": my suggestion for the contextual button, built from the brief and from the current `flude_menu.dart` / `glass_button.dart`. 50 examples in total. Nothing was removed.

**Files:** `releases/lumen-build-16.apk`, `releases/lumen-source-build-16.zip`

### New: R50 The button

From the brief:

- One tap and the button splits into a single row of up to five blobs. No second layer, no folders.
- A blob can be an app, a Gym Buddy screen or a quick action. An app keeps its own icon, set behind the glass, and the glass takes a light tint of the icon's colour. A quick action is solid tinted glass in its category's colour (all Food actions are orange).
- Two spots on each side of the button in the bottom bar.
- Editing in place: hold the button. A pencil appears on it; every blob gets a minus and a pencil; an empty "plus" blob appears in the rightmost free slot while there are fewer than five. Tapping a blob opens "What should it do?" with Quick actions, Gym Buddy screens and Apps.
- A quick action opens as a small window over the home screen. An app or a screen grows out of its blob.

Motion (the "Springs" mechanics):

- Every blob has its own spring. It leaves the button stretched along its line of flight, goes slightly past its place and settles. The middle blob leaves first; each step outward starts 14 ms later. The button recoils as it fires. Closing is faster and does not bounce.
- Press the button, slide to a blob and let go: one movement. The blob under the thumb swells and its neighbours lean away from it, with a tick as you cross each one.
- A **Motion** switch at the top compares three tunings: Snappy (stiffness 1500, damping 0.92), Balanced (950, 0.62) and Bouncy (520, 0.45). Tell me which one, or where between two.

My additions (not in the brief; say if you want them out):

- **A suggestion pill** between the button and the row: one action that fits the moment (Morning: weigh-in; Workout: finish set 3; Lunch: log lunch). It is the largest target and the nearest to the thumb. The **Situation** switch at the top changes it; "Off" shows the button exactly as briefed.
- **A ring on the button itself** while a rest timer runs, readable without opening anything.
- **A short label under each blob.** The brief asks for the same icon for actions of one category; with identical icons, Scan and Quick log could not be told apart, so I kept one colour per category and a distinct glyph per action.

### What to test on the phone

1. Tap the button a few times in each Motion setting. Which one feels right for something used all day?
2. Press, slide to a blob, let go. Can you do it without looking? Do the ticks help?
3. Is the suggestion pill useful or in the way? Switch Situation to compare, and to Off.
4. Hold the button to edit. Remove one, add one with the plus, change one.
5. Watch the frame-rate readout while opening and closing quickly, many times.

### Not checked

- Only the Linux preview (software rendering, mouse), which runs at about 15 frames a second: I could confirm positions, order and that everything responds, not how the springs look or feel at 120 Hz. The stretch in flight is the part I could least see.
- The glass here is a single blurred layer cut to the shape of the blobs, not the refracting glass from room 1; that was a choice for speed. If it looks flat on the phone, say so.
- Haptics.

## Build 15 (13 November 2026)

A new home section, "During a workout", with three proposals for the hard parts of a training screen (49 examples in total). Nothing was removed.

**Files:** `releases/lumen-build-15.apk`, `releases/lumen-source-build-15.zip`

### New

- **R47 Demo video.** A demo clip that never takes over the screen. It has three sizes: a small loop beside the exercise name; grown in place (tap it) with a coaching cue, 1× / 0.5× speed, a scrub bar and tap-to-pause, while the sets stay visible underneath; and a floating bubble you can drag to any corner. Ticking a set while it is large shrinks it to the bubble by itself. The clip is a drawn figure, not a real video: Lumen ships no footage.
- **R48 Swap.** "Swap" on the exercise opens a sheet of four alternatives. Three reasons at the top (Equipment busy, Discomfort, Variety) re-rank the list and change the one-line reason under each; the top one is marked Best fit. Picking one turns the card over with your three sets kept and the weight adjusted. Only then does it ask "Just today" or "Every time", with Undo.
- **R49 Edit mid-workout.** No edit mode. Tap a set's badge to step through normal, warm-up (W), drop set (D) and to failure (F); "Add a set like the last"; a minus removes one. In "Up next": drag a handle to reorder, the arrow skips an exercise for today (and brings it back), and the chain between two rows links them into a superset, drawn as a bracket round both. Reordering clears supersets.

### What to test on the phone

1. R47: tap the loop, then tick set 1. Does the video stepping aside by itself feel helpful or presumptuous? Drag the bubble and throw it toward a corner.
2. R47: slide along the bar at the bottom of the large video to step through the movement.
3. R48: open Swap and switch between the three reasons; the order should change. Pick one and watch the card turn. Is asking "today or every time" afterwards the right moment?
4. R49: tap the set badges; tap a chain; drag a handle (the page should not scroll while dragging).

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked, in particular throwing the video bubble and the card turning over.
- A real video would add loading, buffering and battery cost that a drawn loop does not have.

## Build 14 (13 November 2026)

Four more examples at the end of "More patterns" (46 in total). Nothing was removed.

**Files:** `releases/lumen-build-14.apk`, `releases/lumen-source-build-14.zip`

### New

- **R43 Wheels.** Wheel pickers for a rest duration, a time of day (the wheels loop round) and a body weight split into whole kilos and tenths. Each step ticks and the wheel snaps to a value.
- **R44 Plates.** A plate calculator. Dial a weight and a drawn barbell loads itself with colour-coded plates, with "Each side: 25 + 5 + 1.25" in words underneath. Bar of 20, 15 or 10 kg.
- **R45 Progress screen.** A complete progress screen: chips to pick the lift, one headline number with its change, a line chart you can run a finger along (the headline follows your finger, one tick per point), a Month / 3 months / Year switch that reshapes the line, and bests as plain rows. Tagged R45.1 to R45.4. Data is made up.
- **R46 Nutrition screen.** A complete food day: a ring with calories left (turns red and says "over" past the goal), three macro bars, meals where one tap on plus adds the usual item, and eight water glasses. Tagged R46.1 to R46.4. Data is made up.

### What to test on the phone

1. R43: flick a wheel and let it coast. It should tick per step and settle exactly on a value. Do the ticks keep up when it spins fast, or turn into a buzz?
2. R45: slide a finger along the chart. The big number should follow without lag. The page should not scroll sideways or fight you; vertical scrolling from the chart should still work.
3. R45: switch lift and period; watch the line reshape and the frame-rate readout.
4. R46: tap plus on Dinner several times until the ring goes over the goal.
5. R44: drag the dial quickly; plates should pop on and off without flicker.

### Known rough edge

- Rolling numbers that start with a 1 (for example "1 160 kcal left") show a small gap after the 1, because every digit gets the same width so the number does not wobble while rolling.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked. Wheel flicks in particular behave differently under a finger.

## Build 13 (13 November 2026)

Three more examples at the end of "More patterns" (42 in total). Includes the 12.1 fixes. Nothing was removed.

**Files:** `releases/lumen-build-13.apk`, `releases/lumen-source-build-13.zip`

### New

- **R40 Navigation.** Three bottom bars for the same four places, side by side: (A) labels with one pill that travels between tabs; (B) a floating bar with one main action in the middle; (C) a bar where only the selected tab opens its name.
- **R41 Reorder.** Editing a list by hand. Drag a row by the handle on its right; the others spring out of the way with a tick per position. Swipe a row left to remove it: red appears underneath, a tick marks the point of no return, and an Undo row replaces any "Are you sure?" question.
- **R42 Summary screen.** The screen after the last set: a tick that lands first, four numbers that count up once, the one special thing today (a personal best), a one-tap "How did it feel?", and Share plus Done. Tap the tick to replay the entrance. Pieces tagged R42.1 to R42.5. Data is made up.

### What to test on the phone

1. R41: drag a row by its handle up and down the list. Does it stay under your thumb, and do the others move aside without jumping? The page should not scroll while you drag a handle.
2. R41: swipe a row left slowly; you should feel one tick where letting go will remove it. Then Undo.
3. R40: tap through the tabs of A, B and C. Which selection movement do you prefer? That is the answer I need for the fitness app.
4. R42: tap the tick to replay. Thud, then the page rises in order, then the numbers count.
5. The sun/moon in the top right corner, and a two-finger tap anywhere, on any screen.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate, feel, and the two-finger tap were not checked.

## Build 12.1 (13 November 2026)

**File:** `releases/lumen-build-12.1.apk`

- **Fixed: cards repeating on the home screen.** Since build 11, Foundations also listed the first four Patterns cards and Patterns also listed the first four Screens cards. My mistake when adding the new section; each example is now listed once.
- **New: quick light/dark switch on every screen.** A small sun or moon in the top right corner, level with the frame-rate readout. A tap with two fingers together anywhere on the screen does the same. The two-finger tap could not be tried in the preview (mouse only).

## Build 12 (13 November 2026)

Four more examples at the end of "More patterns". Nothing was removed or changed elsewhere.

**Files:** `releases/lumen-build-12.apk`, `releases/lumen-source-build-12.zip`

### New

- **R36 Theme lab.** One small screen restyled live: six accents, corner radius, three spacings, light or dark, and whether the background borrows a little of the accent. The line under the preview states the exact values (for example "accent #9B6BFF · corner 23 · gap 12 · dark, tinted"), so a screenshot carries the recipe.
- **R37 Notifications.** Five ways for an app to speak up, quietest first: a badge; a bottom message with Undo whose background drains as the time runs out; a banner from the top (swipe up to dismiss, or it leaves after four seconds); a stack of three that unfolds on tap; and a polite request before the system permission dialog.
- **R38 Calendar.** History as a month. Dots mark days with a session, today has a ring, one highlight travels between days, the month changes by swipe or arrows, and the day's summary sits underneath. Future days and future months cannot be picked (the month bumps back with a thud).
- **R39 Workout screen.** A complete workout-in-progress screen. Progress through the session and elapsed time; last time's numbers as a hint; set rows with the kg and reps dials; one tap finishes a set; the rest timer then starts by itself as a floating pill (+15 s, Skip); when every set is done, the "Next" button lights up. Pieces are tagged R39.1 to R39.5 with "Show names" on. The session data is made up.

### What to test on the phone

1. R39: tick a set. The rest pill should rise from the bottom without covering a row you need. Does it feel right that it starts unasked? Tick all four: "Next" should wake up with a thud.
2. R39: the dials inside the rows should feel the same as in R23.
3. R38: tap days far apart and watch the highlight travel. Swipe sideways for the previous month; try to go into December.
4. R37: "Archive this session", then Undo before the bar drains. "Show a banner", then swipe it up.
5. R36: move the corner slider end to end and switch spacing; watch the frame-rate readout.

### Not checked

- Only the Linux preview (software rendering, mouse). Haptics, real frame rate and feel were not checked.
- R36 in Lumen's light mode, and all four at a large system text size.

## Build 11 (13 November 2026)

Six new examples, in a new home section called "More patterns". Nothing was removed; rooms 1 to 29 and the bonus are unchanged.

**Files:** `releases/lumen-build-11.apk`, `releases/lumen-source-build-11.zip`

### New

- **R30 Settings screen.** A complete settings screen. Profile header; rows in small groups; controls that work inside the row (a dial for rest seconds, kg/lb, a switch); a back-up row that shows its progress in place; and a "Danger zone" where erasing needs a held press that fills the button, followed by an Undo for six seconds. The Haptics and Reduce motion switches are real and affect all of Lumen. Pieces are tagged R30.1 to R30.5 when "Show names" is on.
- **R31 Number pad.** A keypad of our own for numbers too far to dial. Large live number, +10 / +50 / +100 chips, and a shake with a thud when a key is refused (a sixth digit, or a decimal point on calories).
- **R32 Scan.** A scanning flow with a drawn stand-in for the camera (Lumen does not ask for camera permission). The corner frame closes on the barcode, a result sheet springs up, and a portion dial updates the calories live.
- **R33 Widgets.** A grid of tiles. Long-press one to edit; drag its round handle to resize in whole cells; the minus removes it; "Add a widget" opens a picker. Other tiles spring out of the way.
- **R34 Lists.** A long list: search as you type, filter chips, letter headers that stick, a letter rail on the right to jump with a thumb (one tick per letter), and an empty state when nothing matches.
- **R35 Celebrate.** Three short rewards: a personal best (medal pop, confetti, rolling number), a weekly streak filling in, and a goal ring closing into a tick. Each lasts about a second and then stops.

### What to test on the phone

1. R30: hold "Hold to erase everything". Does the ticking build-up feel like a warning? Let go halfway: it should drain back. Does a quick tap do nothing?
2. R30: while holding the erase button, the page should not scroll.
3. R33: long-press a tile, then drag the handle. Does the size snap where you expect, with a tick each time?
4. R34: slide a thumb down the letters. One tick per letter, and the list should keep up.
5. R35: "Lift 5 kg more". A thud, then three light ticks, in time with the confetti. Watch the frame-rate readout during the burst.
6. R32: watch the readout while the scan line sweeps.

### Not checked

- Everything was checked only in the Linux preview (software rendering, mouse). Haptics, real frame rate, and how any of this feels under a thumb were not checked.
- R31 and R34 with a large system text size.

## Build 10.2 (13 November 2026)

**File:** `releases/lumen-build-10.2.apk`

- R23 Inputs: removed the "step / fine" bubble above the dials. The steps, the haptics, the lift and the turning wheel edge are unchanged.

## Build 10.1 (13 November 2026)

**File:** `releases/lumen-build-10.1.apk`

- R23 Inputs: the kilo dial now moves by 1 kg at normal speed and 0.5 kg when the thumb moves slowly (was 0.5 and 0.1). Reps unchanged: 1, and 0.5 slowly. Nothing else changed.

## Build 10 (13 November 2026)

Lumen as a visual vocabulary: things to screenshot, record or point at. A catalogue of named components, four
complete screens, labels you can switch on, and thumb dials for workout numbers.

**Files:** `releases/lumen-build-10.apk`, `releases/lumen-source-build-10.zip`

### Changed on request

- **R23 Inputs: the set rows are now thumb dials.** Drag a number sideways. Kilos move by 0.5, and by 0.1 when the
  thumb moves slowly; reps by 1, and by 0.5 slowly. Slow means under about 45 px a second for a tenth of a second;
  speeding up past about 160 px a second returns to normal steps (which land on the 0.5 grid again). A bubble above
  the dial says which step is active, a different haptic marks the switch, and the edge of a wheel turns under the
  thumb. A tap on the left or right half steps once.

### New: Screens (a new section on the home screen)

- **R25 Components.** Every control with its id and name printed under it (C01 to C24): buttons, the newer button
  group, split button, FAB menu and floating toolbar, chips, switch, checkbox, radio, segmented picker, slider,
  stepper, search field, list row, badges, progress, tabs, toast, banner. All of them work.
- **R26 Dashboard.** A complete home screen: greeting, summary card with a ring, stat tiles, an action tile, a
  list section, a floating glass toolbar.
- **R27 Detail page.** A hero picture with parallax, title block, fact chips, highlights, and a floating glass
  action bar.
- **R28 Assistant.** An AI chat: thinking state, an answer that streams, numbered citations, a sources list and
  the reasoning as fold-outs, a generated card with an action, suggestions, and a send button that becomes stop.
  Prepared answers only; it says so.
- **R29 Onboarding.** Three swipeable steps whose illustration morphs with the swipe, progress dots, skip, and a
  finish state.
- **Show names.** The tag button at the top right of R26 to R29 draws a blue label on every piece (for example
  "R26.3 Stat tile"), so a screenshot names what it shows.

### What to test

1. **Dials:** change a weight quickly, then slow right down. Is the switch to 0.1 at the right speed, or does it
   trigger too easily or too late? Same for reps.
2. **Show names:** switch it on in the Dashboard and take a screenshot. Are the labels useful, too many, too big?
3. Scroll the Detail page: the picture should move slower than the text.
4. Assistant: tap a suggestion; try Stop mid-answer; open "How I worked this out" and the sources.
5. Components: press everything in "Newer button patterns".

### Not checked here

Feel, haptics and frame rate. The two glass bars (R26.6, R27.5) were only seen on my software renderer.

## Build 9 (13 November 2026)

Lumen becomes a reference library: every example has an id, and there are six new "Patterns" rooms.

**Files:** `releases/lumen-build-9.apk`, `releases/lumen-source-build-9.zip`

### New: the reference system

- Every room has a stable id (R01 to R24, B01 for the bonus), shown as a small chip next to the room number.
  Tap the chip: it copies a line with the id, the name, what the example shows and its source files, ready to
  paste into another chat.
- `REFERENCE.md` in the source lists every id with its files and a short "how to reuse" note.
- `lib/reference.dart` is the same index in code.

### New: Patterns

- **R19 Performance lab.** Three cases (shadows, live blur, an idle animation), each built the costly way and the
  cheap way. A button runs a 3 second test and reports frames drawn, average build and raster time, the slowest
  frame and missed frames, from the engine's own timings on the device.
- **R20 Launcher.** A home screen: long-press an icon and drag, the others make room on springs; hold it over
  another icon to make a folder; tap a folder to open it, long-press an app inside to take it out; a dock; an
  "All apps" drawer with search.
- **R21 Blob menu.** One button splits into three, four or five actions on an arc. Tap, or press, slide and
  release in one movement. Labels are placed so they cannot collide.
- **R22 Timers.** A rest timer that stores its end time, wakes once a second, and stays reachable as a pill when
  you scroll away. Pause, resume, add or remove 15 seconds.
- **R23 Inputs.** A weight ruler (drag or flick, a tick per half kilo, resistance at the ends), steppers that
  repeat while held and speed up, and workout set rows with a tick.
- **R24 Do and don't.** Four mistakes next to their fixes: spinner and skeleton, confirm and undo, vanishing and
  persistent labels, small and proper touch targets.

### What to test

1. Tap an id chip in any room, then paste somewhere: is the line useful as it is?
2. **Performance lab:** run Shadows and Blur, costly then cheap. Send me a screenshot of the results table; these
   are the first real numbers for those effects on your phone.
3. **Launcher:** drag an icon across the grid; make a folder; open it; take an app out; open All apps and search.
4. **Blob menu:** press the button, slide to an action and release without lifting in between.
5. **Timers:** start one, scroll down, tap the pill. Lock the phone for 20 seconds and come back: the time should
   be right.
6. **Inputs:** flick the ruler; hold a plus button.

### Not checked here

Feel, haptics and frame rate. The Performance lab's numbers on my machine come from a software renderer and are
meaningless; I only checked that the test runs and reports.

## Build 8 (12 November 2026)

Fixes from testing, plus a new home section, "Foundations": six rooms on the basics.

**File:** `releases/lumen-build-8.apk`

### Fixed

- **Haptics everywhere.** Every haptic (dial notches, lens tick, toggles, dance floor)
  now drives the vibration motor from native code, like the disco beat. Three strengths:
  tick, click, thud. They play even in silent mode; Settings has a new Haptics switch.
- **Foil cards.** The card now tilts away from your finger, as if you pressed it down
  there (it used to lift toward the finger). Dragging on the card no longer scrolls the
  page. The glare sits near your finger. Starlight's stars no longer sit on a grid.

### New: Foundations

- **13 Type.** One article, with hierarchy on or off. Pick a scale ratio and every size
  re-derives from it. Line-height slider.
- **14 Space.** A contact card built from one base unit (4, 8 or 12). Switch grouping off
  to see why distance matters. Grid overlay.
- **15 Contrast.** Sliders for text and background with the live contrast ratio and pass
  marks. A colour-blindness simulation shows why status needs more than colour.
- **16 States.** A button in its six states. A screen that loads with a skeleton and
  ends as content, empty or error.
- **17 Forms.** Floating labels, checks as you type, errors only after you leave a field,
  password strength, a button that shakes and shows what is missing.
- **18 Sheets.** Rows you swipe away with Undo. A bottom sheet with three resting
  heights you can drag or flick.

### What to test

1. Dials: do you feel the notches now? Too strong, too weak?
2. Foil: does tilting feel natural now? Try "Tilt with the phone" again.
3. Forms: type in the fields with the keyboard open. Nothing should be hidden.
4. Sheets: flick the sheet up and down; swipe a row away and undo.

## Build 7.1 (12 November 2026)

**File:** `releases/lumen-build-7.1.apk`

- **Feel the beat** now drives the vibration motor directly from native Android code
  with a heavy "thud" (or the strongest effect the phone supports), and plays it as
  media vibration so silent mode should not mute it. It previously used the lightest
  system tick, which Samsung phones can play very faintly or skip when no finger is on
  the screen.
- **Smoother opening and closing:**
  - All custom shaders are prepared off screen while the app starts, instead of on
    their first use inside a room.
  - Every open and close holds still for about 25 ms (three frames) before moving, so
    the expensive first frame of a new screen happens before anything is in motion.
    A back swipe still continues immediately.
- **Measured, not guessed:** after each open and close, the readout shows how many
  frames were missed during it ("Open: 0 missed frames" in green, otherwise yellow).

### What to test

1. Disco room, Party mode on, Feel the beat on: is the beat strong and regular now?
   Try once with the phone in silent mode and once in vibrate or sound mode.
2. Open and close several rooms, especially Glass, Shaders and Flow. Note the numbers
   in the readout. A screenshot of a yellow one tells me where to look next.

## Build 7 (12 November 2026)

The last three trend rooms. All twelve rooms and the bonus are now in.

**File:** `releases/lumen-build-7.apk`

### What is new

- **Room 09, Colour.** Pick one of six pictures. The phone renders it small, groups its
  pixels into five colour clusters (k-means, written for this app) and picks a seed: the
  largest cluster that is also colourful. Material's colour engine then grows the seed
  into a full scheme, and a sample screen plus every colour role glide to the new
  colours. Four scheme styles: Calm, Vibrant, Playful, Faithful.
- **Room 11, Data.** A line chart that morphs between Week, Month and Year (the line
  reshapes and the scale slides rather than redrawing). Drag across it: a magnetic
  cursor snaps to each day with a tick, and the headline number rolls to that day's
  value. Below, bars grow in a wave; tap one to focus it.
- **Room 12, Access.** The same small screen four times: standard, 170% text, high
  contrast and reduced motion. "Play" triggers the same action on all four: the
  reduced-motion one changes in place with a fade instead of bouncing. Switches show
  what a screen reader announces (numbered, in order) and outline every touch area.
- Fixed: progress fills were invisible on the Foil card stats and the Live pill music bar.

### What to test

1. **Colour:** switch pictures and styles quickly, mid-animation. Colours should glide,
   never flash.
2. **Data:** scrub slowly over Month: about 30 ticks across the chart. Too many?
3. **Access:** turn on "Show what a screen reader says". If you have time, turn on
   TalkBack in phone settings and swipe through the standard panel: it should read the
   same list.

## Build 6 (12 November 2026)

Home gets a second section, "Trends, part two", with six new rooms. Three of them are in
this build; Colour, Data and Access follow in build 7. Discomorphism moves to its own
Bonus section at the end. Each new room opens with one or two lines on the trend it shows.

**File:** `releases/lumen-build-6.apk`

### What is new

- **Room 07, Foil.** Collectible cards with a holographic foil drawn by a shader:
  rainbow bands that shift with the angle, a moving glare, and per-card patterns
  (diffraction lines, flashing stars, a mosaic). Drag on the card to tilt it in 3D. Or
  switch on "Tilt with the phone": the app reads the gravity sensor directly (no
  library) and the card follows the phone.
- **Room 08, Dials.** A volume knob with 40 notches: a tick per notch, a heavier thud at
  each end, rubber-band resistance past the ends. Flick it and it coasts, then settles
  into the nearest notch. The shading stays put while the knurled edge turns, like a
  real knob under a fixed light. Below it, an alarm set with 3D wheels that click.
- **Room 10, Live pill.** A black status pill on a lock-screen mock. Start a timer,
  music or a call: the pill grows to show it. With two activities the second one
  splits off into its own bubble. Tap the pill to open it into controls; tap the
  background to close. "Notify" shows a short-lived notification. A call opens by
  itself and takes priority.

### What to test

1. **Foil:** drag slowly across the card. With "Tilt with the phone" on, rock the phone.
   Is the effect convincing, too strong, or too weak?
2. **Dials:** turn slowly and count the ticks; then flick hard. Does it feel like a real
   knob? Is the haptic too busy?
3. **Live pill:** start Timer and Music, then Call. Watch the bubble split off and the
   pill reshape. Answer and decline a call.
4. The lock-screen background in the Live pill room and the Flow pages may show a hard
   edge in their gradient on my preview. Tell me if you see that on the phone.

## Build 5 (12 November 2026)

Adds a bonus room: Discomorphism.

**File:** `releases/lumen-build-5.apk`

- **Discomorphism** (bonus card at the bottom of home). A mirror ball drawn live by a
  shader: about 900 flat tiles, each reflecting three circling coloured spotlights and a
  white key light, with random glints. Its light spots sweep across the walls as it
  turns. Chrome headline with a sweeping highlight, a Party mode button tiled with tiny
  mirrors, and a dance floor in perspective that lights up under your finger.
- **Party mode:** the ball spins faster, colours come up, the floor lights to a 120 BPM
  beat, and with "Feel the beat" on the phone pulses a light haptic on every beat.

### What to test

1. Swipe across the dance floor: tiles should light where your finger is, with a tick per
   new tile.
2. Party mode on, phone in your hand: does the haptic beat feel like a beat or like noise?
3. Watch the readout with Party mode on.

## Build 4.1 (12 November 2026)

**File:** `releases/lumen-build-4.1.apk`

- Fixed: the like counter showed misaligned digits (for example "1276") when the phone's
  text size is larger than default. Digits are now measured at the phone's text size.
- Same fix for the Copy/Copied label and the rolling suggestions in the prompt bar.
- Test: tap like several times quickly; the digits should always land on a clean number.

## Build 4 (12 November 2026)

Adds Room 06 (Details). All six rooms are now in.

**File:** `releases/lumen-build-4.apk`

### What is new

- **Room 06, Details.**
  - **Fluid type:** the headline is drawn letter by letter. Its weight thins as you
    scroll down; scrolling fast condenses the letters and sends a wave of weight
    through them, which wobbles out on a spring when you stop.
  - **Pull to refresh:** a ring fills as you pull, turns into a coral shape with a tick
    once you have pulled far enough, becomes a loader, then a check. A new message opens
    up space for itself at the top of the inbox.
  - **Prompt bar:** suggestions roll through the empty field. The send button turns from
    a round grey button into a coral square when you type. Sending starts a light that
    runs around the bar, then the answer streams in word by word, and labels (AI draft,
    sources, check before using) fade in at the end. The four suggestions have their own
    answers; anything you type gets an honest "demo reply" answer.
  - **Small things:** a like button with a burst and a rolling counter; a copy button
    that turns into a confirmation and actually copies text.

### What to test

1. **Pull to refresh:** pull slowly. Feel for the single tick when it arms. Pull a bit,
   then release before the tick: nothing should happen.
2. **Headline:** from the top of the room, flick the page up and down. Watch the
   letters during and just after the flick.
3. **Prompt bar with the keyboard:** tap the field and type. The bar should stay visible
   above the keyboard. Send with the button and with the keyboard's send key.
4. **Like:** tap repeatedly and quickly. The digits should roll, not jump.

## Build 3.1 (12 November 2026)

**File:** `releases/lumen-build-3.1.apk`

- Springs room: removed the target marker (ring and cross) behind the balls. Tapping still sets where both balls go.

## Build 3 (12 November 2026)

Adds Room 04 (Flow) and Room 05 (Shaders), and predictive back on every screen.

**File:** `releases/lumen-build-3.apk`

### What is new

- **Predictive back everywhere.** With gesture navigation, swiping back makes the
  current screen shrink, round its corners, drift with your finger and reveal the
  screen underneath. Let go early or drag back and it springs open again; finish the
  swipe and it flies back into the card it came from. With the back button, the same
  closing animation plays on a spring.
- **Room 04, Flow.** Six story cards in a two-column grid. A card grows into a full page
  (the page itself grows out of the card, not just a window into it). Back puts it
  back into its slot. The room shows which navigation mode the phone is using.
- **Room 05, Shaders.** Three full-screen exhibits, switched with a glass bar:
  - **Aurora:** domain-warped noise at full resolution, six noise layers. Touch swirls
    and pulls it.
  - **Ripple:** tap or drag. Real text and shapes are bent and lit by up to six waves.
  - **Blur:** a progressive blur at the top, sharp at its lower edge and fully blurred at
    the top, computed in one pass with 56 samples per pixel.
- Shader exhibits follow the quality setting: Auto starts at Full and steps down if
  frames are missed.

### What to test

1. **Back with the button**, from every room: it should close into its card on home.
2. **Back with gestures:** switch the phone to gesture navigation (Settings, Display,
   Navigation bar, Swipe gestures). In every room, swipe slowly from the left or right
   edge, hold, move up and down, then let go. Try once releasing early (should spring
   open again) and once completing (should fly into its card).
3. **Glass room with the back swipe:** the glass must stay aligned with its outline
   while the page shrinks.
4. **Flow:** open each card and go back. The card's slot should stay empty while it is
   open, and the card should reappear exactly as the page lands.
5. **Flow page header:** on my preview renderer, tall colour gradients show a hard
   horizontal edge. If the landscape at the top of a story page is cut off by a straight
   line on your phone, tell me.
6. **Shaders:** watch the readout in each exhibit, especially Aurora while touching and
   Blur while scrolling fast. If a "Glass lowered" notice appears, note which exhibit.

### Known limits

- Settings are still not remembered between launches.

## Build 2 (12 November 2026)

Adds Room 02 (Springs) and Room 03 (Shape morph). Rooms 04 to 06 are still placeholders.

**File:** `releases/lumen-build-2.apk`

### What is new

- **Room 02, Springs.** Two balls get exactly the same input. The top one moves the
  classic way (420 ms, ease in-out); the bottom one is a spring.
  - Tap to move the target. Tap again before it arrives.
  - Drag on empty space to drag the target around continuously.
  - Grab a ball (both are caught where they are), move it, then throw it.
  - Four spring presets: Bouncy, Natural, Snappy, Gentle. The plot under them shows
    position over time for the curve and the chosen spring.
  - Haptic tick when the spring ball settles. The curve ball gets none.
- **Room 03, Shape morph.** All shapes are hand-built and morph by blending outlines.
  - Hero shape: tap to step through eight shapes, or drag sideways to scrub; release
    and it springs to the nearest shape, with a tick when it lands.
  - Toggles: round when off, squircle when on, squeeze on press.
  - Send button: becomes a circle with a morphing loader, then a green tick, then
    returns to a pill.
  - Three loading indicators that spin while changing shape.

### What to test

1. **Springs, interruption:** tap one spot, then quickly tap another before the balls
   arrive. The top ball should visibly stop and restart; the bottom one should curve
   smoothly into the new direction. This is the whole point of the room.
2. **Springs, drag the target:** drag on empty space. The top ball should lag and crawl;
   the bottom one should follow fluidly.
3. **Springs, throw:** grab the bottom ball and flick it. It should fly in the direction
   of the flick before coming back. The top ball ignores the flick.
4. **Shape morph, scrub:** drag sideways slowly over the shape, then flick. Every
   in-between frame should be a clean outline, with no kinks or flicker.
5. **Send button:** tap it and watch the whole sequence. Does the timing feel right?
6. **Frame rate:** the Shape room keeps animating because of the loaders, so the readout
   shows fps there all the time. Note the numbers.

### Known limits

- Same as build 1: back does not follow the finger yet, settings are not remembered.

## Build 1 (12 November 2026)

First build: home screen and Room 01, Glass. Rooms 02 to 06 are placeholders.

**File:** `releases/lumen-build-1.apk`

### What is in it

- Home: bento grid of six rooms. Glass opens; the others shake to say "not yet".
- Room 01, Glass: a colourful feed with glass only on the controls.
  - Navigation bar whose selection indicator is a lens you can drag or throw.
  - Two round glass buttons (back, tune) and a tuning panel.
  - Clear-to-tinted slider, quality picker (Auto, Full, Medium, Low), solid fallback switch.
  - Four feeds. Paper is nearly white on purpose: it is the hardest case for glass.
- Settings (top right on home): theme, reduce motion, reduce transparency, glass quality, frame-rate readout.
- Frame-rate readout at the top of every screen, on by default.

### How it is built

- Flutter 3.50, Dart 3.14, `material_ui` 1.11 (no deprecated imports), Impeller.
- Glass shader, spring system and controls are hand-written. No community UI packages.
- Glass is two passes: the engine blurs what is behind the control, then the shader bends,
  tints and lights it. Quality tiers: Full (refraction, colour split, rim light), Medium
  (lighter refraction, no colour split), Low (blur and tint only), Solid (opaque).
- In Auto, quality steps down by itself if more than about 12% of frames are missed for
  two seconds running, and a notice appears above the bar.

### What to test

1. **Readout when idle.** It should say `idle · 120 Hz`. If it says 60 Hz the phone is not
   giving the app its fast display mode.
2. **Does the glass look like glass?** Rim light on the edges, content bending near the
   rim, slight colour fringes on the lens. If any glass is black, offset from its outline,
   or upside down, switch quality to Low and tell me. This is the one part verified only
   on a software renderer here, not on a real phone GPU.
3. **Drag the lens** slowly, then throw it. It should follow the finger with a little
   weight, stretch when fast, and land on a tab with one haptic tick as it settles.
4. **Scroll the feed** under the bar while watching the readout: fps and `missed`.
5. **Tune panel:** move the slider end to end; try each quality tier; try Solid fallback.
6. **Paper feed:** are the bar labels still readable over white?
7. **Open and close the room** several times, including pressing back mid-opening.
8. **Light theme and Reduce motion** in Settings.

### Known limits

- Smoothness, haptic strength and shader cost are unverified on a real device.
- Back uses the system gesture but does not yet follow the finger (that is Room 04).
- Settings are not remembered between launches.
- The readout updates about once a second; it shows `idle` when nothing is moving.
