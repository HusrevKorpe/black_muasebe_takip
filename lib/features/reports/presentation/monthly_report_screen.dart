import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final pct = await _askCardTaxPct();
    if (pct == null) return;
    if (!mounted) return;

    setState(() => _exporting = true);
    try {
      final file = await ExcelExportService.generate(report, cardTaxPct: pct);
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

  Future<double?> _askCardTaxPct() {
    return showDialog<double>(
      context: context,
      builder: (_) => const _CardTaxDialog(),
    );
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

class _CardTaxDialog extends StatefulWidget {
  const _CardTaxDialog();

  @override
  State<_CardTaxDialog> createState() => _CardTaxDialogState();
}

class _CardTaxDialogState extends State<_CardTaxDialog> {
  static const _quickPicks = <double>[2.5, 3.75, 4.25];

  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _errorText;
  double? _selectedPick;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  double? _parse() {
    final raw = _controller.text
        .trim()
        .replaceAll('/', '.')
        .replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    final v = double.tryParse(raw);
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  void _applyQuickPick(double value) {
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString().replaceAll('.', ',');
    setState(() {
      _controller.text = formatted;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _selectedPick = value;
      _errorText = null;
    });
  }

  void _submit() {
    final v = _parse();
    if (v == null) {
      setState(() => _errorText = '0 ile 100 arası geçerli bir sayı girin');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bu ay banka tarafından kart toplamından kesilen vergi yüzdesini girin.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildQuickPicks(scheme),
                  const SizedBox(height: 14),
                  _buildInput(scheme),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Boş bırakırsanız vergi uygulanmaz.',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: scheme.outlineVariant,
                            ),
                            foregroundColor: scheme.onSurface,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Excel İndir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55) ?? scheme.primary,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.percent_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kart Vergisi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Excel raporuna uygulansın',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPicks(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı seçim',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickPicks.map((pct) {
            final selected = _selectedPick == pct;
            final label =
                '%${pct.toString().replaceAll('.', ',')}';
            return _QuickPickChip(
              label: label,
              selected: selected,
              onTap: () => _applyQuickPick(pct),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInput(ColorScheme scheme) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: 0.2,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_SlashToCommaFormatter()],
      decoration: InputDecoration(
        hintText: '0,0',
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Icon(
            Icons.percent_rounded,
            color: scheme.primary,
            size: 16,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        errorText: _errorText,
        errorStyle: TextStyle(
          fontSize: 11,
          color: scheme.error,
          fontWeight: FontWeight.w500,
        ),
      ),
      onChanged: (_) {
        if (_selectedPick != null || _errorText != null) {
          setState(() {
            _selectedPick = null;
            _errorText = null;
          });
        }
      },
      onSubmitted: (_) => _submit(),
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurface,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashToCommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains('/')) return newValue;
    return TextEditingValue(
      text: newValue.text.replaceAll('/', ','),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
