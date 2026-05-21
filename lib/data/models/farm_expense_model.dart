import 'package:cloud_firestore/cloud_firestore.dart';

class FarmExpenseModel {
  const FarmExpenseModel({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    this.seasonYear = 0,
    this.fieldId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String date;
  final String category;
  final double amount;
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

  FarmExpenseModel copyWith({
    String? id,
    String? date,
    String? category,
    double? amount,
    String? description,
    int? seasonYear,
    String? fieldId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmExpenseModel(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      seasonYear: seasonYear ?? this.seasonYear,
      fieldId: fieldId ?? this.fieldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FarmExpenseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmExpenseModel(
      id: doc.id,
      date: data['tarih'] as String? ?? '',
      category: data['kategori'] as String? ?? '',
      amount: _doubleFromFirestore(data['tutar']),
      description: data['aciklama'] as String? ?? '',
      seasonYear: _intFromFirestore(data['sezon_yili']),
      fieldId: data['tarla_id'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'tarih': date,
      'kategori': category,
      'tutar': amount,
      'aciklama': description,
      'sezon_yili': resolvedSeasonYear,
      'tarla_id': fieldId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'tarih': date,
      'kategori': category,
      'tutar': amount,
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
