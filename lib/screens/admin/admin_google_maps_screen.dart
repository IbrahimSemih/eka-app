import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../services/google_maps_integration_service.dart';
import '../../utils/polyline_helper.dart';
import '../../utils/api_key_tester.dart';

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
  late GoogleMapsIntegrationService _mapsService;
  
  // Rota bilgileri
  Map<String, dynamic>? _routeInfo;
  bool _isLoadingRoute = false;
  bool _useRealRoutes = true; // Gerçek rotalar veya direkt çizgi
  String _errorMessage = '';
  
  // Başlangıç konumu (varsayılan)
  double? _startLatitude;
  double? _startLongitude;

  @override
  void initState() {
    super.initState();
    _mapsService = GoogleMapsIntegrationService();
    _buildMarkers();
    _loadRealRoutes();
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    // Başlangıç noktası marker'ı (eğer belirlenmişse)
    if (_startLatitude != null && _startLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(_startLatitude!, _startLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(
            title: '🏁 Başlangıç',
            snippet: 'Rota başlangıç noktası',
          ),
        ),
      );
    }

    // Koordinatları olan durakları filtrele
    final stopsWithCoordinates = widget.route.stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    // Durak marker'larını oluştur
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
            title: '${i + 1}. ${stop.customerName}',
            snippet: '${stop.address}\nDurum: ${_getStatusText(stop.status)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(markerColor),
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }
  
  /// Gerçek rotaları yükle
  Future<void> _loadRealRoutes() async {
    if (!_useRealRoutes) {
      _buildDirectPolylines();
      return;
    }

    final stopsWithCoordinates = widget.route.stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    if (stopsWithCoordinates.isEmpty) {
      return;
    }

    // Başlangıç noktası yoksa ilk durağı kullan
    if (_startLatitude == null || _startLongitude == null) {
      _startLatitude = stopsWithCoordinates.first.latitude;
      _startLongitude = stopsWithCoordinates.first.longitude;
    }

    setState(() {
      _isLoadingRoute = true;
      _errorMessage = '';
    });

    try {
      final routeData = await _mapsService.getPolylineRoute(
        stops: stopsWithCoordinates,
        startLatitude: _startLatitude!,
        startLongitude: _startLongitude!,
        travelMode: 'driving',
      );

      if (routeData != null) {
        final polylinePoints = routeData['polylinePoints'];
        if (polylinePoints != null) {
          final points = PolylineHelper.pointsToLatLng(polylinePoints);
          
          setState(() {
            _routeInfo = routeData;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('real_route'),
                points: points,
                color: Colors.blue,
                width: 5,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
            };
          });

          // Haritayı rotaya göre ayarla
          if (_mapController != null && points.isNotEmpty) {
            await PolylineHelper.fitBounds(_mapController!, points);
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Rota yüklenemedi. Direkt çizgiler gösteriliyor.';
        });
        _buildDirectPolylines();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hata: $e';
      });
      _buildDirectPolylines();
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }
  
  /// Direkt çizgilerle polyline oluştur (yedek)
  void _buildDirectPolylines() {
    final stopsWithCoordinates = widget.route.stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .toList();

    if (stopsWithCoordinates.length > 1) {
      final points = stopsWithCoordinates
          .map((stop) => LatLng(stop.latitude!, stop.longitude!))
          .toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('direct_route'),
            points: points,
            color: Colors.grey,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      });
    }
  }
  
  /// Başlangıç noktası seçim dialog'u
  Future<void> _selectStartLocation() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StartLocationDialog(
        currentLat: _startLatitude,
        currentLng: _startLongitude,
      ),
    );

    if (result != null) {
      setState(() {
        _startLatitude = result['latitude'];
        _startLongitude = result['longitude'];
      });
      
      _buildMarkers();
      _loadRealRoutes();
    }
  }
  
  /// API anahtarını test et
  Future<void> _testApiKey() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('API anahtarı test ediliyor...'),
          ],
        ),
      ),
    );

    final result = await ApiKeyTester.testDirectionsApi();

    if (mounted) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: result['success'] ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(result['success'] ? 'Test Başarılı' : 'Test Başarısız'),
            ],
          ),
          content: Text(result['message']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
            if (result['success'])
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadRealRoutes();
                },
                child: const Text('Rotayı Yükle'),
              ),
          ],
        ),
      );
    }
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
            icon: const Icon(Icons.science),
            onPressed: _testApiKey,
            tooltip: 'API Test',
          ),
          IconButton(
            icon: const Icon(Icons.place),
            onPressed: _selectStartLocation,
            tooltip: 'Başlangıç Noktası',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _buildMarkers();
              _loadRealRoutes();
            },
            tooltip: 'Yenile',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _useRealRoutes = value == 'real';
              });
              if (_useRealRoutes) {
                _loadRealRoutes();
              } else {
                _buildDirectPolylines();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'real',
                child: Row(
                  children: [
                    Icon(
                      Icons.route,
                      color: _useRealRoutes ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('Gerçek Rotalar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'direct',
                child: Row(
                  children: [
                    Icon(
                      Icons.timeline,
                      color: !_useRealRoutes ? Colors.grey : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('Direkt Çizgiler'),
                  ],
                ),
              ),
            ],
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
                Row(
                  children: [
                    Expanded(
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
                        ],
                      ),
                    ),
                    if (_isLoadingRoute)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
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
                if (_routeInfo != null) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRouteInfoItem(
                        Icons.straighten,
                        '${_routeInfo!['totalDistanceKm']} km',
                        'Mesafe',
                      ),
                      _buildRouteInfoItem(
                        Icons.access_time,
                        _routeInfo!['formattedDuration'],
                        'Süre',
                      ),
                      _buildRouteInfoItem(
                        Icons.route,
                        _useRealRoutes ? 'Gerçek' : 'Direkt',
                        'Rota Tipi',
                      ),
                    ],
                  ),
                ],
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
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

  Widget _buildRouteInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Başlangıç konumu seçim dialog'u
class _StartLocationDialog extends StatefulWidget {
  final double? currentLat;
  final double? currentLng;

  const _StartLocationDialog({this.currentLat, this.currentLng});

  @override
  State<_StartLocationDialog> createState() => _StartLocationDialogState();
}

class _StartLocationDialogState extends State<_StartLocationDialog> {
  int _selectedOption = 0;
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  final List<Map<String, dynamic>> _predefinedLocations = [
    {
      'name': 'İstanbul Merkez',
      'latitude': 41.0082,
      'longitude': 28.9784,
    },
    {
      'name': 'Ankara Merkez',
      'latitude': 39.9334,
      'longitude': 32.8597,
    },
    {
      'name': 'İzmir Merkez',
      'latitude': 38.4192,
      'longitude': 27.1287,
    },
    {
      'name': 'Bursa Merkez',
      'latitude': 40.1826,
      'longitude': 29.0665,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentLat != null && widget.currentLng != null) {
      _latController.text = widget.currentLat!.toStringAsFixed(6);
      _lngController.text = widget.currentLng!.toStringAsFixed(6);
      _selectedOption = _predefinedLocations.length; // Özel konum
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.place, color: Colors.green),
          SizedBox(width: 8),
          Text('Başlangıç Konumu Seç'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rota başlangıç noktasını seçin:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Önceden tanımlı konumlar
            ...List.generate(_predefinedLocations.length, (index) {
              final location = _predefinedLocations[index];
              return RadioListTile<int>(
                value: index,
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value!;
                  });
                },
                title: Text(location['name']),
                subtitle: Text(
                  '${location['latitude']}, ${location['longitude']}',
                  style: const TextStyle(fontSize: 11),
                ),
                dense: true,
              );
            }),

            // Özel konum seçeneği
            RadioListTile<int>(
              value: _predefinedLocations.length,
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value!;
                });
              },
              title: const Text('Özel Konum'),
              subtitle: const Text('Koordinat girin'),
              dense: true,
            ),

            // Koordinat girişi
            if (_selectedOption == _predefinedLocations.length) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Enlem (Latitude)',
                  hintText: '41.0082',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Boylam (Longitude)',
                  hintText: '28.9784',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Seç'),
        ),
      ],
    );
  }

  void _handleConfirm() {
    if (_selectedOption < _predefinedLocations.length) {
      // Önceden tanımlı konum seçildi
      final location = _predefinedLocations[_selectedOption];
      Navigator.pop(context, {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'name': location['name'],
      });
    } else {
      // Özel konum seçildi
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);

      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli koordinatlar girin'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.pop(context, {
        'latitude': lat,
        'longitude': lng,
        'name': 'Özel Konum',
      });
    }
  }
}
