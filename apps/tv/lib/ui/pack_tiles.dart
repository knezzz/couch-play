import 'package:core/core.dart';

import '../session/session.dart';
import 'home_screen.dart';

/// The packs of [game] for the TV pack screen, in lobby order, each on or off as the host has set it.
List<PackTile> packTiles(Session s, GameKind game) {
  final on = s.tickedPackIds(game).toSet();
  PackTile t(String id, String title, int count, [int pictures = 0]) => (id: id, title: title, count: count, pictures: pictures, on: on.contains(id));
  return switch (game) {
    GameKind.quiz => [
        for (final i in s.packStore?.infos ?? const <PackInfo>[])
          t(i.id, i.title, i.questionCount, i.pictures ? (s.packStore!.get(i.id)?.questions.where((q) => q.image != null).length ?? 0) : 0),
      ],
    GameKind.uljez => [for (final p in s.uljezPacks) t(p.id, p.title, p.pairs.length)],
    GameKind.objasni => [for (final p in s.objasniPacks) t(p.id, p.title, p.words.length)],
    GameKind.koliko => [for (final p in s.kolikoPacks) t(p.id, p.title, p.questions.length, p.questions.where((q) => q.image != null).length)],
    GameKind.blef => [for (final p in s.blefPacks) t(p.id, p.title, p.questions.length)],
    GameKind.tkobi => [for (final p in s.tkobiPacks) t(p.id, p.title, p.prompts.length)],
    _ => const [],
  };
}
