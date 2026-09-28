import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final receiptPhotoCacheRepositoryProvider =
    Provider<ReceiptPhotoCacheRepository>((ref) {
      return ReceiptPhotoCacheRepository();
    });

class ReceiptPhotoCacheRepository {
  Future<Directory> _getReceiptsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${appDir.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Copies an image file into the application temporary cache directory for the confirmed expense.
  Future<String> saveReceiptPhoto({
    required int expenseId,
    required String sourceFilePath,
  }) async {
    final dir = await _getReceiptsDirectory();
    final targetPath = '${dir.path}/$expenseId.jpg';
    final targetFile = await File(sourceFilePath).copy(targetPath);
    return targetFile.path;
  }

  /// Retrieves the cached image file for a confirmed expense if it exists.
  Future<File?> getCachedReceiptPhoto(int expenseId) async {
    final dir = await _getReceiptsDirectory();
    final file = File('${dir.path}/$expenseId.jpg');
    return await file.exists() ? file : null;
  }

  /// Deletes the cached receipt photo when an expense is deleted.
  Future<void> deleteCachedReceiptPhoto(int expenseId) async {
    final file = await getCachedReceiptPhoto(expenseId);
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }
}
