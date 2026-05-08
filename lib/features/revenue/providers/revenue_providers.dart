import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_keys.dart';
import '../../../models/revenue.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/revenue_repository.dart';

final revenueRepositoryProvider = Provider<RevenueRepository>(
  (ref) => RevenueRepository(ref.watch(firestoreProvider)),
);

class RevenueRangeArgs {
  final String shopId;
  final DateTime from;
  final DateTime to;
  const RevenueRangeArgs({required this.shopId, required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is RevenueRangeArgs &&
      other.shopId == shopId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(shopId, from, to);
}

final revenueRangeProvider =
    StreamProvider.family<List<Revenue>, RevenueRangeArgs>((ref, args) {
  return ref.watch(revenueRepositoryProvider).watchRange(
        shopId: args.shopId,
        from: args.from,
        to: args.to,
      );
});

class TodayRevenueArgs {
  final String shopId;
  const TodayRevenueArgs(this.shopId);

  @override
  bool operator ==(Object other) =>
      other is TodayRevenueArgs && other.shopId == shopId;

  @override
  int get hashCode => shopId.hashCode;
}

final todayRevenueProvider =
    StreamProvider.family<Revenue?, TodayRevenueArgs>((ref, args) {
  return ref.watch(revenueRepositoryProvider).watchByDate(
        shopId: args.shopId,
        date: DateKeys.today(),
      );
});

class RevenueByDateArgs {
  final String shopId;
  final DateTime date;
  const RevenueByDateArgs({required this.shopId, required this.date});

  @override
  bool operator ==(Object other) =>
      other is RevenueByDateArgs && other.shopId == shopId && other.date == date;

  @override
  int get hashCode => Object.hash(shopId, date);
}

final revenueByDateProvider =
    StreamProvider.family<Revenue?, RevenueByDateArgs>((ref, args) {
  return ref.watch(revenueRepositoryProvider).watchByDate(
        shopId: args.shopId,
        date: args.date,
      );
});

class RevenueMonthArgs {
  final String shopId;
  final int year;
  final int month;
  const RevenueMonthArgs({required this.shopId, required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      other is RevenueMonthArgs &&
      other.shopId == shopId &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(shopId, year, month);
}

final revenueMonthProvider =
    StreamProvider.family<List<Revenue>, RevenueMonthArgs>((ref, args) {
  final from = DateTime(args.year, args.month, 1);
  final to = DateTime(args.year, args.month + 1, 0);
  return ref.watch(revenueRepositoryProvider).watchRange(
        shopId: args.shopId,
        from: from,
        to: to,
      );
});
