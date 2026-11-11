import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jiao_authenticator/core/android_files.dart';
import 'package:jiao_authenticator/core/backup_codec.dart';
import 'package:jiao_authenticator/core/totp.dart';
import 'package:jiao_authenticator/core/vault_controller.dart';
import 'package:jiao_authenticator/core/vault_repository.dart';
import 'package:jiao_authenticator/main.dart';
import 'package:jiao_authenticator/ui/account_screens.dart';
import 'package:jiao_authenticator/ui/jiao_theme.dart';

import 'qr_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android offline QR, secure vault, encrypted SAF backup and recovery',
    (tester) async {
      const prefix = 'jiao-integration';
      const files = AndroidFiles();
      final namespaces = [
        for (final name in ['primary', 'recovery', 'settings']) '$prefix-$name',
      ];
      Future<void> clean() async {
        for (final name in namespaces) {
          await FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: name,
              resetOnError: false,
              migrateOnAlgorithmChange: false,
            ),
          ).deleteAll();
        }
      }

      await clean();
      final repository = VaultRepository(
        primary: AndroidSecureStore(namespaces[0]),
        recovery: AndroidSecureStore(namespaces[1]),
        settings: AndroidSecureStore(namespaces[2]),
      );
      final vault = VaultController(
        repository: repository,
        authenticate: () async => UnlockResult.accepted,
      );
      final directory = await Directory.systemTemp.createTemp(
        'jiao_integration_',
      );
      try {
        debugPrint('NATIVE_STEP=secure-store');
        await vault.initialize();
        expect(vault.locked, isTrue);
        await vault.unlock();
        expect(vault.readFailed, isFalse);
        await tester.pumpWidget(JiaoApp(vault: vault));
        await tester.pumpAndSettle();

        debugPrint('NATIVE_STEP=image-picker');
        final imagePicked = await files.pickQrImage();
        expect(imagePicked?.accounts.length, 1);
        if (vault.locked) await vault.unlock();
        await tester.pumpAndSettle();

        final singleFile = File('${directory.path}/single.png');
        await singleFile.writeAsBytes(base64Decode(singleQrPng));
        final single = await files.scanImagePath(singleFile.path);
        expect(single.accounts.length, 1);
        await vault.saveAccount(single.accounts.single);
        final multiFile = File('${directory.path}/multi.png');
        await multiFile.writeAsBytes(base64Decode(multiQrPng));
        final multi = await files.scanImagePath(multiFile.path);
        expect(multi.accounts.length, 2);
        final merge = await vault.restore(
          multi.accounts,
          recoverUnreadable: false,
        );
        expect((merge.added, merge.skipped), (1, 1));
        final reloaded = await repository.load();
        expect(reloaded.accounts.length, 2);
        final seed = reloaded.accounts.first.secret;

        final preferencesDirectory = Directory(
          '/data/user/0/app.jiao.authenticator/shared_prefs',
        );
        for (final file in preferencesDirectory.listSync().whereType<File>()) {
          if (!file.path.endsWith('.xml')) continue;
          expect((await file.readAsString()).contains(seed), isFalse);
        }
        await tester.pumpAndSettle();
        expect(find.text('Next'), findsWidgets);

        debugPrint('NATIVE_STEP=backup-encryption');
        const password = 'Synthetic integration passphrase 2026!';
        final bytes = await const BackupCodec().export(
          vault.accounts,
          password,
        );
        debugPrint('NATIVE_STEP=save-file');
        final saved = await files.saveBackup(bytes);
        expect(saved, isTrue);
        if (vault.locked) await vault.unlock();
        await tester.pumpAndSettle();

        debugPrint('NATIVE_STEP=open-file');
        final picked = await files.pickBackup();
        expect(picked, isNotNull);
        expect(picked, orderedEquals(bytes));
        final restored = await const BackupCodec().restore(picked!, password);
        if (vault.locked) await vault.unlock();
        final duplicates = await vault.restore(
          restored,
          recoverUnreadable: false,
        );
        expect((duplicates.added, duplicates.skipped), (0, 2));
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        for (var index = 0; index < restored.length; index++) {
          expect(
            const TotpService().at(restored[index], timestamp).code,
            const TotpService().at(vault.accounts[index], timestamp).code,
          );
        }

        vault.lock();
        expect(vault.accounts, isEmpty);
        await vault.unlock();
        expect(vault.accounts.length, 2);
        await tester.pumpAndSettle();
        debugPrint('NATIVE_STEP=clipboard');
        final code = const TotpService()
            .at(vault.accounts.first, timestamp)
            .code;
        await deviceChannel.invokeMethod<void>('copyCode', code);
        expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, code);
        await Clipboard.setData(
          const ClipboardData(text: 'synthetic-user-clipboard'),
        );
        await Future<void>.delayed(const Duration(seconds: 31));
        expect(
          (await Clipboard.getData(Clipboard.kTextPlain))?.text,
          'synthetic-user-clipboard',
        );
        await deviceChannel.invokeMethod<void>('copyCode', code);
        await Future<void>.delayed(const Duration(seconds: 31));
        expect(
          (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '',
          isEmpty,
        );
        debugPrint('NATIVE_CORE_PASSED');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final file in directory.listSync().whereType<File>()) {
          await file.delete();
        }
        await directory.delete();
        await clean();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets('actual Android device credential authentication succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: jiaoTheme(Brightness.dark),
        home: const Scaffold(body: Center(child: Text('系统验证测试'))),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('NATIVE_STEP=device-auth');
    expect(await authenticateWithAndroid(), UnlockResult.accepted);
    debugPrint('NATIVE_AUTH_PASSED');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
    'camera permission denial leaves other import methods available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: jiaoTheme(Brightness.dark),
          home: const CameraScreen(),
        ),
      );
      debugPrint('NATIVE_STEP=camera-permission');
      for (var count = 0; count < 45; count++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.textContaining('相机不可用').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('相机不可用'), findsOneWidget);
      expect(find.text('返回添加方式'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      debugPrint('NATIVE_CAMERA_DENIAL_PASSED');
      debugPrint('NATIVE_ALL_DONE');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
