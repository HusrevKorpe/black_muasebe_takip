import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_keys.dart';
import '../../../models/employee_ledger_entry.dart';

class EmployeeLedgerRepository {
  EmployeeLedgerRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(
    String shopId,
    String employeeId,
  ) {
    return _db
        .collection('shops')
        .doc(shopId)
        .collection('employees')
        .doc(employeeId)
        .collection('ledger');
  }

  Stream<List<EmployeeLedgerEntry>> watchAll({
    required String shopId,
    required String employeeId,
  }) {
    return _col(shopId, employeeId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => EmployeeLedgerEntry.fromDoc(shopId, employeeId, d))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> add({
    required String shopId,
    required String employeeId,
    required LedgerEntryType type,
    required double amount,
    required DateTime date,
    String? note,
    required String createdBy,
  }) async {
    await _col(shopId, employeeId).add({
      'type': type.wireValue,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'dateKey': DateKeys.key(date),
      if (note != null && note.isNotEmpty) 'note': note,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({
    required String shopId,
    required String employeeId,
    required String entryId,
  }) {
    return _col(shopId, employeeId).doc(entryId).delete();
  }
}
