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
    final progress = shops.isEmpty ? 0.0 : filed / shops.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.today_rounded,
                    color: scheme.onPrimary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateKeys.human(DateKeys.today()),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              Money.format(total),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bugünün toplam cirosu',
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: 0.75),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  filed == shops.length
                      ? Icons.check_circle_rounded
                      : Icons.access_time_rounded,
                  color: scheme.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$filed / ${shops.length} dükkan ciro girdi',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: scheme.onPrimary.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
              ),
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
    final hasRevenue = today.value != null;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasRevenue
                  ? scheme.outlineVariant.withValues(alpha: 0.4)
                  : scheme.error.withValues(alpha: 0.35),
              width: hasRevenue ? 1 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.secondaryContainer,
                      Color.alphaBlend(
                        scheme.primary.withValues(alpha: 0.15),
                        scheme.secondaryContainer,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    today.when(
                      loading: () => Text(
                        'Yükleniyor…',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      error: (e, _) => Text(
                        'Hata: $e',
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                      data: (rev) {
                        if (rev == null) {
                          return Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: scheme.error,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bugün ciro girilmedi',
                                style: TextStyle(
                                  color: scheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }
                        return Text(
                          'Nakit ${Money.format(rev.cash)}  •  Kart ${Money.format(rev.card)}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              today.when(
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => Icon(Icons.error_outline, color: scheme.error),
                data: (rev) => Text(
                  rev == null ? '—' : Money.format(rev.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.4,
                    color: rev == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
