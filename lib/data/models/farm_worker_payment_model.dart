import 'package:cloud_firestore/cloud_firestore.dart';

class FarmWorkerPaymentModel {
  const FarmWorkerPaymentModel({
    required this.id,
    required this.workerId,
    required this.date,
    required this.amount,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workerId;
  final String date;
  final double amount;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmWorkerPaymentModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      description: description ?? this.description,
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
