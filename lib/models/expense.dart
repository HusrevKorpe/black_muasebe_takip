import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String shopId;
  final String dateKey;
  final String name;
  final double amount;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.shopId,
    required this.dateKey,
    required this.name,
    required this.amount,
    required this.createdBy,
    this.note,
    this.createdAt,
  });

  factory Expense.fromDoc(
    String shopId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Expense(
      id: doc.id,
      shopId: shopId,
      dateKey: data['date'] as String? ?? '',
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'date': dateKey,
        'name': name,
        'amount': amount,
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
