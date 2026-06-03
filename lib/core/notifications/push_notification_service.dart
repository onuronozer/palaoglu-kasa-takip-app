import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/push_token_repository.dart';
import 'local_notification_service.dart';

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance);
});

class PushNotificationService {
  PushNotificationService(this._messaging);

  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _registeredUid;

  bool get isSupported => !kIsWeb;

  Future<bool> registerForUser({
    required AppUser user,
    required PushTokenRepository tokenRepository,
    required LocalNotificationService localNotifications,
  }) async {
    if (!isSupported || !user.active) {
      return false;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!allowed) {
      return false;
    }

    await localNotifications.initialize();
    await _waitForApplePushToken();

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    await tokenRepository.saveToken(user: user, token: token);
    _registeredUid = user.uid;

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      tokenRepository.saveToken(user: user, token: newToken);
    });

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] as String?;
      final body = notification?.body ?? message.data['body'] as String?;
      if (title == null || title.trim().isEmpty) {
        return;
      }
      localNotifications.showPushMessage(
        id: _notificationId(message),
        title: title,
        body: body ?? '',
        payload: message.data['type'] as String?,
      );
    });

    return true;
  }

  Future<void> unregister(PushTokenRepository tokenRepository) async {
    if (!isSupported || _registeredUid == null) {
      return;
    }
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await tokenRepository.removeToken(token);
    }
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _registeredUid = null;
  }

  Future<void> _waitForApplePushToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    for (var attempt = 0; attempt < 10; attempt++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  int _notificationId(RemoteMessage message) {
    final value =
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    return value.abs() % 2147483647;
  }
}
