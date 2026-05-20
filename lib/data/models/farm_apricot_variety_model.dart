import 'package:cloud_firestore/cloud_firestore.dart';

class FarmApricotVarietyModel {
  const FarmApricotVarietyModel({
    required this.id,
    required this.name,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FarmApricotVarietyModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FarmApricotVarietyModel(
      id: doc.id,
      name: data['ad'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  FarmApricotVarietyModel copyWith({
    String? id,
    String? name,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmApricotVarietyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'ad': name,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'ad': name,
      'active': active,
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
    return null;
  }
}
