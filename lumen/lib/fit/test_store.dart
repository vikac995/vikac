import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/settings.dart';

/// While one of Prism's own tests runs, what Prism keeps is kept apart from the person's (build
/// 201, the outside review's F02 and F34).
///
/// - **Before 201** the tests changed the person's own menu, swipes, labels and look, and saved
///   them to the person's own files, putting them back only at the very end. A test killed half
///   way (swiped away, a crash, the phone off) left the person with the test's menu.
/// - **Now** every store that keeps something in a file asks [file] for it. While a test runs,
///   that is a file of the test's own, beside the person's, never the person's. When the test
///   ends ([end]) each store reads the person's own again. A test killed half way leaves the
///   person's files exactly as they were, and the next start simply reads them.
/// - **A marker** is written as a test begins and removed as it ends; found at the next start, it
///   says a test ended unfinished ([unfinished]).
/// - The settings that are not kept anywhere yet (glass quality, reduce transparency, the lights,
///   the glass style) are put back in memory as before; [on] is what anything that comes to keep
///   them must ask first.
class TestStore {
  TestStore._();

  static bool _on = false;

  /// Whether one of Prism's tests is running, and so whether anything kept now is the test's.
  static bool get on => _on;

  /// The files the stores keep, as they were asked for while a test ran: removed at its end.
  static final Set<String> _used = <String>{};

  /// The file to keep [real]'s contents in now: [real] itself, or while a test runs, a file of
  /// the test's own beside it.
  static File file(File real) {
    if (!_on) {
      return real;
    }
    _used.add(real.path);
    return File('${real.path}.test');
  }

  static Directory get _dir {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return files.existsSync() ? files : Directory.systemTemp;
  }

  static File get _marker => File('${_dir.path}/prism_test_running');

  /// A test begins ([what]: which, for the marker).
  static void begin(String what) {
    _on = true;
    AppSettings.testing = true;
    try {
      _marker.writeAsStringSync(
        '$what, begun ${DateTime.now().toIso8601String()}',
      );
    } catch (_) {
      // No marker: only the note at the next start is lost.
    }
  }

  /// The test has ended: the stores are the person's again, and the test's own files go.
  static void end() {
    _on = false;
    AppSettings.testing = false;
    for (final String p in _used) {
      try {
        File('$p.test').deleteSync();
      } catch (_) {
        // Never made, or gone already.
      }
    }
    _used.clear();
    try {
      _marker.deleteSync();
    } catch (_) {
      // None.
    }
  }

  /// A test that never ended (Prism was stopped during it): what it was and when it began, and
  /// its own files are cleared away. Null if there was none.
  static String? unfinished() {
    try {
      final File m = _marker;
      if (!m.existsSync()) {
        return null;
      }
      final String said = m.readAsStringSync();
      m.deleteSync();
      for (final FileSystemEntity f in <Directory>{
        _dir,
        Directory.systemTemp,
      }.expand((Directory d) => d.listSync())) {
        if (f is File && f.path.endsWith('.test')) {
          try {
            f.deleteSync();
          } catch (_) {
            // Left: it is never read.
          }
        }
      }
      return said;
    } catch (e) {
      debugPrint('test store: $e');
      return null;
    }
  }

  /// The person's own files' contents, as they are now (null for one not made yet): for the
  /// test to show they were not touched.
  static Map<String, List<int>?> snapshot(Map<String, File> files) =>
      <String, List<int>?>{
        for (final MapEntry<String, File> e in files.entries)
          e.key: e.value.existsSync() ? e.value.readAsBytesSync() : null,
      };
}
