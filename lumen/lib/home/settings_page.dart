import 'package:material_ui/material_ui.dart';

import '../core/frame_stats.dart';
import '../core/glass.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/controls.dart';

String qualityBlurb(GlassQuality q) => switch (q) {
  GlassQuality.auto => 'Starts at Full and steps down if frames are missed.',
  GlassQuality.full => 'Blur, refraction, colour split and rim light.',
  GlassQuality.medium => 'Blur, lighter refraction and rim light.',
  GlassQuality.low => 'Blur and tint only.',
};

String qualityName(GlassQuality q) => switch (q) {
  GlassQuality.auto => 'Auto',
  GlassQuality.full => 'Full',
  GlassQuality.medium => 'Medium',
  GlassQuality.low => 'Low',
};

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? _) {
          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              safe.top + 52,
              20,
              safe.bottom + 32,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  RoundButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style: LumenType.display(32, weight: 720, color: c.ink),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _Group(
                label: 'Appearance',
                children: <Widget>[
                  Segmented<ThemeMode>(
                    values: const <ThemeMode>[
                      ThemeMode.system,
                      ThemeMode.light,
                      ThemeMode.dark,
                    ],
                    labels: const <String>['System', 'Light', 'Dark'],
                    value: settings.themeMode,
                    onChanged: (ThemeMode m) => settings.themeMode = m,
                  ),
                ],
              ),
              _Group(
                label: 'Comfort',
                children: <Widget>[
                  _SwitchRow(
                    title: 'Reduce motion',
                    detail: 'No overshoot. Everything arrives almost at once.',
                    value: settings.reduceMotion,
                    onChanged: (bool v) => settings.reduceMotion = v,
                  ),
                  Divider(height: 1, thickness: 1, color: c.hairline),
                  _SwitchRow(
                    title: 'Reduce transparency',
                    detail: 'Glass becomes a solid surface.',
                    value: settings.reduceTransparency,
                    onChanged: (bool v) => settings.reduceTransparency = v,
                  ),
                ],
              ),
              _Group(
                label: 'Glass quality',
                children: <Widget>[
                  Segmented<GlassQuality>(
                    values: GlassQuality.values,
                    labels: GlassQuality.values.map(qualityName).toList(),
                    value: settings.quality,
                    onChanged: (GlassQuality q) {
                      settings.quality = q;
                      if (q == GlassQuality.auto) {
                        settings.resetAutoTier();
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                    child: Text(
                      settings.quality == GlassQuality.auto
                          ? '${qualityBlurb(GlassQuality.auto)} Running ${qualityName(settings.effectiveQuality)} now.'
                          : qualityBlurb(settings.quality),
                      style: LumenType.text(13, color: c.inkMuted),
                    ),
                  ),
                  if (!GlassShaders.available)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                      child: Text(
                        'This device cannot run the glass shader, so Low is always used.',
                        style: LumenType.text(13, color: c.accent),
                      ),
                    ),
                ],
              ),
              _Group(
                label: 'Diagnostics',
                children: <Widget>[
                  _SwitchRow(
                    title: 'Frame-rate readout',
                    detail: 'Shown at the top of every screen.',
                    value: settings.showFps,
                    onChanged: (bool v) {
                      settings.showFps = v;
                      FrameStats.instance.resetCounters();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: LumenType.label(color: c.inkFaint),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(color: c.hairline),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: LumenType.text(16, weight: 560, color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: LumenType.text(13, color: c.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LumenSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
