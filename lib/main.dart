import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/android_files.dart';
import 'core/temporary_screenshot_override.dart';
import 'core/vault_controller.dart';
import 'core/vault_repository.dart';
import 'ui/home_screen.dart';
import 'ui/jiao_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    JiaoApp(
      vault: VaultController(
        repository: VaultRepository(
          primary: AndroidSecureStore('jiao-vault'),
          recovery: AndroidSecureStore('jiao-recovery'),
          settings: AndroidSecureStore('jiao-settings'),
        ),
        authenticate: authenticateWithAndroid,
      ),
    ),
  );
}

class JiaoApp extends StatefulWidget {
  const JiaoApp({
    super.key,
    required this.vault,
    this.files = const AndroidFiles(),
  });
  final VaultController vault;
  final AndroidFiles files;

  @override
  State<JiaoApp> createState() => _JiaoAppState();
}

class _JiaoAppState extends State<JiaoApp> with WidgetsBindingObserver {
  // TEMP_SCREENSHOT_TOGGLE: remove this binding, its init/dispose, and import.
  late final TemporaryScreenshotOverride _screenshotOverride;
  VaultController get vault => widget.vault;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final current = WidgetsBinding.instance.lifecycleState;
    if (current != null) vault.onLifecycle(current);
    _screenshotOverride = TemporaryScreenshotOverride(vault);
    if (!vault.initialized) unawaited(vault.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      vault.onLifecycle(state);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenshotOverride.dispose();
    vault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vault,
    builder: (context, _) => MaterialApp(
      key: ValueKey((vault.locked, vault.session)),
      title: brandName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: jiaoTheme(Brightness.light),
      darkTheme: jiaoTheme(Brightness.dark),
      themeMode: vault.preferences.theme,
      builder: (context, child) {
        final hidden = !vault.foreground;
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: hidden,
              child: Offstage(offstage: hidden, child: child),
            ),
            if (hidden)
              const ColoredBox(
                color: Color(0xff0a0a0a),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xffa0a0a0),
                    size: 40,
                  ),
                ),
              ),
          ],
        );
      },
      home: vault.locked
          ? _LockScreen(vault: vault)
          : HomeScreen(vault: vault, files: widget.files),
    ),
  );
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.vault});
  final VaultController vault;

  @override
  Widget build(BuildContext context) {
    final result = vault.lastUnlock;
    final message = switch (result) {
      UnlockResult.needsDeviceLock => '请先在 Android 设置中启用锁屏 PIN、图案或密码。',
      UnlockResult.cancelled => '验证已取消，账号仍保持锁定。',
      UnlockResult.unavailable => '系统验证暂不可用。请检查设备锁屏设置后重试。',
      _ => '使用指纹或设备锁屏凭据查看验证码。',
    };
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const JiaoBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 72),
                    const SizedBox(height: 24),
                    Text(
                      brandName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '本机密钥库已锁定',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted(context)),
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (!vault.initialized || vault.authenticating)
                      const CircularProgressIndicator()
                    else
                      GlassSurface(
                        key: const Key('unlock'),
                        reduced: vault.preferences.reduceTransparency,
                        onTap: vault.unlock,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 23,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fingerprint_rounded),
                              SizedBox(width: 8),
                              Text('解锁'),
                            ],
                          ),
                        ),
                      ),
                    if (result == UnlockResult.needsDeviceLock)
                      TextButton(
                        onPressed: () async {
                          try {
                            await deviceChannel.invokeMethod<void>(
                              'openDeviceSecurity',
                            );
                          } on PlatformException {
                            if (context.mounted) {
                              showNotice(context, '请手动打开 Android 的安全设置。');
                            }
                          }
                        },
                        child: const Text('打开设备安全设置'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
