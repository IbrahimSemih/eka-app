import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../providers/stops_provider.dart';
import '../../providers/drivers_provider.dart';
import '../../widgets/stop_card.dart';
import '../../widgets/driver_assignment_modal.dart';
import '../../services/geocoding_service.dart';
import 'add_stop_screen.dart';
import 'admin_google_maps_screen.dart';

/// Ana rota görüntüleme ekranı - Gerçek zamanlı güncelleme ile
class RouteViewScreen extends ConsumerWidget {
  const RouteViewScreen({super.key});

  // Önceden tanımlı konumlar
  static const List<Map<String, dynamic>> _predefinedLocations = [
    {'name': 'İstanbul Merkez', 'latitude': 41.0082, 'longitude': 28.9784},
    {'name': 'Ankara Merkez', 'latitude': 39.9334, 'longitude': 32.8597},
    {'name': 'İzmir Merkez', 'latitude': 38.4192, 'longitude': 27.1287},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gerçek zamanlı rota verisi
    final routeAsync = ref.watch(mainRouteStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Rota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(mainRouteStreamProvider);
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: routeAsync.when(
        data: (route) {
          if (route == null || route.stops.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Rota istatistikleri
              _buildRouteStatistics(context, route),

              // Duraklar listesi
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(mainRouteStreamProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: route.stops.length,
                    itemBuilder: (context, index) {
                      final stop = route.stops[index];
                      return StopCard(
                        stop: stop,
                        route: route,
                        displayIndex: index,
                        onTap: () =>
                            _showStopDetails(context, ref, stop, route),
                        onMenuTap: () {
                          print(
                            '🎯 StopCard onMenuTap çağrıldı: ${stop.customerName}',
                          );
                          print('🚀 _showStopMenu çağrılıyor...');
                          _showStopMenu(context, ref, stop, route);
                          print('🏁 _showStopMenu çağrısı tamamlandı');
                        },
                        onAssignDriver: () => _showStopDriverAssignmentDialog(
                          context,
                          ref,
                          stop,
                          route,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rota yükleniyor...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Bir hata oluştu',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(mainRouteStreamProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStopScreen()),
          );
        },
        icon: const Icon(Icons.add_location),
        label: const Text('Durak Ekle'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Henüz durak eklenmemiş',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ana rotaya ilk durağı ekleyerek başlayın',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStopScreen()),
                );
              },
              icon: const Icon(Icons.add_location, size: 24),
              label: const Text('İlk Durağı Ekle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStatistics(BuildContext context, RouteModel route) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (route.assignedDriverName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sürücü: ${route.assignedDriverName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${route.totalStops} Durak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  'Bekleyen',
                  '${route.pendingStops}',
                  Icons.pending_outlined,
                  Colors.orange[300]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Yolda',
                  '${route.inProgressStops}',
                  Icons.local_shipping_outlined,
                  Colors.lightBlue[300]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  'Tamamlanan',
                  '${route.completedStops}',
                  Icons.check_circle,
                  Colors.green[300]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Harita butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openInAppGoogleMaps(context, route),
              icon: const Icon(Icons.map, size: 20),
              label: const Text('Haritada Göster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showStopDetails(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
    RouteModel route,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Durak Detayları',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Müşteri', stop.customerName, Icons.person),
              const Divider(),
              _buildDetailRow('Adres', stop.address, Icons.location_on),
              const Divider(),
              _buildDetailRow('Durum', stop.statusText, Icons.info),
              if (stop.latitude != null && stop.longitude != null) ...[
                const Divider(),
                _buildDetailRow(
                  'Koordinatlar',
                  '${stop.latitude!.toStringAsFixed(6)}, ${stop.longitude!.toStringAsFixed(6)}',
                  Icons.gps_fixed,
                ),
                const Divider(),
                _buildCoordinateActions(context, stop, route),
              ],
              if (stop.driverName != null) ...[
                const Divider(),
                _buildDetailRow(
                  'Sürücü',
                  stop.driverName!,
                  Icons.local_shipping,
                ),
              ],
              if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                const Divider(),
                _buildDetailRow('Notlar', stop.notes!, Icons.note),
              ],
              const Divider(),
              _buildDetailRow(
                'Oluşturma',
                _formatDate(stop.createdAt),
                Icons.calendar_today,
              ),
              if (stop.completedAt != null) ...[
                const Divider(),
                _buildDetailRow(
                  'Tamamlanma',
                  _formatDate(stop.completedAt!),
                  Icons.check_circle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Koordinat aksiyonları widget'ı
  Widget _buildCoordinateActions(
    BuildContext context,
    StopModel stop,
    RouteModel route,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.navigation, size: 24, color: Colors.grey[600]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigasyon',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu durağa navigasyon başlat',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openInAppGoogleMaps(context, route),
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Haritada Göster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uygulama içi Google Maps'i açar
  void _openInAppGoogleMaps(BuildContext context, RouteModel route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminGoogleMapsScreen(route: route),
      ),
    );
  }

  void _showStopMenu(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
    RouteModel route,
  ) {
    print('📋 Durak menüsü açılıyor: ${stop.customerName}');

    try {
      print('🔄 showModalBottomSheet çağrılıyor...');
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          print('🏗️ Bottom sheet builder çağrıldı');
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Detayları Görüntüle'),
                  onTap: () {
                    print('ℹ️ Detaylar seçildi');
                    Navigator.pop(context);
                    _showStopDetails(context, ref, stop, route);
                  },
                ),
                if (stop.status == StopStatus.pending)
                  ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('Teslim Edildi Olarak İşaretle'),
                    onTap: () {
                      print('✅ Teslim edildi seçildi');
                      Navigator.pop(context);
                      _markAsCompleted(context, ref, stop);
                    },
                  ),
                if (stop.status != StopStatus.completed &&
                    stop.status != StopStatus.cancelled)
                  ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.orange),
                    title: const Text('İptal Et'),
                    onTap: () {
                      print('❌ İptal et seçildi');
                      Navigator.pop(context);
                      _cancelStop(context, ref, stop);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Sil'),
                  onTap: () {
                    print('🗑️ Sil seçildi');
                    Navigator.pop(context);
                    _deleteStop(context, ref, stop);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      print('✅ showModalBottomSheet başarıyla çağrıldı');
    } catch (e) {
      print('❌ showModalBottomSheet hatası: $e');
    }
  }

  Future<void> _markAsCompleted(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teslim Edildi İşaretle'),
        content: Text(
          '${stop.customerName} durağını teslim edildi olarak işaretlemek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Evet, İşaretle'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(stopsNotifierProvider.notifier)
            .updateStopStatus(stop.id, StopStatus.completed);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Durak teslim edildi olarak işaretlendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelStop(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Durağı İptal Et'),
        content: Text(
          '${stop.customerName} durağını iptal etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(stopsNotifierProvider.notifier)
            .updateStopStatus(stop.id, StopStatus.cancelled);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Durak iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteStop(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    print('🗑️ Silme dialogu açılıyor: ${stop.customerName}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Durağı Sil'),
        content: Text(
          '${stop.customerName} durağını kalıcı olarak silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ Silme işlemi iptal edildi');
              Navigator.pop(context, false);
            },
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              print('✅ Silme işlemi onaylandı');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    print('🔍 Onay sonucu: $confirmed');
    print('🔍 Context mounted mu? ${context.mounted}');

    if (confirmed == true) {
      print('🚀 Silme işlemi başlatılıyor...');
      try {
        await ref.read(stopsNotifierProvider.notifier).deleteStop(stop.id);

        // Context kontrolü yapmadan önce güvenli kontrol et
        try {
          if (context.mounted) {
            print('✅ Silme işlemi başarılı, mesaj gösteriliyor');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Durak silindi'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            print('⚠️ Context mount değil, mesaj gösterilemiyor');
          }
        } catch (e) {
          print('⚠️ Context kontrolü hatası: $e');
        }
      } catch (e) {
        print('❌ Silme işlemi hatası: $e');
        try {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hata: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (contextError) {
          print('⚠️ Context kontrolü hatası: $contextError');
        }
      }
    } else {
      print('⚠️ Silme işlemi iptal edildi');
    }
  }

  Future<void> _showDriverAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final routeAsync = ref.read(mainRouteStreamProvider);

    routeAsync.whenData((route) {
      if (route == null || route.stops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce rotaya durak ekleyin'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => DriverAssignmentModal(
          route: route,
          onAssign: (driverId, driverName) async {
            await _assignRouteToDriver(
              context,
              ref,
              route,
              driverId,
              driverName,
            );
          },
        ),
      );
    });
  }

  // Durak için sürücü atama dialog'u
  Future<void> _showStopDriverAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
    RouteModel route,
  ) async {
    showDialog(
      context: context,
      builder: (context) => _StopDriverAssignmentModal(
        stop: stop,
        route: route,
        onAssign: (driverId, driverName) async {
          try {
            // Durak için sürücü atama işlemini gerçekleştir
            await ref
                .read(stopsNotifierProvider.notifier)
                .assignStopToDriver(
                  stopId: stop.id,
                  driverId: driverId,
                  driverName: driverName,
                );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ ${stop.customerName} durağı ${driverName} sürücüsüne atandı!',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Atama hatası: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _assignRouteToDriver(
    BuildContext context,
    WidgetRef ref,
    RouteModel route,
    String driverId,
    String driverName,
  ) async {
    try {
      // Rota atama işlemini gerçekleştir
      await ref
          .read(stopsNotifierProvider.notifier)
          .assignRouteToDriver(
            routeId: route.id,
            driverId: driverId,
            driverName: driverName,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Atama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _showOptimizationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StartLocationDialog(),
    );

    if (result != null && context.mounted) {
      await _optimizeRoute(
        context,
        ref,
        startLatitude: result['latitude'],
        startLongitude: result['longitude'],
        startLocationName: result['name'],
      );
    }
  }

  Future<void> _optimizeRoute(
    BuildContext context,
    WidgetRef ref, {
    required double? startLatitude,
    required double? startLongitude,
    required String? startLocationName,
  }) async {
    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              'Rota optimize ediliyor...\nBaşlangıç: ${startLocationName ?? "Belirtilmemiş"}',
            ),
          ],
        ),
      ),
    );

    try {
      await ref
          .read(stopsNotifierProvider.notifier)
          .optimizeRoute(
            startLatitude: startLatitude,
            startLongitude: startLongitude,
          );

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Rota başarıyla optimize edildi!\nBaşlangıç: ${startLocationName ?? "Belirtilmemiş"}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Optimizasyon hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAllCoordinates(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_searching, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Koordinat Güncelleme'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tüm durakların adresleri koordinatlara dönüştürülecek.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'ℹ️ Bilgi:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            SizedBox(height: 8),
            Text('• İnternet bağlantısı gereklidir'),
            Text('• İşlem biraz zaman alabilir'),
            Text('• Koordinatları olan duraklar atlanacak'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _performCoordinateUpdate(context, ref);
    }
  }

  Future<void> _performCoordinateUpdate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Koordinatlar güncelleniyor...'),
          ],
        ),
      ),
    );

    try {
      await ref.read(stopsNotifierProvider.notifier).updateAllStopCoordinates();

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Koordinatlar başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Koordinat güncelleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Google Maps için optimize edilmiş rota URL'si oluşturur
  String _buildGoogleMapsRouteUrl(List<StopModel> stops) {
    if (stops.isEmpty) return '';

    // Durakları orderIndex'e göre sırala (optimize edilmiş sıralama)
    final sortedStops = List<StopModel>.from(stops);
    sortedStops.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    if (sortedStops.length == 1) {
      // Sadece bir durak varsa
      final stop = sortedStops.first;
      return 'https://maps.google.com/maps?daddr=${stop.latitude},${stop.longitude}&dirflg=d';
    }

    // Tüm durakları waypoints olarak ekle
    final allWaypoints = sortedStops
        .map((stop) => '${stop.latitude},${stop.longitude}')
        .join('|');

    return 'https://maps.google.com/maps?waypoints=$allWaypoints&dirflg=d';
  }

  /// Başlangıç konumu seçimi için modal gösterir
  Future<void> _selectStartLocation(
    BuildContext context,
    List<StopModel> stops,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.my_location, color: Colors.blue),
            SizedBox(width: 8),
            Text('Başlangıç Konumu Seç'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rota optimizasyonu için başlangıç konumunu seçin:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Mevcut konum seçeneği
              Card(
                child: ListTile(
                  leading: const Icon(Icons.gps_fixed, color: Colors.green),
                  title: const Text('Mevcut Konumum'),
                  subtitle: const Text('GPS ile otomatik tespit'),
                  onTap: () => Navigator.pop(context, {
                    'type': 'current',
                    'name': 'Mevcut Konumum',
                  }),
                ),
              ),

              // Önceden tanımlı konumlar
              ..._predefinedLocations.map(
                (location) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_city,
                      color: Colors.blue,
                    ),
                    title: Text(location['name']),
                    subtitle: Text(
                      '${location['latitude']}, ${location['longitude']}',
                    ),
                    onTap: () => Navigator.pop(context, {
                      'type': 'predefined',
                      'name': location['name'],
                      'latitude': location['latitude'],
                      'longitude': location['longitude'],
                    }),
                  ),
                ),
              ),

              // Özel adres seçeneği
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.edit_location,
                    color: Colors.orange,
                  ),
                  title: const Text('Özel Adres'),
                  subtitle: const Text('Manuel adres girişi'),
                  onTap: () => Navigator.pop(context, {
                    'type': 'custom',
                    'name': 'Özel Adres',
                  }),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _handleStartLocationSelection(context, result, stops);
    }
  }

