import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../models/employee.dart';
import '../../../models/employee_ledger_entry.dart';
import '../../../models/expense.dart';
import '../../../models/revenue.dart';
import '../../../models/shop.dart';
import '../../employees/providers/employee_providers.dart';
import '../../expense/providers/expense_providers.dart';
import '../../revenue/providers/revenue_providers.dart';
import '../../shop/providers/shop_providers.dart';
import '../logic/monthly_report.dart';
import '../logic/monthly_report_calculator.dart';
import '../services/excel_export_service.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key, required this.shopId});
  final String shopId;

  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late int _year;
  late int _month;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shiftMonth(int delta) {
    var y = _year;
    var m = _month + delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    setState(() {
      _year = y;
      _month = m;
    });
  }

  bool get _isCurrentOrFutureMonth {
    final now = DateTime.now();
    if (_year > now.year) return true;
    if (_year == now.year && _month >= now.month) return true;
    return false;
  }

  Future<void> _exportToExcel(MonthlyReport report) async {
    setState(() => _exporting = true);
    try {
      final file = await ExcelExportService.generate(report);
      if (!mounted) return;
      await ExcelExportService.share(file, context);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel oluşturulamadı: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopByIdProvider(widget.shopId));
    final from = DateTime(_year, _month, 1);
    final to = DateTime(_year, _month + 1, 0);
    final revenuesAsync = ref.watch(revenueMonthProvider(
      RevenueMonthArgs(shopId: widget.shopId, year: _year, month: _month),
    ));
    final expensesAsync = ref.watch(expenseRangeProvider(
      ExpenseRangeArgs(shopId: widget.shopId, from: from, to: to),
    ));
    final employeesAsync = ref.watch(employeesProvider(widget.shopId));

    final partneredEmployees = (employeesAsync.value ?? const <Employee>[])
        .where((e) => e.isPartner)
        .toList();

    final ledgersByEmployee = <String, List<EmployeeLedgerEntry>>{};
    var ledgersReady = true;
    for (final emp in partneredEmployees) {
      final async = ref.watch(employeeLedgerProvider(
        (shopId: widget.shopId, employeeId: emp.id),
      ));
      final value = async.value;
      if (value == null) {
        ledgersReady = false;
      } else {
        ledgersByEmployee[emp.id] = value;
      }
    }

    final report = _tryBuildReport(
      shopAsync,
      revenuesAsync,
      expensesAsync,
      employees: employeesAsync.value,
      ledgersByEmployee: ledgersReady ? ledgersByEmployee : null,
    );
    final canExport = report != null && !_exporting;

    return Scaffold(
      appBar: AppBar(
        title: Text(shopAsync.value?.name == null
            ? 'Aylık Rapor'
            : 'Aylık Rapor — ${shopAsync.value!.name}'),
      ),
      body: Column(
        children: [
          _MonthSelector(
            year: _year,
            month: _month,
            onPrev: () => _shiftMonth(-1),
            onNext: _isCurrentOrFutureMonth ? null : () => _shiftMonth(1),
          ),
          Expanded(
            child: _buildBody(shopAsync, revenuesAsync, expensesAsync, report),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: canExport ? () => _exportToExcel(report) : null,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(_exporting ? 'Hazırlanıyor…' : 'Excel olarak indir'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MonthlyReport? _tryBuildReport(
    AsyncValue<Shop?> shopAsync,
    AsyncValue<List<Revenue>> revenuesAsync,
    AsyncValue<List<Expense>> expensesAsync, {
    List<Employee>? employees,
    Map<String, List<EmployeeLedgerEntry>>? ledgersByEmployee,
  }) {
    final shop = shopAsync.value;
    final revenues = revenuesAsync.value;
    final expenses = expensesAsync.value;
    if (shop == null || revenues == null || expenses == null) return null;
    if (ledgersByEmployee == null) return null;
    return calculateMonthlyReport(
      shop: shop,
      revenues: revenues,
      expenses: expenses,
      year: _year,
      month: _month,
      employees: employees ?? const [],
      ledgersByEmployee: ledgersByEmployee,
    );
  }

  Widget _buildBody(
    AsyncValue<Shop?> shopAsync,
    AsyncValue<List<Revenue>> revenuesAsync,
    AsyncValue<List<Expense>> expensesAsync,
    MonthlyReport? report,
  ) {
    if (shopAsync.hasError) {
      return Center(child: Text('Dükkan hatası: ${shopAsync.error}'));
    }
    if (revenuesAsync.hasError) {
      return Center(child: Text('Ciro hatası: ${revenuesAsync.error}'));
    }
    if (expensesAsync.hasError) {
      return Center(child: Text('Gider hatası: ${expensesAsync.error}'));
    }
    if (shopAsync.value == null && !shopAsync.isLoading) {
      return const Center(child: Text('Dükkan bulunamadı'));
    }
    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SummaryCard(report: report),
        const SizedBox(height: 16),
        _SharesCard(report: report),
        if (report.isEmpty) ...[
          const SizedBox(height: 16),
          const _EmptyMonthNotice(),
        ],
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'tr_TR')
        .format(DateTime(year, month))
        .replaceFirstMapped(
          RegExp(r'^.'),
          (m) => m.group(0)!.toUpperCase(),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Önceki ay',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Sonraki ay',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profitColor = report.isLoss ? scheme.error : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aylık Özet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            _row('Toplam Nakit', Money.format(report.totalCash)),
            const SizedBox(height: 6),
            _row('Toplam Kart', Money.format(report.totalCard)),
            const Divider(height: 24),
            _row(
              'Toplam Ciro',
              Money.format(report.totalRevenue),
              bold: true,
            ),
            const SizedBox(height: 6),
            _row(
              'Toplam Gider',
              '- ${Money.format(report.totalExpense)}',
              valueColor: scheme.error,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.isLoss ? 'Net Zarar' : 'Net Kâr',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  Money.format(report.netProfit),
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${report.revenues.length} ciro kaydı  •  ${report.expenses.length} gider kaydı',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class _SharesCard extends StatelessWidget {
  const _SharesCard({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (report.shares.isEmpty) {
      return Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu dükkan için ortak tanımlı değil',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kâr dağılımını görmek için önce ortakları tanımlayın.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ortaklık Dağılımı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            ...report.shares.expand((share) => [
                  _ShareRow(share: share),
                  const SizedBox(height: 12),
                ]),
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share});
  final PartnerShare share;

  String _formatPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      '%${_formatPct(share.percentage)}',
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      share.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Money.format(share.hasDeductions ? share.netAmount : share.amount),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: share.netAmount < 0
                    ? scheme.error
                    : share.hasDeductions
                        ? scheme.primary
                        : null,
              ),
            ),
          ],
        ),
        if (share.hasDeductions) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pay: ${Money.format(share.amount)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Borç: −${Money.format(share.deductions)}',
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyMonthNotice extends StatelessWidget {
  const _EmptyMonthNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bu ay için henüz ciro veya gider kaydı yok.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
