import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../theme.dart';
import 'tenkovi_text.dart';
import 'wolf_screens.dart' show RoleHoldScreen;

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

/// The phone's Tenkovi screens: aim and press Pucaj, then a hold-to-see card
/// (the aim is on screen only while a finger is down), then the round result.
///
/// PRIVACY: this phone gets only its own aim back; the hidden card looks the
/// same on every phone, and the aim shows only while it is held.
class TenkoviFlow extends StatelessWidget {
  const TenkoviFlow(this.conn, this.myId, this.inbox, {super.key});
  final Connection conn;
  final int myId;
  final TenkoviInbox inbox;

  @override
  Widget build(BuildContext context) {
    final t = inbox.turn;
    if (t == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (t.stage == 'end') return _RoundOver(t, myId);
    if (!t.alive) {
      return _Quiet(t, text: TenkoviStrings.out);
    }
    final sent = t.sent != null || t.stage == 'fly';
    if (sent) {
      final TenkoviFire? p = t.sent != null
          ? TenkoviFire(t.sent![0], t.sent![1], TenkoviShell.values[t.sent![2]])
          : inbox.pressed;
      // After a reload in the air only the last angle and power are known.
      final answer = p != null
          ? TenkoviStrings.sentText(p.angle, p.power, p.shell)
          : t.last != null
          ? TenkoviStrings.sentTextShort(t.last![0], t.last![1])
          : '–';
      return RoleHoldScreen(
        key: ValueKey('tenkovi-sent-${t.round}-${t.stage}'),
        name: TenkoviStrings.round(t.round, t.rounds),
        night: 0,
        header: TenkoviStrings.windValue(t.wind),
        heading: TenkoviStrings.sentCaps,
        hiddenHint: 'Poslano. Gledaj TV.\nHitac se vidi samo dok držiš.',
        role: answer,
        description: t.stage == 'fly'
            ? TenkoviStrings.volley
            : TenkoviStrings.ready(t.ready, t.total),
        bottom: null,
      );
    }
    return TenkoviAimScreen(
      // A new turn starts from last turn's values.
      key: ValueKey('aim-${t.round}-${t.last}-${t.hp}-${t.heavy}-${t.cluster}'),
      turn: t,
      onFire: (angle, power, shell) {
        final m = TenkoviFire(angle, power, shell);
        inbox.pressed = m;
        conn.send(m);
      },
    );
  }
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
              TenkoviStrings.round(t.round, t.rounds),
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
              TenkoviStrings.windValue(t.wind),
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
  });
  final TenkoviTurn turn;
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

  Widget _stepper({
    required String id,
    required String label,
    required String value,
    required int v,
    required int max,
    required void Function(int) set,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: muted)),
          const Spacer(),
          Text(
            value,
            key: ValueKey('$id-value'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      Row(
        children: [
          _stepButton(ValueKey('$id-minus'), '−', v > 0 ? () => set(v - 1) : null),
          Expanded(
            child: Slider(
              key: ValueKey(id),
              value: v.toDouble(),
              min: 0,
              max: max.toDouble(),
              onChanged: (d) => set(d.round()),
            ),
          ),
          _stepButton(ValueKey('$id-plus'), '+', v < max ? () => set(v + 1) : null),
        ],
      ),
    ],
  );

  Widget _stepButton(Key key, String text, VoidCallback? on) => SizedBox(
    width: 52,
    height: 52,
    child: FilledButton(
      key: key,
      onPressed: on,
      style: FilledButton.styleFrom(
        minimumSize: const Size(52, 52),
        padding: EdgeInsets.zero,
        backgroundColor: raised,
        foregroundColor: textColor,
      ),
      child: Text(text, style: const TextStyle(fontSize: 28)),
    ),
  );

  Widget _chip(TenkoviShell s) {
    final left = _left(s);
    final on = _shell == s && left;
    final sub = s == TenkoviShell.grenade
        ? TenkoviStrings.unlimited
        : left
        ? TenkoviStrings.one
        : TenkoviStrings.used;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Opacity(
          opacity: left ? 1 : 0.4,
          child: InkWell(
            key: ValueKey('shell-${s.name}'),
            borderRadius: BorderRadius.circular(14),
            onTap: left ? () => setState(() => _shell = s) : null,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: on ? accent.withValues(alpha: 0.2) : surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: on ? accent : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      TenkoviStrings.shellName(s),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 14, color: muted),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      TenkoviStrings.round(t.round, t.rounds),
                      style: const TextStyle(fontSize: 18, color: muted),
                    ),
                  ),
                  Text(
                    '${TenkoviStrings.wind}: ${TenkoviStrings.windValue(t.wind)}',
                    key: const ValueKey('tenkovi-wind'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                TenkoviStrings.life(t.hp),
                style: const TextStyle(fontSize: 18, color: muted),
              ),
              const SizedBox(height: 8),
              _stepper(
                id: 'angle',
                label: TenkoviStrings.angle,
                value: TenkoviStrings.degrees(_angle),
                v: _angle,
                max: 180,
                set: (v) => setState(() => _angle = v),
              ),
              _stepper(
                id: 'power',
                label: TenkoviStrings.power,
                value: '$_power',
                v: _power,
                max: 100,
                set: (v) => setState(() => _power = v),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _chip(TenkoviShell.grenade),
                  _chip(TenkoviShell.heavy),
                  _chip(TenkoviShell.cluster),
                ],
              ),
              const SizedBox(height: 8),
              if (last != null)
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          TenkoviStrings.lastTime(last[0], last[1]),
                          key: const ValueKey('tenkovi-last'),
                          style: const TextStyle(fontSize: 17, color: muted),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('tenkovi-last-button'),
                        onPressed: () => setState(() {
                          _angle = last[0];
                          _power = last[1];
                        }),
                        child: const Text(
                          TenkoviStrings.lastTimeButton,
                          style: TextStyle(fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 48),
              const Spacer(),
              SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('tenkovi-fire'),
                  onPressed: _pressed
                      ? null
                      : () {
                          setState(() => _pressed = true);
                          widget.onFire(
                            _angle,
                            _power,
                            _left(_shell) ? _shell : TenkoviShell.grenade,
                          );
                        },
                  child: const Text(TenkoviStrings.fire),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
