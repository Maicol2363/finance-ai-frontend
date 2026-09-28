import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../application/receipt_capture_notifier.dart';
import '../domain/receipt_capture_state.dart';
import 'screens/receipt_camera_screen.dart';
import 'screens/receipt_pre_check_screen.dart';

/// Starts the HU-015 receipt capture journey from a hub screen.
///
/// On mobile, [ImageSource.camera] opens the **in-app** camera
/// ([ReceiptCameraScreen], ChatGPT-style): preview, shutter, flip, torch and a
/// gallery shortcut all live inside the app — the native camera activity is
/// never launched. On desktop (no camera support) the native file dialog is
/// used instead. [ImageSource.gallery] always opens the platform picker.
///
/// When an image is chosen (from either source), [ReceiptPreCheckScreen] is
/// pushed where the user can rotate it, swap it, or send it to the AI
/// analysis.
///
/// The Riverpod container, navigator and messenger are resolved from [context]
/// before the first `await`: the camera/gallery activity suspends the app, so
/// the calling widget (e.g. the entry wheel) may already be unmounted by the
/// time the picker returns and `context` must not be touched afterwards.
Future<void> startReceiptCapture(
  BuildContext context, {
  required ImageSource source,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  if (source == ImageSource.camera && _supportsInAppCamera()) {
    final captured = await container.read(receiptCameraLauncherProvider)(
      navigator,
    );
    if (captured == null) {
      return; // User cancelled the in-app camera.
    }
    await container
        .read(receiptCaptureNotifierProvider.notifier)
        .useImageFile(captured);
  } else {
    await container
        .read(receiptCaptureNotifierProvider.notifier)
        .pickImage(_resolveSource(source));
  }

  if (!navigator.mounted) {
    return;
  }

  final state = container.read(receiptCaptureNotifierProvider);
  if (state is ReceiptCapturePreCheck) {
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const ReceiptPreCheckScreen()),
    );
  } else if (state is ReceiptCaptureError) {
    messenger.showSnackBar(SnackBar(content: Text(state.errorMessage)));
  }
}

/// The in-app `camera` plugin only runs on mobile: on desktop there is no
/// camera, so the native file dialog (gallery) is used instead.
bool _supportsInAppCamera() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// [ImageSource.camera] is only implemented on mobile: on desktop the native
/// file dialog (gallery) is used instead.
ImageSource _resolveSource(ImageSource source) {
  if (_supportsInAppCamera()) {
    return source;
  }
  return ImageSource.gallery;
}
