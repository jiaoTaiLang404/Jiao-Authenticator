import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'backup_codec.dart';
import 'totp.dart';

const deviceChannel = MethodChannel('app.jiao.authenticator/device');

typedef QrCandidates = ({List<OtpAccount> accounts, String? error});

QrCandidates decodeQrValues(Iterable<String> values) {
  final accounts = <OtpAccount>[];
  final seen = <OtpIdentity>{};
  String? error;
  for (final value in values) {
    try {
      final account = parseOtpUri(value);
      if (seen.add(account.identity)) accounts.add(account);
    } on FormatException catch (exception) {
      error ??= exception.message;
    }
  }
  return (accounts: accounts, error: error);
}

class AndroidFiles {
  const AndroidFiles();

  Future<QrCandidates?> pickQrImage() async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    if (picked == null) return null;
    const limit = 20 * 1024 * 1024;
    Uint8List? bytes;
    Directory? dir;
    try {
      bytes = await _readBounded(picked, limit, '二维码图片超过 20 MB。');
      dir = await Directory.systemTemp.createTemp('jiao_qr_');
      final file = File('${dir.path}/scan_image');
      await file.writeAsBytes(bytes, flush: true);
      return await scanImagePath(file.path);
    } finally {
      if (dir != null) {
        final file = File('${dir.path}/scan_image');
        if (await file.exists()) await file.delete();
        await dir.delete();
      }
      bytes?.fillRange(0, bytes.length, 0);
      await FilePicker.clearTemporaryFiles();
    }
  }

  Future<QrCandidates> scanImagePath(String path) async {
    final controller = MobileScannerController(autoStart: false);
    try {
      final result = await controller.analyzeImage(
        path,
        formats: const [BarcodeFormat.qrCode],
      );
      return decodeQrValues(
        result?.barcodes.map((b) => b.rawValue).nonNulls ?? const [],
      );
    } finally {
      await controller.dispose();
    }
  }

  Future<Uint8List?> pickBackup() async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    try {
      return await _readBounded(picked, BackupCodec.maxBytes, '备份文件超过 10 MB。');
    } finally {
      await FilePicker.clearTemporaryFiles();
    }
  }

  Future<bool> saveBackup(Uint8List bytes) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return await FilePicker.saveFile(
          fileName: 'Jiao-$date.${BackupCodec.extension}',
          bytes: bytes,
          mimeType: 'application/octet-stream',
        ) !=
        null;
  }

  Future<Uint8List> _readBounded(
    PlatformFile file,
    int limit,
    String tooLarge,
  ) async {
    final knownLength = file.lengthSync();
    if (knownLength != null && knownLength > limit) {
      throw FormatException(tooLarge);
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (chunk.length > limit - buffer.length) throw FormatException(tooLarge);
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}
