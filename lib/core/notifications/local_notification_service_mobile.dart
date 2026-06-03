import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/reminder_model.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});

class LocalNotificationService {
  LocalNotificationService();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _timezoneReady = false;

  static const int dailyReminderId = 1200;

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> initialize() async {
    if (!isSupported) {
      return false;
    }
    if (_initialized) {
      return true;
    }

    _configureTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
    return true;
  }

  Future<bool> requestPermission() async {
    final ready = await initialize();
    if (!ready) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  Future<bool> areNotificationsEnabled() async {
    final ready = await initialize();
    if (!ready) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }

    return true;
  }

  Future<void> ensureDailyReminderScheduled() async {
    final granted = await requestPermission();
    if (!granted) {
      return;
    }

    await _plugin.zonedSchedule(
      dailyReminderId,
      'Günlük kayıt hatırlatması',
      'Dünkü ciro, masraf ve ödemeleri girmeyi unutmayın.',
      _nextTime(hour: 12, minute: 0),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_kiraathane_reminder',
    );
  }

  Future<void> scheduleReminder(ReminderModel reminder) async {
    if (!reminder.active) {
      await cancelReminder(reminder);
      return;
    }
    final granted = await requestPermission();
    if (!granted) {
      return;
    }

    final scheduledAt = _nextReminderTime(reminder);
    await _plugin.zonedSchedule(
      reminder.notificationId,
      reminder.title,
      reminder.note.trim().isEmpty ? 'Hatırlatma zamanı geldi.' : reminder.note,
      scheduledAt,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: reminder.repeat == ReminderRepeat.monthly
          ? DateTimeComponents.dayOfMonthAndTime
          : null,
      payload: 'manual_reminder:${reminder.id}',
    );
  }

  Future<void> cancelReminder(ReminderModel reminder) async {
    if (!isSupported) {
      return;
    }
    await initialize();
    await _plugin.cancel(reminder.notificationId);
  }

  Future<void> rescheduleActiveReminders(List<ReminderModel> reminders) async {
    if (!isSupported) {
      return;
    }
    for (final reminder in reminders) {
      if (reminder.active && !reminder.isPast) {
        await scheduleReminder(reminder);
      } else {
        await cancelReminder(reminder);
      }
    }
  }

  Future<void> showTestNotification() async {
    final granted = await requestPermission();
    if (!granted) {
      return;
    }

    await _plugin.show(
      9001,
      'Palaoğlu Yönetim',
      'Bildirimler çalışıyor.',
      _notificationDetails(),
      payload: 'test_notification',
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      'palaoglu_reminders',
      'Palaoğlu Hatırlatmalar',
      channelDescription: 'Günlük kayıt ve manuel ödeme hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  tz.TZDateTime _nextTime({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  tz.TZDateTime _nextReminderTime(ReminderModel reminder) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      reminder.scheduledAt.year,
      reminder.scheduledAt.month,
      reminder.scheduledAt.day,
      reminder.scheduledAt.hour,
      reminder.scheduledAt.minute,
    );

    if (reminder.repeat == ReminderRepeat.monthly) {
      while (!next.isAfter(now)) {
        next = tz.TZDateTime(
          tz.local,
          next.year,
          next.month + 1,
          next.day,
          next.hour,
          next.minute,
        );
      }
    }

    return next;
  }

  void _configureTimezone() {
    if (_timezoneReady) {
      return;
    }
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    _timezoneReady = true;
  }
}
