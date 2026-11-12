import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Content for the glass to sit over. Generated, not downloaded: bold
/// colour, hard edges and big type make refraction easy to see.
class FeedSpec {
  const FeedSpec(this.name, this.caption, this.icon, this.palette, this.words);
  final String name;
  final String caption;
  final IconData icon;
  final List<Color> palette;
  final List<String> words;
}

const List<FeedSpec> feeds = <FeedSpec>[
  FeedSpec(
    'Dawn',
    'Warm colour. The easy case for glass.',
    Icons.wb_twilight_rounded,
    <Color>[
      Color(0xFFFF6B4A),
      Color(0xFFFFB23E),
      Color(0xFFFF4D8D),
      Color(0xFF6C4DFF),
      Color(0xFF2A1B4D),
    ],
    <String>['RISE', 'GLOW', 'WARM', 'SOFT'],
  ),
  FeedSpec(
    'Reef',
    'Cool colour with sharp detail.',
    Icons.water_rounded,
    <Color>[
      Color(0xFF12D6B0),
      Color(0xFF2E7BFF),
      Color(0xFFB6F23A),
      Color(0xFF083B5C),
      Color(0xFF7CE8FF),
    ],
    <String>['TIDE', 'DEEP', 'KELP', 'SALT'],
  ),
  FeedSpec(
    'Neon',
    'High contrast. Hard on legibility.',
    Icons.bolt_rounded,
    <Color>[
      Color(0xFFFF2BD6),
      Color(0xFF2B50FF),
      Color(0xFF0A0A14),
      Color(0xFF00F0FF),
      Color(0xFFF9F871),
    ],
    <String>['LOUD', 'VOLT', 'RUSH', 'LATE'],
  ),
  FeedSpec(
    'Paper',
    'Almost white. The worst case for glass.',
    Icons.article_rounded,
    <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFF1ECE2),
      Color(0xFF111111),
      Color(0xFFE5361F),
      Color(0xFFD8D2C4),
    ],
    <String>['READ', 'INK', 'NOTE', 'PLAIN'],
  ),
];

class Feed extends StatelessWidget {
  const Feed({
    super.key,
    required this.index,
    required this.topInset,
    required this.bottomInset,
  });
  final int index;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final FeedSpec f = feeds[index];
    const double gap = 12;
    Widget poster(int i, double h) => RepaintBoundary(
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: h,
          child: CustomPaint(painter: PosterPainter(f, i)),
        ),
      ),
    );

    final List<Widget> rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('ROOM 01  ·  GLASS', style: LumenType.label(color: c.accent)),
            const SizedBox(height: 10),
            Text(
              f.name,
              style: LumenType.display(
                64,
                weight: 780,
                width: 92,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(f.caption, style: LumenType.text(15.5, color: c.inkMuted)),
          ],
        ),
      ),
    ];
    int n = 0;
    for (int block = 0; block < 4; block++) {
      rows.add(poster(n++, 300));
      rows.add(const SizedBox(height: gap));
      rows.add(
        Row(
          children: <Widget>[
            Expanded(child: poster(n++, 190)),
            const SizedBox(width: gap),
            Expanded(child: poster(n++, 190)),
          ],
        ),
      );
      rows.add(const SizedBox(height: gap));
      rows.add(poster(n++, 220));
      rows.add(const SizedBox(height: gap));
    }

    return ListView(
      key: PageStorageKey<int>(index),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16, topInset, 16, bottomInset),
      children: rows,
    );
  }
}

class PosterPainter extends CustomPainter {
  const PosterPainter(this.feed, this.i);
  final FeedSpec feed;
  final int i;

  Color _c(int k) => feed.palette[k % feed.palette.length];

