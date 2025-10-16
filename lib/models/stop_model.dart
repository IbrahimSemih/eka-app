import 'package:cloud_firestore/cloud_firestore.dart';

enum StopStatus {
  pending, // Beklemede
  assigned, // Atandı
  inProgress, // Yolda
  completed, // Tamamlandı
  cancelled, // İptal
}

/// Durak/Teslimat Noktası Modeli
class StopModel {
  final String id;
  final String customerName;
  final String address;
  final StopStatus status;
  final String? driverId; // Atanan sürücü ID'si
  final String? driverName; // Atanan sürücü adı
  final int orderIndex; // Rota sırası (optimizasyon sonrası)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String createdBy; // Oluşturan yönetici ID'si

  // Konum bilgileri (gelecek aşamalar için)
  final double? latitude;
  final double? longitude;

  // Notlar
  final String? notes;

  StopModel({
    required this.id,
    required this.customerName,
    required this.address,
    required this.status,
    this.driverId,
    this.driverName,
    required this.orderIndex,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    required this.createdBy,
    this.latitude,
    this.longitude,
    this.notes,
  });

  // Firestore'dan veri okuma
  factory StopModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return StopModel(
      id: doc.id,
      customerName: data['customerName'] ?? '',
      address: data['address'] ?? '',
      status: _statusFromString(data['status'] ?? 'pending'),
      driverId: data['driverId'],
      driverName: data['driverName'],
      orderIndex: data['orderIndex'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'] ?? '',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      notes: data['notes'],
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'address': address,
      'status': _statusToString(status),
      'driverId': driverId,
      'driverName': driverName,
      'orderIndex': orderIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'createdBy': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
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

  // Status için Türkçe metin
  String get statusText {
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

  // copyWith metodu
  StopModel copyWith({
    String? id,
    String? customerName,
    String? address,
    StopStatus? status,
    String? driverId,
    String? driverName,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? createdBy,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    return StopModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
    );
  }
}
