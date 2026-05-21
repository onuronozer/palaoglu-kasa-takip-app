import 'package:cloud_firestore/cloud_firestore.dart';

class FarmPaymentModel {
  const FarmPaymentModel({
    required this.id,
    required this.merchantId,
    required this.date,
    required this.amount,
    this.seasonYear = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String merchantId;
  final String date;
  final double amount;
  final int seasonYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get resolvedSeasonYear {
    if (seasonYear > 0) {
      return seasonYear;
    }
    return _seasonFromDateKey(date);
  }

  FarmPaymentModel copyWith({
    String? id,
    String? merchantId,
    String? date,
    double? amount,
    int? seasonYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmPaymentModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      seasonYear: seasonYear ?? this.seasonYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FarmPaymentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmPaymentModel(
      id: doc.id,
      merchantId: data['tuccar_id'] as String? ?? '',
      date: data['tarih'] as String? ?? '',
      amount: _doubleFromFirestore(data['alinan_tutar']),
      seasonYear: _intFromFirestore(data['sezon_yili']),
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
      'sezon_yili': resolvedSeasonYear,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'tuccar_id': merchantId,
      'tarih': date,
      'alinan_tutar': amount,
      'sezon_yili': resolvedSeasonYear,
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

  static int _intFromFirestore(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static int _seasonFromDateKey(String value) {
    if (value.length >= 4) {
      return int.tryParse(value.substring(0, 4)) ?? DateTime.now().year;
    }
    return DateTime.now().year;
  }
}
