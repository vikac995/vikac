import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';

const List<(String, String)> _exercises = <(String, String)>[
  ('Arnold press', 'Push'),
  ('Back extension', 'Pull'),
  ('Barbell row', 'Pull'),
  ('Bench press', 'Push'),
  ('Bulgarian split squat', 'Legs'),
  ('Cable fly', 'Push'),
  ('Calf raise', 'Legs'),
  ('Chin-up', 'Pull'),
  ('Close-grip bench', 'Push'),
  ('Deadlift', 'Pull'),
  ('Dip', 'Push'),
  ('Dumbbell curl', 'Pull'),
  ('Face pull', 'Pull'),
  ('Front squat', 'Legs'),
  ('Goblet squat', 'Legs'),
  ('Hack squat', 'Legs'),
  ('Hammer curl', 'Pull'),
  ('Hip thrust', 'Legs'),
  ('Incline press', 'Push'),
  ('Lat pulldown', 'Pull'),
  ('Lateral raise', 'Push'),
  ('Leg curl', 'Legs'),
  ('Leg extension', 'Legs'),
  ('Leg press', 'Legs'),
  ('Lunge', 'Legs'),
  ('Overhead press', 'Push'),
  ('Pec deck', 'Push'),
  ('Preacher curl', 'Pull'),
  ('Pull-up', 'Pull'),
  ('Push-up', 'Push'),
  ('Romanian deadlift', 'Legs'),
  ('Seated row', 'Pull'),
  ('Shrug', 'Pull'),
  ('Skull crusher', 'Push'),
  ('Squat', 'Legs'),
  ('Step-up', 'Legs'),
  ('T-bar row', 'Pull'),
  ('Triceps pushdown', 'Push'),
  ('Upright row', 'Pull'),
  ('Walking lunge', 'Legs'),
];

/// Room 34. A long list done properly: search as you type, filter chips,
/// section headers that stick, and a letter rail to jump with a thumb.
class ListsRoom extends StatefulWidget {
  const ListsRoom({super.key});

  @override
  State<ListsRoom> createState() => _ListsRoomState();
}

class _ListsRoomState extends State<ListsRoom> {
  static const double _rowH = 62, _headH = 34;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  String _filter = 'All', _query = '';
  String? _bubble;
  double _topBlock = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Map<String, List<(String, String)>> get _groups {
    final Map<String, List<(String, String)>> m =
        <String, List<(String, String)>>{};
    for (final (String, String) e in _exercises) {
      if ((_filter == 'All' || e.$2 == _filter) &&
          e.$1.toLowerCase().contains(_query.toLowerCase())) {
        (m[e.$1[0]] ??= <(String, String)>[]).add(e);
      }
    }
    return m;
  }

