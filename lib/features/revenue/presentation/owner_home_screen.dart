import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../auth/providers/auth_providers.dart';
import '../../employees/presentation/employees_screen.dart';
import '../../expense/presentation/expenses_screen.dart';
import '../../shop/providers/shop_providers.dart';
import '../providers/revenue_providers.dart';
import 'revenue_calendar_screen.dart';
import 'revenue_entry_sheet.dart';

class OwnerHomeScreen extends ConsumerStatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final shopId = appUser?.shopId;

    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Muasebe Takip')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Hesabınıza henüz dükkan tanımlanmamış.\nLütfen yöneticinizle iletişime geçin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final shopAsync = ref.watch(shopByIdProvider(shopId));

    return Scaffold(
      appBar: AppBar(
        title: Text(shopAsync.value?.name ?? 'Dükkanım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Giderler',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensesScreen(shopId: shopId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Personeller',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeesScreen(shopId: shopId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Takvim',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _OwnerOverview(shopId: shopId, createdBy: appUser!.uid),
          RevenueCalendarScreen(shopId: shopId, createdBy: appUser.uid),
        ],
      ),
    );
  }
}

class _OwnerOverview extends ConsumerWidget {
  const _OwnerOverview({required this.shopId, required this.createdBy});
  final String shopId;
  final String createdBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayRevenueProvider(TodayRevenueArgs(shopId)));

    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthEnd = DateKeys.today();
    final rangeAsync = ref.watch(revenueRangeProvider(
      RevenueRangeArgs(shopId: shopId, from: monthStart, to: monthEnd),
    ));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _TodayCard(
          todayAsync: todayAsync,
          onEdit: () => RevenueEntrySheet.show(
            context,
            shopId: shopId,
            createdBy: createdBy,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bu Ay',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        rangeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Hata: $e'),
          data: (revenues) {
            if (revenues.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Bu ay henüz kayıt yok.'),
                ),
              );
            }
            final total = revenues.fold<double>(0, (a, b) => a + b.total);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Aylık toplam'),
                        Text(
                          Money.format(total),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          onTap: () => RevenueEntrySheet.show(
                            context,
                            shopId: shopId,
                            createdBy: createdBy,
                            date: DateTime.parse(r.dateKey),
                          ),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.todayAsync, required this.onEdit});
  final AsyncValue todayAsync;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: todayAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Hata: $e'),
          data: (rev) {
            if (rev == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugün için ciro girilmedi',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateKeys.human(DateKeys.today()),
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Şimdi Gir'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateKeys.human(DateKeys.today()),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  Money.format(rev.total),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Nakit',
                        value: Money.format(rev.cash),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Kart',
                        value: Money.format(rev.card),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Düzenle'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              )),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
