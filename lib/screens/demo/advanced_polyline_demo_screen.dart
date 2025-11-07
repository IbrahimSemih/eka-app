import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/google_maps_integration_service.dart';
import '../../models/stop_model.dart';
import '../../utils/polyline_helper.dart';
import '../../utils/api_key_tester.dart';

/// Gelişmiş Polyline Demo Ekranı
///
/// Animasyonlu polyline, segment bazlı renklendirme ve diğer gelişmiş özellikler
class AdvancedPolylineDemoScreen extends StatefulWidget {
  const AdvancedPolylineDemoScreen({super.key});

  @override
  State<AdvancedPolylineDemoScreen> createState() =>
      _AdvancedPolylineDemoScreenState();
}

class _AdvancedPolylineDemoScreenState extends State<AdvancedPolylineDemoScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapsIntegrationService _mapsService;
  GoogleMapController? _mapController;

  // Animasyon
  late AnimationController _animationController;
  bool _isAnimating = false;

  // Demo duraklar (İstanbul)
  final List<StopModel> _demoStops = [
    StopModel(
      id: '1',
      customerName: 'Kadıköy Moda',
      address: 'Moda, Kadıköy, İstanbul',
      status: StopStatus.pending,
      orderIndex: 0,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 40.9888,
      longitude: 29.0255,
    ),
    StopModel(
      id: '2',
      customerName: 'Beşiktaş İskele',
      address: 'Beşiktaş İskele, İstanbul',
      status: StopStatus.pending,
      orderIndex: 1,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 41.0430,
      longitude: 29.0076,
    ),
    StopModel(
      id: '3',
      customerName: 'Maslak',
      address: 'Maslak, Sarıyer, İstanbul',
      status: StopStatus.pending,
      orderIndex: 2,
      createdAt: DateTime.now(),
      createdBy: 'demo',
      latitude: 41.1086,
      longitude: 29.0216,
    ),
  ];

  final double _startLatitude = 40.9923;
  final double _startLongitude = 29.0244;

  // Harita durumu
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<LatLng> _allPolylinePoints = [];
  Map<String, dynamic>? _routeInfo;
  bool _isLoading = false;
  String _errorMessage = '';

  // Özellik ayarları
  bool _showSegments = false;
  bool _simplifyPoints = false;
  String _travelMode = 'driving';

  @override
  void initState() {
    super.initState();
    _mapsService = GoogleMapsIntegrationService();

    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _animationController.addListener(() {
      if (_isAnimating && _allPolylinePoints.isNotEmpty) {
        _updateAnimatedPolyline();
      }
    });

    _createMarkers();
    _loadRoute();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Marker'ları oluştur
  void _createMarkers() {
    final markers = <Marker>{};

    // Başlangıç noktası
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_startLatitude, _startLongitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: '🏁 Başlangıç',
          snippet: 'Depo/Ofis',
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
          icon: PolylineHelper.getMarkerColor(i + 1, _demoStops.length + 1),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${stop.customerName}',
            snippet: stop.address,
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
      _isAnimating = false;
    });

    _animationController.reset();

    try {
      final routeData = await _mapsService.getPolylineRoute(
        stops: _demoStops,
        startLatitude: _startLatitude,
        startLongitude: _startLongitude,
        travelMode: _travelMode,
      );

      if (routeData != null) {
        final polylinePoints = routeData['polylinePoints'];

        if (polylinePoints != null) {
          final points = PolylineHelper.pointsToLatLng(polylinePoints);

          // Basitleştirme varsa uygula
          final finalPoints = _simplifyPoints
              ? PolylineHelper.simplifyPoints(points, 0.0001)
              : points;

          setState(() {
            _allPolylinePoints = finalPoints;
            _routeInfo = routeData;
          });

          _createPolylines(finalPoints);

          // Haritayı rotaya göre ayarla
          if (_mapController != null && finalPoints.isNotEmpty) {
            await PolylineHelper.fitBounds(_mapController!, finalPoints);
          }
        }
      } else {
        setState(() {
          _errorMessage =
              'Rota yüklenemedi. API anahtarı veya bağlantı hatası olabilir.';
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
  void _createPolylines(List<LatLng> points) {
    final polylines = <Polyline>{};

    if (_showSegments) {
      // Segment bazlı polyline (her iki durak arası farklı renk)
      final segments = _createSegments(points);
      polylines.addAll(PolylineHelper.createSegmentedPolylines(segments));
    } else {
      // Tek bir polyline
      polylines.add(
        Polyline(
          polylineId: const PolylineId('main_route'),
          points: points,
          color: Colors.blue,
          width: 6,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    setState(() {
      _polylines = polylines;
    });
  }

  /// Segment'leri oluştur
  List<List<LatLng>> _createSegments(List<LatLng> allPoints) {
    final segments = <List<LatLng>>[];

    if (allPoints.isEmpty || _demoStops.isEmpty) return segments;

    // Her durak çifti için segment oluştur
    int currentIndex = 0;
    final stopPositions = [
      LatLng(_startLatitude, _startLongitude),
      ..._demoStops.map((s) => LatLng(s.latitude!, s.longitude!)),
    ];

    for (int i = 0; i < stopPositions.length - 1; i++) {
      final segmentPoints = <LatLng>[];
      final targetPosition = stopPositions[i + 1];

      // Hedef pozisyona en yakın polyline noktasını bul
      while (currentIndex < allPoints.length) {
        segmentPoints.add(allPoints[currentIndex]);

        final distance = PolylineHelper.calculateDistance(
          allPoints[currentIndex],
          targetPosition,
        );

        if (distance < 100 || currentIndex == allPoints.length - 1) {
          // 100m yakınlık veya son nokta
          currentIndex++;
          break;
        }

        currentIndex++;
      }

      if (segmentPoints.isNotEmpty) {
        segments.add(segmentPoints);
      }
    }

    return segments;
  }

  /// Animasyonu başlat/durdur
  void _toggleAnimation() {
    if (_isAnimating) {
      _animationController.stop();
      setState(() {
        _isAnimating = false;
      });
      _createPolylines(_allPolylinePoints);
    } else {
      _animationController.reset();
      _animationController.forward();
      setState(() {
        _isAnimating = true;
      });
    }
  }

  /// Animasyonlu polyline'ı güncelle
  void _updateAnimatedPolyline() {
    final progress = _animationController.value;
    final animatedPoints = PolylineHelper.getAnimatedPoints(
      _allPolylinePoints,
      progress,
    );

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('animated_route'),
          points: animatedPoints,
          color: Colors.blue,
          width: 6,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      };
    });

    // Animasyon tamamlandıysa durdur
    if (progress >= 1.0) {
      setState(() {
        _isAnimating = false;
      });
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

  /// Polyline bilgilerini göster
  void _showPolylineInfo() {
    if (_allPolylinePoints.isEmpty) return;

    final info = PolylineHelper.getPolylineInfo(_allPolylinePoints);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Polyline Bilgileri'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info),
              if (_routeInfo != null) ...[
                const Divider(),
                Text('📏 Toplam Mesafe: ${_routeInfo!['totalDistanceKm']} km'),
                Text('⏱️ Tahmini Süre: ${_routeInfo!['formattedDuration']}'),
                Text('🗺️ Seyahat Modu: $_travelMode'),
                if (_simplifyPoints)
                  const Text('🔧 Nokta basitleştirme: Aktif'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişmiş Polyline Demo'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _testApiKey,
            icon: const Icon(Icons.science),
            tooltip: 'API Test',
          ),
          IconButton(
            onPressed: _loadRoute,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rotayı Yenile',
          ),
          IconButton(
            onPressed: _showPolylineInfo,
            icon: const Icon(Icons.info),
            tooltip: 'Polyline Bilgileri',
          ),
        ],
      ),
      body: Column(
        children: [
          // Kontrol Paneli
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Özellik anahtarları
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Segment Renkleri'),
                        subtitle: const Text('Her segment ayrı renk'),
                        value: _showSegments,
                        onChanged: (value) {
                          setState(() {
                            _showSegments = value;
                          });
                          if (_allPolylinePoints.isNotEmpty) {
                            _createPolylines(_allPolylinePoints);
                          }
                        },
                        dense: true,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Nokta Basitleştir'),
                        subtitle: const Text('Performans için'),
                        value: _simplifyPoints,
                        onChanged: (value) {
                          setState(() {
                            _simplifyPoints = value;
                          });
                          _loadRoute();
                        },
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Aksiyon butonları
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _toggleAnimation,
                      icon: Icon(_isAnimating ? Icons.stop : Icons.play_arrow),
                      label: Text(_isAnimating ? 'Durdur' : 'Animasyon'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAnimating
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadRoute,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
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
              padding: const EdgeInsets.all(12),
              color: Colors.red[100],
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          // Rota bilgileri
          if (_routeInfo != null && !_isAnimating)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.straighten, color: Colors.blue),
                      const SizedBox(height: 4),
                      Text(
                        '${_routeInfo!['totalDistanceKm']} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Mesafe', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.access_time, color: Colors.orange),
                      const SizedBox(height: 4),
                      Text(
                        _routeInfo!['formattedDuration'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Süre', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.route, color: Colors.green),
                      const SizedBox(height: 4),
                      Text(
                        '${_allPolylinePoints.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Nokta', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

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
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
