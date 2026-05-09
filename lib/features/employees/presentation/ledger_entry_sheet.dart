import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/turkish_money_input_formatter.dart';
import '../../../models/employee_ledger_entry.dart';
import '../../auth/providers/auth_providers.dart';
import '../../expense/providers/expense_providers.dart';
import '../providers/employee_providers.dart';

class LedgerEntrySheet extends ConsumerStatefulWidget {
  const LedgerEntrySheet({
    super.key,
    required this.shopId,
    required this.employeeId,
    required this.employeeName,
    this.initialType = LedgerEntryType.avans,
  });

  final String shopId;
  final String employeeId;
  final String employeeName;
  final LedgerEntryType initialType;

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String employeeId,
    required String employeeName,
    LedgerEntryType initialType = LedgerEntryType.avans,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LedgerEntrySheet(
        shopId: shopId,
        employeeId: employeeId,
        employeeName: employeeName,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<LedgerEntrySheet> createState() => _LedgerEntrySheetState();
}

class _LedgerEntrySheetState extends ConsumerState<LedgerEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late LedgerEntryType _type;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      setState(() => _error = 'Oturum bilgisi alınamadı.');
      return;
    }
    final amount = Money.tryParse(_amountCtrl.text) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _noteCtrl.text.trim();
    try {
      await ref.read(employeeLedgerRepositoryProvider).add(
            shopId: widget.shopId,
            employeeId: widget.employeeId,
            type: _type,
            amount: amount,
            date: _date,
            note: note,
            createdBy: appUser.uid,
          );
      if (_type == LedgerEntryType.avans) {
        await ref.read(expenseRepositoryProvider).add(
              shopId: widget.shopId,
              date: _date,
              name: 'Avans - ${widget.employeeName}',
              amount: amount,
              note: note,
              createdBy: appUser.uid,
            );
      }
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
    final dateLabel = DateFormat('d MMMM yyyy', 'tr_TR').format(_date);
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
                  'Hesap Hareketi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<LedgerEntryType>(
                  segments: const [
                    ButtonSegment(
                      value: LedgerEntryType.avans,
                      label: Text('Avans'),
                      icon: Icon(Icons.savings_outlined),
                    ),
                    ButtonSegment(
                      value: LedgerEntryType.odeme,
                      label: Text('Ödeme'),
                      icon: Icon(Icons.trending_down_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [TurkishMoneyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: '₺',
                    border: OutlineInputBorder(),
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
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tarih',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(dateLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    prefixIcon: Icon(Icons.note_outlined),
                    border: OutlineInputBorder(),
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
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
