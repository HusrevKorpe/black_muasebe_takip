import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/partner.dart';
import '../providers/shop_providers.dart';
import 'partner_form_sheet.dart';

class ShopPartnersScreen extends ConsumerStatefulWidget {
  const ShopPartnersScreen({super.key, required this.shopId});
  final String shopId;

  @override
  ConsumerState<ShopPartnersScreen> createState() => _ShopPartnersScreenState();
}

class _ShopPartnersScreenState extends ConsumerState<ShopPartnersScreen> {
  List<Partner>? _draft;
  bool _saving = false;

  double get _totalPercentage =>
      (_draft ?? const <Partner>[]).fold(0.0, (acc, p) => acc + p.percentage);

  bool get _isValid {
    final d = _draft;
    if (d == null) return false;
    return d.isNotEmpty && (_totalPercentage - 100).abs() < 0.01;
  }

  bool _isDirty(List<Partner> server) {
    final d = _draft;
    if (d == null) return false;
    if (d.length != server.length) return true;
    for (var i = 0; i < d.length; i++) {
      final a = d[i];
      final b = server[i];
      if (a.id != b.id ||
          a.name != b.name ||
          a.percentage != b.percentage ||
          a.note != b.note) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addPartner() async {
    final partner = await PartnerFormSheet.show(context);
    if (partner == null) return;
    setState(() => _draft!.add(partner));
  }

  Future<void> _editPartner(int index) async {
    final partner = await PartnerFormSheet.show(
      context,
      initial: _draft![index],
    );
    if (partner == null) return;
    setState(() => _draft![index] = partner);
  }

  void _removePartner(int index) {
    setState(() => _draft!.removeAt(index));
  }

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(shopRepositoryProvider)
          .updatePartners(widget.shopId, _draft!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ortaklar kaydedildi')),
        );
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text('Çıkmak istediğine emin misin? Yaptığın değişiklikler kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopByIdProvider(widget.shopId));

    return shopAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Ortaklar')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Ortaklar')),
        body: Center(child: Text('Hata: $e')),
      ),
      data: (shop) {
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ortaklar')),
            body: const Center(child: Text('Dükkan bulunamadı')),
          );
        }
        // İlk veri geldiğinde draft'ı sunucudaki ortaklarla doldur
        _draft ??= List.of(shop.partners);
        final draft = _draft!;
        final dirty = _isDirty(shop.partners);

        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final ok = await _confirmDiscard();
            if (!context.mounted) return;
            if (ok) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Ortaklar — ${shop.name}'),
            ),
            body: Column(
              children: [
                _SummaryCard(
                  total: _totalPercentage,
                  partnerCount: draft.length,
                  isValid: _isValid,
                ),
                Expanded(
                  child: draft.isEmpty
                      ? _EmptyState(onAdd: _addPartner)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: draft.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _PartnerRow(
                            partner: draft[i],
                            onEdit: () => _editPartner(i),
                            onDelete: () => _removePartner(i),
                          ),
                        ),
                ),
              ],
            ),
            floatingActionButton: draft.isEmpty
                ? null
                : FloatingActionButton.extended(
                    onPressed: _addPartner,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Ortak Ekle'),
                  ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: (_saving || !_isValid) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Kaydet'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.partnerCount,
    required this.isValid,
  });
  final double total;
  final int partnerCount;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isValid ? scheme.primaryContainer : scheme.errorContainer;
    final onColor = isValid ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    final formatted = total == total.roundToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: onColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toplam: %$formatted',
                      style: TextStyle(
                        color: onColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partnerCount == 0
                          ? 'Henüz ortak yok'
                          : isValid
                              ? '$partnerCount ortak — toplam doğru'
                              : '$partnerCount ortak — %100 olmalı',
                      style: TextStyle(color: onColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.partner,
    required this.onEdit,
    required this.onDelete,
  });
  final Partner partner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatPct(double v) {
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Text(
            '%${_formatPct(partner.percentage)}',
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          partner.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: partner.note == null || partner.note!.isEmpty
            ? null
            : Text(partner.note!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Düzenle',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Bu dükkan için henüz ortak yok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aylık raporlama için en az bir ortak gerekli',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('İlk Ortağı Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
