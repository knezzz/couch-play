import 'package:core/core.dart';

/// The settings with some fields changed, every other field kept. All the
/// game settings live in one object the TV owns, so every change must send
/// the whole of it; a hand-written constructor call drops new fields.
GameSettings copySettings(
  GameSettings s, {
  int? quizSeconds,
  int? quizQuestions,
  int? revealSeconds,
  int? curveCountdown,
  CurveMode? curveMode,
  Set<WolfRole>? wolfRoles,
  bool? wolfHideRoles,
  int? uljezImpostors,
  int? objasniSeconds,
  int? objasniTarget,
  int? kolikoSeconds,
  int? kolikoQuestions,
  int? blefQuestions,
  int? tkobiPrompts,
  // Replace one game's switched-off packs. The old single pack ids are never
  // sent (null): the TV would turn one into 'only that pack'.
  GameKind? offFor,
  Set<String>? off,
}) => GameSettings(
  quizSeconds: quizSeconds ?? s.quizSeconds,
  quizQuestions: quizQuestions ?? s.quizQuestions,
  revealSeconds: revealSeconds ?? s.revealSeconds,
  curveCountdown: curveCountdown ?? s.curveCountdown,
  curveMode: curveMode ?? s.curveMode,
  wolfRoles: wolfRoles ?? s.wolfRoles,
  wolfHideRoles: wolfHideRoles ?? s.wolfHideRoles,
  uljezImpostors: uljezImpostors ?? s.uljezImpostors,
  objasniSeconds: objasniSeconds ?? s.objasniSeconds,
  objasniTarget: objasniTarget ?? s.objasniTarget,
  kolikoSeconds: kolikoSeconds ?? s.kolikoSeconds,
  kolikoQuestions: kolikoQuestions ?? s.kolikoQuestions,
  blefQuestions: blefQuestions ?? s.blefQuestions,
  tkobiPrompts: tkobiPrompts ?? s.tkobiPrompts,
  quizOffPacks: offFor == GameKind.quiz ? off! : s.quizOffPacks,
  uljezOffPacks: offFor == GameKind.uljez ? off! : s.uljezOffPacks,
  objasniOffPacks: offFor == GameKind.objasni ? off! : s.objasniOffPacks,
  kolikoOffPacks: offFor == GameKind.koliko ? off! : s.kolikoOffPacks,
  blefOffPacks: offFor == GameKind.blef ? off! : s.blefOffPacks,
  tkobiOffPacks: offFor == GameKind.tkobi ? off! : s.tkobiOffPacks,
);
