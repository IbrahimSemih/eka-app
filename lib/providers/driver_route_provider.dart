import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../models/stop_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

/// Sürücünün atanmış rotasını getiren provider
final driverRouteStreamProvider = StreamProvider<RouteModel?>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);

  return currentUserAsync.when(
    data: (user) {
      if (user == null || user.role != UserRole.driver) {
        return Stream.value(null);
      }

      // Sürücüye atanmış rotayı bul
      return FirebaseFirestore.instance
          .collection('routes')
          .where('assignedDriverId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return null;
            }

            // İlk atanmış rotayı döndür (genellikle bir sürücüye bir rota atanır)
            return RouteModel.fromFirestore(snapshot.docs.first);
          });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Sürücünün atanmış rotasının duraklarını getiren provider
final driverStopsProvider = Provider<List<StopModel>>((ref) {
  final routeAsync = ref.watch(driverRouteStreamProvider);

  return routeAsync.when(
    data: (route) => route?.stops ?? <StopModel>[],
    loading: () => <StopModel>[],
    error: (_, __) => <StopModel>[],
  );
});

/// Sürücünün atanmış rotasının optimize edilmiş sıralamasını getiren provider
final driverOptimizedStopsProvider = Provider<List<StopModel>>((ref) {
  final stops = ref.watch(driverStopsProvider);

  // Durakları orderIndex'e göre sırala (optimize edilmiş sıralama)
  final sortedStops = List<StopModel>.from(stops);
  sortedStops.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  return sortedStops;
});

/// Sürücünün bugünkü görevlerini getiren provider
final driverTodayTasksProvider = Provider<List<StopModel>>((ref) {
  final stops = ref.watch(driverOptimizedStopsProvider);
  final today = DateTime.now();

  return stops.where((stop) {
    // Bugün oluşturulan veya bugün tamamlanan duraklar
    return stop.createdAt.year == today.year &&
        stop.createdAt.month == today.month &&
        stop.createdAt.day == today.day;
  }).toList();
});

/// Sürücünün bekleyen görevlerini getiren provider
final driverPendingTasksProvider = Provider<List<StopModel>>((ref) {
  final stops = ref.watch(driverOptimizedStopsProvider);

  return stops
      .where(
        (stop) =>
            stop.status == StopStatus.pending ||
            stop.status == StopStatus.assigned,
      )
      .toList();
});

/// Sürücünün tamamlanan görevlerini getiren provider
final driverCompletedTasksProvider = Provider<List<StopModel>>((ref) {
  final stops = ref.watch(driverOptimizedStopsProvider);

  return stops.where((stop) => stop.status == StopStatus.completed).toList();
});

/// Sürücü rota notifier'ı
final driverRouteNotifierProvider =
    NotifierProvider<DriverRouteNotifier, AsyncValue<RouteModel?>>(
      DriverRouteNotifier.new,
    );

class DriverRouteNotifier extends Notifier<AsyncValue<RouteModel?>> {
  @override
  AsyncValue<RouteModel?> build() {
    return const AsyncValue.loading();
  }

  /// Sürücünün rotasını yükle
  Future<void> loadDriverRoute(String driverId) async {
    state = const AsyncValue.loading();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('routes')
          .where('assignedDriverId', isEqualTo: driverId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final route = RouteModel.fromFirestore(snapshot.docs.first);
      state = AsyncValue.data(route);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Durak durumunu güncelle
  Future<void> updateStopStatus(String stopId, StopStatus newStatus) async {
    try {
      final currentRoute = state.value;
      if (currentRoute == null) return;

      final firestore = FirebaseFirestore.instance;
      final routeDoc = await firestore
          .collection('routes')
          .doc(currentRoute.id)
          .get();

      if (!routeDoc.exists) return;

      final routeData = routeDoc.data() as Map<String, dynamic>;
      final stops = routeData['stops'] as List<dynamic>? ?? [];

      // Durağı bul ve güncelle
      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i] as Map<String, dynamic>;
        if (stop['id'] == stopId) {
          stops[i] = {
            ...stop,
            'status': _statusToString(newStatus),
            'updatedAt': Timestamp.now(),
            if (newStatus == StopStatus.completed)
              'completedAt': Timestamp.now(),
          };
          break;
        }
      }

      // Güncellenmiş durakları kaydet
      await firestore.collection('routes').doc(currentRoute.id).update({
        'stops': stops,
        'updatedAt': Timestamp.now(),
      });

      // Yerel state'i güncelle
      await loadDriverRoute(currentRoute.assignedDriverId!);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  String _statusToString(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return 'pending';
      case StopStatus.assigned:
        return 'assigned';
      case StopStatus.inProgress:
        return 'inProgress';
      case StopStatus.completed:
        return 'completed';
      case StopStatus.cancelled:
        return 'cancelled';
    }
  }
}
