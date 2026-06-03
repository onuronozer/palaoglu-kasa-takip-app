import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/local_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/announcement_model.dart';
import '../../data/models/app_user.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/push_token_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../auth/auth_controller.dart';
import '../../core/notifications/push_notification_service.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _repeat = ReminderRepeat.none;
  ReminderModel? _editingReminder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resetDateTime();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remindersState = ref.watch(remindersProvider);
    final announcementsState = ref.watch(announcementsProvider);
    final notificationService = ref.watch(localNotificationServiceProvider);
    final supported = notificationService.isSupported;
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final isAdmin = appUser?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapılacak İşler'),
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NotificationStatusCard(
                    supported: supported,
                    onEnable: () => _enableNotifications(
                      notificationService: notificationService,
                      appUser: appUser,
                    ),
                    onTest: () => _testNotification(notificationService),
                  ),
                  announcementsState.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (announcements) {
                      if (announcements.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          _AnnouncementListCard(
                            announcements: announcements.take(5).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    _AddReminderCard(
                      titleController: _titleController,
                      noteController: _noteController,
                      selectedDate: _selectedDate,
                      selectedTime: _selectedTime,
                      repeat: _repeat,
                      editing: _editingReminder != null,
                      saving: _saving,
                      onPickDate: _pickDate,
                      onPickTime: _pickTime,
                      onRepeatChanged: (value) {
                        if (value != null) {
                          setState(() => _repeat = value);
                        }
                      },
                      onCancelEdit: _cancelEdit,
                      onSave: () => _saveReminder(appUser),
                    ),
                  ],
                  const SizedBox(height: 16),
                  remindersState.when(
                    loading: () => const _StateCard(
                      icon: Icons.hourglass_empty,
                      title: 'Yapılacak işler yükleniyor',
                      message: 'Kayıtlar hazırlanıyor.',
                    ),
                    error: (_, __) => const _StateCard(
                      icon: Icons.error_outline,
                      title: 'Yapılacak işler alınamadı',
                      message: 'Tekrar deneyin.',
                    ),
                    data: (reminders) => _ReminderListCard(
                      reminders: isAdmin
                          ? reminders
                          : reminders
                              .where((reminder) => reminder.active)
                              .toList(),
                      isAdmin: isAdmin,
                      onToggle: (reminder, active) => ref
                          .read(reminderRepositoryProvider)
                          .setReminderActive(
                            reminder: reminder,
                            active: active,
                          ),
                      onEdit: _startEdit,
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

  Future<void> _enableNotifications({
    required LocalNotificationService notificationService,
    required AppUser? appUser,
  }) async {
    if (appUser == null) {
      _showSnack('Oturum bulunamadı.');
      return;
    }
    final registered =
        await ref.read(pushNotificationServiceProvider).registerForUser(
              user: appUser,
              tokenRepository: ref.read(pushTokenRepositoryProvider),
              localNotifications: notificationService,
            );
    if (!mounted) {
      return;
    }
    if (!registered) {
      _showSnack('Bildirim izni verilmedi.');
      return;
    }
    _showSnack('Bildirimler açıldı.');
  }

  Future<void> _testNotification(
    LocalNotificationService notificationService,
  ) async {
    await notificationService.showTestNotification();
    if (mounted) {
      _showSnack('Test bildirimi gönderildi.');
    }
  }

  Future<void> _pickDate() async {
    final minimumDate = DateTime.now().subtract(const Duration(days: 1));
    final firstDate =
        _selectedDate.isBefore(minimumDate) ? _selectedDate : minimumDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveReminder(AppUser? appUser) async {
    if (appUser?.isAdmin != true) {
      _showSnack('Yapılacak iş eklemek için yönetici yetkisi gerekli.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('Başlık yazmalısın.');
      return;
    }

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (_repeat == ReminderRepeat.none &&
        !scheduledAt.isAfter(DateTime.now())) {
      _showSnack('Tek seferlik iş geçmiş saate kurulamaz.');
      return;
    }

    setState(() => _saving = true);
    try {
      final editing = _editingReminder;
      if (editing == null) {
        await ref.read(reminderRepositoryProvider).addReminder(
              title: title,
              note: _noteController.text,
              scheduledAt: scheduledAt,
              repeat: _repeat,
              createdBy: appUser!,
            );
        _showSnack('Yapılacak iş eklendi.');
      } else {
        await ref.read(reminderRepositoryProvider).updateReminder(
              editing.copyWith(
                title: title,
                note: _noteController.text.trim(),
                scheduledAt: scheduledAt,
                repeat: _repeat,
                active: true,
              ),
            );
        _showSnack('Yapılacak iş güncellendi.');
      }
      _clearForm();
    } catch (_) {
      _showSnack('Yapılacak iş kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _startEdit(ReminderModel reminder) {
    setState(() {
      _editingReminder = reminder;
      _titleController.text = reminder.title;
      _noteController.text = reminder.note;
      _selectedDate = DateTime(
        reminder.scheduledAt.year,
        reminder.scheduledAt.month,
        reminder.scheduledAt.day,
      );
      _selectedTime = TimeOfDay(
        hour: reminder.scheduledAt.hour,
        minute: reminder.scheduledAt.minute,
      );
      _repeat = reminder.repeat;
    });
    _showSnack('Kayıt düzenleme alanına alındı.');
  }

  void _cancelEdit() {
    _clearForm();
    _showSnack('Düzenleme iptal edildi.');
  }

  Future<void> _confirmDelete(ReminderModel reminder) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Yapılacak işi sil'),
          content: Text(
            '"${reminder.title}" silinsin mi?',
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

    await ref.read(reminderRepositoryProvider).deleteReminder(reminder.id);
    if (_editingReminder?.id == reminder.id) {
      _clearForm();
    }
    _showSnack('Yapılacak iş silindi.');
  }

  void _clearForm() {
    _titleController.clear();
    _noteController.clear();
    setState(() {
      _editingReminder = null;
      _repeat = ReminderRepeat.none;
      _resetDateTime();
    });
  }

  void _resetDateTime() {
    final next = DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(next.year, next.month, next.day);
    _selectedTime = TimeOfDay(hour: next.hour, minute: next.minute);
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

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.supported,
    required this.onEnable,
    required this.onTest,
  });

  final bool supported;
  final VoidCallback onEnable;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bank.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.bank,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bildirimler',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: supported ? onEnable : null,
                icon: const Icon(Icons.notifications_on_outlined),
                label: const Text('Bildirimleri Aç'),
              ),
              OutlinedButton.icon(
                onPressed: supported ? onTest : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Test Et'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementListCard extends StatelessWidget {
  const _AnnouncementListCard({required this.announcements});

  final List<AnnouncementModel> announcements;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Duyurular', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (var index = 0; index < announcements.length; index++) ...[
            _AnnouncementTile(announcement: announcements[index]),
            if (index != announcements.length - 1)
              const Divider(color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
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
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fullDateLabel(announcement.createdAt),
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddReminderCard extends StatelessWidget {
  const _AddReminderCard({
    required this.titleController,
    required this.noteController,
    required this.selectedDate,
    required this.selectedTime,
    required this.repeat,
    required this.editing,
    required this.saving,
    required this.onPickDate,
    required this.onPickTime,
    required this.onRepeatChanged,
    required this.onCancelEdit,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String repeat;
  final bool editing;
  final bool saving;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<String?> onRepeatChanged;
  final VoidCallback onCancelEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'Yapılacak İşi Düzenle' : 'Yeni Yapılacak İş',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (editing)
                TextButton.icon(
                  onPressed: onCancelEdit,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Vazgeç'),
                ),
            ],
          ),
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
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.calendar_month_outlined,
                  label: _dateLabel(selectedDate),
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickButton(
                  icon: Icons.schedule_outlined,
                  label: selectedTime.format(context),
                  onTap: onPickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: repeat,
            decoration: const InputDecoration(labelText: 'Tekrar'),
            items: [
              for (final item in ReminderRepeat.all)
                DropdownMenuItem(
                  value: item,
                  child: Text(ReminderRepeat.label(item)),
                ),
            ],
            onChanged: onRepeatChanged,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(editing ? Icons.done_outlined : Icons.save_outlined),
            label: Text(
              saving
                  ? 'Kaydediliyor'
                  : editing
                      ? 'Güncelle'
                      : 'Yapılacak İş Ekle',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderListCard extends StatelessWidget {
  const _ReminderListCard({
    required this.reminders,
    required this.isAdmin,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ReminderModel> reminders;
  final bool isAdmin;
  final Future<void> Function(ReminderModel reminder, bool active) onToggle;
  final ValueChanged<ReminderModel> onEdit;
  final Future<void> Function(ReminderModel reminder) onDelete;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yapılacak İş Listesi',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            const Text(
              'Henüz yapılacak iş yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (var index = 0; index < reminders.length; index++) ...[
              _ReminderTile(
                reminder: reminders[index],
                isAdmin: isAdmin,
                onToggle: (active) => onToggle(reminders[index], active),
                onEdit: () => onEdit(reminders[index]),
                onDelete: () => onDelete(reminders[index]),
              ),
              if (index != reminders.length - 1)
                const Divider(color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.isAdmin,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final bool isAdmin;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = !reminder.active || reminder.isPast;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin) ...[
            Switch(
              value: reminder.active,
              onChanged: reminder.isPast ? null : onToggle,
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.debt.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.task_alt_outlined,
                color: AppColors.debt,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    color: muted ? AppColors.mutedText : AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fullDateLabel(reminder.scheduledAt)} - ${reminder.repeatLabel}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                if (reminder.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.note,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (!reminder.active) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Pasif',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ] else if (reminder.isPast) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Süresi geçti',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Düzenle',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            ),
            IconButton(
              tooltip: 'Sil',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
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
  return '${date.day} ${AppDateUtils.monthNames[date.month - 1]} ${date.year}';
}

String _fullDateLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_dateLabel(date)} $hour:$minute';
}
