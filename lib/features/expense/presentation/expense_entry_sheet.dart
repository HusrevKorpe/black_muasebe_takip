import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/turkish_money_input_formatter.dart';
import '../providers/expense_providers.dart';

class ExpenseEntrySheet extends ConsumerStatefulWidget {
  const ExpenseEntrySheet({
    super.key,
    required this.shopId,
    required this.createdBy,
  });

  final String shopId;
  final String createdBy;

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String createdBy,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseEntrySheet(shopId: shopId, createdBy: createdBy),
    );
  }

  @override
  ConsumerState<ExpenseEntrySheet> createState() => _ExpenseEntrySheetState();
}

class _ExpenseEntrySheetState extends ConsumerState<ExpenseEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amountCtrl.text) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expenseRepositoryProvider).add(
            shopId: widget.shopId,
            date: DateKeys.today(),
            name: _nameCtrl.text.trim(),
            amount: amount,
            createdBy: widget.createdBy,
            note: _noteCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yeni Gider',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateKeys.human(DateKeys.today()),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Gider adı',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    hintText: 'Örn. Elektrik faturası',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Gider adı girilmeli';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [TurkishMoneyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: '₺',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Tutar girilmeli';
                    final parsed = Money.tryParse(v);
                    if (parsed == null || parsed <= 0) {
                      return 'Geçerli bir tutar gir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
