import '../../../models/expense.dart';
import '../../../models/revenue.dart';

class PartnerShare {
  final String partnerName;
  final double percentage;
  final double amount;

  const PartnerShare({
    required this.partnerName,
    required this.percentage,
    required this.amount,
  });
}

class MonthlyReport {
  final String shopId;
  final String shopName;
  final int year;
  final int month;
  final double totalCash;
  final double totalCard;
  final double totalRevenue;
  final double totalExpense;
  final double netProfit;
  final List<PartnerShare> shares;
  final List<Revenue> revenues;
  final List<Expense> expenses;

  const MonthlyReport({
    required this.shopId,
    required this.shopName,
    required this.year,
    required this.month,
    required this.totalCash,
    required this.totalCard,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netProfit,
    required this.shares,
    required this.revenues,
    required this.expenses,
  });

  bool get isLoss => netProfit < 0;
  bool get isEmpty => revenues.isEmpty && expenses.isEmpty;
}
