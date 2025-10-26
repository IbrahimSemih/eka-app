import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stop_model.dart';
import '../../models/route_model.dart';
import '../../providers/stops_provider.dart';
import '../../providers/drivers_provider.dart';
import '../../widgets/stop_card.dart';
import 'add_stop_screen.dart';

class StopsListScreen extends ConsumerWidget {
  const StopsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(stopsStreamProvider);
    final statistics = ref.watch(stopsStatisticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Durak Listesi')),
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
                        onAssignDriver: () =>
                            _showStopDriverAssignmentDialog(context, ref, stop),
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

  // Durak için sürücü atama dialog'u
  Future<void> _showStopDriverAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
  ) async {
    // Ana rotayı al
    final routeAsync = ref.read(mainRouteStreamProvider);

    routeAsync.whenData((route) {
      if (route == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rota bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => _StopDriverAssignmentModal(
          stop: stop,
          route: route,
          onAssign: (driverId, driverName) async {
            await _assignStopToDriver(
              context,
              ref,
              stop,
              route,
              driverId,
              driverName,
            );
          },
        ),
      );
    });
  }

  // Durak için sürücü atama işlemi
  Future<void> _assignStopToDriver(
    BuildContext context,
    WidgetRef ref,
    StopModel stop,
    RouteModel route,
    String driverId,
    String driverName,
  ) async {
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
