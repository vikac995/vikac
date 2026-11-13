import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

const Color _bad = Color(0xFFE5484D), _good = Color(0xFF2FA84F);

/// Room 24. Four common mistakes, each next to its fix.
class DoDontRoom extends StatefulWidget {
  const DoDontRoom({super.key});

  @override
  State<DoDontRoom> createState() => _DoDontRoomState();
}

class _DoDontRoomState extends State<DoDontRoom>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  Timer? _loadTimer;
  final ValueNotifier<double> _shimmer = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (Duration e) => _shimmer.value = (e.inMilliseconds % 1400) / 1400,
  );

  // Deleting: left asks first, right deletes and offers undo.
  final List<String> _left = <String>['Oats', 'Eggs', 'Rice'];
  String? _asking;
  final List<String> _right = <String>['Oats', 'Eggs', 'Rice'];
  String? _undo;
  int _undoAt = 0;
  Timer? _undoTimer;
  int _tapsLeft = 0, _tapsRight = 0;

  @override
  void dispose() {
    _loadTimer?.cancel();
    _undoTimer?.cancel();
    _ticker.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _loading = true);
    _ticker.start();
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 1800), () {
      _ticker.stop();
      setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 24,
          title: "Do and don't",
          hint: 'Pattern: the fastest way to explain a rule is to show it broken. Left is the common mistake, right is the fix.',
        ),
        _pair(
          c,
          'Waiting',
          'A spinner on an empty screen says nothing and makes the content jump in. A skeleton shows what is coming.',
          _waitSide(c, skeleton: false),
          _waitSide(c, skeleton: true),
          footer: Pressable(
            onTap: _loading ? null : _reload,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: c.ink.withValues(alpha: 0.08),
                shape: const StadiumBorder(),
              ),
              child: Text(
                _loading ? 'Loading…' : 'Reload both',
                style: LumenType.text(
                  14.5,
                  weight: 620,
                  color: c.ink,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        _pair(
          c,
          'Deleting',
          'Asking "are you sure?" every time costs two taps and people stop reading it. Delete at once and offer Undo.',
          _deleteSide(c, ask: true),
          _deleteSide(c, ask: false),
          footer: Text(
            'Taps used: $_tapsLeft on the left, $_tapsRight on the right.',
            style: LumenType.text(13, color: c.inkMuted),
          ),
        ),
        _pair(
          c,
          'Labels',
          'A hint inside the field vanishes once you type, and then nobody knows what the field was. Keep the label.',
          _fieldSide(c, keep: false),
          _fieldSide(c, keep: true),
        ),
        _pair(
          c,
          'Touch targets',
          'Small icons packed together get mis-tapped. Each needs 48 by 48 of its own, even if the icon is small.',
          _targetSide(c, proper: false),
          _targetSide(c, proper: true),
        ),
      ],
    );
  }

  Widget _pair(
    LumenColors c,
    String title,
    String why,
    Widget dont,
    Widget doo, {
    Widget? footer,
  }) {
    Widget side(bool good, Widget child) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                good ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: good ? _good : _bad,
              ),
              const SizedBox(width: 5),
              Text(
                good ? 'Do' : "Don't",
                style: LumenType.text(
                  12.5,
                  weight: 700,
                  color: good ? _good : _bad,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: c.ink.withValues(alpha: 0.05),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: (good ? _good : _bad).withValues(alpha: 0.35),
                ),
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(title, detail: why),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  side(false, dont),
                  const SizedBox(width: 12),
                  side(true, doo),
                ],
              ),
              if (footer != null) ...<Widget>[
                const SizedBox(height: 12),
                footer,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowLine(LumenColors c, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: ShapeDecoration(
            color: c.accent.withValues(alpha: 0.25),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LumenType.text(13.5, weight: 560, color: c.ink),
          ),
        ),
      ],
    ),
  );

  Widget _waitSide(LumenColors c, {required bool skeleton}) {
    if (!_loading) {
      return Column(
        children: <Widget>[
          _rowLine(c, 'Tidal flats'),
          _rowLine(c, 'Ember ridge'),
          _rowLine(c, 'Moss forest'),
        ],
      );
    }
    if (!skeleton) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _shimmer,
      builder: (BuildContext context, Widget? _) {
        final double t = _shimmer.value;
        Widget bone(double w, double h, double r) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: LinearGradient(
              begin: Alignment(3 * t - 2, 0),
              end: Alignment(3 * t - 1, 0),
              colors: <Color>[
                c.ink.withValues(alpha: 0.08),
                c.ink.withValues(alpha: 0.18),
                c.ink.withValues(alpha: 0.08),
              ],
            ),
          ),
        );
        return Column(
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    bone(28, 28, 14),
                    const SizedBox(width: 8),
                    bone(70.0 + i * 12, 12, 6),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _deleteSide(LumenColors c, {required bool ask}) {
    final List<String> items = ask ? _left : _right;
    if (items.isEmpty && (ask || _undo == null)) {
      return Center(
        child: GestureDetector(
          onTap: () => setState(() {
            items.addAll(<String>['Oats', 'Eggs', 'Rice']);
          }),
          child: Text(
            'Reset',
            style: LumenType.text(13.5, weight: 650, color: c.accent),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final String it in items)
          SizedBox(
            height: 34,
            child: ask && _asking == it
                ? Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Sure?',
                          style: LumenType.text(
                            12.5,
                            weight: 600,
                            color: c.ink,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _asking = null;
                          _tapsLeft++;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'No',
                            style: LumenType.text(
                              12.5,
                              weight: 650,
                              color: c.inkMuted,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _left.remove(it);
                          _asking = null;
                          _tapsLeft++;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'Delete',
                            style: LumenType.text(
                              12.5,
                              weight: 700,
                              color: _bad,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          it,
                          style: LumenType.text(14, weight: 560, color: c.ink),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          if (ask) {
                            _asking = it;
                            _tapsLeft++;
                          } else {
                            _undoAt = _right.indexOf(it);
                            _right.remove(it);
                            _undo = it;
                            _tapsRight++;
                            Haptics.settle();
                            _undoTimer?.cancel();
                            _undoTimer = Timer(
                              const Duration(seconds: 4),
                              () => setState(() => _undo = null),
                            );
                          }
                        }),
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: c.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        const Spacer(),
        if (!ask && _undo != null)
          GestureDetector(
            onTap: () => setState(() {
              _right.insert(_undoAt.clamp(0, _right.length), _undo!);
              _undo = null;
              _undoTimer?.cancel();
            }),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const ShapeDecoration(
                color: Color(0xF21A1C22),
                shape: StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Deleted',
                    style: LumenType.text(
                      12,
                      color: Colors.white70,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Undo',
                    style: LumenType.text(
                      12,
                      weight: 700,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _fieldSide(LumenColors c, {required bool keep}) {
    Widget field(String label, String value) => Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.06),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.ink.withValues(alpha: 0.16)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (keep)
            Text(
              label,
              textScaler: TextScaler.noScaling,
              style: LumenType.text(
                10.5,
                weight: 600,
                color: c.inkMuted,
                height: 1.1,
              ),
            ),
          Text(
            value,
            textScaler: TextScaler.noScaling,
            style: LumenType.text(14.5, color: c.ink, height: 1.25),
          ),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        field('Protein, g', '180'),
        field('Carbs, g', '249'),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              keep ? 'Still clear' : 'Which is which?',
              style: LumenType.text(12, color: c.inkMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _targetSide(LumenColors c, {required bool proper}) {
    const List<IconData> icons = <IconData>[
      Icons.edit_rounded,
      Icons.share_rounded,
      Icons.delete_rounded,
    ];
    final double box = proper ? 48 : 24;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final IconData i in icons)
              Container(
                width: box,
                height: box,
                margin: EdgeInsets.symmetric(horizontal: proper ? 2 : 0),
                decoration: BoxDecoration(
                  color: (proper ? _good : _bad).withValues(alpha: 0.14),
                  border: Border.all(
                    color: (proper ? _good : _bad).withValues(alpha: 0.7),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(i, size: 18, color: c.ink),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          proper ? '48 × 48 each' : '24 × 24, touching',
          style: LumenType.text(12, color: c.inkMuted),
        ),
      ],
    );
  }
}
