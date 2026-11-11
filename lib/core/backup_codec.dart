import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'totp.dart';
import 'vault_repository.dart';

final class BackupCodec {
  const BackupCodec();

  static const maxBytes = 10 * 1024 * 1024;
  static const extension = 'jiaoauth';
  static const _iterations = 600000;
  static const _version = 1;
  static const _magic = <int>[74, 73, 65, 79, 65, 85, 84, 72]; // JIAOAUTH
  static const _saltStart = 9;
  static const _nonceStart = _saltStart + 16;
  static const _tagStart = _nonceStart + 12;
  static const _payloadStart = _tagStart + 16;

  Future<Uint8List> export(List<OtpAccount> accounts, String password) {
    checkPassword(password);
    return Isolate.run(() => _encrypt(accounts, password));
  }

  Future<List<OtpAccount>> restore(Uint8List file, String password) {
    _checkHeader(file);
    if (password.isEmpty || password.runes.length > 256) {
      throw const FormatException('请输入备份口令。');
    }
    return Isolate.run(() => _decrypt(file, password));
  }

  static void checkPassword(String password) {
    if (password.runes.length < 12 ||
        password.runes.length > 256 ||
        password.trim().isEmpty) {
      throw const FormatException('备份口令须为 12 至 256 个字符。');
    }
  }

  static Future<SecretKey> _derive(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  static Future<Uint8List> _encrypt(
    List<OtpAccount> accounts,
    String password,
  ) async {
    final plain = Uint8List.fromList(utf8.encode(encodeAccounts(accounts)));
    SecretKey? key;
    try {
      if (plain.length + _payloadStart > maxBytes) {
        throw const FormatException('备份文件超过 10 MB。');
      }
      final random = Random.secure();
      final header = Uint8List.fromList([
        ..._magic,
        _version,
        ...List.generate(28, (_) => random.nextInt(256)),
      ]);
      key = await _derive(password, header.sublist(_saltStart, _nonceStart));
      final box = await AesGcm.with256bits().encrypt(
        plain,
        secretKey: key,
        nonce: header.sublist(_nonceStart),
        aad: header,
      );
      return Uint8List.fromList([
        ...header,
        ...box.mac.bytes,
        ...box.cipherText,
      ]);
    } finally {
      plain.fillRange(0, plain.length, 0);
      key?.destroy();
    }
  }

  static void _checkHeader(Uint8List file) {
    if (file.length > maxBytes) throw const FormatException('备份文件超过 10 MB。');
    if (file.length <= _payloadStart ||
        _magic.indexed.any((part) => file[part.$1] != part.$2)) {
      throw const FormatException('这不是有效的 Jiao Authenticator 备份。');
    }
    if (file[_magic.length] != _version) {
      throw const FormatException('此版本暂不支持这个备份格式。');
    }
  }

  static Future<List<OtpAccount>> _decrypt(
    Uint8List file,
    String password,
  ) async {
    final key = await _derive(password, file.sublist(_saltStart, _nonceStart));
    List<int>? plain;
    try {
      final box = SecretBox(
        Uint8List.sublistView(file, _payloadStart),
        nonce: Uint8List.sublistView(file, _nonceStart, _tagStart),
        mac: Mac(Uint8List.sublistView(file, _tagStart, _payloadStart)),
      );
      plain = await AesGcm.with256bits().decrypt(
        box,
        secretKey: key,
        aad: Uint8List.sublistView(file, 0, _tagStart),
      );
      return decodeAccounts(utf8.decode(plain));
    } on SecretBoxAuthenticationError {
      throw const FormatException('备份口令错误，或文件已损坏。');
    } on FormatException {
      throw const FormatException('备份中的账号数据无效。');
    } finally {
      if (plain is Uint8List) plain.fillRange(0, plain.length, 0);
      key.destroy();
    }
  }
}
