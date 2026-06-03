import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    await ref
        .read(reminderControllerProvider.notifier)
        .rescheduleActiveReminders();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
