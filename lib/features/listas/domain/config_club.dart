import 'item_lista.dart';

/// Configuración del club, guardada en el documento `config/app` de Firestore.
///
/// Campos (todos booleanos; si faltan, valen `true`):
/// - `peliculas`, `deseos`, `planes`: qué listas se muestran.
/// - `registroAbierto`: si alguien nuevo puede entrar al club.
class ConfigClub {
  const ConfigClub({
    this.peliculas = true,
    this.deseos = true,
    this.planes = true,
    this.registroAbierto = true,
  });

  factory ConfigClub.fromMap(Map<String, Object?>? map) => ConfigClub(
    peliculas: map?['peliculas'] as bool? ?? true,
    deseos: map?['deseos'] as bool? ?? true,
    planes: map?['planes'] as bool? ?? true,
    registroAbierto: map?['registroAbierto'] as bool? ?? true,
  );

  final bool peliculas;
  final bool deseos;
  final bool planes;
  final bool registroAbierto;

  bool esVisible(TipoLista tipo) => switch (tipo) {
    TipoLista.peliculas => peliculas,
    TipoLista.deseos => deseos,
    TipoLista.planes => planes,
  };

  List<TipoLista> get listasVisibles =>
      TipoLista.values.where(esVisible).toList();
}
