# Movil App

Aplicación móvil desarrollada con [Flutter](https://flutter.dev) (Android, iOS y Web).

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
    └── home/                 # Un módulo por funcionalidad
        ├── data/             # Fuentes de datos, modelos, repositorios
        ├── domain/           # Entidades y lógica de negocio
        └── presentation/     # Pantallas y widgets
```

Para agregar una nueva funcionalidad, cree `lib/features/<nombre>/` con las
mismas tres capas y registre sus rutas en `lib/core/routes/app_router.dart`.

## CI

`.github/workflows/flutter-ci.yml` ejecuta formato, análisis y pruebas en cada push a `main` y en cada PR.
