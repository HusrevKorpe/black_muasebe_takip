import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../../models/shop.dart';
import '../../employees/presentation/employees_screen.dart';
import '../../expense/presentation/expenses_screen.dart';
import '../../reports/presentation/monthly_report_screen.dart';
import '../../revenue/providers/revenue_providers.dart';
import '../../shop/presentation/shop_partners_screen.dart';

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({super.key, required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateKeys.today();

    final rangeAsync = ref.watch(revenueRangeProvider(
      RevenueRangeArgs(shopId: shop.id, from: monthStart, to: today),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Menü',
            onPressed: () => _openShopMenu(context, shop.id),
          ),
        ],
      ),
      body: rangeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (revenues) {
          if (revenues.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Bu ay için kayıt bulunamadı.'),
              ),
            );
          }
          final total = revenues.fold<double>(0, (a, b) => a + b.total);
          final cash = revenues.fold<double>(0, (a, b) => a + b.cash);
          final card = revenues.fold<double>(0, (a, b) => a + b.card);
          final avg = total / revenues.length;

          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.surfaceContainerHighest,
                      scheme.surfaceContainer,
                    ],
                  ),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 16,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bu ay özet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Money.format(total),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.0,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Toplam ciro',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.payments_outlined,
                            label: 'Nakit',
                            value: Money.format(cash),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.credit_card_rounded,
                            label: 'Kart',
                            value: Money.format(card),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.show_chart_rounded,
                            label: 'Günlük ort.',
                            value: Money.format(avg),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.event_available_rounded,
                            label: 'Kayıt',
                            value: '${revenues.length} gün',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.list_alt_rounded,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Günlük kayıtlar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...revenues.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.event_rounded,
                              color: scheme.onSecondaryContainer,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateKeys.human(DateTime.parse(r.dateKey)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nakit ${Money.format(r.cash)}  •  Kart ${Money.format(r.card)}',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Money.format(r.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _openShopMenu(BuildContext context, String shopId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        final items = <_MenuAction>[
          _MenuAction(
            icon: Icons.receipt_long_outlined,
            label: 'Giderler',
            color: scheme.tertiary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensesScreen(shopId: shopId, canEdit: false),
              ),
            ),
          ),
          _MenuAction(
            icon: Icons.people_alt_outlined,
            label: 'Personeller',
            color: scheme.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeesScreen(shopId: shopId, canEdit: false),
              ),
            ),
          ),
          _MenuAction(
            icon: Icons.handshake_outlined,
            label: 'Ortaklar',
            color: scheme.secondary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShopPartnersScreen(shopId: shopId),
              ),
            ),
          ),
          _MenuAction(
            icon: Icons.assessment_outlined,
            label: 'Aylık Rapor',
            color: scheme.error,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MonthlyReportScreen(shopId: shopId),
              ),
            ),
          ),
        ];

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      item.onTap();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuAction {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
