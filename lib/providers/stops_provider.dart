import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/stop_model.dart';
import '../models/route_model.dart';
import '../services/route_optimization_service.dart';
import '../services/geocoding_service.dart';

// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// UUID generator provider
final uuidProvider = Provider<Uuid>((ref) {
  return const Uuid();
});

// Geocoding service provider
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

// Route optimization service provider
final routeOptimizationServiceProvider = Provider<RouteOptimizationService>((
  ref,
) {
  return RouteOptimizationService();
});

// Ana rota ID'si - MVP için sabit
const String mainRouteId = 'main_route';

// Ana rotayı dinleyen stream provider
final mainRouteStreamProvider = StreamProvider<RouteModel?>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('routes').doc(mainRouteId).snapshots().map((
    snapshot,
  ) {
    if (!snapshot.exists) {
      return null;
    }
    return RouteModel.fromFirestore(snapshot);
  });
});

// Ana rotadaki durakları getiren provider
final routeStopsProvider = Provider<List<StopModel>>((ref) {
  final routeAsync = ref.watch(mainRouteStreamProvider);

  return routeAsync.when(
    data: (route) => route?.stops ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

// Tüm durakları dinleyen stream provider (eski sistem - geriye dönük uyumluluk için)
final stopsStreamProvider = StreamProvider<List<StopModel>>((ref) {
  // Önce route'dan duraklarını almaya çalış
  final route = ref.watch(mainRouteStreamProvider).value;

  if (route != null && route.stops.isNotEmpty) {
    // Route varsa onun durakları ile bir stream oluştur
    return Stream.value(route.stops);
  }

  // Yoksa eski stops koleksiyonundan al
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('stops')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => StopModel.fromFirestore(doc))
            .toList();
      });
});

