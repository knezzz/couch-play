/// Every sound the TV plays. Phones stay silent.
enum Sound {
  join,
  countdownBeep,
  countdownGo,
  pickup,
  crash,
  roundWin,
  matchWin,
  quizStart,
  tick,
  right,
  wrong,
  fanfare,
  menuMove,
  menuConfirm,
  quizTick,
  nightAmbience,
  howl,
  rooster,
  voteBell,
  drum,
  tickUrgent,
  heartbeat,
  timeUp,
  sumoDash,
  sumoBump,
  sumoFall,
  cannon,
  blast,
  bigBlast,
}

/// The session calls this on each event. Fire and forget: it must never block
/// or throw (the Curve loop calls it 60 times a second).
abstract interface class Sfx {
  void play(Sound sound);
}

/// Used until a real player is ready, and in tests.
class SilentSfx implements Sfx {
  const SilentSfx();
  @override
  void play(Sound sound) {}
}
