import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")

check(keystorePropertiesFile.isFile) {
    "Missing android/key.properties. Release signing cannot continue."
}

val keystoreProperties = Properties().apply {
    keystorePropertiesFile.inputStream().use { load(it) }
}

fun requiredKeyProperty(name: String): String {
    return keystoreProperties.getProperty(name)
        ?.takeIf { it.isNotBlank() }
        ?: error("Missing '$name' in android/key.properties")
}

android {
    namespace = "com.pyaephyoaung.kyatflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = requiredKeyProperty("keyAlias")
            keyPassword = requiredKeyProperty("keyPassword")
            storePassword = requiredKeyProperty("storePassword")
            storeFile = file(requiredKeyProperty("storeFile"))

            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.pyaephyoaung.kyatflow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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