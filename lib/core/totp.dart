import 'dart:math';
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart';

enum TotpAlgorithm {
  sha1('SHA1'),
  sha256('SHA256'),
  sha512('SHA512');

  const TotpAlgorithm(this.label);
  final String label;

  static TotpAlgorithm parse(String value) {
    final name = value.trim().toUpperCase().replaceAll('-', '');
    for (final algorithm in values) {
      if (algorithm.label == name) return algorithm;
    }
    throw const FormatException('仅支持 SHA1、SHA256 或 SHA512。');
  }

  Hash get hash => switch (this) {
    sha1 => packageSha1,
    sha256 => packageSha256,
    sha512 => packageSha512,
  };
}

final packageSha1 = sha1;
final packageSha256 = sha256;
final packageSha512 = sha512;

typedef OtpIdentity = (String, TotpAlgorithm, int, int);

final class OtpAccount {
  const OtpAccount._({
    required this.id,
    required this.issuer,
    required this.label,
    required this.secret,
    required this.algorithm,
    required this.digits,
    required this.period,
    required this.createdAt,
  });

  factory OtpAccount.create({
    required String issuer,
    required String label,
    required String secret,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = 6,
    int period = 30,
    String? id,
    int? createdAt,
  }) {
    final normalizedId = id ?? _newId();
    final timestamp = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(normalizedId) || timestamp < 0) {
      throw const FormatException('账号记录无效。');
    }
    if (digits != 6 && digits != 8) {
      throw const FormatException('验证码位数只能为 6 或 8。');
    }
    if (period < 1 || period > 3600) {
      throw const FormatException('刷新周期须为 1 至 3600 秒。');
    }
    return OtpAccount._(
      id: normalizedId,
      issuer: _name(issuer, '服务名称'),
      label: _name(label, '账号'),
      secret: normalizeSecret(secret),
      algorithm: algorithm,
      digits: digits,
      period: period,
      createdAt: timestamp,
    );
  }

  factory OtpAccount.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['id'] is! String ||
        raw['issuer'] is! String ||
        raw['label'] is! String ||
        raw['secret'] is! String ||
        raw['algorithm'] is! String ||
        raw['digits'] is! int ||
        raw['period'] is! int ||
        raw['createdAt'] is! int) {
      throw const FormatException('账号记录无效。');
    }
    return OtpAccount.create(
      id: raw['id'] as String,
      issuer: raw['issuer'] as String,
      label: raw['label'] as String,
      secret: raw['secret'] as String,
      algorithm: TotpAlgorithm.parse(raw['algorithm'] as String),
      digits: raw['digits'] as int,
      period: raw['period'] as int,
      createdAt: raw['createdAt'] as int,
    );
  }

  final String id;
  final String issuer;
  final String label;
  final String secret;
  final TotpAlgorithm algorithm;
  final int digits;
  final int period;
  final int createdAt;

  OtpIdentity get identity => (secret, algorithm, digits, period);

  OtpAccount reidentify() => OtpAccount._(
    id: _newId(),
    issuer: issuer,
    label: label,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
    createdAt: createdAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'issuer': issuer,
    'label': label,
    'secret': secret,
    'algorithm': algorithm.label,
    'digits': digits,
    'period': period,
    'createdAt': createdAt,
  };

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _name(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty ||
        clean.length > 160 ||
        RegExp(r'[\x00-\x1F\x7F\u202A-\u202E\u2066-\u2069]').hasMatch(clean)) {
      throw FormatException('请填写有效的$field（最多 160 字符）。');
    }
    return clean;
  }
}

