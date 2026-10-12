import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'error_diagnostic.dart';

class ErrorDiagnosticPanel extends StatelessWidget {
  const ErrorDiagnosticPanel({required this.diagnostic, super.key});

  final ErrorDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectionArea(
                child: Text(
                  diagnostic.userMessage,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              const SizedBox(height: 8),
              SelectionArea(
                child: Text(
                  'Código de error: ${diagnostic.code}',
                  key: const Key('error-diagnostic-code'),
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Copia el reporte seguro al pedir ayuda. No incluye los datos del formulario.',
                style: TextStyle(color: colors.onErrorContainer),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('copy-error-details-button'),
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar detalles del error'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: diagnostic.clipboardText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Se copiaron los detalles seguros del error.'),
      ),
    );
  }
}
