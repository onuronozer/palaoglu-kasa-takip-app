import 'package:cloud_firestore/cloud_firestore.dart';

class FarmWorkerPaymentModel {
  const FarmWorkerPaymentModel({
    required this.id,
    required this.workerId,
    required this.date,
    required this.amount,
    required this.description,
    this.seasonYear = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workerId;
  final String date;
  final double amount;
  final String description;
  final int seasonYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get resolvedSeasonYear {
    if (seasonYear > 0) {
      return seasonYear;
    }
    return _seasonFromDateKey(date);
  }

  factory FarmWorkerPaymentModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FarmWorkerPaymentModel(
      id: doc.id,
      workerId: data['isci_id'] as String? ?? '',
      date: data['tarih'] as String? ?? '',
      amount: _doubleFromFirestore(data['odenen_tutar']),
      description: data['aciklama'] as String? ?? '',
      seasonYear: _intFromFirestore(data['sezon_yili']),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  FarmWorkerPaymentModel copyWith({
    String? id,
    String? workerId,
    String? date,
    double? amount,
    String? description,
    int? seasonYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmWorkerPaymentModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      seasonYear: seasonYear ?? this.seasonYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'isci_id': workerId,
      'tarih': date,
      'odenen_tutar': amount,
      'aciklama': description,
      'sezon_yili': resolvedSeasonYear,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'isci_id': workerId,
      'tarih': date,
      'odenen_tutar': amount,
      'aciklama': description,
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
