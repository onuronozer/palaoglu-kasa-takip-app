import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/farm_apricot_variety_model.dart';
import '../models/farm_expense_model.dart';
import '../models/farm_payment_model.dart';
import '../models/farm_sale_model.dart';
import '../models/farm_worker_model.dart';
import '../models/farm_worker_payment_model.dart';
import '../models/farm_worker_work_model.dart';
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

final farmWorkersProvider = StreamProvider<List<FarmWorkerModel>>((ref) {
  return ref.watch(farmRepositoryProvider).watchFarmWorkers();
});

final activeFarmWorkersProvider =
    Provider<AsyncValue<List<FarmWorkerModel>>>((ref) {
      return ref
          .watch(farmWorkersProvider)
          .whenData(
            (workers) => workers.where((worker) => worker.active).toList(),
          );
    });

final farmWorkerWorksProvider =
    StreamProvider<List<FarmWorkerWorkModel>>((ref) {
      return ref.watch(farmRepositoryProvider).watchFarmWorkerWorks();
    });

final farmWorkerPaymentsProvider =
    StreamProvider<List<FarmWorkerPaymentModel>>((ref) {
      return ref.watch(farmRepositoryProvider).watchFarmWorkerPayments();
    });

final farmApricotVarietiesProvider =
    StreamProvider<List<FarmApricotVarietyModel>>((ref) {
      return ref.watch(farmRepositoryProvider).watchApricotVarieties();
    });

final activeApricotVarietyNamesProvider = Provider<AsyncValue<List<String>>>((
  ref,
) {
  return ref
      .watch(farmApricotVarietiesProvider)
      .whenData(
        (varieties) => varieties
            .where((variety) => variety.active)
            .map((variety) => variety.name)
            .where((name) => name.trim().isNotEmpty)
            .toList(),
      );
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

  CollectionReference<Map<String, dynamic>> get _farmWorkers =>
      _firestore.collection('tarim_isciler');

  CollectionReference<Map<String, dynamic>> get _farmWorkerWorks =>
      _firestore.collection('tarim_isci_gunleri');

  CollectionReference<Map<String, dynamic>> get _farmWorkerPayments =>
      _firestore.collection('tarim_isci_odemeleri');

  CollectionReference<Map<String, dynamic>> get _apricotVarieties =>
      _firestore.collection('kayisi_cinsleri');

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

  Stream<List<FarmWorkerModel>> watchFarmWorkers() {
    return _farmWorkers.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmWorkerModel.fromDoc).toList();
      items.sort((a, b) {
        if (a.active != b.active) {
          return a.active ? -1 : 1;
        }
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
      return items;
    });
  }

  Stream<List<FarmWorkerWorkModel>> watchFarmWorkerWorks() {
    return _farmWorkerWorks.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmWorkerWorkModel.fromDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<List<FarmWorkerPaymentModel>> watchFarmWorkerPayments() {
    return _farmWorkerPayments.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmWorkerPaymentModel.fromDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Stream<List<FarmApricotVarietyModel>> watchApricotVarieties() {
    return _apricotVarieties.snapshots().map((snapshot) {
      final items = snapshot.docs.map(FarmApricotVarietyModel.fromDoc).toList();
      items.sort((a, b) {
        if (a.active != b.active) {
          return a.active ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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

  Future<void> addFarmWorker({
    required String fullName,
    required double dailyWage,
  }) async {
    final id = Uuid().v4();
    final worker = FarmWorkerModel(
      id: id,
      fullName: fullName,
      dailyWage: dailyWage,
      active: true,
    );
    await _farmWorkers.doc(id).set(worker.toCreateMap());
  }

  Future<void> updateFarmWorker(FarmWorkerModel worker) async {
    await _farmWorkers.doc(worker.id).update(worker.toUpdateMap());
  }

  Future<void> setFarmWorkerActive({
    required FarmWorkerModel worker,
    required bool active,
  }) async {
    await updateFarmWorker(worker.copyWith(active: active));
  }

  Future<void> addFarmWorkerWork(FarmWorkerWorkModel work) async {
    final id = work.id.isEmpty ? Uuid().v4() : work.id;
    await _farmWorkerWorks
        .doc(id)
        .set(work.copyWith(id: id).toCreateMap());
  }

  Future<void> updateFarmWorkerWork(FarmWorkerWorkModel work) async {
    await _farmWorkerWorks.doc(work.id).update(work.toUpdateMap());
  }

  Future<void> deleteFarmWorkerWork(String id) async {
    await _farmWorkerWorks.doc(id).delete();
  }

  Future<void> addFarmWorkerPayment(FarmWorkerPaymentModel payment) async {
    final id = payment.id.isEmpty ? Uuid().v4() : payment.id;
    await _farmWorkerPayments
        .doc(id)
        .set(payment.copyWith(id: id).toCreateMap());
  }

  Future<void> updateFarmWorkerPayment(FarmWorkerPaymentModel payment) async {
    await _farmWorkerPayments.doc(payment.id).update(payment.toUpdateMap());
  }

  Future<void> deleteFarmWorkerPayment(String id) async {
    await _farmWorkerPayments.doc(id).delete();
  }

  Future<void> addApricotVariety(String name) async {
    final id = Uuid().v4();
    final variety = FarmApricotVarietyModel(id: id, name: name, active: true);
    await _apricotVarieties.doc(id).set(variety.toCreateMap());
  }

  Future<void> updateApricotVariety(FarmApricotVarietyModel variety) async {
    await _apricotVarieties.doc(variety.id).update(variety.toUpdateMap());
  }

  Future<void> setApricotVarietyActive({
    required FarmApricotVarietyModel variety,
    required bool active,
  }) async {
    await updateApricotVariety(variety.copyWith(active: active));
  }

  Future<void> deleteApricotVariety(String id) async {
    await _apricotVarieties.doc(id).delete();
  }
}
