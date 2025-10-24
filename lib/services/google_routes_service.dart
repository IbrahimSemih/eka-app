import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stop_model.dart';

/// Google Routes API Servisi
///
/// Google'ın Routes API'sini kullanarak gelişmiş rota optimizasyonu sağlar
class GoogleRoutesService {
  static const String _baseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  final String _apiKey;

  GoogleRoutesService({required String apiKey}) : _apiKey = apiKey;

  /// Google Routes API ile rota optimizasyonu yapar
  ///
  /// [stops] - Optimize edilecek durak listesi
  /// [startLatitude] - Başlangıç noktası enlemi
  /// [startLongitude] - Başlangıç noktası boylamı
  /// [vehicleType] - Araç tipi (AUTO, WALKING, BICYCLING, TRANSIT)
  /// [trafficModel] - Trafik modeli (BEST_GUESS, PESSIMISTIC, OPTIMISTIC)
  ///
  /// Returns: Optimize edilmiş durak listesi
  Future<List<StopModel>> optimizeRouteWithGoogle({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String vehicleType = 'AUTO',
    String trafficModel = 'BEST_GUESS',
  }) async {
    if (stops.isEmpty) return stops;

    try {
      // Koordinatları olan durakları filtrele
      final validStops = stops
          .where((stop) => stop.latitude != null && stop.longitude != null)
          .toList();

      if (validStops.isEmpty) {
        print('❌ Koordinatları olan durak bulunamadı');
        return stops;
      }

      // Google Routes API isteği oluştur
      final requestBody = _buildRoutesRequest(
        validStops,
        startLatitude,
        startLongitude,
        vehicleType,
        trafficModel,
      );

      // API isteği gönder
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseOptimizedRoute(data, validStops);
      } else {
        print('❌ Google Routes API hatası: ${response.statusCode}');
        print('Response: ${response.body}');
        return _fallbackOptimization(validStops);
      }
    } catch (e) {
      print('❌ Google Routes API isteği başarısız: $e');
      return _fallbackOptimization(stops);
    }
  }

  /// Google Routes API isteği oluşturur
  Map<String, dynamic> _buildRoutesRequest(
    List<StopModel> stops,
    double startLatitude,
    double startLongitude,
    String vehicleType,
    String trafficModel,
  ) {
    // Başlangıç noktası
    final origin = {
      'location': {
        'latLng': {'latitude': startLatitude, 'longitude': startLongitude},
      },
    };

    // Duraklar (waypoints)
    final waypoints = stops
        .map(
          (stop) => {
            'location': {
              'latLng': {
                'latitude': stop.latitude!,
                'longitude': stop.longitude!,
              },
            },
          },
        )
        .toList();

    // Son durak (destination)
    final destination = waypoints.removeLast();

    return {
      'origin': origin,
      'destination': destination,
      'intermediates': waypoints,
      'travelMode': vehicleType,
      'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
      'trafficModel': trafficModel,
      'computeAlternativeRoutes': false,
      'routeModifiers': {
        'avoidTolls': false,
        'avoidHighways': false,
        'avoidFerries': false,
      },
      'languageCode': 'tr-TR',
      'units': 'METRIC',
    };
  }

  /// Google Routes API yanıtını parse eder
  List<StopModel> _parseOptimizedRoute(
    Map<String, dynamic> data,
    List<StopModel> originalStops,
  ) {
    try {
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        print('❌ Rota bulunamadı');
        return originalStops;
      }

      final route = routes.first;
      final legs = route['legs'] as List<dynamic>?;

      if (legs == null || legs.isEmpty) {
        print('❌ Rota segmentleri bulunamadı');
        return originalStops;
      }

      // Optimize edilmiş sırayı oluştur
      final optimizedStops = <StopModel>[];

      for (int i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final endLocation = leg['endLocation'] as Map<String, dynamic>?;

        if (endLocation != null) {
          final lat = endLocation['latLng']?['latitude'] as double?;
          final lng = endLocation['latLng']?['longitude'] as double?;

          if (lat != null && lng != null) {
            // Bu koordinatlara sahip durakı bul
            final matchingStop = originalStops.firstWhere(
              (stop) =>
                  (stop.latitude! - lat).abs() < 0.0001 &&
                  (stop.longitude! - lng).abs() < 0.0001,
              orElse: () => originalStops[i % originalStops.length],
            );

            // Yeni orderIndex ile kopyala
            optimizedStops.add(matchingStop.copyWith(orderIndex: i));
          }
        }
      }

      print(
        '✅ Google Routes API ile ${optimizedStops.length} durak optimize edildi',
      );
      return optimizedStops;
    } catch (e) {
      print('❌ Rota parse hatası: $e');
      return originalStops;
    }
  }

  /// Fallback optimizasyon (Google API başarısız olursa)
  List<StopModel> _fallbackOptimization(List<StopModel> stops) {
    print(
      '⚠️ Google Routes API kullanılamıyor, basit optimizasyon uygulanıyor',
    );

    // Basit sıralama: koordinatlara göre
    final sortedStops = List<StopModel>.from(stops);
    sortedStops.sort((a, b) {
      if (a.latitude == null || b.latitude == null) return 0;
      return a.latitude!.compareTo(b.latitude!);
    });

    // OrderIndex'leri güncelle
    for (int i = 0; i < sortedStops.length; i++) {
      sortedStops[i] = sortedStops[i].copyWith(orderIndex: i);
    }

    return sortedStops;
  }

  /// Rota mesafesi ve süresini hesaplar
  Future<Map<String, dynamic>?> getRouteInfo({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
  }) async {
    try {
      final requestBody = _buildRoutesRequest(
        stops,
        startLatitude,
        startLongitude,
        'AUTO',
        'BEST_GUESS',
      );

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final distance = route['distanceMeters'] as int? ?? 0;
          final duration = route['duration'] as String? ?? '0s';

          return {
            'distance': distance,
            'duration': duration,
            'distanceKm': (distance / 1000).toStringAsFixed(2),
            'formattedDuration': _formatDuration(duration),
          };
        }
      }
    } catch (e) {
      print('❌ Rota bilgisi alınamadı: $e');
    }

    return null;
  }

  /// Süreyi formatlar
  String _formatDuration(String duration) {
    // ISO 8601 duration formatını parse et
    // Örnek: "PT1H30M" -> "1 saat 30 dakika"
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);

    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      if (hours > 0) {
        return '$hours saat ${minutes > 0 ? '$minutes dakika' : ''}';
      } else if (minutes > 0) {
        return '$minutes dakika';
      } else {
        return '$seconds saniye';
      }
    }

    return duration;
  }
}
