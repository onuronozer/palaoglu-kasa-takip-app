import 'package:cloud_firestore/cloud_firestore.dart';

class FarmExpenseModel {
  const FarmExpenseModel({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String date;
  final String category;
  final double amount;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FarmExpenseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmExpenseModel(
      id: doc.id,
      date: data['tarih'] as String? ?? '',
      category: data['kategori'] as String? ?? '',
      amount: _doubleFromFirestore(data['tutar']),
      description: data['aciklama'] as String? ?? '',
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
