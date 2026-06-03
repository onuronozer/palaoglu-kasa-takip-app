import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/announcement_model.dart';
import '../models/app_user.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(FirebaseFirestore.instance);
});

final announcementsProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  return ref.watch(announcementRepositoryProvider).watchAnnouncements();
});

class AnnouncementRepository {
  AnnouncementRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _firestore.collection('duyurular');

  Stream<List<AnnouncementModel>> watchAnnouncements() {
    return _announcements.snapshots().map((snapshot) {
      final items = snapshot.docs.map(AnnouncementModel.fromDoc).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> addAnnouncement({
    required String title,
    required String message,
    required AppUser createdBy,
  }) async {
    final id = const Uuid().v4();
    final announcement = AnnouncementModel(
      id: id,
      title: title.trim(),
      message: message.trim(),
      createdByUid: createdBy.uid,
      createdByName: createdBy.displayName,
      createdAt: DateTime.now(),
    );
    await _announcements.doc(id).set(announcement.toCreateMap());
  }

  Future<void> deleteAnnouncement(String id) async {
    await _announcements.doc(id).delete();
  }
}
