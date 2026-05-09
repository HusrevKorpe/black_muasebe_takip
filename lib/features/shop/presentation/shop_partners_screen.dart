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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: draft.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _PartnerRow(
                            partner: draft[i],
                            onEdit: () => _editPartner(i),
                            onDelete: () => _removePartner(i),
                          ),
                        ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _addPartner,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Ortak Ekle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatPct(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

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
    final accent = isValid ? scheme.primary : scheme.error;
    final accentTone = isValid ? scheme.tertiary : scheme.errorContainer;
    final progress = (total / 100).clamp(0.0, 1.0);
    final formatted = _formatPct(total);
    final isEmpty = partnerCount == 0;
    final delta = (100 - total);

    String statusText;
    if (isEmpty) {
      statusText = 'Henüz ortak yok';
    } else if (isValid) {
      statusText = '$partnerCount ortak — dağılım tamam';
    } else if (delta > 0) {
      statusText = '%${_formatPct(delta)} eksik';
    } else {
      statusText = '%${_formatPct(-delta)} fazla';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              Color.alphaBlend(accentTone.withValues(alpha: 0.55), accent),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          scheme.onPrimary.withValues(alpha: 0.20),
                      valueColor:
                          AlwaysStoppedAnimation(scheme.onPrimary),
                    ),
                  ),
                  Text(
                    '%$formatted',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isValid
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: scheme.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isValid ? 'Dağılım doğru' : 'Dağılım eksik',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          color: scheme.onPrimary,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$partnerCount ortak',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = (partner.percentage / 100).clamp(0.0, 1.0);
    final initial = partner.name.trim().isEmpty
        ? '?'
        : partner.name.trim().characters.first.toUpperCase();

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          Color.alphaBlend(
                            scheme.tertiary.withValues(alpha: 0.55),
                            scheme.primary,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (partner.note != null &&
                            partner.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            partner.note!,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '%${_formatPct(partner.percentage)}',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Sil',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 5,
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation(scheme.primary),
                ),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    Color.alphaBlend(
                      scheme.tertiary.withValues(alpha: 0.20),
                      scheme.primaryContainer,
                    ),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.handshake_rounded,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Henüz ortak eklenmedi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aylık raporlama ve kâr dağılımı için\nen az bir ortak ekle',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'İlk Ortağı Ekle',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
