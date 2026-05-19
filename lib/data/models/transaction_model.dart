import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/categories.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.date,
    required this.monthKey,
    required this.type,
    required this.category,
    required this.person,
    required this.amount,
    required this.description,
    required this.createdByUid,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.status = 'active',
  });

  final String id;
  final String date;
  final String monthKey;
  final String type;
  final String category;
  final String person;
  final double amount;
  final String description;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;

  String get typeLabel => TransactionTypes.label(type);

  String get subjectLabel {
    if (type == TransactionTypes.isci || type == TransactionTypes.borc) {
      return person.isEmpty ? category : person;
    }
    return category;
  }

  factory TransactionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return TransactionModel(
      id: doc.id,
      date: data['date'] as String? ?? '',
      monthKey: data['monthKey'] as String? ?? '',
      type: data['type'] as String? ?? '',
      category: data['category'] as String? ?? '',
      person: data['person'] as String? ?? '',
      amount: _doubleFromFirestore(data['amount']),
      description: data['description'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
      status: data['status'] as String? ?? 'active',
    );
  }

  TransactionModel copyWith({
    String? id,
    String? date,
    String? monthKey,
    String? type,
    String? category,
    String? person,
    double? amount,
    String? description,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      monthKey: monthKey ?? this.monthKey,
      type: type ?? this.type,
      category: category ?? this.category,
      person: person ?? this.person,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'date': date,
      'monthKey': monthKey,
      'type': type,
      'category': category,
      'person': person,
      'amount': amount,
      'description': description,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': status,
    };
  }

  Map<String, dynamic> toArchiveMap() {
    return {
      'id': id,
      'date': date,
      'monthKey': monthKey,
      'type': type,
      'category': category,
      'person': person,
      'amount': amount,
      'description': description,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'status': status,
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
