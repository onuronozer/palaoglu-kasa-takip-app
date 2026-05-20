import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/app_user.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../auth/auth_controller.dart';
import 'employee_controller.dart';

class EmployeeSettingsScreen extends ConsumerStatefulWidget {
  const EmployeeSettingsScreen({super.key});

  @override
  ConsumerState<EmployeeSettingsScreen> createState() =>
      _EmployeeSettingsScreenState();
}

class _EmployeeSettingsScreenState
    extends ConsumerState<EmployeeSettingsScreen> {
  final _nameController = TextEditingController();
  final _salaryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final employeesState = ref.watch(employeesProvider);
    final controllerState = ref.watch(employeeControllerProvider);

    if (appUser?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Personel Ayarları'),
          leading: IconButton(
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Bu işlem için yetkiniz yok',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Ayarları'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AddEmployeeCard(
                    nameController: _nameController,
                    salaryController: _salaryController,
                    isLoading: controllerState.isLoading,
                    onAdd: () => _addEmployee(appUser!),
                  ),
                  const SizedBox(height: 16),
                  employeesState.when(
                    loading: () => const _LoadingCard(
                      message: 'Personeller yükleniyor...',
                    ),
                    error: (_, __) => const _LoadingCard(
                      message: 'Personel listesi okunamadı.',
                    ),
                    data: (employees) {
                      return _EmployeeList(
                        employees: employees,
                        appUser: appUser!,
                        isLoading: controllerState.isLoading,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addEmployee(AppUser appUser) async {
    final success = await ref
        .read(employeeControllerProvider.notifier)
        .addEmployee(
          name: _nameController.text,
          salaryText: _salaryController.text,
          updatedBy: appUser,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      _nameController.clear();
      _salaryController.clear();
      _showSnack('Personel eklendi.');
    } else {
      _showSnack('Personel eklenemedi.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddEmployeeCard extends StatelessWidget {
  const _AddEmployeeCard({
    required this.nameController,
    required this.salaryController,
    required this.isLoading,
    required this.onAdd,
  });

  final TextEditingController nameController;
  final TextEditingController salaryController;
  final bool isLoading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Yeni personel ekle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameController,
            enabled: !isLoading,
            decoration: const InputDecoration(
              labelText: 'Personel adı',
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: salaryController,
            enabled: !isLoading,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Maaş baremi',
              prefixIcon: Icon(Icons.payments_outlined),
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onAdd,
            icon: const Icon(Icons.add),
            label: Text(isLoading ? 'Kaydediliyor...' : 'Personel Ekle'),
          ),
        ],
      ),
    );
  }
}

class _EmployeeList extends ConsumerWidget {
  const _EmployeeList({
    required this.employees,
    required this.appUser,
    required this.isLoading,
  });

  final List<EmployeeModel> employees;
  final AppUser appUser;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Personel listesi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (employees.isEmpty)
                TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final success = await ref
                              .read(employeeControllerProvider.notifier)
                              .ensureDefaults(appUser);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Varsayılan personeller oluşturuldu.'
                                    : 'Varsayılan personeller oluşturulamadı.',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Varsayılanları ekle'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (employees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Henüz personel yok.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            )
          else
            for (final employee in employees)
              _EmployeeTile(
                employee: employee,
                appUser: appUser,
                isLoading: isLoading,
              ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends ConsumerWidget {
  const _EmployeeTile({
    required this.employee,
    required this.appUser,
    required this.isLoading,
  });

  final EmployeeModel employee;
  final AppUser appUser;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  employee.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch(
                value: employee.active,
                activeColor: AppColors.primary,
                onChanged: isLoading
                    ? null
                    : (value) {
                        ref
                            .read(employeeControllerProvider.notifier)
                            .setActive(
                              employee: employee,
                              active: value,
                              updatedBy: appUser,
                            );
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Maaş baremi: ${MoneyUtils.format(employee.salary)}',
            style: const TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: employee.active
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    employee.active ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                      color: employee.active
                          ? AppColors.primary
                          : AppColors.expense,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _showSalaryDialog(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Maaş güncelle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSalaryDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: employee.salary == 0 ? '' : employee.salary.toStringAsFixed(0),
    );

    final salaryText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('${employee.name} maaş baremi'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Yeni maaş baremi',
              prefixText: '₺ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (salaryText == null) {
      return;
    }

    final success = await ref
        .read(employeeControllerProvider.notifier)
        .updateSalary(
          employee: employee,
          salaryText: salaryText,
          updatedBy: appUser,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Maaş baremi güncellendi.' : 'Maaş baremi güncellenemedi.',
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
    );
  }
}
