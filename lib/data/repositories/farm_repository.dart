import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/farm_expense_model.dart';
import '../models/farm_payment_model.dart';
import '../models/farm_sale_model.dart';
import '../models/merchant_model.dart';

final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FarmRepository(FirebaseFirestore.instance);
});

final merchantsProvider = StreamProvider<List<MerchantModel>>((ref) {
  return ref.watch(farmRepositoryProvider).watchMerchants();
});

final farmSalesProvider = StreamProvider<List<FarmSaleModel>>((ref) {
  return ref.watch(farmRepositoryProvider).watchSales();
});

final farmPaymentsProvider = StreamProvider<List<FarmPaymentModel>>((ref) {
  return ref.watch(farmRepositoryProvider).watchPayments();
});

final farmExpensesProvider = StreamProvider<List<FarmExpenseModel>>((ref) {
  return ref.watch(farmRepositoryProvider).watchExpenses();
});

class FarmRepository {
  FarmRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _merchants =>
      _firestore.collection('tuccarlar');

  CollectionReference<Map<String, dynamic>> get _sales =>
      _firestore.collection('satislar');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('tahsilatlar');

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection('giderler');

  Stream<List<MerchantModel>> watchMerchants() {
    return _merchants.snapshots().map((snapshot) {
      final items = snapshot.docs.map(MerchantModel.fromDoc).toList();
      items.sort((a, b) => a.fullName.compareTo(b.fullName));
      return items;
    });
  }

  Stream<List<FarmSaleModel>> watchSales() {
    return _sales.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmSaleModel.fromDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<List<FarmPaymentModel>> watchPayments() {
    return _payments.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmPaymentModel.fromDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<List<FarmExpenseModel>> watchExpenses() {
    return _expenses.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmExpenseModel.fromDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Future<void> addMerchant({
    required String fullName,
    required String phone,
  }) async {
    final id = Uuid().v4();
    final merchant = MerchantModel(
      id: id,
      fullName: fullName,
      phone: phone,
      currentBalance: 0,
    );
    await _merchants.doc(id).set(merchant.toCreateMap());
  }

  Future<void> addSale(FarmSaleModel sale) async {
    final id = sale.id.isEmpty ? Uuid().v4() : sale.id;
    final saleWithId = FarmSaleModel(
      id: id,
      merchantId: sale.merchantId,
      date: sale.date,
      productName: sale.productName,
      productVariety: sale.productVariety,
      amountKg: sale.amountKg,
      priceTl: sale.priceTl,
      totalAmount: sale.totalAmount,
    );

    await _firestore.runTransaction((transaction) async {
      final merchantRef = _merchants.doc(saleWithId.merchantId);
      final merchantSnapshot = await transaction.get(merchantRef);
      if (!merchantSnapshot.exists) {
        throw StateError('Tüccar bulunamadı.');
      }

      transaction.set(_sales.doc(id), saleWithId.toCreateMap());
      transaction.update(merchantRef, {
        'guncel_bakiye': FieldValue.increment(saleWithId.totalAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addPayment(FarmPaymentModel payment) async {
    final id = payment.id.isEmpty ? Uuid().v4() : payment.id;
    final paymentWithId = FarmPaymentModel(
      id: id,
      merchantId: payment.merchantId,
      date: payment.date,
      amount: payment.amount,
    );

    await _firestore.runTransaction((transaction) async {
      final merchantRef = _merchants.doc(paymentWithId.merchantId);
      final merchantSnapshot = await transaction.get(merchantRef);
      if (!merchantSnapshot.exists) {
        throw StateError('Tüccar bulunamadı.');
      }

      transaction.set(_payments.doc(id), paymentWithId.toCreateMap());
      transaction.update(merchantRef, {
        'guncel_bakiye': FieldValue.increment(-paymentWithId.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addExpense(FarmExpenseModel expense) async {
    final id = expense.id.isEmpty ? Uuid().v4() : expense.id;
    await _expenses
        .doc(id)
        .set(
          FarmExpenseModel(
            id: id,
            date: expense.date,
            category: expense.category,
            amount: expense.amount,
            description: expense.description,
          ).toCreateMap(),
        );
  }
}
