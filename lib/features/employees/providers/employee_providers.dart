import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/employee.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref.watch(firestoreProvider)),
);

final employeesProvider =
    StreamProvider.family<List<Employee>, String>((ref, shopId) {
  return ref.watch(employeeRepositoryProvider).watchAll(shopId);
});
