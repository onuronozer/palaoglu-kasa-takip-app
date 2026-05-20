import 'dart:math' as math;

import '../../data/models/employee_model.dart';
import '../../data/models/transaction_model.dart';
import '../constants/categories.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.todayCiro,
    required this.todayGider,
    required this.monthlyCiro,
    required this.monthlyMasraf,
    required this.employeePayments,
    required this.bankDeposits,
    required this.debtGiven,
    required this.debtPaid,
    required this.cashPaidMasraf,
    required this.cashPaidEmployees,
    required this.personalPaidMasraf,
    required this.personalPaidEmployees,
    required this.bankPaidMasraf,
    required this.bankPaidEmployees,
    required this.businessCommissionPayments,
    required this.cashPaidCommission,
    required this.personalPaidCommission,
    required this.bankPaidCommission,
  });

  final double todayCiro;
  final double todayGider;
  final double monthlyCiro;
  final double monthlyMasraf;
  final double employeePayments;
  final double bankDeposits;
  final double debtGiven;
  final double debtPaid;
  final double cashPaidMasraf;
  final double cashPaidEmployees;
  final double personalPaidMasraf;
  final double personalPaidEmployees;
  final double bankPaidMasraf;
  final double bankPaidEmployees;
  final double businessCommissionPayments;
  final double cashPaidCommission;
  final double personalPaidCommission;
  final double bankPaidCommission;

  double get totalExpense => monthlyMasraf + employeePayments;
  double get profitLoss => monthlyCiro - monthlyMasraf - employeePayments;
  double get businessCommission => profitLoss <= 0 ? 0 : profitLoss / 2;
  double get businessCommissionRemaining =>
      businessCommission - businessCommissionPayments;
  double get businessCommissionDue => math.max(0, businessCommissionRemaining);
  double get businessCommissionOverPaid =>
      math.max(0, -businessCommissionRemaining);
  double get cashOnHand =>
      monthlyCiro -
      cashPaidMasraf -
      cashPaidEmployees -
      cashPaidCommission -
      bankDeposits;
  double get remainingDebt => debtGiven - debtPaid;
  double get personalPaidTotal =>
      personalPaidMasraf + personalPaidEmployees + personalPaidCommission;
  double get bankPaidTotal =>
      bankPaidMasraf + bankPaidEmployees + bankPaidCommission;
  double get cashPaidTotal =>
      cashPaidMasraf + cashPaidEmployees + cashPaidCommission;
}

class ExpenseCategorySummary {
  const ExpenseCategorySummary({
    required this.category,
    required this.amount,
    required this.percent,
  });

  final String category;
  final double amount;
  final double percent;
}

class EmployeeSalarySummary {
  const EmployeeSalarySummary({
    required this.name,
    required this.salary,
    required this.paid,
    required this.active,
  });

  final String name;
  final double salary;
  final double paid;
  final bool active;

  double get difference => salary - paid;
  double get remaining => math.max(0, difference);
  double get overPaid => math.max(0, -difference);
  bool get isComplete => salary > 0 && difference == 0;
  bool get isOverPaid => paid > salary && salary > 0;
  bool get hasRemaining => paid < salary;

  String get status {
    if (salary <= 0 && paid > 0) {
      return 'Barem yok';
    }
    if (isOverPaid) {
      return 'Fazla ödeme';
    }
    if (isComplete) {
      return 'Tamamlandı';
    }
    return 'Kalan var';
  }
}

class DebtPersonSummary {
  const DebtPersonSummary({
    required this.person,
    required this.given,
    required this.paid,
  });

  final String person;
  final double given;
  final double paid;

  double get remaining => given - paid;
}

class ReportUtils {
  const ReportUtils._();

  static FinancialSummary summarize(
    List<TransactionModel> transactions, {
    required String todayKey,
  }) {
    var todayCiro = 0.0;
    var todayGider = 0.0;
    var monthlyCiro = 0.0;
    var monthlyMasraf = 0.0;
    var employeePayments = 0.0;
    var bankDeposits = 0.0;
    var debtGiven = 0.0;
    var debtPaid = 0.0;
    var cashPaidMasraf = 0.0;
    var cashPaidEmployees = 0.0;
    var personalPaidMasraf = 0.0;
    var personalPaidEmployees = 0.0;
    var bankPaidMasraf = 0.0;
    var bankPaidEmployees = 0.0;
    var businessCommissionPayments = 0.0;
    var cashPaidCommission = 0.0;
    var personalPaidCommission = 0.0;
    var bankPaidCommission = 0.0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionTypes.ciro) {
        monthlyCiro += transaction.amount;
        if (transaction.date == todayKey) {
          todayCiro += transaction.amount;
        }
      }

      if (transaction.type == TransactionTypes.masraf) {
        monthlyMasraf += transaction.amount;
        if (transaction.paymentSource == PaymentSources.personal) {
          personalPaidMasraf += transaction.amount;
        } else if (transaction.paymentSource == PaymentSources.bank) {
          bankPaidMasraf += transaction.amount;
        } else {
          cashPaidMasraf += transaction.amount;
        }
        if (transaction.date == todayKey) {
          todayGider += transaction.amount;
        }
      }

