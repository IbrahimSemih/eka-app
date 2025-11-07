import '../config/google_maps_config.dart';
import '../models/stop_model.dart';
import 'google_routes_service.dart';
import 'google_geocoding_service.dart';
import 'google_navigation_service.dart';
import 'google_directions_service.dart';

/// Google Maps Entegrasyon Servisi
///
/// Tüm Google Maps API'lerini tek bir serviste birleştirir
class GoogleMapsIntegrationService {
  late final GoogleRoutesService _routesService;
  late final GoogleGeocodingService _geocodingService;
  late final GoogleNavigationService _navigationService;
  late final GoogleDirectionsService _directionsService;

  GoogleMapsIntegrationService() {
    if (!GoogleMapsConfig.isApiKeyValid) {
      throw Exception(
        'Google Maps API anahtarı geçerli değil. Lütfen config dosyasını güncelleyin.',
      );
    }

    _routesService = GoogleRoutesService(apiKey: GoogleMapsConfig.apiKey);
    _geocodingService = GoogleGeocodingService(apiKey: GoogleMapsConfig.apiKey);
    _navigationService = GoogleNavigationService(
      apiKey: GoogleMapsConfig.apiKey,
    );
    _directionsService = GoogleDirectionsService(
      apiKey: GoogleMapsConfig.apiKey,
    );
  }

  /// Gelişmiş rota optimizasyonu
  Future<List<StopModel>> optimizeRoute({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String vehicleType = 'AUTO',
    String trafficModel = 'BEST_GUESS',
  }) async {
    print('🗺️ Google Routes API ile rota optimizasyonu başlatılıyor...');

    try {
      final optimizedStops = await _routesService.optimizeRouteWithGoogle(
        stops: stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        vehicleType: vehicleType,
        trafficModel: trafficModel,
      );

      print('✅ Rota optimizasyonu tamamlandı: ${optimizedStops.length} durak');
      return optimizedStops;
    } catch (e) {
      print('❌ Rota optimizasyonu başarısız: $e');
      return stops; // Orijinal sırayı koru
    }
  }

  /// Gelişmiş adres çözümleme
  Future<({double latitude, double longitude})?> resolveAddress(
    String address,
  ) async {
    print('🔍 Google Geocoding API ile adres çözümleme...');

    try {
      final coordinates = await _geocodingService.addressToCoordinates(address);
      if (coordinates != null) {
        print(
          '✅ Adres çözümlendi: ${coordinates.latitude}, ${coordinates.longitude}',
        );
      } else {
        print('❌ Adres çözümlenemedi');
      }
      return coordinates;
    } catch (e) {
      print('❌ Adres çözümleme hatası: $e');
      return null;
    }
  }

  /// Koordinatları adrese dönüştürme
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    print('📍 Google Reverse Geocoding ile koordinat çözümleme...');

