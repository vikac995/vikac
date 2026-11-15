# Handover: Prism, after build 171 (15 November 2026)

Read this first in a new chat. Then **`DESIGN.md` (the design rules: every agent follows them)**,
`PRISM.md` (the product), the top of `CHANGELOG.md` (what each build did), and only then the code.
Everything below was agreed with the owner of the project.

**Where the work stands:** step 1 of THE PLAN (below) is **done** and accepted in review: build 170, report
`reviews/step1-report.md`. Build 171 ("step 1b") then fixed what the first phone run of the button test
showed (report `reviews/step1b-report.md`). Build 172 ("step 1c", `reviews/step1c-report.md`) is about
messages from the Sidekick reaching a *second* copy of Prism: Prism is the home activity, and a launch
by an ordinary intent (app icon, recents, Prism's own `openPrism`) can make a second `MainActivity`
with its own engine. Android's line to Prism now follows the copy on screen; the test report lists
every engine. Build 172's phone run confirmed two copies and passed 485 of 485. Build 173 ("step 1d",
`reviews/step1d-report.md`) makes it one: **every way Prism brings itself forward goes through
`PrismScreen.bringForward()` (`PrismScreen.kt`), and the app icon goes through `PrismLauncher`; never
start `MainActivity` by name anywhere else.** It also counts every cache in the test report, to find
the native memory growth (about 57 MB a round). Build 173 passed 485 of 485 on the phone with one
engine; step 1 is closed. Build 174 ("step 1e", test only, `reviews/step1e-report.md`) adds the **leak
test** (testing panel: everyday steps done 20 times, memory read every 5; `tools/preview/test.sh
leak`). Its phone run found the growth: a font weight that moves with an animation (the two-way
pickers' labels, the tab bar's labels) makes a new font in the text engine on every frame, kept for good.
Build 175 ("step 1f", `reviews/step1f-report.md`) draws every weight in steps of 10 and runs the leak test
again as a bisect. **Never let a font's weight, or any other font variation, follow an animation: use
`LumenType` (it rounds weights with `LumenType.steady`) and never build a `TextStyle` with `fontVariations`
by hand. `LumenType`'s `opsz` follows the size, so don't animate a `LumenType` size either; scale the text
with a `Transform` instead.** Next: 175's phone results, then step 2. Tasks are in `tasks/`; each ends with a
report in `reviews/` that is reviewed before the owner relies on the work. The preview scripts are in
`tools/preview/` (see its README).

## Who you are working with, and how

- The owner has a product background and is **not a developer**. Explain in plain language. Never ask them
  to edit code; do all of it yourself.
