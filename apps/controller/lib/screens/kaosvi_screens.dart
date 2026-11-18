import 'package:core/core.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'settings_widgets.dart';

/// One answer group on the host's merge screen: an id and the text, never who
/// wrote it.
class MergeGroup {
  const MergeGroup(this.id, this.text);
  final int id;
  final String text;
}

/// The host's merge screen: the groups as answer chips. Tap one, tap another:
/// the two are asked to merge (the TV sends the new groups). Gotovo ends it.
class KaosviMergeScreen extends StatefulWidget {
  const KaosviMergeScreen({
    super.key,
    required this.seconds,
    required this.groups,
    required this.onMerge,
    required this.onDone,
  });
  final int seconds;
  final List<MergeGroup> groups;
  final void Function(int a, int b) onMerge;
  final VoidCallback onDone;

  @override
  State<KaosviMergeScreen> createState() => _MergeState();
}

class _MergeState extends State<KaosviMergeScreen> {
  late int _left = widget.seconds;
  int? _first;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void didUpdateWidget(KaosviMergeScreen old) {
    super.didUpdateWidget(old);
    // The TV restates the groups after every merge: a pick of a group that is
    // gone means nothing, and the clock follows the TV.
    if (_first != null && !widget.groups.any((g) => g.id == _first)) {
      _first = null;
    }
    if (old.seconds != widget.seconds) _left = widget.seconds;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _tap(MergeGroup g) {
    if (_first == null) {
      setState(() => _first = g.id);
    } else if (_first == g.id) {
      setState(() => _first = null);
    } else {
      final a = _first!;
      setState(() => _first = null);
      widget.onMerge(a, g.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    Strings.mergeTitle,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  Strings.minutes(_left),
                  key: const ValueKey('merge-clock'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              Strings.mergeHint,
              style: TextStyle(fontSize: 18, color: muted, height: 1.3),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in widget.groups)
                      Material(
                        color: _first == g.id ? accent : surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          key: ValueKey('group-${g.id}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _tap(g),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 56,
                              minWidth: 56,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              g.text,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _first == g.id ? ink : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: FilledButton(
                key: const ValueKey('merge-done'),
                onPressed: widget.onDone,
                child: const Text(Strings.done),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What everyone but the host sees while the host merges.
class KaosviWaitScreen extends StatelessWidget {
  const KaosviWaitScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            Strings.mergeWait,
            key: ValueKey('merge-wait'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: muted, height: 1.3),
          ),
        ),
      ),
    ),
  );
}

/// This phone's own result for the question.
class KaosviResultScreen extends StatelessWidget {
  const KaosviResultScreen({
    super.key,
    required this.answer,
    required this.size,
    required this.points,
    required this.total,
    required this.largest,
    required this.lone,
  });
  final String? answer;
  final int size, points, total;
  final bool largest, lone;

  @override
  Widget build(BuildContext context) {
    final headline = answer == null
        ? ''
        : largest
        ? Strings.largestGroup
        : lone
        ? Strings.loneAnswer
        : '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                Strings.yourAnswer,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: muted),
              ),
              Text(
                answer ?? Strings.noAnswer,
                key: const ValueKey('own-answer'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (answer != null)
                Text(
                  Strings.groupSize(size),
                  key: const ValueKey('group-size'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, color: muted),
                ),
              const SizedBox(height: 20),
              if (headline.isNotEmpty)
                Text(
                  headline,
                  key: const ValueKey('headline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              Text(
                Strings.signedPoints(points),
                key: const ValueKey('points'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                Strings.totalScore(total),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The host's settings for Kao svi: questions, target score, pack.
class KaosviSettingsView extends StatelessWidget {
  const KaosviSettingsView({
    super.key,
    required this.questions,
    required this.target,
    required this.packs,
    required this.ticked,
    required this.onQuestions,
    required this.onTarget,
    required this.onTogglePack,
  });
  final int questions, target;
  final List<PackInfo> packs;
  final Set<String> ticked;
  final void Function(int) onQuestions, onTarget;
  final void Function(String id) onTogglePack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ChoiceRow(
        label: Strings.quizQuestions,
        keyPrefix: 'kaosvi-questions',
        values: const [8, 12, 16],
        value: questions,
        text: (n) => '$n',
        onPick: onQuestions,
      ),
      const SizedBox(height: 8),
      ChoiceRow(
        label: Strings.targetScore,
        keyPrefix: 'kaosvi-target',
        values: const [5, 8, 10],
        value: target,
        text: (n) => '$n',
        onPick: onTarget,
      ),
      const SizedBox(height: 8),
      PackChecklist(
        key: const ValueKey('kaosvi-packs'),
        title: Strings.packsTitle,
        packs: packs,
        ticked: ticked,
        onToggle: onTogglePack,
      ),
    ],
  );
}
