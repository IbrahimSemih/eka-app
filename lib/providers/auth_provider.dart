import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// AuthService provider'ı
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Mevcut Firebase User stream provider'ı
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Mevcut kullanıcı verisi provider'ı (UserModel)
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);

  return authService.authStateChanges.asyncMap((user) async {
    if (user == null) {
      return null;
    }
    return await authService.getUserData(user.uid);
  });
});

// Mevcut kullanıcının UID'si
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.uid;
});
