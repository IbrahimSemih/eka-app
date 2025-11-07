import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/google_maps_config.dart';

/// API anahtarını test eder
class ApiKeyTester {
  /// Directions API'yi test eder
  static Future<Map<String, dynamic>> testDirectionsApi() async {
    final apiKey = GoogleMapsConfig.apiKey;
    
    // Basit bir test isteği (İstanbul - Ankara)
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=41.0082,28.9784'
      '&destination=39.9334,32.8597'
      '&key=$apiKey',
    );

    try {
      print('🧪 API Anahtarı Test Ediliyor...');
      print('🔑 API Key: ${GoogleMapsConfig.maskedApiKey}');
      print('🌐 Test URL: ${url.toString().replaceAll(apiKey, "***")}');
      
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      print('📊 HTTP Status: ${response.statusCode}');
      print('📋 API Status: ${data['status']}');

      if (data['status'] == 'OK') {
        print('✅ API Anahtarı çalışıyor!');
        return {
          'success': true,
          'message': 'API anahtarı başarıyla test edildi',
          'status': data['status'],
        };
      } else {
        print('❌ API Hatası: ${data['status']}');
        if (data['error_message'] != null) {
          print('💬 Hata Mesajı: ${data['error_message']}');
        }
        return {
          'success': false,
          'message': data['error_message'] ?? 'Bilinmeyen hata',
          'status': data['status'],
        };
      }
    } catch (e) {
      print('❌ Test Hatası: $e');
      return {
        'success': false,
        'message': e.toString(),
        'status': 'EXCEPTION',
      };
    }
  }

  /// Geocoding API'yi test eder
  static Future<Map<String, dynamic>> testGeocodingApi() async {
    final apiKey = GoogleMapsConfig.apiKey;
    
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=Istanbul,Turkey'
      '&key=$apiKey',
    );

    try {
      print('🧪 Geocoding API Test Ediliyor...');
      
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      print('📊 HTTP Status: ${response.statusCode}');
      print('📋 API Status: ${data['status']}');

      if (data['status'] == 'OK') {
        print('✅ Geocoding API çalışıyor!');
        return {
          'success': true,
          'message': 'Geocoding API başarıyla test edildi',
          'status': data['status'],
        };
      } else {
        print('❌ API Hatası: ${data['status']}');
        if (data['error_message'] != null) {
          print('💬 Hata Mesajı: ${data['error_message']}');
        }
        return {
          'success': false,
          'message': data['error_message'] ?? 'Bilinmeyen hata',
          'status': data['status'],
        };
      }
    } catch (e) {
      print('❌ Test Hatası: $e');
      return {
        'success': false,
        'message': e.toString(),
        'status': 'EXCEPTION',
      };
    }
  }

  /// Tüm API'leri test eder
  static Future<void> testAllApis() async {
    print('\n' + '=' * 50);
    print('🧪 GOOGLE MAPS API TEST BAŞLADI');
    print('=' * 50 + '\n');

    // Directions API
    print('1️⃣ DIRECTIONS API TEST');
    print('-' * 50);
    await testDirectionsApi();
    print('');

    // Geocoding API
    print('2️⃣ GEOCODING API TEST');
    print('-' * 50);
    await testGeocodingApi();
    print('');

    print('=' * 50);
    print('🎯 TEST TAMAMLANDI');
    print('=' * 50 + '\n');
  }
}

