import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final DateTime startDate;
  final String createdBy;
  final DateTime? createdAt;
  final String? partnerId;

  const Employee({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    required this.startDate,
    required this.createdBy,
    this.createdAt,
    this.partnerId,
  });

  bool get isPartner => partnerId != null && partnerId!.isNotEmpty;

  factory Employee.fromDoc(
    String shopId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['startDate'];
    final start = ts is Timestamp
        ? ts.toDate()
        : (ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now());
    final pid = data['partnerId'] as String?;
    return Employee(
      id: doc.id,
      shopId: shopId,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      startDate: start,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      partnerId: (pid == null || pid.isEmpty) ? null : pid,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'phone': phone,
        'startDate': Timestamp.fromDate(startDate),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        if (partnerId != null && partnerId!.isNotEmpty) 'partnerId': partnerId,
      };
}
