import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/room_header.dart';
import '../flow/stories.dart';

class _Swatch {
  const _Swatch(this.color, this.share);
  final Color color;
  final double share;
}

/// Finds the main colours of a picture: render it small, then group its
/// pixels into five clusters (k-means), and score each cluster by size and
/// colourfulness to pick the seed.
Future<(List<_Swatch>, Color)> _extract(Story story) async {
  const int n = 72;
  final ui.PictureRecorder rec = ui.PictureRecorder();
  StoryArt(story).paint(Canvas(rec), const Size(n * 1.0, n * 1.0));
  final ui.Image img = await rec.endRecording().toImage(n, n);
  final ByteData data = (await img.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  img.dispose();
  final int count = n * n;
  final Float64List px = Float64List(count * 3);
  for (int i = 0; i < count; i++) {
    px[i * 3] = data.getUint8(i * 4).toDouble();
    px[i * 3 + 1] = data.getUint8(i * 4 + 1).toDouble();
    px[i * 3 + 2] = data.getUint8(i * 4 + 2).toDouble();
  }
  const int k = 5;
  // Start from pixels spread across the brightness range.
  final List<int> order = List<int>.generate(count, (int i) => i)
    ..sort(
      (int a, int b) => (px[a * 3] + px[a * 3 + 1] + px[a * 3 + 2]).compareTo(
        px[b * 3] + px[b * 3 + 1] + px[b * 3 + 2],
      ),
    );
  final List<List<double>> centres = <List<double>>[
    for (int j = 0; j < k; j++)
      <double>[
        px[order[(count * (j + 0.5) / k).floor()] * 3],
        px[order[(count * (j + 0.5) / k).floor()] * 3 + 1],
        px[order[(count * (j + 0.5) / k).floor()] * 3 + 2],
      ],
  ];
  final List<int> sizes = List<int>.filled(k, 0);
  for (int iter = 0; iter < 10; iter++) {
    final List<List<double>> sum = List<List<double>>.generate(
      k,
      (_) => <double>[0, 0, 0],
    );
    sizes.fillRange(0, k, 0);
    for (int i = 0; i < count; i++) {
      int best = 0;
      double bd = double.infinity;
      for (int j = 0; j < k; j++) {
        final double dr = px[i * 3] - centres[j][0],
            dg = px[i * 3 + 1] - centres[j][1],
            db = px[i * 3 + 2] - centres[j][2];
        final double d = dr * dr + dg * dg + db * db;
        if (d < bd) {
          bd = d;
          best = j;
        }
      }
      sizes[best]++;
      sum[best][0] += px[i * 3];
      sum[best][1] += px[i * 3 + 1];
      sum[best][2] += px[i * 3 + 2];
    }
    for (int j = 0; j < k; j++) {
      if (sizes[j] > 0) {
        centres[j] = <double>[
          sum[j][0] / sizes[j],
          sum[j][1] / sizes[j],
          sum[j][2] / sizes[j],
        ];
      }
    }
  }
  final List<_Swatch> swatches = <_Swatch>[
    for (int j = 0; j < k; j++)
      if (sizes[j] > 0)
        _Swatch(
          Color.fromARGB(
            255,
            centres[j][0].round(),
            centres[j][1].round(),
            centres[j][2].round(),
          ),
          sizes[j] / count,
        ),
  ]..sort((_Swatch a, _Swatch b) => b.share.compareTo(a.share));
  Color seed = swatches.first.color;
  double bestScore = -1;
  for (final _Swatch s in swatches) {
    final HSVColor h = HSVColor.fromColor(s.color);
    final double score = math.sqrt(s.share) * h.saturation * (0.3 + h.value);
    if (score > bestScore) {
      bestScore = score;
      seed = s.color;
    }
  }
  return (swatches, seed);
}

/// Room 09. One picture becomes a whole colour scheme.
class ColourRoom extends StatefulWidget {
  const ColourRoom({super.key});

  @override
  State<ColourRoom> createState() => _ColourRoomState();
}

class _ColourRoomState extends State<ColourRoom> with TickerProviderStateMixin {
  int _pic = 0;
  DynamicSchemeVariant _variant = DynamicSchemeVariant.tonalSpot;
  List<_Swatch> _swatches = const <_Swatch>[];
  Color? _seed;
  ColorScheme? _from;
  ColorScheme? _to;
  late final SpringValue _t = SpringValue(
    this,
    value: 1,
    spring: Motions.spatialSlow,
  );
  late final SpringValue _swatchIn = SpringValue(
    this,
    spring: Motions.expressive,
  );
  Brightness? _brightness;

  static const List<(DynamicSchemeVariant, String)> _variants =
      <(DynamicSchemeVariant, String)>[
        (DynamicSchemeVariant.tonalSpot, 'Calm'),
        (DynamicSchemeVariant.vibrant, 'Vibrant'),
        (DynamicSchemeVariant.expressive, 'Playful'),
        (DynamicSchemeVariant.fidelity, 'Faithful'),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Brightness b = Theme.of(context).brightness;
    if (b != _brightness) {
      _brightness = b;
      _choose(_pic, first: _seed == null);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _swatchIn.dispose();
    super.dispose();
  }

  Future<void> _choose(int i, {bool first = false}) async {
    final (List<_Swatch> sw, Color seed) = await _extract(stories[i]);
    if (!mounted) {
      return;
    }
    setState(() {
      _pic = i;
      _swatches = sw;
      _seed = seed;
    });
    _swatchIn.jumpTo(0);
    _swatchIn.animateTo(1);
    _retheme(first: first);
  }

  void _retheme({bool first = false}) {
    final ColorScheme next = ColorScheme.fromSeed(
      seedColor: _seed!,
      brightness: _brightness!,
      dynamicSchemeVariant: _variant,
    );
    final ColorScheme current = _to == null
        ? next
        : ColorScheme.lerp(_from ?? _to!, _to!, _t.value.clamp(0.0, 1.0));
    setState(() {
      _from = current;
      _to = next;
    });
    if (first) {
      _t.jumpTo(1);
    } else {
      _t.jumpTo(0);
      _t.onSettle = Haptics.settle;
      _t.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 32),
        children: <Widget>[
          const RoomHeader(
            number: 9,
            title: 'Colour',
            hint:
                'Trend: personal colour. The interface takes its palette from something you chose, '
                'like a wallpaper or a photo. Pick a picture: its colours are found on the phone, then grown into a full scheme.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: stories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int i) => GestureDetector(
                onTap: () => _choose(i),
                child: Container(
                  width: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: i == _pic ? c.ink : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(painter: StoryArt(stories[i])),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _extracted(c),
          const SizedBox(height: 16),
          Segmented<DynamicSchemeVariant>(
            values: _variants
                .map(((DynamicSchemeVariant, String) v) => v.$1)
                .toList(),
            labels: _variants
                .map(((DynamicSchemeVariant, String) v) => v.$2)
                .toList(),
            value: _variant,
            onChanged: (DynamicSchemeVariant v) {
              setState(() => _variant = v);
              _retheme();
            },
          ),
          const SizedBox(height: 16),
          if (_to != null)
            ListenableBuilder(
              listenable: _t,
              builder: (BuildContext context, Widget? _) {
                final ColorScheme s = ColorScheme.lerp(
                  _from!,
                  _to!,
                  _t.value.clamp(0.0, 1.0),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _mock(s),
                    const SizedBox(height: 16),
                    _roles(c, s),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _extracted(LumenColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'FOUND IN THE PICTURE',
            style: LumenType.label(color: c.inkFaint),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _swatchIn,
            builder: (BuildContext context, Widget? _) => Row(
              children: <Widget>[
                for (int i = 0; i < _swatches.length; i++)
                  Expanded(
                    flex: math.max(1, (_swatches[i].share * 100).round()),
                    child: Transform.scale(
                      scaleY: (_swatchIn.value * 1.4 - i * 0.1).clamp(0.0, 1.3),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: ShapeDecoration(
                          color: _swatches[i].color,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _swatches[i].color == _seed
                                  ? c.ink
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Widths show how much of the picture each colour covers. The outlined one is the seed: '
            'the biggest colour that is also colourful.',
            style: LumenType.text(12.5, color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  /// A small app screen painted entirely from the derived scheme.
  Widget _mock(ColorScheme s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(
        color: s.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: s.primaryContainer,
                child: Icon(
                  Icons.landscape_rounded,
                  color: s.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      stories[_pic].title,
                      style: LumenType.text(
                        17,
                        weight: 650,
                        color: s.onSurface,
                      ),
                    ),
                    Text(
                      'Saved walk',
                      style: LumenType.text(13, color: s.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: s.tertiaryContainer,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: s.onTertiaryContainer,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: s.surfaceContainerHigh,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stories[_pic].lede,
                  style: LumenType.text(14.5, color: s.onSurface, height: 1.4),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.64,
                    minHeight: 6,
                    color: s.primary,
                    backgroundColor: s.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String t in <String>['Coast', 'Easy', '2 h'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: ShapeDecoration(
                    color: s.secondaryContainer,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    t,
                    style: LumenType.text(
                      13,
                      weight: 560,
                      color: s.onSecondaryContainer,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: s.primary,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Start walk',
                    style: LumenType.text(
                      15,
                      weight: 640,
                      color: s.onPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: s.outline)),
                  ),
                  child: Text(
                    'Share',
                    style: LumenType.text(
                      15,
                      weight: 640,
                      color: s.primary,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roles(LumenColors c, ColorScheme s) {
    final List<(String, Color, Color)> roles = <(String, Color, Color)>[
      ('Primary', s.primary, s.onPrimary),
      ('Primary container', s.primaryContainer, s.onPrimaryContainer),
      ('Secondary', s.secondary, s.onSecondary),
      ('Secondary container', s.secondaryContainer, s.onSecondaryContainer),
      ('Tertiary', s.tertiary, s.onTertiary),
      ('Tertiary container', s.tertiaryContainer, s.onTertiaryContainer),
      ('Surface', s.surface, s.onSurface),
      ('Surface high', s.surfaceContainerHigh, s.onSurface),
    ];
    String hex(Color x) =>
        '#${(x.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'THE SCHEME, ROLE BY ROLE',
            style: LumenType.label(color: c.inkFaint),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: <Widget>[
            for (final (String name, Color bg, Color fg) in roles)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: ShapeDecoration(
                  color: bg,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: c.hairline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumenType.text(
                        13,
                        weight: 620,
                        color: fg,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      hex(bg),
                      style: LumenType.text(
                        11.5,
                        color: fg.withValues(alpha: 0.75),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
