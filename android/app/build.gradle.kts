plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.fittechs.duruNotesApp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    buildFeatures {
        buildConfig = true
    }
    defaultConfig {
        applicationId = "com.fittechs.duruNotesApp"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Required for various plugins
        multiDexEnabled = true
        
        // Required for ML Kit and other Google services
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    flavorDimensions += "environment"
    
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appName"] = "Duru Notes Dev"
            buildConfigField("String", "FLAVOR", "\"dev\"")
        }
        
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            manifestPlaceholders["appName"] = "Duru Notes Staging"
            buildConfigField("String", "FLAVOR", "\"staging\"")
        }
        
        create("prod") {
            dimension = "environment"
            applicationIdSuffix = ""  // No suffix for production
            manifestPlaceholders["appName"] = "Duru Notes"
            buildConfigField("String", "FLAVOR", "\"prod\"")
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            // Remove debug suffix to match google-services.json
            applicationIdSuffix = ""
        }
        
        release {
            isDebuggable = false
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Ensure native sqlite libs are packaged for common ABIs
    // Adjust if you use different ABI coverage
    packagingOptions {
        resources {
            pickFirst("**/libsqlite3.so")
        }
    }

    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Required for MultiDex
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Required for some plugins
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // Fix Sentry UI tracking
    implementation("io.sentry:sentry-android:7.3.0")
    implementation("io.sentry:sentry-android-fragment:7.3.0")
}

flutter {
    source = "../.."
}
