import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantModel {
  const MerchantModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.currentBalance,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final double currentBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MerchantModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    double? currentBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MerchantModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MerchantModel(
      id: doc.id,
      fullName: data['ad_soyad'] as String? ?? '',
      phone: data['telefon'] as String? ?? '',
      currentBalance: _doubleFromFirestore(data['guncel_bakiye']),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'ad_soyad': fullName,
      'telefon': phone,
      'guncel_bakiye': currentBalance,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'ad_soyad': fullName,
      'telefon': phone,
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
