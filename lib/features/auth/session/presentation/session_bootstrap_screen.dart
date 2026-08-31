import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/auth_session_controller.dart';
import '../application/auth_session_state.dart';

class SessionBootstrapScreen extends ConsumerWidget {
  const SessionBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionControllerProvider);
    final controller = ref.read(authSessionControllerProvider.notifier);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: state.status == AuthSessionStatus.restorationRetry
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Session restoration needs attention',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (state.diagnostic case final diagnostic?)
                            ErrorDiagnosticPanel(
                              key: const Key('restore-error-banner'),
                              diagnostic: diagnostic,
                            ),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const Key('restore-retry-button'),
                            onPressed: controller.restoreSession,
                            child: const Text('Retry restoration'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('restore-clear-button'),
                            onPressed: controller.clearLocalSession,
                            child: const Text('Clear local session and log in'),
                          ),
                        ],
                      )
                    : Semantics(
                        liveRegion: true,
                        label: 'Checking your session',
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Checking your session…'),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
