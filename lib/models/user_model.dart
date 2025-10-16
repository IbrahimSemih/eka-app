import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  driver,
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? assignedDriverId; // Sadece admin için, atanan sürücü ID'si
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.assignedDriverId,
    required this.createdAt,
    this.updatedAt,
  });

  // Firestore'dan veri okuma
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: _roleFromString(data['role'] ?? 'driver'),
      assignedDriverId: data['assignedDriverId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': _roleToString(role),
      'assignedDriverId': assignedDriverId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Rol dönüştürme yardımcıları
  static UserRole _roleFromString(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.driver;
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.driver:
        return 'driver';
    }
  }

  // copyWith metodu - güncelleme için
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    UserRole? role,
    String? assignedDriverId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

