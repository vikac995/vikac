# Step 2 plan: the Sidekick's own settings panel

A plan only, for the owner to read before anything is built. Nothing here is coded yet.

**The goal, in the owner's words:** "Editing Sidekick menu should make the user feel like they are not
editing the Prism." Step 1 gave the Sidekick its own list of blobs, kept by Android. Step 2 gives it its
own settings:
- **kept by Android,** not by Prism;
- **shown by Android,** over whatever app is open;
- **opened from the Sidekick itself,** without Prism ever coming forward or its triangle turning.

DESIGN.md §6 already says how it must feel: "Each one is edited where it is. Editing the Sidekick
happens over the app it is in and never opens or turns Prism." And "The Sidekick never takes the
keyboard or the focus of the app underneath."

## 1. What moves, and where it lives now

Every Sidekick setting is in Prism's settings panel today, under **Prism | Sidekick → Sidekick**.
Prism keeps each one in a small file of its own and sends it to Android.

| Setting | Today: kept by Prism in | Today: when never chosen | Android already holds it live as |
|---|---|---|---|
| In this app (switch) | `prism_floating` (first number) | on | `Floater.floatIn` (all floating things: the Sidekick **and the timer**) |
| Over other apps (switch) | `prism_floating` (second number) | on | `Floater.floatOut` (the same) |
| Distance from the edge (slider, 0–36) | `prism_side_spots` (first number) | 8 | `restGap` |
| Tucked in, how much shows (slider, 8–40) | `prism_side_spots` (second number) | 22 | `tuckOut` |
| Labels Show \| Hide | `prism_blob_names_side` | Prism's own Labels | `RestBubble.blobNames` |
| Icons Prism \| Regular | `prism_icons_blobs`: **one setting shared with Prism's blobs** | Prism | (none: Prism draws the pictures in Prism's choice) |
| Colours Mellow \| Vivid | `prism_side_vivid` | Prism's own Colours | `RestBubble.vivid` |
| Look (six looks) | `prism_side_look` | Prism's own Look | `RestBubble.look` |

Nothing else in that part of the panel belongs to the Sidekick. The two-finger swipes are Prism's
alone. The Sidekick's spot on the screen (where it was left, tucked or not) is already Android's own
(`prism_lens` preferences).

**Where each will live:** in Android's own storage, next to the Sidekick's menu:
- the same preferences file as step 1's list (`prism_sidekick`), in a small `SidekickSettings` beside
  `SidekickMenu`;
- one key per setting: `inApp`, `overApps`, `gap`, `tuck`, `names`, `icons`, `vivid`, `look`.

**The one-time move,** like step 1's, but simpler:
- Prism's files sit in the app's own folder, so **Android can read them itself.** It doesn't have to
  wait for Prism to start.
- **When:** the first time the new build starts, before the Sidekick is shown, if Android has no
  settings of its own yet.
- **What it reads:** the files above. Where one was never written, it takes what the Sidekick showed
  until now: Prism's own Labels, Colours and Look, from `prism_blob_names`, `prism_blob_vivid` and
  `prism_blob_look`.
- **What it does:** saves its own copy and marks the move as done.
- **The recorder** gets one line: "Sidekick settings moved from Prism: …", with every value.
- **The flag:** the move happens once, whatever happens later.
- **Prism's old files:** Prism stops reading its Sidekick files and deletes them after the move, as step
  1 deleted `prism_blobs_side`. Prism's own Labels, Colours and Look files stay; they are Prism's.
- **Icons:** the Sidekick gets its own choice, starting as the shared one was. Prism keeps its own.
  - **For Regular,** Android draws the apps' own icons itself: it already makes them, for Prism's app
    list.
  - **For Prism,** it uses the pictures Prism sends, as today.
  - So the choice needs no new message to Prism. Blobs that aren't apps (Prism's pages and actions)
    always have Prism's pictures, as in Prism.

