import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../services/google_directions_service.dart';
import '../models/stop_model.dart';

/// Rota Polyline Widget
///
/// Google Maps üzerinde waypointler arasında polyline çizer
class RoutePolylineWidget extends StatefulWidget {
  final List<StopModel> stops;
  final double startLatitude;
  final double startLongitude;
  final String travelMode;
  final bool avoidHighways;
  final bool avoidTolls;
  final Color polylineColor;
  final double polylineWidth;
  final bool showMarkers;
  final bool showInfoWindow;
  final Function(Map<String, dynamic>?)? onRouteLoaded;
  final Function(String)? onError;

  const RoutePolylineWidget({
    super.key,
    required this.stops,
    required this.startLatitude,
    required this.startLongitude,
    this.travelMode = 'driving',
    this.avoidHighways = false,
    this.avoidTolls = false,
    this.polylineColor = Colors.blue,
    this.polylineWidth = 5.0,
    this.showMarkers = true,
    this.showInfoWindow = true,
    this.onRouteLoaded,
    this.onError,
  });

  @override
  State<RoutePolylineWidget> createState() => _RoutePolylineWidgetState();
}

class _RoutePolylineWidgetState extends State<RoutePolylineWidget> {
  late GoogleDirectionsService _directionsService;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  Map<String, dynamic>? _routeInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _directionsService = GoogleDirectionsService();
    _loadRoute();
  }

  @override
  void didUpdateWidget(RoutePolylineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Duraklar değiştiyse rotayı yeniden yükle
    if (oldWidget.stops != widget.stops ||
        oldWidget.startLatitude != widget.startLatitude ||
        oldWidget.startLongitude != widget.startLongitude) {
      _loadRoute();
    }
  }

  /// Rotayı yükler ve polyline oluşturur
  Future<void> _loadRoute() async {
    if (widget.stops.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final routeData = await _directionsService.getPolylineRoute(
        stops: widget.stops,
        startLatitude: widget.startLatitude,
        startLongitude: widget.startLongitude,
        travelMode: widget.travelMode,
        avoidHighways: widget.avoidHighways,
        avoidTolls: widget.avoidTolls,
      );

      if (routeData != null) {
        _createPolylines(routeData);
        if (widget.showMarkers) {
          _createMarkers();
        }
        _routeInfo = routeData;
        widget.onRouteLoaded?.call(routeData);
      } else {
        widget.onError?.call('Rota yüklenemedi');
      }
    } catch (e) {
      widget.onError?.call('Hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Polyline'ları oluşturur
  void _createPolylines(Map<String, dynamic> routeData) {
    final polylines = <Polyline>{};

    // Ana polyline
    final polylinePoints = routeData['polylinePoints'] as List<PointLatLng>?;
    if (polylinePoints != null && polylinePoints.isNotEmpty) {
      final points = polylinePoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      polylines.add(
        Polyline(
          polylineId: const PolylineId('main_route'),
          points: points,
          color: widget.polylineColor,
          width: widget.polylineWidth.toInt(),
          patterns: [],
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    // Leg polyline'ları (her segment için ayrı renk)
    final legPolylines = routeData['legPolylines'] as List<List<PointLatLng>>?;
    if (legPolylines != null) {
      for (int i = 0; i < legPolylines.length; i++) {
        final legPoints = legPolylines[i]
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        if (legPoints.isNotEmpty) {
          // Her leg için farklı renk
          final color = _getLegColor(i);

          polylines.add(
            Polyline(
              polylineId: PolylineId('leg_$i'),
              points: legPoints,
              color: color,
              width: (widget.polylineWidth * 0.8).toInt(),
              patterns: [PatternItem.dot, PatternItem.gap(10)],
              jointType: JointType.round,
            ),
          );
        }
      }
    }

    setState(() {
      _polylines = polylines;
    });
  }

  /// Leg için renk döndürür
  Color _getLegColor(int index) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  /// Marker'ları oluşturur
  void _createMarkers() {
    final markers = <Marker>{};

    // Başlangıç noktası
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(widget.startLatitude, widget.startLongitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Başlangıç',
          snippet: 'Rota başlangıç noktası',
        ),
      ),
    );

    // Duraklar
    for (int i = 0; i < widget.stops.length; i++) {
      final stop = widget.stops[i];
      if (stop.latitude != null && stop.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.latitude!, stop.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == widget.stops.length - 1
                  ? BitmapDescriptor
                        .hueRed // Son durak kırmızı
                  : BitmapDescriptor.hueBlue, // Diğer duraklar mavi
            ),
            infoWindow: widget.showInfoWindow
                ? InfoWindow(
                    title: stop.customerName,
                    snippet: '${stop.address}\nSıra: ${i + 1}',
                  )
                : const InfoWindow(),
            onTap: () => _onMarkerTapped(stop, i),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  /// Marker tıklandığında çağrılır
  void _onMarkerTapped(StopModel stop, int index) {
    // Marker tıklama işlemleri burada yapılabilir
    print('Marker tıklandı: ${stop.customerName} (Sıra: ${index + 1})');
  }

  /// Polyline'ları temizler
  void clearPolylines() {
    setState(() {
      _polylines.clear();
      _markers.clear();
      _routeInfo = null;
    });
  }

  /// Rotayı yeniler
  void refreshRoute() {
    _loadRoute();
  }

  /// Polyline'ları döndürür
  Set<Polyline> get polylines => _polylines;

  /// Marker'ları döndürür
  Set<Marker> get markers => _markers;

  /// Rota bilgilerini döndürür
  Map<String, dynamic>? get routeInfo => _routeInfo;

  /// Yükleniyor durumunu döndürür
  bool get isLoading => _isLoading;

  @override
  Widget build(BuildContext context) {
    // Bu widget sadece polyline ve marker verilerini sağlar
    // Gerçek Google Maps widget'ı parent widget'ta kullanılmalı
    return const SizedBox.shrink();
  }
}

/// Rota Polyline Controller
///
/// Polyline widget'ını kontrol etmek için kullanılır
class RoutePolylineController {
  _RoutePolylineWidgetState? _state;

  void attach(_RoutePolylineWidgetState state) {
    _state = state;
  }

  void detach() {
    _state = null;
  }

  /// Polyline'ları temizler
  void clearPolylines() {
    _state?.clearPolylines();
  }

  /// Rotayı yeniler
  void refreshRoute() {
    _state?.refreshRoute();
  }

  /// Polyline'ları döndürür
  Set<Polyline>? get polylines => _state?.polylines;

  /// Marker'ları döndürür
  Set<Marker>? get markers => _state?.markers;

  /// Rota bilgilerini döndürür
  Map<String, dynamic>? get routeInfo => _state?.routeInfo;

  /// Yükleniyor durumunu döndürür
  bool? get isLoading => _state?.isLoading;
}

/// Rota bilgilerini gösteren widget
class RouteInfoWidget extends StatelessWidget {
  final Map<String, dynamic>? routeInfo;
  final VoidCallback? onRefresh;

  const RouteInfoWidget({super.key, this.routeInfo, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (routeInfo == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rota Bilgileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (routeInfo!['totalDistanceKm'] != null)
              _InfoRow(
                icon: Icons.straighten,
                label: 'Toplam Mesafe',
                value: '${routeInfo!['totalDistanceKm']} km',
              ),
            if (routeInfo!['formattedDuration'] != null)
              _InfoRow(
                icon: Icons.access_time,
                label: 'Tahmini Süre',
                value: routeInfo!['formattedDuration'],
              ),
            if (routeInfo!['summary'] != null)
              _InfoRow(
                icon: Icons.route,
                label: 'Rota Özeti',
                value: routeInfo!['summary'],
              ),
          ],
        ),
      ),
    );
  }
}

/// Bilgi satırı widget'ı
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
