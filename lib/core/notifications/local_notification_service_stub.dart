import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/announcement_model.dart';
import '../../data/models/reminder_model.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});

class LocalNotificationService {
  LocalNotificationService();

  bool get isSupported => false;

  Stream<String> get notificationPayloads => const Stream.empty();

  Future<bool> initialize() async => false;

  Future<bool> requestPermission() async => false;

  Future<bool> areNotificationsEnabled() async => false;

  Future<void> ensureDailyReminderScheduled() async {}

  Future<void> scheduleReminder(ReminderModel reminder) async {}

  Future<void> cancelReminder(ReminderModel reminder) async {}

  Future<void> rescheduleActiveReminders(List<ReminderModel> reminders) async {}

  Future<void> showTestNotification() async {}

  Future<void> showAnnouncement(AnnouncementModel announcement) async {}
}
