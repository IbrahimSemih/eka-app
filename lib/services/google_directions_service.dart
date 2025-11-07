import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../config/google_maps_config.dart';
import '../models/stop_model.dart';

/// Google Directions API Servisi
///
/// Waypointler arasında polyline çizmek için Directions API kullanır
class GoogleDirectionsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  final String _apiKey;
  final PolylinePoints _polylinePoints;

  GoogleDirectionsService({String? apiKey})
    : _apiKey = apiKey ?? GoogleMapsConfig.apiKey,
      _polylinePoints = PolylinePoints();

  /// Waypointler arasında polyline oluşturur
  ///
  /// [stops] - Durak listesi (waypoints)
  /// [startLatitude] - Başlangıç noktası enlemi
  /// [startLongitude] - Başlangıç noktası boylamı
  /// [travelMode] - Seyahat modu (driving, walking, bicycling, transit)
  /// [avoidHighways] - Otoyollardan kaçın
  /// [avoidTolls] - Ücretli yollardan kaçın
  ///
  /// Returns: Polyline noktaları ve rota bilgileri
  Future<Map<String, dynamic>?> getPolylineRoute({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String travelMode = 'driving',
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    if (stops.isEmpty) return null;

    try {
      print('🗺️ Google Directions API ile polyline oluşturuluyor...');

      // Koordinatları olan durakları filtrele
      final validStops = stops
          .where((stop) => stop.latitude != null && stop.longitude != null)
          .toList();

      if (validStops.isEmpty) {
        print('❌ Koordinatları olan durak bulunamadı');
        return null;
      }

      // Directions API isteği oluştur
      final url = _buildDirectionsUrl(
        validStops,
        startLatitude,
        startLongitude,
        travelMode,
        avoidHighways,
        avoidTolls,
      );

      // API isteği gönder
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          return _parseDirectionsResponse(data);
        } else {
          final errorMessage = data['error_message'] ?? 'Bilinmeyen hata';
          print('❌ Directions API hatası: ${data['status']}');
          print('Error message: $errorMessage');

          // Özel hata mesajları
          if (data['status'] == 'REQUEST_DENIED') {
            print('🔑 API anahtarı yetkilendirme hatası!');
            print('📋 Çözüm adımları:');
            print('1. Google Cloud Console\'da API anahtarınızı kontrol edin');
            print('2. Application restrictions: Android apps');
            print('3. Package name: com.example.eka_app');
            print(
              '4. SHA-1: 30:43:B9:0D:A8:A7:6A:B1:79:28:D1:B0:63:AD:FF:BD:C1:E0:D5:16',
            );
            print(
              '5. API restrictions: Directions API, Geocoding API, Maps SDK for Android',
            );
          }

          return null;
        }
      } else {
        print('❌ HTTP hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Directions API isteği başarısız: $e');
      return null;
    }
  }

  /// Directions API URL'si oluşturur
  String _buildDirectionsUrl(
    List<StopModel> stops,
    double startLatitude,
    double startLongitude,
    String travelMode,
    bool avoidHighways,
    bool avoidTolls,
  ) {
    final origin = '$startLatitude,$startLongitude';

    // Waypointler için koordinatları hazırla
    final waypoints = stops
        .map((stop) => '${stop.latitude},${stop.longitude}')
        .join('|');

    // Son durak destination olarak kullan
    final destination = waypoints.split('|').last;

    // Waypointler (son durak hariç)
    final waypointStr = waypoints
        .split('|')
        .sublist(0, stops.length - 1)
        .join('|');

    // URL parametreleri
    final params = <String, String>{
      'origin': origin,
      'destination': destination,
      'waypoints': waypointStr,
      'mode': travelMode,
      'language': 'tr',
      'region': 'tr',
      'units': 'metric',
      'key': _apiKey,
    };

    // Ek parametreler
    if (avoidHighways) params['avoid'] = 'highways';
    if (avoidTolls) params['avoid'] = 'tolls';
    if (avoidHighways && avoidTolls) params['avoid'] = 'highways|tolls';

    // URL oluştur
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Directions API yanıtını parse eder
  Map<String, dynamic>? _parseDirectionsResponse(Map<String, dynamic> data) {
    try {
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        print('❌ Rota bulunamadı');
        return null;
      }

      final route = routes.first;
      final legs = route['legs'] as List<dynamic>?;
      final overviewPolyline =
          route['overview_polyline'] as Map<String, dynamic>?;

      if (legs == null || legs.isEmpty || overviewPolyline == null) {
        print('❌ Rota verisi eksik');
        return null;
      }

      // Polyline noktalarını decode et
      final polylinePoints = _polylinePoints.decodePolyline(
        overviewPolyline['points'] as String,
      );

      // Rota bilgilerini hesapla
      int totalDistance = 0;
      int totalDuration = 0;

      for (final leg in legs) {
        final distance = leg['distance']?['value'] as int? ?? 0;
        final duration = leg['duration']?['value'] as int? ?? 0;
        totalDistance += distance;
        totalDuration += duration;
      }

      // Leg'ler arası polyline'ları oluştur
      final legPolylines = <List<PointLatLng>>[];
      for (final leg in legs) {
        final steps = leg['steps'] as List<dynamic>?;
        if (steps != null) {
          for (final step in steps) {
            final polyline = step['polyline'] as Map<String, dynamic>?;
            if (polyline != null) {
              final points = _polylinePoints.decodePolyline(
                polyline['points'] as String,
              );
              legPolylines.add(points);
            }
          }
        }
      }

      print('✅ Polyline oluşturuldu: ${polylinePoints.length} nokta');
      print(
        '📏 Toplam mesafe: ${(totalDistance / 1000).toStringAsFixed(2)} km',
      );
      print('⏱️ Toplam süre: ${_formatDuration(totalDuration)}');

      return {
        'polylinePoints': polylinePoints,
        'legPolylines': legPolylines,
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'totalDistanceKm': (totalDistance / 1000).toStringAsFixed(2),
        'formattedDuration': _formatDuration(totalDuration),
        'legs': legs,
        'bounds': route['bounds'],
        'summary': route['summary'],
      };
    } catch (e) {
      print('❌ Directions yanıtı parse hatası: $e');
      return null;
    }
  }

  /// Süreyi formatlar (saniye -> okunabilir format)
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours saat ${minutes > 0 ? '$minutes dakika' : ''}';
    } else if (minutes > 0) {
      return '$minutes dakika';
    } else {
      return '$remainingSeconds saniye';
    }
  }

  /// Sadece iki nokta arasında polyline oluşturur
  Future<Map<String, dynamic>?> getSimplePolyline({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String travelMode = 'driving',
  }) async {
    try {
      print('🗺️ İki nokta arası polyline oluşturuluyor...');

      final url = _buildSimpleDirectionsUrl(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
        travelMode,
      );

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          return _parseDirectionsResponse(data);
        } else {
          print('❌ Directions API hatası: ${data['status']}');
          return null;
        }
      } else {
        print('❌ HTTP hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Simple polyline oluşturma hatası: $e');
      return null;
    }
  }

  /// İki nokta arası Directions API URL'si oluşturur
  String _buildSimpleDirectionsUrl(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
    String travelMode,
  ) {
    final params = <String, String>{
      'origin': '$startLatitude,$startLongitude',
      'destination': '$endLatitude,$endLongitude',
      'mode': travelMode,
      'language': 'tr',
      'region': 'tr',
      'units': 'metric',
      'key': _apiKey,
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Rota alternatiflerini getirir
  Future<List<Map<String, dynamic>>> getAlternativeRoutes({
    required List<StopModel> stops,
    required double startLatitude,
    required double startLongitude,
    String travelMode = 'driving',
    int maxAlternatives = 3,
  }) async {
    try {
      print('🗺️ Alternatif rotalar alınıyor...');

      final validStops = stops
          .where((stop) => stop.latitude != null && stop.longitude != null)
          .toList();

      if (validStops.isEmpty) return [];

      final origin = '$startLatitude,$startLongitude';
      final waypoints = validStops
          .map((stop) => '${stop.latitude},${stop.longitude}')
          .join('|');
      final destination = waypoints.split('|').last;
      final waypointStr = waypoints
          .split('|')
          .sublist(0, validStops.length - 1)
          .join('|');

      final params = <String, String>{
        'origin': origin,
        'destination': destination,
        'waypoints': waypointStr,
        'mode': travelMode,
        'language': 'tr',
        'region': 'tr',
        'units': 'metric',
        'alternatives': 'true',
        'key': _apiKey,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(Uri.parse(uri.toString()));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List<dynamic>? ?? [];
          final alternativeRoutes = <Map<String, dynamic>>[];

          for (int i = 0; i < routes.length && i < maxAlternatives; i++) {
            final route = routes[i];
            final overviewPolyline =
                route['overview_polyline'] as Map<String, dynamic>?;

            if (overviewPolyline != null) {
              final polylinePoints = _polylinePoints.decodePolyline(
                overviewPolyline['points'] as String,
              );

              alternativeRoutes.add({
                'index': i,
                'polylinePoints': polylinePoints,
                'summary': route['summary'],
                'bounds': route['bounds'],
                'legs': route['legs'],
              });
            }
          }

          print('✅ ${alternativeRoutes.length} alternatif rota bulundu');
          return alternativeRoutes;
        }
      }

      return [];
    } catch (e) {
      print('❌ Alternatif rotalar alınamadı: $e');
      return [];
    }
  }
}
