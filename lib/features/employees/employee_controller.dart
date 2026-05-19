import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';

final employeeControllerProvider =
    StateNotifierProvider<EmployeeController, AsyncValue<void>>((ref) {
  return EmployeeController(ref.watch(employeeRepositoryProvider));
});

class EmployeeController extends StateNotifier<AsyncValue<void>> {
  EmployeeController(this._repository) : super(const AsyncData(null));

  final EmployeeRepository _repository;

  Future<bool> addEmployee({
    required String name,
    required String salaryText,
    required AppUser updatedBy,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = AsyncError('Personel adı boş olamaz.', StackTrace.current);
      return false;
    }

    final salary = MoneyUtils.parse(salaryText);
    if (salary < 0) {
      state = AsyncError('Maaş baremi negatif olamaz.', StackTrace.current);
      return false;
    }

    return _run(
      () => _repository.addEmployee(
        name: trimmedName,
        salary: salary,
        updatedBy: updatedBy,
      ),
    );
  }

  Future<bool> updateSalary({
    required EmployeeModel employee,
    required String salaryText,
    required AppUser updatedBy,
  }) async {
    final salary = MoneyUtils.parse(salaryText);
    if (salary < 0) {
      state = AsyncError('Maaş baremi negatif olamaz.', StackTrace.current);
      return false;
    }

    return _run(
      () => _repository.updateSalary(
        employee: employee,
        salary: salary,
        updatedBy: updatedBy,
      ),
    );
  }

  Future<bool> setActive({
    required EmployeeModel employee,
    required bool active,
    required AppUser updatedBy,
  }) {
    return _run(
      () => _repository.setActive(
        employee: employee,
        active: active,
        updatedBy: updatedBy,
      ),
    );
  }

  Future<bool> ensureDefaults(AppUser updatedBy) {
    return _run(() => _repository.ensureDefaultEmployees(updatedBy));
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
