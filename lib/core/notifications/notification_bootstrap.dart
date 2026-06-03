import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import 'local_notification_service.dart';

class NotificationBootstrap extends ConsumerStatefulWidget {
  const NotificationBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationBootstrap> createState() =>
      _NotificationBootstrapState();
}

class _NotificationBootstrapState extends ConsumerState<NotificationBootstrap> {
  static bool _started = false;
  static bool _announcementsPrimed = false;
  static Set<String> _knownAnnouncementIds = {};

  @override
  void initState() {
    super.initState();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareNotifications();
    });
  }

  Future<void> _prepareNotifications() async {
    await ref
        .read(localNotificationServiceProvider)
        .ensureDailyReminderScheduled();
    if (!mounted) {
      return;
    }
    try {
      final reminders = await ref.read(remindersProvider.future);
      if (!mounted) {
        return;
      }
      await ref
          .read(localNotificationServiceProvider)
          .rescheduleActiveReminders(reminders);
    } catch (_) {
      // Firestore gecikirse uygulama açılışını engelleme.
    }

    try {
      final announcements = await ref.read(announcementsProvider.future);
      _primeAnnouncements(announcements);
    } catch (_) {
      // Duyuru akışı gecikirse uygulama açılışını engelleme.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(remindersProvider, (previous, next) {
      next.whenData((reminders) {
        ref
            .read(localNotificationServiceProvider)
            .rescheduleActiveReminders(reminders);
      });
    });
    ref.listen(announcementsProvider, (previous, next) {
      next.whenData(_notifyNewAnnouncements);
    });
    return widget.child;
  }

  void _primeAnnouncements(List<AnnouncementModel> announcements) {
    _knownAnnouncementIds = announcements.map((item) => item.id).toSet();
    _announcementsPrimed = true;
  }

  Future<void> _notifyNewAnnouncements(
    List<AnnouncementModel> announcements,
  ) async {
    final ids = announcements.map((item) => item.id).toSet();
    if (!_announcementsPrimed) {
      _knownAnnouncementIds = ids;
      _announcementsPrimed = true;
      return;
    }

    final newItems = announcements
        .where((item) => !_knownAnnouncementIds.contains(item.id))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _knownAnnouncementIds = ids;

    for (final item in newItems) {
      await ref.read(localNotificationServiceProvider).showAnnouncement(item);
    }
  }
}