    try {
      final address = await _geocodingService.coordinatesToAddress(
        latitude,
        longitude,
      );
      if (address != null) {
        print('✅ Koordinat çözümlendi: $address');
      } else {
        print('❌ Koordinat çözümlenemedi');
      }
      return address;
    } catch (e) {
      print('❌ Koordinat çözümleme hatası: $e');
      return null;
    }
  }

  /// Adres arama
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    print('🔍 Google Address Search ile arama...');

    try {
      final results = await _geocodingService.searchAddresses(query);
      print('✅ ${results.length} adres bulundu');
      return results;
    } catch (e) {
      print('❌ Adres arama hatası: $e');
      return [];
    }
  }

  /// Gerçek zamanlı navigasyon
  Future<Map<String, dynamic>?> getNavigationInfo({
    required List<StopModel> stops,
    required double currentLatitude,
    required double currentLongitude,
    required int nextStopIndex,
  }) async {
    print('🧭 Google Navigation API ile navigasyon bilgisi alınıyor...');

    try {
      final navInfo = await _navigationService.getNavigationInfo(
        stops: stops,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        nextStopIndex: nextStopIndex,
      );

      if (navInfo != null) {
        print('✅ Navigasyon bilgisi alındı');
      } else {
        print('❌ Navigasyon bilgisi alınamadı');
      }
      return navInfo;
    } catch (e) {
      print('❌ Navigasyon hatası: $e');
      return null;
    }
  }

  /// ETA hesaplama
  Future<DateTime?> calculateETA({
    required List<StopModel> stops,
    required double currentLatitude,
    required double currentLongitude,
    required int nextStopIndex,
  }) async {
    print('⏰ ETA hesaplanıyor...');

    try {
      final eta = await _navigationService.calculateETA(
        stops: stops,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        nextStopIndex: nextStopIndex,
      );

      if (eta != null) {
        print('✅ ETA hesaplandı: $eta');
      } else {
        print('❌ ETA hesaplanamadı');
      }
      return eta;
    } catch (e) {
      print('❌ ETA hesaplama hatası: $e');
      return null;
    }
  }

  /// Trafik verileri
  Future<Map<String, dynamic>?> getTrafficData({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
  }) async {
    print('🚦 Google Traffic API ile trafik verisi alınıyor...');

    try {
      final trafficData = await _navigationService.getTrafficData(
        stops: stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
      );

      if (trafficData != null) {
        print('✅ Trafik verisi alındı');
      } else {
        print('❌ Trafik verisi alınamadı');
      }
      return trafficData;
    } catch (e) {
      print('❌ Trafik verisi hatası: $e');
      return null;
    }
  }

  /// Rota bilgileri
  Future<Map<String, dynamic>?> getRouteInfo({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
  }) async {
    print('📊 Google Routes API ile rota bilgisi alınıyor...');

    try {
      final routeInfo = await _routesService.getRouteInfo(
        stops: stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
      );

      if (routeInfo != null) {
        print('✅ Rota bilgisi alındı');
      } else {
        print('❌ Rota bilgisi alınamadı');
      }
      return routeInfo;
    } catch (e) {
      print('❌ Rota bilgisi hatası: $e');
      return null;
    }
  }

  /// Tüm durakların koordinatlarını güncelle
  Future<List<StopModel>> updateAllStopCoordinates(
    List<StopModel> stops,
  ) async {
    print('🔄 Tüm durakların koordinatları güncelleniyor...');

    final updatedStops = <StopModel>[];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];

      // Koordinatı olmayan durakları güncelle
      if (stop.latitude == null || stop.longitude == null) {
        print(
          '📍 Durak ${i + 1}/${stops.length} güncelleniyor: ${stop.customerName}',
        );

        final coordinates = await resolveAddress(stop.address);
        if (coordinates != null) {
          updatedStops.add(
            stop.copyWith(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            ),
          );
          print(
            '✅ Koordinat güncellendi: ${coordinates.latitude}, ${coordinates.longitude}',
          );
        } else {
          updatedStops.add(stop);
          print('❌ Koordinat güncellenemedi');
        }
      } else {
        updatedStops.add(stop);
        print('✅ Koordinat zaten mevcut: ${stop.latitude}, ${stop.longitude}');
      }

      // API rate limiting için kısa bekleme
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('✅ Tüm duraklar güncellendi: ${updatedStops.length} durak');
    return updatedStops;
  }

  /// Waypointler arasında polyline oluşturur
  Future<Map<String, dynamic>?> getPolylineRoute({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String travelMode = 'driving',
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    print('🗺️ Google Directions API ile polyline oluşturuluyor...');

    try {
      final routeData = await _directionsService.getPolylineRoute(
        stops: stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        travelMode: travelMode,
        avoidHighways: avoidHighways,
        avoidTolls: avoidTolls,
      );

      if (routeData != null) {
        print(
          '✅ Polyline oluşturuldu: ${routeData['polylinePoints']?.length ?? 0} nokta',
        );
        print('📏 Toplam mesafe: ${routeData['totalDistanceKm']} km');
        print('⏱️ Toplam süre: ${routeData['formattedDuration']}');
      } else {
        print('❌ Polyline oluşturulamadı');
      }

      return routeData;
    } catch (e) {
      print('❌ Polyline oluşturma hatası: $e');
      return null;
    }
  }

  /// İki nokta arasında basit polyline oluşturur
  Future<Map<String, dynamic>?> getSimplePolyline({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String travelMode = 'driving',
  }) async {
    print('🗺️ İki nokta arası polyline oluşturuluyor...');

    try {
      final routeData = await _directionsService.getSimplePolyline(
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: endLatitude,
        endLongitude: endLongitude,
        travelMode: travelMode,
      );

      if (routeData != null) {
        print('✅ Basit polyline oluşturuldu');
      } else {
        print('❌ Basit polyline oluşturulamadı');
      }

      return routeData;
    } catch (e) {
      print('❌ Basit polyline oluşturma hatası: $e');
      return null;
    }
  }

  /// Alternatif rotaları getirir
  Future<List<Map<String, dynamic>>> getAlternativeRoutes({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String travelMode = 'driving',
    int maxAlternatives = 3,
  }) async {
    print('🗺️ Alternatif rotalar alınıyor...');

    try {
      final alternativeRoutes = await _directionsService.getAlternativeRoutes(
        stops: stops,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        travelMode: travelMode,
        maxAlternatives: maxAlternatives,
      );

      print('✅ ${alternativeRoutes.length} alternatif rota bulundu');
      return alternativeRoutes;
    } catch (e) {
      print('❌ Alternatif rotalar alınamadı: $e');
      return [];
    }
  }
}
