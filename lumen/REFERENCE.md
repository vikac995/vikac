# Lumen reference index

Lumen is a library of working interface examples. Each has a stable id. To point another chat at one, give it this
source and say, for example, "build it like **Lumen R17 Forms**". In the app, every room shows its id as a chip;
tapping the chip copies a reference line.

Shared building blocks used by most rooms: `lib/core/springs.dart` (spring tokens and `SpringValue`),
`lib/core/theme.dart` (colour and type tokens), `lib/core/haptics.dart` (native haptics), `lib/core/expand_route.dart`
(screen transitions and predictive back), `lib/widgets/controls.dart` (switch, segmented picker, slider),
`lib/widgets/pressable.dart` (press feedback), `lib/widgets/panel.dart` (cards and the room scaffold).


## Core

| Id | Name | What it shows | Files |
|---|---|---|---|
| R01 | Glass | Refracting glass on controls only: a tab bar with a draggable lens, glass buttons, a tuning panel, quality tiers and a solid fallback. | `lib/rooms/glass/glass_room.dart`<br>`lib/core/glass.dart`<br>`shaders/glass.frag` |
| R02 | Springs | Spring motion against a fixed curve with the same input: retarget mid-flight, drag the target, grab and throw. | `lib/rooms/springs/springs_room.dart`<br>`lib/core/springs.dart` |
| R03 | Shape morph | Shapes that morph cleanly: a scrubbable hero shape, toggles, a send button that becomes a loader then a tick, loading indicators. | `lib/rooms/shapes/shape_room.dart`<br>`lib/rooms/shapes/shape_loader.dart`<br>`lib/core/shapes.dart` |
| R04 | Flow | A card grows into a page and returns to its slot; predictive back follows the finger. | `lib/rooms/flow/flow_room.dart`<br>`lib/core/expand_route.dart` |
| R05 | Shaders | Three GPU effects: touch-reactive aurora, water ripples that bend live content, progressive blur. | `lib/rooms/shaders/shaders_room.dart`<br>`lib/rooms/shaders/progressive_blur.dart`<br>`shaders/aurora.frag`<br>`shaders/ripple.frag`<br>`shaders/pblur.frag` |
| R06 | Details | Scroll-reactive variable type, pull to refresh with a morphing indicator, an AI prompt bar with streaming and trust labels, a like button with rolling digits, a copy button. | `lib/rooms/details/details_room.dart`<br>`lib/rooms/details/prompt_bar.dart`<br>`lib/rooms/details/small_things.dart` |

## Trends

| Id | Name | What it shows | Files |
|---|---|---|---|
| R07 | Foil | Holographic cards that tilt in 3D under a finger or with the phone (gravity sensor). | `lib/rooms/foil/foil_room.dart`<br>`shaders/holo.frag` |
| R08 | Dials | A knob with haptic notches, fling and end stops; a 3D wheel time picker. | `lib/rooms/dials/dials_room.dart` |
| R09 | Colour | A colour scheme extracted from a picture (k-means) and applied with a glide. | `lib/rooms/colour/colour_room.dart` |
| R10 | Live pill | A status pill that grows into a timer, music or a call, splits in two, and opens into controls. | `lib/rooms/pill/pill_room.dart` |
| R11 | Data | A chart that morphs between ranges, a magnetic scrub cursor, bars that grow in a wave. | `lib/rooms/data/data_room.dart` |
| R12 | Access | One screen shown at standard, large text, high contrast and reduced motion; screen-reader order and touch areas made visible. | `lib/rooms/access/access_room.dart` |

## Foundations

| Id | Name | What it shows | Files |
|---|---|---|---|
| R13 | Type | Type hierarchy from one scale ratio, with hierarchy on and off, and line height. | `lib/rooms/basics/type_room.dart` |
| R14 | Space | Spacing from one base unit, grouping by distance, a grid overlay. | `lib/rooms/basics/space_room.dart` |
| R15 | Contrast | Live contrast ratio with pass marks; why status needs more than colour. | `lib/rooms/basics/contrast_room.dart` |
| R16 | States | A button in six states; a screen that loads with a skeleton and ends as content, empty or error. | `lib/rooms/basics/states_room.dart` |
| R17 | Forms | Floating labels, validation that waits until a field is left, password strength, a submit button that shows what is missing. | `lib/rooms/basics/forms_room.dart` |
| R18 | Sheets | Swipe a row away with Undo; a bottom sheet with three resting heights, drag and flick. | `lib/rooms/basics/sheets_room.dart` |

