import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await cred.user!.getIdToken(true);

    // 1) users/{uid} doğrulaması — auth token Firestore'a propagate oldu mu?
    final userSnap = await _readWithAuthRetry(
      () => _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server)),
    );

    // 2) userDoc() chain'i kullanan kuralların da hazır olduğunu doğrula.
    //    Owner: shops/{shopId}, Boss: shops koleksiyonu (limit 1).
    final data = userSnap.data();
    final role = data?['role'] as String?;
    final shopId = data?['shopId'] as String?;

    if (role == 'owner' && shopId != null && shopId.isNotEmpty) {
      await _readWithAuthRetry(
        () => _firestore
            .collection('shops')
            .doc(shopId)
            .get(const GetOptions(source: Source.server)),
      );
    } else if (role == 'boss') {
      await _readWithAuthRetry(
        () => _firestore
            .collection('shops')
            .limit(1)
            .get(const GetOptions(source: Source.server)),
      );
    }
  }

  Future<T> _readWithAuthRetry<T>(Future<T> Function() read) async {
    const maxAttempts = 6;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await read();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || i == maxAttempts - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * (i + 1)));
      }
    }
    throw StateError('unreachable');
  }

  Future<void> signOut() async {
    // Firestore client cache'ini auth signOut'tan ÖNCE temizle.
    // Aksi halde sonraki login'de Rules `get(/users/{uid})` cache'teki
    // eski kullanıcıyla eşleşmez ve permission-denied'a düşer.
    try {
      await _firestore.terminate();
    } catch (e) {
      debugPrint('Firestore terminate hatası (yutuldu): $e');
    }
    try {
      await _firestore.clearPersistence();
    } catch (e) {
      debugPrint('Firestore clearPersistence hatası (yutuldu): $e');
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
