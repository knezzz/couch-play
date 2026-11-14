import 'package:characters/characters.dart';

const maxNameLength = 16;

/// Trims, collapses runs of whitespace to one space and cuts to 16
/// user-perceived characters (an emoji counts as one). Null if nothing is left.
String? cleanName(String raw) {
  final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
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
