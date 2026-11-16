import 'dart:convert';
import 'dart:io';

/// One kept report: when it was finished, which test, and its full text.
class PastReport {
  PastReport._(this.file, this.when, this.title);

  final File file;
  final DateTime when;

  /// The test's own name, as the test calls itself ("button test (Prism and the Sidekick)").
  final String title;

  /// Its full text, exactly as it was kept.
  String text() => file.readAsStringSync();

  /// The name to show: the test's name without its explanation in brackets, capitalised.
  String get name {
    final String t = title.split(' (').first.trim();
    return t.isEmpty ? 'Report' : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  /// The build it was made with ("182"), from the report itself; null if it does not say.
  String? build(String text) =>
      RegExp(r'Prism build (\d+)').firstMatch(text)?.group(1);

  /// What it found, in a few words ("605 right, 12 wrong"), from the report itself.
  String result(String text) {
    final RegExpMatch? m = RegExp(r'CHECKS: (\d+) right, (\d+) wrong')
        .firstMatch(text);
    final String checks = m == null ? '' : '${m[1]} right, ${m[2]} wrong';
    if (text.contains('STOPPED BY YOU')) {
      return checks.isEmpty ? 'stopped by you' : '$checks, stopped by you';
    }
    return checks;
  }
}

/// Every finished test's report, kept in Prism's own storage: one file each, the newest
/// [keep] of them. Prism's storage survives Prism being closed, the phone restarting and a
/// new build being installed over it; uninstalling Prism clears it.
class PastReports {
  PastReports(this.dir);

  /// Where Prism keeps them: beside the last report ([TestRun]'s file), in Prism's own files.
  static final PastReports instance = PastReports(() {
    final Directory files = Directory(
      '${Directory.systemTemp.parent.path}/files',
    );
    return Directory(
      '${files.existsSync() ? files.path : Directory.systemTemp.path}/prism_reports',
    );
  }());

  final Directory dir;

  /// How many are kept.
  static const int keep = 20;

  // The one this run kept last, so that a note added to it afterwards goes into the same file.
  File? _last;

  /// Keeps a finished report, at once and before anything else, and lets the oldest go past
  /// [keep]. The file name holds when it was finished and the test's name; the text is the
  /// report exactly. Written to a spare file first and then renamed, so a crash leaves either
  /// the whole report or nothing.
  PastReport? save(String title, String text, {DateTime? at}) {
    try {
      dir.createSync(recursive: true);
      final DateTime when = at ?? DateTime.now();
      final String name =
          '${when.millisecondsSinceEpoch.toString().padLeft(14, '0')}_${Uri.encodeComponent(title)}.txt';
      final File spare = File('${dir.path}/.$name.part');
      spare.writeAsBytesSync(utf8.encode(text), flush: true);
      final File file = spare.renameSync('${dir.path}/$name');
      _last = file;
      _trim();
      return PastReport._(file, when, title);
    } catch (_) {
      // Not kept: the last report ([TestRun.keep]) and the screen still have it.
      return null;
    }
  }

  /// A note added to the report this run just kept: the same file, with the note.
  void update(String text) {
    final File? f = _last;
    if (f == null) {
      return;
    }
    try {
      final File spare = File('${f.path}.part');
      spare.writeAsBytesSync(utf8.encode(text), flush: true);
      spare.renameSync(f.path);
    } catch (_) {
      // The report stays as it was kept, without the note.
    }
  }

  /// The kept reports, newest first, read from storage each time.
  List<PastReport> list() {
    final List<PastReport> all = <PastReport>[];
    try {
      if (!dir.existsSync()) {
        return all;
      }
      for (final FileSystemEntity e in dir.listSync()) {
        if (e is! File) {
          continue;
        }
        final String base = e.uri.pathSegments.last;
        final RegExpMatch? m = RegExp(r'^(\d{14})_(.*)\.txt$').firstMatch(base);
        if (m == null) {
          continue;
        }
        String title;
        try {
          title = Uri.decodeComponent(m[2]!);
        } catch (_) {
          title = m[2]!;
        }
        all.add(
          PastReport._(
            e,
            DateTime.fromMillisecondsSinceEpoch(int.parse(m[1]!)),
            title,
          ),
        );
      }
    } catch (_) {
      // Storage could not be read: nothing to show.
    }
    all.sort(
      (PastReport a, PastReport b) => b.file.path.compareTo(a.file.path),
    );
    return all;
  }

  void _trim() {
    final List<PastReport> all = list();
    for (final PastReport r in all.skip(keep)) {
      try {
        r.file.deleteSync();
      } catch (_) {
        // Left: the next one kept tries again.
      }
    }
  }

  /// When a report was finished, as the list shows it: "Today 12:33", "Yesterday 07:57" or
  /// "15 Nov 22:10".
  static String whenSaid(DateTime t, {DateTime? now}) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final DateTime n = now ?? DateTime.now();
    final String hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (same(t, n)) {
      return 'Today $hm';
    }
    // (By the calendar, not by 24 hours, so a change of clocks does not move it.)
    if (same(t, DateTime(n.year, n.month, n.day - 1))) {
      return 'Yesterday $hm';
    }
    return '${t.day} ${months[t.month - 1]} $hm';
  }
}
