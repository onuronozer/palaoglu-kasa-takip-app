import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final firebaseUser = ref.watch(authStateProvider).valueOrNull;
  if (firebaseUser == null) {
    return Stream<AppUser?>.value(null);
  }
  return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.signIn(email: email, password: password);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }
}
