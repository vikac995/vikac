# Lumen changelog

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
