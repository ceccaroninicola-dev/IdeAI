import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Il Flutter Gradle Plugin va applicato dopo Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// Leggi il keystore di rilascio da keystore/key.properties (se presente)
val keystorePropertiesFile = rootProject.file("keystore/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.cortexlabs.ideai"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.cortexlabs.ideai"
        minSdk = 21
        targetSdk = 35
        versionCode = 11
        versionName = "1.0.10"
        // Necessario per google_mobile_ads (multidex su API < 21 non serve con minSdk 21)
        multiDexEnabled = true
    }

    // Configurazione firma di rilascio
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                storeFile = keystoreProperties["storeFile"]?.toString()?.let { file(it) }
                storePassword = keystoreProperties["storePassword"]?.toString()
            }
        }
    }

    buildTypes {
        release {
            // Usa il keystore di rilascio se disponibile, altrimenti debug
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Abilita R8/ProGuard per ridurre la dimensione dell'APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
