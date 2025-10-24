import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stop_model.dart';

/// Google Navigation SDK Servisi
///
/// Google'ın Navigation SDK'sini kullanarak gelişmiş navigasyon özellikleri sağlar
class GoogleNavigationService {
  static const String _baseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  final String _apiKey;

  GoogleNavigationService({required String apiKey}) : _apiKey = apiKey;

  /// Gerçek zamanlı navigasyon bilgileri alır
  ///
  /// [stops] - Rota durakları
  /// [currentLatitude] - Mevcut konum enlemi
  /// [currentLongitude] - Mevcut konum boylamı
  /// [nextStopIndex] - Bir sonraki durak indeksi
  ///
  /// Returns: Navigasyon bilgileri
  Future<Map<String, dynamic>?> getNavigationInfo({
    required List<StopModel> stops,
    required double currentLatitude,
    required double currentLongitude,
    required int nextStopIndex,
  }) async {
    try {
      if (nextStopIndex >= stops.length) {
        print('❌ Geçersiz durak indeksi');
        return null;
      }

      final nextStop = stops[nextStopIndex];
      if (nextStop.latitude == null || nextStop.longitude == null) {
        print('❌ Sonraki durağın koordinatları bulunamadı');
        return null;
      }

      final requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': currentLatitude,
              'longitude': currentLongitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': nextStop.latitude!,
              'longitude': nextStop.longitude!,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
        'trafficModel': 'BEST_GUESS',
        'languageCode': 'tr-TR',
        'units': 'METRIC',
        'computeAlternativeRoutes': false,
        'routeModifiers': {
          'avoidTolls': false,
          'avoidHighways': false,
          'avoidFerries': false,
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseNavigationResponse(data, nextStop);
      } else {
        print('❌ Google Navigation API hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Google Navigation isteği başarısız: $e');
      return null;
    }
  }

  /// Navigasyon yanıtını parse eder
  Map<String, dynamic>? _parseNavigationResponse(
    Map<String, dynamic> data,
    StopModel nextStop,
  ) {
    try {
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        print('❌ Navigasyon rotası bulunamadı');
        return null;
      }

      final route = routes.first;
      final legs = route['legs'] as List<dynamic>?;

      if (legs == null || legs.isEmpty) {
        print('❌ Navigasyon segmentleri bulunamadı');
        return null;
      }

      final leg = legs.first;
      final distance = leg['distanceMeters'] as int? ?? 0;
      final duration = leg['duration'] as String? ?? '0s';
      final polyline = leg['polyline']?['encodedPolyline'] as String? ?? '';

      // Adım adım talimatlar
      final steps = leg['steps'] as List<dynamic>? ?? [];
      final instructions = steps.map((step) {
        final instruction =
            step['navigationInstruction'] as Map<String, dynamic>?;
        return {
          'instruction': instruction?['instructions'] as String? ?? '',
          'maneuver': instruction?['maneuver'] as String? ?? '',
          'distance': step['distanceMeters'] as int? ?? 0,
        };
      }).toList();

      return {
        'nextStop': {
          'name': nextStop.customerName,
          'address': nextStop.address,
          'latitude': nextStop.latitude,
          'longitude': nextStop.longitude,
        },
        'distance': {
          'meters': distance,
          'kilometers': (distance / 1000).toStringAsFixed(2),
          'formatted': _formatDistance(distance),
        },
        'duration': {
          'raw': duration,
          'formatted': _formatDuration(duration),
          'seconds': _parseDurationToSeconds(duration),
        },
        'polyline': polyline,
        'instructions': instructions,
        'trafficInfo': _extractTrafficInfo(route),
      };
    } catch (e) {
      print('❌ Navigasyon yanıtı parse hatası: $e');
      return null;
    }
  }

  /// Trafik bilgilerini çıkarır
  Map<String, dynamic> _extractTrafficInfo(Map<String, dynamic> route) {
    try {
      final legs = route['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return {};

      final leg = legs.first;
      final durationInTraffic = leg['durationInTraffic'] as String?;
      final trafficInfo = leg['trafficInfo'] as Map<String, dynamic>?;

      return {
        'durationInTraffic': durationInTraffic,
        'trafficInfo': trafficInfo,
        'hasTrafficData': durationInTraffic != null,
      };
    } catch (e) {
      print('❌ Trafik bilgisi çıkarılamadı: $e');
      return {};
    }
  }

  /// Mesafeyi formatlar
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    } else {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    }
  }

  /// Süreyi formatlar
  String _formatDuration(String duration) {
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

  /// Süreyi saniyeye çevirir
  int _parseDurationToSeconds(String duration) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);

    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      return (hours * 3600) + (minutes * 60) + seconds;
    }

    return 0;
  }

  /// ETA (Estimated Time of Arrival) hesaplar
  Future<DateTime?> calculateETA({
    required List<StopModel> stops,
    required double currentLatitude,
    required double currentLongitude,
    required int nextStopIndex,
  }) async {
    try {
      final navInfo = await getNavigationInfo(
        stops: stops,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        nextStopIndex: nextStopIndex,
      );

      if (navInfo != null) {
        final durationSeconds = navInfo['duration']?['seconds'] as int? ?? 0;
        final eta = DateTime.now().add(Duration(seconds: durationSeconds));
        return eta;
      }
    } catch (e) {
      print('❌ ETA hesaplama hatası: $e');
    }

    return null;
  }

  /// Rota optimizasyonu için trafik verilerini alır
  Future<Map<String, dynamic>?> getTrafficData({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
  }) async {
    try {
      final requestBody = {
        'origin': {
          'location': {
            'latLng': {'latitude': startLatitude, 'longitude': startLongitude},
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': stops.last.latitude!,
              'longitude': stops.last.longitude!,
            },
          },
        },
        'intermediates': stops
            .take(stops.length - 1)
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
            .toList(),
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
        'trafficModel': 'BEST_GUESS',
        'languageCode': 'tr-TR',
        'units': 'METRIC',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseTrafficData(data);
      } else {
        print('❌ Google Traffic API hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Google Traffic isteği başarısız: $e');
      return null;
    }
  }

  /// Trafik verilerini parse eder
  Map<String, dynamic>? _parseTrafficData(Map<String, dynamic> data) {
    try {
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      final legs = route['legs'] as List<dynamic>?;

      if (legs == null || legs.isEmpty) return null;

      int totalDistance = 0;
      String totalDuration = '0s';
      int totalDurationInTraffic = 0;
      List<Map<String, dynamic>> trafficSegments = [];

      for (final leg in legs) {
        final distance = leg['distanceMeters'] as int? ?? 0;
        final duration = leg['duration'] as String? ?? '0s';
        final durationInTraffic = leg['durationInTraffic'] as String?;

        totalDistance += distance;

        if (durationInTraffic != null) {
          totalDurationInTraffic += _parseDurationToSeconds(durationInTraffic);
        }

        trafficSegments.add({
          'distance': distance,
          'duration': duration,
          'durationInTraffic': durationInTraffic,
          'hasTrafficDelay': durationInTraffic != null,
        });
      }

      return {
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'totalDurationInTraffic': totalDurationInTraffic,
        'hasTrafficData': totalDurationInTraffic > 0,
        'trafficDelay':
            totalDurationInTraffic - _parseDurationToSeconds(totalDuration),
        'segments': trafficSegments,
      };
    } catch (e) {
      print('❌ Trafik verisi parse hatası: $e');
      return null;
    }
  }
}
