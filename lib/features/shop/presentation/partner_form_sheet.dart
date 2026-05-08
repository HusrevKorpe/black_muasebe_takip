import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/partner.dart';

class PartnerFormSheet extends StatefulWidget {
  const PartnerFormSheet({super.key, this.initial});
  final Partner? initial;

  static Future<Partner?> show(
    BuildContext context, {
    Partner? initial,
  }) {
    return showModalBottomSheet<Partner>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PartnerFormSheet(initial: initial),
      ),
    );
  }

  @override
  State<PartnerFormSheet> createState() => _PartnerFormSheetState();
}

class _PartnerFormSheetState extends State<PartnerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _percentageCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _percentageCtrl = TextEditingController(
      text: widget.initial == null
          ? ''
          : _formatPercentage(widget.initial!.percentage),
    );
    _noteCtrl = TextEditingController(text: widget.initial?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _percentageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatPercentage(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString().replaceAll('.', ',');
  }

  double? _parsePercentage(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final percentage = _parsePercentage(_percentageCtrl.text)!;
    final id = widget.initial?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final note = _noteCtrl.text.trim();
    final partner = Partner(
      id: id,
      name: _nameCtrl.text.trim(),
      percentage: percentage,
      note: note.isEmpty ? null : note,
    );
    Navigator.of(context).pop(partner);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Ortağı Düzenle' : 'Ortak Ekle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ad soyad gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _percentageCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Yüzde (%)',
                  hintText: 'örn. 33,33',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                validator: (v) {
                  final parsed = _parsePercentage(v ?? '');
                  if (parsed == null) return 'Geçerli bir sayı girin';
                  if (parsed <= 0) return '0\'dan büyük olmalı';
                  if (parsed > 100) return '100\'den büyük olamaz';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'örn. kurucu ortak',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(isEdit ? 'Güncelle' : 'Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
