import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One real app the blob menu can open.
class BlobApp {
  BlobApp(this.name, this.package, Color brand) : color = BlobApps.tame(brand);
  final String name;

  /// The app's package, or "label:" and its name on the home screen when the package is not known.
  String package;
  bool installed = false;

  /// How the picture on the blob was made: outline, cut-out, coin or letter. For the test report.
  String made = 'letter';

  /// The blob's colour: the icon's own colour, brought into Prism's palette.
  Color color;

  /// A white outline of the icon where the app supplies one, else the icon itself.
  ui.Image? glyph, icon;

  /// For an icon that is a picture: the picture itself, calmed toward the palette.
  ui.Image? picture;
}

/// The apps in the blob menu, and the rule that keeps their colours in the family.
class BlobApps extends ChangeNotifier {
  BlobApps._();
  static final BlobApps instance = BlobApps._();
  static const MethodChannel _channel = MethodChannel('lumen/apps');

  /// Whether the blob menu shows apps rather than fitness actions.
  final ValueNotifier<bool> on = ValueNotifier<bool>(true);

  // The colours here are only a stand-in until the real icon has been read.
  final List<BlobApp> apps = <BlobApp>[
    BlobApp('Claude', 'com.anthropic.claude', const Color(0xFFD97757)),
    BlobApp('WhatsApp', 'com.whatsapp', const Color(0xFF25D366)),
    BlobApp('Instagram', 'com.instagram.android', const Color(0xFFE1306C)),
    BlobApp('Facebook', 'com.facebook.katana', const Color(0xFF1877F2)),
    // No outline of its own, and a plain square icon: the test case for the cut-out rule.
    BlobApp('moj ZET', 'label:moj ZET', const Color(0xFF00369D)),
  ];

  Future<void> load() async {
    try {
      final List<Object?> got =
          await _channel.invokeMethod<List<Object?>>('icons', <String>[
            for (final BlobApp a in apps) a.package,
          ]) ??
          <Object?>[];
      for (final Object? o in got) {
        final Map<Object?, Object?> m = o! as Map<Object?, Object?>;
        final BlobApp a = apps.firstWhere(
          (BlobApp a) => a.package == m['asked'],
        );
        a.installed = true;
        a.package = m['package']! as String;
        a.icon = await _decode(m['icon']! as Uint8List);
        final Object? mono = m['mono'];
        final AppLook look = await IconEngine.look(
          a.icon!,
          mono == null ? null : await _decode(mono as Uint8List),
        );
        a
          ..glyph = look.glyph
          ..picture = look.picture
          ..made = look.made
          ..color = look.color ?? a.color;
      }
      notifyListeners();
    } catch (_) {
      // Not on Android: the stand-in colours and initials are used.
      // For my own checking, icons can be fed in from files: CUT_TEST=a.png,b.png,...
      const String test = String.fromEnvironment('CUT_TEST');
      if (test.isNotEmpty) {
        final List<String> files = test.split(',');
        for (int i = 0; i < files.length && i < apps.length; i++) {
          final BlobApp a = apps[apps.length - 1 - i];
          a.icon = await _decode(File(files[i]).readAsBytesSync());
          final AppLook look = await IconEngine.look(a.icon!, null);
          a
            ..glyph = look.glyph
            ..picture = look.picture
            ..made = look.made
            ..color = look.color ?? a.color;
        }
        notifyListeners();
      }
    }
  }

