import 'curve_sim.dart';

/// Whom a power-up acts on: green on you, red on everyone else, blue on everyone.
enum PowerUpTarget { you, others, all }

PowerUpTarget powerUpActsOn(PowerUpKind k) => switch (k) {
      PowerUpKind.speed || PowerUpKind.slow || PowerUpKind.ghost || PowerUpKind.cheese => PowerUpTarget.you,
      PowerUpKind.speedOthers ||
      PowerUpKind.slowOthers ||
      PowerUpKind.fatOthers ||
      PowerUpKind.reverseOthers ||
      PowerUpKind.squareOthers =>
        PowerUpTarget.others,
      PowerUpKind.clear || PowerUpKind.wrap => PowerUpTarget.all,
    };

/// One power-up in the legend: its name, what it does in one line, and for how long.
class PowerUpText {
  const PowerUpText(this.name, this.what, this.time);
  final String name, what, time;
}

/// The Curve power-up legend in Croatian, shared by the TV (the home's Curve card) and the host's
/// phone (Curve details). Plain, ti-form, no past-tense verbs on people.
const powerUpTexts = <PowerUpKind, PowerUpText>{
  PowerUpKind.speed: PowerUpText('Ubrzanje', 'Ti voziš brže.', '5 s'),
  PowerUpKind.slow: PowerUpText('Usporavanje', 'Ti voziš sporije i lakše skrećeš.', '5 s'),
  PowerUpKind.ghost: PowerUpText('Duh', 'Prolaziš kroz linije i ne ostavljaš trag. Zid te i dalje zaustavlja.', '5 s'),
  PowerUpKind.cheese: PowerUpText('Sir', 'Tvoja linija je puna rupa kroz koje se može proći.', '5 s'),
  PowerUpKind.speedOthers: PowerUpText('Ubrzanje ostalih', 'Svi ostali voze brže.', '5 s'),
  PowerUpKind.slowOthers: PowerUpText('Usporavanje ostalih', 'Svi ostali voze sporije.', '5 s'),
  PowerUpKind.fatOthers: PowerUpText('Debela linija', 'Svima ostalima linija je deblja; svako novo pojačanje još deblja (do 3 puta).', '7,5 s'),
  PowerUpKind.reverseOthers: PowerUpText('Obrnuto', 'Svima ostalima su lijevo i desno zamijenjeni.', '5 s'),
  PowerUpKind.squareOthers: PowerUpText('Pravi kutovi', 'Svi ostali skreću pod pravim kutom: jedan dodir, jedan zavoj.', '5 s'),
  PowerUpKind.clear: PowerUpText('Čišćenje', 'Sve linije nestaju s ploče. Igra ide dalje.', 'odmah'),
  PowerUpKind.wrap: PowerUpText('Kroz zid', 'Svi prolaze kroz zid i izlaze na drugoj strani. Bijeli rub pokazuje koliko još traje.', '5 s'),
};
