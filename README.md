# Movil App

Aplicación móvil con tema de michis 🐱, desarrollada con [Flutter](https://flutter.dev) (Android, iOS y Web).

## Funciones

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
