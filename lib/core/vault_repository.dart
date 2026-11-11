import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'totp.dart';

abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class AndroidSecureStore implements LocalStore {
  AndroidSecureStore(String namespace)
    : _storage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: namespace,
          resetOnError: false,
          migrateOnAlgorithmChange: false,
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

final class AppPreferences {
  const AppPreferences({
    this.theme = ThemeMode.dark,
    this.lockEnabled = true,
    this.reduceTransparency = false,
    this.allowScreenshots = false,
  });

  factory AppPreferences.decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['v'] != 1 ||
        data['lock'] is! bool ||
        data['reduceTransparency'] is! bool ||
        !ThemeMode.values.any((mode) => mode.name == data['theme'])) {
      throw const FormatException('本机设置无法读取。');
    }
    return AppPreferences(
      theme: ThemeMode.values.byName(data['theme'] as String),
      lockEnabled: data['lock'] as bool,
      reduceTransparency: data['reduceTransparency'] as bool,
      allowScreenshots: data['allowScreenshots'] == true,
    );
  }

  final ThemeMode theme;
  final bool lockEnabled;
  final bool reduceTransparency;
  // TEMP_SCREENSHOT_TOGGLE: remove this field and its codec/copyWith entries.
  final bool allowScreenshots;

  AppPreferences copyWith({
    ThemeMode? theme,
    bool? lockEnabled,
    bool? reduceTransparency,
    bool? allowScreenshots,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    allowScreenshots: allowScreenshots ?? this.allowScreenshots,
  );

  String encode() => jsonEncode({
    'v': 1,
    'theme': theme.name,
    'lock': lockEnabled,
    'reduceTransparency': reduceTransparency,
    'allowScreenshots': allowScreenshots,
  });
}

typedef LoadedVault = ({List<OtpAccount> accounts, bool recovered});

final class VaultRepository {
  const VaultRepository({
    required this.primary,
    required this.recovery,
    required this.settings,
  });

  static const accountsKey = 'accounts_v1';
  static const preferencesKey = 'preferences_v1';
  final LocalStore primary;
  final LocalStore recovery;
  final LocalStore settings;

  Future<AppPreferences> loadPreferences() async {
    final raw = await settings.read(preferencesKey);
    return raw == null ? const AppPreferences() : AppPreferences.decode(raw);
  }

  Future<void> savePreferences(AppPreferences value) =>
      settings.write(preferencesKey, value.encode());

  Future<LoadedVault> load() async {
    final recovered = await recovery.read(accountsKey);
    if (recovered != null) {
      return (accounts: decodeAccounts(recovered), recovered: true);
    }
    final raw = await primary.read(accountsKey);
    return (
      accounts: raw == null ? const <OtpAccount>[] : decodeAccounts(raw),
      recovered: false,
    );
  }

  Future<void> save(List<OtpAccount> accounts, {required bool recovered}) =>
      (recovered ? recovery : primary).write(
        accountsKey,
        encodeAccounts(accounts),
      );
}

const maxAccounts = 2000;

String encodeAccounts(List<OtpAccount> accounts) {
  if (accounts.length > maxAccounts) {
    throw const FormatException('账号数量超过本机上限。');
  }
  return jsonEncode({
    'v': 1,
    'accounts': accounts.map((a) => a.toJson()).toList(),
  });
}

List<OtpAccount> decodeAccounts(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['v'] != 1 ||
        data['accounts'] is! List ||
        (data['accounts'] as List).length > maxAccounts) {
      throw const FormatException('账号数据格式无效。');
    }
    final accounts = (data['accounts'] as List)
        .map(OtpAccount.fromJson)
        .toList();
    if (accounts.map((a) => a.id).toSet().length != accounts.length) {
      throw const FormatException('账号标识冲突。');
    }
    return List.unmodifiable(accounts);
  } on FormatException {
    throw const FormatException('账号数据格式无效。');
  }
}

({List<OtpAccount> merged, int added, int skipped}) mergeAccounts(
  List<OtpAccount> current,
  List<OtpAccount> incoming,
) {
  final ids = current.map((a) => a.id).toSet();
  final identities = current.map((a) => a.identity).toSet();
  final merged = [...current];
  var added = 0;
  for (final account in incoming) {
    if (!identities.add(account.identity)) continue;
    var item = account;
    while (!ids.add(item.id)) {
      item = item.reidentify();
    }
    merged.add(item);
    added++;
  }
  return (merged: merged, added: added, skipped: incoming.length - added);
}
