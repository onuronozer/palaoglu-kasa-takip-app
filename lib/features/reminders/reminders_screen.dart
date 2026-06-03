import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/local_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/reminder_repository.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remindersState = ref.watch(reminderControllerProvider);
    final notificationService = ref.watch(localNotificationServiceProvider);
    final supported = notificationService.isSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hatırlatmalar'),
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NotificationStatusCard(
                    supported: supported,
                    onEnable: () => _enableNotifications(notificationService),
                    onTest: () => _testNotification(notificationService),
                  ),
                  const SizedBox(height: 16),
                  _AddReminderCard(
                    titleController: _titleController,
                    noteController: _noteController,
                    selectedDate: _selectedDate,
                    selectedTime: _selectedTime,
                    repeat: _repeat,
                    saving: _saving,
                    onPickDate: _pickDate,
                    onPickTime: _pickTime,
                    onRepeatChanged: (value) {
                      if (value != null) {
                        setState(() => _repeat = value);
                      }
                    },
                    onSave: _saveReminder,
                  ),
                  const SizedBox(height: 16),
                  remindersState.when(
                    loading: () => const _StateCard(
                      icon: Icons.hourglass_empty,
                      title: 'Hatırlatmalar yükleniyor',
                      message: 'Kayıtlar hazırlanıyor.',
                    ),
                    error: (_, __) => const _StateCard(
                      icon: Icons.error_outline,
                      title: 'Hatırlatmalar alınamadı',
                      message: 'Lütfen uygulamayı kapatıp tekrar açın.',
                    ),
                    data: (reminders) => _ReminderListCard(
                      reminders: reminders,
                      onToggle: (reminder, active) => ref
                          .read(reminderControllerProvider.notifier)
                          .toggleReminder(reminder, active),
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

  Future<void> _enableNotifications(
    LocalNotificationService notificationService,
  ) async {
    final granted = await notificationService.requestPermission();
    if (!mounted) {
      return;
    }
    if (!granted) {
      _showSnack('Bildirim izni verilmedi.');
      return;
    }
    await notificationService.ensureDailyReminderScheduled();
    await ref
        .read(reminderControllerProvider.notifier)
        .rescheduleActiveReminders();
    _showSnack('Bildirimler açıldı. Günlük 12:00 hatırlatması kuruldu.');
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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

  Future<void> _saveReminder() async {
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
      _showSnack('Tek seferlik hatırlatma geçmiş saate kurulamaz.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(reminderControllerProvider.notifier).addReminder(
            title: title,
            note: _noteController.text,
            scheduledAt: scheduledAt,
            repeat: _repeat,
          );
      _titleController.clear();
      _noteController.clear();
      setState(() {
        _repeat = ReminderRepeat.none;
        final next = DateTime.now().add(const Duration(hours: 1));
        _selectedDate = DateTime(next.year, next.month, next.day);
        _selectedTime = TimeOfDay(hour: next.hour, minute: next.minute);
      });
      _showSnack('Hatırlatma eklendi.');
    } catch (_) {
      _showSnack('Hatırlatma eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete(ReminderModel reminder) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Hatırlatmayı sil'),
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

    await ref
        .read(reminderControllerProvider.notifier)
        .deleteReminder(reminder);
    _showSnack('Hatırlatma silindi.');
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final message = supported
        ? 'Günlük kayıt hatırlatması her gün 12:00 için kurulur.'
        : kIsWeb
            ? 'Web sayfasında kayıt tutulur; telefon bildirimi iOS/Android uygulamasında çalışır.'
            : 'Bu cihazda yerel bildirim desteklenmiyor.';

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
                    SizedBox(height: 4),
                    Text(
                      'Dünkü ciro ve masrafları hatırlatır.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.mutedText)),
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

class _AddReminderCard extends StatelessWidget {
  const _AddReminderCard({
    required this.titleController,
    required this.noteController,
    required this.selectedDate,
    required this.selectedTime,
    required this.repeat,
    required this.saving,
    required this.onPickDate,
    required this.onPickTime,
    required this.onRepeatChanged,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String repeat;
  final bool saving;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<String?> onRepeatChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Hatırlatma',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              hintText: 'Kart ödemesi, kira, toplantı...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'İstersen kısa açıklama yaz',
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
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Kaydediliyor' : 'Hatırlatma Ekle'),
          ),
        ],
      ),
    );
  }
}

class _ReminderListCard extends StatelessWidget {
  const _ReminderListCard({
    required this.reminders,
    required this.onToggle,
    required this.onDelete,
  });

  final List<ReminderModel> reminders;
  final Future<void> Function(ReminderModel reminder, bool active) onToggle;
  final Future<void> Function(ReminderModel reminder) onDelete;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kayıtlı Hatırlatmalar',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            const Text(
              'Henüz manuel hatırlatma yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (var index = 0; index < reminders.length; index++) ...[
              _ReminderTile(
                reminder: reminders[index],
                onToggle: (active) => onToggle(reminders[index], active),
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
    required this.onToggle,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = !reminder.active || reminder.isPast;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Switch(
            value: reminder.active && !reminder.isPast,
            onChanged: reminder.isPast ? null : onToggle,
          ),
          const SizedBox(width: 8),
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
                  '${_fullDateLabel(reminder.scheduledAt)} • ${reminder.repeatLabel}',
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
                if (reminder.isPast) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Süresi geçti',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
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
