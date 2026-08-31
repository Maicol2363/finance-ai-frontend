import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/application/auth_session_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionControllerProvider);
    final controller = ref.read(authSessionControllerProvider.notifier);
    final user = state.user;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Budget Home'),
          actions: [
            TextButton.icon(
              key: const Key('logout-button'),
              onPressed: state.status == AuthSessionStatus.loggingOut
                  ? null
                  : controller.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Your secure session is active',
                    key: const Key('home-title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user == null
                        ? 'Authenticated account'
                        : '${user.email} · ${user.preferredCurrency}',
                    key: const Key('home-user-context'),
                  ),
                  const SizedBox(height: 24),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'The budgeting forms will be added in the next stories. They will work manually first; optional AI assistance will use the same forms later.',
                      ),
                    ),
                  ),
                  if (state.status == AuthSessionStatus.loggingOut) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      label: 'Logging out',
                      child: const LinearProgressIndicator(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
