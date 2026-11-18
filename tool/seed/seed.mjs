// Crea las colecciones principales y los datos básicos de El Club del Frijol.
//
//   config/app                         configuración (listas visibles y registro)
//   clubs/club-del-frijol              documento del club
//   clubs/club-del-frijol/peliculas    reto Disney (peliculas.json)
//   clubs/club-del-frijol/deseos       ejemplos (datos_basicos.json)
//   clubs/club-del-frijol/planes       ejemplos (datos_basicos.json)
//
// Se puede correr varias veces: lo que ya existe NO se sobrescribe
// (no se pierden las marcas de "hecho" ni la configuración que cambies).
//
// Uso:
//   1. Firebase Console → Configuración del proyecto → Cuentas de servicio →
//      "Generar nueva clave privada" → guárdala aquí como serviceAccountKey.json
//      (no se versiona).
//   2. cd tool/seed && npm install && npm run seed
import { readFileSync, existsSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';

const CLUB_ID = 'club-del-frijol';
const dir = new URL('.', import.meta.url);
const leer = (f) => JSON.parse(readFileSync(new URL(f, dir), 'utf8'));

const llave = new URL('serviceAccountKey.json', dir);
if (process.env.FIRESTORE_EMULATOR_HOST) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-club' });
} else if (existsSync(llave)) {
  initializeApp({ credential: cert(leer('serviceAccountKey.json')) });
} else {
  console.error('Falta tool/seed/serviceAccountKey.json (ver instrucciones en seed.mjs).');
  process.exit(1);
}
const db = getFirestore();

/** Crea el documento solo si no existe. Devuelve true si lo creó. */
async function crear(ref, datos) {
  try {
    await ref.create(datos);
    return true;
  } catch (e) {
    if (e.code === 6) return false; // ALREADY_EXISTS
    throw e;
  }
}

/** Id estable a partir del título, para no duplicar al correr de nuevo. */
const slug = (t) =>
  t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

async function cargarLista(nombre, items) {
  const col = db.collection('clubs').doc(CLUB_ID).collection(nombre);
  const base = Date.now();
  let creados = 0;
  // En paralelo por bloques; creadoEn crece para conservar el orden.
  for (let i = 0; i < items.length; i += 50) {
    const res = await Promise.all(items.slice(i, i + 50).map((it, j) =>
      crear(col.doc(slug(it.titulo)), {
        titulo: it.titulo,
        categoria: it.categoria,
        nota: it.nota ?? '',
        hecho: false,
        hechoEn: null,
        creadoEn: Timestamp.fromMillis(base + i + j),
      })));
    creados += res.filter(Boolean).length;
  }
  console.log(`  ${nombre}: ${creados} nuevos, ${items.length - creados} ya existían`);
}

console.log('Configuración…');
const config = await crear(db.doc('config/app'), {
  peliculas: true,
  deseos: true,
  planes: true,
  registroAbierto: true,
});
console.log(`  config/app: ${config ? 'creado' : 'ya existía (sin cambios)'}`);

const club = await crear(db.doc(`clubs/${CLUB_ID}`), {
  nombre: 'El Club del Frijol',
  creadoEn: FieldValue.serverTimestamp(),
});
console.log(`  clubs/${CLUB_ID}: ${club ? 'creado' : 'ya existía'}`);

console.log('Listas…');
const basicos = leer('datos_basicos.json');
await cargarLista('peliculas', leer('peliculas.json'));
await cargarLista('deseos', basicos.deseos);
await cargarLista('planes', basicos.planes);
console.log('¡Listo! 🫘');
