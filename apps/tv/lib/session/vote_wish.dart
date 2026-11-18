/// "Idemo glasati": who wants to end the talking and vote (Uljez clues from the
/// end of round 1, the Vukodlak day). A wish is a state, not a toggle, so a
/// double send changes nothing. The players counted are everyone still in the
/// game, connected or not (a locked phone drops its socket), so a wish stays
/// counted while its player's phone sleeps. Only a kick removes a player.
class WishBox {
  final _on = <int>{};

  void set(int id, bool on) => on ? _on.add(id) : _on.remove(id);
  bool has(int id) => _on.contains(id);
  void clear() => _on.clear();

  int want(Iterable<int> counted) => counted.where(_on.contains).length;

  /// More than half of [n].
  static int needed(int n) => n ~/ 2 + 1;

  /// An empty room is never a majority.
  bool majority(List<int> counted) => counted.isNotEmpty && want(counted) >= needed(counted.length);
}
