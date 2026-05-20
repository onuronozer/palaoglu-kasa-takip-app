import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/deleted_transaction_model.dart';
import '../models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(FirebaseFirestore.instance);
});

final transactionsByMonthProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, monthKey) {
      return ref.watch(transactionRepositoryProvider).watchByMonth(monthKey);
    });

final transactionByIdProvider =
    StreamProvider.family<TransactionModel?, String>((ref, transactionId) {
      return ref.watch(transactionRepositoryProvider).watchById(transactionId);
    });

class TransactionRepository {
  TransactionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _deletedTransactions =>
      _firestore.collection('deleted_transactions');

  Stream<List<TransactionModel>> watchByMonth(String monthKey) {
    return _transactions.where('monthKey', isEqualTo: monthKey).snapshots().map(
      (snapshot) {
        final items = snapshot.docs
            .map(TransactionModel.fromDoc)
            .where((transaction) => transaction.status == 'active')
            .toList();

        items.sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) {
            return byDate;
          }
          final aCreatedAt = a.createdAt ?? DateTime(1900);
          final bCreatedAt = b.createdAt ?? DateTime(1900);
          return bCreatedAt.compareTo(aCreatedAt);
        });

        return items;
      },
    );
  }

  Stream<TransactionModel?> watchById(String transactionId) {
    return _transactions.doc(transactionId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return TransactionModel.fromDoc(doc);
    });
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final id = transaction.id.isEmpty ? Uuid().v4() : transaction.id;
    final doc = _transactions.doc(id);
    await doc.set(transaction.copyWith(id: id).toCreateMap());
  }

  Future<void> addTransactions(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final transaction in transactions) {
      final id = transaction.id.isEmpty ? Uuid().v4() : transaction.id;
      batch.set(
        _transactions.doc(id),
        transaction.copyWith(id: id).toCreateMap(),
      );
    }

    await batch.commit();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _transactions.doc(transaction.id).update(transaction.toUpdateMap());
  }

  Future<void> deleteTransaction({
    required TransactionModel transaction,
    required AppUser deletedBy,
  }) async {
    final deletedId = Uuid().v4();
    final deleted = DeletedTransactionModel.fromTransaction(
      id: deletedId,
      transaction: transaction,
      deletedBy: deletedBy,
    );

    final batch = _firestore.batch();
    batch.set(_deletedTransactions.doc(deletedId), deleted.toCreateMap());
    batch.delete(_transactions.doc(transaction.id));
    await batch.commit();
  }
}
