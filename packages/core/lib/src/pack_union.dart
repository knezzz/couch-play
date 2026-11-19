import 'dart:typed_data';
import 'blef.dart';
import 'koliko.dart';
import 'objasni.dart';
import 'quiz_pack.dart';
import 'tkobi.dart';
import 'uljez.dart';

/// Packs are multi-select: a game draws from the union of the ticked packs.
/// Each function merges the packs into one pack of the same kind, in the order
/// given, dropping repeats (same text ignoring case, spacing and the unordered
/// order of a word pair): the first copy wins. One pack comes back unchanged
/// (same id, same title). [title] names a merged pack on the TV.

String _fold(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

List<T> _unique<T>(Iterable<List<T>> lists, String Function(T) key) {
  final seen = <String>{};
  return [
    for (final l in lists)
      for (final e in l)
        if (seen.add(key(e))) e
  ];
}

QuizPack unionQuiz(String id, String title, List<QuizPack> packs) {
  if (packs.length == 1) return packs.single;
  // Pictures are named by their path in each zip, so two packs can use the same
  // name for different files: a merged pack names them "<pack id>/<name>".
  final images = <String, Uint8List>{};
  final lists = <List<PackQuestion>>[];
  for (final p in packs) {
    lists.add([
      for (final q in p.questions)
        q.image == null || !p.images.containsKey(q.image)
            ? q
            : PackQuestion(q.q, '${p.id}/${q.image}', q.choices, q.answer)
    ]);
    for (final e in p.images.entries) {
      images['${p.id}/${e.key}'] = e.value;
    }
  }
  // A repeat is the same question with the same right answer and the same
  // picture. The text alone is not enough: "Koji je ovo grad?" is eleven
  // different picture questions.
  String key(PackQuestion q) {
    final pic = q.image == null ? '' : '${images[q.image]?.length}:${Object.hashAll(images[q.image] ?? const <int>[])}';
    return '${_fold(q.q)}\u0000${_fold(q.choices[q.answer])}\u0000$pic';
  }

  final qs = _unique<PackQuestion>(lists, key);
  final used = {for (final q in qs) if (q.image != null) q.image!};
  return QuizPack(id, title, qs, {for (final e in images.entries) if (used.contains(e.key)) e.key: e.value});
}

UljezPack unionUljez(String id, String title, List<UljezPack> packs) {
  if (packs.length == 1) return packs.single;
  String key(WordPair p) {
    final w = [_fold(p.a), _fold(p.b)]..sort();
    return w.join('\u0000');
  }

  // Each pair remembers its pack: the guess draws its decoys from there.
  return UljezPack(id, title, _unique<WordPair>([
    for (final p in packs) [for (final w in p.pairs) WordPair(w.a, w.b, source: p.id)]
  ], key));
}

ObjasniPack unionObjasni(String id, String title, List<ObjasniPack> packs) =>
    packs.length == 1 ? packs.single : ObjasniPack(id, title, _unique<String>([for (final p in packs) p.words], _fold));

KolikoPack unionKoliko(String id, String title, List<KolikoPack> packs) => packs.length == 1
    ? packs.single
    : KolikoPack(id, title, _unique<KolikoQuestion>([for (final p in packs) p.questions], (q) => _fold(q.q)));

BlefPack unionBlef(String id, String title, List<BlefPack> packs) => packs.length == 1
    ? packs.single
    : BlefPack(id, title, _unique<BlefQuestion>([for (final p in packs) p.questions], (q) => _fold(q.q)));

TkobiPack unionTkobi(String id, String title, List<TkobiPack> packs) =>
    packs.length == 1 ? packs.single : TkobiPack(id, title, _unique<String>([for (final p in packs) p.prompts], _fold));
