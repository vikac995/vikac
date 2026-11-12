import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

class Story {
  const Story(
    this.title,
    this.place,
    this.palette,
    this.seed,
    this.lede,
    this.body,
  );
  final String title;
  final String place;

  /// sky top, sky bottom, sun, far hills, near hills
  final List<Color> palette;
  final int seed;
  final String lede;
  final List<String> body;
}

const List<Story> stories = <Story>[
  Story(
    'Tidal',
    'North Sea, low tide',
    <Color>[
      Color(0xFF0E2A47),
      Color(0xFF3F8FB5),
      Color(0xFFFFE3A3),
      Color(0xFF1C5873),
      Color(0xFF0B2236),
    ],
    3,
    'The water leaves twice a day, and the flats fill with light.',
    <String>[
      'At low tide the sea pulls back almost to the horizon. What it leaves is a mirror a few millimetres deep, and the sky lands in it twice.',
      'Walkers keep to the ridges where the sand is firm. The channels between them move every season, so the routes are learned again each spring.',
      'By the time the water turns, the light has gone from white to amber, and the mirror breaks into a thousand small ones.',
    ],
  ),
  Story(
    'Ember',
    'Volcanic ridge, dusk',
    <Color>[
      Color(0xFF2B0F1E),
      Color(0xFFE2563A),
      Color(0xFFFFC46B),
      Color(0xFF7A1F2B),
      Color(0xFF2A0C14),
    ],
    7,
    'A ridge that still holds the warmth of the day after dark.',
    <String>[
      'The rock here is young. It cracks in straight lines and keeps the heat long after sunset, so the path is warm under your hand on the way down.',
      'From the top you can see three valleys, each a different colour as the light leaves them: rust, then rose, then a grey that is nearly blue.',
      'Nobody lingers once the wind turns. It comes up from the sea all at once, and the warmth goes with it.',
    ],
  ),
  Story(
    'Moss',
    'Old forest, after rain',
    <Color>[
      Color(0xFF0F2A1E),
      Color(0xFF5E9E6E),
      Color(0xFFE8F5C8),
      Color(0xFF285A3A),
      Color(0xFF0C2016),
    ],
    11,
    'Green on green on green, and every surface soft.',
    <String>[
      'After rain the forest sounds different. Drops fall from three heights at once and the floor answers each of them.',
      'Moss covers the fallen trunks so completely that the shapes become hills. Children take them for animals asleep.',
      'The paths are old enough that the roots have learned them, and step aside.',
    ],
  ),
  Story(
    'Dune',
    'Inland desert, noon',
    <Color>[
      Color(0xFFF2B36B),
      Color(0xFFF7DDB0),
      Color(0xFFFFF6E0),
      Color(0xFFD98A4E),
      Color(0xFFB0602E),
    ],
    5,
    'Lines drawn by wind, redrawn every night.',
    <String>[
      'At noon the dunes lose their shadows and the desert goes flat and bright. The only depth is in the ridges, sharp as folded paper.',
      'By morning the wind will have moved every ridge a hand to the east. Footprints last a day, sometimes less.',
      'Water is three days in any direction, so the people who live here measure distance in mornings.',
    ],
  ),
  Story(
    'Nocturne',
    'High plateau, 2 a.m.',
    <Color>[
      Color(0xFF05060F),
      Color(0xFF1D1E4A),
      Color(0xFFDCE3FF),
      Color(0xFF131536),
      Color(0xFF06070F),
    ],
    13,
    'So far from a town that the sky has texture.',
    <String>[
      'Up here the stars are not points but dust, and the dust has rivers in it.',
      'The cold comes in steps. Each hour after midnight is a degree or two colder than the last, and the grass stiffens with frost by four.',
      'If you wait long enough, a satellite crosses, then another, then a meteor so bright it leaves a line behind your eyes.',
    ],
  ),
  Story(
    'Bloom',
    'Valley meadow, late spring',
    <Color>[
      Color(0xFF7FB3E8),
      Color(0xFFF4D6E6),
      Color(0xFFFFF4C9),
      Color(0xFFE77FA8),
      Color(0xFF8E3E6E),
    ],
    17,
    'A week in May when the whole valley turns pink.',
    <String>[
      'It happens in a week. One morning the slopes are green, the next they are pink, and the bees arrive before the people do.',
      'The flowers face the sun and turn with it, so the colour of the valley shifts through the day from rose to violet.',
      'By the second week the petals are on the river, and the town downstream knows the meadow has peaked.',
    ],
  ),
];

/// A generated landscape: sky, sun and two ranges of hills.
class StoryArt extends CustomPainter {
  const StoryArt(this.story);
  final Story story;

  @override
  void paint(Canvas canvas, Size s) {
    final List<Color> p = story.palette;
    final Rect r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[p[0], p[1]],
        ).createShader(r),
    );
    final math.Random rnd = math.Random(story.seed);
    final bool night = story.title == 'Nocturne';
    if (night) {
      for (int i = 0; i < 140; i++) {
        final double x = rnd.nextDouble() * s.width,
            y = rnd.nextDouble() * s.height * 0.7;
        canvas.drawCircle(
          Offset(x, y),
          rnd.nextDouble() * 1.3 + 0.3,
          Paint()
            ..color = Colors.white.withValues(
              alpha: 0.35 + rnd.nextDouble() * 0.6,
            ),
        );
      }
    }
    final Offset sun = Offset(
      s.width * (0.25 + rnd.nextDouble() * 0.5),
      s.height * (0.32 + rnd.nextDouble() * 0.12),
    );
    final double sr = s.shortestSide * (night ? 0.08 : 0.16);
    canvas.drawCircle(
      sun,
      sr * 2.6,
      Paint()
        ..color = p[2].withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sr),
    );
    canvas.drawCircle(sun, sr, Paint()..color = p[2]);

    Path hills(double base, double amp, double freq, double phase) {
      final Path path = Path()..moveTo(0, s.height);
      for (int i = 0; i <= 48; i++) {
        final double x = i / 48 * s.width;
        final double y =
            s.height * base -
            amp *
                s.height *
                (0.6 * math.sin(x / s.width * freq + phase) +
                    0.4 * math.sin(x / s.width * freq * 2.3 + phase * 1.7));
        path.lineTo(x, y);
      }
      return path
        ..lineTo(s.width, s.height)
        ..close();
    }

    canvas.drawPath(
      hills(0.70, 0.07, 5.0, rnd.nextDouble() * 6),
      Paint()..color = p[3],
    );
    canvas.drawPath(
      hills(0.84, 0.06, 3.4, rnd.nextDouble() * 6),
      Paint()..color = p[4],
    );
  }

  @override
  bool shouldRepaint(StoryArt old) => old.story != story;
}

/// The card on the Flow room's grid. Also drawn by the route as the page
/// grows out of it, so the two must match.
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final bool lightSky = story.palette[1].computeLuminance() > 0.5;
    final Color ink = lightSky ? const Color(0xFF1A1414) : Colors.white;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(child: CustomPaint(painter: StoryArt(story))),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  story.title,
                  style: LumenType.display(
                    25,
                    weight: 700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  story.place,
                  style: LumenType.text(
                    12.5,
                    weight: 520,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: Icon(
              Icons.north_east_rounded,
              size: 18,
              color: ink.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
