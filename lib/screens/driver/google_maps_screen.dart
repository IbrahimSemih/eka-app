import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/driver_route_provider.dart';
import '../../models/stop_model.dart';

/// Google Maps entegre ekranı - Rota ve waypoint'leri gösterir
class GoogleMapsScreen extends ConsumerStatefulWidget {
  const GoogleMapsScreen({super.key});

  @override
  ConsumerState<GoogleMapsScreen> createState() => _GoogleMapsScreenState();
}

class _GoogleMapsScreenState extends ConsumerState<GoogleMapsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _center;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      print('🗺️ Harita başlatılıyor...');

      // Varsayılan İstanbul konumu
      _center = const LatLng(41.0082, 28.9784);

      final stops = ref.read(driverOptimizedStopsProvider);
      print('📊 Toplam durak sayısı: ${stops.length}');

      if (stops.isNotEmpty) {
        // Koordinatları olan durakları filtrele
        final stopsWithCoordinates = stops
            .where((stop) => stop.latitude != null && stop.longitude != null)
            .toList();

        print('📍 Koordinatlı durak sayısı: ${stopsWithCoordinates.length}');

        if (stopsWithCoordinates.isNotEmpty) {
          // Harita merkezini hesapla
          double totalLat = 0;
          double totalLng = 0;
          for (final stop in stopsWithCoordinates) {
            totalLat += stop.latitude!;
            totalLng += stop.longitude!;
          }
          _center = LatLng(
            totalLat / stopsWithCoordinates.length,
            totalLng / stopsWithCoordinates.length,
          );

          print(
            '🎯 Harita merkezi: ${_center!.latitude}, ${_center!.longitude}',
          );

          // Marker'ları oluştur
          _createMarkers(stopsWithCoordinates);

          // Polyline'ları oluştur
          _createPolylines(stopsWithCoordinates);
        }
      }

      setState(() {
        _isLoading = false;
      });

      print('✅ Harita başlatma tamamlandı');
    } catch (e) {
      print('❌ Harita başlatma hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createMarkers(List<StopModel> stops) {
    final markers = <Marker>{};

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final markerId = MarkerId('stop_${stop.id}');

      markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(stop.latitude!, stop.longitude!),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${stop.customerName}',
            snippet: stop.address,
          ),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _createPolylines(List<StopModel> stops) {
    if (stops.length < 2) return;

    // Durakları sıralı koordinatlara çevir
    final points = stops
        .map((stop) => LatLng(stop.latitude!, stop.longitude!))
        .toList();

    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: Colors.blue,
      width: 4,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );

    setState(() {
      _polylines = {polyline};
    });
  }

  Color _getMarkerColor(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return Colors.orange;
      case StopStatus.assigned:
        return Colors.blue;
      case StopStatus.inProgress:
        return Colors.purple;
      case StopStatus.completed:
        return Colors.green;
      case StopStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return 'Bekliyor';
      case StopStatus.assigned:
        return 'Atandı';
      case StopStatus.inProgress:
        return 'Devam Ediyor';
      case StopStatus.completed:
        return 'Tamamlandı';
      case StopStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = ref.watch(driverOptimizedStopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rota Haritası',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: () {
              _initializeMap();
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Harita yükleniyor...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _center == null
          ? _buildNoDataState()
          : Column(
              children: [
                // Harita
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _center!,
                        zoom: 12,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        print('✅ Google Maps controller oluşturuldu');

                        // Harita yüklendikten sonra marker'ları güncelle
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted) {
                            setState(() {
                              // Marker'ları yeniden oluştur
                            });
                          }
                        });
                      },
                      markers: _markers,
                      polylines: _polylines,
                      mapType: MapType.normal,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      compassEnabled: true,
                      buildingsEnabled: true,
                      trafficEnabled: false,
                      mapToolbarEnabled: false,
                      liteModeEnabled: false,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                    ),
                  ),
                ),

                // Durak listesi
                Expanded(flex: 2, child: _buildStopsList(stops)),
              ],
            ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Harita Verisi Bulunamadı',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Koordinatları olan duraklar bulunamadı.\nLütfen durakların koordinatlarının\ngüncellendiğinden emin olun.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsList(List<StopModel> stops) {
    if (stops.isEmpty) {
      return const Center(
        child: Text(
          'Durak bulunamadı',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.list, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Rota Durakları (${stops.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),

          // Durak listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final statusColor = _getMarkerColor(stop.status);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      stop.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.address,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _getStatusText(stop.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      _focusOnStop(stop);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _focusOnStop(StopModel stop) {
    if (_mapController != null &&
        stop.latitude != null &&
        stop.longitude != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(stop.latitude!, stop.longitude!), 16),
      );
    }
  }
}