  void _jump(String letter, Map<String, List<(String, String)>> g) {
    double y = _topBlock;
    for (final String k in g.keys) {
      if (k == letter) {
        break;
      }
      y += _headH + g[k]!.length * _rowH;
    }
    _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  void _rail(double dy, double height, Map<String, List<(String, String)>> g) {
    final List<String> letters = g.keys.toList();
    if (letters.isEmpty) {
      return;
    }
    final String l =
        letters[(dy / height * letters.length).floor().clamp(
          0,
          letters.length - 1,
        )];
    if (l != _bubble) {
      setState(() => _bubble = l);
      Haptics.tick();
      _jump(l, g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Map<String, List<(String, String)>> g = _groups;
    final int count = g.values.fold<int>(
      0,
      (int n, List<(String, String)> l) => n + l.length,
    );
    _topBlock = 254;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: safe.top + 40),
            child: CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _topBlock,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const RoomHeader(number: 34, title: 'Lists'),
                          const SizedBox(height: 10),
                          Text(
                            'Pattern: forty rows here, seven hundred in a real library. Search, filter, or slide a thumb down the letters on the right.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: LumenType.text(
                              14,
                              color: c.inkMuted,
                              height: 1.4,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: ShapeDecoration(
                              color: c.ink.withValues(alpha: 0.07),
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: c.inkMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _search,
                                    onChanged: (String q) =>
                                        setState(() => _query = q),
                                    cursorColor: c.accent,
                                    style: LumenType.text(16, color: c.ink),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: 'Search exercises',
                                      hintStyle: LumenType.text(
                                        16,
                                        color: c.inkFaint,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_query.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      size: 20,
                                      color: c.inkFaint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              for (final String f in <String>[
                                'All',
                                'Push',
                                'Pull',
                                'Legs',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _filter = f);
                                      Haptics.tick();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: ShapeDecoration(
                                        color: _filter == f
                                            ? c.accent
                                            : Colors.transparent,
                                        shape: StadiumBorder(
                                          side: BorderSide(
                                            color: _filter == f
                                                ? c.accent
                                                : c.inkFaint,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        f,
                                        style: LumenType.text(
                                          13.5,
                                          weight: 620,
                                          color: _filter == f
                                              ? c.onAccent
                                              : c.ink,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                '$count',
                                style: LumenType.text(
                                  13.5,
                                  weight: 650,
                                  color: c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
                if (g.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: c.inkFaint,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nothing called "$_query"',
                            style: LumenType.text(
                              16,
                              weight: 620,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            'Check the spelling or clear the filter.',
                            style: LumenType.text(14, color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final MapEntry<String, List<(String, String)>> e
                    in g.entries)
                  SliverMainAxisGroup(
                    slivers: <Widget>[
                      // Each letter's header stays at the top while its rows pass under it.
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _Head(e.key, c, safe.top + 38, _headH),
                      ),
                      SliverFixedExtentList.list(
                        itemExtent: _rowH,
                        children: <Widget>[
                          for (final (String name, String group) in e.value)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 44, 0),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: ShapeDecoration(
                                      color: c.accent.withValues(alpha: 0.14),
                                      shape: const CircleBorder(),
                                    ),
                                    child: Icon(
                                      Icons.fitness_center_rounded,
                                      size: 18,
                                      color: c.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LumenType.text(
                                        16,
                                        weight: 580,
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    group,
                                    style: LumenType.text(
                                      13,
                                      color: c.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                SliverToBoxAdapter(child: SizedBox(height: safe.bottom + 40)),
              ],
            ),
          ),
          // The letter rail.
          if (g.length > 1)
            Positioned(
              right: 2,
              top: safe.top + 40 + 262,
              bottom: safe.bottom + 60,
              width: 40,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) =>
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (DragStartDetails d) =>
                          _rail(d.localPosition.dy, box.maxHeight, g),
                      onVerticalDragUpdate: (DragUpdateDetails d) =>
                          _rail(d.localPosition.dy, box.maxHeight, g),
                      onVerticalDragEnd: (_) => setState(() => _bubble = null),
                      onTapDown: (TapDownDetails d) =>
                          _rail(d.localPosition.dy, box.maxHeight, g),
                      onTapUp: (_) => setState(() => _bubble = null),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          for (final String l in g.keys)
                            Text(
                              l,
                              textScaler: TextScaler.noScaling,
                              style: LumenType.text(
                                11.5,
                                weight: 700,
                                color: l == _bubble ? c.accent : c.inkMuted,
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
              ),
            ),
          if (_bubble != null)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: const Color(0xE61A1C22),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _bubble!,
                    textScaler: TextScaler.noScaling,
                    style: LumenType.display(
                      52,
                      weight: 700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Head extends SliverPersistentHeaderDelegate {
  const _Head(this.letter, this.c, this.topInset, this.h);
  final String letter;
  final LumenColors c;
  final double topInset, h;

  @override
  double get minExtent => h;
  @override
  double get maxExtent => h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: c.bg,
      padding: const EdgeInsets.only(left: 20),
      alignment: Alignment.centerLeft,
      child: Text(
        letter,
        textScaler: TextScaler.noScaling,
        style: LumenType.text(14, weight: 700, color: c.accent),
      ),
    );
  }

  @override
  bool shouldRebuild(_Head old) => old.letter != letter || old.c != c;
}
