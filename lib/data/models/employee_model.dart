import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.name,
    required this.salary,
    required this.active,
    required this.updatedByUid,
    required this.updatedByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double salary;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String updatedByUid;
  final String updatedByName;

  factory EmployeeModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EmployeeModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      salary: _doubleFromFirestore(data['salary']),
      active: data['active'] as bool? ?? true,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
      updatedByUid: data['updatedByUid'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? '',
    );
  }

  EmployeeModel copyWith({
    String? id,
    String? name,
    double? salary,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedByUid,
    String? updatedByName,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      salary: salary ?? this.salary,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'name': name,
      'salary': salary,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'salary': salary,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
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

  static double _doubleFromFirestore(Object? value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}
