import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Sürücü listesi provider'ı
final driversStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'driver')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      });
});

/// Sürücü listesi notifier'ı
final driversNotifierProvider =
    NotifierProvider<DriversNotifier, AsyncValue<List<UserModel>>>(
      DriversNotifier.new,
    );

class DriversNotifier extends Notifier<AsyncValue<List<UserModel>>> {
  @override
  AsyncValue<List<UserModel>> build() {
    return const AsyncValue.loading();
  }

  /// Tüm sürücüleri yükle
  Future<void> loadDrivers() async {
    state = const AsyncValue.loading();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();

      final drivers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      state = AsyncValue.data(drivers);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sürücü ekle
  Future<void> addDriver({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      // Bu işlem auth_service'te yapılacak
      // Şimdilik sadece placeholder
      await loadDrivers(); // Listeyi yenile
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sürücü güncelle
  Future<void> updateDriver(UserModel driver) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(driver.uid)
          .update(driver.toFirestore());

      await loadDrivers(); // Listeyi yenile
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sürücü sil
  Future<void> deleteDriver(String driverId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .delete();

      await loadDrivers(); // Listeyi yenile
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
