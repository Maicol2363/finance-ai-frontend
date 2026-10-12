import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/receipt_capture/presentation/receipt_capture_flow.dart';
import '../../features/text_capture/presentation/quick_capture_sheet.dart';
import '../../features/text_capture/presentation/widgets/capture_wheel.dart';
import '../widgets/app_bottom_nav.dart';

/// Shell with bottom navigation, Android back-button pop scope, and
/// global floating action wheel across all tabs.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = <AppNavDestination>[
    AppNavDestination(id: 'inicio', label: 'Inicio', icon: Icons.home_outlined),
    AppNavDestination(
      id: 'movimientos',
      label: 'Movimientos',
      icon: Icons.receipt_long_outlined,
    ),
    AppNavDestination(
      id: 'ajustes',
      label: 'Ajustes',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            navigationShell,
            CaptureWheel(
              onPhoto: () =>
                  startReceiptCapture(context, source: ImageSource.camera),
              onVoice: () =>
                  showQuickCaptureSheet(context, startWithVoice: true),
              onText: () =>
                  showQuickCaptureSheet(context, startWithVoice: false),
              onManual: () => context.push('/expenses/new'),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          destinations: destinations,
          currentIndex: navigationShell.currentIndex,
          onSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
