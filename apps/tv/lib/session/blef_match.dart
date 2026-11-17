import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';

enum BlefStageTv { write, pick, reveal, over }

/// An entry as the TV may show it at the reveal.
class BlefShown {
  const BlefShown(this.text, this.isTruth, this.writers, this.pickers);
  final String text;
  final bool isTruth;
  final List<int> writers;
  final List<int> pickers;
}

/// One game of Blef on the TV: asks, collects the fakes, lists them, collects
/// the picks and reveals entry by entry.
///
/// PRIVACY. Nobody sees a fake before the list: during writing the TV knows
/// only WHO has sent ([sent]); the list the phones get ([BlefList]) holds the
/// texts without writers and without any mark of the true one, and a phone's
/// own fake is left out. The truth and the writers become visible only entry
/// by entry at the reveal ([shown]).
class BlefMatch {
  BlefMatch({
    required this.ids,
    required this.pack,
    required this.settings,
    required this.send,
    required this.clock,
    required this.random,
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
  });

  final List<int> ids;
  final BlefPack pack;
  final GameSettings settings;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(Map<int, int> scores)? onOver;

  static const writeTime = Duration(seconds: 60);
  static const pickTime = Duration(seconds: 20);
  static const stepTime = Duration(seconds: 4);

  /// After the LAST entry (the true answer) all rows and the points stay up this long.
  static const finalHold = Duration(seconds: 8);

  /// The rules. Holds the true answer and every fake: not for the TV to show from.
  @visibleForTesting
  late BlefGame game;
  BlefStageTv stage = BlefStageTv.write;
  Timer? _tick, _timer;
  var _left = 0;
  var _step = -1; // the reveal step shown; -1 before the first
  Duration _stageEnd = Duration.zero;

  int get number => game.number;
  int get total => game.total;
  String get q => game.current.q;
  int get secondsLeft => _left;
  Set<int> get sent => game.sent;
  Set<int> get picked => game.picked;
  Map<int, int> get totals => Map.of(game.totals);
  int get revealStep => _step;

  /// The list in the picking phase: texts only, shuffled, nothing marked.
  List<String> get listTexts => stage == BlefStageTv.pick ? [for (final e in game.entries) e.text] : const [];

  /// At the reveal: the entries revealed so far, in the order they were shown.
  List<BlefShown> get shown {
    if (stage != BlefStageTv.reveal) return const [];
    final order = game.lastReveal!.order;
    return [
      for (var k = 0; k <= _step && k < order.length; k++)
        BlefShown(game.entries[order[k]].text, game.entries[order[k]].isTruth, List.of(game.entries[order[k]].writers),
            List.of(game.entries[order[k]].pickers)),
    ];
  }

