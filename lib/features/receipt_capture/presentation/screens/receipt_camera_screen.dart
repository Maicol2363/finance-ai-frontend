import 'package:finance_ai/core/icons/finance_icon_catalog.dart';

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/receipt_capture_notifier.dart';
import '../../data/receipt_photo_guide_prefs.dart';
import '../widgets/receipt_photo_guide_dialog.dart';

/// Signature of the strategy that opens the in-app camera and resolves with
/// the captured (or gallery selected) image, or null when the user cancels.
///
/// Injectable through [receiptCameraLauncherProvider] so widget tests can
/// simulate captures without a real camera device.
typedef ReceiptCameraLauncher = Future<XFile?> Function(
  NavigatorState navigator,
);

/// Default launcher: pushes [ReceiptCameraScreen] on [navigator].
final receiptCameraLauncherProvider = Provider<ReceiptCameraLauncher>((ref) {
  return (navigator) => navigator.push<XFile>(
    MaterialPageRoute(builder: (_) => const ReceiptCameraScreen()),
  );
});

/// Full-screen, in-app receipt camera (ChatGPT-style): the preview, shutter,
/// flip, torch and gallery actions all live inside the app, so the native
/// camera activity is never opened.
///
/// Resolves with the chosen [XFile] via `Navigator.pop`, or null when the
/// user backs out without selecting an image.
class ReceiptCameraScreen extends ConsumerStatefulWidget {
  const ReceiptCameraScreen({super.key});

  @override
  ConsumerState<ReceiptCameraScreen> createState() =>
      _ReceiptCameraScreenState();
}

class _ReceiptCameraScreenState extends ConsumerState<ReceiptCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _torchOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowGuide());
  }

  /// Shows the one-time photo guide ("cómo tomar una buena foto").
  ///
  /// Persisted via [ReceiptPhotoGuidePrefs] so it appears only once per
  /// device. Fail-open: if storage fails the guide is shown again instead
  /// of blocking capture.
  Future<void> _maybeShowGuide() async {
    if (!mounted) return;
    final shouldShow = await ReceiptPhotoGuidePrefs.shouldShowGuide();
    if (!mounted || !shouldShow) return;
    await _showPhotoGuide(markGuideSeen: true);
  }

  Future<void> _showPhotoGuide({required bool markGuideSeen}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ReceiptPhotoGuideDialog(
        onConfirm: () => Navigator.of(dialogContext).pop(),
      ),
    );
    if (markGuideSeen) {
      await ReceiptPhotoGuidePrefs.markGuideSeen();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera while the app is backgrounded (e.g. when the gallery
    // picker takes over) and re-open it on resume.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _errorMessage == null) {
      _openCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose().catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> _openCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _errorMessage = 'No se encontró ninguna cámara en este dispositivo.';
        });
        return;
      }

      _cameras = cameras;
      if (_cameraIndex >= cameras.length) {
        _cameraIndex = 0;
      }

      final controller = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false, // No RECORD_AUDIO permission required for photos.
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      if (_torchOn) {
        await controller.setFlashMode(FlashMode.torch);
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = _friendlyCameraError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = 'No se pudo abrir la cámara. Inténtalo de nuevo.';
      });
    }
  }

  String _friendlyCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'No se otorgó permiso para usar la cámara. Puedes concederlo '
            'en Ajustes o elegir una imagen de la galería.';
      case 'NoCameraAvailable':
        return 'No se encontró ninguna cámara en este dispositivo.';
      default:
        return 'No se pudo abrir la cámara. Inténtalo de nuevo.';
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        // Disposal races (e.g. already disposed) are non-blocking.
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _initializing) return;
    setState(() => _initializing = true);
    await _disposeController();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (_torchOn) {
        await controller.setFlashMode(FlashMode.off);
      } else {
        await controller.setFlashMode(FlashMode.torch);
      }
      if (mounted) {
        setState(() => _torchOn = !_torchOn);
      }
    } on CameraException {
      // Torch unsupported on this device: keep the current UI state.
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _initializing) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo tomar la foto. Reintenta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildBody()),
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _buildErrorBody(errorMessage);
    }

    final controller = _controller;
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Abriendo cámara...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildErrorBody(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              FinanceIcons.photoCameraOutlined,
              size: 56,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _openCamera,
              style: FilledButton.styleFrom(backgroundColor: Colors.white),
              child: const Text(
                'Reintentar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickFromGallery,
              child: const Text(
                'Elegir de la galería',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _glassButton(
                icon: FinanceIcons.close,
                tooltip: 'Cerrar',
                onTap: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'Escanear recibo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _glassButton(
                icon: FinanceIcons.infoOutline,
                tooltip: 'Cómo tomar una buena foto',
                semanticLabel: 'Ayuda: cómo tomar una buena foto',
                onTap: () => _showPhotoGuide(markGuideSeen: false),
              ),
              _glassButton(
                icon: _torchOn
                    ? FinanceIcons.flashlightOn
                    : FinanceIcons.flashlightOff,
                tooltip: 'Linterna',
                onTap: _toggleTorch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _glassButton(
                icon: FinanceIcons.photoLibraryOutlined,
                tooltip: 'Galería',
                onTap: _pickFromGallery,
              ),
              _buildShutter(),
              _glassButton(
                icon: FinanceIcons.cameraswitchOutlined,
                tooltip: 'Cambiar cámara',
                onTap: _flipCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShutter() {
    final controller = _controller;
    final canCapture =
        !_initializing &&
        !_capturing &&
        controller != null &&
        controller.value.isInitialized;
    return Semantics(
      button: true,
      label: 'Tomar foto del recibo',
      enabled: canCapture,
      onTap: canCapture ? _capturePhoto : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: canCapture ? _capturePhoto : null,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _capturing ? Colors.white54 : Colors.white,
            ),
            child: _capturing
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await ref
          .read(imagePickerProvider)
          .pickImage(
            source: ImageSource.gallery,
            maxWidth: 2400,
            maxHeight: 2400,
            imageQuality: 85,
          );
      if (file == null || !mounted) return;
      Navigator.of(context).pop(file);
    } catch (_) {
      if (!mounted) return;
      // Fixed, path-free message: the raw picker exception may contain the
      // selected file location.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo seleccionar la imagen. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  Widget _glassButton({
    required IconData icon,
    required String tooltip,
    String? semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x66000000),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
