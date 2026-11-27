import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../theme.dart';
import 'tenkovi_text.dart';
import 'wolf_screens.dart' show RoleHoldScreen;

const _amber = Color(0xFFFFB020);
const _green = Color(0xFF3DDC84);

/// What the TV last told this phone during Tenkovi: the latest [TenkoviTurn].
class TenkoviInbox {
  TenkoviTurn? turn;

  /// The aim this phone pressed, kept only here so the held card can show it
  /// while the volley flies (the TV forgets it when it fires).
  TenkoviFire? pressed;

  void on(Message m) {
    if (m is! TenkoviTurn) return;
    // A new turn clears what was pressed in the last one.
    if (m.stage == 'aim' && m.sent == null) pressed = null;
    turn = m;
  }

  void reset() {
    turn = null;
    pressed = null;
  }
}

/// The phone's Tenkovi screens (boards TenkoviPhoneAim, AimSmall, Wait): aim
/// and press Pucaj, then a hold-to-see card (the aim is on screen only while a
/// finger is down), then the round result.
///
/// PRIVACY: this phone gets only its own aim back; the hidden card looks the
/// same on every phone, and the aim shows only while it is held. The names
/// under the card are only who has NOT pressed Pucaj yet (the TV shows that).
class TenkoviFlow extends StatelessWidget {
  const TenkoviFlow(this.conn, this.lobby, this.myId, this.inbox, {super.key});
  final Connection conn;
  final LobbyState lobby;
  final int myId;
  final TenkoviInbox inbox;

