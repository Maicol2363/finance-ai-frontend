import 'dart:convert';

import 'package:finance_ai/core/diagnostics/error_diagnostic.dart';
import 'package:finance_ai/core/diagnostics/error_diagnostic_panel.dart';
import 'package:finance_ai/features/support/data/support_repository.dart';
import 'package:finance_ai/features/support/domain/support_models.dart';
import 'package:finance_ai/features/support/presentation/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSupportRepository implements SupportRepository {
  @override
  Future<Uint8List> download(int id, int attachmentId) async {
    if (downloadFailure case final failure?) throw failure;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGMQqo0BAAGQAOzY5F2BAAAAAElFTkSuQmCC',
    );
  }

  SupportFailure? downloadFailure;
  List<SupportAttachment> attachments = [];

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
    Map<String, String>? attachment,
  }) async {
    commands.add('$subject|$category|$description');
    return ticket;
  }

  @override
  Future<SupportConversation> read(int id) async => SupportConversation(
    ticket: ticket,
    attachments: attachments,
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
  Future<void> send(
    int id,
    String body, {
    Map<String, String>? attachment,
  }) async {
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
    'opens initial legacy and message images and returns to the ticket',
    (tester) async {
      final repository = FakeSupportRepository()
        ..bodies.add('Mensaje con imagen')
        ..attachments = [
          const SupportAttachment(1, null, 'tmp_123.png'),
          const SupportAttachment(2, 0, 'nueva.JPG'),
          const SupportAttachment(3, null, 'documento.pdf'),
        ];
      await mount(tester, repository);
      await tester.tap(find.text('Caso de prueba'));
      await tester.pumpAndSettle();
      for (final name in ['tmp_123.png', 'nueva.JPG']) {
        final thumbnail = find.bySemanticsLabel('Abrir imagen $name');
        await tester.ensureVisible(thumbnail);
        await tester.tap(thumbnail);
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        await tester.tap(find.text('Cerrar imagen'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(find.text('Descripción inicial'), findsOneWidget);
      }
      expect(find.text('documento.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed preview keeps download and safe copyable diagnostic', (
    tester,
  ) async {
    final repository = FakeSupportRepository()
      ..attachments = [const SupportAttachment(1, null, 'tmp_private.png')]
      ..downloadFailure = SupportFailure(
        ErrorDiagnostic.capture(
          code: 'support_ticket_not_found',
          operation: 'support_attachment',
          userMessage: 'No se pudo mostrar la vista previa. Puedes descargar el archivo.',
          technicalReason: 'http_404',
          correlationId: 'preview-test',
        ),
      );
    await mount(tester, repository);
    await tester.tap(find.text('Caso de prueba'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorDiagnosticPanel), findsOneWidget);
    expect(find.text('tmp_private.png'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    final report = tester
        .widget<ErrorDiagnosticPanel>(find.byType(ErrorDiagnosticPanel))
        .diagnostic
        .clipboardText;
    expect(report, contains('support_ticket_not_found'));
    expect(report, contains('preview-test'));
    expect(report, isNot(contains('tmp_private')));
  });

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
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repository.bodies, ['<script>texto seguro</script>']);
      expect(find.text('<script>texto seguro</script>'), findsOneWidget);
      repository.status = 'resolved';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Consulta atendida'));
      expect(find.text('Consulta atendida'), findsOneWidget);
      expect(find.byTooltip('Enviar mensaje'), findsNothing);
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear ticket'));
    await tester.pumpAndSettle();
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
