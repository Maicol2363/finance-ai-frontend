import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/support_repository.dart';
import '../domain/support_models.dart';
import 'support_picker_options.dart'
    if (dart.library.js_interop) 'support_picker_options_web.dart';

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
  final detailKey = GlobalKey();
  final createController = ExpansibleController();
  static const maxAttachmentBytes = 2 * 1024 * 1024;
  Map<String, String>? ticketAttachment;
  Map<String, String>? replyAttachment;

  Future<void> selectFile({required bool reply}) => perform((_) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      webOptions: supportPickerOptions,
    );
    if (file == null || !mounted) return;
    final length = await file.length();
    if (length == null || length <= 0 || length > maxAttachmentBytes) {
      throw SupportFailure(
        ErrorDiagnostic.capture(
          code: 'support_attachment_invalid',
          operation: 'support_attachment',
          userMessage: 'Elige un PNG, JPG o PDF de hasta 2 MB.',
          technicalReason: 'invalid_file_size',
        ),
      );
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final attachment = {'name': file.name, 'content': base64Encode(bytes)};
    setState(() {
      if (reply) {
        replyAttachment = attachment;
      } else {
        ticketAttachment = attachment;
      }
    });
  });

  Widget attachmentPicker({required bool reply}) {
    final name = (reply ? replyAttachment : ticketAttachment)?['name'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: busy ? null : () => selectFile(reply: reply),
          icon: const Icon(Icons.attach_file),
          label: Text(name == null ? 'Adjuntar archivo' : 'Cambiar archivo'),
        ),
        if (name != null)
          InputChip(
            label: Text(name),
            onDeleted: busy
                ? null
                : () => setState(() {
                    if (reply) {
                      replyAttachment = null;
                    } else {
                      ticketAttachment = null;
                    }
                  }),
          ),
      ],
    );
  }

  Widget downloadButton(int ticketId, SupportAttachment attachment) =>
      TextButton.icon(
        icon: const Icon(Icons.download_outlined),
        label: Text(attachment.name),
        onPressed: busy
            ? null
            : () => perform((repository) async {
                final bytes = await repository.download(
                  ticketId,
                  attachment.id,
                );
                if (mounted) {
                  await FilePicker.saveFile(
                    fileName: attachment.name,
                    bytes: bytes,
                  );
                }
              }),
      );

  void showConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detailContext = detailKey.currentContext;
      if (mounted && detailContext != null) {
        Scrollable.ensureVisible(detailContext);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    createController.dispose();
    subject.dispose();
    description.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function(SupportRepository) action) async {
    if (!mounted || busy) return;
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
        replyAttachment = null;
      });
      showConversation();
    }
  });
  Future<void> create() async {
    if (!(createKey.currentState?.validate() ?? false)) return;
    await perform((repository) async {
      final ticket = await repository.create(
        subject: subject.text,
        category: category,
        description: description.text,
        attachment: ticketAttachment,
      );
      final items = await repository.list();
      final value = await repository.read(ticket.id);
      if (mounted) {
        setState(() {
          tickets = items;
          conversation = value;
          subject.clear();
          description.clear();
          ticketAttachment = null;
          replyAttachment = null;
          message.clear();
          notice = 'Ticket creado.';
        });
        createController.collapse();
        showConversation();
      }
    });
  }

  Future<void> send() async {
    if (!(replyKey.currentState?.validate() ?? false) || conversation == null) {
      return;
    }
    final id = conversation!.ticket.id;
    await perform((repository) async {
      await repository.send(id, message.text, attachment: replyAttachment);
      if (mounted) {
        setState(() {
          message.clear();
          replyAttachment = null;
        });
      }
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
    final userId = ref.watch(
      authSessionControllerProvider.select((state) => state.user?.id),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 4,
                  child: busy
                      ? const LinearProgressIndicator(
                          semanticsLabel: 'Cargando soporte',
                        )
                      : null,
                ),
                if (diagnostic != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(diagnostic!.userMessage),
                      ErrorDiagnosticPanel(diagnostic: diagnostic!),
                      TextButton(
                        onPressed: busy ? null : load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: const ValueKey('support-create-request'),
                    controller: createController,
                    leading: const Icon(Icons.add_comment_outlined),
                    title: const Text('Crear solicitud'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Form(
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
                              const SizedBox(height: 12),
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
                                    : (value) =>
                                          setState(() => category = value!),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: description,
                                maxLength: 4000,
                                maxLines: 4,
                                validator: requiredText,
                                decoration: const InputDecoration(
                                  labelText: 'Descripción',
                                ),
                              ),
                              attachmentPicker(reply: false),
                              FilledButton(
                                onPressed: busy ? null : create,
                                child: const Text('Crear ticket'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Mis tickets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (tickets != null && tickets!.isEmpty)
                  const Text('Todavía no tienes tickets.'),
                ...?tickets?.map(
                  (ticket) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      selectedTileColor: colors.secondaryContainer,
                      selectedColor: colors.onSecondaryContainer,
                      title: Text(ticket.subject),
                      subtitle: Text(
                        '#${ticket.id} · ${supportStatusLabels[ticket.status] ?? ticket.status}',
                      ),
                      selected: current?.ticket.id == ticket.id,
                      onTap: busy ? null : () => open(ticket.id),
                    ),
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: detailKey,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notice.isNotEmpty) ...[
                            Semantics(liveRegion: true, child: Text(notice)),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            current.ticket.subject,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            supportStatusLabels[current.ticket.status] ??
                                current.ticket.status,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(current.ticket.description),
                          ...current.attachments
                              .where((file) => file.messageId == null)
                              .map(
                                (file) =>
                                    downloadButton(current.ticket.id, file),
                              ),
                          const SizedBox(height: 16),
                          Text(
                            'Conversación',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (current.messages.isEmpty)
                            const Text('Aún no hay mensajes.'),
                          ...current.messages.map(
                            (item) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: item.author == userId
                                  ? colors.secondaryContainer
                                  : colors.surfaceContainerLow,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.author == userId ? 'Tú' : 'Soporte',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    Text(
                                      '${localizations.formatShortDate(item.createdAt.toLocal())} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(item.createdAt.toLocal()))}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(item.body),
                                    ...current.attachments
                                        .where(
                                          (file) => file.messageId == item.id,
                                        )
                                        .map(
                                          (file) => downloadButton(
                                            current.ticket.id,
                                            file,
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (current.ticket.resolution != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Resolución',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SelectableText(current.ticket.resolution!),
                          ],
                          const SizedBox(height: 16),
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
                                  attachmentPicker(reply: true),
                                  FilledButton(
                                    onPressed: busy ? null : send,
                                    child: const Text('Enviar mensaje'),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              'Este ticket está en modo de solo lectura.',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
