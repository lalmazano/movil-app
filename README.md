# El Club del Frijol 🫘

Aplicación para dos, con tema de michis 🐱, desarrollada con [Flutter](https://flutter.dev) (Android, iOS y Web).

## Funciones

- **Películas 🎬:** lista de películas por ver, por categorías (Princesas, Clásicos,
  Pixar, Navideñas...). El botón ✨ carga el reto Disney completo.
- **Deseos 🌠** y **Hacer juntos 💞:** listas de deseos y planes en pareja.
- En todas se puede agregar, editar, borrar y **marcar como hecho** (guarda la fecha).
  Se sincronizan en tiempo real entre teléfonos con **Cloud Firestore**.

- **Inicio:** michi interactivo y datos curiosos de gatos.
- **Recuerdos:** tómate una foto con tu michi (selfie, cámara trasera o galería),
  califícala de 1 a 5 huellitas 🐾 y guárdala con una nota. Puedes guardarla en la
  galería (álbum "Michis") o compartirla por WhatsApp. Las fotos se guardan
  en la carpeta privada de la app (solo Android e iOS).

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
y **Firebase Auth anónimo** para que solo la app pueda leer/escribir.
Los datos quedan en `clubs/club-del-frijol/{peliculas|deseos|planes}`.

1. Crea un proyecto en <https://console.firebase.google.com> (plan Spark, sin tarjeta).
2. Activa **Firestore Database** y en *Authentication → Método de acceso* activa **Anónimo**.
3. **Android:** descarga `google-services.json` (app `com.almazan.josue`) y
   colócalo en `android/app/google-services.json`. **No se versiona** (está en
   `.gitignore`). Para iOS/Web: `flutterfire configure`.
4. Copia `firestore.rules` en *Firestore → Reglas* y publica
   (o `firebase deploy --only firestore:rules`).

Sin este paso la app funciona en **modo local** (los datos no se guardan).

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
    ├── listas/               # Películas, deseos y planes (Firestore)
    ├── recuerdos/            # Fotos con el michi y su calificación
    └── home/                 # Un módulo por funcionalidad
        ├── data/             # Fuentes de datos, modelos, repositorios
        ├── domain/           # Entidades y lógica de negocio
        └── presentation/     # Pantallas y widgets
```

Para agregar una nueva funcionalidad, cree `lib/features/<nombre>/` con las
mismas tres capas y registre sus rutas en `lib/core/routes/app_router.dart`.

## CI

`.github/workflows/flutter-ci.yml` ejecuta formato, análisis y pruebas en cada push a `main` y en cada PR.