## Patterns

| Id | Name | What it shows | Files |
|---|---|---|---|
| R19 | Performance lab | The same screen built the costly way and the cheap way (shadows, blur, idle animation), measured on the device. | `lib/rooms/patterns/perf_room.dart`<br>`lib/core/frame_stats.dart` |
| R20 | Launcher | A home screen: drag to reorder with icons making room, folders by dropping one icon on another, a dock, an app drawer with search. | `lib/rooms/patterns/launcher_room.dart`<br>`lib/widgets/spring_box.dart` |
| R21 | Blob menu | One button that splits into three to five actions on an arc; tap, or press and slide to choose. | `lib/rooms/patterns/blob_room.dart` |
| R22 | Timers | A rest timer stored as an end time, redrawn once a second, with a pill that stays visible while scrolling. | `lib/rooms/patterns/timer_room.dart` |
| R23 | Inputs | Number entry for workouts: a weight ruler with ticks and fling, steppers that repeat while held, set rows with a tick. | `lib/rooms/patterns/inputs_room.dart` |
| R24 | Do and don't | Common mistakes next to the fix: spinner and skeleton, confirm and undo, vanishing and persistent labels, small and proper touch targets. | `lib/rooms/patterns/dodont_room.dart` |

## Screens

| Id | Name | What it shows | Files |
|---|---|---|---|
| R25 | Components | A catalogue of every control, each named on screen (C01 to C24). | `lib/rooms/screens/components_room.dart` |
| R26 | Dashboard | A complete home screen: greeting, summary card with a ring, bento of stat tiles, week chart, floating glass toolbar. | `lib/rooms/screens/dashboard_screen.dart` |
| R27 | Detail page | A complete detail page: hero picture with parallax, facts as chips, highlights, floating glass action bar with a split button. | `lib/rooms/screens/detail_screen.dart` |
| R28 | Assistant | A complete AI chat: streaming, numbered citations and sources, collapsible reasoning, a generated card, suggestions, send that becomes stop. | `lib/rooms/screens/assistant_screen.dart` |
| R29 | Onboarding | A complete first-run flow: three swipeable steps with a morphing illustration, progress dots, skip, a finish state. | `lib/rooms/screens/onboarding_screen.dart` |

Pieces inside the Screens rooms carry their own ids (for example `R26.3`). Switch on "Show names" (the tag button at
the top of those screens) and every piece is labelled in the app, so a screenshot names what it shows.

## More patterns

| Id | Name | What it shows | Files |
|---|---|---|---|
| R30 | Settings screen | A complete settings screen: profile header, rows in small groups, controls that work inside the row (dial, segmented, switch), progress inside a row, and a hold-to-erase button with undo. | `lib/rooms/screens/settings_screen.dart` |
| R31 | Number pad | A custom keypad for typing a number: big live display, quick-add chips, and a shake with a thud when a key is refused. | `lib/rooms/patterns/numpad_room.dart` |
| R32 | Scan | A camera scanning flow: corner frame that closes on a find, sweeping line, torch, and a result sheet with a portion dial and live total. | `lib/rooms/patterns/scan_room.dart` |
| R33 | Widgets | An editable grid of tiles: long-press to edit, drag a handle to resize in whole cells, remove with a badge, add from a picker; everything else springs out of the way. | `lib/rooms/patterns/widgets_room.dart` |
| R34 | Lists | A long list: search as you type, filter chips, sticky letter headers, a letter rail with ticks to jump, and an empty result state. | `lib/rooms/patterns/lists_room.dart` |
| R35 | Celebrate | Short reward moments that end: personal best with confetti and a rolling number, a streak filling day by day, a goal ring closing into a tick. | `lib/rooms/patterns/celebrate_room.dart` |
| R36 | Theme lab | One small screen restyled live by accent, corner radius, spacing, light or dark and background tint; a line under it states the exact values. | `lib/rooms/patterns/theme_room.dart` |
| R37 | Notifications | Five ways to speak up, quietest first: a badge, a bottom message with Undo and a draining timer, a banner from the top, a stack that unfolds, and a polite permission request. | `lib/rooms/patterns/notify_room.dart` |
| R38 | Calendar | History as a month: dots on days with a session, one highlight that travels between days, month change by swipe or arrows, a day summary, and a future that cannot be picked. | `lib/rooms/patterns/calendar_room.dart` |
| R39 | Workout screen | A complete workout-in-progress screen: progress through the session, last time as a hint, set rows with thumb dials, one tap to finish a set, a rest timer that starts itself, and a next button that wakes when all sets are done. | `lib/rooms/screens/workout_screen.dart` |
| R40 | Navigation | Three bottom bars for the same four destinations: labels with a travelling pill, a floating bar with one main action, and a bar where only the selected tab shows its name. | `lib/rooms/patterns/nav_room.dart` |
| R41 | Reorder | Editing a list by hand: drag a row by its handle while the others spring out of the way, swipe left to remove with a tick at the point of no return, and Undo instead of a confirmation. | `lib/rooms/patterns/reorder_room.dart` |
| R42 | Summary screen | A complete workout-finished screen: a tick that lands first, numbers that count up once, the one special thing today, a one-tap feeling question, and Share plus Done. | `lib/rooms/screens/summary_screen.dart` |
| R43 | Wheels | Wheel pickers for a duration, a time of day (looping) and a body weight split into kilos and tenths; each step ticks and the wheel snaps. | `lib/rooms/patterns/wheels_room.dart` |
| R44 | Plates | A plate calculator: dial a weight and a drawn barbell loads itself with colour-coded plates, with the per-side list in words. | `lib/rooms/patterns/plates_room.dart` |
| R45 | Progress screen | A complete progress screen: lift chips, one headline number with its change, a line chart you can run a finger along, a period switch that reshapes the line, and bests as plain rows. | `lib/rooms/screens/progress_screen.dart` |
| R46 | Nutrition screen | A complete food day: a ring showing calories left, three macro bars, meals where one tap adds the usual item, and a row of water glasses. | `lib/rooms/screens/nutrition_screen.dart` |

