import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/partner.dart';
import '../../../models/shop.dart';

class ShopRepository {
  ShopRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _shops => _db.collection('shops');

  Stream<List<Shop>> watchAll() {
    return _shops.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(Shop.fromDoc).toList(),
        );
  }

  Stream<Shop?> watchOne(String shopId) {
    return _shops.doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Shop.fromDoc(doc);
    });
  }

  Future<Shop?> fetch(String shopId) async {
    final doc = await _shops.doc(shopId).get();
    if (!doc.exists) return null;
    return Shop.fromDoc(doc);
  }

  Future<void> updatePartners(String shopId, List<Partner> partners) async {
    if (partners.isEmpty) {
      throw ArgumentError('En az bir ortak gerekli');
    }
    final total = partners.fold(0.0, (acc, p) => acc + p.percentage);
    if ((total - 100).abs() > 0.01) {
      throw ArgumentError(
        'Yüzdelerin toplamı 100 olmalı (şu an: ${total.toStringAsFixed(2)})',
      );
    }
    await _shops.doc(shopId).update({
      'partners': partners.map((p) => p.toMap()).toList(),
    });
  }
}