      if (transaction.type == TransactionTypes.isci) {
        employeePayments += transaction.amount;
        if (transaction.paymentSource == PaymentSources.personal) {
          personalPaidEmployees += transaction.amount;
        } else if (transaction.paymentSource == PaymentSources.bank) {
          bankPaidEmployees += transaction.amount;
        } else {
          cashPaidEmployees += transaction.amount;
        }
        if (transaction.date == todayKey) {
          todayGider += transaction.amount;
        }
      }

      if (transaction.type == TransactionTypes.komisyon) {
        businessCommissionPayments += transaction.amount;
        if (transaction.paymentSource == PaymentSources.personal) {
          personalPaidCommission += transaction.amount;
        } else if (transaction.paymentSource == PaymentSources.bank) {
          bankPaidCommission += transaction.amount;
        } else {
          cashPaidCommission += transaction.amount;
        }
      }

      if (transaction.type == TransactionTypes.banka) {
        bankDeposits += transaction.amount;
      }

      if (transaction.type == TransactionTypes.borc) {
        if (transaction.category == AppCategories.debtGiven) {
          debtGiven += transaction.amount;
        } else if (transaction.category == AppCategories.debtPayment) {
          debtPaid += transaction.amount;
        }
      }
    }

    return FinancialSummary(
      todayCiro: todayCiro,
      todayGider: todayGider,
      monthlyCiro: monthlyCiro,
      monthlyMasraf: monthlyMasraf,
      employeePayments: employeePayments,
      bankDeposits: bankDeposits,
      debtGiven: debtGiven,
      debtPaid: debtPaid,
      cashPaidMasraf: cashPaidMasraf,
      cashPaidEmployees: cashPaidEmployees,
      personalPaidMasraf: personalPaidMasraf,
      personalPaidEmployees: personalPaidEmployees,
      bankPaidMasraf: bankPaidMasraf,
      bankPaidEmployees: bankPaidEmployees,
      businessCommissionPayments: businessCommissionPayments,
      cashPaidCommission: cashPaidCommission,
      personalPaidCommission: personalPaidCommission,
      bankPaidCommission: bankPaidCommission,
    );
  }

  static List<ExpenseCategorySummary> expenseCategories(
    List<TransactionModel> transactions,
  ) {
    final totals = {
      for (final category in AppCategories.expenseCategories) category: 0.0,
    };

    for (final transaction in transactions) {
      if (transaction.type != TransactionTypes.masraf) {
        continue;
      }
      final category =
          AppCategories.expenseCategories.contains(transaction.category)
          ? transaction.category
          : 'Diğer';
      totals[category] = (totals[category] ?? 0) + transaction.amount;
    }

    final total = totals.values.fold<double>(0, (sum, amount) => sum + amount);

    return totals.entries
        .map(
          (entry) => ExpenseCategorySummary(
            category: entry.key,
            amount: entry.value,
            percent: total == 0 ? 0 : entry.value / total,
          ),
        )
        .where((entry) => entry.amount > 0 || total == 0)
        .toList();
  }

  static List<EmployeeSalarySummary> employeeSalarySummaries(
    List<EmployeeModel> employees,
    List<TransactionModel> transactions,
  ) {
    final paidByEmployee = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionTypes.isci) {
        continue;
      }
      final name = transaction.person.trim();
      if (name.isEmpty) {
        continue;
      }
      paidByEmployee[name] = (paidByEmployee[name] ?? 0) + transaction.amount;
    }

    final summaries = <EmployeeSalarySummary>[];
    final knownNames = <String>{};

    for (final employee in employees) {
      knownNames.add(employee.name);
      final paid = paidByEmployee[employee.name] ?? 0;
      if (!employee.active && paid == 0) {
        continue;
      }
      summaries.add(
        EmployeeSalarySummary(
          name: employee.name,
          salary: employee.salary,
          paid: paid,
          active: employee.active,
        ),
      );
    }

    for (final entry in paidByEmployee.entries) {
      if (knownNames.contains(entry.key)) {
        continue;
      }
      summaries.add(
        EmployeeSalarySummary(
          name: entry.key,
          salary: 0,
          paid: entry.value,
          active: false,
        ),
      );
    }

    summaries.sort((a, b) => a.name.compareTo(b.name));
    return summaries;
  }

  static List<DebtPersonSummary> debtByPerson(
    List<TransactionModel> transactions,
  ) {
    final given = <String, double>{};
    final paid = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionTypes.borc) {
        continue;
      }
      final person = transaction.person.trim();
      if (person.isEmpty) {
        continue;
      }

      if (transaction.category == AppCategories.debtGiven) {
        given[person] = (given[person] ?? 0) + transaction.amount;
      } else if (transaction.category == AppCategories.debtPayment) {
        paid[person] = (paid[person] ?? 0) + transaction.amount;
      }
    }

    final people = {...given.keys, ...paid.keys}.toList()..sort();
    return people
        .map(
          (person) => DebtPersonSummary(
            person: person,
            given: given[person] ?? 0,
            paid: paid[person] ?? 0,
          ),
        )
        .toList();
  }
}
