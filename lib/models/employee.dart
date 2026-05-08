import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final DateTime startDate;
  final String createdBy;
  final DateTime? createdAt;

  const Employee({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    required this.startDate,
    required this.createdBy,
    this.createdAt,
  });

  factory Employee.fromDoc(
    String shopId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['startDate'];
    final start = ts is Timestamp
        ? ts.toDate()
        : (ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now());
    return Employee(
      id: doc.id,
      shopId: shopId,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      startDate: start,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'phone': phone,
        'startDate': Timestamp.fromDate(startDate),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
