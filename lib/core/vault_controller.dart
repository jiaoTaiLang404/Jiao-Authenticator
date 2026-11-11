import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'totp.dart';
import 'vault_repository.dart';

enum UnlockResult { accepted, cancelled, needsDeviceLock, unavailable }

typedef DeviceAuthentication = Future<UnlockResult> Function();

Future<UnlockResult> authenticateWithAndroid() async {
  try {
    final auth = LocalAuthentication();
    final accepted = await auth.authenticate(
      localizedReason: '解锁 Jiao Authenticator',
      biometricOnly: false,
    );
    return accepted ? UnlockResult.accepted : UnlockResult.cancelled;
  } on LocalAuthException catch (error) {
    return switch (error.code) {
      LocalAuthExceptionCode.noCredentialsSet => UnlockResult.needsDeviceLock,
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled => UnlockResult.cancelled,
      _ => UnlockResult.unavailable,
    };
  } on Exception {
    return UnlockResult.unavailable;
  }
}

final class VaultController extends ChangeNotifier {
  VaultController({
    required this.repository,
    required this.authenticate,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const lockDelay = Duration(seconds: 30);
  final VaultRepository repository;
  final DeviceAuthentication authenticate;
  final DateTime Function() now;

  AppPreferences preferences = const AppPreferences();
  List<OtpAccount> _accounts = const [];
  List<OtpAccount> get accounts => _accounts;
  bool initialized = false;
  bool foreground = true;
  bool locked = true;
  bool authenticating = false;
  bool loading = false;
  bool readFailed = false;
  bool settingsReadFailed = false;
  UnlockResult? lastUnlock;
  int session = 0;
  bool _recovered = false;
  bool _disposed = false;
  DateTime? _hiddenAt;
  DateTime? _pendingAuthorization;
  final Stopwatch _background = Stopwatch();
  Timer? _lockTimer;
  Future<void> _pending = Future<void>.value();

  Future<void> initialize() async {
    try {
      preferences = await repository.loadPreferences();
    } on Exception {
      settingsReadFailed = true;
    }
    if (_disposed) return;
    initialized = true;
    if (!preferences.lockEnabled) {
      locked = false;
      await _load();
    } else {
      _notify();
    }
  }

  Future<void> unlock() async {
    if (!initialized || !locked || authenticating || !foreground) return;
    authenticating = true;
    lastUnlock = null;
    _notify();
    final result = await authenticate();
    if (_disposed) return;
    authenticating = false;
    lastUnlock = result;
    if (result == UnlockResult.accepted && foreground) {
      await _enterVault();
    } else {
      if (result == UnlockResult.accepted) _pendingAuthorization = now();
      _notify();
    }
  }

  Future<void> _enterVault() async {
    locked = false;
    await _load();
  }

  Future<void> retryRead() => _load();

  Future<void> _load() async {
    if (locked || loading) return;
    final epoch = session;
    loading = true;
    _notify();
    await _pending;
    try {
      if (!isCurrent(epoch)) return;
      final value = await repository.load();
      if (!isCurrent(epoch)) return;
      _accounts = value.accounts;
      _recovered = value.recovered;
      readFailed = false;
    } on Exception {
      if (isCurrent(epoch)) readFailed = true;
    } finally {
      if (isCurrent(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  bool isCurrent(int epoch) => !_disposed && !locked && epoch == session;

  void onLifecycle(AppLifecycleState state) {
    if (_disposed) return;
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      final hidden = _hiddenAt;
      if (hidden != null &&
          preferences.lockEnabled &&
          (_background.elapsed >= lockDelay ||
              now().difference(hidden) >= lockDelay)) {
        lock();
      }
      _hiddenAt = null;
      _background
        ..stop()
        ..reset();
      _lockTimer?.cancel();
      final authorization = _pendingAuthorization;
      _pendingAuthorization = null;
      if (locked &&
          authorization != null &&
          now().difference(authorization) < lockDelay) {
        unawaited(_enterVault());
      }
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_hiddenAt == null) {
        _hiddenAt = now();
        _background
          ..reset()
          ..start();
        if (preferences.lockEnabled && !locked) {
          _lockTimer = Timer(lockDelay, lock);
        }
      }
    }
    _notify();
  }

  void lock() {
    if (_disposed || locked) return;
    locked = true;
    session++;
    _accounts = const [];
    _pendingAuthorization = null;
    readFailed = false;
    loading = false;
    lastUnlock = null;
    _lockTimer?.cancel();
    _notify();
  }

  Future<void> setPreferences(AppPreferences value) => _serial((epoch) async {
    if (settingsReadFailed) {
      throw const FormatException('本机设置无法读取，原设置已保留。');
    }
    if (value.lockEnabled != preferences.lockEnabled) {
      final result = await authenticate();
      if (result == UnlockResult.needsDeviceLock) {
        throw const FormatException('请先在 Android 设置中启用锁屏 PIN 或指纹。');
      }
      if (result != UnlockResult.accepted) {
        throw const FormatException('未完成系统验证，设置未更改。');
      }
      _ensure(epoch);
    }
    await repository.savePreferences(value);
    if (isCurrent(epoch)) {
      preferences = value;
      _notify();
    } else {
      // Preserve the persisted lock policy without restoring any vault data.
      preferences = value;
    }
  });

  Future<void> saveAccount(OtpAccount account, {bool editing = false}) =>
      _serial((epoch) async {
        _ensureWritable();
        if (_accounts.any(
          (a) => a.id != account.id && a.identity == account.identity,
        )) {
          throw const FormatException('已存在相同密钥和验证码参数的账号。');
        }
        final index = _accounts.indexWhere((a) => a.id == account.id);
        if (editing != (index >= 0)) {
          throw const FormatException('账号已更改，请重新打开。');
        }
        final next = [..._accounts];
        if (editing) {
          next[index] = account;
        } else {
          next.insert(0, account);
        }
        await _commit(next, epoch, recovered: _recovered);
      });

  Future<void> deleteAccount(String id) => _serial((epoch) async {
    _ensureWritable();
    final next = _accounts.where((a) => a.id != id).toList();
    if (next.length != _accounts.length) {
      await _commit(next, epoch, recovered: _recovered);
    }
  });

  Future<({int added, int skipped})> restore(
    List<OtpAccount> incoming, {
    required bool recoverUnreadable,
  }) => _serial((epoch) async {
    if (loading ||
        (readFailed && !recoverUnreadable) ||
        (!readFailed && recoverUnreadable)) {
      throw const FormatException('账号状态已变化，请重新预览备份。');
    }
    final result = mergeAccounts(_accounts, incoming);
    if (result.added > 0) {
      await _commit(result.merged, epoch, recovered: readFailed || _recovered);
    }
    return (added: result.added, skipped: result.skipped);
  });

  void _ensureWritable() {
    if (loading || readFailed) {
      throw const FormatException('请先重新读取账号或从加密备份恢复。');
    }
  }

  Future<void> _commit(
    List<OtpAccount> next,
    int epoch, {
    required bool recovered,
  }) async {
    await repository.save(next, recovered: recovered);
    if (!isCurrent(epoch)) return;
    _accounts = List.unmodifiable(next);
    _recovered = recovered;
    readFailed = false;
    _notify();
  }

  void _ensure(int epoch) {
    if (!isCurrent(epoch)) {
      throw const FormatException('会话已锁定，请解锁后重试。');
    }
  }

  Future<T> _serial<T>(Future<T> Function(int epoch) operation) {
    final epoch = session;
    final next = _pending.then((_) {
      _ensure(epoch);
      return operation(epoch);
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lockTimer?.cancel();
    _background.stop();
    _accounts = const [];
    super.dispose();
  }
}
