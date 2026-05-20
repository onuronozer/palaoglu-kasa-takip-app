import 'package:cloud_firestore/cloud_firestore.dart';

class FarmWorkerModel {
  const FarmWorkerModel({
    required this.id,
    required this.fullName,
    required this.dailyWage,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final double dailyWage;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FarmWorkerModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmWorkerModel(
      id: doc.id,
      fullName: data['ad_soyad'] as String? ?? '',
      dailyWage: _doubleFromFirestore(data['yevmiye']),
      active: data['active'] as bool? ?? true,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  FarmWorkerModel copyWith({
    String? id,
    String? fullName,
    double? dailyWage,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmWorkerModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      dailyWage: dailyWage ?? this.dailyWage,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'ad_soyad': fullName,
      'yevmiye': dailyWage,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'ad_soyad': fullName,
      'yevmiye': dailyWage,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static double _doubleFromFirestore(Object? value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}
