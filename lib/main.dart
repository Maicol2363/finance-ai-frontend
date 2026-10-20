import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/receipt_capture/data/receipt_photo_cache_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ReceiptPhotoCacheRepository().quarantineLegacyPhotos();
  } catch (_) {
    // Keep the app available if local storage is temporarily unavailable.
  }
  runApp(const ProviderScope(child: FinanceApp()));
}
