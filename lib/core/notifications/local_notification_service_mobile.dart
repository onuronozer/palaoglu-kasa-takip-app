import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/announcement_model.dart';
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
  static final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  static bool _initialized = false;
  static bool _timezoneReady = false;
  static bool _launchPayloadHandled = false;

  static const int dailyReminderId = 1200;
  static const String _scheduledReminderIdsKey =
      'palaoglu_scheduled_reminder_ids_v1';

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Stream<String> get notificationPayloads => _payloadController.stream;

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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _emitPayload(response.payload);
      },
    );
    if (!_launchPayloadHandled) {
      _launchPayloadHandled = true;
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _emitPayload(launchDetails?.notificationResponse?.payload);
      }
    }
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
      return await android?.requestNotificationsPermission() ?? true;
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
      'Günlük ciro hatırlatması',
      'Bugünün cirosunu girmeyi unutma.',
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
      reminder.note.trim().isEmpty
          ? 'Yapılacak iş zamanı geldi.'
          : reminder.note,
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
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final knownIds = (prefs.getStringList(_scheduledReminderIdsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final targetReminders = reminders
        .where((reminder) => reminder.active && !reminder.isPast)
        .toList();
    final targetIds =
        targetReminders.map((reminder) => reminder.notificationId).toSet();

    for (final staleId in knownIds.difference(targetIds)) {
      await _plugin.cancel(staleId);
    }

    for (final reminder in reminders) {
      if (reminder.active && !reminder.isPast) {
        await scheduleReminder(reminder);
      } else {
        await cancelReminder(reminder);
      }
    }

    await prefs.setStringList(
      _scheduledReminderIdsKey,
      targetIds.map((id) => '$id').toList(),
    );
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

  Future<void> showAnnouncement(AnnouncementModel announcement) async {
    final granted = await requestPermission();
    if (!granted) {
      return;
    }

    await _plugin.show(
      announcement.notificationId,
      announcement.title,
      announcement.message.trim().isEmpty
          ? 'Yeni duyuru var.'
          : announcement.message,
      _notificationDetails(),
      payload: 'announcement:${announcement.id}',
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      'palaoglu_reminders',
      'Palaoğlu Yapılacak İşler',
      channelDescription: 'Günlük ciro ve yapılacak iş bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
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

  void _emitPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    _payloadController.add(payload);
  }
}
