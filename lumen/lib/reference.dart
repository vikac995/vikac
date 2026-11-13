// GENERATED from tool data in the build notes: the index of every example in Lumen.
// Other chats can be pointed at an example by its id (for example "Lumen R17 Forms").

class Ref {
  const Ref(this.id, this.title, this.section, this.files, this.use);
  final String id;
  final String title;
  final String section;
  final List<String> files;
  final String use;

  /// The line to paste to another chat.
  String get text => 'Lumen $id $title. $use Files: ${files.join(', ')}';
}

const Map<int, Ref> refs = <int, Ref>{
  1: Ref(
    'R01',
    'Glass',
    'Core',
    <String>[
      'lib/rooms/glass/glass_room.dart',
      'lib/core/glass.dart',
      'shaders/glass.frag',
    ],
    'Refracting glass on controls only: a tab bar with a draggable lens, glass buttons, a tuning panel, quality tiers and a solid fallback.',
  ),
  2: Ref(
    'R02',
    'Springs',
    'Core',
    <String>['lib/rooms/springs/springs_room.dart', 'lib/core/springs.dart'],
    'Spring motion against a fixed curve with the same input: retarget mid-flight, drag the target, grab and throw.',
  ),
  3: Ref(
    'R03',
    'Shape morph',
    'Core',
    <String>[
      'lib/rooms/shapes/shape_room.dart',
      'lib/rooms/shapes/shape_loader.dart',
      'lib/core/shapes.dart',
    ],
    'Shapes that morph cleanly: a scrubbable hero shape, toggles, a send button that becomes a loader then a tick, loading indicators.',
  ),
  4: Ref(
    'R04',
    'Flow',
    'Core',
    <String>['lib/rooms/flow/flow_room.dart', 'lib/core/expand_route.dart'],
    'A card grows into a page and returns to its slot; predictive back follows the finger.',
  ),
  5: Ref(
    'R05',
    'Shaders',
    'Core',
    <String>[
      'lib/rooms/shaders/shaders_room.dart',
      'lib/rooms/shaders/progressive_blur.dart',
      'shaders/aurora.frag',
      'shaders/ripple.frag',
      'shaders/pblur.frag',
    ],
    'Three GPU effects: touch-reactive aurora, water ripples that bend live content, progressive blur.',
  ),
  6: Ref(
    'R06',
    'Details',
    'Core',
    <String>[
      'lib/rooms/details/details_room.dart',
      'lib/rooms/details/prompt_bar.dart',
      'lib/rooms/details/small_things.dart',
    ],
    'Scroll-reactive variable type, pull to refresh with a morphing indicator, an AI prompt bar with streaming and trust labels, a like button with rolling digits, a copy button.',
  ),
  7: Ref(
    'R07',
    'Foil',
    'Trends',
    <String>['lib/rooms/foil/foil_room.dart', 'shaders/holo.frag'],
    'Holographic cards that tilt in 3D under a finger or with the phone (gravity sensor).',
  ),
  8: Ref(
    'R08',
    'Dials',
    'Trends',
    <String>['lib/rooms/dials/dials_room.dart'],
    'A knob with haptic notches, fling and end stops; a 3D wheel time picker.',
  ),
  9: Ref(
    'R09',
    'Colour',
    'Trends',
    <String>['lib/rooms/colour/colour_room.dart'],
    'A colour scheme extracted from a picture (k-means) and applied with a glide.',
  ),
  10: Ref(
    'R10',
    'Live pill',
    'Trends',
    <String>['lib/rooms/pill/pill_room.dart'],
    'A status pill that grows into a timer, music or a call, splits in two, and opens into controls.',
  ),
  11: Ref(
    'R11',
    'Data',
    'Trends',
    <String>['lib/rooms/data/data_room.dart'],
    'A chart that morphs between ranges, a magnetic scrub cursor, bars that grow in a wave.',
  ),
  12: Ref(
    'R12',
    'Access',
    'Trends',
    <String>['lib/rooms/access/access_room.dart'],
    'One screen shown at standard, large text, high contrast and reduced motion; screen-reader order and touch areas made visible.',
  ),
  13: Ref(
    'R13',
    'Type',
    'Foundations',
    <String>['lib/rooms/basics/type_room.dart'],
    'Type hierarchy from one scale ratio, with hierarchy on and off, and line height.',
  ),
  14: Ref('R14', 'Space', 'Foundations', <String>[
    'lib/rooms/basics/space_room.dart',
  ], 'Spacing from one base unit, grouping by distance, a grid overlay.'),
  15: Ref('R15', 'Contrast', 'Foundations', <String>[
    'lib/rooms/basics/contrast_room.dart',
  ], 'Live contrast ratio with pass marks; why status needs more than colour.'),
  16: Ref(
    'R16',
    'States',
    'Foundations',
    <String>['lib/rooms/basics/states_room.dart'],
    'A button in six states; a screen that loads with a skeleton and ends as content, empty or error.',
  ),
  17: Ref(
    'R17',
    'Forms',
    'Foundations',
    <String>['lib/rooms/basics/forms_room.dart'],
    'Floating labels, validation that waits until a field is left, password strength, a submit button that shows what is missing.',
  ),
  18: Ref(
    'R18',
    'Sheets',
    'Foundations',
    <String>['lib/rooms/basics/sheets_room.dart'],
    'Swipe a row away with Undo; a bottom sheet with three resting heights, drag and flick.',
  ),
  19: Ref(
    'R19',
    'Performance lab',
    'Patterns',
    <String>['lib/rooms/patterns/perf_room.dart', 'lib/core/frame_stats.dart'],
    'The same screen built the costly way and the cheap way (shadows, blur, idle animation), measured on the device.',
  ),
  20: Ref(
    'R20',
    'Launcher',
    'Patterns',
    <String>[
      'lib/rooms/patterns/launcher_room.dart',
      'lib/widgets/spring_box.dart',
    ],
    'A home screen: drag to reorder with icons making room, folders by dropping one icon on another, a dock, an app drawer with search.',
  ),
  21: Ref(
    'R21',
    'Blob menu',
    'Patterns',
    <String>['lib/rooms/patterns/blob_room.dart'],
    'One button that splits into three to five actions on an arc; tap, or press and slide to choose.',
  ),
  22: Ref(
    'R22',
    'Timers',
    'Patterns',
    <String>['lib/rooms/patterns/timer_room.dart'],
    'A rest timer stored as an end time, redrawn once a second, with a pill that stays visible while scrolling.',
  ),
  23: Ref(
    'R23',
    'Inputs',
    'Patterns',
    <String>['lib/rooms/patterns/inputs_room.dart'],
    'Number entry for workouts: a weight ruler with ticks and fling, steppers that repeat while held, set rows with a tick.',
  ),
  24: Ref(
    'R24',
    'Do and don\'t',
    'Patterns',
    <String>['lib/rooms/patterns/dodont_room.dart'],
    'Common mistakes next to the fix: spinner and skeleton, confirm and undo, vanishing and persistent labels, small and proper touch targets.',
  ),
  99: Ref(
    'B01',
    'Discomorphism',
    'Bonus',
    <String>['lib/rooms/disco/disco_room.dart', 'shaders/disco.frag'],
    'A mirror ball shader, a dance floor and a haptic beat. A joke; also a ray-per-tile shading example.',
  ),
};
