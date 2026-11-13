import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One real app the blob menu can open.
class BlobApp {
  BlobApp(this.name, this.package, Color brand) : color = BlobApps.tame(brand);
  final String name, package;
  bool installed = false;

  /// The blob's colour: the icon's own colour, brought into Prism's palette.
  Color color;

  /// A white outline of the icon where the app supplies one, else the icon itself.
  ui.Image? glyph, icon;
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
          (BlobApp a) => a.package == m['package'],
        );
        a.installed = true;
        a.icon = await _decode(m['icon']! as Uint8List);
        final Object? mono = m['mono'];
        if (mono != null) {
          a.glyph = await _decode(mono as Uint8List);
        }
        final Color? main = await _mainColour(a.icon!);
        if (main != null) {
          a.color = tame(main);
        }
      }
      notifyListeners();
    } catch (_) {
      // Not on Android: the stand-in colours and initials are used.
    }
  }

  Future<bool> launch(BlobApp a) async {
    try {
      return await _channel.invokeMethod<bool>('launch', a.package) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  /// The colour an icon is mostly made of. Pixels vote for their hue, the more
  /// colourful the louder; white, black and grey do not vote. Null if the icon
  /// has no real colour.
  static Future<Color?> _mainColour(ui.Image image) async {
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
