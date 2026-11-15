# Step 1 report: the Sidekick's own menu (build 170)

Task: `tasks/STEP1-separate-menus.md`. Branch `claude/flutter-ui-showcase-ngzfru`, based on
`origin/claude/flutter-ui-showcase-ngzfru` at `b6d8734`.

In one paragraph: the Sidekick's list of blobs now lives on Android, in a new object
`SidekickMenu` (`android/.../SidekickMenu.kt`), saved in SharedPreferences. Remove and
reordering happen there alone. Change and Add still use Prism's app list, as a chooser only: Prism
is told what is in the place, shows the list, and sends the chosen key back; Android puts it in.
Prism keeps no Sidekick list. It keeps only the last keys Android told it, read-only, to draw their
pictures (sent one way) and for the settings report. The first start of build 170 moves the old list
over once.

## 1. Every file changed

| File | What changed |
|---|---|
| `android/app/src/main/kotlin/dev/lumen/lumen/SidekickMenu.kt` | **New.** The Sidekick's menu: five keys, saved, with Remove, Change, Add-after, reorder, the one-time move, and the pictures from Prism. |
| `android/app/src/main/kotlin/dev/lumen/lumen/MainActivity.kt` | The `blobs` handler became `sidekickPictures`; new handlers `sidekickKeys`, `sidekickAdopt`, `sidekickChosen`; the menu's Remove and drag-to-reorder call `SidekickMenu` instead of messaging Prism; Change/Add send `sidekickChoose` (was `editSlot`) with the current key; `Floater.blobs` is now set only through `setBlobs()`; the test report (`state`) includes the stored menu; new test steps `sidekick` and `leave`; `front` also removes the keep-awake speck. |
| `lib/fit/apps.dart` | `BlobSlots` holds only Prism's list: the side list, the switching and the side file are gone. |
| `lib/fit/bubble.dart` | `tellBlobs` replaced by the Sidekick channel calls: `tellSidekickPictures`, `sidekickKeys`, `sidekickAdopt`, `sidekickChosen`. |
| `lib/fit/shell.dart` | Prism sends pictures for the keys Android tells it; the one-time move; the app list as a chooser for the Sidekick (pseudo-place 200); the Sidekick's list editing removed; the button test's Sidekick half rewritten; the dead edit screen's Prism/Sidekick switch removed. |
| `lib/fit/diag.dart` | `Prism build 170`. |
| `pubspec.yaml` | `0.131.0+198`. |
| `CHANGELOG.md` | Build 170 entry. |
| `releases/prism-build-170.apk` | The build. |
| `reviews/step1-report.md` | This report. |

## 2. Removed from Prism's code

`lib/fit/apps.dart`, `BlobSlots`:
- `_side` (the side list), `_showSide`, `side`, `sideOwn`, `sideAt()`, `show({side})`, `sideAsMain()`,
  `putSideAll()`, `_sideFile` (`prism_blobs_side`).
- In `load()`: reading `prism_blobs_side`. In `put()` / `putAll()`: the branches that wrote the side
  list. `keys` is now simply Prism's list.
