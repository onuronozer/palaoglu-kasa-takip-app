import 'package:cloud_firestore/cloud_firestore.dart';

class FarmWorkerWorkModel {
  const FarmWorkerWorkModel({
    required this.id,
    required this.workerId,
    required this.date,
    required this.dayCount,
    required this.dailyWage,
    required this.totalEarned,
    required this.description,
    this.seasonYear = 0,
    this.fieldId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workerId;
  final String date;
  final double dayCount;
  final double dailyWage;
  final double totalEarned;
  final String description;
  final int seasonYear;
  final String fieldId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get resolvedSeasonYear {
    if (seasonYear > 0) {
      return seasonYear;
    }
    return _seasonFromDateKey(date);
  }

  factory FarmWorkerWorkModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FarmWorkerWorkModel(
      id: doc.id,
      workerId: data['isci_id'] as String? ?? '',
      date: data['tarih'] as String? ?? '',
      dayCount: _doubleFromFirestore(data['gun_sayisi']),
      dailyWage: _doubleFromFirestore(data['yevmiye']),
      totalEarned: _doubleFromFirestore(data['hakedis_tutari']),
      description: data['aciklama'] as String? ?? '',
      seasonYear: _intFromFirestore(data['sezon_yili']),
      fieldId: data['tarla_id'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  FarmWorkerWorkModel copyWith({
    String? id,
    String? workerId,
    String? date,
    double? dayCount,
    double? dailyWage,
    double? totalEarned,
    String? description,
    int? seasonYear,
    String? fieldId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmWorkerWorkModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      date: date ?? this.date,
      dayCount: dayCount ?? this.dayCount,
      dailyWage: dailyWage ?? this.dailyWage,
      totalEarned: totalEarned ?? this.totalEarned,
      description: description ?? this.description,
      seasonYear: seasonYear ?? this.seasonYear,
      fieldId: fieldId ?? this.fieldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'isci_id': workerId,
      'tarih': date,
      'gun_sayisi': dayCount,
      'yevmiye': dailyWage,
      'hakedis_tutari': totalEarned,
      'aciklama': description,
      'sezon_yili': resolvedSeasonYear,
      'tarla_id': fieldId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'isci_id': workerId,
      'tarih': date,
      'gun_sayisi': dayCount,
      'yevmiye': dailyWage,
      'hakedis_tutari': totalEarned,
      'aciklama': description,
      'sezon_yili': resolvedSeasonYear,
      'tarla_id': fieldId,
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
