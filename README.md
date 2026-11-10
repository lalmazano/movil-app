# Movil App

Aplicación móvil con tema de michis 🐱, desarrollada con [Flutter](https://flutter.dev) (Android, iOS y Web).

## Funciones

| Sección | Qué hace |
|---|---|
| **Inicio** | Saluda a tus michis por su nombre, avisa sus cumpleaños 🎂, michi interactivo con maullidos y ronroneo, datos curiosos. |
| **Mis michis** | Perfiles con foto, fecha de nacimiento, raza y emoji; varios michis. |
| **Foto con mi michi** | Selfie/cámara/galería, decorar con marcos y stickers ✨, calificar de 1 a 5 huellitas 🐾, etiquetar al michi, guardar en galería y compartir por WhatsApp. Orden y filtros por michi y mes. |
| **Recordatorios** | Vacunas, desparasitación, comida, arenero, medicina… con notificaciones (una vez, diario, semanal, mensual). |
| **Salud** | Diario de visitas al veterinario, vacunas, medicinas y síntomas, con costos. |
| **Peso** | Registro de peso por michi con gráfica. |
| **Logros** | Insignias que se desbloquean usando la app 🏆. |
| **Juego para michi** | Ratón, pez o láser que el gato persigue en la pantalla. |

Los sonidos son originales, generados con `tool/generar_sonidos.py`.
Los datos se guardan solo en el teléfono (carpeta privada de la app).

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
    ├── home/                 # Un módulo por funcionalidad
    ├── michis/               # Perfiles de michis
    ├── recuerdos/            # Fotos con el michi y su calificación
    ├── editor_foto/          # Marcos y stickers
    ├── recordatorios/        # Recordatorios con notificaciones
    ├── salud/                # Diario de salud
    ├── peso/                 # Control de peso
    ├── logros/               # Logros
    ├── juego/                # Juego para el gato
    └── sonidos/              # Efectos de sonido
        ├── data/             # Fuentes de datos, modelos, repositorios
        ├── domain/           # Entidades y lógica de negocio
        └── presentation/     # Pantallas y widgets
```

Para agregar una nueva funcionalidad, cree `lib/features/<nombre>/` con las
mismas tres capas, registre su ruta en `lib/core/routes/app_router.dart` y
agréguela al menú en `lib/app/secciones.dart`.

## CI

`.github/workflows/flutter-ci.yml` ejecuta formato, análisis y pruebas en cada push a `main` y en cada PR.
