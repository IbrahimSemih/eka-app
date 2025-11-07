import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/google_maps_integration_service.dart';
import '../../widgets/route_polyline_widget.dart';
import '../../models/stop_model.dart';
import '../../utils/api_key_tester.dart';
import 'dart:async';

/// Polyline Demo Ekranı
///
/// Google Maps üzerinde waypointler arasında polyline çizimini gösterir
class PolylineDemoScreen extends StatefulWidget {
  const PolylineDemoScreen({super.key});

  @override
  State<PolylineDemoScreen> createState() => _PolylineDemoScreenState();
}

class _PolylineDemoScreenState extends State<PolylineDemoScreen> {
  late GoogleMapsIntegrationService _mapsService;

  // Demo duraklar
  final List<StopModel> _demoStops = [
    StopModel(
      id: '1',
      customerName: 'Müşteri 1',
      address: 'Kadıköy, İstanbul',
      status: StopStatus.pending,
      orderIndex: 0,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 40.9888,
      longitude: 29.0255,
    ),
    StopModel(
      id: '2',
      customerName: 'Müşteri 2',
      address: 'Beşiktaş, İstanbul',
      status: StopStatus.pending,
      orderIndex: 1,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 41.0430,
      longitude: 29.0076,
    ),
    StopModel(
      id: '3',
      customerName: 'Müşteri 3',
      address: 'Şişli, İstanbul',
      status: StopStatus.pending,
      orderIndex: 2,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 41.0608,
      longitude: 28.9876,
    ),
    StopModel(
      id: '4',
      customerName: 'Müşteri 4',
      address: 'Beyoğlu, İstanbul',
      status: StopStatus.pending,
      orderIndex: 3,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 41.0369,
      longitude: 28.9850,
    ),
  ];

  // Başlangıç noktası (depo)
  final double _startLatitude = 40.9923;
  final double _startLongitude = 29.0244;

  // Harita durumu
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  Map<String, dynamic>? _routeInfo;
  bool _isLoading = false;
  String _errorMessage = '';

  // Harita ayarları
  String _travelMode = 'driving';
  bool _avoidHighways = false;
  bool _avoidTolls = false;

  @override
  void initState() {
    super.initState();
    _mapsService = GoogleMapsIntegrationService();
    _createMarkers();
    _loadRoute();
  }

  /// Harita controller'ını kaydet
  void _onMapCreated(GoogleMapController controller) {
    // Controller kaydedildi
  }

  /// Marker'ları oluştur
  void _createMarkers() {
    final markers = <Marker>{};

    // Başlangıç noktası (depo)
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_startLatitude, _startLongitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Depo',
          snippet: 'Başlangıç noktası',
        ),
      ),
    );

    // Duraklar
    for (int i = 0; i < _demoStops.length; i++) {
      final stop = _demoStops[i];
      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.latitude!, stop.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == _demoStops.length - 1
                ? BitmapDescriptor
                      .hueRed // Son durak kırmızı
                : BitmapDescriptor.hueBlue, // Diğer duraklar mavi
          ),
          infoWindow: InfoWindow(
            title: stop.customerName,
            snippet: '${stop.address}\nSıra: ${i + 1}',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  /// Rotayı yükle
  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final routeData = await _mapsService.getPolylineRoute(
        stops: _demoStops,
        startLatitude: _startLatitude,
        startLongitude: _startLongitude,
        travelMode: _travelMode,
        avoidHighways: _avoidHighways,
        avoidTolls: _avoidTolls,
      );

      if (routeData != null) {
        _createPolylines(routeData);
        setState(() {
          _routeInfo = routeData;
        });
      } else {
        setState(() {
          _errorMessage =
              'Rota yüklenemedi. API anahtarı yetkilendirme hatası olabilir.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Polyline'ları oluştur
  void _createPolylines(Map<String, dynamic> routeData) {
    final polylines = <Polyline>{};

    // Ana polyline
    final polylinePoints = routeData['polylinePoints'];
    if (polylinePoints != null && polylinePoints.isNotEmpty) {
      List<LatLng> points;

      // PointLatLng tipini kontrol et
      if (polylinePoints is List) {
        points = polylinePoints
            .map((point) {
              if (point.latitude != null && point.longitude != null) {
                return LatLng(
                  point.latitude as double,
                  point.longitude as double,
                );
              } else {
                return LatLng(0.0, 0.0);
              }
            })
            .where((point) => point.latitude != 0.0)
            .toList();
      } else {
        points = [];
      }

      if (points.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('main_route'),
            points: points,
            color: Colors.blue,
            width: 5,
            patterns: [],
            jointType: JointType.round,
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
          ),
        );
      }
    }

    setState(() {
      _polylines = polylines;
    });
  }

  /// Rotayı yenile
  void _refreshRoute() {
    _loadRoute();
  }

  /// Polyline'ları temizle
  void _clearPolylines() {
    setState(() {
      _polylines.clear();
      _routeInfo = null;
    });
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${result['status']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(result['message']),
              if (!result['success']) ...[
                const SizedBox(height: 16),
                const Text(
                  '💡 Çözüm:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1. Google Cloud Console\'a gidin\n'
                  '2. API restrictions: "Don\'t restrict key"\n'
                  '3. Application restrictions: "None"\n'
                  '4. 2-5 dakika bekleyin',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
            if (result['success'])
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadRoute();
                },
                child: const Text('Rotayı Yükle'),
              ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polyline Demo'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _testApiKey,
            icon: const Icon(Icons.science),
            tooltip: 'API Test',
          ),
          IconButton(onPressed: _refreshRoute, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _travelMode = value;
              });
              _loadRoute();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'driving', child: Text('Araç')),
              const PopupMenuItem(value: 'walking', child: Text('Yürüyüş')),
              const PopupMenuItem(value: 'bicycling', child: Text('Bisiklet')),
              const PopupMenuItem(
                value: 'transit',
                child: Text('Toplu Taşıma'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Kontrol paneli
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Seyahat Modu: $_travelMode')),
                    Switch(
                      value: _avoidHighways,
                      onChanged: (value) {
                        setState(() {
                          _avoidHighways = value;
                        });
                        _loadRoute();
                      },
                    ),
                    const Text('Otoyol Yok'),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ücretli Yol Yok: ${_avoidTolls ? 'Evet' : 'Hayır'}',
                      ),
                    ),
                    Switch(
                      value: _avoidTolls,
                      onChanged: (value) {
                        setState(() {
                          _avoidTolls = value;
                        });
                        _loadRoute();
                      },
                    ),
                    const Text('Ücretli Yol Yok'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _refreshRoute,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Rotayı Yenile'),
                    ),
                    ElevatedButton(
                      onPressed: _clearPolylines,
                      child: const Text('Polyline Temizle'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Hata mesajı
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Çözüm: Google Cloud Console\'da API anahtarınızı kontrol edin',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // Rota bilgileri
          if (_routeInfo != null)
            RouteInfoWidget(routeInfo: _routeInfo, onRefresh: _refreshRoute),

          // Harita
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(_startLatitude, _startLongitude),
                zoom: 12,
              ),
              polylines: _polylines,
              markers: _markers,
              onTap: (position) {
                // Harita tıklama işlemleri
              },
            ),
          ),
        ],
      ),
    );
  }
}
