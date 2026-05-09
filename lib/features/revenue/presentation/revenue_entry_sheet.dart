import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/turkish_money_input_formatter.dart';
import '../../../models/revenue.dart';
import '../providers/revenue_providers.dart';

class RevenueEntrySheet extends ConsumerStatefulWidget {
  const RevenueEntrySheet({
    super.key,
    required this.shopId,
    required this.createdBy,
    required this.date,
  });

  final String shopId;
  final String createdBy;
  final DateTime date;

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String createdBy,
    DateTime? date,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RevenueEntrySheet(
        shopId: shopId,
        createdBy: createdBy,
        date: date ?? DateKeys.today(),
      ),
    );
  }

  @override
  ConsumerState<RevenueEntrySheet> createState() => _RevenueEntrySheetState();
}

class _RevenueEntrySheetState extends ConsumerState<RevenueEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  late DateTime _date;
  Revenue? _existing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _prefill();
  }

  Future<void> _prefill() async {
    setState(() => _loading = true);
    final existing = await ref
        .read(revenueRepositoryProvider)
        .fetchByDate(shopId: widget.shopId, date: _date);
    if (!mounted) return;
    _existing = existing;
    if (existing != null) {
      _cashCtrl.text = Money.forEdit(existing.cash);
      _cardCtrl.text = Money.forEdit(existing.card);
    } else {
      _cashCtrl.clear();
      _cardCtrl.clear();
    }
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateKeys.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      locale: const Locale('tr', 'TR'),
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked == null) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    if (normalized == _date) return;
    setState(() => _date = normalized);
    await _prefill();
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  double get _cash => Money.tryParse(_cashCtrl.text) ?? 0;
  double get _card => Money.tryParse(_cardCtrl.text) ?? 0;

  bool get _isToday => _date == DateKeys.today();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(revenueRepositoryProvider).upsert(
            shopId: widget.shopId,
            date: _date,
            cash: _cash,
            card: _card,
            createdBy: widget.createdBy,
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
    final scheme = Theme.of(context).colorScheme;
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
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isToday ? 'Bugünün Cirosu' : 'Ciro Girişi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateKeys.human(_date),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!_isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'geçmiş tarih',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more_rounded,
                            size: 20, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  TextFormField(
                    controller: _cashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [TurkishMoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Nakit',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: '₺',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if ((v == null || v.isEmpty) && _cardCtrl.text.isEmpty) {
                        return 'Nakit veya kart girilmeli';
                      }
                      if (v != null && v.isNotEmpty && Money.tryParse(v) == null) {
                        return 'Geçerli bir tutar gir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cardCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [TurkishMoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Kart',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                      suffixText: '₺',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && Money.tryParse(v) == null) {
                        return 'Geçerli bir tutar gir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Toplam',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          Money.format(_cash + _card),
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_existing != null && _existing!.editHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AuditHistory(history: _existing!.editHistory),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditHistory extends StatelessWidget {
  const _AuditHistory({required this.history});
  final List<RevenueEdit> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yyyy HH:mm', 'tr_TR');
    final reversed = history.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Düzenleme geçmişi (${history.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...reversed.take(5).map((e) {
            final when = e.at != null ? fmt.format(e.at!) : '-';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${Money.format(e.oldTotal)} → ${Money.format(e.newTotal)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (history.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... ve ${history.length - 5} eski kayıt daha',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
