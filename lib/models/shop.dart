import 'package:cloud_firestore/cloud_firestore.dart';

import 'partner.dart';

class Shop {
  final String id;
  final String name;
  final String ownerId;
  final DateTime? createdAt;
  final List<Partner> partners;

  const Shop({
    required this.id,
    required this.name,
    required this.ownerId,
    this.createdAt,
    this.partners = const [],
  });

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPartners = data['partners'] as List?;
    final partners = rawPartners
            ?.whereType<Map<String, dynamic>>()
            .map(Partner.fromMap)
            .toList() ??
        const <Partner>[];
    return Shop(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      partners: partners,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerId': ownerId,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
        'partners': partners.map((p) => p.toMap()).toList(),
      };

  double get totalPartnerPercentage =>
      partners.fold(0.0, (acc, p) => acc + p.percentage);

  bool get hasValidPartners =>
      partners.isNotEmpty && (totalPartnerPercentage - 100).abs() < 0.01;
}
