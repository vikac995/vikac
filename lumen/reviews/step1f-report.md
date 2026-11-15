# Step 1f report: the leak found, and the bisect run (build 175)

Asked for by the review of build 174's phone leak test (b and c kept about 15–17 MB a repeat). Branch
`claude/flutter-ui-showcase-ngzfru`, based on `2bc345b`. Two commits: `0005166` (the code, the APK, the
changelog, the handover, this report) and the one after it, which only adds the checked link here. Step 2
not started.

**What has only run in the preview:** everything. Nothing in this build has run on a phone. In the
preview the leak test has only its "process" column (no Android), and it draws in software: a picker's
slide there is about 3 frames, where the phone draws dozens. The cause below is proven in the preview, in
two ways; that it is *the whole* of b's and c's growth on the phone is what this build's phone run must
show.

## Files changed

| File | What changed |
|---|---|
| `lib/core/theme.dart` | **The fix.** `LumenType.steady`: every weight `LumenType.text` and `LumenType.display` draw is rounded to a step of 10. |
| `lib/fit/shell.dart` | The leak test's new steps (below). Four test-only switches, all off outside the test and put back in its `finally`: `_leakNoSends`, `_leakNoCover`, `_leakNoLooks`, `_leakBump`. Each reading also records how many frames Prism has drawn. The button: "about 11 min". |
| `lib/widgets/controls.dart` | `Segmented.testJump`, test only: the pickers jump instead of sliding while it is on. |
| `lib/fit/main.dart` | The leak test's probe text under the banner (only while `Diag.probe` is set). |
| `lib/fit/diag.dart` | `Diag.probe`; `Prism build 175`. |
| `lib/fit/long_test.dart` | `framesCounted`; the LEAK TEST table's last column, frames per repeat. |
| `pubspec.yaml` | `0.136.0+203`. |
| `CHANGELOG.md`, `HANDOVER.md` | Build 175 entry; the rule (no font variation may follow an animation). |
| `releases/prism-build-175.apk` | The build. |

## 1. The cause: a font weight that moves

**From the code.** `LumenType.text` and `LumenType.display` draw every text with font variations: a
`wght` (weight) and an `opsz` (optical size, from the font size). Two places in Prism give them a weight
that changes on every frame of an animation:
- `Segmented` (`lib/widgets/controls.dart`, the two-way picker): each label's weight is
  `lerpDouble(500, 650, sel)`, with `sel` following the sliding thumb. That's every picker: Show | Hide,
  Prism | Sidekick, Icons, Colours, the app list's two, the progress page's range, the look settings.
- The tab bar (`lib/fit/shell.dart`, the bar's labels): `560 + 140 * on`, with `on` following the light
  (`_lensX`) as it slides between pages.

I searched every weight in Prism's code (`fit/`, `widgets/`, `core/`, and the two shared files Prism
uses): these two are the only ones that are computed. Every other one is a fixed number, and every fixed
number is a multiple of 10 (450, 500, 560, 570, 600, 620, 650, 680, 700, 720, 800). No other code builds
font variations.

