import '../domain/item_lista.dart';

/// Datos con los que arranca un club nuevo (solo se crean una vez).
/// El resto de películas se puede cargar con el botón ✨ "Reto Disney".
const Map<TipoLista, List<NuevoItem>> datosIniciales = {
  TipoLista.peliculas: [
    (titulo: 'Tierra de osos', categoria: 'Aventura', nota: ''),
  ],
  TipoLista.deseos: [
    (titulo: 'Viajar juntos a la playa', categoria: 'Viajes', nota: ''),
  ],
  TipoLista.planes: [(titulo: 'Hacer un picnic', categoria: 'Citas', nota: '')],
};
