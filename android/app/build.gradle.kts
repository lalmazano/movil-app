import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase: android/app/google-services.json no se versiona (.gitignore).
// Si no existe, la app compila igual y funciona en modo local.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Llave de firma permanente (nunca se versiona):
// - local: android/key.properties (storeFile, storePassword, keyAlias, keyPassword)
// - GitHub Actions: variables CLUB_KEYSTORE_PATH, CLUB_KEYSTORE_PASSWORD,
//   CLUB_KEY_ALIAS y CLUB_KEY_PASSWORD.
// Sin ninguna de las dos se firma con la llave de depuración.
val firma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
    System.getenv("CLUB_KEYSTORE_PATH")?.let { setProperty("storeFile", it) }
    System.getenv("CLUB_KEYSTORE_PASSWORD")?.let { setProperty("storePassword", it) }
    System.getenv("CLUB_KEY_ALIAS")?.let { setProperty("keyAlias", it) }
    System.getenv("CLUB_KEY_PASSWORD")?.let { setProperty("keyPassword", it) }
}
val tieneFirma = firma.getProperty("storeFile") != null

android {
    namespace = "com.igss.movil_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por ota_update (actualizaciones dentro de la app).
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        if (tieneFirma) {
            create("club") {
                storeFile = file(firma.getProperty("storeFile"))
                storePassword = firma.getProperty("storePassword")
                keyAlias = firma.getProperty("keyAlias")
                keyPassword = firma.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.almazan.josue"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (tieneFirma) "club" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
