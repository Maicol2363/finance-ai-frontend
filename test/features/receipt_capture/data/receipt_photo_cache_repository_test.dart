import 'dart:io';

import 'package:finance_ai/features/receipt_capture/data/receipt_photo_cache_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documents;
  late ReceiptPhotoCacheRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('receipt_photo_test_');
    repository = ReceiptPhotoCacheRepository(
      documentsDirectory: () async => documents,
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
  });

  test(
    'encrypts photos and isolates the same expense ID across users',
    () async {
      final source = File('${documents.path}/source.jpg');
      final firstPhoto = List<int>.generate(64, (index) => index);
      await source.writeAsBytes(firstPhoto);
      final firstPath = await repository.saveReceiptPhoto(
        userId: 1,
        expenseId: 7,
        sourceFilePath: source.path,
      );

      expect(await File(firstPath).readAsBytes(), isNot(firstPhoto));
      expect(
        await repository.getCachedReceiptPhoto(userId: 1, expenseId: 7),
        firstPhoto,
      );
      expect(
        await repository.getCachedReceiptPhoto(userId: 2, expenseId: 7),
        isNull,
      );

      final secondPhoto = List<int>.generate(64, (index) => 255 - index);
      await source.writeAsBytes(secondPhoto);
      await repository.saveReceiptPhoto(
        userId: 2,
        expenseId: 7,
        sourceFilePath: source.path,
      );
      expect(
        await repository.getCachedReceiptPhoto(userId: 1, expenseId: 7),
        firstPhoto,
      );
      expect(
        await repository.getCachedReceiptPhoto(userId: 2, expenseId: 7),
        secondPhoto,
      );

      await repository.deleteCachedReceiptPhoto(userId: 1, expenseId: 7);
      expect(
        await repository.getCachedReceiptPhoto(userId: 1, expenseId: 7),
        isNull,
      );
      expect(
        await repository.getCachedReceiptPhoto(userId: 2, expenseId: 7),
        secondPhoto,
      );
    },
  );

  test('rejects modified ciphertext', () async {
    final source = File('${documents.path}/source.jpg');
    await source.writeAsBytes(List<int>.filled(64, 42));
    final path = await repository.saveReceiptPhoto(
      userId: 1,
      expenseId: 7,
      sourceFilePath: source.path,
    );
    final encrypted = await File(path).readAsBytes();
    encrypted[encrypted.length - 1] ^= 1;
    await File(path).writeAsBytes(encrypted);

    expect(
      repository.getCachedReceiptPhoto(userId: 1, expenseId: 7),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'quarantines unowned legacy JPEGs without exposing them to users',
    () async {
      final receipts = Directory('${documents.path}/receipts');
      await receipts.create();
      final legacy = File('${receipts.path}/7.jpg');
      final photo = List<int>.generate(64, (index) => index);
      await legacy.writeAsBytes(photo);

      await repository.quarantineLegacyPhotos();

      expect(await legacy.exists(), isFalse);
      final encrypted = File('${receipts.path}/legacy/7.jpg.enc');
      expect(await encrypted.exists(), isTrue);
      expect(await encrypted.readAsBytes(), isNot(photo));
      expect(
        await repository.getCachedReceiptPhoto(userId: 1, expenseId: 7),
        isNull,
      );
    },
  );

  test(
    'deleting an expense also purges its quarantined legacy photo',
    () async {
      final receipts = Directory('${documents.path}/receipts');
      await receipts.create();
      final legacy = File('${receipts.path}/7.jpg');
      await legacy.writeAsBytes(List<int>.generate(64, (index) => index));

      await repository.quarantineLegacyPhotos();
      final quarantined = File('${receipts.path}/legacy/7.jpg.enc');
      expect(await quarantined.exists(), isTrue);

      await repository.deleteCachedReceiptPhoto(userId: 42, expenseId: 7);

      expect(await quarantined.exists(), isFalse);
    },
  );
}
