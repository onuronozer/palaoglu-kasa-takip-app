import 'package:cloud_firestore/cloud_firestore.dart';

class FarmFieldModel {
  const FarmFieldModel({
    required this.id,
    required this.name,
    required this.ada,
    required this.parsel,
    required this.areaSquareMeters,
    required this.treeCount,
    required this.cropNotes,
    required this.note,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ada;
  final String parsel;
  final double areaSquareMeters;
  final int treeCount;
  final String cropNotes;
  final String note;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get locationLabel {
    final parts = <String>[
      if (ada.trim().isNotEmpty) 'Ada $ada',
      if (parsel.trim().isNotEmpty) 'Parsel $parsel',
    ];
    if (parts.isEmpty) {
      return 'Konum bilgisi yok';
    }
    return parts.join(' - ');
  }

  factory FarmFieldModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmFieldModel(
      id: doc.id,
      name: data['ad'] as String? ?? '',
      ada: data['ada'] as String? ?? '',
      parsel: data['parsel'] as String? ?? '',
      areaSquareMeters: _doubleFromFirestore(data['metrekare']),
      treeCount: _intFromFirestore(data['agac_sayisi']),
      cropNotes: data['urun_cinsleri'] as String? ?? '',
      note: data['not'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  FarmFieldModel copyWith({
    String? id,
    String? name,
    String? ada,
    String? parsel,
    double? areaSquareMeters,
    int? treeCount,
    String? cropNotes,
    String? note,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmFieldModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ada: ada ?? this.ada,
      parsel: parsel ?? this.parsel,
      areaSquareMeters: areaSquareMeters ?? this.areaSquareMeters,
      treeCount: treeCount ?? this.treeCount,
      cropNotes: cropNotes ?? this.cropNotes,
      note: note ?? this.note,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'ad': name,
      'ada': ada,
      'parsel': parsel,
      'metrekare': areaSquareMeters,
      'agac_sayisi': treeCount,
      'urun_cinsleri': cropNotes,
      'not': note,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'ad': name,
      'ada': ada,
      'parsel': parsel,
      'metrekare': areaSquareMeters,
      'agac_sayisi': treeCount,
      'urun_cinsleri': cropNotes,
      'not': note,
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

  static int _intFromFirestore(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}
