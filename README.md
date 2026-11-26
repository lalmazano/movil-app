# El Club del Frijol 🫘

Aplicación para dos desarrollada con [Flutter](https://flutter.dev) (Android, iOS y Web).

## Funciones

- **Entrar con Google** (Firebase Auth).
- **Películas 🎬:** lista de películas por ver, por categorías (Princesas, Clásicos,
  Pixar, Navideñas...). El botón ✨ carga el reto Disney completo.
- **Deseos 🌠** y **Hacer juntos 🧺:** listas de deseos y planes en pareja.
- En todas se puede agregar, editar, borrar y **marcar como hecho** (guarda la fecha).
  Se sincronizan en tiempo real entre teléfonos con **Cloud Firestore**.

## Requisitos

- Flutter SDK (canal `stable`, 3.x) — `flutter --version`
- Android Studio / Xcode según la plataforma destino

## Primeros pasos

```bash
flutter pub get
flutter run          # ejecuta en el dispositivo/emulador conectado
flutter test         # pruebas
flutter analyze      # análisis estático
```

## Firebase (plan gratuito Spark)

Se usa **Cloud Firestore** (gratis: 1 GiB, 50 000 lecturas y 20 000 escrituras al día)
y **Firebase Auth con Google** para que solo ustedes puedan leer/escribir.
Los datos quedan en `clubs/club-del-frijol/{peliculas|deseos|planes}`.

1. Crea un proyecto en <https://console.firebase.google.com> (plan Spark, sin tarjeta).
2. Activa **Firestore Database** y en *Authentication → Método de acceso* activa **Google**.
   Registra la huella **SHA-1** de tu llave de firma en *Configuración del proyecto →
   Tus apps → Android* (`cd android && ./gradlew signingReport`) y vuelve a descargar
   `google-services.json`.
3. **Android:** descarga `google-services.json` (app `com.almazan.josue`) y
   colócalo en `android/app/google-services.json`. **No se versiona** (está en
   `.gitignore`). Para iOS/Web: `flutterfire configure`.
4. No hace falta crear nada: la primera vez que alguien entra, la app crea
   `config/app`, `clubs/club-del-frijol` y los datos iniciales (una película, un deseo y
   un plan; el resto del reto Disney se carga con el botón ✨). `usuarios` se llena al entrar.

   Las **categorías** de cada lista están en `categorias/{peliculas|deseos|planes}`,
   campo `nombres` (arreglo de textos, en el orden en que se muestran). La app las
   crea la primera vez con las de por defecto (películas: Disney, DreamWorks,
   Princesas, Clásicos, Mágicas / Fantasía, Pixar, Aventura, Navideñas, Otras);
   para agregar o quitar, edita el arreglo desde la consola.

   El documento **`config/app`** tiene:

   | Campo | Tipo | Para qué |
   |---|---|---|
   | `peliculas` | boolean | Mostrar la lista de películas |
   | `deseos` | boolean | Mostrar la lista de deseos |
   | `planes` | boolean | Mostrar "Hacer juntos" |
   | `registroAbierto` | boolean | Permitir que alguien nuevo se una al club |

   Si falta el documento o un campo, vale `true`. Los miembros quedan en
   `usuarios/{uid}`; cuando ya estén los dos, pon `registroAbierto` en `false`.
5. Copia `firestore.rules` en *Firestore → Reglas* y publica
   (o `firebase deploy --only firestore:rules`).

Sin este paso la app funciona en **modo local** (los datos no se guardan).

## Funciones y banderas (`config/app`)

Cada función se activa o desactiva con un campo booleano en `config/app`.
Al abrir la app se crean las banderas que falten (en `true`); las que ya
existen no se cambian:

| Campo | Función |
|---|---|
| `calificaciones` | 🐾 de 1 a 5 y comentario al marcar como hecho |
| `autores` | Quién agregó y quién marcó cada elemento |
| `ruleta` | 🎲 "¿Qué vemos/hacemos hoy?" |
| `buscar` | 🔍 Búsqueda por título o nota |
| `fotos` | 📷 Fotos de recuerdos (dentro de Firestore, < 900 KB c/u) |
| `posters` | 🎞️ Pósters y datos de TMDB (requiere `config/tmdb.apiKey`) |
| `contador` | Contador de aniversario (requiere `aniversario`, timestamp) |
| `widget` | Widget de la pantalla de inicio de Android |

## Icono (Gato con Botas)

Reemplaza `assets/icon/app_icon.png` por tu imagen cuadrada de 1024×1024 y ejecuta:

```bash
dart run flutter_launcher_icons
```

La misma imagen se usa como logo en la pantalla de inicio.

## Estructura

```
lib/
├── main.dart                 # Punto de entrada
├── app/app.dart              # MaterialApp (tema, rutas)
├── core/
│   ├── constants/            # Constantes globales
│   ├── routes/               # Rutas y router centralizado
│   ├── theme/                # Tema claro/oscuro (Material 3)
│   └── widgets/              # Widgets reutilizables
└── features/
    ├── auth/                 # Entrar con Google
    ├── listas/               # Películas, deseos y planes (Firestore)
    └── home/                 # Un módulo por funcionalidad
        ├── data/             # Fuentes de datos, modelos, repositorios
        ├── domain/           # Entidades y lógica de negocio
        └── presentation/     # Pantallas y widgets
```

Para agregar una nueva funcionalidad, cree `lib/features/<nombre>/` con las
mismas tres capas y registre sus rutas en `lib/core/routes/app_router.dart`.

## CI

`.github/workflows/flutter-ci.yml` ejecuta formato, análisis y pruebas en cada push a `main` y en cada PR.

## Actualizaciones automáticas

La app lee `config/version` en Firestore; si hay un build mayor que el
instalado, muestra las novedades, descarga el APK y abre el instalador de
Android (bandera `actualizaciones` en `config/app`). El APK se guarda en
Firestore partido en trozos (`apk/{build}/partes/…`), porque Firebase Hosting
gratuito no permite archivos `.apk`; solo los miembros pueden leerlo.

### Configuración (una sola vez)
1. **Cuenta de servicio:** Google Cloud Console → IAM → la cuenta
   `firebase-adminsdk-…@clubdelfrijol-1f507.iam.gserviceaccount.com` →
   *Editar* → rol **Administrador de Firebase**. Luego Firebase →
   Configuración del proyecto → Cuentas de servicio → *Generar nueva clave*.
2. **Secretos en GitHub** (Settings → Secrets and variables → Actions):
   `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`,
   `GOOGLE_SERVICES_JSON_BASE64` y `FIREBASE_SERVICE_ACCOUNT` (el JSON).
3. Registra la SHA-1 de la llave permanente en Firebase (app Android).

### Publicar una versión
1. En GitHub: **Releases → Draft a new release** → etiqueta nueva `v1.2.0`
   sobre la rama con el código → novedades en la descripción (agrega
   `[obligatoria]` para forzarla) → **Publish release**. La versión sale de la
   etiqueta (no hay que editar `pubspec.yaml`); el número de compilación es
   X·10000 + Y·100 + Z, así que cada versión mayor siempre es más nueva.
2. GitHub Actions (`publicar.yml`) prueba, compila y firma, publica
   `firestore.rules`, sube el APK a Firestore, actualiza `config/version` y
   adjunta el APK al Release (para instalarlo a mano si hace falta).
