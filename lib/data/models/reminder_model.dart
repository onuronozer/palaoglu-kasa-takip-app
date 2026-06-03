class ReminderRepeat {
  const ReminderRepeat._();

  static const none = 'none';
  static const monthly = 'monthly';

  static const all = [none, monthly];

  static String label(String value) {
    switch (value) {
      case monthly:
        return 'Her ay';
      case none:
      default:
        return 'Tek seferlik';
    }
  }
}

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.title,
    required this.note,
    required this.scheduledAt,
    required this.repeat,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String note;
  final DateTime scheduledAt;
  final String repeat;
  final bool active;
  final DateTime createdAt;

  int get notificationId => _notificationIdFromId(id);

  String get repeatLabel => ReminderRepeat.label(repeat);

  bool get isPast =>
      repeat == ReminderRepeat.none && scheduledAt.isBefore(DateTime.now());

  ReminderModel copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? scheduledAt,
    String? repeat,
    bool? active,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      repeat: repeat ?? this.repeat,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
      repeat: ReminderRepeat.all.contains(json['repeat'])
          ? json['repeat'] as String
          : ReminderRepeat.none,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'scheduledAt': scheduledAt.toIso8601String(),
      'repeat': repeat,
      'active': active,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static int _notificationIdFromId(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return 10000 + hash;
  }
}
