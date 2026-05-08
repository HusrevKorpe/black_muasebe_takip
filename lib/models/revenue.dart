import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueEdit {
  final String by;
  final DateTime? at;
  final double oldCash;
  final double oldCard;
  final double newCash;
  final double newCard;

  const RevenueEdit({
    required this.by,
    required this.at,
    required this.oldCash,
    required this.oldCard,
    required this.newCash,
    required this.newCard,
  });

  double get oldTotal => oldCash + oldCard;
  double get newTotal => newCash + newCard;

  factory RevenueEdit.fromMap(Map<String, dynamic> m) {
    return RevenueEdit(
      by: m['by'] as String? ?? '',
      at: (m['at'] as Timestamp?)?.toDate(),
      oldCash: (m['oldCash'] as num?)?.toDouble() ?? 0,
      oldCard: (m['oldCard'] as num?)?.toDouble() ?? 0,
      newCash: (m['newCash'] as num?)?.toDouble() ?? 0,
      newCard: (m['newCard'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Revenue {
  final String id;
  final String shopId;
  final String dateKey;
  final double cash;
  final double card;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RevenueEdit> editHistory;

  const Revenue({
    required this.id,
    required this.shopId,
    required this.dateKey,
    required this.cash,
    required this.card,
    required this.createdBy,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.editHistory = const [],
  });

  double get total => cash + card;

  factory Revenue.fromDoc(
    String shopId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final history = (data['editHistory'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(RevenueEdit.fromMap)
            .toList() ??
        const <RevenueEdit>[];
    return Revenue(
      id: doc.id,
      shopId: shopId,
      dateKey: data['date'] as String? ?? doc.id,
      cash: (data['cash'] as num?)?.toDouble() ?? 0,
      card: (data['card'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      editHistory: history,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'date': dateKey,
        'cash': cash,
        'card': card,
        'amount': total,
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'cash': cash,
        'card': card,
        'amount': total,
        if (note != null) 'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
