import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名配置：密钥文件与密码只存本机 key.properties（已在 .gitignore 排除）
// 用 UTF-8 读取：Properties.load(InputStream) 默认按 ISO-8859-1 解码，
// 路径里一旦有中文就会变乱码、导致下面的 exists() 判断失败并静默退回 debug 签名。
val keystoreProperties = Properties().apply {
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) {
        FileInputStream(propsFile).use { stream ->
            // Kotlin 的 reader() 默认 UTF-8，避免中文路径被 ISO-8859-1 读成乱码
            load(stream.reader(Charsets.UTF_8))
        }
    }
}

// 兜底判断：key.properties 存在且四个字段齐全，才算「配好了正式签名」。
// 缺任何一项就自动回退 debug 签名，保证没有密钥的机器（CI / 新克隆的仓库）也能出包，
// 而不是抛一句看不懂的 keystore 空指针。
val hasReleaseKeystore = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() } &&
    keystoreProperties.getProperty("storeFile")
        ?.let { file(it).exists() } == true

if (!hasReleaseKeystore) {
    if (keystoreProperties.isEmpty) {
        logger.lifecycle(
            "[签名] 未找到 android/key.properties，release 将回退 debug 签名（仅适合自测，勿分发）。"
        )
    } else {
        logger.warn(
            "[签名] key.properties 存在但不可用（字段不全或密钥文件不存在），release 已回退 debug 签名。storeFile=" +
                keystoreProperties.getProperty("storeFile") +
                "，请检查路径是否存在。"
        )
    }
}

android {
    namespace = "com.jigongshi.jigongshi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jigongshi.jigongshi"
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                // 同时启用 v1/v2 签名：v2 供 Android 7+ 校验，v1 兼容老机型
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            // 有正式密钥 → 正式签名；没有 → 回退 debug，避免构建直接失败
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 代码混淆/压缩：减小包体并让反编译更难读懂业务逻辑
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
