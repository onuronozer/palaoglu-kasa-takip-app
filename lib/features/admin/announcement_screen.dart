import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/announcement_model.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/announcement_repository.dart';
import '../auth/auth_controller.dart';

class AnnouncementScreen extends ConsumerStatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (appUser?.isAdmin != true) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(
          child: _StateCard(
            icon: Icons.lock_outline,
            title: 'Yönetici yetkisi gerekli',
            message: 'Giriş yetkisi yok.',
          ),
        ),
      );
    }

    final announcementsState = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SendAnnouncementCard(
                    titleController: _titleController,
                    messageController: _messageController,
                    sending: _sending,
                    onSend: () => _sendAnnouncement(appUser!),
                  ),
                  const SizedBox(height: 16),
                  announcementsState.when(
                    loading: () => const _StateCard(
                      icon: Icons.hourglass_empty,
                      title: 'Duyurular yükleniyor',
                      message: 'Liste hazırlanıyor.',
                    ),
                    error: (_, __) => const _StateCard(
                      icon: Icons.error_outline,
                      title: 'Duyurular alınamadı',
                      message: 'Tekrar deneyin.',
                    ),
                    data: (announcements) => _AnnouncementListCard(
                      announcements: announcements,
                      onDelete: _confirmDelete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: const Text('Duyuru Gönder'),
      leading: IconButton(
        tooltip: 'Geri',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          context.go('/overview');
        },
      ),
    );
  }

  Future<void> _sendAnnouncement(AppUser appUser) async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      _showSnack('Başlık yazmalısın.');
      return;
    }
    if (message.isEmpty) {
      _showSnack('Mesaj yazmalısın.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(announcementRepositoryProvider).addAnnouncement(
            title: title,
            message: message,
            createdBy: appUser,
          );
      _titleController.clear();
      _messageController.clear();
      _showSnack('Duyuru gönderildi.');
    } catch (_) {
      _showSnack('Duyuru gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _confirmDelete(AnnouncementModel announcement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Duyuruyu sil'),
          content: Text(
            '"${announcement.title}" silinsin mi?',
            style: const TextStyle(color: AppColors.mutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: AppColors.text,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await ref
        .read(announcementRepositoryProvider)
        .deleteAnnouncement(announcement.id);
    _showSnack('Duyuru silindi.');
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SendAnnouncementCard extends StatelessWidget {
  const _SendAnnouncementCard({
    required this.titleController,
    required this.messageController,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController titleController;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Duyuru', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Başlık',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mesaj',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.campaign_outlined),
            label: Text(sending ? 'Gönderiliyor' : 'Duyuru Gönder'),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementListCard extends StatelessWidget {
  const _AnnouncementListCard({
    required this.announcements,
    required this.onDelete,
  });

  final List<AnnouncementModel> announcements;
  final Future<void> Function(AnnouncementModel announcement) onDelete;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Son Duyurular', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (announcements.isEmpty)
            const Text(
              'Henüz duyuru yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (var index = 0; index < announcements.length; index++) ...[
              _AnnouncementTile(
                announcement: announcements[index],
                onDelete: () => onDelete(announcements[index]),
              ),
              if (index != announcements.length - 1)
                const Divider(color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.announcement,
    required this.onDelete,
  });

  final AnnouncementModel announcement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.message,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_dateLabel(announcement.createdAt)} - ${announcement.createdByName}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.expense),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${AppDateUtils.monthNames[date.month - 1]} ${date.year} $hour:$minute';
}
