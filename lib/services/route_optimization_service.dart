import '../models/stop_model.dart';
import 'geocoding_service.dart';

/// Rota Optimizasyonu Servisi
///
/// En Yakın Komşu (Nearest Neighbor) algoritması kullanarak
/// durakların optimal sırasını belirler
class RouteOptimizationService {
  static final RouteOptimizationService _instance =
      RouteOptimizationService._internal();
  factory RouteOptimizationService() => _instance;
  RouteOptimizationService._internal();

  final GeocodingService _geocodingService = GeocodingService();

  /// Durakları optimize eder ve yeni sıralarını belirler
  ///
  /// [stops] - Optimize edilecek durak listesi
  /// [startLatitude] - Başlangıç noktası enlemi (opsiyonel)
  /// [startLongitude] - Başlangıç noktası boylamı (opsiyonel)
  ///
  /// Returns: Optimize edilmiş durak listesi
  Future<List<StopModel>> optimizeRoute(
    List<StopModel> stops, {
    double? startLatitude,
    double? startLongitude,
  }) async {
    if (stops.isEmpty) return stops;

    // 1. Koordinatları olmayan duraklar için geocoding yap
    List<StopModel> stopsWithCoordinates = await _ensureCoordinates(stops);

    // 2. Koordinatları olmayan durakları filtrele
    List<StopModel> validStops = stopsWithCoordinates
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    if (validStops.isEmpty) {
      print('Hiçbir durak için koordinat bulunamadı');
      return stops; // Orijinal sırayı koru
    }

    // 3. Başlangıç noktasını belirle
    double startLat = startLatitude ?? 0.0;
    double startLon = startLongitude ?? 0.0;

    if (startLatitude == null || startLongitude == null) {
      // Başlangıç noktası belirtilmemişse, ilk durağı başlangıç olarak kullan
      startLat = validStops.first.latitude!;
      startLon = validStops.first.longitude!;
    }

    // 4. En Yakın Komşu algoritmasını uygula
    List<StopModel> optimizedStops = _nearestNeighborAlgorithm(
      validStops,
      startLat,
      startLon,
    );

    // 5. Yeni orderIndex değerlerini ata
    for (int i = 0; i < optimizedStops.length; i++) {
      optimizedStops[i] = optimizedStops[i].copyWith(orderIndex: i);
    }

    // 6. Koordinatları olmayan durakları sona ekle
    List<StopModel> stopsWithoutCoordinates = stopsWithCoordinates
        .where((stop) => stop.latitude == null || stop.longitude == null)
        .toList();

    for (int i = 0; i < stopsWithoutCoordinates.length; i++) {
      stopsWithoutCoordinates[i] = stopsWithoutCoordinates[i].copyWith(
        orderIndex: optimizedStops.length + i,
      );
    }

    // 7. Son listeyi oluştur
    List<StopModel> finalStops = [
      ...optimizedStops,
      ...stopsWithoutCoordinates,
    ];

    print('Rota optimizasyonu tamamlandı: ${finalStops.length} durak');
    return finalStops;
  }

  /// En Yakın Komşu algoritması
  ///
  /// [stops] - Durak listesi
  /// [startLat] - Başlangıç enlemi
  /// [startLon] - Başlangıç boylamı
  ///
  /// Returns: Optimize edilmiş durak listesi
  List<StopModel> _nearestNeighborAlgorithm(
    List<StopModel> stops,
    double startLat,
    double startLon,
  ) {
    if (stops.isEmpty) return stops;

    List<StopModel> result = [];
    List<StopModel> remaining = List.from(stops);

    double currentLat = startLat;
    double currentLon = startLon;

    while (remaining.isNotEmpty) {
      // En yakın durağı bul
      int nearestIndex = 0;
      double nearestDistance = double.infinity;

      for (int i = 0; i < remaining.length; i++) {
        double distance = _geocodingService.calculateDistance(
          currentLat,
          currentLon,
          remaining[i].latitude!,
          remaining[i].longitude!,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }

      // En yakın durağı sonuca ekle
      StopModel nearestStop = remaining.removeAt(nearestIndex);
      result.add(nearestStop);

      // Mevcut konumu güncelle
      currentLat = nearestStop.latitude!;
      currentLon = nearestStop.longitude!;
    }

    return result;
  }

  /// Durakların koordinatlarını sağlar
  ///
  /// [stops] - Durak listesi
  ///
  /// Returns: Koordinatları olan durak listesi
  Future<List<StopModel>> _ensureCoordinates(List<StopModel> stops) async {
    List<StopModel> updatedStops = [];

    for (StopModel stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        // Koordinat zaten var
        updatedStops.add(stop);
      } else {
        // Koordinat yok, geocoding yap
        final coordinates = await _geocodingService.addressToCoordinates(
          stop.address,
        );

        if (coordinates != null) {
          updatedStops.add(
            stop.copyWith(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            ),
          );
        } else {
          // Geocoding başarısız, koordinatsız bırak
          updatedStops.add(stop);
        }
      }
    }

    return updatedStops;
  }

