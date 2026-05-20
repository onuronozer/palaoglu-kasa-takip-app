import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/categories.dart';
import '../models/app_user.dart';
import '../models/employee_model.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(FirebaseFirestore.instance);
});

final employeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  return ref.watch(employeeRepositoryProvider).watchEmployees();
});

final activeEmployeesProvider = Provider<AsyncValue<List<EmployeeModel>>>((
  ref,
) {
  return ref
      .watch(employeesProvider)
      .whenData(
        (employees) => employees.where((employee) => employee.active).toList(),
      );
});

class EmployeeRepository {
  EmployeeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employees =>
      _firestore.collection('employees');

  Stream<List<EmployeeModel>> watchEmployees() {
    return _employees.snapshots().map((snapshot) {
      final items = snapshot.docs.map(EmployeeModel.fromDoc).toList();
      items.sort((a, b) {
        if (a.active != b.active) {
          return a.active ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  Future<void> addEmployee({
    required String name,
    required double salary,
    required AppUser updatedBy,
  }) async {
    final id = Uuid().v4();
    final employee = EmployeeModel(
      id: id,
      name: name,
      salary: salary,
      active: true,
      updatedByUid: updatedBy.uid,
      updatedByName: updatedBy.displayName,
    );
    await _employees.doc(id).set(employee.toCreateMap());
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    await _employees.doc(employee.id).update(employee.toUpdateMap());
  }

  Future<void> updateSalary({
    required EmployeeModel employee,
    required double salary,
    required AppUser updatedBy,
  }) async {
    await updateEmployee(
      employee.copyWith(
        salary: salary,
        updatedByUid: updatedBy.uid,
        updatedByName: updatedBy.displayName,
      ),
    );
  }

  Future<void> setActive({
    required EmployeeModel employee,
    required bool active,
    required AppUser updatedBy,
  }) async {
    await updateEmployee(
      employee.copyWith(
        active: active,
        updatedByUid: updatedBy.uid,
        updatedByName: updatedBy.displayName,
      ),
    );
  }

  Future<void> ensureDefaultEmployees(AppUser updatedBy) async {
    final batch = _firestore.batch();
    var hasChanges = false;

    for (final definition in AppCategories.defaultEmployees) {
      final id = _defaultEmployeeId(definition.name);
      final doc = _employees.doc(id);
      final snapshot = await doc.get();
      if (snapshot.exists) {
        continue;
      }

      final employee = EmployeeModel(
        id: id,
        name: definition.name,
        salary: definition.salary,
        active: true,
        updatedByUid: updatedBy.uid,
        updatedByName: updatedBy.displayName,
      );
      batch.set(doc, employee.toCreateMap());
      hasChanges = true;
    }

    if (hasChanges) {
      await batch.commit();
    }
  }

  String _defaultEmployeeId(String name) {
    return name
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
  }
}
