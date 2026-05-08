import 'package:cloud_firestore/cloud_firestore.dart';

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
}