String normalizeSecret(String input) {
  const bad = FormatException('请输入有效的 Base32 密钥。');
  if (input.length > 2048) throw bad;
  final clean = input.replaceAll(RegExp(r'[ \t\r\n]'), '').toUpperCase();
  if (!RegExp(r'^[A-Z2-7]{2,512}={0,6}$').hasMatch(clean)) throw bad;
  final bare = clean.replaceFirst(RegExp(r'=+$'), '');
  try {
    final padded = bare.padRight((bare.length + 7) ~/ 8 * 8, '=');
    final decoded = base32.decode(padded);
    final canonical = base32.encode(decoded);
    if (decoded.isEmpty ||
        canonical.replaceFirst(RegExp(r'=+$'), '') != bare ||
        (clean != bare && clean != canonical)) {
      throw bad;
    }
    return bare;
  } on Exception {
    throw bad;
  }
}

OtpAccount parseOtpUri(String input) {
  if (input.length > 4096) throw const FormatException('二维码内容过长。');
  final raw = input.trim();
  if (raw.toLowerCase().startsWith('otpauth-migration:')) {
    throw const FormatException('这是批量迁移码。请使用服务提供的单账号二维码。');
  }
  late Uri uri;
  late Map<String, List<String>> query;
  late List<String> path;
  try {
    uri = Uri.parse(raw);
    query = uri.queryParametersAll;
    path = uri.pathSegments;
  } on FormatException {
    throw const FormatException('二维码格式无效。');
  }
  if (uri.scheme != 'otpauth' ||
      uri.host != 'totp' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      path.length != 1 ||
      path.single.isEmpty) {
    throw const FormatException('请选择标准 TOTP 账号二维码。');
  }
  String? param(String key) {
    final values = query[key];
    if (values == null) return null;
    if (values.length != 1 || values.single.trim().isEmpty) {
      throw const FormatException('二维码包含无效或重复的参数。');
    }
    return values.single;
  }

  int numeric(String key, int fallback) {
    final value = param(key);
    if (value == null) return fallback;
    final number = int.tryParse(value, radix: 10);
    if (number == null) throw const FormatException('二维码包含无效的数字参数。');
    return number;
  }

  final label = path.single;
  final colon = label.indexOf(':');
  final prefix = colon < 0 ? null : label.substring(0, colon).trim();
  final issuer = param('issuer')?.trim();
  if (prefix != null && issuer != null && prefix != issuer) {
    throw const FormatException('二维码中的服务名称不一致。');
  }
  return OtpAccount.create(
    issuer: issuer ?? prefix ?? '未命名服务',
    label: colon < 0 ? label : label.substring(colon + 1),
    secret: param('secret') ?? '',
    algorithm: TotpAlgorithm.parse(param('algorithm') ?? 'SHA1'),
    digits: numeric('digits', 6),
    period: numeric('period', 30),
  );
}

final class TotpSnapshot {
  const TotpSnapshot(this.code, this.remaining);
  final String code;
  final int remaining;

  String get formatted {
    final half = code.length ~/ 2;
    return '${code.substring(0, half)} ${code.substring(half)}';
  }
}

final class TotpService {
  const TotpService();

  TotpSnapshot nextAt(OtpAccount account, int unixMilliseconds) {
    final seconds = max(0, unixMilliseconds) ~/ 1000;
    final nextBoundary =
        (seconds ~/ account.period + 1) * account.period * 1000;
    return at(account, nextBoundary);
  }

  TotpSnapshot at(OtpAccount account, int unixMilliseconds) {
    final seconds = max(0, unixMilliseconds) ~/ 1000;
    final step = seconds ~/ account.period;
    final message = ByteData(8)..setUint64(0, step, Endian.big);
    final secret = account.secret.padRight(
      (account.secret.length + 7) ~/ 8 * 8,
      '=',
    );
    final key = base32.decode(secret);
    try {
      final bytes = Hmac(
        account.algorithm.hash,
        key,
      ).convert(message.buffer.asUint8List()).bytes;
      final offset = bytes.last & 15;
      final value =
          ((bytes[offset] & 127) << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      final divisor = account.digits == 6 ? 1000000 : 100000000;
      return TotpSnapshot(
        (value % divisor).toString().padLeft(account.digits, '0'),
        account.period - seconds % account.period,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
