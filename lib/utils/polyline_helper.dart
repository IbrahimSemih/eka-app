import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math' as math;

/// Polyline işlemleri için yardımcı sınıf
class PolylineHelper {
  /// Polyline noktalarından LatLng listesi oluşturur
  static List<LatLng> pointsToLatLng(List<PointLatLng> points) {
    return points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  /// İki nokta arası mesafe hesaplar (metre)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // metre

    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Toplam rota mesafesini hesaplar
  static double calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateDistance(points[i], points[i + 1]);
    }

    return totalDistance;
  }

  /// Polyline için bounds oluşturur
  static LatLngBounds createBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double? minLat, maxLat, minLng, maxLng;

    for (final point in points) {
      minLat = minLat == null
          ? point.latitude
          : math.min(minLat, point.latitude);
      maxLat = maxLat == null
          ? point.latitude
          : math.max(maxLat, point.latitude);
      minLng = minLng == null
          ? point.longitude
          : math.min(minLng, point.longitude);
      maxLng = maxLng == null
          ? point.longitude
          : math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  /// Harita kamerasını polyline'a göre ayarlar
  static Future<void> fitBounds(
    GoogleMapController controller,
    List<LatLng> points, {
    double padding = 50,
  }) async {
    if (points.isEmpty) return;

    final bounds = createBounds(points);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  /// Polyline noktalarını basitleştirir (Douglas-Peucker algoritması)
  static List<LatLng> simplifyPoints(List<LatLng> points, double tolerance) {
    if (points.length < 3) return points;

    // Douglas-Peucker algoritması
    return _douglasPeucker(points, tolerance);
  }

  static List<LatLng> _douglasPeucker(List<LatLng> points, double tolerance) {
    if (points.length < 3) return points;

    // En uzak noktayı bul
    double maxDistance = 0;
    int maxIndex = 0;
    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // Eğer en uzak nokta tolerance'tan büyükse, bölüp devam et
    if (maxDistance > tolerance) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      final right = _douglasPeucker(points.sublist(maxIndex), tolerance);

      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [start, end];
    }
  }

  static double _perpendicularDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    final mag = math.sqrt(dx * dx + dy * dy);
    if (mag > 0.0) {
      final u =
          ((point.longitude - lineStart.longitude) * dx +
              (point.latitude - lineStart.latitude) * dy) /
          (mag * mag);

      if (u >= 0.0 && u <= 1.0) {
        final ix = lineStart.longitude + u * dx;
        final iy = lineStart.latitude + u * dy;

        final pdx = point.longitude - ix;
        final pdy = point.latitude - iy;

        return math.sqrt(pdx * pdx + pdy * pdy);
      }
    }

    // Eğer nokta çizgi dışındaysa, en yakın uç noktaya olan mesafeyi döndür
    final d1 = math.sqrt(
      math.pow(point.longitude - lineStart.longitude, 2) +
          math.pow(point.latitude - lineStart.latitude, 2),
    );
    final d2 = math.sqrt(
      math.pow(point.longitude - lineEnd.longitude, 2) +
          math.pow(point.latitude - lineEnd.latitude, 2),
    );

    return math.min(d1, d2);
  }

  /// Mesafe formatla (metre -> km/m)
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Süre formatla (saniye -> saat/dakika)
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours saat ${minutes > 0 ? '$minutes dk' : ''}';
    } else if (minutes > 0) {
      return '$minutes dakika';
    } else {
      return '$seconds saniye';
    }
  }

  /// Trafik yoğunluğuna göre renk döndürür
  static Color getTrafficColor(double trafficRatio) {
    if (trafficRatio > 1.5) {
      return Colors.red; // Yoğun trafik
    } else if (trafficRatio > 1.2) {
      return Colors.orange; // Orta trafik
    } else if (trafficRatio > 1.0) {
      return Colors.yellow; // Hafif trafik
    } else {
      return Colors.green; // Rahat trafik
    }
  }

  /// Segment bazlı polyline oluşturur (her iki durak arası farklı renk)
  static Set<Polyline> createSegmentedPolylines(
    List<List<LatLng>> segments, {
    List<Color>? colors,
    double width = 5.0,
  }) {
    final polylines = <Polyline>{};
    final defaultColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    for (int i = 0; i < segments.length; i++) {
      final segmentPoints = segments[i];
      if (segmentPoints.isEmpty) continue;

      final color = colors != null && i < colors.length
          ? colors[i]
          : defaultColors[i % defaultColors.length];

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_$i'),
          points: segmentPoints,
          color: color,
          width: width.toInt(),
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    return polylines;
  }

  /// Animasyonlu polyline için kısmi noktalar döndürür
  static List<LatLng> getAnimatedPoints(
    List<LatLng> allPoints,
    double progress,
  ) {
    if (allPoints.isEmpty) return [];
    if (progress >= 1.0) return allPoints;

    final targetIndex = (allPoints.length * progress).toInt();
    return allPoints.sublist(0, math.max(1, targetIndex));
  }

  /// Nokta üzerinde interpolasyon yapar
  static LatLng interpolate(LatLng start, LatLng end, double fraction) {
    final lat = start.latitude + (end.latitude - start.latitude) * fraction;
    final lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  /// Polyline üzerinde belirli bir mesafedeki noktayı bulur
  static LatLng? getPointAtDistance(
    List<LatLng> points,
    double targetDistance,
  ) {
    if (points.isEmpty) return null;

    double currentDistance = 0;

    for (int i = 0; i < points.length - 1; i++) {
      final segmentDistance = calculateDistance(points[i], points[i + 1]);

      if (currentDistance + segmentDistance >= targetDistance) {
        final remainingDistance = targetDistance - currentDistance;
        final fraction = remainingDistance / segmentDistance;
        return interpolate(points[i], points[i + 1], fraction);
      }

      currentDistance += segmentDistance;
    }

    return points.last;
  }

  /// Marker'lar için farklı renkler döndürür
  static BitmapDescriptor getMarkerColor(int index, int total) {
    if (index == 0) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      ); // Başlangıç
    } else if (index == total - 1) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      ); // Bitiş
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      ); // Ara duraklar
    }
  }

  /// Polyline için gradyan renk listesi oluşturur
  static List<Color> createGradientColors(
    Color startColor,
    Color endColor,
    int steps,
  ) {
    final colors = <Color>[];

    for (int i = 0; i < steps; i++) {
      final fraction = i / (steps - 1);
      colors.add(Color.lerp(startColor, endColor, fraction)!);
    }

    return colors;
  }

  /// Polyline bilgilerini metne dönüştürür
  static String getPolylineInfo(List<LatLng> points) {
    if (points.isEmpty) return 'Polyline yok';

    final distance = calculateTotalDistance(points);
    final bounds = createBounds(points);

    return '''
📍 Nokta Sayısı: ${points.length}
📏 Toplam Mesafe: ${formatDistance(distance)}
🗺️ Bounds: 
  - Güneybatı: ${bounds.southwest.latitude.toStringAsFixed(4)}, ${bounds.southwest.longitude.toStringAsFixed(4)}
  - Kuzeydoğu: ${bounds.northeast.latitude.toStringAsFixed(4)}, ${bounds.northeast.longitude.toStringAsFixed(4)}
    ''';
  }

  /// Polyline'ı encode eder (Google encoding algoritması)
  static String encodePolyline(List<LatLng> points) {
    final pointList = points
        .map((p) => PointLatLng(p.latitude, p.longitude))
        .toList();

    // flutter_polyline_points paketi decode edebilir ama encode edemez
    // Bu yüzden basit bir implementasyon:
    return _encodePoints(pointList);
  }

  static String _encodePoints(List<PointLatLng> points) {
    final buffer = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();

      buffer.write(_encodeNumber(lat - prevLat));
      buffer.write(_encodeNumber(lng - prevLng));

      prevLat = lat;
      prevLng = lng;
    }

    return buffer.toString();
  }

  static String _encodeNumber(int num) {
    final buffer = StringBuffer();
    int value = num < 0 ? ~(num << 1) : (num << 1);

    while (value >= 0x20) {
      buffer.writeCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }

    buffer.writeCharCode(value + 63);
    return buffer.toString();
  }
}
