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

## Bonus

| Id | Name | What it shows | Files |
|---|---|---|---|
| B01 | Discomorphism | A mirror ball shader, a dance floor and a haptic beat. A joke; also a ray-per-tile shading example. | `lib/rooms/disco/disco_room.dart`<br>`shaders/disco.frag` |

## How to reuse an example

1. Read the room file named above; it is self-contained apart from the shared building blocks.
2. Copy the building blocks it imports. None depend on packages other than `material_ui`.
3. Keep the numbers (spring stiffness and damping, sizes, timings): they were tuned on a 120 Hz phone.
4. `CHANGELOG.md` records what was verified on the phone for each build and what was not.