- Kept on purpose: `sideNames` (the Sidekick's Labels Show | Hide). It is a setting, not the list;
  the settings move in step 2.

`lib/fit/shell.dart`:
- `_sideKey()`, `_pickSide`, `_showMenu({side})` and every call to it (in `_setEditing`, `_setOpen`,
  `_setDrawer`).
- The `editSlot` handler's list editing (it inserted an empty place into the side list for Add).
  It is replaced by `sidekickChoose`, which only records what Android asked.
- The `sideRemove` handler and the `blobOrder` handler, entirely.
- `_sendBlobs()` (which built the Sidekick's menu from the side list, slot numbers and the "+" blob
  included). Replaced by `_sendSidekick()`, which sends pictures only, for exactly the keys Android
  told. The "+" for an empty menu is now made by Android.
- The two `_sendBlobs()` calls after Prism's own blobs were dropped back or a pin changed (they were
  there because the Sidekick used to mirror Prism's list; it no longer does).
- In the old edit screen (reached only with `_editing`, which nothing sets to true any more): the
  "Prism | Sidekick" switch (`menuMain` / `menuSide`) and "Same as Prism" (`menuSame`). The rest
  of that dead screen is left for step 4, as the plan says.
- In the button test: `sideKeys()` (read the side list), `BlobSlots.instance.sideAsMain()` and
  `putSideAll()` calls.

## 3. The new Android class: `SidekickMenu`

**What it stores:** five keys (`app:<package>`, `action:<n>`, `screen:<n>`, `phone:shade`,
`phone:side`, or `empty:`), always with the blobs together and the empty places last. Also whether it
has a menu of its own yet, and what was moved over the one time.

**Where:** SharedPreferences `prism_sidekick`:
- `keys`: the five keys, one per line;
- `moved`: what was taken over from Prism at the one-time move (for the button test's note).

The presence of `keys` is what says "Android owns it". In memory it also holds the pictures Prism last
sent, by key (not saved).

**What it does:** `remove(slot)`, `put(slot, key)` (Change; `empty:` removes), `addAfter(slot, key)`
(only while there is room), `arrange(slots)` (drag-to-reorder: the places the blobs were in, as they
now stand), `adopt(keys)` (the one-time move, ignored once it owns a list), `pictures(...)`,
`testPut(keys)` (button test only). After every change it saves, rebuilds what the Sidekick shows
(`Floater.setBlobs`: each place whose picture has come, in order, each knowing its place; one "+"
when all are empty), and tells Prism the keys. Before the one-time move (no menu of its own yet) it
shows nothing, not even the "+", and ignores every change, so nothing can be saved that would stop the
move; the move itself is written with `commit()` (at once), because Prism deletes its old copy right
after.

**Every message about the Sidekick's list now** (all on the `lumen/device` channel):

| Name | Direction | Carries | When |
|---|---|---|---|
| `sidekickKeys` | Prism → Android (a question) | nothing; answered with the five keys, or null if Android has no menu of its own yet | at every start of Prism |
| `sidekickAdopt` | Prism → Android | the five keys the Sidekick showed until now; answered with the keys Android now has | once: only when the answer above was null (the first start of 170) |
| `sidekickKeys` | Android → Prism | the five keys | every time the Sidekick's menu changes, and after the move |
| `sidekickPictures` | Prism → Android | for each of those keys (no duplicates): key, kind, index, package, notesFor, name, colour, badge colour, picture flag, PNG | each time Prism is told the keys, and when pictures may have changed (apps' icons arrived, look/labels changed) |
| `sidekickChoose` (was `editSlot`) | Android → Prism | slot, add (true for Add / Add Blob), back (Prism came forward only for this), key now in that place | Change or Add on a Sidekick blob, after bringing Prism forward |
| `sidekickChosen` | Prism → Android | slot, add, the chosen key (`empty:` for the red Remove in the list) | when something is chosen; nothing is sent if the list is closed without choosing |

Gone: `blobs` (Prism → Android, the whole menu), `sideRemove` and `blobOrder` (Android → Prism).
Unchanged, and still Prism's settings until step 2: `blobNames`, `blobLook`, `blobVivid`
(sent along with the pictures).

Test only, through `lensTest`: `sidekick` (set the Sidekick's menu for the test, and put the person's
own back), `leave` (put another app in front and leave it there; `front` brings Prism back).

## 4. How each "Done means" item was checked

### 1. No Sidekick list in `BlobSlots`, no code in `shell.dart` that edits one

```
# The BlobSlots class only (from "class BlobSlots" to its end), every line that says "side":
$ awk '/^class BlobSlots/,/^}/' lib/fit/apps.dart | grep -ni side
5:  // Prism's own menu: what each of its five places holds. (The Sidekick has a menu of its own,
6:  // kept by Android: see SidekickMenu.kt. Nothing here is the Sidekick's.)
24:  /// The same for the Sidekick's blobs: its own choice.
25:  bool sideNames = true;
27:  File get _sideNamesFile => File('${_file.parent.path}/prism_blob_names_side');
29:  void setNames(bool v, {bool side = false}) {
30:    if (side) {
31:      sideNames = v;
36:      (side ? _sideNamesFile : _namesFile).writeAsStringSync(v ? '1' : '0');
67:      sideNames = _sideNamesFile.readAsStringSync().trim() != '0';
69:      // Never chosen for the Sidekick: as Prism's are.
70:      sideNames = names;
# (Besides the comment saying the list is not here: only the Sidekick's Labels setting, sideNames, which step 2 moves. No list.)

$ grep -nE "_sideKey\b|_pickSide|_showMenu|sideAsMain|putSideAll|sideOwn|sideAt\(|BlobSlots\.instance\.(side|show)\b|tellBlobs|_sendBlobs" lib/fit/*.dart
(nothing found)

$ grep -nE "call.method == '(editSlot|sideRemove|blobOrder)'" lib/fit/*.dart
(nothing found)

$ grep -nE "\"(editSlot|sideRemove|blobOrder|blobs)\"" android/app/src/main/kotlin/dev/lumen/lumen/*.kt
android/app/src/main/kotlin/dev/lumen/lumen/MainActivity.kt:2043:        m["blobs"] = blobs.size
# (That one line is the test report's count of blobs shown, not a message.)

# Every place Prism's copy of the Sidekick's keys is written: only from what Android sent.
$ grep -nE "_sideKeys\s*=[^=]" lib/fit/shell.dart
428:  List<String> _sideKeys = const <String>[];
1777:    _sideKeys = List<String>.unmodifiable(keys);
```

In `shell.dart` the only things left about the Sidekick's list are: `_sideKeys` (written only in
`_sidekickTold`, from what Android sent), `_sideAsk` (what Android asked to choose for), and the
one-time move `_sidekickStart`, which reads the old file and Prism's list once and hands them to
Android.

### 2. The preview tests

Run from `lumen/` after `flutter build linux --release -t lib/fit/main.dart`.

**The button test** (`tools/preview/test.sh buttons`), expected 62 of 63. First run:

```
CHECKS: 61 right, 2 wrong, of 63
  WRONG  flick: a flick up opens the app list, and not the settings
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
```

The flick miss is a timing check in the slow preview (in that run the script also failed to size the
window: "There are no windows in the stack"). Second run, as the README says:

```
CHECKS: 62 right, 1 wrong, of 63
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
```

The one miss is the Android-only measurement. The report's settings line reads
`side menu: not told by Android yet` in the preview, as it should with no Android side. Every
`clean:` check now also reports "for the Sidekick false". The Sidekick half was skipped ("Prism is
not allowed over other apps"), as always in the preview.

**The long test** (`tools/preview/test.sh long`), expected 65 of 69. One run:

```
CHECKS: 65 right, 4 wrong, of 69
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
  WRONG  blobs out: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
  WRONG  app list open: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
```

The usual four: three measurements only Android can make, and the flick timing check (a 90 ms flick
in the software-drawn preview; it watches the magnifying glass, nothing about the Sidekick).

**After the review fixes (section 6), both were run again on the final code**, the one in the APK:

```
button test:  CHECKS: 62 right, 1 wrong, of 63
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
long test:    CHECKS: 65 right, 4 wrong, of 69
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
  WRONG  blobs out: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
  WRONG  app list open: measured  [no answer (MissingPluginException(No implementation found for method lensTest on channel lumen/device))]
```

The analyser (`flutter analyze lib/fit`) gives the same 4 notes as before the change (three
`prefer_final_fields`, one `use_build_context_synchronously`, all in code not touched here), and
`dart format` leaves the changed files as they are.

### 3. The button test's Sidekick half

Rewritten for the new ownership. It cannot run in the preview (Prism is not allowed over other apps
there; the half is skipped with a note), so **none of these checks has run yet**. What it checks on the
phone, in order:

- `sidekick: its menu is Android's own, five places, the empty ones last` (the person's own menu,
  before the test touches it).
- A note with what was moved over at build 170's first start.
- `sidekick: Prism has been told its keys, and keeps no saved copy of them` (Prism's copy equals
  Android's; `prism_blobs_side` is gone).
- `sidekick: it shows every blob of its own menu, in order` (after the move, the same blobs show).
- The test then sets the Sidekick's menu to `action:4 action:3 action:2 action:1 screen:0` (Prism's is
  `action:0`..`action:4` during the test), so it can tell which menu changed. The person's own is put
  back at the end of the half, and again at the very end of the test whatever happened.
- Unchanged checks: a tap opens its blobs; as many blobs as its menu has; holding a blob brings its
  small menu; a tap beside it puts the small menu away.
- **Remove, over another app** (the usual stand-in app, when one is found; otherwise in Prism, with a
  note): `Remove takes that blob out of its own menu, and the others close up`; `Remove over another
  app leaves that app in front: Prism is not brought forward` (Prism not in front, Prism not asked to
  choose, no list up); `Remove leaves Prism's menu as it was, and its blobs as they were`; `Prism has
  been told its keys again, only for their pictures`.
- **Add, closed without choosing:** `Add brings Prism's list, only to choose for the place after it`;
  `while Prism's list is up for it, Prism's triangle does not turn`; `closed without choosing, both
  menus are as they were and Prism's blobs do not open`.
- **Change, choosing the first thing:** `Change brings Prism's list, only to choose for that blob, and
  the button wears it meanwhile`; `what was chosen is in that place of the Sidekick's menu, and only
  there`; `chosen, Prism's blobs do not open`.
- **Add, choosing the first thing (new):** `Add puts what was chosen right after the held blob, in the
  Sidekick's menu only`.
- Unchanged: settings, the two distances, moved first, let go low, carried to the bottom.
- `with nothing in its menu, it holds one plus` (now set through Android); `its own menu is back as it
  was before the test` (new); `Prism's menu is the same after all of it` (new).

How the old checks changed: the old ones read the side list from `BlobSlots` (`sideKeys()`,
`_sideKey(0)`, `BlobSlots.instance.side`, `_pickSide`); they now read Android's stored menu from the
test report (`sidekickKeys`) and the chooser state (`_sideAsk`, `_editSlot == 200`). The old "Change"
check compared `action:0` with a menu that already had `action:0` in that place, so it could not fail;
the test menu now starts without it there. The old "closed without choosing" check expected Prism's
menu "shown again"; it now expects Prism's blobs not to open. `clean(...)` checks `_sideAsk == null`
instead of `!_pickSide`. No check was loosened or deleted.

### 4. Both sides compile; build 170; NAME-OK; link; changelog

- **Compiles, both sides:** `./gradlew :app:compileReleaseKotlin -Pfit=1` gives no errors;
  `flutter analyze lib/fit` gives no errors or warnings (the four old notes above).
- **Build 170:** `lib/fit/diag.dart` says `Prism build 170`, `pubspec.yaml` `0.131.0+198`. Built with
  `ORG_GRADLE_PROJECT_fit=1 flutter build apk --release --target-platform android-arm64 -t
  lib/fit/main.dart`, from the final code (after the review fixes). The first attempt failed with
  "429 Too Many Requests" from Maven Central while Gradle checked its artifacts; the retry built.
- **NAME-OK:** `unzip -p releases/prism-build-170.apk lib/arm64-v8a/libapp.so | strings | grep -c 'Prism
  build 170'` is 1 or more: NAME-OK. Its Android code has the new messages (`sidekickPictures` found
  in its `classes.dex`). sha256 `87edd236c307449270bf874587c83337dd2e652ecb2f3bdef3282026f0e992ea`.
- **Link:** LINK_RESULT
- **Changelog:** the build 170 entry at the top of `CHANGELOG.md`.

## 5. Not checked, and what to try on the phone

Not checked anywhere: everything on Android. The move of the saved list, Remove, Change, Add, Add
Blob and dragging on the Sidekick, the pictures arriving, and the button test's Sidekick half have
never run. In the preview the Android side does not exist.

On the phone, step by step:

1. **Before installing**, open the Sidekick's blobs and note which blobs it shows, in order.
2. Install build 170 over 169. Open the Sidekick's blobs: **the same blobs, in the same order.**
3. Hold one of the Sidekick's blobs, **Remove**, over WhatsApp (or any app): the Sidekick's blobs
   close up; the app stays in front; Prism does not appear. Go to Prism: its own blobs are as before.
4. Over an app, hold a Sidekick blob, **Change**, choose something: Prism's list comes up titled
   "Change ...", the button shows that blob; after choosing, you are back in the app and the Sidekick
   has the new blob in that place. Prism's own blobs are unchanged and did not open.
5. Over an app, hold a Sidekick blob, **Add**, choose something: it is right after the blob you held.
6. Hold the empty space round the Sidekick's blobs, **Add Blob**: the new one is at the right end.
7. Do 4 inside Prism (the Sidekick over Prism): after choosing, Prism's own blobs stay in, and the
   triangle did not turn while the list was up.
8. Drag one of the Sidekick's blobs to another place: the new order stays after closing and reopening,
   and after restarting the phone.
9. Remove all of the Sidekick's blobs: one "+", and Prism's menu is untouched. Tap "+" and add one.
10. Run the **button test** (hold any blob, Change, "Button test") and send the report. Its Sidekick
    half runs for the first time on the phone; I will read its misses with that in mind.
11. Copy the flight recorder's report: the SETTINGS line "side menu:" should list the Sidekick's keys,
    and the recorder should have a line "Sidekick: its menu moved to Android (from ...)".

## 6. What I was unsure about, and what I chose

- **Remove closes the Sidekick's blobs, as before.** In Prism, Remove keeps the blobs out while the
  others close up. On the Sidekick, Remove has always closed its blobs. The task says not to change
  how anything looks or moves, so it still closes them; the list closes up at once, and they are
  together when opened again. Making it stay open like Prism is a separate, visible change: say if
  you want it.
- **Prism's triangle and Prism's blobs while choosing for the Sidekick.** The task asks for both, so
  the triangle no longer turns while the list is up only for the Sidekick, and Prism's blobs no longer
  come out afterwards (before, inside Prism, they did). The button still wears the Sidekick's blob
  meanwhile, as before.
- **How the list knows it is choosing for the Sidekick:** a pseudo-place, 200, the same trick as the
  two-finger swipes (100 to 103). Everything that names or draws a blob (the list's title, the red
  Remove, the button wearing the blob) works for it unchanged, and it only reads the key Android sent.
- **The one-time move is done by Prism, not Android**, because only Prism knows what an unset place
  meant (its defaults are the five apps by the packages the phone really has them under, known once
  they are looked up). It waits for that look-up, sends the list once, and deletes `prism_blobs_side`
  only after Android has answered. Android takes it only if it has no list yet, so it can never
  replace a list Android already owns. Empty places in the middle of an old list are moved to the end
  (nothing shown changes: empty places are never shown).
- **A key Prism cannot draw is kept but not shown**, as before: `phone:side` ("Sidekick") can be
  chosen for a Sidekick place, and Prism has never drawn a picture for it there, so it did not show
  before and does not now. It still takes a place. Not changed; worth deciding in step 3.
- **Keys of apps from the app list:** if the Sidekick has one and Prism's own menu has none, Prism now
  reads the app list once so it can draw it (before, that picture could be missing until the app list
  was opened).
- **The button test now leaves the person's Sidekick menu as it was.** Before, it reset it to Prism's
  list for good (`sideAsMain()`). To do that it sets the Sidekick's menu through a test-only step.
- **Not changed, noticed:** choosing "Button test" while choosing for the Sidekick over another app
  sends Prism back behind that app before the test starts (as in 169).
- `BlobSlots.sideNames`, `Apps.sideLook/sideVivid` and `RestBubble.sideGap/sideTuck` stay in Prism for
  now: they are the Sidekick's settings, which step 2 moves.

**A second read.** Because none of the Android side can run here, I had the change read once more,
separately, against the task (code only, not my notes). It found no mistake in the messages, the list
operations or the test's expected lists, and four edge cases, all fixed before the build:

1. The button test put the person's Sidekick menu aside by its length, which is always five; had the
   one-time move not happened, it would have saved an empty menu as Android's own and stopped the move.
   It now puts aside only a menu Android reports as its own (`sidekickOwn`), and without one it does
   not touch the Sidekick's menu at all (it says so in a note).
2. Before the move, Android showed a lone "+" (all places empty), and using it would have saved a menu
   and stopped the move. Before the move it now shows nothing and ignores changes; the move is written
   at once (`commit()`).
3. The test's `leave` step left its keep-the-screen-on speck behind if the other app was slow to come
   to the front. Prism is now brought back (`front`, which removes the speck) whenever `leave` worked.
4. If Android already had a menu and the old `prism_blobs_side` was still there (a crash between the
   move and the delete), it was never deleted. It is now deleted at any start once Android has a menu.
