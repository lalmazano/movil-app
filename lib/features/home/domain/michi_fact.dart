/// Un dato curioso sobre gatos.
class MichiFact {
  const MichiFact(this.text);

  final String text;
}

/// Contrato para obtener datos de michis.
abstract interface class MichiFactRepository {
  List<MichiFact> getAll();
}
