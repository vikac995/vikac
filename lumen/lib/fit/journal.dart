import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'diag.dart';

/// A diary Prism keeps by itself, so every day of ordinary use leaves
/// something to learn from. It is written to disk each time Prism leaves the
/// screen, and it survives restarts.
///
/// It records three things:
///   - how each stretch of use went (time, frames, late frames, worst action);
///   - anything that went wrong in the code (errors, with where they happened);
///   - what the battery was doing while Prism was on screen.
///
/// It only works while Prism is on screen. Off screen it does nothing at all:
/// no timers, no wake-ups. On screen it costs one battery reading every ten
/// seconds, and one small file write when you leave.
class Journal with WidgetsBindingObserver {
  Journal._();
  static final Journal instance = Journal._();
  static const MethodChannel _device = MethodChannel('lumen/device');
  File get _file => File('${Directory.systemTemp.path}/prism_journal_v1.txt');
  File get _errorFile =>
      File('${Directory.systemTemp.path}/prism_errors_v1.txt');

  Timer? _timer;
  final Stopwatch _onScreen = Stopwatch();
  int _frames0 = 0, _over0 = 0, _late0 = 0, _framesAtSample = 0;
  // Battery, since Prism last came on screen. "Still" means almost nothing was drawn in those ten seconds.
  int _stillN = 0,
      _moveN = 0,
      _plugN = 0,
      _level0 = -1,
      _level1 = -1,
      _brightN = 0;
  double _stillMa = 0, _moveMa = 0, _bright = 0, _temp = 0, _capacityMah = 0;
  String _unit = '';
  final List<String> _raw = <String>[];
  final Map<String, int> _errors = <String, int>{};

