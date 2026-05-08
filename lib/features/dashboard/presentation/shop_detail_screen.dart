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
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Giderler',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensesScreen(
                  shopId: shop.id,
                  canEdit: false,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Personeller',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeesScreen(
                  shopId: shop.id,
                  canEdit: false,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.handshake_outlined),
            tooltip: 'Ortaklar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShopPartnersScreen(shopId: shop.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Aylık Rapor',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MonthlyReportScreen(shopId: shop.id),
              ),
            ),
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu ay özet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _row(context, 'Toplam', Money.format(total), bold: true),
                      const SizedBox(height: 6),
                      _row(context, 'Nakit', Money.format(cash)),
                      const SizedBox(height: 6),
                      _row(context, 'Kart', Money.format(card)),
                      const Divider(height: 24),
                      _row(context, 'Günlük ortalama', Money.format(avg)),
                      const SizedBox(height: 6),
                      _row(context, 'Kayıt sayısı', '${revenues.length} gün'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Günlük kayıtlar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ...revenues.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(DateKeys.human(DateTime.parse(r.dateKey))),
                        subtitle: Text(
                          'Nakit ${Money.format(r.cash)}  •  Kart ${Money.format(r.card)}',
                        ),
                        trailing: Text(
                          Money.format(r.total),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
