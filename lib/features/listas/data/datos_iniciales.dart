import '../domain/item_lista.dart';
import 'catalogo_disney.dart';

/// Datos con los que arranca un club nuevo (solo se crean una vez).
final Map<TipoLista, List<NuevoItem>> datosIniciales = {
  TipoLista.peliculas: peliculasFaltantes(const []),
  TipoLista.deseos: const [
    (titulo: 'Viajar juntos a la playa', categoria: 'Viajes', nota: ''),
    (titulo: 'Conocer Tikal', categoria: 'Viajes', nota: ''),
    (titulo: 'Ir a un concierto juntos', categoria: 'Experiencias', nota: ''),
    (titulo: 'Probar un restaurante nuevo', categoria: 'Comida', nota: ''),
    (
      titulo: 'Ahorrar para nuestro próximo viaje',
      categoria: 'Metas',
      nota: '',
    ),
  ],
  TipoLista.planes: const [
    (titulo: 'Hacer un picnic', categoria: 'Citas', nota: ''),
    (titulo: 'Maratón de películas Disney', categoria: 'En casa', nota: ''),
    (titulo: 'Cocinar una receta nueva', categoria: 'En casa', nota: ''),
    (titulo: 'Ver el amanecer', categoria: 'Aventuras', nota: ''),
    (titulo: 'Aprender a bailar juntos', categoria: 'Aprender', nota: ''),
  ],
};
