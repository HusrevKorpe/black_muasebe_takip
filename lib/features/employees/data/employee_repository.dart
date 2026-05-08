import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/employee.dart';

class EmployeeRepository {
  EmployeeRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String shopId) {
    return _db.collection('shops').doc(shopId).collection('employees');
  }

  Stream<List<Employee>> watchAll(String shopId) {
    return _col(shopId).snapshots().map((snap) {
      final list = snap.docs.map((d) => Employee.fromDoc(shopId, d)).toList();
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      return list;
    });
  }

  Future<void> add({
    required String shopId,
    required String name,
    required String phone,
    required DateTime startDate,
    required String createdBy,
  }) async {
    await _col(shopId).add({
      'name': name,
      'phone': phone,
      'startDate': Timestamp.fromDate(startDate),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String shopId, required String employeeId}) {
    return _col(shopId).doc(employeeId).delete();
  }
}