## During a workout

| Id | Name | What it shows | Files |
|---|---|---|---|
| R47 | Demo video | A demo clip inside a workout in three sizes: a small loop beside the exercise name, grown in place with cues, speed and scrubbing while the sets stay visible, and a floating bubble that parks in any corner; finishing a set shrinks it automatically. The clip is a drawn loop. | `lib/rooms/patterns/video_room.dart` |
| R48 | Swap | Swapping an exercise mid-workout: a sheet of alternatives re-ranked by the reason (equipment busy, discomfort, variety), the card turns over with sets kept and weight adjusted, then asks just today or every time, with Undo. | `lib/rooms/patterns/swap_room.dart` |
| R49 | Edit mid-workout | Editing in place during a session: tap a set badge to cycle its type (normal, warm-up, drop, failure), add a set like the last, remove a set, and in the queue drag to reorder, skip for today, or link two exercises into a superset. | `lib/rooms/patterns/session_room.dart` |

## The centre button

| Id | Name | What it shows | Files |
|---|---|---|---|
| R50 | The button | The contextual centre button: one tap splits it into up to five glass blobs on individual springs (stretch in flight, slight overshoot, 14 ms stagger), press-slide-release picks in one movement with neighbours leaning away, a context suggestion pill nearest the thumb, a rest ring on the button itself, apps shown as icons behind tinted glass, quick actions colour-coded by category, and in-place editing with pencil, minus and an empty plus slot. Motion switch: Snappy, Balanced, Bouncy. | `lib/rooms/patterns/flude_room.dart` |
| R51 | Button and lens | The centre button with two jobs. Tap: it stays a flat coloured button and splits into five solid blobs on an arc, each on its own spring (stretch in flight, slight overshoot, 14 ms stagger). Drag: it lifts off the bar as real refracting, magnifying glass riding above the thumb; things on screen swell continuously as it approaches and an explanation card appears while it is over one; on release over something with actions it stays put with its card open and usable, otherwise it springs home and becomes a flat button again. | `lib/rooms/patterns/lens_room.dart`<br>`lib/core/glass.dart` |

## Bonus

| Id | Name | What it shows | Files |
|---|---|---|---|
| B01 | Discomorphism | A mirror ball shader, a dance floor and a haptic beat. A joke; also a ray-per-tile shading example. | `lib/rooms/disco/disco_room.dart`<br>`shaders/disco.frag` |

## How to reuse an example

1. Read the room file named above; it is self-contained apart from the shared building blocks.
2. Copy the building blocks it imports. None depend on packages other than `material_ui`.
3. Keep the numbers (spring stiffness and damping, sizes, timings): they were tuned on a 120 Hz phone.
4. `CHANGELOG.md` records what was verified on the phone for each build and what was not.
