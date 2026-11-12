import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/springs.dart';
import '../../core/theme.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/room_header.dart';
import '../shapes/shape_loader.dart';

const Color _ok = Color(0xFF2FA84F);
const Color _bad = Color(0xFFE5484D);

/// Room 17. A sign-up form that helps instead of scolding: labels that stay
/// visible, checks as you go, clear errors, and a button that says why not.
class FormsRoom extends StatefulWidget {
  const FormsRoom({super.key});

  @override
  State<FormsRoom> createState() => _FormsRoomState();
}

class _FormsRoomState extends State<FormsRoom> with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final GlobalKey<_FieldState> _emailKey = GlobalKey<_FieldState>();
  final GlobalKey<_FieldState> _passKey = GlobalKey<_FieldState>();
  late final SpringValue _shake = SpringValue(
    this,
    spring: Motions.expressiveFast,
    settleDistance: 0.5,
    settleVelocity: 10,
  );
  bool _hide = true;
  int _phase = 0; // 0 idle, 1 sending, 2 done
  Timer? _timer;

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  String? _emailError(String v) => v.isEmpty
      ? 'Enter your email'
      : _emailRe.hasMatch(v)
      ? null
      : 'That does not look like an email. Check for a missing @ or ending.';

  int _strength(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[A-Za-z]').hasMatch(v)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
  }

  String? _passError(String v) =>
      v.length >= 8 ? null : 'Use at least 8 characters (${v.length} so far)';

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _pass.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _submit() {
    if (_phase != 0) {
      return;
    }
    final bool valid =
        _emailError(_email.text) == null && _passError(_pass.text) == null;
    if (!valid) {
      // Show what is wrong on the fields themselves, and shake the button.
      _emailKey.currentState?.touch();
      _passKey.currentState?.touch();
      _shake.jumpTo(0);
      _shake.animateTo(0, velocity: 700);
      Haptics.thud();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _phase = 1);
    _timer = Timer(const Duration(milliseconds: 1500), () {
      setState(() => _phase = 2);
      Haptics.settle();
      _timer = Timer(
        const Duration(milliseconds: 2200),
        () => setState(() => _phase = 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final int strength = _strength(_pass.text);
    const List<String> words = <String>[
      'Too short',
      'Weak',
      'Fair',
      'Good',
      'Strong',
    ];
    const List<Color> cols = <Color>[
      _bad,
      _bad,
      Color(0xFFF5A524),
      Color(0xFF7BC96F),
      _ok,
    ];
    return RoomScaffold(
      children: <Widget>[
        const RoomHeader(
          number: 17,
          title: 'Forms',
          hint:
              'Basics: forms are where people give up. Keep the label visible, check as they type '
              'but complain only after they leave a field, and say how to fix it.',
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Create your account',
                style: LumenType.display(24, weight: 700, color: c.ink),
              ),
              const SizedBox(height: 16),
              _Field(
                key: _emailKey,
                label: 'Email',
                controller: _email,
                validator: _emailError,
                keyboardType: TextInputType.emailAddress,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _Field(
                key: _passKey,
                label: 'Password',
                controller: _pass,
                validator: _passError,
                obscure: _hide,
                onChanged: () => setState(() {}),
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _hide = !_hide),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: c.inkMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 5,
                        margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                        decoration: ShapeDecoration(
                          color: _pass.text.isNotEmpty && i < strength
                              ? cols[strength]
                              : c.ink.withValues(alpha: 0.1),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _pass.text.isEmpty
                    ? 'Longer is stronger. A phrase works well.'
                    : words[strength],
                style: LumenType.text(
                  12.5,
                  weight: 560,
                  color: _pass.text.isEmpty ? c.inkMuted : cols[strength],
                ),
              ),
              const SizedBox(height: 18),
              ListenableBuilder(
                listenable: _shake,
                builder: (BuildContext context, Widget? child) =>
                    Transform.translate(
                      offset: Offset(_shake.value, 0),
                      child: child,
                    ),
                child: Pressable(
                  onTap: _submit,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: _phase == 2 ? _ok : c.accent,
                      shape: const StadiumBorder(),
                    ),
                    child: switch (_phase) {
                      1 => ShapeLoader(size: 24, color: c.onAccent),
                      2 => const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Account created',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      _ => Text(
                        'Create account',
                        style: LumenType.text(
                          16,
                          weight: 640,
                          color: c.onAccent,
                          height: 1,
                        ),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: Text(
            'Try it: tap Create account while empty. Type "mira@" and move to the password. Then fix it and watch the error leave.',
            style: LumenType.text(13.5, color: c.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String) validator;
  final VoidCallback onChanged;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  late final SpringValue _float = SpringValue(
    this,
    spring: Motions.spatialFast,
  );
  late final SpringValue _err = SpringValue(this, spring: Motions.spatial);
  bool _touched = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Complain only once the person has left the field.
      if (!_focus.hasFocus && widget.controller.text.isNotEmpty) {
        _touched = true;
      }
      _sync();
    });
    widget.controller.addListener(_sync);
  }

  void touch() {
    _touched = true;
    _sync();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    _float.animateTo(
      _focus.hasFocus || widget.controller.text.isNotEmpty ? 1 : 0,
    );
    final String? e = _touched
        ? widget.validator(widget.controller.text)
        : null;
    if (e != null) {
      _lastError = e;
    }
    _err.animateTo(e == null ? 0 : 1);
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focus.dispose();
    _float.dispose();
    _err.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LumenColors c = LumenColors.of(context);
    final bool valid =
        widget.controller.text.isNotEmpty &&
        widget.validator(widget.controller.text) == null;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_float, _err]),
      builder: (BuildContext context, Widget? input) {
        final double f = _float.value.clamp(0.0, 1.0);
        final double e = _err.value.clamp(0.0, 1.0);
        final Color edge = Color.lerp(
          _focus.hasFocus ? c.accent : c.ink.withValues(alpha: 0.18),
          _bad,
          e,
        )!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              onTap: _focus.requestFocus,
              child: Container(
                height: 60,
                padding: const EdgeInsets.only(left: 16),
                decoration: ShapeDecoration(
                  color: c.ink.withValues(alpha: 0.04),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: edge,
                      width: _focus.hasFocus || e > 0 ? 2 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          // The label shrinks and rises; it never disappears.
                          Transform.translate(
                            offset: Offset(0, -15 * f),
                            child: Transform.scale(
                              scale: lerpDouble(1, 0.76, f)!,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                textScaler: TextScaler.noScaling,
                                style: LumenType.text(
                                  16,
                                  color: Color.lerp(c.inkMuted, _bad, e),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: input,
                          ),
                        ],
                      ),
                    ),
                    if (valid)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: _ok,
                          size: 22,
                        ),
                      ),
                    if (widget.trailing != null) widget.trailing!,
                    if (widget.trailing == null && !valid)
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: e,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.error_rounded, size: 15, color: _bad),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lastError ?? '',
                          style: LumenType.text(12.5, weight: 560, color: _bad),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: c.accent,
        onChanged: (_) => widget.onChanged(),
        style: LumenType.text(16, color: c.ink),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}
