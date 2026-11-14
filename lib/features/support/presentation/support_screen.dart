import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/support_repository.dart';
import '../domain/support_models.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  List<SupportTicket>? tickets;
  SupportConversation? conversation;
  ErrorDiagnostic? diagnostic;
  bool busy = false;
  String notice = '';
  final subject = TextEditingController();
  final description = TextEditingController();
  final message = TextEditingController();
  String category = 'general';
  final createKey = GlobalKey<FormState>();
  final replyKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function(SupportRepository) action) async {
    if (busy) return;
    setState(() {
      busy = true;
      diagnostic = null;
      notice = '';
    });
    try {
      await action(ref.read(supportRepositoryProvider));
    } on SupportFailure catch (error) {
      if (mounted) setState(() => diagnostic = error.diagnostic);
    } on AuthSessionFailure catch (error) {
      if (mounted) {
        setState(
          () => diagnostic = ErrorDiagnostic.capture(
            code: error.code,
            operation: 'support_session',
            userMessage: 'Inicia sesión de nuevo para continuar.',
            technicalReason: error.technicalReason,
            correlationId: error.correlationId,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => diagnostic = ErrorDiagnostic.capture(
            code: 'unexpected_client_error',
            operation: 'support',
            userMessage: 'No se pudo completar la operación. Intenta de nuevo.',
            technicalReason: 'support_unavailable',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => perform((repository) async {
    final items = await repository.list();
    final current = conversation;
    final refreshed = current == null
        ? null
        : await repository.read(current.ticket.id);
    if (mounted) {
      setState(() {
        tickets = items;
        conversation = refreshed;
      });
    }
  });
  Future<void> open(int id) => perform((repository) async {
    final value = await repository.read(id);
    if (mounted) {
      setState(() {
        conversation = value;
        message.clear();
      });
    }
  });
  Future<void> create() async {
    if (!(createKey.currentState?.validate() ?? false)) return;
    await perform((repository) async {
      final ticket = await repository.create(
        subject: subject.text,
        category: category,
        description: description.text,
      );
      final items = await repository.list();
      final value = await repository.read(ticket.id);
      if (mounted) {
        setState(() {
          tickets = items;
          conversation = value;
          subject.clear();
          description.clear();
          notice = 'Ticket creado.';
        });
      }
    });
  }

  Future<void> send() async {
    if (!(replyKey.currentState?.validate() ?? false) || conversation == null) {
      return;
    }
    final id = conversation!.ticket.id;
    await perform((repository) async {
      await repository.send(id, message.text);
      if (mounted) message.clear();
      final value = await repository.read(id);
      if (mounted) {
        setState(() {
          conversation = value;
          notice = 'Mensaje enviado.';
        });
      }
    });
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Completa este campo.' : null;
  @override
  Widget build(BuildContext context) {
    final current = conversation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y soporte'),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Cargando soporte',
                ),
              if (diagnostic != null) ...[
                Text(diagnostic!.userMessage),
                ErrorDiagnosticPanel(diagnostic: diagnostic!),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Reintentar'),
                ),
              ],
              if (notice.isNotEmpty)
                Semantics(liveRegion: true, child: Text(notice)),
              ExpansionTile(
                title: const Text('Crear solicitud'),
                children: [
                  Form(
                    key: createKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: subject,
                          maxLength: 160,
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Asunto',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'general',
                              child: Text('General'),
                            ),
                            DropdownMenuItem(
                              value: 'account',
                              child: Text('Cuenta'),
                            ),
                            DropdownMenuItem(
                              value: 'technical',
                              child: Text('Problema técnico'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Otro'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(() => category = value!),
                        ),
                        TextFormField(
                          controller: description,
                          maxLength: 4000,
                          maxLines: 4,
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                          ),
                        ),
                        FilledButton(
                          onPressed: busy ? null : create,
                          child: const Text('Crear ticket'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Mis tickets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (tickets != null && tickets!.isEmpty)
                const Text('Todavía no tienes tickets.'),
              ...?tickets?.map(
                (ticket) => ListTile(
                  title: Text(ticket.subject),
                  subtitle: Text(
                    '#${ticket.id} · ${supportStatusLabels[ticket.status] ?? ticket.status}',
                  ),
                  selected: current?.ticket.id == ticket.id,
                  onTap: busy ? null : () => open(ticket.id),
                ),
              ),
              if (current != null) ...[
                const Divider(),
                Text(
                  current.ticket.subject,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  supportStatusLabels[current.ticket.status] ??
                      current.ticket.status,
                ),
                Text(current.ticket.description),
                const SizedBox(height: 16),
                Text(
                  'Conversación',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (current.messages.isEmpty)
                  const Text('Aún no hay mensajes.'),
                ...current.messages.map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuario #${item.author} · ${item.createdAt.toLocal()}',
                          ),
                          SelectableText(item.body),
                        ],
                      ),
                    ),
                  ),
                ),
                if (current.ticket.resolution != null) ...[
                  Text(
                    'Resolución',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(current.ticket.resolution!),
                ],
                if (current.ticket.status == 'open' ||
                    current.ticket.status == 'in_progress')
                  Form(
                    key: replyKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: message,
                          maxLength: 4000,
                          maxLines: 3,
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje',
                          ),
                        ),
                        FilledButton(
                          onPressed: busy ? null : send,
                          child: const Text('Enviar mensaje'),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('Este ticket está en modo de solo lectura.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
