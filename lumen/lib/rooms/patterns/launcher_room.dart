import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/room_header.dart';
import '../../widgets/spring_box.dart';

class _Item {
  _Item(this.id, this.name, this.icon, this.color, [this.kids]);
  final int id;
  String name;
  final IconData icon;
  final Color color;
  List<_Item>? kids; // not null: this is a folder
  bool get isFolder => kids != null;
}

List<_Item> _apps() => <_Item>[
  _Item(1, 'Photos', Icons.photo_rounded, const Color(0xFFEF5DA8)),
  _Item(2, 'Maps', Icons.map_rounded, const Color(0xFF34A853)),
  _Item(3, 'Music', Icons.music_note_rounded, const Color(0xFFFF5E5B)),
  _Item(4, 'Clock', Icons.access_time_filled_rounded, const Color(0xFF3A3F4B)),
  _Item(5, 'Weather', Icons.wb_sunny_rounded, const Color(0xFF3B9BFF)),
  _Item(6, 'Notes', Icons.sticky_note_2_rounded, const Color(0xFFF5B301)),
  _Item(7, 'Mail', Icons.mail_rounded, const Color(0xFF4E6CC4)),
  _Item(8, 'Files', Icons.folder_rounded, const Color(0xFF2F978F)),
  _Item(9, 'Health', Icons.favorite_rounded, const Color(0xFFE5484D)),
  _Item(
    10,
    'Wallet',
    Icons.account_balance_wallet_rounded,
    const Color(0xFF865AC9),
  ),
  _Item(11, 'Gym Buddy', Icons.fitness_center_rounded, const Color(0xFFFF6B4A)),
  _Item(12, 'Settings', Icons.settings_rounded, const Color(0xFF7A8090)),
];

final List<_Item> _dock = <_Item>[
  _Item(101, 'Phone', Icons.call_rounded, const Color(0xFF30B55C)),
  _Item(102, 'Messages', Icons.chat_bubble_rounded, const Color(0xFF3B9BFF)),
  _Item(103, 'Camera', Icons.photo_camera_rounded, const Color(0xFF3A3F4B)),
  _Item(104, 'Browser', Icons.public_rounded, const Color(0xFF6C63FF)),
];

/// Room 20. A home screen. Long-press an icon and drag: the others make
/// room. Hold it over another icon to make a folder. Swipe up for all apps.
class LauncherRoom extends StatefulWidget {
  const LauncherRoom({super.key});

  @override
  State<LauncherRoom> createState() => _LauncherRoomState();
}

