# 构建与测试

## 锁定环境

- Flutter 3.47.9 stable / Dart 3.13.7，commit `c197ca5199e9ee5661e865596c9c07294dfab51c`。
- SDK：`~\Documents\Codex\toolchains\flutter`。
- 官方 ZIP SHA-256：`d8e2b5977e09082c6440f89dc1aa887b94c8fbcc3b39222797046295a3f68a9e`。
- Android SDK：`~\AppData\Local\Android\Sdk`；compile/target 36，min 24，build-tools 36.0.0，cmdline-tools 23.0，NDK 28.2.13676358，CMake 3.22.1。
- Java 17：`C:\Program Files\Java\jdk-17`；Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0。
- [官方 Flutter 版本元数据](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json)。

## 一键打包

双击 `~\Desktop\Jiao Authenticator\Build-APK.cmd`，或用 PowerShell 7 执行：

```powershell
& '~\Desktop\Jiao Authenticator\Build-APK.ps1'
```

脚本使用项目外的原发布密钥，构建单个正式 APK、验签并核对复制后 SHA-256。当前版本输出：

- `~\Desktop\Jiao Authenticator\dist\Jiao-Authenticator-v0.1.3.apk`
- 同目录 `.apk.sha256` 校验文件。

可传 `-OutputDirectory`、`-FlutterRoot`、`-AndroidSdk`、`-JavaHome`、`-SigningConfig`。项目根目录有空格也可直接运行。更新应用请保持同一发布签名，并增加 pubspec.yaml 构建号。

## 其他 PowerShell 7 命令

```powershell
$script = '~\Desktop\Jiao Authenticator\tool\dev.ps1'
& $script -Action Doctor
& $script -Action Analyze
& $script -Action Test
& $script -Action Release
```

脚本默认路径适用于本机，不改全局 PATH。其他机器可传 `-FlutterRoot`、`-AndroidSdk`、`-JavaHome`。首次构建需下载依赖并接受 Android SDK 许可；运行中的 APK 不联网。

发布脚本读取项目外 `Documents\Codex\toolchains\jiao-signing\signing.json`（可用 `-SigningConfig` 指定），字段是 `storeFile`、`storePassword`、`keyPassword`。别名固定 `jiao-authenticator`。不要把配置或密钥移入源码。构建后自动执行 apksigner verify。

APK 在 `build\app\outputs\flutter-apk\app-release.apk`。同一源码重新构建的 ZIP 字节不保证完全一致。更新应保留原发布密钥，并增加版本构建号。

本机已在项目外准备 `Documents\Codex\toolchains\jiao-maven-cache`。现有 Gradle init 可直接读取此本地仓库，无须启动代理；其他机器没有缓存时使用官方 Google/Maven Central/Gradle 仓库。构建缓存不随应用分发。

## 验证

Test 执行 `flutter test --coverage --reporter expanded`，生成 `coverage/lcov.info`。覆盖 RFC 全算法向量、时间/Next 边界、前导零、非法参数、存储失败、锁定竞态、备份往返/篡改与界面状态。

Integration 默认在专用 `emulator-5570` 执行，需要配合原生测试驱动或人工完成系统对话框。不要指向有真实账号的手机。测试使用 `jiao-integration-*` 安全存储，结束后清理。

自动化约定：Downloads 中准备集成测试公开二维码图片 `Jiao-qr-fixture.png`；保存文件命名 `Jiao-integration.jiaoauth`；使用专用模拟器的测试凭据；相机弹窗选择拒绝。交付的测试驱动只操作该模拟器，不随 APK 执行。

发布前执行 analyze、coverage、Android 集成测试、release build 和 APK 签名/权限检查。测试结果和真实手机待确认项见交付记录。维护时不得记录密钥、二维码原文、验证码或口令，不得在存储错误时自动清空数据。
