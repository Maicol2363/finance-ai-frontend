import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import 'text_capture_chat.dart';

/// Opens the quick capture sheet for AI-assisted voice or text expense entry.
Future<void> showQuickCaptureSheet(
  BuildContext context, {
  bool startWithVoice = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final palette = context.palette;
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.85,
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Text(
                      startWithVoice
                          ? 'Dictar movimiento'
                          : 'Nuevo movimiento con IA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(FinanceIcons.close),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.line),
              Expanded(
                child: TextCaptureChat(
                  showWheel: false,
                  autoFocus: !startWithVoice,
                  startVoice: startWithVoice,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
