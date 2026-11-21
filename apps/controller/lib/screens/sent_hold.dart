import 'package:flutter/material.dart';

import '../strings.dart';
import 'wolf_screens.dart';

/// What a phone shows once an answer is sent: the Vukodlak hold-to-see card
/// ([RoleHoldScreen]). The answer is on screen only while a finger is down, so
/// a neighbour cannot read it off the sofa.
class SentHoldScreen extends StatelessWidget {
  const SentHoldScreen({
    super.key,
    required this.title,
    required this.label,
    required this.answer,
  });

  /// Top left (the question's number or the game's round).
  final String title;

  /// Small caps over the answer ("TVOJ ODGOVOR").
  final String label;
  final String answer;

  @override
  Widget build(BuildContext context) => RoleHoldScreen(
    name: title,
    night: 0,
    header: '',
    heading: label,
    hiddenHint: Strings.sentHint,
    role: answer,
    description: Strings.waitTv,
  );
}
