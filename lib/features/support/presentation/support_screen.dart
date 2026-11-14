import 'dart:convert';
import 'dart:typed_data';

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
  final chatScroll = ScrollController();
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
      _ChatAttachment(
        key: ValueKey((ticketId, attachment.id)),
        attachment: attachment,
        load: () => ref
            .read(supportRepositoryProvider)
            .download(ticketId, attachment.id),
        onSave: (load) => perform((_) async {
          final bytes = await load();
          if (mounted) {
            await FilePicker.saveFile(fileName: attachment.name, bytes: bytes);
          }
        }),
      );

  void showConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && chatScroll.hasClients) {
        chatScroll.jumpTo(chatScroll.position.maxScrollExtent);
      }
    });
  }

  void closeConversation() {
    setState(() {
      conversation = null;
      diagnostic = null;
      notice = '';
      replyAttachment = null;
      message.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    chatScroll.dispose();
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
        showConversation();
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
    if (current != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !busy) closeConversation();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: busy ? null : closeConversation,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#${current.ticket.id} · ${supportStatusLabels[current.ticket.status] ?? current.ticket.status}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: busy ? null : load,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  if (busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Cargando soporte',
                    ),
                  if (diagnostic case final error?)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ErrorDiagnosticPanel(diagnostic: error),
                    ),
                  Expanded(
                    child: ListView(
                      controller: chatScroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solicitud inicial',
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 6),
                                SelectableText(current.ticket.description),
                                ...current.attachments
                                    .where((file) => file.messageId == null)
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
                        if (current.messages.isEmpty)
                          const Center(child: Text('Aún no hay mensajes.')),
                        for (final item in current.messages)
                          Align(
                            alignment: item.author == userId
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: .82,
                              alignment: item.author == userId
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: item.author == userId
                                    ? colors.secondaryContainer
                                    : colors.surfaceContainerHigh,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.author == userId
                                            ? 'Tú'
                                            : 'Soporte',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
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
                                      const SizedBox(height: 4),
                                      Text(
                                        '${localizations.formatShortDate(item.createdAt.toLocal())} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(item.createdAt.toLocal()))}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (current.ticket.resolution
                            case final resolution?) ...[
                          Text(
                            'Resolución',
                            style: theme.textTheme.titleMedium,
                          ),
                          SelectableText(resolution),
                        ],
                        if (notice.isNotEmpty)
                          Semantics(liveRegion: true, child: Text(notice)),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child:
                          current.ticket.status == 'open' ||
                              current.ticket.status == 'in_progress'
                          ? Form(
                              key: replyKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (replyAttachment case final file?)
                                    InputChip(
                                      label: Text(file['name']!),
                                      deleteButtonTooltipMessage:
                                          'Quitar archivo',
                                      onDeleted: busy
                                          ? null
                                          : () => setState(
                                              () => replyAttachment = null,
                                            ),
                                    ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => selectFile(reply: true),
                                        tooltip: replyAttachment == null
                                            ? 'Adjuntar archivo'
                                            : 'Cambiar archivo',
                                        icon: const Icon(Icons.attach_file),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: message,
                                          maxLength: 4000,
                                          minLines: 1,
                                          maxLines: 4,
                                          validator: requiredText,
                                          decoration: const InputDecoration(
                                            labelText: 'Mensaje',
                                            counterText: '',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(22),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filled(
                                        onPressed: busy ? null : send,
                                        tooltip: 'Enviar mensaje',
                                        icon: const Icon(Icons.send_rounded),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : const Text(
                              'Este ticket está en modo de solo lectura.',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
      body: Align(
        alignment: Alignment.topCenter,
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
                      title: Text(ticket.subject),
                      subtitle: Text(
                        '#${ticket.id} · ${supportStatusLabels[ticket.status] ?? ticket.status}',
                      ),
                      onTap: busy ? null : () => open(ticket.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatAttachment extends StatefulWidget {
  const _ChatAttachment({
    super.key,
    required this.attachment,
    required this.load,
    required this.onSave,
  });

  final SupportAttachment attachment;
  final Future<Uint8List> Function() load;
  final void Function(Future<Uint8List> Function()) onSave;

  @override
  State<_ChatAttachment> createState() => _ChatAttachmentState();
}

class _ChatAttachmentState extends State<_ChatAttachment> {
  Future<Uint8List>? preview;

  @override
  void initState() {
    super.initState();
    if (RegExp(
      r'\.(png|jpe?g)$',
      caseSensitive: false,
    ).hasMatch(widget.attachment.name)) {
      preview = widget.load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (preview case final future?)
        FutureBuilder<Uint8List>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.data case final bytes?) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    bytes,
                    width: 240,
                    height: 160,
                    fit: BoxFit.contain,
                    semanticLabel: widget.attachment.name,
                    cacheWidth: 480,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      TextButton.icon(
        onPressed: () => widget.onSave(widget.load),
        icon: const Icon(Icons.download_outlined),
        label: Text(widget.attachment.name),
      ),
    ],
  );
}
