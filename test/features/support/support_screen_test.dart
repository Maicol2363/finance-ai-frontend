import 'package:finance_ai/core/diagnostics/error_diagnostic.dart';
import 'package:finance_ai/features/support/data/support_repository.dart';
import 'package:finance_ai/features/support/domain/support_models.dart';
import 'package:finance_ai/features/support/presentation/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSupportRepository implements SupportRepository {
  String status = 'open';
  bool denied = false;
  final bodies = <String>[];
  final commands = <String>[];
  SupportTicket get ticket => SupportTicket(
    id: 7,
    subject: 'Caso de prueba',
    category: 'general',
    description: 'Descripción inicial',
    status: status,
    createdAt: DateTime.utc(2026),
    resolution: status == 'resolved' ? 'Consulta atendida' : null,
  );
  @override
  Future<List<SupportTicket>> list() async {
    if (denied) {
      throw SupportFailure(
        ErrorDiagnostic.capture(
          code: 'support_ticket_not_found',
          operation: 'support_list',
          userMessage: 'No se pudo completar la operación de soporte.',
          technicalReason: 'http_404',
          correlationId: 'corr-widget',
        ),
      );
    }
    return [ticket];
  }

  @override
  Future<SupportTicket> create({
    required String subject,
    required String category,
    required String description,
  }) async {
    commands.add('$subject|$category|$description');
    return ticket;
  }

  @override
  Future<SupportConversation> read(int id) async => SupportConversation(
    ticket: ticket,
    messages: bodies.indexed
        .map(
          (item) => SupportMessage(
            id: item.$1,
            author: 42,
            body: item.$2,
            createdAt: DateTime.utc(2026),
          ),
        )
        .toList(),
  );
  @override
  Future<void> send(int id, String body) async {
    bodies.add(body);
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeSupportRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SupportScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reads own tickets, sends literal text, refreshes resolution and disables replying',
    (tester) async {
      final repository = FakeSupportRepository();
      await mount(tester, repository);
      await tester.tap(find.text('Caso de prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Descripción inicial'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensaje'),
        '<script>texto seguro</script>',
      );
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(repository.bodies, ['<script>texto seguro</script>']);
      expect(find.text('<script>texto seguro</script>'), findsOneWidget);
      repository.status = 'resolved';
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Consulta atendida'));
      expect(find.text('Consulta atendida'), findsOneWidget);
      expect(find.text('Enviar mensaje'), findsNothing);
    },
  );
  testWidgets('creates a request with required fields', (tester) async {
    final repository = FakeSupportRepository();
    await mount(tester, repository);
    await tester.tap(find.text('Crear solicitud'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear ticket'));
    await tester.tap(find.text('Crear ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Completa este campo.'), findsNWidgets(2));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Asunto'),
      'Consulta',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Ayuda con la app',
    );
    await tester.ensureVisible(find.text('Crear ticket'));
    await tester.tap(find.text('Crear ticket'));
    await tester.pumpAndSettle();
    expect(repository.commands, ['Consulta|general|Ayuda con la app']);
    expect(find.text('Ticket creado.'), findsOneWidget);
  });
  testWidgets('shows copyable safe failures and retries', (tester) async {
    final repository = FakeSupportRepository()..denied = true;
    await mount(tester, repository);
    expect(
      find.text('No se pudo completar la operación de soporte.'),
      findsWidgets,
    );
    repository.denied = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Caso de prueba'), findsOneWidget);
  });
}
