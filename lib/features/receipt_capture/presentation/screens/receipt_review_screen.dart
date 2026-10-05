import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../accounts/application/accounts_controller.dart';
import '../../../accounts/domain/account_models.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/domain/category_models.dart';
import '../../application/receipt_capture_notifier.dart';
import '../../domain/receipt_capture_state.dart';
import '../../domain/receipt_review_form_data.dart';
import '../widgets/receipt_photo_viewer_dialog.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _totalAmountController;
  late TextEditingController _noteController;
  List<Category> _availableCategories = const [];

  @override
  void initState() {
    super.initState();
    final state = ref.read(receiptCaptureNotifierProvider);
    final initialMerchant = state is ReceiptCaptureReview
        ? state.formData.merchant
        : '';
    final initialTotal = state is ReceiptCaptureReview
        ? (state.formData.totalAmount > 0
              ? state.formData.totalAmount.toStringAsFixed(0)
              : '')
        : '';
    final initialNote = state is ReceiptCaptureReview
        ? (state.formData.note ?? '')
        : '';

    _merchantController = TextEditingController(text: initialMerchant);
    _totalAmountController = TextEditingController(text: initialTotal);
    _noteController = TextEditingController(text: initialNote);

    Future<void>.microtask(() {
      ref
          .read(accountsControllerProvider.notifier)
          .load(includeInactive: false);
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(categoriesRepositoryProvider);
      final res = await repo.list();
      if (mounted) {
        setState(() {
          _availableCategories = res.categories;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>() ?? AppPalette.light;
    final state = ref.watch(receiptCaptureNotifierProvider);
    final accountsState = ref.watch(accountsControllerProvider);
    final notifier = ref.read(receiptCaptureNotifierProvider.notifier);

    if (state is! ReceiptCaptureReview) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(title: const Text('Revisar recibo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No hay ningún borrador de recibo activo.'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    final formData = state.formData;
    final activeAccounts = (accountsState.result?.accounts ?? const <Account>[])
        .where((a) => a.isActive && a.currency.code == formData.currency)
        .toList();

    // Auto-select account if none selected
    if (formData.accountId == null && activeAccounts.isNotEmpty) {
      Account? matchedAccount;
      // 1. Try matching suggestedAccount name
      if (formData.suggestedAccount != null &&
          formData.suggestedAccount!.trim().isNotEmpty) {
        final suggName = formData.suggestedAccount!.trim().toLowerCase();
        matchedAccount = activeAccounts.where((a) {
          final aName = a.name.trim().toLowerCase();
          return aName == suggName ||
              aName.contains(suggName) ||
              suggName.contains(aName);
        }).firstOrNull;
      }

      // 2. Try matching by paymentMethod heuristic
      if (matchedAccount == null &&
          formData.paymentMethod != null &&
          formData.paymentMethod!.trim().isNotEmpty) {
        final pm = formData.paymentMethod!.trim().toLowerCase();
        if (pm.contains('efectivo') || pm.contains('cash')) {
          matchedAccount = activeAccounts
              .where(
                (a) =>
                    a.type == AccountType.cash ||
                    a.name.toLowerCase().contains('efectivo'),
              )
              .firstOrNull;
        } else if (pm.contains('debito') ||
            pm.contains('debit') ||
            pm.contains('credito') ||
            pm.contains('credit') ||
            pm.contains('tarjeta') ||
            pm.contains('card') ||
            pm.contains('banco') ||
            pm.contains('bank')) {
          matchedAccount = activeAccounts
              .where(
                (a) =>
                    a.type == AccountType.bank ||
                    a.type == AccountType.creditCard ||
                    a.name.toLowerCase().contains('banco') ||
                    a.name.toLowerCase().contains('tarjeta'),
              )
              .firstOrNull;
        } else if (pm.contains('nequi') ||
            pm.contains('daviplata') ||
            pm.contains('wallet') ||
            pm.contains('billetera')) {
          matchedAccount = activeAccounts
              .where(
                (a) =>
                    a.type == AccountType.digitalWallet ||
                    a.name.toLowerCase().contains('nequi') ||
                    a.name.toLowerCase().contains('daviplata'),
              )
              .firstOrNull;
        }
      }

      // 3. Fallback to first active account
      matchedAccount ??= activeAccounts.first;

      final selectedId = matchedAccount.id;
      Future<void>.microtask(() {
        if (mounted) {
          notifier.updateFormData(formData.copyWith(accountId: selectedId));
        }
      });
    }

    final suggestion = formData.suggestedCategory?.trim();
    final hasSuggestedOption =
        suggestion != null &&
        suggestion.isNotEmpty &&
        !_availableCategories.any(
          (c) => c.name.trim().toLowerCase() == suggestion.toLowerCase(),
        );

    // Auto-select category from AI suggestion if none selected
    if (formData.categoryId == null &&
        suggestion != null &&
        suggestion.isNotEmpty &&
        _availableCategories.isNotEmpty) {
      final match = _availableCategories
          .where((c) => c.name.trim().toLowerCase() == suggestion.toLowerCase())
          .firstOrNull;
      Future<void>.microtask(() {
        if (mounted) {
          if (match != null) {
            notifier.updateFormData(formData.copyWith(categoryId: match.id));
          } else {
            notifier.updateFormData(
              formData.copyWith(categoryId: -1, newCategoryName: suggestion),
            );
          }
        }
      });
    }

    final imageFile = File(state.localImagePath);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        notifier.discardDraft();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: const Text('Revisar recibo'),
          backgroundColor: palette.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: () => _handleDiscardAndExit(context, notifier),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo thumbnail preview card
                        _buildPhotoPreviewCard(
                          context,
                          palette,
                          imageFile,
                          notifier,
                          state,
                        ),
                        const SizedBox(height: 16),

                        // Warning banner for non-receipts
                        if (state.status == 'not_a_receipt') ...[
                          _buildWarningBanner(
                            palette: palette,
                            icon: Icons.block,
                            color: palette.discard,
                            bgColor: palette.errorSoft,
                            title: 'La imagen no parece ser un recibo válido',
                            subtitle: 'La IA determinó que esta imagen no corresponde a un comprobante o recibo de compra. Por seguridad no se puede registrar como gasto.',
                          ),
                          const SizedBox(height: 16),
                        ] else if (state.status == 'failed_extraction') ...[
                          _buildWarningBanner(
                            palette: palette,
                            icon: Icons.info_outline,
                            color: Colors.orange.shade800,
                            bgColor: Colors.orange.shade50,
                            title: 'Extracción automática no disponible',
                            subtitle: 'No se pudieron extraer datos automáticamente. Puedes completar los campos obligatorios para registrar el gasto o descartarlo.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Duplicate warning banner
                        if (state.possibleDuplicate) ...[
                          _buildWarningBanner(
                            palette: palette,
                            icon: Icons.warning_amber_rounded,
                            color: Colors.amber.shade900,
                            bgColor: Colors.amber.shade50,
                            title: 'Posible recibo duplicado',
                            subtitle: state.duplicateWarning ?? 'Ya registraste una compra idéntica en este comercio y fecha.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Arithmetic discrepancy banner
                        if (formData.hasArithmeticDiscrepancy) ...[
                          _buildWarningBanner(
                            palette: palette,
                            icon: Icons.info_outline,
                            color: Colors.amber.shade900,
                            bgColor: Colors.amber.shade50,
                            title: 'Diferencia en la suma de productos',
                            subtitle:
                                'Suma de items: ${MoneyFormatter.displayMajor(formData.itemsSum, formData.currency)} | Total: ${MoneyFormatter.displayMajor(formData.totalAmount, formData.currency)}.\nEl total confirmado será el monto oficial del gasto.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Submission failure report (privacy-safe, copyable)
                        if (state.submissionDiagnostic
                            case final diagnostic?) ...[
                          ErrorDiagnosticPanel(diagnostic: diagnostic),
                          const SizedBox(height: 16),
                        ],

                        // Client-side validation hint
                        if (state.submissionError != null) ...[
                          _buildWarningBanner(
                            palette: palette,
                            icon: Icons.error_outline,
                            color: palette.discard,
                            bgColor: palette.errorSoft,
                            title: 'Error al confirmar',
                            subtitle: state.submissionError!,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Financial Details Section
                        _buildCard(
                          palette: palette,
                          title: 'Datos del gasto',
                          children: [
                            TextFormField(
                              controller: _merchantController,
                              decoration: const InputDecoration(
                                labelText: 'Comercio / Tienda *',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Ingresa el nombre del comercio';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                notifier.updateFormData(
                                  formData.copyWith(merchant: val),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _totalAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: palette.discard,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    'Monto total (${formData.currency}) *',
                                prefixText: '- \$ ',
                                prefixStyle: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: palette.discard,
                                ),
                              ),
                              validator: (val) {
                                final parsed = double.tryParse(val ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'Ingresa un monto válido mayor a 0';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 0.0;
                                notifier.updateFormData(
                                  formData.copyWith(totalAmount: parsed),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.calendar_today_outlined,
                                color: palette.primary,
                              ),
                              title: const Text('Fecha del comprobante'),
                              subtitle: Text(
                                '${formData.occurredAt.day.toString().padLeft(2, '0')}/${formData.occurredAt.month.toString().padLeft(2, '0')}/${formData.occurredAt.year}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: formData.occurredAt,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    notifier.updateFormData(
                                      formData.copyWith(occurredAt: picked),
                                    );
                                  }
                                },
                                child: const Text('Cambiar'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: formData.accountId,
                              decoration: const InputDecoration(
                                labelText: 'Cuenta de pago *',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              items: activeAccounts
                                  .map(
                                    (acc) => DropdownMenuItem<int>(
                                      value: acc.id,
                                      child: Text(
                                        '${acc.name} (${acc.currency.code})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              validator: (val) {
                                if (val == null) {
                                  return 'Selecciona una cuenta de pago';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                if (val != null) {
                                  notifier.updateFormData(
                                    formData.copyWith(accountId: val),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue:
                                  formData.categoryId == -1 &&
                                      hasSuggestedOption
                                  ? -1
                                  : (_availableCategories.any(
                                          (c) => c.id == formData.categoryId,
                                        )
                                        ? formData.categoryId
                                        : null),
                              decoration: const InputDecoration(
                                labelText: 'Categoría general (opcional)',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Sin categoría específica'),
                                ),
                                if (hasSuggestedOption)
                                  DropdownMenuItem<int>(
                                    value: -1,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 16,
                                          color: palette.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Crear "$suggestion" (IA)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ..._availableCategories.map(
                                  (cat) => DropdownMenuItem<int>(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == -1) {
                                  notifier.updateFormData(
                                    formData.copyWith(
                                      categoryId: -1,
                                      newCategoryName: suggestion,
                                    ),
                                  );
                                } else {
                                  notifier.updateFormData(
                                    formData.copyWith(
                                      categoryId: val,
                                      clearCategoryId: val == null,
                                      clearNewCategoryName: true,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _noteController,
                              decoration: const InputDecoration(
                                labelText: 'Notas adicionales (opcional)',
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                              onChanged: (val) {
                                notifier.updateFormData(
                                  formData.copyWith(note: val),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Line Items Breakdown Section
                        _buildLineItemsSection(
                          context,
                          palette,
                          formData,
                          notifier,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Sticky Bottom Action Bar
              _buildBottomActionBar(context, palette, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreviewCard(
    BuildContext context,
    AppPalette palette,
    File file,
    ReceiptCaptureNotifier notifier,
    ReceiptCaptureReview state,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comprobante analizado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${state.proposalId.length > 8 ? '${state.proposalId.substring(0, 8)}...' : state.proposalId}',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ReceiptPhotoViewerDialog.show(context, imageFile: file);
            },
            icon: const Icon(Icons.zoom_in, size: 16),
            label: const Text('Ver foto'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner({
    required AppPalette palette,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.text, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required AppPalette palette,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: palette.text,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLineItemsSection(
    BuildContext context,
    AppPalette palette,
    ReceiptReviewFormData formData,
    ReceiptCaptureNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productos / Items (${formData.items.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                  fontSize: 15,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showItemEditDialog(context, notifier),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (formData.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No se detectaron items individuales. Se registrará como un gasto único por el total.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: formData.items.length,
              separatorBuilder: (context, index) =>
                  Divider(color: palette.line, height: 1),
              itemBuilder: (context, index) {
                final item = formData.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  subtitle: Text(
                    '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.unitPrice != null ? 'x ${MoneyFormatter.displayMajor(item.unitPrice!, formData.currency)}' : ''}',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MoneyFormatter.displayMajor(item.totalPrice, formData.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showItemEditDialog(
                          context,
                          notifier,
                          item: item,
                          index: index,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: palette.discard,
                        ),
                        onPressed: () => notifier.removeLineItem(index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    AppPalette palette,
    ReceiptCaptureReview state,
    ReceiptCaptureNotifier notifier,
  ) {
    final formData = state.formData;
    final isNotAReceipt = state.status == 'not_a_receipt';
    final canConfirm =
        !state.isSubmitting && !isNotAReceipt && formData.isValid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => _handleDiscardAndExit(context, notifier),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.discard,
                side: BorderSide(color: palette.discard.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Descartar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: FilledButton(
              onPressed: canConfirm
                  ? () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final created = await notifier.confirmExpense();
                        if (created != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Gasto en ${created.store} registrado exitosamente.',
                              ),
                            ),
                          );
                          context.go('/expenses/${created.id}');
                        }
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                disabledBackgroundColor: palette.line,
                disabledForegroundColor: palette.muted,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.onPrimary,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Confirmar gasto',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDiscardAndExit(
    BuildContext context,
    ReceiptCaptureNotifier notifier,
  ) async {
    await notifier.discardDraft();
    if (context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _showItemEditDialog(
    BuildContext context,
    ReceiptCaptureNotifier notifier, {
    ReceiptLineItemDraft? item,
    int? index,
  }) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: item != null ? item.quantity.toString() : '1',
    );
    final priceCtrl = TextEditingController(
      text: item != null ? item.totalPrice.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Nuevo producto' : 'Editar producto'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Total *'),
                      validator: (val) {
                        final parsed = double.tryParse(val ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final name = nameCtrl.text.trim();
      final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
      final total = double.tryParse(priceCtrl.text) ?? 0.0;

      if (item != null && index != null) {
        notifier.updateLineItem(
          index,
          item.copyWith(name: name, quantity: qty, totalPrice: total),
        );
      } else {
        notifier.addLineItem(
          ReceiptLineItemDraft(
            localId: 'item-new-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            quantity: qty,
            totalPrice: total,
          ),
        );
      }
    }
  }
}
