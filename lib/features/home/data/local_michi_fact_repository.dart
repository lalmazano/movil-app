import '../domain/michi_fact.dart';

/// Datos de michis guardados localmente.
class LocalMichiFactRepository implements MichiFactRepository {
  const LocalMichiFactRepository();

  static const _facts = [
    MichiFact('Los gatos duermen entre 12 y 16 horas al día. 😴'),
    MichiFact('El ronroneo puede ayudar a sanar huesos y tejidos.'),
    MichiFact('Cada nariz de gato tiene un patrón único, como una huella.'),
    MichiFact('Los gatos casi solo maúllan para comunicarse con humanos.'),
    MichiFact('Un gato puede saltar hasta seis veces su propia altura.'),
    MichiFact('Los bigotes les ayudan a medir si caben por un espacio.'),
    MichiFact('Los gatos no pueden saborear lo dulce.'),
    MichiFact(
      'Cuando un gato parpadea lento, te está diciendo "te quiero". 💕',
    ),
  ];

  @override
  List<MichiFact> getAll() => _facts;
}
