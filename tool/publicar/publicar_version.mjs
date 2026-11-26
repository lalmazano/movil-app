// Sube el APK a Firestore (partido en trozos de < 1 MB, porque Firebase
// Hosting gratuito no permite .apk) y actualiza config/version para que la
// app avise a todos. Lo ejecuta GitHub Actions (.github/workflows/publicar.yml).
//
// Variables de entorno:
//   GOOGLE_APPLICATION_CREDENTIALS  ruta al JSON de la cuenta de servicio
//   APK          ruta del APK          VERSION  p. ej. 1.2.0
//   BUILD        versionCode, p. ej. 5 NOTAS    novedades (texto)
//   OBLIGATORIA  "true" o "false"
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const TAM_PARTE = 900 * 1024;
const e = process.env;
for (const k of ['APK', 'VERSION', 'BUILD']) {
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
const db = getFirestore();
const refVersion = db.doc('config/version');

const actual = (await refVersion.get()).data();
if (actual && actual.build >= build) {
  console.error(`config/version ya tiene build ${actual.build} (>= ${build}); no se cambia.`);
  process.exit(1);
}

// 1. Subir el APK por partes.
const apk = readFileSync(e.APK);
const sha256 = createHash('sha256').update(apk).digest('hex');
const partes = Math.ceil(apk.length / TAM_PARTE);
const refApk = db.collection('apk').doc(String(build));
for (let i = 0; i < partes; i++) {
  const datos = apk.subarray(i * TAM_PARTE, (i + 1) * TAM_PARTE);
  await refApk.collection('partes').doc(String(i).padStart(3, '0')).set({ datos });
  process.stdout.write(`\rSubiendo APK: ${i + 1}/${partes}`);
}
await refApk.set({
  version: e.VERSION,
  tamano: apk.length,
  partes,
  sha256,
  subidoEn: FieldValue.serverTimestamp(),
});
console.log(`\nAPK ${(apk.length / 1048576).toFixed(1)} MB en ${partes} partes`);

// 2. Avisar a la app (solo cuando el APK ya está completo).
await refVersion.set({
  version: e.VERSION,
  build,
  partes,
  sha256,
  notas: (e.NOTAS ?? '').trim(),
  obligatoria: e.OBLIGATORIA === 'true',
  publicadaEn: FieldValue.serverTimestamp(),
});
console.log(`config/version → ${e.VERSION} (build ${build})`);

// 3. Borrar APKs viejos (se conserva solo el actual) para no gastar espacio.
for (const viejo of await db.collection('apk').listDocuments()) {
  if (viejo.id === String(build)) continue;
  await db.recursiveDelete(viejo);
  console.log(`Borrado APK viejo: build ${viejo.id}`);
}