  Future<bool> launch(BlobApp a) async {
    try {
      return a.installed &&
          (await _channel.invokeMethod<bool>('launch', a.package) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) => IconEngine.decode(bytes);

  // ignore: unused_element
  static Future<ui.Image> _decodeOld(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  /// Turns a simple icon into a white mark. It finds the icon's ground (the
  /// one colour around its edge), and keeps whatever differs from it, in
  /// white. That works when the icon is a mark on a plain ground, which is
  /// most of them. It gives up (null) when the ground is not plain or the
  /// mark covers too little or too much, which means the icon is a picture.
  /// Also returns the colour the blob should take: the ground if it has
  /// colour, otherwise the mark's own colour.
  static Future<(ui.Image, Color?)?> cutOut(ui.Image image) async {
    final ByteData? data = await image.toByteData();
    final int w = image.width, h = image.height;
    if (data == null || w < 24 || h < 24) {
      return null;
    }
    int at(int x, int y) => (y * w + x) * 4;
    // The ground: the commonest colour on a ring a little in from the edge.
    final Map<int, List<int>> ring = <int, List<int>>{};
    int ringAll = 0;
    final int inset = (w * 0.12).round();
    void vote(int x, int y) {
      final int i = at(x, y);
      if (data.getUint8(i + 3) < 200) {
        return;
      }
      ringAll++;
      final int r = data.getUint8(i),
          g = data.getUint8(i + 1),
          b = data.getUint8(i + 2);
      final List<int> e = ring.putIfAbsent(
        (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4),
        () => <int>[0, 0, 0, 0],
      );
      e[0]++;
      e[1] += r;
      e[2] += g;
      e[3] += b;
    }

    for (int i = 0; i < w; i++) {
      vote(i, inset);
      vote(i, h - 1 - inset);
      vote(inset, i * h ~/ w);
      vote(w - 1 - inset, i * h ~/ w);
    }
    if (ring.isEmpty) {
      return null;
    }
    final List<int> top = ring.values.reduce(
      (List<int> a, List<int> b) => a[0] >= b[0] ? a : b,
    );
    if (top[0] < ringAll * 0.8) {
      return null; // The edge is not one colour: a picture or a gradient.
    }
    final double gr = top[1] / top[0],
        gg = top[2] / top[0],
        gb = top[3] / top[0];
    // Everything that differs from the ground becomes white. The outer rim is left out,
    // where the icon's own soft edge would otherwise show up as an outline.
    final Uint8List out = Uint8List(w * h * 4);
    final int rim = (w * 0.07).round();
    int opaque = 0, marked = 0, minX = w, minY = h, maxX = 0, maxY = 0;
    final Map<int, List<int>> ink = <int, List<int>>{};
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = at(x, y);
        if (data.getUint8(i + 3) < 128) {
          continue;
        }
        opaque++;
        if (x < rim || y < rim || x >= w - rim || y >= h - rim) {
          continue;
        }
        final int r = data.getUint8(i),
            g = data.getUint8(i + 1),
            b = data.getUint8(i + 2);
        final double d = math.sqrt(
          (r - gr) * (r - gr) + (g - gg) * (g - gg) + (b - gb) * (b - gb),
        );
        final double a = ((d - 45) / 50).clamp(0.0, 1.0);
        if (a <= 0) {
          continue;
        }
        // White, with the alpha already multiplied in, as the engine expects.
        final int v = (255 * a).round();
        out[i] = v;
        out[i + 1] = v;
        out[i + 2] = v;
        out[i + 3] = v;
        if (d > 70) {
          marked++;
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
          final List<int> e = ink.putIfAbsent(
            (r >> 5) << 6 | (g >> 5) << 3 | (b >> 5),
            () => <int>[0, 0, 0, 0],
          );
          e[0]++;
          e[1] += r;
          e[2] += g;
          e[3] += b;
        }
      }
    }
    final double share = marked / math.max(opaque, 1);
    if (share < 0.04 || share > 0.5) {
      return null; // Nearly nothing, or nearly everything: not a mark on a ground.
    }
    // Crop to the mark, as a square, so every mark fills its blob alike.
    final int side = math.max(maxX - minX, maxY - minY) + 1 + 2 * (w ~/ 16);
    final int cx = (minX + maxX) ~/ 2, cy = (minY + maxY) ~/ 2;
    final Uint8List crop = Uint8List(side * side * 4);
    for (int y = 0; y < side; y++) {
      final int sy = cy - side ~/ 2 + y;
      if (sy < 0 || sy >= h) {
        continue;
      }
      for (int x = 0; x < side; x++) {
        final int sx = cx - side ~/ 2 + x;
        if (sx < 0 || sx >= w) {
          continue;
        }
        final int from = at(sx, sy), to = (y * side + x) * 4;
        crop[to] = out[from];
        crop[to + 1] = out[from + 1];
        crop[to + 2] = out[from + 2];
        crop[to + 3] = out[from + 3];
      }
    }
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      crop,
    );
    final ui.ImageDescriptor desc = ui.ImageDescriptor.raw(
      buffer,
      width: side,
      height: side,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Image glyph =
        (await (await desc.instantiateCodec()).getNextFrame()).image;
    // The blob's colour: the ground if it has colour, else the mark's.
    Color? pick(double r, double g, double b) {
      final HSLColor c = HSLColor.fromColor(
        Color.fromARGB(255, r.round(), g.round(), b.round()),
      );
      return c.saturation >= 0.25 && c.lightness > 0.1 && c.lightness < 0.92
          ? c.toColor()
          : null;
    }

    Color? colour = pick(gr, gg, gb);
    if (colour == null && ink.isNotEmpty) {
      final List<List<int>> byUse = ink.values.toList()
        ..sort((List<int> a, List<int> b) => b[0].compareTo(a[0]));
      for (final List<int> e in byUse.take(4)) {
        colour ??= pick(e[1] / e[0], e[2] / e[0], e[3] / e[0]);
      }
    }
    return (glyph, colour);
  }

  /// The colour an icon is mostly made of. Pixels vote for their hue, the more
  /// colourful the louder; white, black and grey do not vote. Null if the icon
  /// has no real colour.
  static Future<Color?> mainColour(ui.Image image) async {
    final ByteData? data = await image.toByteData();
    if (data == null) {
      return null;
    }
    const int bins = 24;
    final List<double> weight = List<double>.filled(bins, 0),
        r = List<double>.filled(bins, 0),
        g = List<double>.filled(bins, 0),
        b = List<double>.filled(bins, 0);
    double all = 0;
    for (int i = 0; i + 3 < data.lengthInBytes; i += 16) {
      final int pr = data.getUint8(i),
          pg = data.getUint8(i + 1),
          pb = data.getUint8(i + 2),
          pa = data.getUint8(i + 3);
      if (pa < 128) {
        continue;
      }
      all++;
      final HSLColor h = HSLColor.fromColor(Color.fromARGB(255, pr, pg, pb));
      if (h.saturation < 0.25 || h.lightness < 0.12 || h.lightness > 0.92) {
        continue;
      }
      final int k = (h.hue / 360 * bins).floor() % bins;
      final double w = h.saturation;
      weight[k] += w;
      r[k] += pr * w;
      g[k] += pg * w;
      b[k] += pb * w;
    }
    int best = 0;
    for (int k = 1; k < bins; k++) {
      if (weight[k] > weight[best]) {
        best = k;
      }
    }
    if (all == 0 || weight[best] < all * 0.03) {
      return null;
    }
    return Color.fromARGB(
      255,
      (r[best] / weight[best]).round(),
      (g[best] / weight[best]).round(),
      (b[best] / weight[best]).round(),
    );
  }

  /// Brings any colour into Prism's family. The hue is kept, because that is
  /// what makes it recognisable. How vivid it is gets held to the same band as
  /// Prism's own blobs, and how bright it is gets set so that white on top
  /// reads equally well on every blob. Colourless icons become slate.
  static Color tame(Color c) {
    final HSLColor h = HSLColor.fromColor(c);
    if (h.saturation < 0.18) {
      return const Color(0xFF5A6373);
    }
    final double s = h.saturation.clamp(0.42, 0.60);
    // Yellows and greens look dull if held as dark as blues, so they get a little more light.
    final double warm = math.max(0, 1 - ((h.hue - 80).abs() / 70));
    final double want = 0.20 + 0.10 * warm;
    double lo = 0.25, hi = 0.68;
    for (int i = 0; i < 14; i++) {
      final double mid = (lo + hi) / 2;
      if (h.withSaturation(s).withLightness(mid).toColor().computeLuminance() <
          want) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return h.withSaturation(s).withLightness((lo + hi) / 2).toColor();
  }
}

/// How one app is shown in Prism: a colour, and a white mark or a calmed picture.
class AppLook {
  AppLook(this.made, this.color, {this.glyph, this.picture});

  /// outline, cut-out or picture.
  final String made;
  final Color? color;
  final ui.Image? glyph, picture;
}

/// Turns any app icon into something that belongs in Prism. It runs inside
/// the app, on the icons that are on the phone: nothing is drawn by hand or
/// shipped with the app. Each icon is tried in order:
///   1. outline: the app's own one-colour outline, in white;
///   2. cut-out: a mark on a plain ground, cut out and made white;
///   3. picture: anything else, kept as a picture but calmed toward the palette.
class IconEngine {
  static Future<ui.Image> decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  static Future<AppLook> look(ui.Image icon, ui.Image? outline) async {
    final Color? main = await BlobApps.mainColour(icon);
    if (outline != null) {
      return AppLook(
        'outline',
        main == null ? const Color(0xFF5A6373) : BlobApps.tame(main),
        glyph: outline,
      );
    }
    final (ui.Image, Color?)? cut = await BlobApps.cutOut(icon);
    if (cut != null) {
      return AppLook(
        'cut-out',
        BlobApps.tame(cut.$2 ?? main ?? const Color(0xFF808080)),
        glyph: cut.$1,
      );
    }
    final Color color = BlobApps.tame(main ?? const Color(0xFF808080));
    return AppLook('picture', color, picture: await _calm(icon, color));
  }

  /// A picture cannot be redrawn, so it is brought as near to the palette as
  /// it can go while staying itself: a little less vivid, the brightest and
  /// darkest parts pulled in, and a wash of its own blob colour over it.
  static Future<ui.Image> _calm(ui.Image image, Color wash) async {
    final ByteData data = (await image.toByteData())!;
    final int n = image.width * image.height;
    final Uint8List out = Uint8List(n * 4);
    final double wr = wash.r * 255, wg = wash.g * 255, wb = wash.b * 255;
    for (int p = 0; p < n; p++) {
      final int i = p * 4, a = data.getUint8(i + 3);
      if (a == 0) {
        continue;
      }
      // Stored with the alpha multiplied in: undo, change, redo.
      final double k = 255 / a;
      double r = data.getUint8(i) * k,
          g = data.getUint8(i + 1) * k,
          b = data.getUint8(i + 2) * k;
      final double grey = 0.299 * r + 0.587 * g + 0.114 * b;
      r = grey + (r - grey) * 0.78;
      g = grey + (g - grey) * 0.78;
      b = grey + (b - grey) * 0.78;
      r = 22 + r * 0.82;
      g = 22 + g * 0.82;
      b = 22 + b * 0.82;
      r += (wr - r) * 0.16;
      g += (wg - g) * 0.16;
      b += (wb - b) * 0.16;
      out[i] = (r / k).round().clamp(0, a);
      out[i + 1] = (g / k).round().clamp(0, a);
      out[i + 2] = (b / k).round().clamp(0, a);
      out[i + 3] = a;
    }
    return fromPixels(out, image.width, image.height);
  }

  static Future<ui.Image> fromPixels(Uint8List pixels, int w, int h) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      pixels,
    );
    final ui.ImageDescriptor desc = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    return (await (await desc.instantiateCodec()).getNextFrame()).image;
  }
}

