import 'package:material_ui/material_ui.dart';

import '../../core/glass.dart';
import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tag.dart';
import '../flow/stories.dart';

/// Room 27. A complete detail page: a hero picture that moves slower than
/// the page (parallax), the facts up front, and the one action that matters
/// floating at the bottom as glass.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  bool _saved = false;
  late final SpringValue _pop = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );

  @override
  void dispose() {
    _scroll.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Story s = stories[1];
    const double hero = 380;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          // The hero sits behind the page and travels at 45 % of its speed.
          ListenableBuilder(
            listenable: _scroll,
            builder: (BuildContext context, Widget? child) {
              final double off = _scroll.hasClients ? _scroll.offset : 0;
              return Positioned(
                top: off < 0 ? 0 : -off * 0.45,
                left: 0,
                right: 0,
                height: hero + (off < 0 ? -off : 0),
                child: child!,
              );
            },
            child: Tag(
              'R27.1',
              'Hero with parallax',
              child: RepaintBoundary(
                child: CustomPaint(size: Size.infinite, painter: StoryArt(s)),
              ),
            ),
          ),
          ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(top: hero - 36, bottom: safe.bottom + 120),
            children: <Widget>[
              Container(
                decoration: ShapeDecoration(
                  color: c.bg,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Tag(
                      'R27.2',
                      'Title block',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.place.toUpperCase(),
                            style: LumenType.label(color: c.accent),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.title} ridge walk',
                            style: LumenType.display(
                              36,
                              weight: 740,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFF5B301),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '4.8',
                                style: LumenType.text(
                                  14.5,
                                  weight: 680,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                '  ·  214 walkers',
                                style: LumenType.text(14, color: c.inkMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Tag(
                      'R27.3',
                      'Fact chips',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final (IconData i, String t)
                              in <(IconData, String)>[
                                (Icons.schedule_rounded, '3 h 20'),
                                (Icons.straighten_rounded, '9.0 km'),
                                (Icons.terrain_rounded, '540 m up'),
                                (Icons.local_fire_department_outlined, 'Steep'),
                              ])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: ShapeDecoration(
                                color: c.surface,
                                shape: StadiumBorder(
                                  side: BorderSide(color: c.hairline),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(i, size: 16, color: c.inkMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    t,
                                    style: LumenType.text(
                                      13.5,
                                      weight: 600,
                                      color: c.ink,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.lede,
                      style: LumenType.display(
                        21,
                        weight: 560,
                        color: c.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final String p in s.body) ...<Widget>[
                      Text(
                        p,
                        style: LumenType.text(
                          16,
                          color: c.inkMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Good to know',
                      style: LumenType.display(22, weight: 700, color: c.ink),
                    ),
                    const SizedBox(height: 10),
                    Tag(
                      'R27.4',
                      'Highlights list',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: c.surface,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(26),
                            side: BorderSide(color: c.hairline),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            for (final (IconData i, String t, String d)
                                in <(IconData, String, String)>[
                                  (
                                    Icons.water_drop_outlined,
                                    'Bring water',
                                    'No springs after the first hour.',
                                  ),
                                  (
                                    Icons.wb_twilight_rounded,
                                    'Best at dusk',
                                    'The rock holds the day\'s warmth.',
                                  ),
                                  (
                                    Icons.air_rounded,
                                    'Mind the wind',
                                    'It turns quickly once the sun is down.',
                                  ),
                                ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(i, size: 22, color: c.accent),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            t,
                                            style: LumenType.text(
                                              15.5,
                                              weight: 620,
                                              color: c.ink,
                                            ),
                                          ),
                                          Text(
                                            d,
                                            style: LumenType.text(
                                              13.5,
                                              color: c.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            right: 16,
            child: const ScreenBar(number: 27),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safe.bottom + 16,
            child: Tag(
              'R27.5',
              'Glass action bar',
              child: SizedBox(
                height: 72,
                child: Glass(
                  radius: 36,
                  // Text sits on this pane, so it uses the more opaque glass.
                  style: GlassStyle(
                    blur: 22,
                    tint: 0.56,
                    refraction: 26,
                    bevel: 18,
                    dispersion: 0.16,
                    fallbackColor: c.surfaceHigh,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 22, right: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Free',
                                style: LumenType.text(
                                  17,
                                  weight: 700,
                                  color: c.glassInk,
                                ),
                              ),
                              Text(
                                'Offline map included',
                                style: LumenType.text(
                                  12.5,
                                  color: c.glassInk.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _saved = !_saved);
                            _pop.jumpTo(0.6);
                            _pop.animateTo(1, velocity: 8);
                            Haptics.tick();
                          },
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: ListenableBuilder(
                              listenable: _pop,
                              builder: (BuildContext context, Widget? _) =>
                                  Transform.scale(
                                    scale: _pop.value,
                                    child: Icon(
                                      _saved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      color: _saved ? c.accent : c.glassInk,
                                      size: 26,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Pressable(
                          onTap: Haptics.settle,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: c.accent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Start walk',
                              style: LumenType.text(
                                15.5,
                                weight: 680,
                                color: c.onAccent,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