**What Prism still needs to know,** read-only:
- **Can anything float?** Prism uses this today: a blob dragged onto Prism's button floats only if
  floating is on.
- **The values for the test report's SETTINGS lines.**

Android tells Prism the values whenever they change (`sidekickSettings`), and Prism keeps a read-only
copy. Recorder lines at both ends: sent / got.

## 2. What stays in Prism

**Prism's settings panel becomes Prism's alone:**
- The **Prism | Sidekick** picker goes. What's left: Labels, Icons, Two-finger swipes, Colours, Look,
  all Prism's own, as today.
- Its title is always "Prism".

**What Prism still does for the Sidekick, one way each** (as THE PLAN in HANDOVER.md lists):
- **Pictures:** Prism-style icon pictures for the Sidekick's blobs, as today.
- **Colours:** Prism's colour and theme. This now includes the panel's own colours (surface, hairline,
  ink, faint ink, accent, light or dark), so the Sidekick's panel looks like Prism's panel in every
  look and in dark mode. Android saves them, so the panel can open even before Prism has started.
- **"Come out":** the Side blob action, as today.

**One question for the owner: the way back.**
- If both "In this app" and "Over other apps" are switched off, the Sidekick is gone. There is nothing
  left to hold to reach its settings again.
- **I propose:** Prism's settings page (the full page, not the panel) shows one line, **"Bring back the
  Sidekick"**, only while both are off. Tapping it switches "In this app" back on and brings the
  Sidekick out.
- That is the only Sidekick control left in Prism, and only while there is no other way.
- **The other choice:** the Sidekick's panel won't let both be switched off at once. That's simpler,
  but a switch that refuses is unusual.

**The timer:**
- Today the two switches also decide where the rest timer floats, because the timer and the Sidekick
  are the same class until step 4.
- **I propose:** until step 4, the timer goes on following the Sidekick's two switches, read from
  Android's storage, so nothing about the timer changes now. Step 4 decides whether the timer gets its
  own.

## 3. How it opens and closes

**It opens three ways,** the same three that today bring Prism forward. All of them go through
`sideSettings()` on Android, so only that one function changes:
1. **Hold the closed Sidekick** (DESIGN.md §6: "Hold the closed button: its settings").
2. **Hold the Sidekick in the middle of its open blobs.**
3. **Edit Sidekick,** in the small menu of the empty space round its blobs.

Prism doesn't come forward, its triangle doesn't turn, and Prism isn't even told, apart from a recorder
line.

**Where it sits:**
- **Beside the Sidekick, on the side away from it:**
  - The Sidekick rests at an edge, so the panel takes the rest of the width (about 330 points on the
    owner's phone, where Prism's panel is about 390).
  - It takes the height between the status bar and the navigation bar, less a margin, the same 70
    points Prism's panel keeps.
  - Its content scrolls if it is taller than that.
