import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

/// Team colours: one source in core, shared with the TV.
final teamColors = objasniTeamColors;

/// A player in a team list.
class TeamMember {
  const TeamMember(this.id, this.name, this.character, this.colorIndex);
  final int id;
  final String name, character;
  final int colorIndex;
}

/// The setup, after the host pressed Igraj: the two teams. The host can draw
/// again (Promiješaj) and start; the others wait.
class ObjasniSetupScreen extends StatelessWidget {
  const ObjasniSetupScreen({
    super.key,
    required this.teams,
    required this.myTeam,
    required this.isHost,
    required this.hostName,
    required this.onReshuffle,
    required this.onGo,
  });
  final List<List<TeamMember>> teams;
  final int myTeam;
  final bool isHost;
  final String? hostName;
  final VoidCallback onReshuffle, onGo;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.teamsTitle,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              Strings.yourTeam(myTeam),
              key: const ValueKey('your-team'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: teamColors[myTeam % 2],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [for (var t = 0; t < teams.length; t++) _team(t)],
              ),
            ),
            if (isHost) ...[
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  key: const ValueKey('reshuffle'),
                  onPressed: onReshuffle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: const BorderSide(color: raised, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text(Strings.reshuffle),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: FilledButton(
                  key: const ValueKey('objasni-go'),
                  onPressed: onGo,
                  child: const Text(Strings.play),
                ),
              ),
            ] else
              Text(
                Strings.waitingForHost(hostName),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: muted),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _team(int t) => Container(
    key: ValueKey('team-$t'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: t == myTeam ? teamColors[t % 2] : Colors.transparent,
        width: 3,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.teamName(t),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: teamColors[t % 2],
          ),
        ),
        const SizedBox(height: 6),
        for (final m in teams[t])
          SizedBox(
            height: 52,
            child: Row(
              children: [
                CharacterFace(
                  m.character.isEmpty ? characterIds.first : m.character,
                  40,
                  playerColors[m.colorIndex % playerColors.length],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A turn, for this phone's role. [word] is null for the explainer's own team.
class ObjasniTurnScreen extends StatefulWidget {
  const ObjasniTurnScreen({
    super.key,
    required this.stage,
    required this.role,
    required this.team,
    required this.explainerName,
    required this.word,
    required this.seconds,
    required this.scores,
    required this.onGo,
    required this.onAct,
  });
  final ObjasniStage stage;
  final ObjasniRole role;
  final int team, seconds;
  final String explainerName;
  final String? word;
  final List<int> scores;
  final VoidCallback onGo;
  final void Function(ObjasniAct) onAct;

  @override
  State<ObjasniTurnScreen> createState() => _TurnState();
}

class _TurnState extends State<ObjasniTurnScreen> {
  late int _left = widget.seconds;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0 && widget.stage == ObjasniStage.play) {
        setState(() => _left--);
      }
    });
  }

  @override
  void didUpdateWidget(ObjasniTurnScreen old) {
    super.didUpdateWidget(old);
    // Every message restates the time left: take it, do not drift.
    if (old.seconds != widget.seconds || old.stage != widget.stage) {
      _left = widget.seconds;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = teamColors[widget.team % 2];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _scores(),
              const SizedBox(height: 12),
              Expanded(child: _body(color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scores() => Row(
    key: const ValueKey('scores'),
    children: [
      for (var t = 0; t < 2; t++)
        Expanded(
          child: Text(
            '${Strings.teamName(t)} · ${widget.scores.length > t ? widget.scores[t] : 0}',
            textAlign: t == 0 ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: teamColors[t],
            ),
          ),
        ),
    ],
  );

  Widget _clock() => Text(
    Strings.minutes(_left),
    key: const ValueKey('turn-clock'),
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
  );

  Widget _body(Color color) {
    switch (widget.stage) {
      case ObjasniStage.ready:
        final explaining = widget.role == ObjasniRole.explain;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              explaining ? Strings.ready : Strings.onTurn(widget.explainerName),
              key: const ValueKey('ready-title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            if (!explaining) ...[
              const SizedBox(height: 8),
              const Text(
                Strings.ready,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, color: muted),
              ),
            ],
            const SizedBox(height: 32),
            if (explaining)
              SizedBox(
                height: 88,
                child: FilledButton(
                  key: const ValueKey('kreni'),
                  onPressed: widget.onGo,
                  child: const Text(Strings.go),
                ),
              ),
          ],
        );
      case ObjasniStage.summary:
        return const Center(
          child: Text(
            Strings.turnOver,
            key: ValueKey('turn-over'),
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
          ),
        );
      case ObjasniStage.play:
        return switch (widget.role) {
          ObjasniRole.guess => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _clock(),
              const SizedBox(height: 24),
              const Text(
                Strings.guessAloud,
                key: ValueKey('guess-aloud'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                Strings.explainsNow(widget.explainerName),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: muted),
              ),
            ],
          ),
          ObjasniRole.explain => _wordCard(Strings.explainTitle, color, [
            _button(
              'act-skip',
              Strings.skip,
              raised,
              textColor,
              ObjasniAct.skip,
              flex: 1,
            ),
            const SizedBox(width: 12),
            _button(
              'act-correct',
              Strings.right,
              const Color(0xFF2ECC71),
              ink,
              ObjasniAct.correct,
              flex: 2,
            ),
          ]),
          ObjasniRole.watch => _wordCard(Strings.watchTitle, color, [
            _button(
              'act-foul',
              Strings.foul,
              const Color(0xFFFF4D4D),
              ink,
              ObjasniAct.foul,
              flex: 1,
            ),
          ]),
        };
    }
  }

  Widget _wordCard(String title, Color color, List<Widget> buttons) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _clock(),
      const SizedBox(height: 8),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, color: muted),
      ),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Text(
                widget.word ?? '',
                key: const ValueKey('word'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: 96, child: Row(children: buttons)),
    ],
  );

  Widget _button(
    String key,
    String label,
    Color bg,
    Color fg,
    ObjasniAct act, {
    required int flex,
  }) => Expanded(
    flex: flex,
    child: FilledButton(
      key: ValueKey(key),
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(96),
      ),
      onPressed: () => widget.onAct(act),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    ),
  );
}

