// Escribe en Firestore config/version la versión recién publicada para que la
// app avise a todos. Lo ejecuta GitHub Actions (.github/workflows/publicar.yml).
//
// Variables de entorno:
//   GOOGLE_APPLICATION_CREDENTIALS  ruta al JSON de la cuenta de servicio
//   VERSION      p. ej. 1.2.0          BUILD  p. ej. 5 (versionCode)
//   URL          URL pública del APK   SHA256 hash del APK
//   NOTAS        novedades (texto)     OBLIGATORIA  "true" o "false"
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const e = process.env;
for (const k of ['VERSION', 'BUILD', 'URL']) {
  if (!e[k]) {
    console.error(`Falta la variable ${k}`);
    process.exit(1);
  }
}
const build = Number.parseInt(e.BUILD, 10);
if (!Number.isInteger(build) || build < 1) {
  console.error(`BUILD inválido: ${e.BUILD}`);
  process.exit(1);
}

initializeApp(
  e.FIRESTORE_EMULATOR_HOST
    ? { projectId: e.GCLOUD_PROJECT ?? 'demo-club' }
    : { credential: applicationDefault() },
);
const ref = getFirestore().doc('config/version');

const actual = (await ref.get()).data();
if (actual && actual.build >= build) {
  console.error(`config/version ya tiene build ${actual.build} (>= ${build}); no se cambia.`);
  process.exit(1);
}

await ref.set({
  version: e.VERSION,
  build,
  url: e.URL,
  sha256: e.SHA256 || null,
  notas: (e.NOTAS ?? '').trim(),
  obligatoria: e.OBLIGATORIA === 'true',
  publicadaEn: FieldValue.serverTimestamp(),
});
console.log(`config/version → ${e.VERSION} (build ${build})`);