/// One app in the drawer.
class AppTile {
  AppTile(this.label, this.package, this.updated);
  final String label, package;
  final int updated;
  Color color = const Color(0xFF5A6373);
  ui.Image? glyph, picture;
  String made = 'waiting';
}

/// Every app on the phone, each given its Prism look once and then remembered.
/// The work happens only when an app is new or has been updated; otherwise
/// the saved result is read back from disk.
class Apps extends ChangeNotifier {
  Apps._();
  static final Apps instance = Apps._();
  static const MethodChannel _channel = MethodChannel('lumen/apps');
  List<AppTile> all = <AppTile>[];
  bool _busy = false;

  /// What the last refresh did, for the test report.
  String summary = 'not run';
  Directory get _dir =>
      Directory('${Directory.systemTemp.path}/prism_looks_v1');

  Future<void> launch(AppTile t) async {
    try {
      await _channel.invokeMethod<bool>('launch', t.package);
    } catch (_) {
      // Not on Android.
    }
  }

  Future<void> refresh() async {
    if (_busy) {
      return;
    }
    _busy = true;
    final Stopwatch clock = Stopwatch()..start();
    try {
      final List<Object?> names =
          await _channel.invokeMethod<List<Object?>>('names') ?? <Object?>[];
      final Map<String, AppTile> old = <String, AppTile>{
        for (final AppTile t in all) '${t.package}|${t.updated}': t,
      };
      final List<AppTile> next =
          <AppTile>[
            for (final Map<Object?, Object?> o
                in names.cast<Map<Object?, Object?>>())
              old['${o['package']}|${(o['updated'] as num?)?.toInt() ?? 0}'] ??
                  AppTile(
                    o['label']! as String,
                    o['package']! as String,
                    (o['updated'] as num?)?.toInt() ?? 0,
                  ),
          ]..sort(
            (AppTile a, AppTile b) =>
                a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
      all = next;
      notifyListeners();
      // 1. Whatever was worked out before is read back.
      _dir.createSync(recursive: true);
      int fromDisk = 0, made = 0;
      final List<AppTile> todo = <AppTile>[];
      for (final AppTile t in all.where((AppTile t) => t.made == 'waiting')) {
        if (await _read(t)) {
          fromDisk++;
        } else {
          todo.add(t);
        }
      }
      notifyListeners();
      // 2. The rest are new or updated: fetch their icons a dozen at a time and work them out.
      for (int i = 0; i < todo.length; i += 12) {
        final List<AppTile> batch = todo.sublist(
          i,
          math.min(i + 12, todo.length),
        );
        final List<Object?> got =
            await _channel.invokeMethod<List<Object?>>('icons', <String>[
              for (final AppTile t in batch) t.package,
            ]) ??
            <Object?>[];
        for (final Object? o in got) {
          final Map<Object?, Object?> m = o! as Map<Object?, Object?>;
          final AppTile t = batch.firstWhere(
            (AppTile t) => t.package == m['asked'],
          );
          final Object? mono = m['mono'];
          final AppLook look = await IconEngine.look(
            await IconEngine.decode(m['icon']! as Uint8List),
            mono == null ? null : await IconEngine.decode(mono as Uint8List),
          );
          t
            ..made = look.made
            ..color = look.color ?? t.color
            ..glyph = look.glyph
            ..picture = look.picture;
          await _write(t);
          made++;
        }
        notifyListeners();
      }
      int count(String kind) => all.where((AppTile t) => t.made == kind).length;
      summary =
          '${all.length} apps: ${count('outline')} outline, ${count('cut-out')} cut-out, ${count('picture')} picture; '
          '$made worked out now, $fromDisk read from disk, ${clock.elapsedMilliseconds} ms';
    } catch (_) {
      if (all.isEmpty) {
        _pretend();
      }
    }
    _busy = false;
    notifyListeners();
  }

  String _file(AppTile t) => '${_dir.path}/${t.package}_${t.updated}';

  Future<bool> _read(AppTile t) async {
    try {
      final List<String> meta = File('${_file(t)}.txt')
          .readAsStringSync()
          .split('|');
      final File png = File('${_file(t)}.png');
      final ui.Image? image = png.existsSync()
          ? await IconEngine.decode(png.readAsBytesSync())
          : null;
      t
        ..made = meta[0]
        ..color = Color(int.parse(meta[1]));
      if (meta[0] == 'picture') {
        t.picture = image;
      } else {
        t.glyph = image;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _write(AppTile t) async {
    try {
      // Older results for the same app are no longer needed.
      for (final FileSystemEntity f in _dir.listSync()) {
        if (f.path.startsWith('${_dir.path}/${t.package}_')) {
          f.deleteSync();
        }
      }
      final ui.Image? image = t.glyph ?? t.picture;
      if (image != null) {
        final ByteData? png = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png != null) {
          File('${_file(t)}.png').writeAsBytesSync(png.buffer.asUint8List());
        }
      }
      File('${_file(t)}.txt')
          .writeAsStringSync('${t.made}|${t.color.toARGB32()}');
    } catch (_) {
      // No storage: it is simply worked out again next time.
    }
  }

  /// Off the phone there are no apps: made-up ones stand in, so the drawer can be looked at.
  void _pretend() {
    const List<String> names = <String>[
      'Atlas',
      'Bank',
      'Books',
      'Calendar',
      'Camera',
      'Chat',
      'Clock',
      'Cloud',
      'Compass',
      'Contacts',
      'Drive',
      'Files',
      'Fitness',
      'Gallery',
      'Games',
      'Health',
      'Home',
      'Mail',
      'Maps',
      'Meet',
      'Music',
      'News',
      'Notes',
      'Pay',
      'Phone',
      'Photos',
      'Podcasts',
      'Radio',
      'Recorder',
      'Settings',
      'Shop',
      'Sport',
      'Store',
      'Tasks',
      'Tickets',
      'Translate',
      'Travel',
      'Tube',
      'Video',
      'Wallet',
      'Watch',
      'Weather',
      'Zoo',
    ];
    all = <AppTile>[
      for (final (int i, String n) in names.indexed)
        AppTile(n, 'pretend.$n', 0)
          ..made = 'letter'
          ..color = BlobApps.tame(
            HSLColor.fromAHSL(1, (i * 47) % 360, 0.7, 0.5).toColor(),
          ),
    ];
    summary = 'pretend apps';
  }
}
