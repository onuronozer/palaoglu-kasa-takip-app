import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../models/app_user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

final usersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers();
});

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<AppUser>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map(AppUser.fromDoc).toList();
      users.sort(_sortUsers);
      return users;
    });
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return AppUser.fromDoc(doc);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return AppUser.fromDoc(doc);
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final appName =
        'admin-user-create-${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Kullanıcı oluşturulamadı.');
      }

      await user.updateDisplayName(displayName.trim());
      await _users.doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': role,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await auth.signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateUser(AppUser user) async {
    await _users.doc(user.uid).update(user.toUpdateMap());
  }

  Future<void> setUserActive({
    required AppUser user,
    required bool active,
  }) async {
    await updateUser(user.copyWith(active: active));
  }

  Future<void> setUserRole({
    required AppUser user,
    required String role,
  }) async {
    await updateUser(user.copyWith(role: role));
  }

  int _sortUsers(AppUser a, AppUser b) {
    if (a.active != b.active) {
      return a.active ? -1 : 1;
    }
    if (a.isAdmin != b.isAdmin) {
      return a.isAdmin ? -1 : 1;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}
