import 'package:characters/characters.dart';

const maxNameLength = 16;

final _lineBreaks = RegExp(r'[\u0009-\u000D\u0085]');

/// Control characters, zero-width characters, and bidi controls and marks: they
/// draw nothing (or flip the text), so a name made of them would look empty or
/// scramble the TV. U+200D (joiner) stays because emoji sequences need it, and
/// U+200C stays because some scripts need it.
final _invisible = RegExp(
    r'[\p{Cc}\u200B\u200E\u200F\u2060\uFEFF\u202A-\u202E\u2066-\u2069]',
    unicode: true);

/// Trims, collapses runs of whitespace to one space and cuts to 16
/// user-perceived characters (an emoji counts as one). Null if nothing is left.
String? cleanName(String raw) {
  final visible = raw
      // Tabs and newlines separate words, so they become spaces first.
      .replaceAll(_lineBreaks, ' ')
      .replaceAll(_invisible, '');
  final words = visible.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final collapsed = words.join(' ');
  if (collapsed.isEmpty) return null;
  return collapsed.characters.take(maxNameLength).toString();
}

/// [name], or "name 2", "name 3"... if it is already in [taken] (ignoring case).
String dedupeName(String name, Iterable<String> taken) {
  final used = {for (final t in taken) t.toLowerCase()};
  if (!used.contains(name.toLowerCase())) return name;
  for (var n = 2;; n++) {
    final candidate = '$name $n';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}