  /// Rota toplam mesafesini hesaplar
  ///
  /// [stops] - Durak listesi
  /// [startLat] - Başlangıç enlemi (opsiyonel)
  /// [startLon] - Başlangıç boylamı (opsiyonel)
  ///
  /// Returns: Toplam mesafe (km)
  double calculateTotalDistance(
    List<StopModel> stops, {
    double? startLat,
    double? startLon,
  }) {
    if (stops.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double currentLat = startLat ?? stops.first.latitude ?? 0.0;
    double currentLon = startLon ?? stops.first.longitude ?? 0.0;

    for (StopModel stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        double distance = _geocodingService.calculateDistance(
          currentLat,
          currentLon,
          stop.latitude!,
          stop.longitude!,
        );
        totalDistance += distance;

        currentLat = stop.latitude!;
        currentLon = stop.longitude!;
      }
    }

    return totalDistance;
  }

  /// Rota optimizasyon istatistiklerini hesaplar
  ///
  /// [originalStops] - Orijinal durak listesi
  /// [optimizedStops] - Optimize edilmiş durak listesi
  ///
  /// Returns: Optimizasyon istatistikleri
  Map<String, dynamic> calculateOptimizationStats(
    List<StopModel> originalStops,
    List<StopModel> optimizedStops,
  ) {
    double originalDistance = calculateTotalDistance(originalStops);
    double optimizedDistance = calculateTotalDistance(optimizedStops);

    double savings = originalDistance - optimizedDistance;
    double savingsPercentage = originalDistance > 0
        ? (savings / originalDistance) * 100
        : 0.0;

    return {
      'originalDistance': originalDistance,
      'optimizedDistance': optimizedDistance,
      'savings': savings,
      'savingsPercentage': savingsPercentage,
      'totalStops': optimizedStops.length,
      'stopsWithCoordinates': optimizedStops
          .where((s) => s.latitude != null && s.longitude != null)
          .length,
    };
  }

  /// Durakları sıraya göre sıralar
  ///
  /// [stops] - Sıralanacak durak listesi
  ///
  /// Returns: Sıralanmış durak listesi
  List<StopModel> sortStopsByOrder(List<StopModel> stops) {
    List<StopModel> sortedStops = List.from(stops);
    sortedStops.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sortedStops;
  }

  /// Durak sırasını manuel olarak günceller
  ///
  /// [stops] - Durak listesi
  /// [fromIndex] - Taşınacak durağın mevcut indeksi
  /// [toIndex] - Hedef indeks
  ///
  /// Returns: Güncellenmiş durak listesi
  List<StopModel> reorderStop(
    List<StopModel> stops,
    int fromIndex,
    int toIndex,
  ) {
    if (fromIndex < 0 ||
        fromIndex >= stops.length ||
        toIndex < 0 ||
        toIndex >= stops.length) {
      return stops;
    }

    List<StopModel> updatedStops = List.from(stops);
    StopModel movedStop = updatedStops.removeAt(fromIndex);
    updatedStops.insert(toIndex, movedStop);

    // Tüm orderIndex değerlerini güncelle
    for (int i = 0; i < updatedStops.length; i++) {
      updatedStops[i] = updatedStops[i].copyWith(orderIndex: i);
    }

    return updatedStops;
  }
}
