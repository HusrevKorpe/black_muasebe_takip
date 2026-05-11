import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../auth/providers/auth_providers.dart';
import '../../revenue/providers/revenue_providers.dart';
import '../providers/expense_providers.dart';
import 'expense_entry_sheet.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({
    super.key,
    required this.shopId,
    this.canEdit = true,
  });

  final String shopId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateKeys.today();
    final appUser = ref.watch(currentAppUserProvider).value;

    final rangeAsync = ref.watch(expenseRangeProvider(
      ExpenseRangeArgs(shopId: shopId, from: monthStart, to: today),
    ));
    final revenueAsync = ref.watch(revenueRangeProvider(
      RevenueRangeArgs(shopId: shopId, from: monthStart, to: today),
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('Giderler')),
      floatingActionButton: canEdit && appUser != null
          ? FloatingActionButton.extended(
              onPressed: () => ExpenseEntrySheet.show(
                context,
                shopId: shopId,
                createdBy: appUser.uid,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Gider'),
            )
          : null,
      body: rangeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  canEdit
                      ? 'Bu ay henüz gider girilmemiş.\nSağ alttan ekleyebilirsin.'
                      : 'Bu ay için gider kaydı yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final total = expenses.fold<double>(0, (a, b) => a + b.amount);
          final cashRevenue = revenueAsync.maybeWhen(
            data: (revs) => revs.fold<double>(0, (a, b) => a + b.cash),
            orElse: () => 0.0,
          );
          final cashInRegister = cashRevenue - total;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aylık toplam',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        Money.format(total),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _CashInRegisterCard(amount: cashInRegister),
              const SizedBox(height: 12),
              ...expenses.map((e) {
                final tile = Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      e.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      DateKeys.human(DateTime.parse(e.dateKey)) +
                          (e.note != null && e.note!.isNotEmpty
                              ? '  •  ${e.note}'
                              : ''),
                    ),
                    trailing: Text(
                      Money.format(e.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                );
                if (!canEdit) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: tile,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Gideri sil?'),
                              content: Text(
                                '"${e.name}" silinecek. Bu işlem geri alınamaz.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('Vazgeç'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) async {
                      try {
                        await ref.read(expenseRepositoryProvider).delete(
                              shopId: shopId,
                              expenseId: e.id,
                            );
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Silinemedi: $err')),
                          );
                        }
                      }
                    },
                    child: tile,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CashInRegisterCard extends StatelessWidget {
  const _CashInRegisterCard({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1B873F);
    const greenSoft = Color(0xFFE6F4EA);
    return Card(
      elevation: 0,
      color: greenSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: green.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: green,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kasadaki Nakit Para',
                    style: TextStyle(
                      color: green,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bu ay nakit ciro − giderler',
                    style: TextStyle(
                      color: green.withValues(alpha: 0.75),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Money.format(amount),
              style: const TextStyle(
                color: green,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
