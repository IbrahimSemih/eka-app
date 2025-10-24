import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Geocoding API Servisi
///
/// Google'ın Geocoding API'sini kullanarak gelişmiş adres çözümleme sağlar
class GoogleGeocodingService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  final String _apiKey;

  GoogleGeocodingService({required String apiKey}) : _apiKey = apiKey;

  /// Adresi koordinatlara dönüştürür (Forward Geocoding)
  ///
  /// [address] - Dönüştürülecek adres
  /// [region] - Bölge kodu (tr için 'tr')
  /// [language] - Dil kodu (tr için 'tr')
  ///
  /// Returns: (latitude, longitude) tuple veya null
  Future<({double latitude, double longitude})?> addressToCoordinates(
    String address, {
    String region = 'tr',
    String language = 'tr',
  }) async {
    try {
      if (address.trim().isEmpty) {
        print('❌ Adres boş olamaz');
        return null;
      }

      // Adresi optimize et
      final optimizedAddress = _optimizeAddressForTurkey(address);
      print('🔍 Google Geocoding: $optimizedAddress');

      final response = await http.get(
        Uri.parse(
          '$_baseUrl?address=${Uri.encodeComponent(optimizedAddress)}&region=$region&language=$language&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseGeocodingResponse(data);
      } else {
        print('❌ Google Geocoding API hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Google Geocoding isteği başarısız: $e');
      return null;
    }
  }

  /// Koordinatları adrese dönüştürür (Reverse Geocoding)
  ///
  /// [latitude] - Enlem
  /// [longitude] - Boylam
  /// [language] - Dil kodu
  ///
  /// Returns: Adres metni veya null
  Future<String?> coordinatesToAddress(
    double latitude,
    double longitude, {
    String language = 'tr',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl?latlng=$latitude,$longitude&language=$language&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseReverseGeocodingResponse(data);
      } else {
        print('❌ Google Reverse Geocoding API hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Google Reverse Geocoding isteği başarısız: $e');
      return null;
    }
  }

  /// Adres arama (Place Autocomplete benzeri)
  ///
  /// [input] - Arama metni
  /// [region] - Bölge kodu
  /// [language] - Dil kodu
  ///
  /// Returns: Adres önerileri listesi
  Future<List<Map<String, dynamic>>> searchAddresses(
    String input, {
    String region = 'tr',
    String language = 'tr',
  }) async {
    try {
      if (input.trim().isEmpty) {
        return [];
      }

      final response = await http.get(
        Uri.parse(
          '$_baseUrl?address=${Uri.encodeComponent(input)}&region=$region&language=$language&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseSearchResults(data);
      } else {
        print('❌ Google Address Search API hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Google Address Search isteği başarısız: $e');
      return [];
    }
  }

  /// Geocoding yanıtını parse eder
  ({double latitude, double longitude})? _parseGeocodingResponse(
    Map<String, dynamic> data,
  ) {
    try {
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        print('❌ Geocoding sonucu bulunamadı');
        return null;
      }

      final result = results.first;
      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      if (location != null) {
        final lat = location['lat'] as double?;
        final lng = location['lng'] as double?;

        if (lat != null && lng != null) {
          print('✅ Google Geocoding başarılı: $lat, $lng');
          return (latitude: lat, longitude: lng);
        }
      }

      print('❌ Geocoding yanıtı parse edilemedi');
      return null;
    } catch (e) {
      print('❌ Geocoding parse hatası: $e');
      return null;
    }
  }

  /// Reverse Geocoding yanıtını parse eder
  String? _parseReverseGeocodingResponse(Map<String, dynamic> data) {
    try {
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        print('❌ Reverse Geocoding sonucu bulunamadı');
        return null;
      }

      final result = results.first;
      final formattedAddress = result['formatted_address'] as String?;

      if (formattedAddress != null) {
        print('✅ Google Reverse Geocoding başarılı: $formattedAddress');
        return formattedAddress;
      }

      print('❌ Reverse Geocoding yanıtı parse edilemedi');
      return null;
    } catch (e) {
      print('❌ Reverse Geocoding parse hatası: $e');
      return null;
    }
  }

  /// Arama sonuçlarını parse eder
  List<Map<String, dynamic>> _parseSearchResults(Map<String, dynamic> data) {
    try {
      final results = data['results'] as List<dynamic>?;
      if (results == null) return [];

      return results.map((result) {
        final geometry = result['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final formattedAddress = result['formatted_address'] as String?;

        return {
          'address': formattedAddress ?? '',
          'latitude': location?['lat'] as double? ?? 0.0,
          'longitude': location?['lng'] as double? ?? 0.0,
          'placeId': result['place_id'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      print('❌ Arama sonuçları parse hatası: $e');
      return [];
    }
  }

  /// Türkiye için adres optimizasyonu
  String _optimizeAddressForTurkey(String address) {
    String optimized = address.trim();

    // Türkiye ekle (yoksa)
    if (!optimized.toLowerCase().contains('türkiye') &&
        !optimized.toLowerCase().contains('turkey')) {
      optimized += ', Türkiye';
    }

    // Yaygın kısaltmaları genişlet
    optimized = optimized
        .replaceAll(RegExp(r'\bCd\.', caseSensitive: false), 'Caddesi')
        .replaceAll(RegExp(r'\bSk\.', caseSensitive: false), 'Sokak')
        .replaceAll(RegExp(r'\bBlv\.', caseSensitive: false), 'Bulvarı')
        .replaceAll(RegExp(r'\bMah\.', caseSensitive: false), 'Mahallesi')
        .replaceAll(RegExp(r'\bNo\.', caseSensitive: false), 'No:')
        .replaceAll(RegExp(r'\bApt\.', caseSensitive: false), 'Apartmanı');

    return optimized;
  }
}
