import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;

  int get notificationId => _notificationIdFromId(id);

  factory AnnouncementModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AnnouncementModel(
      id: doc.id,
      title: data['baslik'] as String? ?? '',
      message: data['mesaj'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'baslik': title,
      'mesaj': message,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
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
    return 200000 + hash;
  }
}
