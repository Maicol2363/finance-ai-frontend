import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

final receiptPhotoCacheRepositoryProvider =
    Provider<ReceiptPhotoCacheRepository>((ref) {
      return ReceiptPhotoCacheRepository();
    });

/// Keeps confirmed receipt photos encrypted and scoped to the signed-in user.
class ReceiptPhotoCacheRepository {
  ReceiptPhotoCacheRepository({
    FlutterSecureStorage? keyStorage,
    Future<Directory> Function()? documentsDirectory,
  }) : _keyStorage = keyStorage ?? const FlutterSecureStorage(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const _version = 1;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _keyPrefix = 'finance_ai.receipt_photo_key.';

  final FlutterSecureStorage _keyStorage;
  final Future<Directory> Function() _documentsDirectory;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<Directory> _receiptsDirectory() async {
    final appDir = await _documentsDirectory();
    final receiptsDir = Directory('${appDir.path}/receipts');
    await receiptsDir.create(recursive: true);
    return receiptsDir;
  }

  Future<SecretKey?> _keyFor(String owner, {required bool create}) async {
    final name = '$_keyPrefix$owner';
    final stored = await _keyStorage.read(key: name);
    if (stored != null) {
      final bytes = base64Decode(stored);
      if (bytes.length != 32) {
        throw const FormatException('Invalid receipt photo key');
      }
      return SecretKey(bytes);
    }
    if (!create) return null;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _keyStorage.write(key: name, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<void> _writeEncrypted(
    File target,
    List<int> photo,
    SecretKey key,
  ) async {
    final random = Random.secure();
    final nonce = List<int>.generate(_nonceLength, (_) => random.nextInt(256));
    final box = await _cipher.encrypt(photo, secretKey: key, nonce: nonce);
    final encrypted = <int>[
      _version,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(encrypted, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<Uint8List> _readEncrypted(File file, SecretKey key) async {
    final data = await file.readAsBytes();
    if (data.length < 1 + _nonceLength + _macLength || data.first != _version) {
      throw const FormatException('Invalid encrypted receipt photo');
    }
    final box = SecretBox(
      data.sublist(1 + _nonceLength + _macLength),
      nonce: data.sublist(1, 1 + _nonceLength),
      mac: Mac(data.sublist(1 + _nonceLength, 1 + _nonceLength + _macLength)),
    );
    return Uint8List.fromList(await _cipher.decrypt(box, secretKey: key));
  }

  /// Old JPEG files have no owner information. Preserve them encrypted without
  /// making them visible to any account until ownership can be established.
  Future<void> quarantineLegacyPhotos() async {
    final directory = await _receiptsDirectory();
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.jpg')) continue;
      final key = await _keyFor('legacy', create: true);
      final name = entry.uri.pathSegments.last;
      final target = File('${directory.path}/legacy/$name.enc');
      await _writeEncrypted(target, await entry.readAsBytes(), key!);
      await entry.delete();
    }
  }

  Future<String> saveReceiptPhoto({
    required int userId,
    required int expenseId,
    required String sourceFilePath,
  }) async {
    final directory = await _receiptsDirectory();
    final key = await _keyFor('$userId', create: true);
    final target = File('${directory.path}/$userId/$expenseId.receipt');
    await _writeEncrypted(
      target,
      await File(sourceFilePath).readAsBytes(),
      key!,
    );
    return target.path;
  }

  Future<Uint8List?> getCachedReceiptPhoto({
    required int userId,
    required int expenseId,
  }) async {
    final directory = await _receiptsDirectory();
    final file = File('${directory.path}/$userId/$expenseId.receipt');
    if (!await file.exists()) return null;
    final key = await _keyFor('$userId', create: false);
    if (key == null) return null;
    return _readEncrypted(file, key);
  }

  Future<void> deleteCachedReceiptPhoto({
    required int userId,
    required int expenseId,
  }) async {
    final directory = await _receiptsDirectory();
    final file = File('${directory.path}/$userId/$expenseId.receipt');
    if (await file.exists()) await file.delete();

    // Legacy images had no owner ID. Their expense-ID filename is the only
    // association available, so a definitive deletion also purges that entry.
    final legacyFile = File('${directory.path}/legacy/$expenseId.jpg.enc');
    if (await legacyFile.exists()) await legacyFile.delete();
  }
}
