import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Geocoding Servisi - Adres ve koordinat dönüşümleri
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  /// Adres metnini koordinatlara dönüştürür
  ///
  /// [address] - Dönüştürülecek adres metni
  ///
  /// Returns: (latitude, longitude) tuple veya null
  Future<({double latitude, double longitude})?> addressToCoordinates(
    String address,
  ) async {
    try {
      if (address.trim().isEmpty) {
        throw Exception('Adres boş olamaz');
      }

      // Adresi Türkiye için optimize et
      String optimizedAddress = _optimizeAddressForTurkey(address);
      print('🔍 Optimize edilmiş adres: $optimizedAddress');

      // Birden fazla geocoding stratejisi dene
      List<Location> locations = await _tryMultipleGeocodingStrategies(
        optimizedAddress,
        address,
      );

      if (locations.isEmpty) {
        throw Exception('Adres bulunamadı: $address');
      }

      // En iyi sonucu seç
      final bestLocation = _selectBestLocation(locations, address);
      print(
        '✅ En iyi koordinatlar seçildi: ${bestLocation.latitude}, ${bestLocation.longitude}',
      );

      // Türkiye sınırları içinde mi kontrol et
      if (!_isInTurkey(bestLocation.latitude, bestLocation.longitude)) {
        print('⚠️ Koordinatlar Türkiye sınırları dışında');
        return null;
      }

      // Koordinat kalitesini kontrol et
      if (!_isCoordinateQualityGood(bestLocation, address)) {
        print('⚠️ Koordinat kalitesi düşük, alternatif aranıyor...');
        // Alternatif koordinat arama stratejisi
        final alternativeLocation = await _findAlternativeCoordinates(address);
        if (alternativeLocation != null) {
          return alternativeLocation;
        }
      }

      return (
        latitude: bestLocation.latitude,
        longitude: bestLocation.longitude,
      );
    } catch (e) {
      print('❌ Geocoding hatası: $e');
      return null;
    }
  }

  /// Birden fazla geocoding stratejisi dener
  Future<List<Location>> _tryMultipleGeocodingStrategies(
    String optimizedAddress,
    String originalAddress,
  ) async {
    List<Location> locations = [];

    // Strateji 1: Optimize edilmiş adres
    try {
      locations = await locationFromAddress(optimizedAddress);
      if (locations.isNotEmpty) {
        print('✅ Strateji 1 başarılı: Optimize edilmiş adres');
        return locations;
      }
    } catch (e) {
      print('❌ Strateji 1 başarısız: $e');
    }

    // Strateji 2: Orijinal adres
    try {
      locations = await locationFromAddress(originalAddress);
      if (locations.isNotEmpty) {
        print('✅ Strateji 2 başarılı: Orijinal adres');
        return locations;
      }
    } catch (e) {
      print('❌ Strateji 2 başarısız: $e');
    }

    // Strateji 3: Adres parçalarını dene
    try {
      final addressParts = _splitAddressIntoParts(originalAddress);
      for (String part in addressParts) {
        if (part.trim().length > 10) {
          // En az 10 karakter
          locations = await locationFromAddress('$part, Türkiye');
          if (locations.isNotEmpty) {
            print('✅ Strateji 3 başarılı: Adres parçası - $part');
            return locations;
          }
        }
      }
    } catch (e) {
      print('❌ Strateji 3 başarısız: $e');
    }

    return locations;
  }

  /// Adresi parçalara böler
  List<String> _splitAddressIntoParts(String address) {
    List<String> parts = address.split(',').map((e) => e.trim()).toList();
    List<String> result = [];

    // Her parçayı ve birleşimlerini dene
    for (int i = 0; i < parts.length; i++) {
      for (int j = i + 1; j <= parts.length; j++) {
        String combination = parts.sublist(i, j).join(', ');
        if (combination.trim().isNotEmpty) {
          result.add(combination);
        }
      }
    }

    return result;
  }

  /// En iyi lokasyonu seçer
  Location _selectBestLocation(
    List<Location> locations,
    String originalAddress,
  ) {
    if (locations.length == 1) return locations.first;

    // Koordinat kalitesine göre sırala
    locations.sort((a, b) {
      double scoreA = _calculateLocationScore(a, originalAddress);
      double scoreB = _calculateLocationScore(b, originalAddress);
      return scoreB.compareTo(scoreA); // Yüksek skor önce
    });

    return locations.first;
  }

  /// Lokasyon skorunu hesaplar
  double _calculateLocationScore(Location location, String originalAddress) {
    double score = 0.0;

    // Türkiye sınırları içinde mi
    if (_isInTurkey(location.latitude, location.longitude)) {
      score += 50.0;
    }

    // Koordinat hassasiyeti (daha yüksek hassasiyet = daha iyi)
    double latPrecision = location.latitude
        .toString()
        .split('.')
        .last
        .length
        .toDouble();
    double lonPrecision = location.longitude
        .toString()
        .split('.')
        .last
        .length
        .toDouble();
    score += (latPrecision + lonPrecision) * 5.0;

    // Adres uzunluğu ile koordinat kalitesi korelasyonu
    if (originalAddress.length > 20) {
      score += 10.0; // Uzun adresler genellikle daha spesifik
    }

    return score;
  }

  /// Koordinat kalitesini kontrol eder
  bool _isCoordinateQualityGood(Location location, String originalAddress) {
    // Temel kalite kontrolleri
    if (location.latitude == 0.0 && location.longitude == 0.0) return false;
    if (location.latitude.abs() > 90.0 || location.longitude.abs() > 180.0)
      return false;

    // Türkiye için makul koordinat aralığı
    if (location.latitude < 35.0 || location.latitude > 42.0) return false;
    if (location.longitude < 25.0 || location.longitude > 45.0) return false;

    return true;
  }

  /// Alternatif koordinat bulma stratejisi
  Future<({double latitude, double longitude})?> _findAlternativeCoordinates(
    String address,
  ) async {
    try {
      // Reverse geocoding ile doğrulama
      final coordinates = await _tryReverseGeocoding(address);
      if (coordinates != null) return coordinates;

      // Yakın konumlar arama
      return await _searchNearbyLocations(address);
    } catch (e) {
      print('❌ Alternatif koordinat bulunamadı: $e');
      return null;
    }
  }

  /// Reverse geocoding ile koordinat doğrulama
  Future<({double latitude, double longitude})?> _tryReverseGeocoding(
    String address,
  ) async {
    // Bu fonksiyon gelecekte implement edilebilir
    return null;
  }

  /// Yakın konumlar arama
  Future<({double latitude, double longitude})?> _searchNearbyLocations(
    String address,
  ) async {
    // Bu fonksiyon gelecekte implement edilebilir
    return null;
  }

  /// Adresi Türkiye için optimize eder
  String _optimizeAddressForTurkey(String address) {
    String optimizedAddress = address.trim();

    // Adres formatını standartlaştır
    optimizedAddress = _standardizeAddressFormat(optimizedAddress);

    // Türkiye ekle (eğer yoksa)
    if (!optimizedAddress.toLowerCase().contains('türkiye') &&
        !optimizedAddress.toLowerCase().contains('turkey') &&
        !optimizedAddress.toLowerCase().contains('tr')) {
      optimizedAddress = '$optimizedAddress, Türkiye';
    }

    return optimizedAddress;
  }

  /// Adres formatını standartlaştırır
  String _standardizeAddressFormat(String address) {
    // Fazla boşlukları temizle
    String cleaned = address.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Yaygın kısaltmaları genişlet
    cleaned = cleaned.replaceAll(
      RegExp(r'\bCad\.\b', caseSensitive: false),
      'Caddesi',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bSok\.\b', caseSensitive: false),
      'Sokağı',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bMah\.\b', caseSensitive: false),
      'Mahallesi',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bNo\.\b', caseSensitive: false),
      'No',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bApt\.\b', caseSensitive: false),
      'Apartmanı',
    );

    // İl/ilçe isimlerini standartlaştır
    cleaned = _standardizeCityNames(cleaned);

    return cleaned;
  }

  /// İl/ilçe isimlerini standartlaştırır
  String _standardizeCityNames(String address) {
    // Yaygın il/ilçe isim düzeltmeleri
    final cityMappings = {
      'İstanbul': 'İstanbul',
      'Istanbul': 'İstanbul',
      'Ankara': 'Ankara',
      'İzmir': 'İzmir',
      'Izmir': 'İzmir',
      'Bursa': 'Bursa',
      'Antalya': 'Antalya',
      'Adana': 'Adana',
      'Konya': 'Konya',
      'Gaziantep': 'Gaziantep',
      'Şanlıurfa': 'Şanlıurfa',
      'Sanliurfa': 'Şanlıurfa',
    };

    String result = address;
    cityMappings.forEach((key, value) {
      result = result.replaceAll(RegExp(key, caseSensitive: false), value);
    });

    return result;
  }

  /// Koordinatların Türkiye sınırları içinde olup olmadığını kontrol eder
  bool _isInTurkey(double latitude, double longitude) {
    // Türkiye'nin daha hassas sınırları
    const double minLat = 35.0;
    const double maxLat = 42.0;
    const double minLon = 25.0;
    const double maxLon = 45.0;

    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLon &&
        longitude <= maxLon;
  }

  /// Koordinat doğruluğunu test eder ve raporlar
  Future<Map<String, dynamic>> testCoordinateAccuracy(String address) async {
    try {
      final startTime = DateTime.now();
      final coordinates = await addressToCoordinates(address);
      final endTime = DateTime.now();

      if (coordinates == null) {
        return {
          'success': false,
          'error': 'Koordinat bulunamadı',
          'address': address,
        };
      }

      // Reverse geocoding ile doğrulama
      final reverseAddress = await coordinatesToAddress(
        coordinates.latitude,
        coordinates.longitude,
      );

      return {
        'success': true,
        'original_address': address,
        'coordinates': {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
        },
        'reverse_address': reverseAddress,
        'processing_time_ms': endTime.difference(startTime).inMilliseconds,
        'accuracy_score': _calculateAccuracyScore(address, reverseAddress),
        'is_in_turkey': _isInTurkey(
          coordinates.latitude,
          coordinates.longitude,
        ),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'address': address};
    }
  }

  /// Doğruluk skorunu hesaplar
  double _calculateAccuracyScore(
    String originalAddress,
    String? reverseAddress,
  ) {
    if (reverseAddress == null) return 0.0;

    // Basit string benzerlik skoru
    final originalWords = originalAddress.toLowerCase().split(' ');
    final reverseWords = reverseAddress.toLowerCase().split(' ');

    int commonWords = 0;
    for (String word in originalWords) {
      if (reverseWords.any((w) => w.contains(word) || word.contains(w))) {
        commonWords++;
      }
    }

    return (commonWords / originalWords.length) * 100.0;
  }

  /// Koordinatları adres metnine dönüştürür
  ///
  /// [latitude] - Enlem
  /// [longitude] - Boylam
  ///
  /// Returns: Adres metni veya null
  Future<String?> coordinatesToAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('Koordinat için adres bulunamadı');
      }

      final placemark = placemarks.first;

      // Türkiye için uygun adres formatı
      List<String> addressParts = [];

      if (placemark.street != null && placemark.street!.isNotEmpty) {
        addressParts.add(placemark.street!);
      }
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        addressParts.add(placemark.subLocality!);
      }
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        addressParts.add(placemark.locality!);
      }
      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.isNotEmpty) {
        addressParts.add(placemark.administrativeArea!);
      }
      if (placemark.country != null && placemark.country!.isNotEmpty) {
        addressParts.add(placemark.country!);
      }

      return addressParts.join(', ');
    } catch (e) {
      print('Reverse geocoding hatası: $e');
      return null;
    }
  }

  /// İki koordinat arasındaki mesafeyi hesaplar (km cinsinden)
  ///
  /// [lat1, lon1] - İlk nokta
  /// [lat2, lon2] - İkinci nokta
  ///
  /// Returns: Mesafe (km)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Kullanıcının mevcut konumunu alır
  ///
  /// Returns: (latitude, longitude) tuple veya null
  Future<({double latitude, double longitude})?> getCurrentLocation() async {
    try {
      // Konum izinlerini kontrol et
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalıcı olarak reddedildi');
      }

      // Mevcut konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return (latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      print('Konum alma hatası: $e');
      return null;
    }
  }

  /// Adres geçerliliğini kontrol eder
  ///
  /// [address] - Kontrol edilecek adres
  ///
  /// Returns: true eğer adres geçerliyse
  Future<bool> isAddressValid(String address) async {
    try {
      final coordinates = await addressToCoordinates(address);
      return coordinates != null;
    } catch (e) {
      return false;
    }
  }

  /// Birden fazla adresi toplu olarak koordinatlara dönüştürür
  ///
  /// [addresses] - Dönüştürülecek adres listesi
  ///
  /// Returns: Adres-koordinat eşleştirmesi
  Future<Map<String, ({double latitude, double longitude})?>>
  batchAddressToCoordinates(List<String> addresses) async {
    Map<String, ({double latitude, double longitude})?> results = {};

    for (String address in addresses) {
      results[address] = await addressToCoordinates(address);
    }

    return results;
  }
}
