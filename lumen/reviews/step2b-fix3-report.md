# Step 2b fix 3 report: the S26's one missed tap (build 182)

Brief: `tasks/STEP2b-fix3.md`. Asked for in 181, but 181 was already pushed (`8db28c0`), so it is 182,
on top of 181. Exactly the two items: the investigation, and the check's explanation when it fails.
Nothing in the app's behaviour changes: one recorder line is added, and the button test reports more.

## Files changed

| File | What changed |
|---|---|
| `android/.../SidekickMenu.kt` | Notes when Prism was last told the keys, and when its pictures last came. A recorder line when they come: "Sidekick: Prism's pictures came, for n of its m blobs, N ms after it was last told the keys". Test state: `sidekickPicturesFor`, `sidekickToldAgo`, `sidekickCameAgo`. |
| `android/.../MainActivity.kt` | `Dot.testTouch()`: the test state adds `attached`, `pressed`, `menuTouch`, `sized`, `settingsHeld`, `ignoring`, `panelTouch`. |
| `lib/fit/shell.dart` | Part 4's `openMenu()` keeps what the tap left; `whyNot()` writes it out. "sidekick: a tap opens its blobs" and "sidekick: over another app, a tap opens its blobs" give it when they are wrong. |
| `lib/fit/diag.dart`, `pubspec.yaml` | Build 182, `0.143.0+210`. |
| `tasks/STEP2b-fix3.md`, `CHANGELOG.md` | The brief; build 182. |
| `releases/prism-build-182.apk` | The build. |

## 1. Why that one tap didn't open the blobs

**Short answer:** most likely a timing race with the step before: the Sidekick had no blobs yet. Not a
`pressed` left set by the old raise, and probably not the Dot off the screen. This is from reading the
code. The S26's report alone can't prove it: it doesn't say what the tap did, and its recorder has no
line for when the pictures came. The recorder lines that would settle it are below.

### What the code does at that moment

1. **The step before** (`op: 'sidekick'`, `SidekickMenu.testPut`) gives the Sidekick the test's menu:
   `action:4 action:3 action:2 action:1 screen:0`.
   - `changed()` shows it at once.
   - `show()` shows only the places whose picture it has.
   - `pictures` holds what Prism last sent, for the person's own menu. Prism's next message replaces it
     whole.
   - So for the test's menu, where every key is new, the Sidekick has **no blobs at all** until Prism
     answers.
2. **Prism is told the keys** and draws the five pictures one after another (`_sendSidekick` awaits each
   `_blobMap`). It sends them in one message once all five are drawn.
