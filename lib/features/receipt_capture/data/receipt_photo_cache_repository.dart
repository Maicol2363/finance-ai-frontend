import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final receiptPhotoCacheRepositoryProvider =
    Provider<ReceiptPhotoCacheRepository>((ref) {
      return ReceiptPhotoCacheRepository();
    });

/// Keeps the receipt photo of a confirmed expense on the device.
///
/// Confirmed photos live in the application documents directory
/// (`<app documents>/receipts/<expenseId>.jpg`) so the expense detail screen can
/// reopen them offline - the backend keeps no image at all. Because that folder
/// is permanent (and can be included in device backups), the photo is deleted
/// when its expense is deleted.
class ReceiptPhotoCacheRepository {
  Future<Directory> _getReceiptsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${appDir.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Copies an image file into the app documents folder for the confirmed expense.
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