- Every change ships as a **full release APK** with a commit-pinned download link (see "Building and
  shipping"). Be direct and short. Always say what was checked and what was not. Never claim something
  feels smooth: it is only ever checked in the preview, on a computer, or on their phone by them.
- Keep `CHANGELOG.md` up to date for every build: what changed, what to look for, what was checked and not.
- **Be very careful with the code; keep backups** of a file before a large edit (the scratchpad is fine).
- If they write STOP, stop, and answer before building anything. When they ask to "explain before
  implementing", do exactly that.
- Their vision: "An app designed to keep you on track and get out of your way." Smooth, battery-light,
  nothing running when nothing is happening. Elements behave the same way everywhere, with the same haptics.
  Intuition over innovation: people should do what they are used to, and it should just work.
- They test every build on a Galaxy S26 (120 Hz, Android 17) and send screen recordings and the flight
  recorder's report ("WHAT HAPPENED ..."), which ends with "YOUR NOTE:".

## Hard rules (never break)

- Git: only add or change files under `lumen/`, only on branch `claude/flutter-ui-showcase-ngzfru`, in the
  public repo `vikac995/vikac`. Never touch other files or `main`. No pull requests unless asked.
- Never commit or share keys or tokens (the Cloudflare band-worker key, the GitHub token), the owner's
  email, or any personal data. No signing keystore in the repo.
- RepDB: its raw data and images never go into this public repo or any public place; no AI restyling, no
  RepDB images into generative models; never share the RepDB order id; its licence is personal.
- No Athlean-X content or wording. No Dragon Ball lookalikes. Prism's looks must not copy the Pink Floyd
  album cover or the Polaroid logo.
- The Gym Buddy project is separate and private (`/home/user/gym-buddy-redesign`), never in this repo.
- No model names or ids in commits, code or files.
- Play Store safety: no accessibility service. The usage-access permission still needs a policy check.
- Games: original ones in a genre only, never a recreation of a specific existing game.

## Names

- **Prism**: the centre button in the bottom bar (the glass with the coloured triangle) and its blob menu.
- **Sidekick**: the floating button that goes with you over other apps (and in Prism), with its own menu.
- **Blobs**: the round buttons that come out of either.
- **Glass**: the magnifying glass you lift off Prism's button.

## THE PLAN: separate the Sidekick from Prism (agreed; step 1 done in build 170)

The owner's words: "Editing Sidekick menu should make the user feel like they are not editing the Prism."
"They now work as separate entities, right?" They do not yet. This is the next work, in four builds, each
self-contained, each tested, each leaving everything working.

### Why (what is tangled now)

1. On Android the Sidekick is the old floating "lens" (`class Floater` in `MainActivity.kt`, ~6,600 lines
   in that file) with a `guest` flag. The same class runs the workout timer (`TimerBubble`) and still has
   the dropped modes: pinned blobs (`pin`, `mode() == 2`), hand-placing, docking. ~50 places ask
   timer-or-Sidekick, ~80 deal with the old modes.
2. Its blob list lives in Prism: `BlobSlots` (`lib/fit/apps.dart`) has a main list and a `_side` list that
   mirrors main until changed, and `show(side: true)` switches which one Prism's own blob code edits.
   Anything in Prism that runs meanwhile edits the wrong menu.
3. Every Sidekick edit is done by Prism: Android sends `editSlot`, `sideSettings`, `sideRemove`,
   `blobOrder` to Prism, which comes forward and reuses its own screens. Hence: the Sidekick's settings
   grow out of Prism's button, Prism's triangle turns, and after Add, Prism's blobs open.
4. Its look, colours, labels and distances are Prism settings (`Apps.sideLook/sideVivid`,
   `BlobSlots.sideNames`, `RestBubble.sideGap/sideTuck`) sent across. `shell.dart` (~9,900 lines) has ~90
   references to Sidekick state.

### What separate means

- **One small blob-menu model used twice**: up to five blobs; change, add after, remove, close up (empties
  always last, the rest together in the middle). Prism has its own; the Sidekick has its own. No switching.
- **The Sidekick owns its screens, on Android, over whatever app is open**: its menu, its small menus
  (Change | Remove | Add on a blob; Edit Sidekick | Add Blob on the empty space), its settings panel, and
  its own app list for Change and Add. Android lists apps itself (PackageManager). It may still show the
  Prism-style icons Prism draws, but only as finished pictures sent one way.
- **The Sidekick keeps and saves its own settings** (Android SharedPreferences). Prism only reads them for
  the flight recorder's SETTINGS lines.
- **The Sidekick and the timer become separate classes**; the dead pinned / hand-placing / docking code is
  deleted (also the old edit screen's unused code in `shell.dart`: `_editing`, the swipe places across the
  top, the `_EditMark` minus/pencil marks, `_cog` morph if unused).
- **What remains between them, one way each**: Prism -> Sidekick: icon pictures, Prism's colour and theme,
  "come out". Sidekick -> Prism: "open this Prism page or action" (when one of its blobs is one), recorder
  lines.

### The four builds

1. **Separate the menus. DONE in build 170** (`SidekickMenu.kt`; report `reviews/step1-report.md`). The
   Sidekick's list moves to Android (saved there); `BlobSlots` keeps only
   Prism's; the `show(side:)` switching, `_sideKey`, `_pickSide`, `putSideAll`, `sideAsMain` go. Migrate the
   saved side list (`prism_blobs_side`) once. The Add/Remove mix-ups stop here.
2. **The Sidekick's own settings panel**, drawn by Android over the current app: look (the six looks are
   already drawn natively in `BlobLooks.kt`), Mellow | Vivid, Labels Show | Hide, In this app / Over other
   apps, the two distance sliders (smooth, the Sidekick moves live as they are dragged, the panel clears
   while one is held). Glass-switch style, like Prism's.
3. **The Sidekick's own app list** for Change and Add, over the current app.
4. **Split the Sidekick from the timer** and delete the dead code.

Risk: this is Android code the preview cannot run. The **button test** (below) is how each step is checked
on the owner's phone; extend its Sidekick half as you go.

## What happens now on Prism's button (keep all of this working)

