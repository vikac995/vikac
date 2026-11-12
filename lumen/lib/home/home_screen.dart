import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/expand_route.dart';
import '../core/springs.dart';
import '../core/theme.dart';
import '../rooms/access/access_room.dart';
import '../rooms/colour/colour_room.dart';
import '../rooms/data/data_room.dart';
import '../rooms/details/details_room.dart';
import '../rooms/dials/dials_room.dart';
import '../rooms/disco/disco_room.dart';
import '../rooms/flow/flow_room.dart';
import '../rooms/foil/foil_room.dart';
import '../rooms/glass/glass_room.dart';
import '../rooms/pill/pill_room.dart';
import '../rooms/shaders/shaders_room.dart';
import '../rooms/shapes/shape_room.dart';
import '../rooms/springs/springs_room.dart';
import '../widgets/controls.dart';
import '../widgets/pressable.dart';
import 'illustrations.dart';
import 'settings_page.dart';

class _Room {
  const _Room(this.title, this.blurb, this.hue, this.builder);
  final String title;
  final String blurb;
  final Color hue;
  final WidgetBuilder? builder;
}

final List<_Room> _rooms = <_Room>[
  _Room(
    'Glass',
    'Controls that bend the light behind them.',
    const Color(0xFFFF6B4A),
    (_) => const GlassRoom(),
  ),
  _Room(
    'Springs',
    'Grab it mid-flight.',
    const Color(0xFFFFB23E),
    (_) => const SpringsRoom(),
  ),
  _Room(
    'Shape morph',
    'Buttons that change shape.',
    const Color(0xFF8E7CFF),
    (_) => const ShapeRoom(),
  ),
  _Room(
    'Flow',
    'A card becomes a screen.',
    const Color(0xFF4FB8FF),
    (_) => const FlowRoom(),
  ),
  _Room(
    'Shaders',
    'Light that reacts to touch.',
    const Color(0xFF2ED3B7),
    (_) => const ShadersRoom(),
  ),
  _Room(
    'Details',
    'The small things.',
    const Color(0xFFFF7AB6),
    (_) => const DetailsRoom(),
  ),
  _Room(
    'Foil',
    'Light that follows the tilt.',
    const Color(0xFFB39CFF),
    (_) => const FoilRoom(),
  ),
  _Room(
    'Dials',
    'Controls you can feel.',
    const Color(0xFFD9C3A0),
    (_) => const DialsRoom(),
  ),
  _Room(
    'Colour',
    'A palette from a picture.',
    const Color(0xFF7BD389),
    (_) => const ColourRoom(),
  ),
  _Room(
    'Live pill',
    'Glanceable activities.',
    const Color(0xFF9AA4B8),
    (_) => const PillRoom(),
  ),
  _Room(
    'Data',
    'Numbers that move.',
    const Color(0xFF5AA9FF),
    (_) => const DataRoom(),
  ),
  _Room(
    'Access',
    'Same screen, four needs.',
    const Color(0xFFFFC857),
    (_) => const AccessRoom(),
  ),
  _Room(
    'Discomorphism',
    'The trend nobody asked for.',
    const Color(0xFFE6E1FF),
    (_) => const DiscoRoom(),
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Entrance: header then cards rise into place, slightly staggered, so the
  // eye is led from the title down through the grid.
  late final List<SpringValue> _enter = List<SpringValue>.generate(
    _rooms.length + 1,
    (_) => SpringValue(this, spring: Motions.expressive),
  );
  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _enter.length; i++) {
      _timers.add(
        Timer(
          Duration(milliseconds: 60 + i * 55),
          () => _enter[i].animateTo(1),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    for (final SpringValue s in _enter) {
      s.dispose();
    }
    super.dispose();
  }

  void _open(
    BuildContext cardContext,
    WidgetBuilder builder, {
    double radius = 32,
  }) {
    final RenderBox box = cardContext.findRenderObject()! as RenderBox;
    final Rect origin = box.localToGlobal(Offset.zero) & box.size;
    Navigator.of(context).push(
      ExpandRoute<void>(
        builder: builder,
        origin: origin,
        originRadius: radius,
        originColor: LumenColors.of(context).surface,
      ),
    );
  }

  Widget _rise(int i, Widget child) {
    return ListenableBuilder(
      listenable: _enter[i],
      builder: (BuildContext context, Widget? child) {
        final double v = _enter[i].value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 36),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _card(int i, {required double height, bool showBlurb = true}) {
    final _Room r = _rooms[i];
    return _rise(
      i + 1,
      _RoomCard(
        index: i,
        room: r,
        height: height,
        showBlurb: showBlurb,
        onOpen: r.builder == null
            ? null
            : (BuildContext ctx) => _open(ctx, r.builder!),
      ),
    );
  }

  Widget _section(LumenColors c, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: LumenType.display(26, weight: 700, color: c.ink)),
          const SizedBox(height: 4),
          Text(detail, style: LumenType.text(14, color: c.inkMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const double gap = 12;
    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(20, safe.top + 52, 20, safe.bottom + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _rise(
              0,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Lumen',
                        style: LumenType.display(46, weight: 760, color: c.ink),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (BuildContext ctx) => RoundButton(
                          icon: Icons.tune_rounded,
                          semanticLabel: 'Settings',
                          onTap: () => _open(
                            ctx,
                            (_) => const SettingsPage(),
                            radius: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A showcase of interface craft.\nTwelve rooms, one idea each.',
                    style: LumenType.text(
                      15.5,
                      color: c.inkMuted,
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
            _card(0, height: 236),
            const SizedBox(height: gap),
            Row(
              children: <Widget>[
                Expanded(child: _card(1, height: 176)),
                const SizedBox(width: gap),
                Expanded(child: _card(2, height: 176)),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 10, child: _card(4, height: 252)),
                const SizedBox(width: gap),
                Expanded(
                  flex: 11,
                  child: Column(
                    children: <Widget>[
                      _card(3, height: 120, showBlurb: false),
                      const SizedBox(height: gap),
                      _card(5, height: 120, showBlurb: false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _section(
              c,
              'Trends, part two',
              'What is shaping interfaces right now.',
            ),
            _card(6, height: 236),
            const SizedBox(height: gap),
            Row(
              children: <Widget>[
                Expanded(child: _card(7, height: 176)),
                const SizedBox(width: gap),
                Expanded(child: _card(8, height: 176)),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 10, child: _card(9, height: 252)),
                const SizedBox(width: gap),
                Expanded(
                  flex: 11,
                  child: Column(
                    children: <Widget>[
                      _card(10, height: 120, showBlurb: false),
                      const SizedBox(height: gap),
                      _card(11, height: 120, showBlurb: false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _section(c, 'Bonus', 'Please do not ship this.'),
            _card(12, height: 150),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Build 7  ·  Flutter 3.50  ·  Impeller',
                style: LumenType.text(12, color: c.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatefulWidget {
  const _RoomCard({
    required this.index,
    required this.room,
    required this.height,
    required this.showBlurb,
    required this.onOpen,
  });

  final int index;
  final _Room room;
  final double height;
  final bool showBlurb;
  final void Function(BuildContext cardContext)? onOpen;

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard>
    with SingleTickerProviderStateMixin {
  // A locked card answers a tap with a short sideways shake: "not yet".
  late final SpringValue _shake = SpringValue(
    this,
    spring: Motions.expressiveFast,
    settleDistance: 0.5,
    settleVelocity: 10,
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final bool open = widget.onOpen != null;
    final _Room r = widget.room;
    final bool hero = widget.index == 0;
    final Color hue = c.dark ? r.hue : Color.lerp(r.hue, Colors.black, 0.12)!;

    final Widget card = Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: c.hairline),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: CustomPaint(
              painter: RoomArt(widget.index, hue, c, dim: !open),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      widget.index == 12
                          ? 'BONUS'
                          : (widget.index + 1).toString().padLeft(2, '0'),
                      style: LumenType.label(
                        color: open ? c.accent : c.inkFaint,
                      ),
                    ),
                    if (!open) ...<Widget>[
                      const SizedBox(width: 8),
                      Text('SOON', style: LumenType.label(color: c.inkFaint)),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  r.title,
                  style: LumenType.display(
                    hero ? 34 : 22,
                    weight: hero ? 700 : 650,
                    color: open ? c.ink : c.inkMuted,
                  ),
                ),
                if (widget.showBlurb) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    r.blurb,
                    style: LumenType.text(
                      hero ? 14.5 : 13,
                      color: open ? c.inkMuted : c.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hero)
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: c.accent,
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  Icons.arrow_outward_rounded,
                  color: c.onAccent,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: open ? r.title : '${r.title}, coming in a later build',
      child: Pressable(
        scale: 0.97,
        onTap: () {
          if (open) {
            widget.onOpen!(context);
          } else {
            _shake.animateTo(0, velocity: 420);
          }
        },
        builder: (BuildContext context, double pressed, Widget child) {
          return ListenableBuilder(
            listenable: _shake,
            builder: (BuildContext context, Widget? _) => Transform.translate(
              offset: Offset(_shake.value, 0),
              child: Transform.scale(scale: 1 - 0.03 * pressed, child: child),
            ),
          );
        },
        child: card,
      ),
    );
  }
}
