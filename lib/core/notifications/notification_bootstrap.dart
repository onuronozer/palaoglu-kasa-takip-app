import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/push_token_repository.dart';
import '../../features/auth/auth_controller.dart';
import 'local_notification_service.dart';
import 'push_notification_service.dart';

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
    try {
      await _registerPushToken();
    } catch (_) {
      // Push hazırlığı gecikirse uygulama açılışını engelleme.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentAppUserProvider, (previous, next) {
      next.whenData((_) => _registerPushToken());
    });
    return widget.child;
  }

  Future<void> _registerPushToken() async {
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (user == null) {
      return;
    }
    await ref.read(pushNotificationServiceProvider).registerForUser(
          user: user,
          tokenRepository: ref.read(pushTokenRepositoryProvider),
          localNotifications: ref.read(localNotificationServiceProvider),
        );
  }
}
