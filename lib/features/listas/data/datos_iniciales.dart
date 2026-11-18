import '../domain/item_lista.dart';

/// Datos con los que arranca un club nuevo (solo se crean una vez).
/// El resto de películas se puede cargar con el botón ✨ "Reto Disney".
const Map<TipoLista, List<NuevoItem>> datosIniciales = {
  TipoLista.peliculas: [
    (titulo: 'Tierra de osos', categoria: 'Aventura', nota: ''),
  ],
  TipoLista.deseos: [(titulo: 'Ir al IRTRA', categoria: 'Viajes', nota: '')],
  TipoLista.planes: [
    (titulo: 'Desayunar juntos', categoria: 'Citas', nota: ''),
  ],
};
