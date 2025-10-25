import 'package:flutter/material.dart';
import '../models/stop_model.dart';
import '../models/route_model.dart';
import '../screens/admin/admin_google_maps_screen.dart';

/// Durak kartı widget'ı - Bekliyor/Teslim Edildi durumlarını gösterir
class StopCard extends StatelessWidget {
  final StopModel stop;
  final RouteModel? route; // Rota bilgisi (harita için)
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;
  final int? displayIndex; // Rota sırası için görüntüleme index'i

  const StopCard({
    super.key,
    required this.stop,
    this.route,
    this.onTap,
    this.onMenuTap,
    this.displayIndex,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(stop.status);
    final isCompleted = stop.status == StopStatus.completed;
    final isPending = stop.status == StopStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCompleted ? 1 : 2,
      color: isCompleted ? Colors.grey[50] : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? Colors.grey[300]!
                  : isPending
                  ? Colors.orange[200]!
                  : statusColor.withValues(alpha: 0.3),
              width: isPending ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst satır: Sıra numarası, durum badge ve menü
                Row(
                  children: [
                    // Sıra numarası
                    if (displayIndex != null)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${displayIndex! + 1}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    if (displayIndex != null) const SizedBox(width: 12),

                    // Durum badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(stop.status),
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusDisplayText(stop.status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Menü butonu
                    if (onMenuTap != null)
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: isCompleted ? Colors.grey : Colors.black87,
                        ),
                        onPressed: () {
                          print(
                            '🔘 Menü butonu tıklandı: ${stop.customerName}',
                          );
                          print('🔍 onMenuTap null mu? ${onMenuTap == null}');
                          if (onMenuTap != null) {
                            print('✅ onMenuTap çağrılıyor...');
                            onMenuTap!();
                          } else {
                            print('❌ onMenuTap null!');
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Müşteri adı
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 20,
                      color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.customerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? Colors.grey[600]
                              : Colors.black87,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Adres
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: isCompleted ? Colors.grey[400] : Colors.red[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted
                              ? Colors.grey[500]
                              : Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                // Sürücü bilgisi (varsa)
                if (stop.driverName != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 20,
                        color: isCompleted
                            ? Colors.grey[400]
                            : Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sürücü: ${stop.driverName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isCompleted
                                ? Colors.grey[500]
                                : Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Notlar (varsa)
                if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.grey[100] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.grey[300]!
                            : Colors.blue[200]!,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note,
                          size: 18,
                          color: isCompleted
                              ? Colors.grey[400]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stop.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCompleted
                                  ? Colors.grey[600]
                                  : Colors.blue[900],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tamamlanma zamanı (tamamlandıysa)
                if (isCompleted && stop.completedAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Teslim edildi: ${_formatDateTime(stop.completedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Harita butonu (koordinatları varsa)
                if (stop.latitude != null && stop.longitude != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openInAppGoogleMaps(context),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return Colors.orange;
      case StopStatus.assigned:
        return Colors.purple;
      case StopStatus.inProgress:
        return Colors.blue;
      case StopStatus.completed:
        return Colors.green;
      case StopStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return Icons.pending_outlined;
      case StopStatus.assigned:
        return Icons.assignment_turned_in_outlined;
      case StopStatus.inProgress:
        return Icons.local_shipping_outlined;
      case StopStatus.completed:
        return Icons.check_circle;
      case StopStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusDisplayText(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return 'BEKLİYOR';
      case StopStatus.assigned:
        return 'ATANDI';
      case StopStatus.inProgress:
        return 'YOLDA';
      case StopStatus.completed:
        return 'TESLİM EDİLDİ';
      case StopStatus.cancelled:
        return 'İPTAL';
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Bugün ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Uygulama içi Google Maps'i açar
  void _openInAppGoogleMaps(BuildContext context) {
    if (route == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminGoogleMapsScreen(route: route!),
      ),
    );
  }
}
