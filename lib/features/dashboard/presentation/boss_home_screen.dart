import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../../models/shop.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shop/providers/shop_providers.dart';
import '../providers/boss_dashboard_providers.dart';
import 'shop_detail_screen.dart';

class BossHomeScreen extends ConsumerWidget {
  const BossHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(allShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Dükkanlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (shops) {
          if (shops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz tanımlı dükkan yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _TodayTotalCard(shops: shops),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: shops.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ShopRow(shop: shops[i]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _TodayTotalCard extends ConsumerWidget {
  const _TodayTotalCard({required this.shops});
  final List<Shop> shops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double total = 0;
    int filed = 0;
    for (final s in shops) {
      final rev = ref.watch(shopTodayRevenueProvider(s.id)).value;
      if (rev != null) {
        total += rev.total;
        filed += 1;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bugün — ${DateKeys.human(DateKeys.today())}',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              Money.format(total),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$filed / ${shops.length} dükkan ciro girdi',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopRow extends ConsumerWidget {
  const _ShopRow({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(shopTodayRevenueProvider(shop.id));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.storefront_rounded, color: scheme.onSecondaryContainer),
        ),
        title: Text(
          shop.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: today.when(
          loading: () => const Text('Yükleniyor…'),
          error: (e, _) => Text('Hata: $e'),
          data: (rev) {
            if (rev == null) {
              return Text(
                'Bugün ciro girilmedi',
                style: TextStyle(color: scheme.error),
              );
            }
            return Text(
              'Nakit ${Money.format(rev.cash)}  •  Kart ${Money.format(rev.card)}',
            );
          },
        ),
        trailing: today.when(
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => const Icon(Icons.error_outline),
          data: (rev) => Text(
            rev == null ? '—' : Money.format(rev.total),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
        ),
      ),
    );
  }
}
