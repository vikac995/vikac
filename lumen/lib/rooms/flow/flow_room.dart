import 'package:material_ui/material_ui.dart';

import '../../core/expand_route.dart';
import '../../core/theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import 'stories.dart';

/// Room 04. Cards that become pages and go back into place, following the
/// finger during the back gesture.
class FlowRoom extends StatefulWidget {
  const FlowRoom({super.key});

  @override
  State<FlowRoom> createState() => _FlowRoomState();
}

class _FlowRoomState extends State<FlowRoom> {
  int? _open;

  void _openStory(BuildContext cardContext, int i) {
    final RenderBox box = cardContext.findRenderObject()! as RenderBox;
    final Rect origin = box.localToGlobal(Offset.zero) & box.size;
    final Story s = stories[i];
    setState(() => _open = i);
    Navigator.of(context).push(
      ExpandRoute<void>(
        builder: (_) => StoryPage(story: s),
        origin: origin,
        originRadius: 28,
        originColor: s.palette[1],
        morph: RouteMorph.container,
        originBuilder: (_) => StoryCard(story: s),
        onLanded: () {
          if (mounted && _open == i) {
            setState(() => _open = null);
          }
        },
      ),
    );
  }

  Widget _card(int i, double height) {
    return SizedBox(
      height: height,
      child: Opacity(
        // The card's place stays empty while it is out being a page.
        opacity: _open == i ? 0 : 1,
        child: Builder(
          builder: (BuildContext ctx) => Semantics(
            button: true,
            label: '${stories[i].title}, ${stories[i].place}',
            child: Pressable(
              scale: 0.96,
              onTap: () => _openStory(ctx, i),
              child: StoryCard(story: stories[i]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool gestures = MediaQuery.systemGestureInsetsOf(context).left > 0;
    const double gap = 12;
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 28),
        children: <Widget>[
          RoomHeader(
            number: 4,
            title: 'Flow',
            hint: gestures
                ? 'Open a card. To close it, swipe slowly from the screen edge: the page follows your finger. Let go early, or drag back, and it springs open again.'
                : 'Open a card. The back button closes it into its place on a spring. Switch the phone to gesture navigation to steer it with your finger.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: ShapeDecoration(
                color: c.surface,
                shape: StadiumBorder(side: BorderSide(color: c.hairline)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    gestures
                        ? Icons.swipe_rounded
                        : Icons.radio_button_checked_rounded,
                    size: 16,
                    color: c.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gestures
                        ? 'Gesture navigation detected'
                        : 'Button navigation detected',
                    style: LumenType.text(
                      12.5,
                      weight: 560,
                      color: c.inkMuted,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    _card(0, 250),
                    const SizedBox(height: gap),
                    _card(2, 196),
                    const SizedBox(height: gap),
                    _card(4, 232),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _card(1, 196),
                    const SizedBox(height: gap),
                    _card(3, 250),
                    const SizedBox(height: gap),
                    _card(5, 232),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoryPage extends StatelessWidget {
  const StoryPage({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: safe.bottom + 40),
            children: <Widget>[
              SizedBox(
                height: w * 1.12,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    RepaintBoundary(
                      child: CustomPaint(painter: StoryArt(story)),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const <double>[0.55, 1],
                          colors: <Color>[c.bg.withValues(alpha: 0), c.bg],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            story.place.toUpperCase(),
                            style: LumenType.label(color: c.accent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.title,
                            style: LumenType.display(
                              58,
                              weight: 760,
                              color: c.ink,
                              height: 0.95,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      story.lede,
                      style: LumenType.display(
                        23,
                        weight: 560,
                        color: c.ink,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        _Stat(label: 'Walk', value: '${2 + story.seed % 5} h'),
                        const SizedBox(width: 10),
                        _Stat(
                          label: 'Distance',
                          value: '${6 + story.seed % 9} km',
                        ),
                        const SizedBox(width: 10),
                        _Stat(
                          label: 'Best',
                          value: story.place.split(', ').last,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    for (final String para in story.body) ...<Widget>[
                      Text(
                        para,
                        style: LumenType.text(
                          16.5,
                          color: c.inkMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: safe.top + 44,
            left: 16,
            child: RoundButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: LumenType.label(color: c.inkFaint),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LumenType.text(16, weight: 620, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}
