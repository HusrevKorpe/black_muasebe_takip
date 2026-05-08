import '../../../models/expense.dart';
import '../../../models/revenue.dart';
import '../../../models/shop.dart';
import 'monthly_report.dart';

/// dateKey "YYYY-MM-DD" formatındaysa istenen yıl+ay'a denk geliyor mu?
/// Geçersiz format dışlanır (rapora alınmaz).
bool _isInMonth(String dateKey, int year, int month) {
  if (dateKey.length < 7) return false;
  final y = int.tryParse(dateKey.substring(0, 4));
  final m = int.tryParse(dateKey.substring(5, 7));
  return y == year && m == month;
}

MonthlyReport calculateMonthlyReport({
  required Shop shop,
  required List<Revenue> revenues,
  required List<Expense> expenses,
  required int year,
  required int month,
}) {
  final monthRevenues = revenues
      .where((r) => _isInMonth(r.dateKey, year, month))
      .toList()
    ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

  final monthExpenses = expenses
      .where((e) => _isInMonth(e.dateKey, year, month))
      .toList()
    ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

  final totalCash = monthRevenues.fold(0.0, (acc, r) => acc + r.cash);
  final totalCard = monthRevenues.fold(0.0, (acc, r) => acc + r.card);
  final totalRevenue = totalCash + totalCard;
  final totalExpense = monthExpenses.fold(0.0, (acc, e) => acc + e.amount);
  final netProfit = totalRevenue - totalExpense;

  final shares = shop.partners
      .map((p) => PartnerShare(
            partnerName: p.name,
            percentage: p.percentage,
            amount: netProfit * (p.percentage / 100),
          ))
      .toList();

  return MonthlyReport(
    shopId: shop.id,
    shopName: shop.name,
    year: year,
    month: month,
    totalCash: totalCash,
    totalCard: totalCard,
    totalRevenue: totalRevenue,
    totalExpense: totalExpense,
    netProfit: netProfit,
    shares: shares,
    revenues: monthRevenues,
    expenses: monthExpenses,
  );
}
