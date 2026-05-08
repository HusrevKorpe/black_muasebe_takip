import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/utils/date_keys.dart';
import '../../../core/utils/money.dart';
import '../../../models/revenue.dart';
import '../providers/revenue_providers.dart';
import 'revenue_entry_sheet.dart';

class RevenueCalendarScreen extends ConsumerStatefulWidget {
  const RevenueCalendarScreen({
    super.key,
    required this.shopId,
    required this.createdBy,
  });

  final String shopId;
  final String createdBy;

  @override
  ConsumerState<RevenueCalendarScreen> createState() => _RevenueCalendarScreenState();
}

class _RevenueCalendarScreenState extends ConsumerState<RevenueCalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;
  CalendarFormat _format = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    final today = DateKeys.today();
    _focused = today;
    _selected = today;
  }

  @override
  Widget build(BuildContext context) {
    final monthAsync = ref.watch(revenueMonthProvider(RevenueMonthArgs(
      shopId: widget.shopId,
      year: _focused.year,
      month: _focused.month,
    )));
    final scheme = Theme.of(context).colorScheme;
    final today = DateKeys.today();
    final firstDay = DateTime(today.year - 2, 1, 1);

    return monthAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (revenues) {
        final byKey = {for (final r in revenues) r.dateKey: r};
        final monthTotal = revenues.fold<double>(0, (a, b) => a + b.total);
        final selectedRev = byKey[DateKeys.key(_selected)];

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: TableCalendar<Revenue>(
                  locale: 'tr_TR',
                  firstDay: firstDay,
                  lastDay: today,
                  focusedDay: _focused.isAfter(today) ? today : _focused,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  calendarFormat: _format,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Ay',
                    CalendarFormat.twoWeeks: '2 Hafta',
                    CalendarFormat.week: 'Hafta',
                  },
                  eventLoader: (day) {
                    final r = byKey[DateKeys.key(day)];
                    return r != null ? [r] : const <Revenue>[];
                  },
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onDaySelected: (selected, focused) {
                    final normalized = DateTime(
                        selected.year, selected.month, selected.day);
                    if (normalized.isAfter(today)) return;
                    setState(() {
                      _selected = normalized;
                      _focused = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() => _focused = focused);
                  },
                  onFormatChanged: (f) => setState(() => _format = f),
                  calendarBuilders: CalendarBuilders<Revenue>(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final r = events.first;
                      return Positioned(
                        bottom: 1,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              Money.compact(r.total),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aylık toplam',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      Money.format(monthTotal),
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SelectedDayCard(
              date: _selected,
              revenue: selectedRev,
              onEdit: () => RevenueEntrySheet.show(
                context,
                shopId: widget.shopId,
                createdBy: widget.createdBy,
                date: _selected,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    required this.revenue,
    required this.onEdit,
  });

  final DateTime date;
  final Revenue? revenue;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateKeys.human(date),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (revenue == null) ...[
              Text(
                'Bu güne kayıt yok.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ciro Gir'),
              ),
            ] else ...[
              Text(
                Money.format(revenue!.total),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nakit ${Money.format(revenue!.cash)}  •  Kart ${Money.format(revenue!.card)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (revenue!.editHistory.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${revenue!.editHistory.length} düzenleme',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}
