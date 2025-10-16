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

      // Geocoding API'sini kullanarak adresi koordinatlara dönüştür
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        throw Exception('Adres bulunamadı: $address');
      }

      final location = locations.first;
      return (latitude: location.latitude, longitude: location.longitude);
    } catch (e) {
      print('Geocoding hatası: $e');
      return null;
    }
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
