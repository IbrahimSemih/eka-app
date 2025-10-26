import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stops_provider.dart';
import '../../services/geocoding_service.dart';
import '../auth/login_screen.dart';
import 'add_stop_screen.dart';
import 'stops_list_screen.dart';
import 'route_view_screen.dart';
import 'add_driver_screen.dart';
import 'drivers_management_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final statistics = ref.watch(stopsStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context, ref),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(stopsStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hoş geldiniz kartı
              currentUser.when(
                data: (user) => Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.admin_panel_settings,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hoş Geldiniz',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.name ?? user?.email ?? 'Yönetici',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // İstatistikler
              Text(
                'Bugünün İstatistikleri',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.today,
                      title: 'Bugün',
                      value: '${statistics.todayStops}',
                      subtitle: 'Toplam Durak',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.check_circle,
                      title: 'Tamamlanan',
                      value: '${statistics.todayCompletedStops}',
                      subtitle: 'Bugün',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Başarı oranı kartı
              _buildSuccessRateCard(context, statistics),
              const SizedBox(height: 24),

              // Genel özet
              Text(
                'Genel Özet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Toplam Durak',
                        '${statistics.totalStops}',
                        Icons.location_on,
                        Colors.blue,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Bekleyen',
                        '${statistics.pendingStops}',
                        Icons.pending,
                        Colors.orange,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Atanan',
                        '${statistics.assignedStops}',
                        Icons.assignment,
                        Colors.purple,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Yolda',
                        '${statistics.inProgressStops}',
                        Icons.local_shipping,
                        Colors.indigo,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Tamamlanan',
                        '${statistics.completedStops}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'İptal Edilen',
                        '${statistics.cancelledStops}',
                        Icons.cancel,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gerçek zamanlı durum kartı
              _buildRealTimeStatusCard(context, statistics),
              const SizedBox(height: 24),

              // Hızlı erişim menüsü
              Text(
                'Hızlı Erişim',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    icon: Icons.route,
                    title: 'Ana Rota',
                    subtitle: 'Rotayı görüntüle',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RouteViewScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.add_location,
                    title: 'Yeni Durak',
                    subtitle: 'Durak ekle',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddStopScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.list_alt,
                    title: 'Durak Listesi',
                    subtitle: 'Tüm duraklar',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StopsListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.route,
                    title: 'Rota Optimize Et',
                    subtitle: 'En kısa yol',
                    color: Colors.teal,
                    onTap: () => _showOptimizationDialog(context, ref),
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.location_searching,
                    title: 'Koordinat Güncelle',
                    subtitle: 'Adres → Koordinat',
                    color: Colors.indigo,
                    onTap: () => _updateAllCoordinates(context, ref),
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.person_add,
                    title: 'Sürücü Ekle',
                    subtitle: 'Yeni sürücü',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddDriverScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.people,
                    title: 'Sürücü Yönetimi',
                    subtitle: 'Tüm sürücüler',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriversManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRateCard(BuildContext context, statistics) {
    final totalToday = statistics.todayStops;
    final completedToday = statistics.todayCompletedStops;
    final failedToday = statistics.cancelledStops;
    final successRate = totalToday > 0
        ? (completedToday / totalToday * 100)
        : 0.0;

    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Başarı Oranı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSuccessMetric(
                    'Başarılı',
                    '$completedToday',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildSuccessMetric(
                    'Başarısız',
                    '$failedToday',
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
                Expanded(
                  child: _buildSuccessMetric(
                    'Oran',
                    '${successRate.toStringAsFixed(1)}%',
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            LinearProgressIndicator(
              value: successRate / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                successRate >= 80
                    ? Colors.green
                    : successRate >= 60
                    ? Colors.orange
                    : Colors.red,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              successRate >= 80
                  ? 'Mükemmel performans! 🎉'
                  : successRate >= 60
                  ? 'İyi performans 👍'
                  : 'Performansı iyileştirmek gerekiyor 📈',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: successRate >= 80
                    ? Colors.green[700]
                    : successRate >= 60
                    ? Colors.orange[700]
                    : Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeStatusCard(BuildContext context, statistics) {
    final completedStops = statistics.completedStops;
    final cancelledStops = statistics.cancelledStops;
    final activeStops =
        statistics.pendingStops +
        statistics.assignedStops +
        statistics.inProgressStops;

    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.purple[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Gerçek Zamanlı Durum',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CANLI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric(
                    'Aktif Görevler',
                    '$activeStops',
                    Colors.orange,
                    Icons.assignment,
                  ),
                ),
                Expanded(
                  child: _buildRealTimeMetric(
                    'Tamamlanan',
                    '$completedStops',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildRealTimeMetric(
                    'İptal Edilen',
                    '$cancelledStops',
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Durum çubuğu
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey[300],
              ),
              child: Row(
                children: [
                  if (completedStops > 0)
                    Expanded(
                      flex: completedStops,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  if (cancelledStops > 0)
                    Expanded(
                      flex: cancelledStops,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  if (activeStops > 0)
                    Expanded(
                      flex: activeStops,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Son güncelleme: ${_getCurrentTime()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
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