3. **The test waits** 900 ms (the op's settle) plus 600 ms, then taps.
4. **A tap with no blobs does nothing:** `tapPinned` opens the menu only `if (there && container &&
   blobs.isNotEmpty())`. Otherwise it goes to `usePinned`, which returns at once for the Sidekick's own
   sign. No menu, nothing in the report, and everything after it in that round goes wrong. That's
   exactly the S26's cascade: "0 shown, 5 in its menu", then "the lens's menu is not open".
5. **Every round runs this same race.** The person's own menu is put back at the end of the part, so
   the next round switches every key again. The S25 won it four times out of four, and so did the S26
   three times. Once, the S26's pictures probably took longer than about 1.5 s.
   - The S26's larger graphics memory (560–590 MB against about 390) may make drawing them slower.
     That's a guess: nothing in the report times it.

### Why it isn't the old raise (180) leaving `pressed` set

- **180 only took the window off with no finger on it.** `raise()` checked `fingerOn()` (that is,
  `pressed`), and otherwise waited for the finger to lift. Then it ran posted after the UP, which had
  already cleared `pressed`. Nothing in it sets or keeps `pressed`, `menuTouch` or `sized`.
- **A stuck `pressed` wouldn't stop a tap anyway.** DOWN sets it afresh, and the tap's path never reads
  it. What could swallow one tap is a `menuTouch`, `sized` or `panelTouch` left from a touch that
  never ended (they are checked before DOWN resets them). The raise didn't touch any of them.
- **The order of the parts doesn't fit either.** The raise was in part 5, after this check in each
  round. A state it left would show in rounds 2–4. And since every round raised, it would most likely
  show more than once.
- **So option (a) in 181 doesn't fix this as a side effect,** because the raise wasn't the cause.

### Why probably not "the Dot not attached"

- The test's touches go straight to the view. Even off the screen, its touch code would run, and the
  menu would still open (from `getLocationOnScreen`).
- In 180 it could only have come off through a raise that failed half way. The recorder would then say
  "could not be put above its panel".

### What would confirm it, in the S26's 180 recorder

Around that round's "sidekick tapped":

- **Seen:** `blob: sending sidekickKeys to Prism #n`, `blob: Prism #n answered sidekickKeys`, then
  `blob tapped: opens … (thinks … is in front)`. That's the no-blobs path: the race.
  - The "answered" comes when Prism has received the keys, not when the pictures are sent. So in 180
    nothing marks the pictures' arrival.
- **Not seen:** `blob tapped in its own app: opens the menu` followed by `blob menu opened`. If those
  are there, the menu opened and something closed it, and my answer is wrong.
- **No "tapped" line at all:** the touch was swallowed (a stuck `menuTouch` or `sized`, or the panel's
  touch). Again, my answer would be wrong.

## 2. The check now says why, when it is wrong

**"sidekick: a tap opens its blobs"** (and its "over another app" twin, which uses the same tap) now
writes, when wrong:

```
menu open no (0 blobs in it); window on the screen yes, shown 1.0; guest yes, pressed no,
menu touch no, two-finger size no, held for settings no, ignoring no, panel touch no,
panel open no; tucked no, roaming no, moving no, docked no, closing no; blobs to open 0 ( ),
pictures for 0 of 5 of its blobs, keys last sent to Prism 1561 ms ago, pictures last came
48210 ms ago; Prism in front yes; its last touch: down at …; lens at …; a tap; Prism in front
true, thinks nothing is in front; so it opens …
```

(The shape only. The numbers here are made up to show it.)

- **The race:** "blobs to open 0", "pictures for 0 of 5", and the keys sent more recently than the
  pictures came.
- **Each other cause** shows as its own flag:
  - not on the screen;
  - a touch left half done (`pressed`, `menu touch`, `two-finger size`, `held for settings`, `ignoring`,
    `panel touch`);
  - tucked, moving or docked;
  - the panel still open;
  - a tap that Android couldn't make at all.
- **When right,** the check writes nothing extra.

## What 182 doesn't do (for you to decide)

- **The test still taps after 1.5 s.** The obvious test fix: wait until `sidekickPicturesFor` reads
  "5 of 5" (up to a few seconds), and note how long it took. I didn't add it, per "nothing else".
- **The same gap can reach a person, rarely.** After a Change or Add, the new blob shows only once its
  picture comes. Only a menu where every blob is new has nothing to open meanwhile, which a person
  can't make in one step. Nothing to change now. Worth knowing for step 3.

## Where I could be wrong

1. **The cause is read from the code, not seen.** The S26's report doesn't give the tap's own line,
   and its recorder has no line for when the pictures came. If the recorder shows "opens the menu" or
   no "tapped" line, it was something else. 182's check would then say what.
2. **"Prism's pictures take over 1.5 s once on the S26" is an assumption.** If they never take that
   long, the race can't be it. 182's recorder line now times each arrival, so the next report shows
   how long they take on both phones.
3. **`isAttachedToWindow` is read on Android's main thread** with the rest of the state, just after
   the tap's settle. A window that came back in between would show as on the screen.

## Results (preview, on the final code)

```
button test:  CHECKS: 67 right, 1 wrong, of 68
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 62 right, 4 wrong, of 66 (the usual 4)
```

- **Analyser:** the same 4 old notes. Kotlin compiles.
- **Not run in the preview:** the check itself and the new state, which are Android's.

**Build 182:** `Prism build 182`, `0.143.0+210`, built from the final code. Name `Prism`, package
`dev.lumen.prism`. Its `classes.dex` has the new recorder line ("pictures came"), and its `libapp.so`
has the new explanation ("pictures last came"). sha256
`fc413fa5dc7143c0fdcfe9c0d9857b2fbf71e61b88f341210d0f59e42144f436`, 18,665,722 bytes. Link (checked: answers 200, same sha256): https://github.com/vikac995/vikac/raw/5eaf4af9ea1482347f621e5dac0797c0961a5171/lumen/releases/prism-build-182.apk

## For the owner on the phone

- **Install 182 over 181.** It looks and behaves the same: 181's no-blink fix is in it.
- **Run the button test** on both phones, and send the reports and the recorders.
- **If "a tap opens its blobs" is wrong again,** its line now says why.
