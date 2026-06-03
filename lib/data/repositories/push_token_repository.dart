import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository(FirebaseFirestore.instance);
});

class PushTokenRepository {
  PushTokenRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('fcm_tokens');

  Future<void> saveToken({
    required AppUser user,
    required String token,
  }) async {
    final platform = defaultTargetPlatform.name;
    await _tokens.doc(Uri.encodeComponent(token)).set({
      'token': token,
      'uid': user.uid,
      'displayName': user.displayName,
      'platform': platform,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeToken(String token) async {
    await _tokens.doc(Uri.encodeComponent(token)).delete();
  }
}