- **Why beside, not above or below:** the content is about 700 points tall, taller than the room above
  or below a Sidekick that rests mid-screen. Beside it:
  - the Sidekick stays in sight, which DESIGN.md §7 asks for ("the button stays in sight, and a tap on
    it … closes the panel");
  - the Sidekick's live moves, while a distance is dragged, happen right next to the panel.
- **With a keyboard up** in the app underneath, the panel sits above the keyboard (Android's keyboard
  insets, as the old sheet does) and its content scrolls.
- The six looks sit three to a row at this width (four in Prism's panel).

**Its motion:** exactly `_SpringPanel`'s, ported to Android:
- **Opening:** grows out of the Sidekick and goes back into it. From a circle the Sidekick's size, at
  the Sidekick's middle, to the panel's place.
  - On `Motions.snappy` (stiffness 1100, damping 0.82), like the app list and Prism's settings.
  - The contents fade in between 5% and 30% of the way, as in Prism.
- **Closing:** back into the Sidekick on `Motions.spatialFast` (1400, 0.9), as fast as it opened.
- **The shade:** black at up to 40%, as in Prism. It leaves a round hole where the Sidekick is, so the
  Sidekick isn't dimmed.
- **The springs:** a small `Springs` object on Android, holding the same named springs as
  `lib/core/springs.dart` (the same numbers). The panel uses it, and later builds can move the
  Sidekick's own hand-written constants onto it. Nothing else changes in this step. The Sidekick's
  menu today opens on its own numbers (1150, 0.6), which are close to `expressiveFast`; that is noted,
  not changed.
- **Haptics:** opening gives `settle`, closing nothing extra, each control its usual tick (DESIGN.md
  §5). They use Android's existing `haptic()`, which already matches Prism's.

**It closes, all at the same speed:**
- with the X;
- with a tap beside the panel (on the shade);
- with a tap on the Sidekick;
- when the person heads for the home screen or the recent apps (Android's "close system dialogs"
  announcement, as the Sidekick's menu already does);
- when the screen turns off.

Back: see §5.

## 4. How it looks

**Built from Android Views, drawn by hand on a Canvas.** The same way the Sidekick's menu and its
small menus already are. One custom View per control, each a copy of Prism's control:

| Prism's control | On Android | Matched |
|---|---|---|
| The panel (`_SpringPanel` content) | a `SidekickPanel` View in its own overlay window | surface colour, hairline rim, 36-point corners, 20-point padding, shade |
| `Segmented` (Labels, Icons, Colours) | `PanelPicker` | stadium track (ink at 7%), the sliding thumb (white or raised surface in dark, hairline, soft shadow: blur 6, down 2), the thumb's spring (`expressiveFast`), the labels' colour change and weight 500 → 650 in steps of 10 (the 175 rule) |
| `LumenSlider` (two distances) | `PanelSlider` | track (ink at 18%), accent fill, 26-point white thumb that grows while held, the follow spring, touch anywhere on the track |
| `SwitchLine` / `LumenSwitch` (two switches) | `PanelSwitch` | the same track, knob, colours and spring |
| The six looks | `BlobLooks.paint`, which already draws them on the Sidekick | the ring round the chosen one, the name under each (650 chosen, 500 not) |
| Title "Sidekick", X | Bricolage 22 at weight 700; the round X | as in Prism |

**Type:**
- Prism's own Inter and Bricolage, loaded from the app's fonts (the Sidekick's names already are), with
  the same weights and optical sizes Prism uses.
- Each weight the panel needs is made **once**, when the panel is first built, and kept: about 16
  Typefaces. Never one per frame: that is LESSONS.md's newest rule, on Android too.

**What will knowingly differ:**
- **The corners:**
  - Prism's panel uses a true superellipse (`RoundedSuperellipseBorder`). Android has none built in.
  - I'll draw the same curve as a path. If it is close but not identical, the difference is in the
    last few pixels of each corner.
- **The shadows:** Android's blurred shadow (`setShadowLayer`) is not Flutter's. It should be the same
  size and colour. Side by side, it may be a touch softer or harder.
- **Text:** Android lays out and smooths text with its own engine. The same font at the same size and
  weight can sit up to a pixel differently.
- **The look previews:** drawn in the Sidekick's own blob colours, as its sign is. Prism's panel drew
  them in Prism's colours.
- **The width:** narrower than Prism's panel, so the looks sit three to a row.

## 5. Focus, keyboard and Back

**The fact:**
- A window that never takes the focus (`FLAG_NOT_FOCUSABLE`) never hears Back. Back goes to the app
  underneath.
- A window that takes the focus hears Back, but takes the focus from the app underneath while it is
  open.
- DESIGN.md has two rules that pull apart here:
  - §6: "The Sidekick never takes the keyboard or the focus of the app underneath."
  - §7: "a tap on it, beside the panel, the X **or back** closes the panel."

**The two ways, A and B:**

**A. Never takes the focus** (as the Sidekick's menu today):
- A keyboard open in the app underneath stays open and keeps working. The panel sits above it.
- Back goes to the app underneath. For example, it closes the app's keyboard, or goes back a page in
  the app, while the panel stays open.
- The panel still closes with the X, a tap beside it, a tap on the Sidekick, or Home.

**B. Takes the focus but never the keyboard** (`FLAG_ALT_FOCUSABLE_IM`: "this window can't type", so
the app underneath stays the keyboard's target):
- Back closes the panel, as everywhere else.
- **Not known:** whether the app's open keyboard stays up while the panel has the focus. Android's
  rules for this have changed between versions.
- **Also not known:** whether some apps react to losing the focus (a game pauses, a video app hides its
  controls).

**My proposal:**
1. **The first build of step 2 measures it on the owner's phone,** test only:
   - The button test opens Prism's own text field (the note field in the test report), with the
     keyboard up.
   - It puts a small invisible window of kind B over it for two seconds.
   - It records whether the keyboard stayed up. Prism's own window is "the app underneath" for this:
     Android treats it like any other app's.
2. **If the keyboard stays: B.** Back then closes the panel, which keeps DESIGN.md §7, and the keyboard
   is never taken, which keeps §6 in what the person sees. The focus does move to the panel while it is
   open: that is the part of §6 we would knowingly bend, only while the panel is open.
3. **If the keyboard goes: A.** The keyboard is worth more than Back. Back then goes to the app, as with
   the Sidekick's menu today.

**Either way, it goes into PRISM.md's Back table:**

| If this is showing | Back does this |
|---|---|
| The Sidekick's settings, over any app | (B) Closes them. (A) Goes to the app underneath; the settings stay until the X, a tap beside them or on the Sidekick, or Home. |

## 6. Live preview, without Prism

- **While a distance slider is held:**
  - The panel clears: everything fades out but that slider, and the shade goes.
  - The Sidekick goes to that place at once: its resting spot, or its tucked-in spot, at the side it is
    on. It follows the slider live.
  - This is what Prism's panel does today, but **in Android alone**: the slider calls the Sidekick's
    `showSpot()` directly, in the same process. No message goes to Prism, and nothing waits for it.
- **Let go:** the panel comes back, and the value is saved.
- **The other choices show at once on the real Sidekick,** even behind the panel: Labels, Colours,
  Look, Icons.
- **Switching off "In this app" while over Prism,** or "Over other apps" while over another app, makes
  the Sidekick go. The panel closes into where the Sidekick was.

## 7. Tests

**The button test's Sidekick half** gets a new part for the panel. Android's test driver gets ops for
it, as it has for the Sidekick's menu: open by each way, tap a control by name, drag a slider and
hold, read the state.

What it checks:
- **Each of the three ways opens it,** and none of them brings Prism forward. Each check reads:
  - Android's own panel state;
  - PrismScreen's "brought forward" count, unchanged;
  - Prism never told `sideSettings`;
  - Prism's triangle unturned.
- **Its window** never takes the keyboard. For A, it never takes the focus either; for B, it takes the
  focus but can't type.
- **Every control changes its setting,** read back from Android's storage. The Sidekick shows the
  change: names drawn or not, the look's id, vivid, the icons' kind.
- **Each slider, held:**
  - the panel cleared;
  - the Sidekick's window at the place the value says, for rest and for tuck;
  - let go: the panel back, the value saved.
- **The path, not only the end** (LESSONS.md):
  - one buzz per action;
  - the panel's first frame is the size and place of the Sidekick (no pop);
  - its frames while opening and closing (late frames counted, as for every scene);
  - which engine and which window answered.
- **Every way of closing it:** the X, beside, the Sidekick, Home. Each leaves the Sidekick as it was.
- **The one-time move:** what it read and what it saved, from the recorder line. On later starts, that
  it didn't run again.
- **Missing answers:** a missing or failed answer from Android is SKIPPED or WRONG, never ok (LESSONS.md).

**Only the owner's eyes can check:**
- whether it looks like Prism's panel: type, weights, corners, shadows, colours, in light and dark and
  in each look;
- whether it moves like it: the grow and shrink, the pickers, the sliders;
- how the haptics feel;
- the keyboard and Back over a real app (for example, a message half typed in a chat app);
- that nothing flickers when it opens over a busy app or a video.

## 8. Risks

1. **The look won't match exactly.** Drawn twice, in two toolkits, the panel will be close, not
   identical (§4). Each difference is named before the owner sees it, and each control is one small View
   that is easy to adjust.
2. **Back and the keyboard** (§5). That's why the first build measures it.
3. **Memory.** A new full-screen window for the shade costs one full-screen buffer of graphics memory
   (about 10 MB) while the panel is open, and nothing once it is closed: the window is removed. Graphics
   memory is the next target, so the panel's window is made only while it is open, and the test reads
   graphics memory before, during and after.
4. **Two copies of each control** (Flutter's and Android's). From now on, a change to a control's look
   has to be made twice. The handover will say so, with a list of the pairs.
5. **The timer** follows the Sidekick's two switches until step 4 (§2). If something about the timer
   breaks, that's where to look.

## 9. Where I could be wrong

1. **Whether Android reads Prism's old files where I expect them.**
   - Prism writes them to the app's files folder (`…/files/prism_floating` and so on), or to its cache
     folder if the files folder didn't exist yet. Android's `filesDir` should be the first.
   - The move will look in both. If it still finds nothing, the Sidekick comes up with the defaults.
   - The recorder line names every file it found, so the first phone run shows it.
2. **Whether kind B keeps another app's keyboard** (§5). I don't know, which is why it is measured
   first.
3. **Whether the panel can sit beside the Sidekick on every screen.** On a narrow phone, or with the
   text made large, 330 points may be too little for the pickers. Then it sits above or below the
   Sidekick and scrolls more. The test reads the panel's width.

## 10. Size: three builds

1. **Build 176, step 2a, the settings move to Android. Nothing looks different.**
   - Android keeps the Sidekick's settings, with the one-time move from Prism's files.
   - Prism's panel still has its Sidekick part for this one build, but it reads and writes through
     Android, and Prism keeps a read-only copy.
   - The Sidekick gets its own Icons choice.
   - Prism sends the panel's colours.
   - The keyboard measurement (test only).
   - The 175 follow-up commit (lessons, the complete font guard) ships in this APK.
   - The button test checks the move and that each setting reaches Android and back.
2. **Build 177, step 2b, the panel.**
   - The Sidekick's own panel on Android, opened the three ways, with the motion, the controls, the live
     preview, and Back as the measurement decided.
   - Prism's Sidekick part goes, and so does the Prism | Sidekick picker.
   - The way back, if the owner agrees to it.
   - The button test's new panel part.
   - This is the big one, but it is one new element: one kind of change.
3. **Build 178, step 2c, if needed:** what the owner's eyes find in 177 (the look, the motion), and
   nothing else.

**Not in step 2:** the Sidekick's own app list for Change and Add (step 3). Until then, Change and Add
still go to Prism's app list, as today.

## The owner's answers (15 November 2026)

1. **The way back:** the "Bring back the Sidekick" line in Prism's settings page, shown only while both
   switches are off. (§2)
2. **Back:** measured in 2a (build 176's keyboard probe), then A or B as in §5.
3. **The timer:** unchanged, until the owner reworks the workout flow. (§2)
4. **The panel:** beside the Sidekick, on the side away from it, nearly full height, as in §3. The
   owner chose it from a mock-up of beside, centred and bottom.

Before 2b is built, the review chat makes a detailed mock-up of the panel's contents and motion, and
the owner approves it (design first: see LESSONS.md). Its link goes into 2b's brief.
