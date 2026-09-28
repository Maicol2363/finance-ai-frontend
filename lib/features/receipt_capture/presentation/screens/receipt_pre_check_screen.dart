import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/theme/app_palette.dart';
import '../../application/receipt_capture_notifier.dart';
import '../../domain/receipt_capture_state.dart';
import 'receipt_camera_screen.dart';
import 'receipt_review_screen.dart';

/// Opens the in-app camera to replace the current photo from
/// [ReceiptPreCheckScreen].
///
/// The container and navigator are captured before the first `await`: the
/// camera suspends the app and `context` must not be touched afterwards. On
/// success the watched capture state changes and the screen rebuilds with the
/// new photo.
Future<void> _retakeWithInAppCamera(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  final captured = await container.read(receiptCameraLauncherProvider)(
    navigator,
  );
  if (captured == null || !navigator.mounted) {
    return;
  }

  await container
      .read(receiptCaptureNotifierProvider.notifier)
      .useImageFile(captured);

  final state = container.read(receiptCaptureNotifierProvider);
  if (state is ReceiptCaptureError) {
    messenger.showSnackBar(
      SnackBar(content: Text(state.diagnostic.userMessage)),
    );
  }
}

class ReceiptPreCheckScreen extends ConsumerWidget {
  const ReceiptPreCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>() ?? AppPalette.light;
    final state = ref.watch(receiptCaptureNotifierProvider);
    final notifier = ref.read(receiptCaptureNotifierProvider.notifier);

    // Listen for transitions to Review or Error
    ref.listen<ReceiptCaptureState>(receiptCaptureNotifierProvider, (
      previous,
      next,
    ) {
      if (next is ReceiptCaptureReview) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const ReceiptReviewScreen()),
        );
      }
    });

    if (state is ReceiptCaptureAnalyzing) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: palette.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  'Analizando comprobante con IA...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Extrayendo comercio, total, fecha y productos del recibo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state is ReceiptCaptureError) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: const Text('Error al analizar'),
          backgroundColor: palette.card,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: palette.discard),
                const SizedBox(height: 16),
                Text(
                  'No se pudo completar el análisis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ErrorDiagnosticPanel(diagnostic: state.diagnostic),
                const SizedBox(height: 24),
                if (state.canRetry && state.localImagePath != null)
                  FilledButton.icon(
                    onPressed: () {
                      notifier.analyzeReceipt();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar análisis'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    notifier.reset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state is! ReceiptCapturePreCheck) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(title: const Text('Vista previa')),
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Seleccionar otra imagen'),
          ),
        ),
      );
    }

    final file = File(state.imagePath);
    final sizeMb = (state.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final turns = (state.rotationDegrees ~/ 90) % 4;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Vista previa del recibo'),
        backgroundColor: palette.card,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Rotar 90°',
            icon: const Icon(Icons.rotate_right),
            onPressed: () => notifier.rotatePreCheck(90),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Text(
                              'No se pudo cargar la vista previa',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: palette.card,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tamaño: $sizeMb MB',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => notifier.rotatePreCheck(90),
                        icon: const Icon(Icons.rotate_right, size: 18),
                        label: Text('Rotar (${state.rotationDegrees}°)'),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              notifier.pickImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('Galería'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.primary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _retakeWithInAppCamera(context),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Otra foto'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.primary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => notifier.analyzeReceipt(),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Analizar recibo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      notifier.reset();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: palette.muted,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
