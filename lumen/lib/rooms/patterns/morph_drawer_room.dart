import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/shapes.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';

const List<(String, IconData)> _names = <(String, IconData)>[
  ('Alarm', Icons.alarm_rounded),
  ('Atlas', Icons.public_rounded),
  ('Bank', Icons.account_balance_rounded),
  ('Books', Icons.menu_book_rounded),
  ('Bus', Icons.directions_bus_rounded),
  ('Calendar', Icons.calendar_month_rounded),
  ('Camera', Icons.photo_camera_rounded),
  ('Chat', Icons.chat_bubble_rounded),
  ('Clock', Icons.schedule_rounded),
  ('Cloud', Icons.cloud_rounded),
  ('Compass', Icons.explore_rounded),
  ('Contacts', Icons.person_rounded),
  ('Cook', Icons.restaurant_rounded),
  ('Dial', Icons.phone_rounded),
  ('Draw', Icons.brush_rounded),
  ('Email', Icons.mail_rounded),
  ('Files', Icons.folder_rounded),
  ('Films', Icons.movie_rounded),
  ('Find', Icons.search_rounded),
  ('Flights', Icons.flight_rounded),
  ('Gallery', Icons.photo_rounded),
  ('Games', Icons.sports_esports_rounded),
  ('Garden', Icons.local_florist_rounded),
  ('Health', Icons.favorite_rounded),
  ('Home', Icons.home_rounded),
  ('Keys', Icons.key_rounded),
  ('Lamp', Icons.lightbulb_rounded),
  ('Learn', Icons.school_rounded),
  ('Maps', Icons.map_rounded),
  ('Maths', Icons.calculate_rounded),
  ('Music', Icons.music_note_rounded),
  ('News', Icons.article_rounded),
  ('Notes', Icons.sticky_note_2_rounded),
  ('Paint', Icons.palette_rounded),
  ('Pay', Icons.credit_card_rounded),
  ('Pets', Icons.pets_rounded),
  ('Podcasts', Icons.podcasts_rounded),
  ('Print', Icons.print_rounded),
  ('Radio', Icons.radio_rounded),
  ('Recorder', Icons.mic_rounded),
  ('Rides', Icons.local_taxi_rounded),
  ('Run', Icons.directions_run_rounded),
  ('Scan', Icons.qr_code_scanner_rounded),
  ('Settings', Icons.settings_rounded),
  ('Shop', Icons.shopping_bag_rounded),
  ('Sleep', Icons.bedtime_rounded),
  ('Sports', Icons.sports_soccer_rounded),
  ('Stocks', Icons.show_chart_rounded),
  ('Store', Icons.storefront_rounded),
  ('Tasks', Icons.task_alt_rounded),
  ('Tickets', Icons.confirmation_number_rounded),
  ('Timer', Icons.timer_rounded),
  ('Trains', Icons.train_rounded),
  ('Translate', Icons.translate_rounded),
  ('Travel', Icons.luggage_rounded),
  ('Tune', Icons.tune_rounded),
  ('Video', Icons.videocam_rounded),
  ('Voice', Icons.graphic_eq_rounded),
  ('Wallet', Icons.account_balance_wallet_rounded),
  ('Watch', Icons.watch_rounded),
  ('Water', Icons.water_drop_rounded),
  ('Weather', Icons.wb_sunny_rounded),
  ('Web', Icons.language_rounded),
  ('Weights', Icons.fitness_center_rounded),
  ('Wifi', Icons.wifi_rounded),
  ('Words', Icons.spellcheck_rounded),
  ('Work', Icons.work_rounded),
  ('Yoga', Icons.self_improvement_rounded),
  ('Zen', Icons.spa_rounded),
  ('Zip', Icons.folder_zip_rounded),
  ('Zoo', Icons.cruelty_free_rounded),
  ('Zoom', Icons.zoom_in_rounded),
];
const List<Color> _hues = <Color>[
  Color(0xFFE5484D),
  Color(0xFFF2784B),
  Color(0xFFF5B301),
  Color(0xFF6FBF4A),
  Color(0xFF2FB7A3),
  Color(0xFF3FA9F5),
  Color(0xFF5B6CFF),
  Color(0xFF9B5CF6),
  Color(0xFFE0457B),
];

/// Room 55. An app drawer that does not scroll. The grid stays where it is
/// and each icon turns into the next one: its outline, colour, picture and
/// name all change in place, in a wave that follows the finger.
class MorphDrawerRoom extends StatefulWidget {
  const MorphDrawerRoom({super.key});

  @override
  State<MorphDrawerRoom> createState() => _MorphDrawerRoomState();
}

