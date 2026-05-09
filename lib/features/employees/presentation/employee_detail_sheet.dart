import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../models/employee.dart';
import '../../../models/employee_ledger_entry.dart';
import '../../../models/partner.dart';
import '../../shop/providers/shop_providers.dart';
import '../providers/employee_providers.dart';
import 'ledger_entry_sheet.dart';

class EmployeeDetailSheet extends ConsumerWidget {
  const EmployeeDetailSheet({
    super.key,
    required this.employee,
    required this.scrollController,
    this.canEdit = true,
  });

  final Employee employee;
  final ScrollController scrollController;
  final bool canEdit;

  static Future<void> show(
    BuildContext context, {
    required Employee employee,
    bool canEdit = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => EmployeeDetailSheet(
          employee: employee,
          canEdit: canEdit,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerKey = (shopId: employee.shopId, employeeId: employee.id);
    final ledgerAsync = ref.watch(employeeLedgerProvider(ledgerKey));
    final shopAsync = ref.watch(shopByIdProvider(employee.shopId));

    Partner? linkedPartner;
    if (employee.partnerId != null) {
      final partners = shopAsync.value?.partners ?? const <Partner>[];
      for (final p in partners) {
        if (p.id == employee.partnerId) {
          linkedPartner = p;
          break;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ledgerAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Hareketler yüklenemedi: $e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (entries) {
                final balance = entries.fold<double>(
                  0,
                  (acc, e) => acc + e.signedAmount,
                );
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _Header(employee: employee, partner: linkedPartner),
                    const SizedBox(height: 12),
                    _BalanceCard(balance: balance),
                    const SizedBox(height: 12),
                    if (canEdit)
                      FilledButton.icon(
                        onPressed: () => LedgerEntrySheet.show(
                          context,
                          shopId: employee.shopId,
                          employeeId: employee.id,
                          employeeName: employee.name,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Hareket Ekle'),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Hareketler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            canEdit
                                ? 'Henüz hareket yok.'
                                : 'Bu personel için kayıtlı hareket yok.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ...entries.map(
                        (e) => _LedgerTile(
                          entry: e,
                          onDelete:
                              canEdit ? () => _confirmDelete(context, ref, e) : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EmployeeLedgerEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text(
          '${entry.type.label} ${Money.format(entry.amount)} kaydı silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(employeeLedgerRepositoryProvider).delete(
            shopId: entry.shopId,
            employeeId: entry.employeeId,
            entryId: entry.id,
          );
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: $err')),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.employee, this.partner});
  final Employee employee;
  final Partner? partner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          child: Text(_initials(employee.name)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                employee.phone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Başlangıç: ${DateFormat('d MMM yyyy', 'tr_TR').format(employee.startDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (partner != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.handshake_rounded,
                        size: 14,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ortak %${partner!.percentage.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (balance) {
      > 0 => (
          'Borç bakiyesi',
          theme.colorScheme.errorContainer,
          Icons.trending_up_rounded,
        ),
      < 0 => (
          'Fazla ödeme',
          theme.colorScheme.tertiaryContainer,
          Icons.trending_down_rounded,
        ),
      _ => (
          'Bakiye temiz',
          theme.colorScheme.secondaryContainer,
          Icons.check_circle_rounded,
        ),
    };
    final onColor = balance > 0
        ? theme.colorScheme.onErrorContainer
        : balance < 0
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.onSecondaryContainer;

    return Card(
      color: color,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: onColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: onColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.format(balance.abs()),
                    style: TextStyle(
                      color: onColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
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

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, this.onDelete});
  final EmployeeLedgerEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = entry.type.sign > 0;
    final color =
        isPositive ? theme.colorScheme.error : theme.colorScheme.primary;
    final sign = isPositive ? '+' : '−';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              switch (entry.type) {
                LedgerEntryType.avans => Icons.savings_outlined,
                LedgerEntryType.borc => Icons.trending_up_rounded,
                LedgerEntryType.odeme => Icons.trending_down_rounded,
              },
              color: color,
            ),
          ),
          title: Row(
            children: [
              Text(
                entry.type.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$sign${Money.format(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('d MMM yyyy', 'tr_TR').format(entry.date)),
              if (entry.note != null && entry.note!.isNotEmpty)
                Text(
                  entry.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          trailing: onDelete == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Sil',
                  onPressed: onDelete,
                ),
        ),
      ),
    );
  }
}
