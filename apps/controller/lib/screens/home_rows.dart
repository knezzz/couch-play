import 'package:core/core.dart';

import '../strings.dart';
import 'settings_copy.dart';

/// What a row opens instead of stepping.
enum HomeOpens { packs, roles }

/// One setting of the selected game, as the home shows it. The host steps it
/// with − / + (or ‹ ›); everybody reads [display]. [key] is the
/// `GameSettings` JSON key (or 'bots'), the same string the TV puts in
/// `LobbyChange.key`, so a change can be matched to its row and its old value
/// worded with [text].
class HomeRow {
  const HomeRow({
    required this.key,
    required this.label,
    required this.raw,
    required this.text,
    this.values = const [],
    this.wrap = false,
    this.messageFor,
    this.opens,
  });
  final String key, label;

  /// The current value as the settings JSON holds it.
  final Object? raw;

  /// Words a raw value (the current one, or an old one from a change).
  final String Function(Object? raw) text;

  /// The raw values − / + step through (empty: the row only opens something).
  final List<Object?> values;

  /// ‹ › choices wrap round; numbers stop at the ends.
  final bool wrap;

  /// The message that sets [values] `[i]`.
  final Message Function(int i)? messageFor;
  final HomeOpens? opens;

  String get display => text(raw);
  bool get adjustable => values.isNotEmpty && messageFor != null;
  bool get isNumber => !wrap && values.every((v) => v is int);
  int get index {
    final i = values.indexOf(raw);
    return i < 0 ? 0 : i;
  }

  int? get prev {
    if (!adjustable) return null;
    if (wrap) return (index + values.length - 1) % values.length;
    return index > 0 ? index - 1 : null;
  }

  int? get next {
    if (!adjustable) return null;
    if (wrap) return (index + 1) % values.length;
    return index < values.length - 1 ? index + 1 : null;
  }
}

List<int> _range(int from, int to, int step) => [
  for (var v = from; v <= to; v += step) v,
];

List<PackInfo> packsOf(GameKind k, LobbyState l) => switch (k) {
  GameKind.quiz => l.packs,
  GameKind.uljez => l.uljezPacks,
  GameKind.objasni => l.objasniPacks,
  GameKind.koliko => l.kolikoPacks,
  GameKind.blef => l.blefPacks,
  GameKind.tkobi => l.tkobiPacks,
  _ => const [],
};

String _offKey(GameKind k) => '${k.name}OffPacks';