  void start() {
    WidgetsBinding.instance.addObserver(this);
    // Anything that goes wrong in the code is written down, not lost.
    final FlutterExceptionHandler? before = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      _error(d.exceptionAsString(), d.stack);
      before?.call(d);
    };
    PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
      _error(e.toString(), s);
      return true;
    };
    _begin();
  }

  void _error(String what, StackTrace? stack) {
    final String first = what.split('\n').first;
    final String where = (stack?.toString() ?? '')
        .split('\n')
        .where((String l) => l.contains('package:lumen'))
        .take(2)
        .map((String l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').trim())
        .join(' < ');
    final String key =
        '${first.length > 160 ? first.substring(0, 160) : first}  @ ${where.isEmpty ? 'unknown' : where}  [${Diag.build}, ${Diag.instance.scene}]';
    _errors[key] = (_errors[key] ?? 0) + 1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back from another app is an action like any other: its first frames are measured.
      Diag.instance.event('back to Prism');
      _begin();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _end();
    }
  }

  void _begin() {
    if (_onScreen.isRunning) {
      return;
    }
    _onScreen
      ..reset()
      ..start();
    _frames0 = Diag.instance.totalFrames;
    _over0 = Diag.instance.totalOver;
    _late0 = Diag.instance.totalLate;
    _framesAtSample = _frames0;
    _stillN = _moveN = _plugN = _brightN = 0;
    _stillMa = _moveMa = _bright = 0;
    _level0 = _level1 = -1;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _sample());
    _sample();
  }

  Future<void> _sample() async {
    try {
      final Map<Object?, Object?>? b = await _device
          .invokeMethod<Map<Object?, Object?>>('battery');
      if (b == null) {
        return;
      }
      final int level = (b['level']! as num).toInt();
      _level0 = _level0 < 0 ? level : _level0;
      _level1 = level;
      _temp = (b['temp']! as num) / 10;
      _bright += (b['brightness']! as num).toDouble();
      _brightN++;
      // Phones disagree on the unit. Samsung reports milliamps, most others microamps.
      double now = (b['current']! as num).toDouble();
      // The untouched figures of this session, so the unit and sign can be checked by eye.
      if (_raw.length < 24) {
        _raw.add(
          '${now.round()}${Diag.instance.totalFrames - _framesAtSample < 30 ? 's' : 'm'}',
        );
      }
      if (now.abs() > 20000) {
        now /= 1000;
        _unit = 'reported in microamps';
      } else {
        _unit = 'reported in milliamps';
      }
      final double counter = (b['counter']! as num).toDouble() / 1000;
      if (level > 5 && counter > 0) {
        _capacityMah = counter / level * 100;
      }
      final int frames = Diag.instance.totalFrames;
      final bool still = frames - _framesAtSample < 30;
      _framesAtSample = frames;
      if (now.abs() > 3000) {
        // Several amps is not a phone in use: it is the moment a charger was pulled or the app was
        // launched. Counting it would swamp everything else.
      } else if (b['plugged'] == true) {
        _plugN++; // On the charger the reading says nothing about drain.
      } else if (still) {
        _stillN++;
        _stillMa += now.abs();
      } else {
        _moveN++;
        _moveMa += now.abs();
      }
    } catch (_) {
      // Not on Android.
    }
  }

  void _end() {
    if (!_onScreen.isRunning) {
      return;
    }
    _onScreen.stop();
    _timer?.cancel();
    _timer = null;
    final int secs = _onScreen.elapsed.inSeconds;
    if (secs < 2) {
      return;
    }
    final DateTime d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final Diag g = Diag.instance;
    final String line = <Object>[
      '${d.year}-${two(d.month)}-${two(d.day)}',
      '${two(d.hour)}:${two(d.minute)}',
      secs,
      g.totalFrames - _frames0,
      g.totalOver - _over0,
      g.totalLate - _late0,
      _stillN,
      _stillMa.round(),
      _moveN,
      _moveMa.round(),
      _plugN,
      _level0,
      _level1,
      _brightN == 0 ? 0 : (_bright / _brightN).round(),
      _temp.round(),
      _capacityMah.round(),
      Diag.build.replaceAll('Prism build ', 'b'),
      g.worstAction().replaceAll('|', '/'),
    ].join('|');
    try {
      final List<String> lines = _file.existsSync()
          ? _file.readAsLinesSync()
          : <String>[];
      lines.add(line);
      // About two weeks of ordinary use; older lines fall off.
      _file.writeAsStringSync(
        '${lines.skip(lines.length > 600 ? lines.length - 600 : 0).join('\n')}\n',
      );
      if (_errors.isNotEmpty) {
        final Map<String, int> all = <String, int>{};
        if (_errorFile.existsSync()) {
          for (final String l in _errorFile.readAsLinesSync()) {
            final int cut = l.indexOf('x ');
            if (cut > 0) {
              all[l.substring(cut + 2)] =
                  int.tryParse(l.substring(0, cut)) ?? 1;
            }
          }
        }
        _errors.forEach((String k, int v) => all[k] = (all[k] ?? 0) + v);
        _errors.clear();
        final List<MapEntry<String, int>> top = all.entries.toList()
          ..sort(
            (MapEntry<String, int> a, MapEntry<String, int> b) =>
                b.value.compareTo(a.value),
          );
        _errorFile.writeAsStringSync(
          '${top.take(40).map((MapEntry<String, int> e) => '${e.value}x ${e.key}').join('\n')}\n',
        );
      }
    } catch (_) {
      // No storage: this stretch is simply not remembered.
    }
  }

  /// Forgets everything, for a clean start after a new build.
  void clear() {
    try {
      if (_file.existsSync()) {
        _file.deleteSync();
      }
      if (_errorFile.existsSync()) {
        _errorFile.deleteSync();
      }
    } catch (_) {
      // Nothing to forget.
    }
    _errors.clear();
  }

  /// The diary as text, for the report: one line per day, then battery, then errors.
  String report() {
    // What is happening right now counts too.
    final bool live = _onScreen.isRunning;
    if (live) {
      _end();
    }
    final StringBuffer o = StringBuffer()
      ..writeln()
      ..writeln(
        'DIARY (kept by itself between tests; one line per day, newest last)',
      );
    try {
      final List<List<String>> rows = <List<String>>[
        if (_file.existsSync())
          for (final String l in _file.readAsLinesSync())
            if (l.split('|').length >= 18) l.split('|'),
      ];
      if (rows.isEmpty) {
        o.writeln('(nothing yet)');
      } else {
        o.writeln(
          'day         times  on screen  frames   late   slow   battery   worst action that day',
        );
        final Map<String, List<List<String>>> days =
            <String, List<List<String>>>{};
        for (final List<String> r in rows) {
          days.putIfAbsent(r[0], () => <List<String>>[]).add(r);
        }
        int n(List<String> r, int i) => int.tryParse(r[i]) ?? 0;
        String pct(int a, int b) =>
            b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';
        for (final MapEntry<String, List<List<String>>> e in days.entries.skip(
          days.length > 14 ? days.length - 14 : 0,
        )) {
          final List<List<String>> rs = e.value;
          final int secs = rs.fold(0, (int s, List<String> r) => s + n(r, 2)),
              frames = rs.fold(0, (int s, List<String> r) => s + n(r, 3));
          final int over = rs.fold(0, (int s, List<String> r) => s + n(r, 4)),
              late = rs.fold(0, (int s, List<String> r) => s + n(r, 5));
          // The worst action of the day is the one named most often as worst.
          final Map<String, int> worst = <String, int>{};
          for (final List<String> r in rs) {
            if (r[17].isNotEmpty) {
              worst[r[17]] = (worst[r[17]] ?? 0) + 1;
            }
          }
          final String w = worst.isEmpty
              ? '-'
              : (worst.entries.toList()..sort(
                      (MapEntry<String, int> a, MapEntry<String, int> b) =>
                          b.value.compareTo(a.value),
                    ))
                    .first
                    .key;
          o.writeln(
            '${e.key}  ${rs.length.toString().padLeft(5)}  ${'${secs ~/ 60}m ${secs % 60}s'.padLeft(9)}  ${frames.toString().padLeft(6)}  ${pct(late, frames).padLeft(5)}  ${pct(over, frames).padLeft(5)}   ${(n(rs.first, 11) < 0 ? '?' : '${n(rs.first, 11)}→${n(rs.last, 12)}%').padLeft(7)}   $w  (${rs.last[16]})',
          );
        }
        // Battery, over everything remembered.
        int stillN = 0,
            moveN = 0,
            plugN = 0,
            secs = 0,
            bright = 0,
            brightRows = 0,
            cap = 0;
        double stillMa = 0, moveMa = 0;
        for (final List<String> r in rows) {
          stillN += n(r, 6);
          stillMa += n(r, 7);
          moveN += n(r, 8);
          moveMa += n(r, 9);
          plugN += n(r, 10);
          secs += n(r, 2);
          if (n(r, 13) > 0) {
            bright += n(r, 13);
            brightRows++;
          }
          if (n(r, 15) > 0) {
            cap = n(r, 15);
          }
        }
        o
          ..writeln()
          ..writeln(
            'BATTERY while Prism was on screen (whole phone: screen, radios and Prism together; Android gives no per-app figure)',
          );
        if (stillN + moveN == 0) {
          o.writeln(
            '(no readings off the charger yet; $plugN readings were on the charger and are not counted)',
          );
        } else {
          final double still = stillN == 0 ? 0 : stillMa / stillN,
              move = moveN == 0 ? 0 : moveMa / moveN;
          String perHour(double ma) => cap == 0
              ? ''
              : '  = ${(100 * ma / cap).toStringAsFixed(1)}% of the battery per hour';
          o
            ..writeln(
              'screen still:   ${stillN == 0 ? 'no readings' : '${still.round()} mA average over $stillN readings${perHour(still)}'}',
            )
            ..writeln(
              'screen moving:  ${moveN == 0 ? 'no readings' : '${move.round()} mA average over $moveN readings${perHour(move)}'}',
            )
            ..writeln(
              stillN >= 20 && moveN >= 20
                  ? 'so drawing costs about ${(move - still).round()} mA on top of a still screen. That difference is the part Prism can change.'
                  : 'not enough readings yet to say what drawing costs (20 of each kind are needed; a single minute is mostly noise).',
            )
            ..writeln(
              'on screen ${secs ~/ 60} min in total; average screen brightness ${brightRows == 0 ? '?' : '${(100 * bright / brightRows / 255).round()}%'}; '
              'battery about ${cap == 0 ? '?' : cap} mAh; $plugN readings on the charger left out; current $_unit',
            );
        }
      }
      o
        ..writeln()
        ..writeln(
          'raw battery readings this session, as the phone gave them (s = screen still, m = moving): ${_raw.isEmpty ? 'none' : _raw.join(' ')}',
        )
        ..writeln()
        ..writeln('ERRORS in the code (most frequent first)');
      final List<String> errs = <String>[
        if (_errorFile.existsSync())
          ..._errorFile.readAsLinesSync().where((String l) => l.isNotEmpty),
        for (final MapEntry<String, int> e in _errors.entries)
          '${e.value}x ${e.key}  (this session)',
      ];
      o.writeln(errs.isEmpty ? '(none)' : errs.take(20).join('\n'));
    } catch (e) {
      o.writeln('(the diary could not be read: $e)');
    }
    if (live) {
      _begin();
    }
    return o.toString();
  }
}
