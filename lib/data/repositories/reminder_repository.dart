import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/local_notification_service.dart';
import '../models/reminder_model.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

final reminderControllerProvider =
    StateNotifierProvider<ReminderController, AsyncValue<List<ReminderModel>>>((
  ref,
) {
  return ReminderController(
    repository: ref.watch(reminderRepositoryProvider),
    notifications: ref.watch(localNotificationServiceProvider),
  );
});

class ReminderRepository {
  static const _storageKey = 'palaoglu_manual_reminders_v1';

  Future<List<ReminderModel>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ReminderModel.fromJson)
        .toList()
      ..sort(_sortReminders);
  }

  Future<void> saveReminders(List<ReminderModel> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = reminders.toList()..sort(_sortReminders);
    await prefs.setString(
      _storageKey,
      jsonEncode(sorted.map((reminder) => reminder.toJson()).toList()),
    );
  }

  int _sortReminders(ReminderModel a, ReminderModel b) {
    if (a.active != b.active) {
      return a.active ? -1 : 1;
    }
    return a.scheduledAt.compareTo(b.scheduledAt);
  }
}

class ReminderController
    extends StateNotifier<AsyncValue<List<ReminderModel>>> {
  ReminderController({required this.repository, required this.notifications})
      : super(const AsyncValue.loading()) {
    load();
  }

  final ReminderRepository repository;
  final LocalNotificationService notifications;

  Future<void> load() async {
    try {
      final reminders = await repository.loadReminders();
      state = AsyncValue.data(reminders);
      await notifications.rescheduleActiveReminders(reminders);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addReminder({
    required String title,
    required String note,
    required DateTime scheduledAt,
    required String repeat,
  }) async {
    final current = state.valueOrNull ?? await repository.loadReminders();
    final reminder = ReminderModel(
      id: const Uuid().v4(),
      title: title.trim(),
      note: note.trim(),
      scheduledAt: scheduledAt,
      repeat: repeat,
      active: true,
      createdAt: DateTime.now(),
    );
    final updated = [...current, reminder]..sort(repository._sortReminders);
    await repository.saveReminders(updated);
    state = AsyncValue.data(updated);
    await notifications.scheduleReminder(reminder);
  }

  Future<void> toggleReminder(ReminderModel reminder, bool active) async {
    final current = state.valueOrNull ?? await repository.loadReminders();
    final updated = [
      for (final item in current)
        if (item.id == reminder.id) item.copyWith(active: active) else item,
    ]..sort(repository._sortReminders);
    await repository.saveReminders(updated);
    state = AsyncValue.data(updated);

    final changed = updated.firstWhere((item) => item.id == reminder.id);
    if (active) {
      await notifications.scheduleReminder(changed);
    } else {
      await notifications.cancelReminder(changed);
    }
  }

  Future<void> deleteReminder(ReminderModel reminder) async {
    final current = state.valueOrNull ?? await repository.loadReminders();
    final updated = current.where((item) => item.id != reminder.id).toList()
      ..sort(repository._sortReminders);
    await repository.saveReminders(updated);
    state = AsyncValue.data(updated);
    await notifications.cancelReminder(reminder);
  }

  Future<void> rescheduleActiveReminders() async {
    final current = state.valueOrNull ?? await repository.loadReminders();
    await notifications.rescheduleActiveReminders(current);
  }
}
