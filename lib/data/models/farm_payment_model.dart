import 'package:cloud_firestore/cloud_firestore.dart';

class FarmPaymentModel {
  const FarmPaymentModel({
    required this.id,
    required this.merchantId,
    required this.date,
    required this.amount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String merchantId;
  final String date;
  final double amount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FarmPaymentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmPaymentModel(
      id: doc.id,
      merchantId: data['tuccar_id'] as String? ?? '',
      date: data['tarih'] as String? ?? '',
      amount: _doubleFromFirestore(data['alinan_tutar']),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'tuccar_id': merchantId,
      'tarih': date,
      'alinan_tutar': amount,
      'createdAt': FieldValue.serverTimestamp(),
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