class _LauncherRoomState extends State<LauncherRoom>
    with TickerProviderStateMixin {
  static const int _cols = 4;
  static const double _rowH = 98, _icon = 58;

  final List<_Item> _grid = _apps();
  final GlobalKey _stageKey = GlobalKey();
  int _nextId = 200;
  int? _dragId;
  Offset _dragAt = Offset.zero;
  int? _folderTarget;
  Timer? _hover;
  int? _hoverIdx;
  _Item? _openFolder;
  String _status = 'Long-press an icon, then drag';
  String _query = '';
  double _cellW = 80;
  late final SpringValue _edit = SpringValue(
    this,
    spring: Motions.expressiveFast,
  );
  late final SpringValue _folder = SpringValue(
    this,
    spring: Motions.expressive,
  );
  late final SpringValue _drawer = SpringValue(
    this,
    spring: Motions.expressive,
  );
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _hover?.cancel();
    _edit.dispose();
    _folder.dispose();
    _drawer.dispose();
    _search.dispose();
    super.dispose();
  }

  Offset _slot(int i) => Offset((i % _cols) * _cellW, (i ~/ _cols) * _rowH);

  Offset _local(Offset global) =>
      (_stageKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  void _dragStart(_Item it, Offset global) {
    setState(() {
      _dragId = it.id;
      _dragAt = _local(global);
      _status = 'Drag to move. Hold over another icon to make a folder';
    });
    _edit.animateTo(1);
    Haptics.thud();
  }

  void _dragMove(Offset global) {
    final int? id = _dragId;
    if (id == null) {
      return;
    }
    final Offset p = _local(global);
    final int from = _grid.indexWhere((_Item x) => x.id == id);
    final int col = (p.dx / _cellW).floor().clamp(0, _cols - 1);
    final int row = (p.dy / _rowH).floor().clamp(0, 9);
    final int idx = math.min(row * _cols + col, _grid.length - 1);
    final Offset centre = _slot(idx) + Offset(_cellW / 2, _rowH / 2 - 8);
    final bool overIcon = idx != from && (p - centre).distance < _cellW * 0.27;
    setState(() => _dragAt = p);
    if (overIcon) {
      // Resting on an icon: after a moment it becomes a folder target.
      if (_hoverIdx != idx) {
        _hover?.cancel();
        _hoverIdx = idx;
        _hover = Timer(const Duration(milliseconds: 420), () {
          setState(() => _folderTarget = idx);
          Haptics.tick();
        });
      }
      return;
    }
    _hover?.cancel();
    _hoverIdx = null;
    if (_folderTarget != null) {
      setState(() => _folderTarget = null);
    }
    if (idx != from) {
      // Between icons: take that place, and the others shuffle along.
      setState(() => _grid.insert(idx, _grid.removeAt(from)));
      Haptics.tick();
    }
  }

  void _dragEnd() {
    final int? id = _dragId;
    if (id == null) {
      return;
    }
    _hover?.cancel();
    _hoverIdx = null;
    final int? target = _folderTarget;
    setState(() {
      if (target != null && target < _grid.length) {
        final int from = _grid.indexWhere((_Item x) => x.id == id);
        final _Item dragged = _grid[from], onto = _grid[target];
        if (!dragged.isFolder) {
          if (onto.isFolder) {
            onto.kids!.add(dragged);
          } else {
            _grid[target] = _Item(
              _nextId++,
              'Folder',
              Icons.folder_rounded,
              const Color(0xFF8A8F9C),
              <_Item>[onto, dragged],
            );
          }
          _grid.removeAt(from);
          _status = 'Folder made. Tap it to open';
          Haptics.thud();
        }
      } else {
        _status = 'Long-press an icon, then drag';
      }
      _dragId = null;
      _folderTarget = null;
    });
    _edit.animateTo(0);
  }

  void _tap(_Item it) {
    if (it.isFolder) {
      setState(() => _openFolder = it);
      _folder.animateTo(1);
      Haptics.tick();
    } else {
      setState(() => _status = 'Opened ${it.name}');
      Haptics.tick();
    }
  }

  void _closeFolder() {
    _folder.onSettle = () {
      if (_folder.target == 0 && mounted) {
        setState(() => _openFolder = null);
      }
    };
    _folder.animateTo(0, spring: Motions.spatialFast);
  }

  void _takeOut(_Item kid) {
    final _Item f = _openFolder!;
    setState(() {
      f.kids!.remove(kid);
      _grid.add(kid);
      if (f.kids!.length == 1) {
        // A folder of one becomes that app again.
        _grid[_grid.indexOf(f)] = f.kids!.first;
        _status = 'Folder removed';
      }
    });
    Haptics.settle();
    if (f.kids!.length <= 1) {
      _closeFolder();
    }
  }

  void _setDrawer(bool open) {
    _drawer.animateTo(
      open ? 1 : 0,
      spring: open ? Motions.expressive : Motions.spatialFast,
    );
    if (!open) {
      FocusScope.of(context).unfocus();
    }
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, safe.top + 44, 16, safe.bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const RoomHeader(number: 20, title: 'Launcher'),
            const SizedBox(height: 8),
            Text(_status, style: LumenType.text(14, color: c.inkMuted)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF2B2140),
                      Color(0xFF16263F),
                      Color(0xFF0F1622),
                    ],
                  ),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(34),
                    side: BorderSide(color: c.hairline),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    _cellW = (box.maxWidth - 24) / _cols;
                    return ListenableBuilder(
                      listenable: Listenable.merge(<Listenable>[
                        _edit,
                        _folder,
                        _drawer,
                      ]),
                      builder: (BuildContext context, Widget? _) => Stack(
                        children: <Widget>[
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 18,
                            bottom: 96,
                            child: _gridView(),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            height: 80,
                            child: _dockView(),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 96,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => _setDrawer(true),
                                onVerticalDragEnd: (DragEndDetails d) {
                                  if ((d.primaryVelocity ?? 0) < -100) {
                                    _setDrawer(true);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  color: Colors.transparent,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      Text(
                                        'All apps',
                                        style: LumenType.text(
                                          12.5,
                                          weight: 600,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_openFolder != null) _folderView(box.biggest),
                          if (_drawer.value > 0.01) _drawerView(c, box.biggest),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridView() {
    // The dragged icon is last, so it draws above the others.
    final List<_Item> order = <_Item>[
      ..._grid.where((_Item x) => x.id != _dragId),
      ..._grid.where((_Item x) => x.id == _dragId),
    ];
    return Stack(
      key: _stageKey,
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final _Item it in order)
          Builder(
            key: ValueKey<int>(it.id),
            builder: (BuildContext context) {
              final int i = _grid.indexOf(it);
              final bool dragging = it.id == _dragId;
              final Offset at = dragging
                  ? _dragAt - Offset(_cellW / 2, _rowH / 2 - 8)
                  : _slot(i);
              return SpringPositioned(
                left: at.dx,
                top: at.dy,
                width: _cellW,
                height: _rowH,
                // Under the finger it follows closely; released, it springs home.
                spring: dragging ? Motions.follow : Motions.expressive,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tap(it),
                  onLongPressStart: (LongPressStartDetails d) =>
                      _dragStart(it, d.globalPosition),
                  onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) =>
                      _dragMove(d.globalPosition),
                  onLongPressEnd: (_) => _dragEnd(),
                  onLongPressCancel: _dragEnd,
                  child: _IconView(
                    item: it,
                    size: _icon,
                    scale: dragging
                        ? 1 + 0.18 * _edit.value
                        : 1 - 0.06 * _edit.value,
                    target: _folderTarget == i && !dragging,
                    showLabel: !dragging,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _dockView() {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final _Item it in _dock)
            GestureDetector(
              onTap: () => _tap(it),
              child: _IconView(
                item: it,
                size: _icon,
                scale: 1,
                target: false,
                showLabel: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _folderView(Size stage) {
    final _Item f = _openFolder!;
    final double v = _folder.value;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeFolder,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5 * v.clamp(0.0, 1.0)),
          child: Center(
            child: Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * v,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: stage.width - 56,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: ShapeDecoration(
                      color: const Color(0xF22A2F3C),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          f.name,
                          style: LumenType.text(
                            17,
                            weight: 660,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final _Item kid in f.kids!)
                              GestureDetector(
                                onTap: () {
                                  _closeFolder();
                                  setState(
                                    () => _status = 'Opened ${kid.name}',
                                  );
                                },
                                onLongPress: () => _takeOut(kid),
                                child: SizedBox(
                                  width: 74,
                                  height: _rowH,
                                  child: _IconView(
                                    item: kid,
                                    size: _icon,
                                    scale: 1,
                                    target: false,
                                    showLabel: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Long-press an app to take it out',
                          style: LumenType.text(12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerView(LumenColors c, Size stage) {
    final double v = _drawer.value;
    final List<_Item> all = <_Item>[
      ..._dock,
      for (final _Item it in _grid) ...(it.isFolder ? it.kids! : <_Item>[it]),
    ]..sort((_Item a, _Item b) => a.name.compareTo(b.name));
    final List<_Item> shown = all
        .where(
          (_Item it) => it.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: stage.height,
      child: Transform.translate(
        offset: Offset(0, stage.height * (1 - v)),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xF5171B24)),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setDrawer(false),
                onVerticalDragEnd: (DragEndDetails d) {
                  if ((d.primaryVelocity ?? 0) > 100) {
                    _setDrawer(false);
                  }
                },
                child: SizedBox(
                  height: 30,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: const ShapeDecoration(
                        color: Colors.white38,
                        shape: StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const ShapeDecoration(
                  color: Color(0x22FFFFFF),
                  shape: StadiumBorder(),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (String q) => setState(() => _query = q),
                        cursorColor: c.accent,
                        style: LumenType.text(16, color: Colors.white),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Search apps',
                          hintStyle: LumenType.text(16, color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          'No app called "$_query"',
                          style: LumenType.text(14.5, color: Colors.white60),
                        ),
                      )
                    : GridView.count(
                        crossAxisCount: 4,
                        childAspectRatio: _cellW / _rowH,
                        padding: const EdgeInsets.only(bottom: 16),
                        children: <Widget>[
                          for (final _Item it in shown)
                            GestureDetector(
                              onTap: () {
                                _setDrawer(false);
                                setState(() => _status = 'Opened ${it.name}');
                              },
                              child: _IconView(
                                item: it,
                                size: _icon,
                                scale: 1,
                                target: false,
                                showLabel: true,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconView extends StatelessWidget {
  const _IconView({
    required this.item,
    required this.size,
    required this.scale,
    required this.target,
    required this.showLabel,
  });
  final _Item item;
  final double size;
  final double scale;
  final bool target;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Widget face = item.isFolder
        ? Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(8),
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(size * 0.32),
              ),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (final _Item k in item.kids!.take(4))
                  Container(
                    width: (size - 20) / 2,
                    height: (size - 20) / 2,
                    decoration: ShapeDecoration(
                      color: k.color,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(item.color, Colors.white, 0.22)!,
                  item.color,
                ],
              ),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(size * 0.32),
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: size * 0.5),
          );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              // The ring that says "drop here to make a folder".
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: target ? size + 18 : size,
                height: target ? size + 18 : size,
                decoration: ShapeDecoration(
                  color: Colors.white.withValues(alpha: target ? 0.28 : 0),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(size * 0.4),
                  ),
                ),
              ),
              face,
            ],
          ),
        ),
        if (showLabel) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: LumenType.text(
              11.5,
              weight: 560,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}