// Bekleyen durakları getiren provider
final pendingStopsProvider = Provider<List<StopModel>>((ref) {
  final stopsAsync = ref.watch(stopsStreamProvider);

  return stopsAsync.when(
    data: (stops) =>
        stops.where((stop) => stop.status == StopStatus.pending).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Tamamlanan durakları getiren provider
final completedStopsProvider = Provider<List<StopModel>>((ref) {
  final stopsAsync = ref.watch(stopsStreamProvider);

  return stopsAsync.when(
    data: (stops) =>
        stops.where((stop) => stop.status == StopStatus.completed).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// İstatistikler provider'ı
final stopsStatisticsProvider = Provider<StopsStatistics>((ref) {
  final stopsAsync = ref.watch(stopsStreamProvider);

  return stopsAsync.when(
    data: (stops) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todayStops = stops.where((stop) {
        return stop.createdAt.isAfter(startOfDay);
      }).toList();

      return StopsStatistics(
        totalStops: stops.length,
        pendingStops: stops.where((s) => s.status == StopStatus.pending).length,
        assignedStops: stops
            .where((s) => s.status == StopStatus.assigned)
            .length,
        inProgressStops: stops
            .where((s) => s.status == StopStatus.inProgress)
            .length,
        completedStops: stops
            .where((s) => s.status == StopStatus.completed)
            .length,
        todayStops: todayStops.length,
        todayCompletedStops: todayStops
            .where((s) => s.status == StopStatus.completed)
            .length,
      );
    },
    loading: () => StopsStatistics.empty(),
    error: (_, __) => StopsStatistics.empty(),
  );
});

// Durak yönetimi için Notifier
class StopsNotifier extends Notifier<void> {
  @override
  void build() {}

  // Ana rotaya yeni durak ekle
  Future<void> addStop({
    required String customerName,
    required String address,
    required String createdBy,
    String? notes,
  }) async {
    try {
      print('🔄 Durak ekleme başladı...');
      print('📝 Müşteri: $customerName');
      print('📍 Adres: $address');
      print('👤 Oluşturan: $createdBy');

      final firestore = ref.read(firestoreProvider);
      final uuid = ref.read(uuidProvider);

      // Mevcut rotayı al
      print('📥 Rota verisi alınıyor: $mainRouteId');
      final routeDoc = await firestore
          .collection('routes')
          .doc(mainRouteId)
          .get();

      final newStop = StopModel(
        id: uuid.v4(),
        customerName: customerName,
        address: address,
        status: StopStatus.pending,
        orderIndex: 0,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        notes: notes,
      );

      if (routeDoc.exists) {
        // Rota varsa, mevcut durakları al ve yeni durağı ekle
        print('✅ Mevcut rota bulundu, güncelleniyor...');
        final currentRoute = RouteModel.fromFirestore(routeDoc);
        final updatedStops = [...currentRoute.stops, newStop];

        // Durakların order index'lerini güncelle
        for (int i = 0; i < updatedStops.length; i++) {
          updatedStops[i] = updatedStops[i].copyWith(orderIndex: i);
        }

        final updatedRoute = currentRoute.copyWith(
          stops: updatedStops,
          updatedAt: DateTime.now(),
        );

        print('💾 Firestore güncelleniyor...');
        await firestore
            .collection('routes')
            .doc(mainRouteId)
            .update(updatedRoute.toFirestore());
        print('✅ Durak başarıyla eklendi!');
      } else {
        // Rota yoksa, yeni rota oluştur
        print('🆕 Yeni rota oluşturuluyor...');
        final newRoute = RouteModel(
          id: mainRouteId,
          name: 'Ana Rota',
          stops: [newStop],
          createdAt: DateTime.now(),
          createdBy: createdBy,
        );

        print('💾 Firestore\'a yazılıyor...');
        await firestore
            .collection('routes')
            .doc(mainRouteId)
            .set(newRoute.toFirestore());
        print('✅ Yeni rota ve durak başarıyla oluşturuldu!');
      }
    } catch (e, stackTrace) {
      print('❌ Durak ekleme hatası: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow; // Hatayı üst katmana ilet
    }
  }

  // Rotadaki bir durağı güncelle
  Future<void> updateStop(String stopId, Map<String, dynamic> updates) async {
    final firestore = ref.read(firestoreProvider);
    final routeDoc = await firestore
        .collection('routes')
        .doc(mainRouteId)
        .get();

    if (routeDoc.exists) {
      // Rota sisteminde güncelle
      final currentRoute = RouteModel.fromFirestore(routeDoc);
      final updatedStops = currentRoute.stops.map((stop) {
        if (stop.id == stopId) {
          // Güncellemeleri uygula
          return stop.copyWith(
            status: updates['status'] != null
                ? _statusFromString(updates['status'])
                : stop.status,
            driverId: updates['driverId'] ?? stop.driverId,
            driverName: updates['driverName'] ?? stop.driverName,
            updatedAt: DateTime.now(),
            completedAt: updates['completedAt'] != null
                ? (updates['completedAt'] as Timestamp).toDate()
                : stop.completedAt,
          );
        }
        return stop;
      }).toList();

      final updatedRoute = currentRoute.copyWith(
        stops: updatedStops,
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('routes')
          .doc(mainRouteId)
          .update(updatedRoute.toFirestore());
    } else {
      // Eski sistem (geriye dönük uyumluluk)
      updates['updatedAt'] = Timestamp.now();
      await firestore.collection('stops').doc(stopId).update(updates);
    }
  }

  // Rotadan durak sil
  Future<void> deleteStop(String stopId) async {
    try {
      print('🗑️ Durak silme işlemi başladı: $stopId');

      final firestore = ref.read(firestoreProvider);
      final routeDoc = await firestore
          .collection('routes')
          .doc(mainRouteId)
          .get();

      if (routeDoc.exists) {
        print('✅ Rota dokümanı bulundu, güncelleniyor...');

        // Rota sisteminden sil
        final currentRoute = RouteModel.fromFirestore(routeDoc);
        print('📊 Mevcut durak sayısı: ${currentRoute.stops.length}');

        final updatedStops = currentRoute.stops
            .where((stop) => stop.id != stopId)
            .toList();

        print('📊 Silme sonrası durak sayısı: ${updatedStops.length}');

        // Order index'leri yeniden düzenle
        for (int i = 0; i < updatedStops.length; i++) {
          updatedStops[i] = updatedStops[i].copyWith(orderIndex: i);
        }

        final updatedRoute = currentRoute.copyWith(
          stops: updatedStops,
          updatedAt: DateTime.now(),
        );

        print('💾 Firestore güncelleniyor...');
        await firestore
            .collection('routes')
            .doc(mainRouteId)
            .update(updatedRoute.toFirestore());

        print('✅ Durak başarıyla silindi!');
      } else {
        print('⚠️ Rota dokümanı bulunamadı, eski sistem kullanılıyor...');
        // Eski sistem (geriye dönük uyumluluk)
        await firestore.collection('stops').doc(stopId).delete();
        print('✅ Durak eski sistemden silindi!');
      }
    } catch (e, stackTrace) {
      print('❌ Durak silme hatası: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Durak durumunu güncelle
  Future<void> updateStopStatus(String stopId, StopStatus newStatus) async {
    final updates = <String, dynamic>{'status': _statusToString(newStatus)};

    if (newStatus == StopStatus.completed) {
      updates['completedAt'] = Timestamp.now();
    }

    await updateStop(stopId, updates);
  }

  // Sürücüye durak ata
  Future<void> assignStopToDriver({
    required String stopId,
    required String driverId,
    required String driverName,
  }) async {
    await updateStop(stopId, {
      'driverId': driverId,
      'driverName': driverName,
      'status': 'assigned',
    });
  }

  // Rotayı sürücüye ata
  Future<void> assignRouteToDriver({
    required String routeId,
    required String driverId,
    required String driverName,
  }) async {
    try {
      print('🔄 Rota atama başladı...');
      print('📝 Rota ID: $routeId');
      print('👤 Sürücü: $driverName ($driverId)');

      final firestore = ref.read(firestoreProvider);

      // Rota güncelleme verilerini hazırla
      final routeUpdates = {
        'assignedDriverId': driverId,
        'assignedDriverName': driverName,
        'assignedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      // Rotayı güncelle
      await firestore.collection('routes').doc(routeId).update(routeUpdates);

      // Rotadaki tüm durakları da sürücüye ata
      final routeDoc = await firestore.collection('routes').doc(routeId).get();
      if (routeDoc.exists) {
        final routeData = routeDoc.data() as Map<String, dynamic>;
        final stops = routeData['stops'] as List<dynamic>? ?? [];

        // Her durağı güncelle
        for (int i = 0; i < stops.length; i++) {
          final stop = stops[i] as Map<String, dynamic>;
          if (stop['status'] == 'pending') {
            stops[i] = {
              ...stop,
              'driverId': driverId,
              'driverName': driverName,
              'status': 'assigned',
              'updatedAt': Timestamp.now(),
            };
          }
        }

        // Güncellenmiş durakları kaydet
        await firestore.collection('routes').doc(routeId).update({
          'stops': stops,
          'updatedAt': Timestamp.now(),
        });
      }

      print('✅ Rota başarıyla atandı!');
    } catch (e) {
      print('❌ Rota atama hatası: $e');
      rethrow;
    }
  }

  // Rotayı optimize et
  Future<void> optimizeRoute({
    double? startLatitude,
    double? startLongitude,
  }) async {
    try {
      print('🔄 Rota optimizasyonu başladı...');

      final firestore = ref.read(firestoreProvider);
      final optimizationService = ref.read(routeOptimizationServiceProvider);

      // Mevcut rotayı al
      final routeDoc = await firestore
          .collection('routes')
          .doc(mainRouteId)
          .get();

      if (!routeDoc.exists) {
        print('❌ Rota bulunamadı');
        return;
      }

      final currentRoute = RouteModel.fromFirestore(routeDoc);
      print('📊 Mevcut durak sayısı: ${currentRoute.stops.length}');

      // Optimizasyonu uygula
      final optimizedStops = await optimizationService.optimizeRoute(
        currentRoute.stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
      );

      // Optimizasyon istatistiklerini hesapla
      final stats = optimizationService.calculateOptimizationStats(
        currentRoute.stops,
        optimizedStops,
      );

      print('📈 Optimizasyon sonuçları:');
      print(
        '   Orijinal mesafe: ${stats['originalDistance']?.toStringAsFixed(2)} km',
      );
      print(
        '   Optimize mesafe: ${stats['optimizedDistance']?.toStringAsFixed(2)} km',
      );
      print(
        '   Tasarruf: ${stats['savings']?.toStringAsFixed(2)} km (${stats['savingsPercentage']?.toStringAsFixed(1)}%)',
      );

      // Güncellenmiş rotayı kaydet
      final updatedRoute = currentRoute.copyWith(
        stops: optimizedStops,
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('routes')
          .doc(mainRouteId)
          .update(updatedRoute.toFirestore());

      print('✅ Rota optimizasyonu tamamlandı!');
    } catch (e, stackTrace) {
      print('❌ Rota optimizasyonu hatası: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Durak koordinatlarını güncelle
  Future<void> updateStopCoordinates(String stopId) async {
    try {
      print('🔄 Durak koordinatları güncelleniyor: $stopId');

      final firestore = ref.read(firestoreProvider);
      final geocodingService = ref.read(geocodingServiceProvider);

      // Mevcut rotayı al
      final routeDoc = await firestore
          .collection('routes')
          .doc(mainRouteId)
          .get();

      if (!routeDoc.exists) {
        print('❌ Rota bulunamadı');
        return;
      }

      final currentRoute = RouteModel.fromFirestore(routeDoc);
      final stop = currentRoute.stops.firstWhere((s) => s.id == stopId);

      // Koordinatları al
      final coordinates = await geocodingService.addressToCoordinates(
        stop.address,
      );

      if (coordinates != null) {
        // Durağı güncelle
        final updatedStops = currentRoute.stops.map((s) {
          if (s.id == stopId) {
            return s.copyWith(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
              updatedAt: DateTime.now(),
            );
          }
          return s;
        }).toList();

        final updatedRoute = currentRoute.copyWith(
          stops: updatedStops,
          updatedAt: DateTime.now(),
        );

        await firestore
            .collection('routes')
            .doc(mainRouteId)
            .update(updatedRoute.toFirestore());

        print(
          '✅ Koordinatlar güncellendi: ${coordinates.latitude}, ${coordinates.longitude}',
        );
      } else {
        print('❌ Koordinatlar alınamadı');
      }
    } catch (e, stackTrace) {
      print('❌ Koordinat güncelleme hatası: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Tüm durakların koordinatlarını güncelle
  Future<void> updateAllStopCoordinates() async {
    try {
      print('🔄 Tüm durak koordinatları güncelleniyor...');

      final firestore = ref.read(firestoreProvider);
      final geocodingService = ref.read(geocodingServiceProvider);

      // Mevcut rotayı al
      final routeDoc = await firestore
          .collection('routes')
          .doc(mainRouteId)
          .get();

      if (!routeDoc.exists) {
        print('❌ Rota bulunamadı');
        return;
      }

      final currentRoute = RouteModel.fromFirestore(routeDoc);
      final stopsWithoutCoordinates = currentRoute.stops
          .where((s) => s.latitude == null || s.longitude == null)
          .toList();

      print(
        '📍 Koordinatı olmayan durak sayısı: ${stopsWithoutCoordinates.length}',
      );

      // Toplu geocoding
      final coordinatesMap = await geocodingService.batchAddressToCoordinates(
        stopsWithoutCoordinates.map((s) => s.address).toList(),
      );

      // Durakları güncelle
      final updatedStops = currentRoute.stops.map((stop) {
        final coordinates = coordinatesMap[stop.address];
        if (coordinates != null) {
          return stop.copyWith(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            updatedAt: DateTime.now(),
          );
        }
        return stop;
      }).toList();

      final updatedRoute = currentRoute.copyWith(
        stops: updatedStops,
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('routes')
          .doc(mainRouteId)
          .update(updatedRoute.toFirestore());

      final updatedCount = coordinatesMap.values.where((c) => c != null).length;
      print('✅ $updatedCount durak koordinatı güncellendi!');
    } catch (e, stackTrace) {
      print('❌ Toplu koordinat güncelleme hatası: $e');
      print('📍 Stack trace: $stackTrace');
      rethrow;
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

  StopStatus _statusFromString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pending':
        return StopStatus.pending;
      case 'assigned':
        return StopStatus.assigned;
      case 'inprogress':
      case 'in_progress':
        return StopStatus.inProgress;
      case 'completed':
        return StopStatus.completed;
      case 'cancelled':
        return StopStatus.cancelled;
      default:
        return StopStatus.pending;
    }
  }
}

// StopsNotifier provider'ı
final stopsNotifierProvider = NotifierProvider<StopsNotifier, void>(() {
  return StopsNotifier();
});

// İstatistikler modeli
class StopsStatistics {
  final int totalStops;
  final int pendingStops;
  final int assignedStops;
  final int inProgressStops;
  final int completedStops;
  final int todayStops;
  final int todayCompletedStops;

  StopsStatistics({
    required this.totalStops,
    required this.pendingStops,
    required this.assignedStops,
    required this.inProgressStops,
    required this.completedStops,
    required this.todayStops,
    required this.todayCompletedStops,
  });

  factory StopsStatistics.empty() {
    return StopsStatistics(
      totalStops: 0,
      pendingStops: 0,
      assignedStops: 0,
      inProgressStops: 0,
      completedStops: 0,
      todayStops: 0,
      todayCompletedStops: 0,
    );
  }
}
