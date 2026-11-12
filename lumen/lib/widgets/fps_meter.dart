import 'package:material_ui/material_ui.dart';

import '../core/frame_stats.dart';
import '../core/theme.dart';

/// Small readout pinned under the status bar. Solid, not glass, so it stays
/// readable in screen recordings.
class FpsMeter extends StatelessWidget {
  const FpsMeter({super.key});

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 6,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _readout(),
                ValueListenableBuilder<String?>(
                  valueListenable: FrameStats.instance.transition,
                  builder: (BuildContext context, String? msg, Widget? _) {
                    if (msg == null) {
                      return const SizedBox.shrink();
                    }
                    final bool clean = msg.contains(': 0 ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: DecoratedBox(
                        decoration: const ShapeDecoration(
                          color: Color(0xE6101216),
                          shape: StadiumBorder(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            msg,
                            style: LumenType.text(
                              11.5,
                              weight: 600,
                              color: clean
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFACC15),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readout() {
    return ListenableBuilder(
      listenable: FrameStats.instance,
      builder: (BuildContext context, Widget? _) {
        final FrameStats s = FrameStats.instance;
        final bool good = s.idle || s.fps >= s.refreshRate * 0.95;
        final Color dot = s.idle
            ? const Color(0xFF8A8F9C)
            : good
            ? const Color(0xFF4ADE80)
            : (s.fps >= s.refreshRate * 0.8
                  ? const Color(0xFFFACC15)
                  : const Color(0xFFF87171));
        final String main = s.idle
            ? 'idle · ${s.refreshRate.round()} Hz'
            : '${s.fps.round()} fps';
        final String detail = s.idle
            ? 'missed ${s.missed}'
            : 'max ${s.worstMs.toStringAsFixed(1)} ms · missed ${s.missed}';
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: const Color(0xE6101216),
            shape: StadiumBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  main,
                  style: LumenType.text(
                    12,
                    weight: 650,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  detail,
                  style: LumenType.text(
                    11,
                    weight: 500,
                    color: const Color(0xFFB4B8C4),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
