plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val jiaoStore = providers.environmentVariable("JIAO_STORE_FILE")
val jiaoStorePassword = providers.environmentVariable("JIAO_STORE_PASSWORD")
val jiaoKeyPassword = providers.environmentVariable("JIAO_KEY_PASSWORD")

android {
    namespace = "app.jiao.authenticator"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.jiao.authenticator"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (jiaoStore.isPresent && jiaoStorePassword.isPresent && jiaoKeyPassword.isPresent) {
            create("jiaoRelease") {
                storeFile = file(jiaoStore.get())
                storePassword = jiaoStorePassword.get()
                keyAlias = "jiao-authenticator"
                keyPassword = jiaoKeyPassword.get()
            }
        }
    }

    buildTypes {
        release { signingConfig = signingConfigs.findByName("jiaoRelease") }
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
