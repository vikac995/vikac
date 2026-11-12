# Lumen changelog

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
