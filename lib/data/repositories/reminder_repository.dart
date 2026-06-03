import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/reminder_model.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(FirebaseFirestore.instance);
});

final remindersProvider = StreamProvider<List<ReminderModel>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchReminders();
});

class ReminderRepository {
  ReminderRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _firestore.collection('hatirlatmalar');

  Stream<List<ReminderModel>> watchReminders() {
    return _reminders.snapshots().map((snapshot) {
      final items = snapshot.docs.map(ReminderModel.fromDoc).toList();
      items.sort(_sortReminders);
      return items;
    });
  }

  Future<void> addReminder({
    required String title,
    required String note,
    required DateTime scheduledAt,
    required String repeat,
    required AppUser createdBy,
  }) async {
    final id = const Uuid().v4();
    final reminder = ReminderModel(
      id: id,
      title: title.trim(),
      note: note.trim(),
      scheduledAt: scheduledAt,
      repeat: repeat,
      active: true,
      createdByUid: createdBy.uid,
      createdByName: createdBy.displayName,
      createdAt: DateTime.now(),
    );
    await _reminders.doc(id).set(reminder.toCreateMap());
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await _reminders.doc(reminder.id).update(reminder.toUpdateMap());
  }

  Future<void> setReminderActive({
    required ReminderModel reminder,
    required bool active,
  }) async {
    await updateReminder(reminder.copyWith(active: active));
  }

  Future<void> deleteReminder(String id) async {
    await _reminders.doc(id).delete();
  }

  int _sortReminders(ReminderModel a, ReminderModel b) {
    if (a.active != b.active) {
      return a.active ? -1 : 1;
    }
    return a.scheduledAt.compareTo(b.scheduledAt);
  }
}
