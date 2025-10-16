import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stop_model.dart';
import '../../providers/stops_provider.dart';
import '../../widgets/stop_card.dart';
import 'add_stop_screen.dart';

class StopsListScreen extends ConsumerWidget {
  const StopsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(stopsStreamProvider);
    final statistics = ref.watch(stopsStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Durak Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStopScreen()),
              );
            },
            tooltip: 'Yeni Durak Ekle',
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistikler kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  'Toplam',
                  '${statistics.totalStops}',
                  Colors.blue,
                ),
                _buildQuickStat(
                  'Bekleyen',
                  '${statistics.pendingStops}',
                  Colors.orange,
                ),
                _buildQuickStat(
                  'Tamamlanan',
                  '${statistics.completedStops}',
                  Colors.green,
                ),
              ],
            ),
          ),

          // Duraklar listesi
          Expanded(
            child: stopsAsync.when(
              data: (stops) {
                if (stops.isEmpty) {
                  return Center(
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
                          'Henüz durak eklenmemiş',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddStopScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('İlk Durağı Ekle'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(stopsStreamProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return StopCard(
                        stop: stop,
                        displayIndex: index,
                        onTap: () => _showStopDetails(context, ref, stop),
                        onMenuTap: () {
                          print(
                            '🎯 StopCard onMenuTap çağrıldı: ${stop.customerName}',
                          );
                          _showStopMenu(context, ref, stop);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
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
                    Text(
                      error.toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStopScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
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

  void _showStopMenu(BuildContext context, WidgetRef ref, StopModel stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
                Navigator.pop(context);
                _showStopDetails(context, ref, stop);
              },
            ),
            if (stop.status == StopStatus.pending)
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.blue),
                title: const Text('Sürücüye Ata'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bu özellik sonraki aşamada eklenecek'),
                    ),
                  );
                },
              ),
            if (stop.status != StopStatus.completed &&
                stop.status != StopStatus.cancelled)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.orange),
                title: const Text('İptal Et'),
                onTap: () {
                  Navigator.pop(context);
                  _cancelStop(context, ref, stop);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Sil'),
              onTap: () {
                Navigator.pop(context);
                _deleteStop(context, ref, stop);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Durağı Sil'),
        content: Text(
          '${stop.customerName} durağını kalıcı olarak silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(stopsNotifierProvider.notifier).deleteStop(stop.id);

        try {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Durak silindi'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (contextError) {
          print('⚠️ Context kontrolü hatası: $contextError');
        }
      } catch (e) {
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
    }
  }
}
