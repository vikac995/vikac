import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../widgets/pressable.dart';
import 'diag.dart';

/// Prism's flight recorder. It quietly keeps the last few hundred things that happened: what
/// was done, slow frames and what was on screen when they came, memory warnings, errors, Prism
/// being closed by Android and started again. Android's side (the floating blob and timer)
/// keeps its own, and the two are put together, in time order, when they are copied.
///
/// What it costs: a line in memory for each thing, written to disk only when Prism leaves the
/// screen. Slow frames are found in the frame times Flutter hands over anyway, about once a
/// second, and only while something is being drawn. While nothing happens it does nothing.
/// Nothing leaves the phone: it is only ever copied, by the person, to paste.
class Recorder with WidgetsBindingObserver {
  Recorder._();
  static final Recorder instance = Recorder._();
  static const MethodChannel _device = MethodChannel('lumen/device');
  static const int _keep = 600;

  final List<(DateTime, String)> _lines = <(DateTime, String)>[];

  File get _file {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return File(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_recorder.txt',
    );
  }

  void start() {
    // What was kept from before, then a line to say Prism has started again.
    try {
      for (final String l in _file.readAsLinesSync()) {
        final int tab = l.indexOf('\t');
        final DateTime? at = DateTime.tryParse(l.substring(0, tab));
        if (tab > 0 && at != null) {
          _lines.add((at, l.substring(tab + 1)));
        }
      }
    } catch (_) {
      // Nothing kept yet.
    }
    add(
      'Prism started (${Diag.build}). If it was not you who closed it, Android did, or it crashed.',
    );
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_frames);
  }

  void add(String what) {
    _lines.add((DateTime.now(), what));
    if (_lines.length > _keep) {
      _lines.removeRange(0, _lines.length - _keep);
    }
  }

  // Slow frames: a frame whose work took more than one and a half refreshes. Counted per batch
  // (about a second) and written as one line, with what was on screen.
  void _frames(List<FrameTiming> timings) {
    final double budget = Diag.instance.budgetMs;
    int slow = 0;
    double worst = 0;
    for (final FrameTiming t in timings) {
      final double ms = t.totalSpan.inMicroseconds / 1000;
      if (ms > budget * 1.5) {
        slow++;
        if (ms > worst) {
          worst = ms;
        }
      }
    }
    if (slow > 0) {
      add(
        'slow: $slow of ${timings.length} frames, worst ${worst.toStringAsFixed(1)} ms, on ${Diag.instance.scene}',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    add('Prism ${state.name}');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _save();
    }
  }

  @override
  void didHaveMemoryPressure() => add('Android said memory is short');

  void _save() {
    try {
      _file.writeAsStringSync(
        _lines
            .map(((DateTime, String) l) => '${l.$1.toIso8601String()}\t${l.$2}')
            .join('\n'),
      );
    } catch (_) {
      // Not kept this time.
    }
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  /// Everything from the last [minutes], Prism's side and Android's, in time order, with the
  /// person's note, the build, the phone, the settings and the memory at the top.
  Future<String> export(String note, {int minutes = 15}) async {
    final DateTime from = DateTime.now().subtract(Duration(minutes: minutes));
    final List<(DateTime, String)> all = <(DateTime, String)>[
      for (final (DateTime, String) l in _lines)
        if (l.$1.isAfter(from)) (l.$1, l.$2),
    ];
    String memory = '';
    String phone = '';
    try {
      final List<Object?> trail =
          await _device.invokeMethod<List<Object?>>('trail') ?? <Object?>[];
      for (final Object? o in trail) {
        final Map<Object?, Object?> m = o! as Map<Object?, Object?>;
        final DateTime at = DateTime.fromMillisecondsSinceEpoch(
          (m['at']! as num).toInt(),
        );
        if (at.isAfter(from)) {
          all.add((at, 'android: ${m['what']}'));
        }
      }
      final Map<Object?, Object?>? m = await _device
          .invokeMethod<Map<Object?, Object?>>('lensTest', <String, Object?>{
            'op': 'memory',
          });
      if (m != null) {
        int mb(Object? kb) => ((kb as num?) ?? 0) ~/ 1024;
        memory =
            'memory now: ${mb(m['pss'])} MB (graphics ${mb(m['mem_graphics'])}, native ${mb(m['mem_native'])}, java ${mb(m['mem_java'])}, code ${mb(m['mem_code'])}, other ${mb(m['mem_other'])})  ·  battery ${m['level'] ?? '?'}%  ·  ${(((m['temp'] as num?) ?? 0) / 10).toStringAsFixed(1)} °C${m['plugged'] == true ? '  ·  charging' : ''}';
      }
      phone = await _device.invokeMethod<String>('phone') ?? '';
    } catch (_) {
      // Off the phone: Prism's side only.
    }
    all.sort(
      ((DateTime, String) a, (DateTime, String) b) => a.$1.compareTo(b.$1),
    );
    final StringBuffer o = StringBuffer()
      ..writeln(
        'WHAT HAPPENED, from Prism\'s flight recorder  ·  ${Diag.build}  ·  ${DateTime.now().toString().substring(0, 16)}',
      );
    if (phone.isNotEmpty) {
      o.writeln(phone);
    }
    for (final String l
        in Diag.instance.settingsLines?.call() ?? const <String>[]) {
      o.writeln(l);
    }
    if (memory.isNotEmpty) {
      o.writeln(memory);
    }
    o
      ..writeln()
      ..writeln('THE LAST $minutes MINUTES (${all.length} things):');
    for (final (DateTime at, String what) in all) {
      o.writeln('${_clock(at)}  $what');
    }
    // The note comes last, and is always there, so more can be written after it once pasted.
    o
      ..writeln()
      ..write('YOUR NOTE: ${note.trim()}');
    return o.toString();
  }
}

/// The panel for sending what just happened: an optional note, and Copy.
void showRecorderExport(BuildContext context) {
  final TextEditingController note = TextEditingController();
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext context, _, _) {
      final LumenColors c = LumenColors.of(context);
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            0,
            10,
            MediaQuery.paddingOf(context).bottom +
                10 +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(36),
                  side: BorderSide(color: c.hairline),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'What just happened',
                    style: LumenType.display(22, weight: 700, color: c.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Copies everything Prism noted in the last 15 minutes, to paste to Claude, with a video or without.',
                    style: LumenType.text(
                      13.5,
                      color: c.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: note,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: LumenType.text(15, color: c.ink, height: 1.3),
                    decoration: InputDecoration(
                      hintText: 'What happened? (optional)',
                      hintStyle: LumenType.text(15, color: c.inkMuted),
                      filled: true,
                      fillColor: c.ink.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Pressable(
                    onTap: () async {
                      final String text = await Recorder.instance.export(
                        note.text,
                      );
                      await Diag.instance.copy(text);
                      Haptics.settle();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: c.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Copy',
                        style: LumenType.text(
                          15.5,
                          weight: 700,
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
      );
    },
  );
}
