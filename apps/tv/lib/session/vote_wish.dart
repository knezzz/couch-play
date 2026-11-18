/// "Idemo glasati": who wants to end the talking and vote (Uljez clues from the
/// end of round 1, the Vukodlak day). A wish is a state, not a toggle, so a
/// double send changes nothing. Only the wishes of the players counted (the
/// connected ones still in) count, so a wish stays set while its player is
/// away and counts again if they come back (build-core's reading).
class WishBox {
  final _on = <int>{};

  void set(int id, bool on) => on ? _on.add(id) : _on.remove(id);
  bool has(int id) => _on.contains(id);
  void clear() => _on.clear();

  int want(Iterable<int> counted) => counted.where(_on.contains).length;

  /// More than half of [n].
  static int needed(int n) => n ~/ 2 + 1;

  /// Nobody connected is never a majority.
  bool majority(List<int> counted) => counted.isNotEmpty && want(counted) >= needed(counted.length);
}
