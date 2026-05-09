import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/employee.dart';
import '../../../models/employee_ledger_entry.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/employee_ledger_repository.dart';
import '../data/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref.watch(firestoreProvider)),
);

final employeesProvider =
    StreamProvider.family<List<Employee>, String>((ref, shopId) {
  return ref.watch(employeeRepositoryProvider).watchAll(shopId);
});

final employeeLedgerRepositoryProvider = Provider<EmployeeLedgerRepository>(
  (ref) => EmployeeLedgerRepository(ref.watch(firestoreProvider)),
);

typedef EmployeeLedgerKey = ({String shopId, String employeeId});

final employeeLedgerProvider = StreamProvider.family<
    List<EmployeeLedgerEntry>, EmployeeLedgerKey>((ref, key) {
  return ref.watch(employeeLedgerRepositoryProvider).watchAll(
        shopId: key.shopId,
        employeeId: key.employeeId,
      );
});