  PlayerInfo? _player(int id) => lobby.players.where((p) => p.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final t = inbox.turn;
    if (t == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final me = _player(myId);
    if (t.stage == 'end') return _RoundOver(t, myId);
    if (!t.alive) return _Quiet(t, text: TenkoviStrings.out);
    final sent = t.sent != null || t.stage == 'fly';
    if (sent) {
      final TenkoviFire? p = t.sent != null
          ? TenkoviFire(t.sent![0], t.sent![1], TenkoviShell.values[t.sent![2]])
          : inbox.pressed;
      // After a reload in the air only the last angle and power are known.
      final a = p?.angle ?? t.last?[0], pw = p?.power ?? t.last?[1];
      return RoleHoldScreen(
        key: ValueKey('tenkovi-sent-${t.round}-${t.stage}'),
        name: me?.name ?? '',
        night: 0,
        header: TenkoviStrings.turn(t.turn),
        heading: TenkoviStrings.sentCaps,
        hiddenHint: TenkoviStrings.holdHint,
        role: p == null ? '–' : TenkoviStrings.shellName(p.shell),
        description: a == null ? '' : TenkoviStrings.angleAndPower(a, pw!),
        extra: '',
        bottom: _WaitBlock(
          flying: t.stage == 'fly',
          waiting: [for (final id in t.waiting) ?_player(id)],
        ),
      );
    }
    return TenkoviAimScreen(
      // A new turn starts from last turn's values.
      key: ValueKey('aim-${t.round}-${t.turn}-${t.last}-${t.hp}-${t.heavy}-${t.cluster}'),
      turn: t,
      me: me,
      onFire: (angle, power, shell) {
        final m = TenkoviFire(angle, power, shell);
        inbox.pressed = m;
        conn.send(m);
      },
    );
  }
}

/// "Pucaj je poslan, čekamo ostale" and who is still aiming.
class _WaitBlock extends StatelessWidget {
  const _WaitBlock({required this.flying, required this.waiting});
  final bool flying;
  final List<PlayerInfo> waiting;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF18181E),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 22, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flying ? TenkoviStrings.volleyTitle : TenkoviStrings.sentTitle,
                      key: const ValueKey('tenkovi-wait-title'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      flying ? TenkoviStrings.watchTv : TenkoviStrings.waitOthers,
                      style: const TextStyle(fontSize: 16, color: Color(0xFF8A8A96)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            TenkoviStrings.stillAiming(waiting.length),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF8A8A96),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 18,
            runSpacing: 2,
            children: [
              for (final p in waiting)
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: playerColors[p.colorIndex % playerColors.length],
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.t, {required this.text});
  final TenkoviTurn t;
  final String text;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              TenkoviStrings.roundTurn(t.round, t.rounds, t.turn),
              style: const TextStyle(fontSize: 18, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              key: const ValueKey('tenkovi-quiet'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              '${TenkoviStrings.wind}: ${TenkoviStrings.windValue(t.wind)}',
              style: const TextStyle(fontSize: 20, color: muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundOver extends StatelessWidget {
  const _RoundOver(this.t, this.myId);
  final TenkoviTurn t;
  final int myId;
  @override
  Widget build(BuildContext context) {
    final line = t.winner == null
        ? TenkoviStrings.draw
        : t.winner == myId
        ? TenkoviStrings.youWon
        : TenkoviStrings.roundOver;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                TenkoviStrings.round(t.round, t.rounds),
                style: const TextStyle(fontSize: 18, color: muted),
              ),
              const SizedBox(height: 16),
              Text(
                line,
                key: const ValueKey('tenkovi-over'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Text(
                TenkoviStrings.roundPoints(t.points, t.score),
                style: const TextStyle(fontSize: 22, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Angle 0-180, power 0-100, projectile, Pucaj. Starts from last turn's values.
class TenkoviAimScreen extends StatefulWidget {
  const TenkoviAimScreen({
    super.key,
    required this.turn,
    required this.onFire,
    this.me,
  });
  final TenkoviTurn turn;
  final PlayerInfo? me;
  final void Function(int angle, int power, TenkoviShell shell) onFire;

  @override
  State<TenkoviAimScreen> createState() => _AimState();
}

class _AimState extends State<TenkoviAimScreen> {
  late int _angle = widget.turn.last?[0] ?? 45;
  late int _power = widget.turn.last?[1] ?? 50;
  TenkoviShell _shell = TenkoviShell.grenade;
  bool _pressed = false;

  bool _left(TenkoviShell s) => switch (s) {
        TenkoviShell.heavy => widget.turn.heavy,
        TenkoviShell.cluster => widget.turn.cluster,
        _ => true,
      };

  Widget _stepButton(Key key, String text, double size, VoidCallback? on) =>
      SizedBox(
        width: size,
        height: size,
        child: FilledButton(
          key: key,
          onPressed: on,
          style: FilledButton.styleFrom(
            minimumSize: Size(size, size),
            padding: EdgeInsets.zero,
            backgroundColor: raised,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
        ),
      );

  /// One panel: − icon+value +, and the fast slider under it.
  Widget _panel({
    required String id,
    required String label,
    required String value,
    required Widget icon,
    required int v,
    required int max,
    required void Function(int) set,
    required bool compact,
  }) {
    final b = compact ? 60.0 : 64.0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: b,
            child: Row(
              children: [
                _stepButton(ValueKey('$id-minus'), '−', b, v > 0 ? () => set(v - 1) : null),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w700, height: 1.05)),
                          Text(
                            value,
                            key: ValueKey('$id-value'),
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.05),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),
                _stepButton(ValueKey('$id-plus'), '+', b, v < max ? () => set(v + 1) : null),
              ],
            ),
          ),
          SizedBox(
            height: compact ? 44 : 56,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: compact ? 44 : 56,
                activeTrackColor: _amber.withValues(alpha: 0.3),
                inactiveTrackColor: bg,
                thumbColor: _amber,
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const _PillTrack(),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 20 : 24, elevation: 3),
              ),
              child: Slider(
                key: ValueKey(id),
                value: v.toDouble(),
                min: 0,
                max: max.toDouble(),
                onChanged: (d) => set(d.round()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(TenkoviShell s, bool compact) {
    final left = _left(s);
    final on = _shell == s && left;
    final sub = s == TenkoviShell.grenade
        ? TenkoviStrings.unlimited
        : left
        ? TenkoviStrings.one
        : TenkoviStrings.none;
    final fg = on ? ink : textColor;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Opacity(
          opacity: left ? 1 : 0.4,
          child: InkWell(
            key: ValueKey('shell-${s.name}'),
            borderRadius: BorderRadius.circular(16),
            onTap: left ? () => setState(() => _shell = s) : null,
            child: Container(
              height: compact ? 76 : 88,
              decoration: BoxDecoration(
                color: on ? accent : surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? accent : raised, width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(28, 28),
                          painter: _ShellIcon(s, fg),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            TenkoviStrings.shellName(s),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg, height: 1.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 4,
                    child: Text(
                      sub,
                      key: ValueKey('ammo-${s.name}'),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.turn;
    final last = t.last;
    final me = widget.me;
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 740;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: compact ? 36 : 40,
                    child: Row(
                      children: [
                        if (me != null && me.character.isNotEmpty) ...[
                          CharacterFace(
                            me.character,
                            compact ? 32 : 36,
                            playerColors[me.colorIndex % playerColors.length],
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            me?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              TenkoviStrings.roundTurn(t.round, t.rounds, t.turn),
                              style: const TextStyle(fontSize: 16, color: muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Row(
                    children: [
                      Expanded(child: _windTile(t.wind)),
                      const SizedBox(width: 8),
                      Expanded(child: _lastTile(last)),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  _panel(
                    id: 'angle',
                    label: TenkoviStrings.angle,
                    value: TenkoviStrings.degrees(_angle),
                    icon: CustomPaint(size: const Size(56, 36), painter: _DialIcon(_angle)),
                    v: _angle,
                    max: 180,
                    set: (v) => setState(() => _angle = v),
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  _panel(
                    id: 'power',
                    label: TenkoviStrings.power,
                    value: '$_power',
                    icon: CustomPaint(size: const Size(56, 36), painter: _BarsIcon(_power)),
                    v: _power,
                    max: 100,
                    set: (v) => setState(() => _power = v),
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Row(
                    children: [
                      _chip(TenkoviShell.grenade, compact),
                      _chip(TenkoviShell.heavy, compact),
                      _chip(TenkoviShell.cluster, compact),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: compact ? 76 : 88,
                    child: FilledButton(
                      key: const ValueKey('tenkovi-fire'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        foregroundColor: ink,
                        disabledBackgroundColor: _amber.withValues(alpha: 0.5),
                        disabledForegroundColor: ink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        textStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                      onPressed: _pressed
                          ? null
                          : () {
                              setState(() => _pressed = true);
                              widget.onFire(_angle, _power, _left(_shell) ? _shell : TenkoviShell.grenade);
                            },
                      child: const Text(TenkoviStrings.fire),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 10),
                    const Text(
                      TenkoviStrings.privacyNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: muted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _windTile(int wind) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
      key: const ValueKey('tenkovi-wind'),
      children: [
        const Text(TenkoviStrings.wind, style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        if (wind == 0)
          const Text(TenkoviStrings.noWind, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))
        else ...[
          Transform.scale(
            scaleX: wind < 0 ? -1 : 1,
            child: const SizedBox(width: 70 * 0.62 + 6, height: 25, child: CustomPaint(painter: _ArrowIcon())),
          ),
          const SizedBox(width: 6),
          Text('${wind.abs()}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ],
      ],
    ),
    ),
  );

  Widget _lastTile(List<int>? last) => InkWell(
    key: const ValueKey('tenkovi-last-button'),
    borderRadius: BorderRadius.circular(14),
    onTap: last == null
        ? null
        : () => setState(() {
              _angle = last[0];
              _power = last[1];
            }),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
      child: last == null
          ? const SizedBox.shrink()
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(TenkoviStrings.lastTimeButton, style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w700, height: 1.1)),
                  Text(
                    TenkoviStrings.lastValues(last[0], last[1]),
                    key: const ValueKey('tenkovi-last'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                ],
              ),
            ),
    ),
  );
}

/// A slider track that is a pill, as on the boards.
class _PillTrack extends SliderTrackShape with BaseSliderTrackShape {
  const _PillTrack();
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final r = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
    final c = context.canvas;
    c.drawRRect(rr, Paint()..color = sliderTheme.inactiveTrackColor!);
    c.save();
    c.clipRRect(rr);
    c.drawRect(
      Rect.fromLTRB(r.left, r.top, thumbCenter.dx, r.bottom),
      Paint()..color = sliderTheme.activeTrackColor!,
    );
    c.restore();
  }
}

/// A half dial with a needle at the angle (the angle is this player's own).
class _DialIcon extends CustomPainter {
  const _DialIcon(this.angle);
  final int angle;
  @override
  void paint(Canvas canvas, Size size) {
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = raised;
    canvas.drawArc(Rect.fromCircle(center: const Offset(28, 32), radius: 24), pi, pi, false, arc);
    final a = angle * pi / 180;
    canvas.drawLine(
      const Offset(28, 32),
      Offset(28 + cos(a) * 19, 32 - sin(a) * 19),
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = _amber,
    );
    canvas.drawCircle(const Offset(28, 32), 4, Paint()..color = textColor);
  }

  @override
  bool shouldRepaint(_DialIcon old) => old.angle != angle;
}

/// Five rising bars, as many lit as the power fills.
class _BarsIcon extends CustomPainter {
  const _BarsIcon(this.power);
  final int power;
  @override
  void paint(Canvas canvas, Size size) {
    final lit = (power / 20).ceil().clamp(0, 5);
    for (var i = 0; i < 5; i++) {
      final h = 8.0 + i * 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * 11.5, 32 - h, 8, h), const Radius.circular(3)),
        Paint()..color = i < lit ? _amber : raised,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsIcon old) => old.power != power;
}

class _ShellIcon extends CustomPainter {
  const _ShellIcon(this.shell, this.color);
  final TenkoviShell shell;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    switch (shell) {
      case TenkoviShell.heavy:
        canvas.drawCircle(const Offset(13, 16), 11, p);
        canvas.drawLine(
          const Offset(19, 7),
          const Offset(24, 2),
          Paint()
            ..color = color
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      case TenkoviShell.cluster:
        canvas.drawCircle(const Offset(14, 6), 5, p);
        canvas.drawCircle(const Offset(6, 20), 5, p);
        canvas.drawCircle(const Offset(22, 20), 5, p);
      default:
        canvas.drawCircle(const Offset(14, 14), 8, p);
    }
  }

  @override
  bool shouldRepaint(_ShellIcon old) => old.shell != shell || old.color != color;
}

class _ArrowIcon extends CustomPainter {
  const _ArrowIcon();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120 * 1.0, size.width / 120);
    canvas.drawLine(
      const Offset(4, 20),
      const Offset(84, 20),
      Paint()
        ..color = textColor
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(80, 2)
        ..lineTo(114, 20)
        ..lineTo(80, 38)
        ..close(),
      Paint()..color = textColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowIcon old) => false;
}
