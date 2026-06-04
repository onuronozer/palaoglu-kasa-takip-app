import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../utils/date_utils.dart';
import 'share_intent_service.dart';
import 'shared_receipt_image.dart';

class ShareIntentBootstrap extends ConsumerStatefulWidget {
  const ShareIntentBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShareIntentBootstrap> createState() =>
      _ShareIntentBootstrapState();
}

class _ShareIntentBootstrapState extends ConsumerState<ShareIntentBootstrap> {
  StreamSubscription<SharedReceiptImage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(shareIntentServiceProvider).images.listen(
          _openSharedImage,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(shareIntentServiceProvider).initialize());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _openSharedImage(SharedReceiptImage image) {
    if (!mounted) {
      return;
    }
    ref.read(sharedReceiptImageProvider.notifier).state = image;
    final monthKey = AppDateUtils.monthKey(DateTime.now());
    context.go('/ai-receipt?month=$monthKey');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
