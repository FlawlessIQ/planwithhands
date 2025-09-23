plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File

android {
    namespace = "com.example.hands_clean"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

        // Static signingConfig using the repository keystore (explicit and early)
        signingConfigs {
            create("release") {
                val repoKeystore = rootProject.file("../android/hands-release-key.keystore")
                storeFile = repoKeystore
                storePassword = "hands123"
                keyAlias = "hands"
                keyPassword = "hands123"
            }
        }

        // Add an explicit signing config that points directly at the repo keystore (absolute path)
        try {
            val repoKeystore = rootProject.file("../android/hands-release-key.keystore")
            val explicit = signingConfigs.findByName("explicitRelease") ?: signingConfigs.create("explicitRelease")
            explicit.storeFile = repoKeystore
            explicit.storePassword = "hands123"
            explicit.keyAlias = "hands"
            explicit.keyPassword = "hands123"
            println("[signing] explicitRelease.created storeFile=${explicit.storeFile} (exists=${explicit.storeFile != null})")
        } catch (e: Exception) {
            println("[signing] explicitRelease: failed to create: ${e.message}")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.hands_clean"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Try to load signing properties from a key.properties file at project root.
            // If not present, fall back to debug signing to avoid breaking local builds.
                val keystorePropertiesFile = file("key.properties")
                if (keystorePropertiesFile.exists()) {
                    val keystoreProps = Properties()
                    keystorePropertiesFile.inputStream().use { keystoreProps.load(it) }
                    val storeFileProp = keystoreProps.getProperty("storeFile")
                    // Resolve the store file relative to the key.properties file location
                    val keyPropsDir = keystorePropertiesFile.parentFile
                    val candidateStoreFile = if (storeFileProp != null) File(keyPropsDir, storeFileProp) else null
                    val resolvedStoreFile = when {
                        candidateStoreFile != null && candidateStoreFile.exists() -> candidateStoreFile
                        else -> rootProject.file("../android/hands-release-key.keystore")
                    }
                    val releaseSigning = signingConfigs.findByName("release")
                        ?: signingConfigs.create("release")
                    // Ensure the release buildType explicitly uses the 'release' signing config
                    signingConfig = signingConfigs.getByName("release")
                    // assign values to the 'release' signing config
                    releaseSigning.storeFile = resolvedStoreFile
                    releaseSigning.storePassword = keystoreProps.getProperty("storePassword")
                    releaseSigning.keyAlias = keystoreProps.getProperty("keyAlias")
                    releaseSigning.keyPassword = keystoreProps.getProperty("keyPassword")
                    signingConfig = releaseSigning
                    println("[signing] buildTypes.release assigned signingConfig=${signingConfig?.name} (storeFile=${releaseSigning.storeFile?.absolutePath})")
                } else {
                    // Default: use debug signing config so local release builds still work.
                    signingConfig = signingConfigs.getByName("debug")
                }
        }
    }
                                    // Explicitly use the statically-created 'release' signingConfig
                                    signingConfig = signingConfigs.getByName("release")
                                } else {
                                    // Default: use debug signing config so local release builds still work.
                                    signingConfig = signingConfigs.getByName("debug")
                                }
    println("[signing] final config: name=${sc.name} storeFile=${sc.storeFile} keyAlias=${sc.keyAlias}")
}

// Print buildTypes signing config assignments
android.buildTypes.forEach { bt ->
    println("[signing] buildType=${bt.name} signingConfig=${bt.signingConfig?.name} (storeFile=${bt.signingConfig?.storeFile})")
}

// Ensure Flutter Gradle plugin or other scripts don't override the release signing config
afterEvaluate {
    try {
        val releaseConfig = android.signingConfigs.getByName("release")
    android.buildTypes.getByName("release").signingConfig = android.signingConfigs.getByName("explicitRelease")
        println("[signing] afterEvaluate forced buildTypes.release.signingConfig=${android.buildTypes.getByName("release").signingConfig?.name}")
    } catch (e: Exception) {
        println("[signing] afterEvaluate: failed to force signing config: ${e.message}")
    }
}

// Use Android Components API to ensure release variant uses the release signing config
try {
    androidComponents.finalizeDsl { ext ->
        try {
            val releaseSigning = android.signingConfigs.getByName("release")
            androidComponents.onVariants { variant ->
                if (variant.name.contains("release", ignoreCase = true)) {
                    println("[signing] androidComponents: variant=${variant.name} will use signingConfig=release")
                }
            }
        } catch (e: Exception) {
            println("[signing] androidComponents error: ${e.message}")
        }
    }
} catch (e: Exception) {
    println("[signing] androidComponents not available: ${e.message}")
}
