import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../auth/providers/auth_providers.dart';
import '../../employees/presentation/employees_screen.dart';
import '../../expense/presentation/expenses_screen.dart';
import '../../settings/presentation/theme_switch_tile.dart';
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
      extendBody: true,
      appBar: AppBar(
        title: Text(
          shopAsync.value?.name ?? 'Dükkanım',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Menü',
            onPressed: () => _openOwnerMenu(context, shopId),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingBottomNav(
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
        items: const [
          _NavItem(
            outlined: Icons.home_outlined,
            filled: Icons.home_rounded,
            label: 'Ana Sayfa',
          ),
          _NavItem(
            outlined: Icons.calendar_month_outlined,
            filled: Icons.calendar_month_rounded,
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

  void _openOwnerMenu(BuildContext context, String shopId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        final items = <_OwnerMenuAction>[
          _OwnerMenuAction(
            icon: Icons.receipt_long_outlined,
            label: 'Giderler',
            color: scheme.tertiary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensesScreen(shopId: shopId),
              ),
            ),
          ),
          _OwnerMenuAction(
            icon: Icons.people_alt_outlined,
            label: 'Personeller',
            color: scheme.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeesScreen(shopId: shopId),
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
                const ThemeSwitchTile(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnerMenuAction {
  const _OwnerMenuAction({
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

class _NavItem {
  const _NavItem({
    required this.outlined,
    required this.filled,
    required this.label,
  });
  final IconData outlined;
  final IconData filled;
  final String label;
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.selectedIndex,
    required this.onChanged,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Container(
          height: 62,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.92)
                : scheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.10),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(items.length, (i) {
              final selected = i == selectedIndex;
              final item = items[i];
              return Expanded(
                child: _NavTab(
                  selected: selected,
                  item: item,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.selected,
    required this.item,
    required this.onTap,
  });

  final bool selected;
  final _NavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    Color.alphaBlend(
                      scheme.tertiary.withValues(alpha: 0.55),
                      scheme.primary,
                    ),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(34),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? item.filled : item.outlined,
                key: ValueKey(selected),
                size: 22,
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _TodayCard(
          todayAsync: todayAsync,
          onEdit: () => RevenueEntrySheet.show(
            context,
            shopId: shopId,
            createdBy: createdBy,
          ),
        ),
        const SizedBox(height: 24),
        rangeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Hata: $e'),
          data: (revenues) {
            if (revenues.isEmpty) {
              return _SoftCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Text('Bu ay henüz kayıt yok.'),
                  ],
                ),
              );
            }
            final total = revenues.fold<double>(0, (a, b) => a + b.total);
            final cash = revenues.fold<double>(0, (a, b) => a + b.cash);
            final card = revenues.fold<double>(0, (a, b) => a + b.card);
            final avg = total / revenues.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthSummaryCard(
                  total: total,
                  cash: cash,
                  card: card,
                  avg: avg,
                  days: revenues.length,
                ),
                const SizedBox(height: 22),
                _SectionHeader(
                  icon: Icons.list_alt_rounded,
                  label: 'Günlük kayıtlar',
                ),
                const SizedBox(height: 12),
                ...revenues.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DayRow(
                        revenue: r,
                        onTap: () => RevenueEntrySheet.show(
                          context,
                          shopId: shopId,
                          createdBy: createdBy,
                          date: DateTime.parse(r.dateKey),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
      ],
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.total,
    required this.cash,
    required this.card,
    required this.avg,
    required this.days,
  });
  final double total;
  final double cash;
  final double card;
  final double avg;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  value: '$days gün',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _DayRow extends StatelessWidget {
  const _DayRow({required this.revenue, required this.onTap});
  final dynamic revenue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
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
                      DateKeys.human(DateTime.parse(revenue.dateKey)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nakit ${Money.format(revenue.cash)}  •  Kart ${Money.format(revenue.card)}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.format(revenue.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
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
        child: todayAsync.when(
          loading: () => SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: scheme.onPrimary),
            ),
          ),
          error: (e, _) =>
              Text('Hata: $e', style: TextStyle(color: scheme.onPrimary)),
          data: (rev) {
            if (rev == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateChip(date: DateKeys.human(DateKeys.today())),
                  const SizedBox(height: 16),
                  Text(
                    'Bugün için\nciro girilmedi',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onPrimary,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Şimdi Gir',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateChip(date: DateKeys.human(DateKeys.today())),
                const SizedBox(height: 14),
                Text(
                  Money.format(rev.total),
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
                  'Bugünün cirosu',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.payments_outlined,
                        label: 'Nakit',
                        value: Money.format(rev.cash),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.credit_card_rounded,
                        label: 'Kart',
                        value: Money.format(rev.card),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onPrimary,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Düzenle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
            date,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: scheme.onPrimary.withValues(alpha: 0.85),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
