/// Google Maps API Konfigürasyonu
class GoogleMapsConfig {
  // API anahtarınızı buraya ekleyin
  static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // API endpoint'leri
  static const String routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String geocodingApiUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // Varsayılan ayarlar
  static const String defaultRegion = 'tr';
  static const String defaultLanguage = 'tr';
  static const String defaultTravelMode = 'DRIVE';
  static const String defaultTrafficModel = 'BEST_GUESS';

  // API kısıtlamaları
  static const int maxRequestsPerMinute = 100;
  static const int maxRequestsPerDay = 2500;

  /// API anahtarının geçerli olup olmadığını kontrol eder
  static bool get isApiKeyValid =>
      apiKey != 'YOUR_GOOGLE_MAPS_API_KEY' && apiKey.isNotEmpty;

  /// API anahtarını maskeler (güvenlik için)
  static String get maskedApiKey {
    if (apiKey.length <= 8) return '***';
    return '${apiKey.substring(0, 4)}***${apiKey.substring(apiKey.length - 4)}';
  }
}