- Tap: blobs out / in. Two-finger swipes are set in Prism's settings.
- Hold the button (Android's hold time x 0.85): Prism's settings. They open and close on the app list's own
  springs (`_SpringPanel` in `shell.dart`: `Motions.snappy` to open, `Motions.spatialFast` to close),
  growing out of the button; the triangle turns half a turn meanwhile; the panel sits above the button; a
  tap on the button, beside it, the X or back closes it.
- Hold a blob: small menu Change | Remove | Add (green, when there is room). Remove: the others close up in
  the middle at once. Add: the new blob goes right after the held one. Change: the list titled "Change ...",
  the button becomes that blob meanwhile, red Remove in the list.
- Hold the empty space with the blobs out: Edit Prism | Add Blob (green). Add Blob goes at the right end.
  (Not a third "Sidekick" item: that was a misunderstanding and was removed.)
- An empty menu: one "+" blob; the button keeps its look in the light's own colours.
- Looks: Pearls, Petals, Lotus, Beam, Halo, Window (default). Triangle-shaped looks are centred by where
  their corners are (`BlobSign.triangleNudge`). Window, Petals keep their colours still while they turn.
- The triangle turns a sixth with the blobs out, half for the app list and the settings, on
  `Motions.spatial`, no overshoot.

## Open questions waiting for the owner's answer (do not build before they answer)

1. **Back closing the Sidekick's blobs while a keyboard stays open.** Since 167 the blobs' window does not
  take focus (keyboard stays, back goes to the app underneath). Proposed: a focusable window marked as not
  the keyboard's target (`FLAG_ALT_FOCUSABLE_IM`) so both work. Unconfirmed on a phone; one line.
2. **Glass vs app list, the doubled buzz** (their recording: "lens lifted" then "drawer open"). Proposed:
  count the 140 ms "down a while" from when the finger starts moving, not from touch-down; and give the
  lift's buzz only once the lift is certain.
3. **Bringing the Sidekick back when it was dismissed.** Proposed: no button; while the blobs are out it
  peeks at the edge where it was last left, tucked; tap or pull to bring it out.
4. **A "Mirror" quick action** (front camera). Proposed an in-app mirror page (camera permission) as a
  quick action; or opening the phone's camera on the front lens (unreliable across phones).
5. **Setting a two-finger swipe by making it** inside Prism's settings (as the old edit screen allowed).
6. Results of the **button test** from the phone (start it: hold any blob, Change, the first item
  "Button test"; or the frame-rate panel's test list). It has never run on a phone; its Sidekick half may
  have wrong expectations.

## Older backlog

Graphics memory (Prism still gets restarted by Android at 830-930 MB; the recorder now says why, after
each restart); a performance / quality slider with two extreme modes, set automatically on first install;
tooltips on every option before testers (with usage logging); the Play policy check for usage access; music-
reactive blob / rhythm minigame (after memory); workout timer flow; notes; share sheet.

## Building and shipping

```
export PATH=/opt/sdk/flutter/bin:$PATH ANDROID_HOME=/opt/sdk/android
cd /home/user/vikac/lumen
# Android-side compile check only:
(cd android && ./gradlew :app:compileReleaseKotlin -Pfit=1 --console=plain -q 2>&1 | grep -E "^e:|error")
# Version: bump Diag.build in lib/fit/diag.dart ('Prism build N') and pubspec.yaml version.
ORG_GRADLE_PROJECT_fit=1 flutter build apk --release --target-platform android-arm64 -t lib/fit/main.dart
cp build/app/outputs/flutter-apk/app-release.apk releases/prism-build-N.apk
# Only upload if the APK really is build N:
[ "$(unzip -p releases/prism-build-N.apk lib/arm64-v8a/libapp.so | strings | grep -c 'Prism build N')" -ge 1 ] && echo NAME-OK
# then git add (CHANGELOG.md, pubspec.yaml, lib, android/app/src/main/kotlin, the apk), commit, push,
# H=$(git rev-parse HEAD), and give the link
# https://github.com/vikac995/vikac/raw/$H/lumen/releases/prism-build-N.apk  (check it answers 200).
```

Always print the link from `$H` in the same command (a wrong commit id was pasted once and gave a 404).
The owner pauses Play Protect to install. The disk allowance is small: old local APKs are removed with
`git update-index --skip-worktree` first (they stay on GitHub).

## Testing in the preview (Linux build, no Android side)

```
flutter build linux --release -t lib/fit/main.dart
export DISPLAY=:99 GDK_SCALE=2 LIBGL_ALWAYS_SOFTWARE=1 FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller=true
pgrep Xvfb || (Xvfb :99 -screen 0 824x1830x24 &)
# The long test (expect 65 of 69: 3 Android-only measurements and one flick timing check miss):
PRISM_LONG_TEST=1 timeout 590 build/linux/x64/release/bundle/lumen > long.log &
# size the window: xdotool search --onlyvisible --name lumen | head -1 -> windowmove 0 0 windowsize 824 1830
# then wait for "CHECKS:" in long.log.
# The button test, one round (expect 68 of 69; the miss is an Android-only measurement); its report is
# written to /tmp/prism_long_test.txt, not to the log. (PRISM_BUTTON_TEST=3 runs three rounds.)
PRISM_BUTTON_TEST=1 timeout 420 build/linux/x64/release/bundle/lumen &
```

Screenshots: `scratchpad/f.sh out.png "<xdotool commands>"` with `NOBUILD=1` (window 824x1830 = 412x915
points x 2; Prism's button at 412,1738). The preview's saved state lives in `/tmp/prism_*` files.
The "hold, then carry" checks sometimes miss once from timing; run again before believing them.