**Why a moving weight keeps memory.** Every distinct set of font variations is a font of its own for the
text engine (Flutter's text layout, SkParagraph): it is made on first use, cached by its exact values, and
never let go while Prism runs. That cache has no limit. Each one also gets its own FreeType face and glyphs
when drawn. Nothing on Dart's side holds it, so neither Dart's collection nor Java's frees it: it is
native memory, as 174's table showed (native, after gc and process together; graphics flat).

**Proven in the preview, two ways:**
1. **A small separate app** (not in the repo), drawing three lines of Inter for 600 frames per phase:

   | phase | process MB after it |
   |---|---|
   | same weight every frame | 408 (start-up included) |
   | **a new weight every frame** | **506 (+98)** |
   | same weight | 505 (−1) |
   | **a new weight every frame** | **559 (+54)** |
   | 16 weights in turn (steps of 10) | 557 (−2) |
   | 16 weights in turn | 557 (0) |
   | **a new weight every frame** | **641 (+84)** |

   New weights grow and keep it; the same few weights again and again keep nothing. About 45–90 KB per
   new weight here.
2. **Inside Prism, the leak test's new step h** (below): a short text drawn at a new weight 30 times per
   repeat, exactly as a moving weight was drawn before 175. It grows **+2.9 MB a repeat**, and keeps it
   (437 → 444 → 450 → 462 → 488 MB). It drew 18 frames a repeat in the preview, so about 160 KB per new
   weight. The same done the new way (steps of 10): flat after the first repeats.

**How it fits 174's phone table:**
- **a, d, e, f kept nothing:** opening the settings, the app list, the blobs, the Sidekick's blobs. No
  weight moves in any of them.
- **b and c kept 15–17 MB a repeat:** each repeat slides a picker twice. Two labels change weight on every
  frame of each slide.
  - At about 160 KB per weight, 17 MB is about 100 new weights a repeat: about 25 frames a slide. That is
    about what the picker's spring takes at 120 frames a second (a guess, not measured).
- **My preview never showed it:** there a slide draws about 3 frames (the new frames column: 6 frames for
  a whole b repeat).
- **Not explained by this, and not known:** why b and c kept less with the glass solid (12) or the Sidekick
  off (9).
  - My guess, not checked: the phone drew fewer frames per slide in those steps (a lower refresh rate).
  - The new frames column will show whether it did. If it didn't, the steps that leave out the Sidekick's
    parts (iii, iv) split what the Sidekick adds.

## 2. The fix

`LumenType.steady(weight)` rounds to the nearest 10, in `LumenType.text` and `LumenType.display`, so in
one place for every text in Prism:
- **At most a few dozen weights** can ever exist (450 to 800 in steps of 10), each made once.
- **Every fixed weight is unchanged:** they are all multiples of 10 already.
- **Only the two moving ones change:**
  - The picker's label: 15 steps from 500 to 650.
  - The tab bar's label: 14 steps from 560 to 700.
- **What could look different:** during a slide the weight steps every 2 or 3 frames instead of every
  frame.
  - The colour still changes every frame.
  - A step of 10 at 13 px (the pickers) or 10.5 px (the tab bar) is a very small change of thickness. I
    don't expect it can be seen, but it is a change to the motion. Please look at it on the phone.
- **Also guarded:** any future moving weight. The handover now says that no font variation may follow an
  animation.

## 3. The bisect run (the leak test, rebuilt)

Same framework as 174: each step's set-up, a reading, the step 20 times with a reading every 5, its
tidy-up. The table's last column (new) is how many frames Prism drew per repeat, from repeat 5 to 20.

| Step | What it is | What it splits |
|---|---|---|
| a. settings opened and closed | as 174 | the control: flat in 174 |
| b. Labels Hide and Show | as 174 | **must be flat now** |
| c. Prism \| Sidekick and back | as 174 | **must be flat now** |
| g. Home to Train and back, by the tab bar | new: the everyday path | **must be flat now** |
| h. a new weight 30 times, as before 175 | new: a text under the banner, a new weight on each of 30 frames, built by hand the old way (on purpose) | **should grow**: proves the mechanism on the phone, and its slope ÷ frames is what one font costs there |
| h, the same in steps of 10, as now | the same text through `LumenType` | flat: the fix |
| i. Labels Hide and Show, the settings closed | the review's (i): `_setNames` with no panel | the state change alone |
| ii. the settings rebuilt twice, nothing changed | the review's (ii): a notifier (`_leakBump`) in the panel's builder, bumped twice a repeat | rebuilding the panel alone |
| iii. b, without Prism's messages to Android | the review's (iii): `_sendPin`, `_sendSidekick`, `_tellFan` left out | the Sidekick's pictures and messages |
| iv. c, without the Sidekick's "covered" message | the review's (iv): `_sideInSight` sends nothing | the Sidekick's windows taken away and back |
| v. b, the six look previews as empty boxes | the review's (v): `BlobSignPreview` and its disc not drawn | the look previews |
| vi. b, the pickers jumping instead of moving | `Segmented.testJump` | the picker's slide (see below) |
| b, the Sidekick switched off | as 174 | as 174 |
| c, the Sidekick switched off | as 174 | as 174 |

- **About the review's (vi), "a static open panel, then b":** the panel is already still while open. Its
  spring has settled, its `Opacity` is 1 (no layer) and its transform is the identity. In b, what moves is
  the picker. So (vi) here takes the picker's slide away instead. Before the fix that alone would have
  made b flat; with the fix it should be flat like b.
- **Left out now:** d (the app list), e (the blobs), f (the Sidekick's blobs) and the two glass-solid
  steps. 174 showed d, e and f keep nothing and the glass isn't the cause. That keeps the run at about 11
  minutes.
- **The switches** are plain fields, read only where named. Each is set by its step's set-up and cleared
  by its tidy-up. The test's `finally` clears them all again and removes the probe text, so a stopped
  test leaves nothing changed.

**How to read the phone's results:**
- **b, c and g flat; h growing:** the cause is proven on the phone and fixed.
- **b or c still growing:** the variant that goes flat names what is left. For example, iii flat while b
  grows: the Sidekick's messages.
- **h flat on the phone:** the mechanism doesn't hold there. Then 174's growth is something else, and the
  variants are the next lead.

## 4. Everyday events: which ones went down the leaking path

**Before 175, every one of these made new fonts:**
- **Every change of page,** however it is made: the tab bar's light slides and both labels change weight
  on every frame. That covers:
  - a tap on a tab;
  - sliding a finger along the tab bar (for as long as the finger moves);
  - a blob, a two-finger swipe or a Sidekick blob that opens one of Prism's pages;
  - the rest timer bubble (to Train);
  - Back to Home (`back: to Home`);
  - the test itself.

  This is the everyday one: many times a day, each about the size of half a b repeat.
- **Every change in a two-way picker:**
  - Prism's settings (Labels, Icons, Colours, Prism | Sidekick);
  - the app list's settings (Prism | Regular, Pages | List);
  - the progress page's Month | 3 months | Year;
  - the look settings in Prism's settings page.

**Not on the path** (they only redraw text at weights it has already used, which the cache reuses):
- notification counts changing (Android draws the badges; Prism's blobs redraw at fixed weights);
- the apps' list being refreshed (`Apps` notifications);
- `BlobSlots` changes, and the Sidekick's keys and pictures being sent (no text weight moves; Android
  decodes a picture only when its bytes change);
- the theme or the look changing (colours move, weights don't).

**Variants i and ii check this on the phone:** a state change with nothing open, and a redraw with
nothing changed. Both should be flat.

## 5. Noted, not changed

- **The app list's names** (`lib/fit/drawer.dart`, `_label`) use a size from the density, `16 * f` and
  `14.2 * f`. With `LumenType`'s `opsz` following the size, a new `f` could make a new font too.
  - It is bounded: the text cache's key rounds `f` to 2 decimals, so each name makes at most one per
    rounded `f`.
  - 174 showed d flat after its first 5 repeats.
  - Not changed, because nothing shows it leaking. The handover's new rule says not to animate a
    `LumenType` size.
- **Android's Sidekick menu** (`MainActivity.kt`) gives its names `'wght' 650` each time it opens. That
  is a fixed value, and Java's own objects, freed by its collection. f was flat.

## Results (preview, on the final code)

```
leak test:    runs (table below); CHECKS: 0 of 0 (it makes none)
button test:  CHECKS: 68 right, 1 wrong, of 69
  WRONG  Home, nothing open, after the button test: measured  [no answer (MissingPluginException(...))]
long test:    CHECKS: 65 right, 4 wrong, of 69 (the usual 4, on its first run)
  WRONG  app list: the flick wakes neither the magnifying glass nor a card
  WRONG  Home, nothing open / blobs out / app list open: measured  [no answer (MissingPluginException(...))]
```

```
step                                               process          frames
a. Prism's settings opened and closed              +15  | +0.32     17
b. Labels Hide and Show, in the settings           +5.15 | +0.69     6
c. Prism | Sidekick and back, in the settings      +3.66 | +0.63     7
g. Home to Train and back, by the tab bar          +7.46 | -0.61     10
h. a new weight 30 times, as before 175            +6.32 | +2.93     18
h, the same in steps of 10, as now                 +7.99 | -1.27     18
i. Labels Hide and Show, the settings closed       +1.27 | -0.07     8
ii. the settings rebuilt twice, nothing changed    +4.45 | +0.10     2
iii. b, without Prism's messages to Android        +11  | +0.06      5
iv. c, without the Sidekick's "covered" message    +9.75 | -0.07     6
v. b, the six look previews as empty boxes         +8.41 | -0.07     6
vi. b, the pickers jumping instead of moving       -2.20 | +0.52     5
b, the Sidekick switched off                       -2.64 | +0.25     6
c, the Sidekick switched off                       +13  | -0.10      7
```

- **h, the old way, is the only step that keeps memory:** +2.93 MB a repeat, steady, in both preview
  runs (the first run: +2.91).
- **Every other step's slope** is between −1.3 and +0.7 MB a repeat, both signs. That's the preview's
  noise: readings wander ±5 MB.
- **Analyser:** the same 4 old notes. `dart format` clean.
- **Kotlin:** unchanged.

**Build 175:** `Prism build 175`, `0.136.0+203`, built from the final code. NAME-OK. "about 11 min, hands off"
and the new step names are in its `libapp.so`. sha256
`29498c4a3bcd1a8a9f147135aade81c4dd2481bb5721f8293876dbde572e7a5d`, 18,583,802 bytes. Link: https://github.com/vikac995/vikac/raw/000516665b3c072cc0068e1965e261ff98b03055/lumen/releases/prism-build-175.apk
(pinned to `0005166`, the commit that added the APK). Checked after the push: it answers 200, and the
downloaded file has the same sha256 as the one built.

## For the owner on the phone

1. Install 175.
2. In the testing panel, tap **Run the leak test (about 11 min, hands off)**. When it ends, copy the
   report and send it, then the flight recorder.
3. Look at Show | Hide in Prism's settings, and at the tab bar while you change page. The labels' boldness
   now changes in small steps; say if you can see it.
4. If you can, use Prism as usual for a day without restarting it, then run the button test and send its
   report. Its first memory reading shows how much Prism holds after a day of use.
