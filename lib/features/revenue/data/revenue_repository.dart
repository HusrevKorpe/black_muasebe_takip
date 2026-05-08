import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_keys.dart';
import '../../../models/revenue.dart';

class RevenueRepository {
  RevenueRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _revenues(String shopId) {
    return _db.collection('shops').doc(shopId).collection('revenues');
  }

  Stream<List<Revenue>> watchRange({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = DateKeys.key(from);
    final toKey = DateKeys.key(to);
    return _revenues(shopId)
        .where('date', isGreaterThanOrEqualTo: fromKey)
        .where('date', isLessThanOrEqualTo: toKey)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Revenue.fromDoc(shopId, d)).toList());
  }

  Stream<Revenue?> watchByDate({required String shopId, required DateTime date}) {
    final key = DateKeys.key(date);
    return _revenues(shopId).doc(key).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Revenue.fromDoc(shopId, doc);
    });
  }

  Future<Revenue?> fetchByDate({required String shopId, required DateTime date}) async {
    final key = DateKeys.key(date);
    final doc = await _revenues(shopId).doc(key).get();
    if (!doc.exists) return null;
    return Revenue.fromDoc(shopId, doc);
  }

  /// Aynı güne ikinci kez girişte üzerine yazar; doc id = "yyyy-MM-dd".
  /// Update durumunda eski değerler `editHistory` dizisine append edilir.
  Future<void> upsert({
    required String shopId,
    required DateTime date,
    required double cash,
    required double card,
    required String createdBy,
    String? note,
  }) async {
    final key = DateKeys.key(date);
    final ref = _revenues(shopId).doc(key);
    final existing = await ref.get();

    if (existing.exists) {
      final data = existing.data() ?? {};
      final oldCash = (data['cash'] as num?)?.toDouble() ?? 0;
      final oldCard = (data['card'] as num?)?.toDouble() ?? 0;
      final changed = oldCash != cash || oldCard != card;

      await ref.update({
        'cash': cash,
        'card': card,
        'amount': cash + card,
        if (note != null && note.isNotEmpty) 'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
        if (changed)
          'editHistory': FieldValue.arrayUnion([
            {
              'by': createdBy,
              'at': Timestamp.now(),
              'oldCash': oldCash,
              'oldCard': oldCard,
              'newCash': cash,
              'newCard': card,
            }
          ]),
      });
    } else {
      await ref.set({
        'date': key,
        'cash': cash,
        'card': card,
        'amount': cash + card,
        if (note != null && note.isNotEmpty) 'note': note,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
