import 'package:cloud_firestore/cloud_firestore.dart';

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
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String note;
  final DateTime scheduledAt;
  final String repeat;
  final bool active;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

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
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      repeat: repeat ?? this.repeat,
      active: active ?? this.active,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ReminderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReminderModel(
      id: doc.id,
      title: data['baslik'] as String? ?? '',
      note: data['not'] as String? ?? '',
      scheduledAt: _dateFromFirestore(data['scheduledAt']) ?? DateTime.now(),
      repeat: ReminderRepeat.all.contains(data['repeat'])
          ? data['repeat'] as String
          : ReminderRepeat.none,
      active: data['active'] as bool? ?? true,
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'baslik': title,
      'not': note,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'repeat': repeat,
      'active': active,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'id': id,
      'baslik': title,
      'not': note,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'repeat': repeat,
      'active': active,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
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
