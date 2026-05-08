import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_keys.dart';
import '../../../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _expenses(String shopId) {
    return _db.collection('shops').doc(shopId).collection('expenses');
  }

  Stream<List<Expense>> watchRange({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = DateKeys.key(from);
    final toKey = DateKeys.key(to);
    return _expenses(shopId)
        .where('date', isGreaterThanOrEqualTo: fromKey)
        .where('date', isLessThanOrEqualTo: toKey)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Expense.fromDoc(shopId, d)).toList();
      list.sort((a, b) {
        final dateCmp = b.dateKey.compareTo(a.dateKey);
        if (dateCmp != 0) return dateCmp;
        final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });
      return list;
    });
  }

  Future<void> add({
    required String shopId,
    required DateTime date,
    required String name,
    required double amount,
    required String createdBy,
    String? note,
  }) async {
    await _expenses(shopId).add({
      'date': DateKeys.key(date),
      'name': name,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({
    required String shopId,
    required String expenseId,
  }) async {
    await _expenses(shopId).doc(expenseId).delete();
  }
}
