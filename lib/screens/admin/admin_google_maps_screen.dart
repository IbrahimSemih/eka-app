import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';

/// Admin paneli için Google Maps ekranı
class AdminGoogleMapsScreen extends StatefulWidget {
  final RouteModel route;

  const AdminGoogleMapsScreen({super.key, required this.route});

  @override
  State<AdminGoogleMapsScreen> createState() => _AdminGoogleMapsScreenState();
}

class _AdminGoogleMapsScreenState extends State<AdminGoogleMapsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Koordinatları olan durakları filtrele
    final stopsWithCoordinates = widget.route.stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    // Marker'ları oluştur
    for (int i = 0; i < stopsWithCoordinates.length; i++) {
      final stop = stopsWithCoordinates[i];
      final position = LatLng(stop.latitude!, stop.longitude!);

      // Durum rengini belirle
      Color markerColor;
      switch (stop.status) {
        case StopStatus.pending:
          markerColor = Colors.orange;
          break;
        case StopStatus.assigned:
          markerColor = Colors.blue;
          break;
        case StopStatus.inProgress:
          markerColor = Colors.purple;
          break;
        case StopStatus.completed:
          markerColor = Colors.green;
          break;
        case StopStatus.cancelled:
          markerColor = Colors.red;
          break;
      }

      markers.add(
        Marker(
          markerId: MarkerId(stop.id),
          position: position,
          infoWindow: InfoWindow(
            title: stop.customerName,
            snippet: '${stop.address}\nDurum: ${_getStatusText(stop.status)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(markerColor),
          ),
        ),
      );
    }

    // Polyline oluştur (waypoint'ler arası bağlantı)
    if (stopsWithCoordinates.length > 1) {
      final points = stopsWithCoordinates
          .map((stop) => LatLng(stop.latitude!, stop.longitude!))
          .toList();

      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  double _getMarkerHue(Color color) {
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    return BitmapDescriptor.hueBlue;
  }

  String _getStatusText(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return 'Beklemede';
      case StopStatus.assigned:
        return 'Atandı';
      case StopStatus.inProgress:
        return 'Yolda';
      case StopStatus.completed:
        return 'Tamamlandı';
      case StopStatus.cancelled:
        return 'İptal';
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Tüm marker'ları gösterecek şekilde kamera konumunu ayarla
    if (_markers.isNotEmpty) {
      _fitMarkersInView();
    }
  }

  void _fitMarkersInView() async {
    if (_mapController == null || _markers.isEmpty) return;

    // Tüm marker'ların koordinatlarını al
    final coordinates = _markers.map((marker) => marker.position).toList();

    if (coordinates.isEmpty) return;

    // Sınırları hesapla
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = minLat < coord.latitude ? minLat : coord.latitude;
      maxLat = maxLat > coord.latitude ? maxLat : coord.latitude;
      minLng = minLng < coord.longitude ? minLng : coord.longitude;
      maxLng = maxLng > coord.longitude ? maxLng : coord.longitude;
    }

    // Padding ekle
    const padding = 0.01;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    // Kamera konumunu ayarla
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stopsWithCoordinates = widget.route.stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota Haritası'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _buildMarkers();
              });
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // Rota bilgileri
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.route.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stopsWithCoordinates.length} durak • ${widget.route.totalStops} toplam',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip(
                      'Bekleyen',
                      widget.route.pendingStops,
                      Colors.orange,
                    ),
                    _buildStatusChip(
                      'Atanan',
                      widget.route.assignedStops,
                      Colors.blue,
                    ),
                    _buildStatusChip(
                      'Tamamlanan',
                      widget.route.completedStops,
                      Colors.green,
                    ),
                    _buildStatusChip(
                      'İptal',
                      widget.route.cancelledStops,
                      Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Harita
          Expanded(
            child: stopsWithCoordinates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Koordinatları olan durak bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Durakların koordinatlarını güncelleyin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: stopsWithCoordinates.isNotEmpty
                          ? LatLng(
                              stopsWithCoordinates.first.latitude!,
                              stopsWithCoordinates.first.longitude!,
                            )
                          : const LatLng(
                              39.1178,
                              27.1767,
                            ), // Bergama koordinatları
                      zoom: 12,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
