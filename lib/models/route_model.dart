import 'package:cloud_firestore/cloud_firestore.dart';
import 'stop_model.dart';

/// Rota Modeli - Birden fazla durağı içerir
class RouteModel {
  final String id; // Rota ID'si (örn: "main_route")
  final String name; // Rota adı
  final List<StopModel> stops; // Rotadaki duraklar
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // Oluşturan yönetici ID'si
  final bool isActive; // Rota aktif mi?
  final String? assignedDriverId; // Atanan sürücü ID'si
  final String? assignedDriverName; // Atanan sürücü adı
  final DateTime? assignedAt; // Atama tarihi

  // İstatistikler
  int get totalStops => stops.length;
  int get pendingStops =>
      stops.where((s) => s.status == StopStatus.pending).length;
  int get assignedStops =>
      stops.where((s) => s.status == StopStatus.assigned).length;
  int get completedStops =>
      stops.where((s) => s.status == StopStatus.completed).length;
  int get inProgressStops =>
      stops.where((s) => s.status == StopStatus.inProgress).length;
  int get cancelledStops =>
      stops.where((s) => s.status == StopStatus.cancelled).length;

  RouteModel({
    required this.id,
    required this.name,
    required this.stops,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.isActive = true,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedAt,
  });

  // Firestore'dan veri okuma
  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Durakları parse et
    List<StopModel> stopsList = [];
    if (data['stops'] != null) {
      final stopsData = data['stops'] as List<dynamic>;
      stopsList = stopsData.map((stopData) {
        // Her durak bir Map olarak gelecek, bunu StopModel'e çeviriyoruz
        return StopModel(
          id: stopData['id'] ?? '',
          customerName: stopData['customerName'] ?? '',
          address: stopData['address'] ?? '',
          status: _statusFromString(stopData['status'] ?? 'pending'),
          driverId: stopData['driverId'],
          driverName: stopData['driverName'],
          orderIndex: stopData['orderIndex'] ?? 0,
          createdAt: stopData['createdAt'] != null
              ? (stopData['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          updatedAt: stopData['updatedAt'] != null
              ? (stopData['updatedAt'] as Timestamp).toDate()
              : null,
          completedAt: stopData['completedAt'] != null
              ? (stopData['completedAt'] as Timestamp).toDate()
              : null,
          createdBy: stopData['createdBy'] ?? '',
          latitude: stopData['latitude']?.toDouble(),
          longitude: stopData['longitude']?.toDouble(),
          notes: stopData['notes'],
        );
      }).toList();
    }

    return RouteModel(
      id: doc.id,
      name: data['name'] ?? 'Ana Rota',
      stops: stopsList,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'] ?? '',
      isActive: data['isActive'] ?? true,
      assignedDriverId: data['assignedDriverId'],
      assignedDriverName: data['assignedDriverName'],
      assignedAt: data['assignedAt'] != null
          ? (data['assignedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'stops': stops.map((stop) => _stopToMap(stop)).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'isActive': isActive,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'totalStops': totalStops,
      'pendingStops': pendingStops,
      'completedStops': completedStops,
      'inProgressStops': inProgressStops,
    };
  }

  // StopModel'i Map'e çevir
  static Map<String, dynamic> _stopToMap(StopModel stop) {
    return {
      'id': stop.id,
      'customerName': stop.customerName,
      'address': stop.address,
      'status': _statusToString(stop.status),
      'driverId': stop.driverId,
      'driverName': stop.driverName,
      'orderIndex': stop.orderIndex,
      'createdAt': Timestamp.fromDate(stop.createdAt),
      'updatedAt': stop.updatedAt != null
          ? Timestamp.fromDate(stop.updatedAt!)
          : null,
      'completedAt': stop.completedAt != null
          ? Timestamp.fromDate(stop.completedAt!)
          : null,
      'createdBy': stop.createdBy,
      'latitude': stop.latitude,
      'longitude': stop.longitude,
      'notes': stop.notes,
    };
  }

  // Status dönüştürme yardımcıları
  static StopStatus _statusFromString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pending':
        return StopStatus.pending;
      case 'assigned':
        return StopStatus.assigned;
      case 'inprogress':
      case 'in_progress':
        return StopStatus.inProgress;
      case 'completed':
        return StopStatus.completed;
      case 'cancelled':
        return StopStatus.cancelled;
      default:
        return StopStatus.pending;
    }
  }

  static String _statusToString(StopStatus status) {
    switch (status) {
      case StopStatus.pending:
        return 'pending';
      case StopStatus.assigned:
        return 'assigned';
      case StopStatus.inProgress:
        return 'inProgress';
      case StopStatus.completed:
        return 'completed';
      case StopStatus.cancelled:
        return 'cancelled';
    }
  }

  // copyWith metodu
  RouteModel copyWith({
    String? id,
    String? name,
    List<StopModel>? stops,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isActive,
    String? assignedDriverId,
    String? assignedDriverName,
    DateTime? assignedAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      stops: stops ?? this.stops,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }
}
