import 'dart:math';

import 'package:core/core.dart';

import '../session/wolf_text.dart';
import 'story_hr.dart';

/// Events the session adds to mark a beat (night falls, day, vote): a beat
/// starts at one of these.
const _markers = {'firstNight', 'nightFalls', 'dayStarts', 'voteStarts'};

/// What the square says now: the last marker on its own, or the events that
/// came after the last marker (a morning with two deaths reads both).
List<WolfEvent> currentBeat(List<WolfEvent> story) {
  if (story.isEmpty) return const [];
  if (_markers.contains(story.last.key)) return [story.last];
  var from = story.length - 1;
  while (from > 0 && !_markers.contains(story[from - 1].key)) {
    from--;
  }
  return story.sublist(from);
}

/// One Croatian line for [e], picked at random from [storyHr]. Plain string
/// replace; an event that carries a role uses its `Role` twin (the engine only
/// sends a role when it may be shown). An unknown key gives ''.
String wolfStoryLine(WolfEvent e, String Function(int id) nameOf, Random random) {
  var key = e.key;
  if (key == 'gameOver') {
    final w = '${e.args['winner'] ?? ''}';
    key = 'gameOver${w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)}';
  }
  final role = e.args['role'];
  if (role != null && storyHr.containsKey('${key}Role')) key = '${key}Role';
  final lines = storyHr[key];
  if (lines == null || lines.isEmpty) return '';
  var s = lines[random.nextInt(lines.length)];
  String name(Object? id) => id is int ? nameOf(id) : '';
  // The hunter's shot: {name} is the hunter, {name2} the one hit. Otherwise {name} is the player.
  final first = e.args['hunter'] ?? e.args['player'];
  final second = e.args['hunter'] != null ? e.args['player'] : e.args['partner'];
  s = s.replaceAll('{name}', name(first)).replaceAll('{name2}', name(second));
  if (role is String) s = s.replaceAll('{role}', WolfText.roleNames[WolfRole.byName(role)] ?? '');
  final count = e.args['count'];
  if (count != null) s = s.replaceAll('{count}', '$count');
  return s;
}