class _MorphDrawerRoomState extends State<MorphDrawerRoom>
    with SingleTickerProviderStateMixin {
  static const int _cols = 4, _rows = 6, _per = _cols * _rows;
  static final int _pages = (_names.length / _per).ceil();
  // Where we are in the list, in pages. 1.5 is halfway between the second and third.
  late final SpringValue _page = SpringValue(this, spring: Motions.expressive);
  double _dragFrom = 0;
  int _lastTick = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _drag(double dy, double height) {
    // A full page takes about 60 % of the grid's height of finger travel.
    final double p = (_page.value - dy / (height * 0.6)).clamp(
      -0.15,
      _pages - 1 + 0.15,
    );
    _page.jumpTo(p);
    final int step = (p * _rows).round();
    if (step != _lastTick) {
      _lastTick = step;
      Haptics.tick(); // one tick per row that turns over
    }
  }

  void _end(double velocity, double height) {
    final double v = -velocity / (height * 0.6);
    final int to = (_page.value + v * 0.18).round().clamp(0, _pages - 1);
    _page.animateTo(to.toDouble(), velocity: v);
    Haptics.settle();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const RoomHeader(number: 55, title: 'Morphing drawer'),
            const SizedBox(height: 8),
            Text(
              'Swipe up or down. Nothing scrolls: every icon turns into the next one where it stands.',
              style: LumenType.text(14, color: c.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final double cw = (box.maxWidth - 30) / _cols,
                      ch = box.maxHeight / _rows;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => _dragFrom = _page.value,
                    onVerticalDragUpdate: (DragUpdateDetails d) =>
                        _drag(d.delta.dy, box.maxHeight),
                    onVerticalDragEnd: (DragEndDetails d) =>
                        _end(d.primaryVelocity ?? 0, box.maxHeight),
                    onVerticalDragCancel: () =>
                        _page.animateTo(_dragFrom.roundToDouble()),
                    child: ListenableBuilder(
                      listenable: _page,
                      builder: (BuildContext context, Widget? _) {
                        final double p = _page.value;
                        return Stack(
                          children: <Widget>[
                            for (int r = 0; r < _rows; r++)
                              for (int col = 0; col < _cols; col++)
                                Positioned(
                                  left: col * cw,
                                  top: r * ch,
                                  width: cw,
                                  height: ch,
                                  child: _cell(c, r, col, p, math.min(cw, ch)),
                                ),
                            // Where you are in the alphabet, and how far through.
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 22,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  for (int i = 0; i < _pages; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      child: Builder(
                                        builder: (BuildContext context) {
                                          final double on = (1 - (p - i).abs())
                                              .clamp(0.0, 1.0);
                                          return Container(
                                            width: 6,
                                            height: 10 + 26 * on,
                                            decoration: ShapeDecoration(
                                              color: Color.lerp(
                                                c.ink.withValues(alpha: 0.18),
                                                c.accent,
                                                on,
                                              ),
                                              shape: const StadiumBorder(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            ListenableBuilder(
              listenable: _page,
              builder: (BuildContext context, Widget? _) {
                final int pg = _page.value.round().clamp(0, _pages - 1);
                final int a = pg * _per,
                    b = math.min(_names.length, a + _per) - 1;
                return Text(
                  '${_names[a].$1[0]} to ${_names[b].$1[0]}   ·   ${a + 1} to ${b + 1} of ${_names.length}',
                  textAlign: TextAlign.center,
                  style: LumenType.text(13, weight: 600, color: c.inkMuted),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(LumenColors c, int row, int col, double p, double size) {
    // The wave: rows turn over one after another, top first when going forward.
    final int base = p.floor().clamp(0, _pages - 1);
    final double frac = (p - base).clamp(0.0, 1.0);
    final double t = Curves.easeInOut.transform(
      ((frac * (1 + 0.55) - (row / (_rows - 1)) * 0.55 - col * 0.02) / 1).clamp(
        0.0,
        1.0,
      ),
    );
    final int i0 = base * _per + row * _cols + col, i1 = i0 + _per;
    final bool has0 = i0 < _names.length, has1 = i1 < _names.length;
    if (!has0 && !has1) {
      return const SizedBox.shrink();
    }
    final double present = has0 && has1 ? 1 : (has0 ? 1 - t : t);
    final int a = has0 ? i0 : i1, b = has1 ? i1 : i0;
    final double s = size * 0.56;
    return Opacity(
      opacity: present.clamp(0.0, 1.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: s,
            child: CustomPaint(
              // Outline and colour blend from one app to the next; a small turn sells the change.
              painter: _Blob(
                ShapeLib.gallery[a % ShapeLib.gallery.length].radii,
                ShapeLib.gallery[b % ShapeLib.gallery.length].radii,
                t,
                Color.lerp(
                  _hues[a % _hues.length],
                  _hues[b % _hues.length],
                  t,
                )!,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (t < 0.98)
                    Opacity(
                      opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 - 0.5 * t,
                        child: Icon(
                          _names[a].$2,
                          color: Colors.white,
                          size: s * 0.46,
                        ),
                      ),
                    ),
                  if (t > 0.02)
                    Opacity(
                      opacity: (t * 1.6 - 0.6).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * t,
                        child: Icon(
                          _names[b].$2,
                          color: Colors.white,
                          size: s * 0.46,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Opacity(
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: Text(
                    _names[a].$1,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: LumenType.text(
                      12,
                      weight: 560,
                      color: c.ink,
                      height: 1.1,
                    ),
                  ),
                ),
                Opacity(
                  opacity: (t * 2 - 1).clamp(0.0, 1.0),
                  child: Text(
                    _names[b].$1,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: LumenType.text(
                      12,
                      weight: 560,
                      color: c.ink,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends CustomPainter {
  const _Blob(this.a, this.b, this.t, this.color);
  final Float32List a, b;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = ShapeLib.lerpPath(
      a,
      b,
      t,
      size.center(Offset.zero),
      size.width / 2 * 0.86,
      math.sin(t * math.pi) * 0.5,
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          <Color>[Color.lerp(color, Colors.white, 0.18)!, color],
        ),
    );
  }

  @override
  bool shouldRepaint(_Blob old) =>
      old.t != t || old.color != color || old.a != a || old.b != b;
}
