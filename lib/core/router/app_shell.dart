import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/receipt_capture/presentation/receipt_capture_flow.dart';
import '../../features/text_capture/presentation/quick_capture_sheet.dart';
import '../../features/text_capture/presentation/widgets/capture_wheel.dart';
import '../widgets/app_bottom_nav.dart';

/// Shell with bottom navigation, Android back-button pop scope, and
/// global floating action wheel across all tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = <AppNavDestination>[
    AppNavDestination(
      id: 'inicio',
      label: 'Inicio',
      icon: FinanceIcons.homeOutlined,
    ),
    AppNavDestination(
      id: 'movimientos',
      label: 'Movimientos',
      icon: FinanceIcons.receiptLongOutlined,
    ),
    AppNavDestination(
      id: 'ajustes',
      label: 'Ajustes',
      icon: FinanceIcons.settingsOutlined,
    ),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _captureWheelKey = GlobalKey<CaptureWheelState>();
  bool _captureWheelOpen = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_captureWheelOpen && widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_captureWheelOpen) {
          _captureWheelKey.currentState?.close();
        } else if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            CaptureWheel(
              key: _captureWheelKey,
              onOpenChanged: (isOpen) {
                if (_captureWheelOpen != isOpen && mounted) {
                  setState(() => _captureWheelOpen = isOpen);
                }
              },
              onPhoto: () =>
                  startReceiptCapture(context, source: ImageSource.camera),
              onAi: () =>
                  showQuickCaptureSheet(context, useRootNavigator: true),
              onManual: () => context.push('/expenses/new'),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          destinations: AppShell.destinations,
          currentIndex: widget.navigationShell.currentIndex,
          onSelected: (index) {
            _captureWheelKey.currentState?.close();
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}