/// The settings rows of [k] in the order of the board.
List<HomeRow> homeRows(GameKind k, LobbyState l) {
  final s = l.settings;
  final json = s.toJson();
  GameSettings set(GameSettings Function(GameSettings s) f) => f(s);

  HomeRow number(
    String key,
    String label,
    List<int> values,
    GameSettings Function(int v) make, {
    String Function(int)? fmt,
  }) => HomeRow(
    key: key,
    label: label,
    raw: json[key],
    text: (r) => fmt == null ? '$r' : fmt(r as int),
    values: values,
    messageFor: (i) => SetSettings(make(values[i])),
  );

  HomeRow packs() {
    final all = packsOf(k, l);
    return HomeRow(
      key: _offKey(k),
      label: k == GameKind.uljez || k == GameKind.objasni
          ? Strings.wordPacks
          : Strings.quizPacks,
      raw: json[_offKey(k)],
      text: (r) {
        final off = {for (final id in (r as List? ?? const [])) '$id'};
        return Strings.packCount(
          all.where((p) => !off.contains(p.id)).length,
          all.length,
        );
      },
      opens: HomeOpens.packs,
    );
  }

  final bots = l.players.where((p) => p.bot).length;
  final humans = l.players.length - bots;
  HomeRow botsRow() => HomeRow(
    key: 'bots',
    label: Strings.bots,
    raw: bots,
    text: (r) => '$r',
    values: _range(0, 8 - humans, 1),
    messageFor: (i) => SetBots(i),
  );

  return switch (k) {
    GameKind.curve => [
      HomeRow(
        key: 'curveMode',
        label: Strings.curveModeLabel,
        raw: json['curveMode'],
        text: (r) => Strings.curveMode(CurveMode.values.byName('$r')),
        values: [for (final m in CurveMode.values) m.name],
        wrap: true,
        messageFor: (i) =>
            SetSettings(copySettings(s, curveMode: CurveMode.values[i])),
      ),
      number(
        'curveCountdown',
        Strings.curveCountdown,
        _range(1, 10, 1),
        (v) => copySettings(s, curveCountdown: v),
        fmt: Strings.seconds,
      ),
      botsRow(),
    ],
    GameKind.quiz => [
      packs(),
      number(
        'quizQuestions',
        Strings.quizQuestions,
        _range(5, 30, 5),
        (v) => copySettings(s, quizQuestions: v),
      ),
      number(
        'quizSeconds',
        Strings.quizSeconds,
        _range(10, 60, 5),
        (v) => copySettings(s, quizSeconds: v),
        fmt: Strings.seconds,
      ),
      number(
        'revealSeconds',
        Strings.revealSeconds,
        _range(2, 15, 1),
        (v) => copySettings(s, revealSeconds: v),
        fmt: Strings.seconds,
      ),
      botsRow(),
    ],
    GameKind.vukodlak => [
      HomeRow(
        key: 'wolfRoles',
        label: Strings.rolesInGame,
        raw: json['wolfRoles'],
        text: (r) => Strings.rolesCount((r as List).length),
        opens: HomeOpens.roles,
      ),
      HomeRow(
        key: 'wolfHideRoles',
        label: Strings.hiddenRoles,
        raw: s.wolfHideRoles,
        text: (r) => r == true ? Strings.yes : Strings.no,
        values: const [false, true],
        wrap: true,
        messageFor: (i) =>
            SetSettings(set((s) => copySettings(s, wolfHideRoles: i == 1))),
      ),
    ],
    GameKind.uljez => [
      packs(),
      number(
        'uljezImpostors',
        Strings.impostorCount,
        // Two impostors only count from 7 players (the TV ignores more).
        l.players.length >= 7 ? const [1, 2] : const [1],
        (v) => copySettings(s, uljezImpostors: v),
      ),
    ],
    GameKind.objasni => [
      packs(),
      number(
        'objasniSeconds',
        Strings.turnSeconds,
        const [45, 60, 90],
        (v) => copySettings(s, objasniSeconds: v),
        fmt: Strings.seconds,
      ),
      number('objasniTarget', Strings.targetPoints, const [
        20,
        30,
        50,
      ], (v) => copySettings(s, objasniTarget: v)),
    ],
    GameKind.koliko => [
      packs(),
      number(
        'kolikoSeconds',
        Strings.quizSeconds,
        const [20, 30, 45],
        (v) => copySettings(s, kolikoSeconds: v),
        fmt: Strings.seconds,
      ),
      number('kolikoQuestions', Strings.quizQuestions, const [
        5,
        10,
        15,
      ], (v) => copySettings(s, kolikoQuestions: v)),
    ],
    GameKind.blef => [
      packs(),
      number('blefQuestions', Strings.quizQuestions, const [
        5,
        7,
        10,
      ], (v) => copySettings(s, blefQuestions: v)),
    ],
    GameKind.tkobi => [
      packs(),
      number('tkobiPrompts', Strings.quizQuestions, const [
        5,
        10,
        15,
      ], (v) => copySettings(s, tkobiPrompts: v)),
    ],
  };
}

/// Words one [LobbyChange] value for the row it belongs to; the raw value as
/// text when no row has that key (a newer TV).
String changeValue(LobbyChange c, Object? raw, LobbyState l) {
  final k = c.game;
  if (k == null || c.key == null) return '$raw';
  for (final r in homeRows(k, l)) {
    if (r.key == c.key) return r.text(raw);
  }
  return '$raw';
}

/// The row of [l]'s selected game that `changed` points at, or null.
String? changedKey(LobbyState l) {
  final c = l.changed;
  if (c == null || c.kind != ChangeKind.setting) return null;
  if (c.game != l.selected) return null;
  return c.key;
}
