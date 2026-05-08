import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/expense.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(firestoreProvider)),
);

class ExpenseRangeArgs {
  final String shopId;
  final DateTime from;
  final DateTime to;
  const ExpenseRangeArgs({
    required this.shopId,
    required this.from,
    required this.to,
  });

  @override
  bool operator ==(Object other) =>
      other is ExpenseRangeArgs &&
      other.shopId == shopId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(shopId, from, to);
}

final expenseRangeProvider =
    StreamProvider.family<List<Expense>, ExpenseRangeArgs>((ref, args) {
  return ref.watch(expenseRepositoryProvider).watchRange(
        shopId: args.shopId,
        from: args.from,
        to: args.to,
      );
});