  /// Başlangıç konumu seçimini işler
  Future<void> _handleStartLocationSelection(
    BuildContext context,
    Map<String, dynamic> selection,
    List<StopModel> stops,
  ) async {
    String? startLat;
    String? startLon;
    String startName = selection['name'];

    switch (selection['type']) {
      case 'current':
        // Mevcut konumu al
        try {
          final geocodingService = GeocodingService();
          final currentLocation = await geocodingService.getCurrentLocation();
          if (currentLocation != null) {
            startLat = currentLocation.latitude.toString();
            startLon = currentLocation.longitude.toString();
          } else {
            throw Exception('Mevcut konum alınamadı');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Konum alınamadı: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        break;

      case 'predefined':
        startLat = selection['latitude'].toString();
        startLon = selection['longitude'].toString();
        break;

      case 'custom':
        // Özel adres girişi için modal göster
        final customResult = await _showCustomAddressDialog(context);
        if (customResult != null) {
          startLat = customResult['latitude'].toString();
          startLon = customResult['longitude'].toString();
          startName = customResult['name'];
        } else {
          return;
        }
        break;
    }

    if (startLat != null && startLon != null) {
      // Navigasyon seçeneklerini göster
      await _showNavigationOptions(
        context,
        stops,
        startLat,
        startLon,
        startName,
      );
    }
  }

  /// Özel adres girişi için dialog gösterir
  Future<Map<String, dynamic>?> _showCustomAddressDialog(
    BuildContext context,
  ) async {
    final addressController = TextEditingController();
    bool isLoading = false;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Özel Adres Gir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  hintText: 'Örn: İstanbul, Beşiktaş, Levent Mahallesi...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Adres işleniyor...'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (addressController.text.trim().isEmpty) return;

                      setState(() => isLoading = true);

                      try {
                        final geocodingService = GeocodingService();
                        final coordinates = await geocodingService
                            .addressToCoordinates(
                              addressController.text.trim(),
                            );

                        if (coordinates != null) {
                          Navigator.pop(context, {
                            'latitude': coordinates.latitude,
                            'longitude': coordinates.longitude,
                            'name': addressController.text.trim(),
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Adres bulunamadı'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigasyon seçeneklerini gösterir
  Future<void> _showNavigationOptions(
    BuildContext context,
    List<StopModel> stops,
    String startLat,
    String startLon,
    String startName,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Navigasyon Seçenekleri'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Başlangıç: $startName\n($startLat, $startLon)',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Google Maps
            Card(
              child: ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text('Google Maps'),
                subtitle: const Text('Tüm durakları göster'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.pop(context);
                  final url = _buildGoogleMapsRouteUrlWithStart(
                    stops,
                    startLat,
                    startLon,
                  );
                  await _launchNavigationUrl(url, 'Google Maps');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  /// Başlangıç konumu ile Google Maps URL'si oluşturur
  String _buildGoogleMapsRouteUrlWithStart(
    List<StopModel> stops,
    String startLat,
    String startLon,
  ) {
    if (stops.isEmpty) return '';

    // Durakları orderIndex'e göre sırala (optimize edilmiş sıralama)
    final sortedStops = List<StopModel>.from(stops);
    sortedStops.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    if (sortedStops.length == 1) {
      // Sadece bir durak varsa
      final stop = sortedStops.first;
      return 'https://maps.google.com/maps?saddr=$startLat,$startLon&daddr=${stop.latitude},${stop.longitude}&dirflg=d';
    }

    // Google Maps için tüm durakları waypoints olarak ekle
    // Son durak da waypoints'e dahil edilmeli
    final allWaypoints = sortedStops
        .map((stop) => '${stop.latitude},${stop.longitude}')
        .join('|');

    // Başlangıç konumunu da waypoints'e ekle
    final waypointsWithStart = '$startLat,$startLon|$allWaypoints';

    return 'https://maps.google.com/maps?waypoints=$waypointsWithStart&dirflg=d';
  }

  /// Navigasyon URL'sini açar
  Future<void> _launchNavigationUrl(String url, String appName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ $appName açıldı: $url');
      } else {
        print('❌ $appName açılamadı');
      }
    } catch (e) {
      print('❌ $appName açılırken hata: $e');
    }
  }
}

/// Başlangıç konumu seçim dialog'u
class _StartLocationDialog extends StatefulWidget {
  @override
  _StartLocationDialogState createState() => _StartLocationDialogState();
}

class _StartLocationDialogState extends State<_StartLocationDialog> {
  int _selectedOption = 0;
  final TextEditingController _addressController = TextEditingController();
  bool _isLoadingLocation = false;

  // Önceden tanımlı başlangıç konumları
  final List<Map<String, dynamic>> _predefinedLocations = [
    {
      'name': 'Depo/Ofis',
      'address': 'İstanbul, Türkiye',
      'latitude': 41.0082,
      'longitude': 28.9784,
    },
    {
      'name': 'Merkez Depo',
      'address': 'Ankara, Türkiye',
      'latitude': 39.9334,
      'longitude': 32.8597,
    },
    {
      'name': 'İzmir Şube',
      'address': 'İzmir, Türkiye',
      'latitude': 38.4192,
      'longitude': 27.1287,
    },
  ];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.route, color: Colors.teal),
          SizedBox(width: 8),
          Text('Başlangıç Konumu Seç'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rota optimizasyonu için başlangıç konumunu seçin:',
            style: TextStyle(fontSize: 16),
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
              subtitle: Text(location['address']),
              dense: true,
            );
          }),

          // Özel adres seçeneği
          RadioListTile<int>(
            value: _predefinedLocations.length,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
            title: const Text('Özel Adres'),
            subtitle: const Text('Adres girin'),
            dense: true,
          ),

          // Adres girişi
          if (_selectedOption == _predefinedLocations.length) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adres',
                hintText: 'Örn: Atatürk Cad. No:123 Kadıköy/İstanbul',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            '⚠️ Dikkat:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          const Text('• Koordinatları olmayan duraklar sona eklenecek'),
          const Text('• Mevcut sıralama değişecek'),
          const Text('• İşlem geri alınamaz'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoadingLocation ? null : _handleOptimize,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: _isLoadingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Optimize Et'),
        ),
      ],
    );
  }

  Future<void> _handleOptimize() async {
    if (_selectedOption < _predefinedLocations.length) {
      // Önceden tanımlı konum seçildi
      final location = _predefinedLocations[_selectedOption];
      Navigator.pop(context, {
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'name': location['name'],
      });
    } else {
      // Özel adres seçildi
      if (_addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen bir adres girin'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoadingLocation = true;
      });

      try {
        // Geocoding servisi ile adresi koordinatlara dönüştür
        final geocodingService = GeocodingService();
        final coordinates = await geocodingService.addressToCoordinates(
          _addressController.text.trim(),
        );

        if (coordinates != null) {
          Navigator.pop(context, {
            'latitude': coordinates.latitude,
            'longitude': coordinates.longitude,
            'name': _addressController.text.trim(),
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Adres bulunamadı. Lütfen farklı bir adres deneyin.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adres dönüştürme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
}

/// Durak için sürücü atama modal'ı
class _StopDriverAssignmentModal extends ConsumerStatefulWidget {
  final StopModel stop;
  final RouteModel route;
  final Function(String driverId, String driverName) onAssign;

  const _StopDriverAssignmentModal({
    required this.stop,
    required this.route,
    required this.onAssign,
  });

  @override
  ConsumerState<_StopDriverAssignmentModal> createState() =>
      _StopDriverAssignmentModalState();
}

class _StopDriverAssignmentModalState
    extends ConsumerState<_StopDriverAssignmentModal> {
  String? _selectedDriverId;
  String? _selectedDriverName;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    // Sürücüleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driversNotifierProvider.notifier).loadDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversStreamProvider);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[600],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Durak Sürücü Ata',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Durak bilgisi
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.purple[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Durak: ${widget.stop.customerName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.stop.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.stop.driverName != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  color: Colors.orange[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mevcut Sürücü: ${widget.stop.driverName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sürücü seçimi
                    const Text(
                      'Sürücü Seçin:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    driversAsync.when(
                      data: (drivers) {
                        if (drivers.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Henüz kayıtlı sürücü bulunmuyor.\nLütfen önce sürücü ekleyin.',
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: drivers.map((driver) {
                            final isSelected = _selectedDriverId == driver.uid;
                            final isCurrentlyAssigned =
                                widget.stop.driverId == driver.uid;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 4 : 1,
                              color: isSelected
                                  ? Colors.purple[100]
                                  : isCurrentlyAssigned
                                  ? Colors.green[50]
                                  : null,
                              child: RadioListTile<String>(
                                value: driver.uid,
                                groupValue: _selectedDriverId,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDriverId = value;
                                    _selectedDriverName = driver.name;
                                  });
                                },
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        driver.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentlyAssigned
                                              ? Colors.green[700]
                                              : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrentlyAssigned) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'ATANMIŞ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver.email,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kayıt: ${_formatDate(driver.createdAt)}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                secondary: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isSelected
                                      ? Colors.purple[600]
                                      : Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stack) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sürücüler yüklenirken hata oluştu: $error',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isAssigning
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isAssigning || _selectedDriverId == null
                        ? null
                        : _handleAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                    ),
                    child: _isAssigning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Ata'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAssign() async {
    if (_selectedDriverId == null || _selectedDriverName == null) return;

    setState(() {
      _isAssigning = true;
    });

    try {
      // Atama işlemini gerçekleştir
      await widget.onAssign(_selectedDriverId!, _selectedDriverName!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${widget.stop.customerName} durağı ${_selectedDriverName} sürücüsüne atandı!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Atama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
