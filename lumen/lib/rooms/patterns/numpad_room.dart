import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';

/// Room 31. A number pad of our own, for numbers too far away to dial
/// (calories, grams). Big keys, quick-add chips, and it refuses nonsense
/// with a shake instead of an error message.
class NumpadRoom extends StatefulWidget {
  const NumpadRoom({super.key});

  @override
  State<NumpadRoom> createState() => _NumpadRoomState();
}

class _NumpadRoomState extends State<NumpadRoom> with TickerProviderStateMixin {
  int _field = 0; // 0 kcal, 1 grams
  final List<String> _text = <String>['450', '120'];
  late final SpringValue _pop = SpringValue(
    this,
    value: 1,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _shake = SpringValue(
    this,
    spring: Motions.expressiveFast,
    settleDistance: 0.5,
    settleVelocity: 10,
  );
  String? _saved;

  @override
  void dispose() {
    _pop.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _refuse() {
    _shake.jumpTo(0);
    _shake.animateTo(0, velocity: 600);
    Haptics.thud();
  }

  void _changed() {
    setState(() => _saved = null);
    _pop.jumpTo(0.94);
    _pop.animateTo(1, velocity: 4);
    Haptics.tick();
  }

  void _key(String k) {
    String t = _text[_field];
    if (k == '<') {
      if (t.isEmpty) {
        return _refuse();
      }
      t = t.substring(0, t.length - 1);
    } else if (k == '.') {
      if (t.contains('.') || _field == 0) {
        return _refuse(); // calories are whole numbers
      }
      t = t.isEmpty ? '0.' : '$t.';
    } else {
      if (t.replaceAll('.', '').length >= 5 ||
          (t.contains('.') && t.split('.')[1].isNotEmpty)) {
        return _refuse();
      }
      t = t == '0' ? k : t + k;
    }
    _text[_field] = t;
    _changed();
  }

  void _add(int n) {
    final double v = (double.tryParse(_text[_field]) ?? 0) + n;
    if (v > 99999) {
      return _refuse();
    }
    _text[_field] = v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(1);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final String t = _text[_field];
    Widget key(String label, {IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Pressable(
          onTap: () => _key(label),
          scale: 0.9,
          child: Container(
            height: 62,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: c.ink.withValues(alpha: icon != null ? 0.04 : 0.08),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: icon != null
                ? Icon(icon, color: c.ink, size: 24)
                : Text(
                    label,
                    textScaler: TextScaler.noScaling,
                    style: LumenType.display(26, weight: 600, color: c.ink),
                  ),
          ),
        ),
      ),
    );
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 31,
          title: 'Number pad',
          hint:
              'Pattern: for numbers too far to dial, a pad of our own beats the system keyboard: bigger keys, '
              'no layout jump, quick-add chips. Try a sixth digit, or a decimal point on calories.',
        ),
        const SizedBox(height: 16),
        Segmented<int>(
          values: const <int>[0, 1],
          labels: const <String>['Calories', 'Grams'],
          value: _field,
          onChanged: (int v) => setState(() => _field = v),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: <Widget>[
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[_pop, _shake]),
                builder: (BuildContext context, Widget? _) =>
                    Transform.translate(
                      offset: Offset(_shake.value, 0),
                      child: Transform.scale(
                        scale: _pop.value,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              t.isEmpty ? '0' : t,
                              textScaler: TextScaler.noScaling,
                              style: LumenType.display(
                                64,
                                weight: 700,
                                color: t.isEmpty ? c.inkFaint : c.ink,
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 9,
                                left: 8,
                              ),
                              child: Text(
                                _field == 0 ? 'kcal' : 'g',
                                style: LumenType.text(18, color: c.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final int n in <int>[10, 50, 100])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Pressable(
                        onTap: () => _add(n),
                        scale: 0.93,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: c.accent.withValues(alpha: 0.16),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            '+$n',
                            style: LumenType.text(
                              14.5,
                              weight: 660,
                              color: c.accent,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final List<String> row in <List<String>>[
                <String>['1', '2', '3'],
                <String>['4', '5', '6'],
                <String>['7', '8', '9'],
              ])
                Row(children: <Widget>[for (final String k in row) key(k)]),
              Row(
                children: <Widget>[
                  key('.'),
                  key('0'),
                  key('<', icon: Icons.backspace_outlined),
                ],
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () {
                  if ((double.tryParse(t) ?? 0) <= 0) {
                    return _refuse();
                  }
                  setState(() => _saved = '$t ${_field == 0 ? 'kcal' : 'g'}');
                  Haptics.settle();
                },
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _saved != null ? const Color(0xFF2FA84F) : c.accent,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _saved != null ? 'Saved $_saved' : 'Done',
                    style: LumenType.text(
                      16,
                      weight: 660,
                      color: _saved != null ? Colors.white : c.onAccent,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