  /// Points this question, once the last entry has been shown.
  Map<int, int>? get questionPoints => stage == BlefStageTv.reveal && _step >= game.lastReveal!.order.length - 1
      ? Map.of(game.lastReveal!.points)
      : null;

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    game = BlefGame(ids, pack, questions: settings.blefQuestions, random: random);
    _write();
  }

  void dispose() {
    _tick?.cancel();
    _timer?.cancel();
  }

  // ---- writing ----

  BlefWrite _writeMsg(int id) => BlefWrite(
      number: game.number, total: game.total, seconds: _left, q: game.current.q, sent: game.sentTextOf(id));

  void _write() {
    stage = BlefStageTv.write;
    _step = -1;
    _left = writeTime.inSeconds;
    sfx.play(Sound.quizStart);
    for (final id in ids) {
      send(id, _writeMsg(id));
    }
    _runClock(_endWriting);
    notify?.call();
  }

  void _runClock(void Function() done) {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _left--;
      if (_left > 0) sfx.play(_left <= 5 ? Sound.tick : Sound.quizTick);
      if (_left <= 0) {
        _tick?.cancel();
        done();
      } else {
        notify?.call();
      }
    });
  }

  void onFake(int id, BlefFake m) {
    if (stage != BlefStageTv.write) return;
    final r = game.submitFake(id, m.text);
    switch (r) {
      case FakeResult.ok:
        send(id, _writeMsg(id)); // the ack: sent is now set
        notify?.call();
        if (game.allSent) _endWriting();
      case FakeResult.truth:
        send(id, const ErrorMsg(BlefText.truth));
      case FakeResult.empty:
        send(id, const ErrorMsg(BlefText.empty));
      case FakeResult.tooLong:
        send(id, const ErrorMsg(BlefText.tooLong));
      case FakeResult.alreadySent:
      case FakeResult.closed:
        break;
    }
  }

  void _endWriting() {
    if (stage != BlefStageTv.write) return;
    _tick?.cancel();
    game.closeWriting();
    if (game.phase == BlefPhase.reveal) return _startReveal();
    stage = BlefStageTv.pick;
    _left = pickTime.inSeconds;
    for (final id in ids) {
      send(id, _listMsg(id));
    }
    _runClock(_endPicking);
    notify?.call();
  }

  // ---- picking ----

  BlefList _listMsg(int id) {
    final opts = game.optionsFor(id);
    return BlefList(
        seconds: _left,
        options: [for (final i in opts) game.entries[i].text],
        ids: opts,
        picked: game.pickOf(id));
  }

  void onPick(int id, BlefPick m) {
    if (stage != BlefStageTv.pick) return;
    if (!game.pick(id, m.index)) return;
    notify?.call();
    if (game.allPicked) _endPicking();
  }

  void _endPicking() {
    if (stage != BlefStageTv.pick) return;
    _tick?.cancel();
    game.reveal();
    _startReveal();
  }

  // ---- reveal, entry by entry ----

  void _startReveal() {
    stage = BlefStageTv.reveal;
    _step = -1;
    _nextStep();
  }

  void _nextStep() {
    final r = game.lastReveal!;
    _step++;
    if (_step < r.order.length) {
      final e = game.entries[r.order[_step]];
      sfx.play(e.isTruth ? Sound.right : Sound.menuMove);
      final last = _step == r.order.length - 1;
      final hold = last ? finalHold : stepTime;
      _stageEnd = clock() + hold;
      _timer?.cancel();
      _timer = Timer(hold, _nextStep);
      if (last) _sendResults();
      notify?.call();
    } else {
      _next();
    }
  }

  /// The last entry is up: each phone gets its own points.
  void _sendResults() {
    final r = game.lastReveal!;
    final truth = game.entries.firstWhere((e) => e.isTruth);
    for (final id in ids) {
      final fooled = game.entries.where((e) => !e.isTruth && e.writers.contains(id)).fold<int>(0, (a, e) => a + e.pickers.length);
      send(id, BlefResult(points: r.points[id] ?? 0, total: game.totals[id]!, foundTruth: truth.pickers.contains(id), fooled: fooled));
    }
  }

  void _next() {
    game.next();
    if (game.phase == BlefPhase.over) return _finish();
    _write();
  }

  void _finish() {
    _tick?.cancel();
    _timer?.cancel();
    stage = BlefStageTv.over;
    sfx.play(Sound.fanfare);
    notify?.call();
    onOver?.call(game.sessionScores);
  }

  // ---- dropping out, reload ----

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == BlefStageTv.over) return;
    game.setAway(id, away);
    if (stage == BlefStageTv.write && game.allSent && game.sent.isNotEmpty) {
      _endWriting();
    } else if (stage == BlefStageTv.pick && game.allPicked) {
      _endPicking();
    }
    notify?.call();
  }

  void rejoin(int id) {
    if (!ids.contains(id) || stage == BlefStageTv.over) return;
    switch (stage) {
      case BlefStageTv.write:
        send(id, _writeMsg(id));
      case BlefStageTv.pick:
        send(id, _listMsg(id));
      case BlefStageTv.reveal:
        if (questionPoints != null) {
          final truth = game.entries.firstWhere((e) => e.isTruth);
          final fooled = game.entries.where((e) => !e.isTruth && e.writers.contains(id)).fold<int>(0, (a, e) => a + e.pickers.length);
          send(id, BlefResult(points: game.lastReveal!.points[id] ?? 0, total: game.totals[id]!, foundTruth: truth.pickers.contains(id), fooled: fooled));
        }
      case BlefStageTv.over:
        break;
    }
  }
}

/// Croatian lines Blef sends to a phone.
class BlefText {
  static const truth = 'To je točan odgovor! Smisli laž.';
  static const empty = 'Upiši svoju laž.';
  static const tooLong = 'Najviše 40 znakova.';
}
