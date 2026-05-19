import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';
import 'transaction_model.dart';

class DeletedTransactionModel {
  const DeletedTransactionModel({
    required this.id,
    required this.originalTransactionId,
    required this.date,
    required this.monthKey,
    required this.type,
    required this.category,
    required this.person,
    required this.amount,
    required this.description,
    required this.createdByUid,
    required this.createdByName,
    required this.deletedByUid,
    required this.deletedByName,
    this.deletedAt,
    this.originalCreatedAt,
  });

  final String id;
  final String originalTransactionId;
  final String date;
  final String monthKey;
  final String type;
  final String category;
  final String person;
  final double amount;
  final String description;
  final String createdByUid;
  final String createdByName;
  final String deletedByUid;
  final String deletedByName;
  final DateTime? deletedAt;
  final DateTime? originalCreatedAt;

  factory DeletedTransactionModel.fromTransaction({
    required String id,
    required TransactionModel transaction,
    required AppUser deletedBy,
  }) {
    return DeletedTransactionModel(
      id: id,
      originalTransactionId: transaction.id,
      date: transaction.date,
      monthKey: transaction.monthKey,
      type: transaction.type,
      category: transaction.category,
      person: transaction.person,
      amount: transaction.amount,
      description: transaction.description,
      createdByUid: transaction.createdByUid,
      createdByName: transaction.createdByName,
      deletedByUid: deletedBy.uid,
      deletedByName: deletedBy.displayName,
      originalCreatedAt: transaction.createdAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'originalTransactionId': originalTransactionId,
      'date': date,
      'monthKey': monthKey,
      'type': type,
      'category': category,
      'person': person,
      'amount': amount,
      'description': description,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deletedAt': FieldValue.serverTimestamp(),
      if (originalCreatedAt != null)
        'originalCreatedAt': Timestamp.fromDate(originalCreatedAt!),
    };
  }
}
