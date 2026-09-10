import 'package:flutter_test/flutter_test.dart';
import 'package:palaoglu_kasa_takip/core/constants/categories.dart';
import 'package:palaoglu_kasa_takip/core/utils/report_utils.dart';
import 'package:palaoglu_kasa_takip/data/models/employee_model.dart';
import 'package:palaoglu_kasa_takip/data/models/transaction_model.dart';

void main() {
  test('kasa nakdi verilen ve geri alınan borcu hesaba katar', () {
    final transactions = [
      _transaction(TransactionTypes.ciro, 100000),
      _transaction(
        TransactionTypes.masraf,
        10000,
        paymentSource: PaymentSources.cash,
      ),
      _transaction(
        TransactionTypes.isci,
        5000,
        paymentSource: PaymentSources.cash,
      ),
      _transaction(
        TransactionTypes.komisyon,
        3000,
        paymentSource: PaymentSources.cash,
      ),
      _transaction(TransactionTypes.banka, 20000),
      _transaction(
        TransactionTypes.borc,
        7000,
        category: AppCategories.debtGiven,
      ),
      _transaction(
        TransactionTypes.borc,
        2000,
        category: AppCategories.debtPayment,
      ),
    ];

    final summary = ReportUtils.summarize(
      transactions,
      todayKey: '2026-09-10',
    );

    expect(summary.cashOnHand, 57000);
  });

  test('maaş geçmişi eski aylık raporları değiştirmez', () {
    const employee = EmployeeModel(
      id: '1',
      name: 'Ali',
      salary: 12000,
      salaryHistory: {
        '2026-01': 10000,
        '2026-09': 12000,
      },
      active: true,
      updatedByUid: 'admin',
      updatedByName: 'Admin',
    );

    expect(employee.salaryForMonth('2026-08'), 10000);
    expect(employee.salaryForMonth('2026-09'), 12000);
  });

  test('eski çalışan kayıtları ilk maaş güncellemesinde korunur', () {
    const employee = EmployeeModel(
      id: '1',
      name: 'Ali',
      salary: 10000,
      active: true,
      updatedByUid: 'admin',
      updatedByName: 'Admin',
    );

    final updated = employee.withSalaryFrom('2026-09', 12000);

    expect(updated.salaryForMonth('2026-08'), 10000);
    expect(updated.salaryForMonth('2026-09'), 12000);
  });
}

TransactionModel _transaction(
  String type,
  double amount, {
  String category = '',
  String paymentSource = PaymentSources.cash,
}) {
  return TransactionModel(
    id: '$type-$amount-$category',
    date: '2026-09-10',
    monthKey: '2026-09',
    type: type,
    category: category,
    person: type == TransactionTypes.isci ? 'Ali' : '',
    amount: amount,
    description: '',
    createdByUid: 'admin',
    createdByName: 'Admin',
    paymentSource: paymentSource,
  );
}
