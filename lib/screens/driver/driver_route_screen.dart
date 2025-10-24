import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/driver_route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/stop_model.dart';
import '../../models/user_model.dart';
import 'google_maps_screen.dart';
import 'simple_google_maps_screen.dart';

/// Sürücü rota ekranı - Optimize edilmiş, büyük yazılı, yüksek kontrastlı
class DriverRouteScreen extends ConsumerWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final routeAsync = ref.watch(driverRouteStreamProvider);
    final optimizedStops = ref.watch(driverOptimizedStopsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Görevlerim',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            onPressed: () {
              ref.invalidate(driverRouteStreamProvider);
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null || user.role != UserRole.driver) {
            return _buildErrorState('Sürücü oturumu bulunamadı');
          }

          return routeAsync.when(
            data: (route) {
              if (route == null) {
                return _buildNoRouteState();
              }

              return _buildRouteContent(context, ref, route, optimizedStops);
            },
            loading: () => _buildLoadingState(),
            error: (error, stack) =>
                _buildErrorState('Rota yüklenirken hata oluştu'),
          );
        },
        loading: () => _buildLoadingState(),
        error: (_, __) => _buildErrorState('Kullanıcı bilgileri yüklenemedi'),
      ),
    );
  }

  Widget _buildRouteContent(
    BuildContext context,
    WidgetRef ref,
    route,
    List<StopModel> stops,
  ) {
    if (stops.isEmpty) {
      return _buildEmptyRouteState();
    }

    return Column(
      children: [
        // Rota özeti
        _buildRouteSummary(context, ref, route),

        // Duraklar listesi
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverRouteStreamProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return _buildStopCard(context, ref, stop, index + 1);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSummary(BuildContext context, WidgetRef ref, route) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.route, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  route.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Toplam',
                  '${route.totalStops}',
                  Icons.location_on,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Bekleyen',
                  '${route.pendingStops}',
                  Icons.pending,
                  Colors.orange[300]!,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Tamamlanan',
                  '${route.completedStops}',
                  Icons.check_circle,
                  Colors.green[300]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Google Maps butonları
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(context),
                  icon: const Icon(Icons.map, color: Colors.white, size: 20),
                  label: const Text(
                    'Haritada Göster',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openSimpleGoogleMaps(context),
                  icon: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Test Harita',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildStopCard(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
    int orderNumber,
  ) {
    final statusColor = _getStatusColor(stop.status);
    final statusIcon = _getStatusIcon(stop.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStopDetails(context, ref, stop),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sıra numarası ve durum
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          '$orderNumber',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.customerName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                stop.statusText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (stop.status == StopStatus.pending ||
                        stop.status == StopStatus.assigned) ...[
                      // Teslim Edildi butonu
                      IconButton(
                        onPressed: () => _markAsCompleted(context, ref, stop),
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                        ),
                        tooltip: 'Teslim Edildi',
                      ),
                      // Ulaşılamadı butonu
                      IconButton(
                        onPressed: () => _markAsFailed(context, ref, stop),
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 32,
                        ),
                        tooltip: 'Ulaşılamadı',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Adres
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stop.address,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Notlar (varsa)
                if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stop.notes!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Harita butonu
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(context),
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
          ),
        ),
      ),
    );
  }

  Widget _buildNoRouteState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Henüz Görev Atanmamış',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yönetici tarafından size bir rota atandığında\nburada görünecektir.',
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

  Widget _buildEmptyRouteState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 100,
              color: Colors.green[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Tüm Görevler Tamamlandı!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bugün için atanan tüm görevleri\ntamamladınız. Tebrikler!',
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

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 4),
          SizedBox(height: 16),
          Text(
            'Görevler yükleniyor...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 100, color: Colors.red[400]),
            const SizedBox(height: 24),
            Text(
              'Hata Oluştu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
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

  Color _getStatusColor(StopStatus status) {
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

  IconData _getStatusIcon(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return Icons.pending;
      case StopStatus.assigned:
        return Icons.assignment;
      case StopStatus.inProgress:
        return Icons.local_shipping;
      case StopStatus.completed:
        return Icons.check_circle;
      case StopStatus.cancelled:
        return Icons.cancel;
    }
  }

  void _showStopDetails(BuildContext context, WidgetRef ref, StopModel stop) {
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
                'Görev Detayları',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Müşteri', stop.customerName, Icons.person, 20),
              const Divider(),
              _buildDetailRow('Adres', stop.address, Icons.location_on, 18),
              const Divider(),
              _buildDetailRow('Durum', stop.statusText, Icons.info, 18),
              if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                const Divider(),
                _buildDetailRow('Notlar', stop.notes!, Icons.note, 16),
              ],
              const Divider(),
              _buildDetailRow(
                'Oluşturma',
                _formatDate(stop.createdAt),
                Icons.calendar_today,
                16,
              ),
              if (stop.completedAt != null) ...[
                const Divider(),
                _buildDetailRow(
                  'Tamamlanma',
                  _formatDate(stop.completedAt!),
                  Icons.check_circle,
                  16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    double fontSize,
  ) {
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
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
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

  Future<void> _markAsCompleted(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Teslim Edildi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${stop.customerName} adresindeki teslimatı tamamladınız mı?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Evet, Tamamlandı',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(driverRouteNotifierProvider.notifier)
            .updateStopStatus(stop.id, StopStatus.completed);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${stop.customerName} teslim edildi olarak işaretlendi',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Hata: ${e.toString()}',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsFailed(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Ulaşılamadı',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${stop.customerName} adresine ulaşılamadı mı?\n\nBu durum teslimatı iptal edecektir.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Evet, Ulaşılamadı',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(driverRouteNotifierProvider.notifier)
            .updateStopStatus(stop.id, StopStatus.cancelled);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${stop.customerName} ulaşılamadı olarak işaretlendi',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Hata: ${e.toString()}',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Google Maps entegre ekranını açar
  void _openGoogleMaps(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GoogleMapsScreen()),
    );
  }

  /// Basit Google Maps test ekranını açar
  void _openSimpleGoogleMaps(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleGoogleMapsScreen()),
    );
  }
}
