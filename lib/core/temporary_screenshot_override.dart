import 'dart:async';

import 'package:flutter/services.dart';

import 'android_files.dart';
import 'vault_controller.dart';

// TEMP_SCREENSHOT_TOGGLE: delete this file when retiring screenshot testing.
final class TemporaryScreenshotOverride {
  TemporaryScreenshotOverride(this._vault) {
    _vault.addListener(_sync);
    _sync();
  }

  final VaultController _vault;
  bool _allowed = false;

  void _sync() {
    _setAllowed(
      _vault.initialized &&
          _vault.foreground &&
          !_vault.locked &&
          !_vault.loading &&
          !_vault.readFailed &&
          !_vault.settingsReadFailed &&
          _vault.preferences.allowScreenshots,
    );
  }

  void _setAllowed(bool allowed) {
    if (_allowed == allowed) return;
    _allowed = allowed;
    unawaited(_apply(allowed));
  }

  Future<void> _apply(bool allowed) async {
    try {
      await deviceChannel.invokeMethod<void>('setScreenshotAllowed', allowed);
    } on PlatformException {
      // The Android window is secure by default.
    } on MissingPluginException {
      // Widget tests and non-Android hosts have no Android window.
    }
  }

  void dispose() {
    _vault.removeListener(_sync);
    _setAllowed(false);
  }
}
