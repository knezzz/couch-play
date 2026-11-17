import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/objasni_match.dart' show ObjasniStageTv;
import 'package:tv/session/blef_match.dart' show BlefStageTv;
import 'package:tv/ui/blef/blef_screen.dart';
import 'package:tv/ui/objasni/objasni_screen.dart';
import 'package:tv/ui/tkobi/tkobi_screen.dart';

/// The party-game TV screens sit on the 1920x1080 canvas and scale to the window, like the quiz: at the Mac's
/// 1280x720 (and 1272x715) nothing may leave the window.
void main() {
  final eight = [for (var i = 0; i < 8; i++) PlayerInfo(i, 'Igrac$i-duže', i, true, 0, character: characterIds[i])];
  const longQ = 'Koje je godine u Zagrebu otvoren prvi javni park za sve građane koji su tada živjeli u gradu i okolici, a danas je jedan od najpoznatijih?';

  for (final size in [const Size(1280, 720), const Size(1272, 715)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: Objasni, Blef and Tko bi? stay inside the window', (t) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      void allInside(String what) {
        expect(t.takeException(), isNull, reason: what);
        for (final w in t.widgetList(find.byType(Text))) {
          final r = t.getRect(find.byWidget(w));
          expect(r.right, lessThanOrEqualTo(size.width + 1), reason: '$what: ${(w as Text).data} $r');
          expect(r.bottom, lessThanOrEqualTo(size.height + 1), reason: '$what: ${w.data} $r');
        }
      }

      for (final st in [ObjasniStageTv.setup, ObjasniStageTv.ready, ObjasniStageTv.play, ObjasniStageTv.summary]) {
        await t.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: ObjasniScreen(ObjasniBoard(
              stage: st,
              teams: [eight.sublist(0, 4), eight.sublist(4)],
              scores: const [12, 9],
              target: 30,
              turnTeam: 0,
              explainer: eight[0],
              words: [for (var i = 0; i < 9; i++) ObjasniMarked('riječ $i', ObjasniMark.values[i % 3])],
              secondsLeft: 30,
              turnSeconds: 60,
              summarySeconds: 4,
              winnerTeam: null,
              pausedSeconds: null,
            ))));
        allInside('objasni $st');
      }
      final cards = [for (var i = 0; i < 9; i++) BlefCard('odgovor $i s malo duljim tekstom', i == 8, i == 8 ? const [] : [eight[0]], [eight[1], eight[2]])];
      for (final st in [BlefStageTv.write, BlefStageTv.pick, BlefStageTv.reveal]) {
        await t.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: BlefScreen(BlefBoard(
              stage: st, number: 1, total: 7, question: longQ, players: eight, sent: const {0, 1}, picked: const {2}, secondsLeft: 30, seconds: 60,
              list: [for (var i = 0; i < 9; i++) 'odgovor $i s malo duljim tekstom'], shown: cards, points: const {0: 500}))));
        allInside('blef $st');
      }
      for (final rows in [null, [for (var i = 0; i < 8; i++) TkobiRow(eight[i], i, i == 7)]]) {
        await t.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: TkobiScreen(TkobiBoard(number: 1, total: 5, prompt: longQ, players: eight, votedCount: 3, secondsLeft: 9, seconds: 15, rows: rows))));
        allInside('tkobi ${rows == null ? 'ask' : 'reveal'}');
      }
    });
  }
}