  Color _on(Color bg) => bg.computeLuminance() > 0.55
      ? const Color(0xFF111111)
      : const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size s) {
    final Rect r = Offset.zero & s;
    final math.Random rnd = math.Random(feed.name.hashCode ^ (i * 7919));
    final int kind = i % 5;
    final int shift = i ~/ 5 + i;
    switch (kind) {
      case 0: // big word on a two-colour field
        final Color a = _c(shift), b = _c(shift + 1);
        canvas.drawRect(r, Paint()..color = a);
        canvas.drawPath(
          Path()
            ..moveTo(0, s.height * 0.62)
            ..lineTo(s.width, s.height * 0.30)
            ..lineTo(s.width, s.height)
            ..lineTo(0, s.height)
            ..close(),
          Paint()..color = b,
        );
        _word(canvas, s, feed.words[(i ~/ 5) % feed.words.length], _on(a));
      case 1: // diagonal stripes
        canvas.drawRect(r, Paint()..color = _c(shift + 2));
        canvas.save();
        canvas.translate(s.width / 2, s.height / 2);
        canvas.rotate(-0.6);
        final double w = 22 + rnd.nextInt(3) * 6;
        int k = 0;
        for (double x = -s.longestSide; x < s.longestSide; x += w * 2) {
          canvas.drawRect(
            Rect.fromLTWH(x, -s.longestSide, w, s.longestSide * 2),
            Paint()..color = _c(shift + (k++ % 2 == 0 ? 0 : 3)),
          );
        }
        canvas.restore();
      case 2: // sun over lines
        final Color sky = _c(shift + 3);
        canvas.drawRect(r, Paint()..color = sky);
        canvas.drawCircle(
          Offset(s.width * 0.5, s.height * 0.56),
          s.shortestSide * 0.36,
          Paint()..color = _c(shift),
        );
        final Paint line = Paint()..color = sky;
        for (int k = 0; k < 6; k++) {
          final double y = s.height * 0.58 + k * (s.height * 0.07);
          canvas.drawRect(Rect.fromLTWH(0, y, s.width, 3.0 + k * 1.6), line);
        }
        canvas.drawCircle(
          Offset(s.width * 0.82, s.height * 0.18),
          9,
          Paint()..color = _c(shift + 1),
        );
      case 3: // dot grid
        final Color bg = _c(shift + 4);
        canvas.drawRect(r, Paint()..color = bg);
        const double step = 26;
        int row = 0;
        for (double y = step / 2 + 4; y < s.height; y += step) {
          int col = 0;
          for (double x = step / 2 + 4; x < s.width; x += step) {
            canvas.drawCircle(
              Offset(x, y),
              7,
              Paint()..color = _c(shift + ((row + col) % 3 == 0 ? 1 : 0)),
            );
            col++;
          }
          row++;
        }
      case 4: // rings
        final Color bg = _c(shift + 1);
        canvas.drawRect(r, Paint()..color = bg);
        final Offset o = Offset(
          s.width * (0.2 + rnd.nextDouble() * 0.6),
          s.height * 1.05,
        );
        for (int k = 0; k < 12; k++) {
          canvas.drawCircle(
            o,
            24.0 + k * 26,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 11
              ..color = _c(shift + (k.isEven ? 3 : 2)),
          );
        }
    }
    // Caption chip, so there is always some small text to look at through glass.
    final Color chipInk = kind == 0 ? _on(_c(shift)) : const Color(0xFFFFFFFF);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'No. ${(i + 1).toString().padLeft(2, '0')}',
        style: LumenType.text(12, weight: 650, color: chipInk, height: 1.1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (kind != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(14, 14, tp.width + 20, 26),
          const Radius.circular(13),
        ),
        Paint()..color = const Color(0xB3000000),
      );
      tp.paint(canvas, const Offset(24, 20));
    } else {
      tp.paint(canvas, const Offset(20, 20));
    }
    tp.dispose();
  }

  void _word(Canvas canvas, Size s, String word, Color ink) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: word,
        style: LumenType.display(
          s.width * 0.34,
          weight: 800,
          width: 88,
          color: ink,
          height: 0.9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(16, s.height - tp.height - 10));
    tp.dispose();
  }

  @override
  bool shouldRepaint(PosterPainter old) => old.feed != feed || old.i != i;
}
