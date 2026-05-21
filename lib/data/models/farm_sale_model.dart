import 'package:cloud_firestore/cloud_firestore.dart';

class FarmSaleModel {
  const FarmSaleModel({
    required this.id,
    required this.merchantId,
    required this.date,
    required this.productName,
    required this.productVariety,
    required this.amountKg,
    required this.priceTl,
    required this.totalAmount,
    this.seasonYear = 0,
    this.fieldId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String merchantId;
  final String date;
  final String productName;
  final String productVariety;
  final double amountKg;
  final double priceTl;
  final double totalAmount;
  final int seasonYear;
  final String fieldId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get resolvedSeasonYear {
    if (seasonYear > 0) {
      return seasonYear;
    }
    return _seasonFromDateKey(date);
  }

  String get productLabel {
    if (productVariety.trim().isEmpty) {
      return productName;
    }
    return '$productName - $productVariety';
  }

  FarmSaleModel copyWith({
    String? id,
    String? merchantId,
    String? date,
    String? productName,
    String? productVariety,
    double? amountKg,
    double? priceTl,
    double? totalAmount,
    int? seasonYear,
    String? fieldId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmSaleModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      date: date ?? this.date,
      productName: productName ?? this.productName,
      productVariety: productVariety ?? this.productVariety,
      amountKg: amountKg ?? this.amountKg,
      priceTl: priceTl ?? this.priceTl,
      totalAmount: totalAmount ?? this.totalAmount,
      seasonYear: seasonYear ?? this.seasonYear,
      fieldId: fieldId ?? this.fieldId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FarmSaleModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmSaleModel(
      id: doc.id,
      merchantId: data['tuccar_id'] as String? ?? '',
      date: data['tarih'] as String? ?? '',
      productName: data['urun_adi'] as String? ?? '',
      productVariety: data['urun_cesidi'] as String? ?? '',
      amountKg: _doubleFromFirestore(data['miktar_kg']),
      priceTl: _doubleFromFirestore(data['fiyat_tl']),
      totalAmount: _doubleFromFirestore(data['toplam_tutar']),
      seasonYear: _intFromFirestore(data['sezon_yili']),
      fieldId: data['tarla_id'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'id': id,
      'tuccar_id': merchantId,
      'tarih': date,
      'urun_adi': productName,
      'urun_cesidi': productVariety,
      'miktar_kg': amountKg,
      'fiyat_tl': priceTl,
      'toplam_tutar': totalAmount,
      'sezon_yili': resolvedSeasonYear,
      'tarla_id': fieldId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'tuccar_id': merchantId,
      'tarih': date,
      'urun_adi': productName,
      'urun_cesidi': productVariety,
      'miktar_kg': amountKg,
      'fiyat_tl': priceTl,
      'toplam_tutar': totalAmount,
      'sezon_yili': resolvedSeasonYear,
      'tarla_id': fieldId,
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

  static int _seasonFromDateKey(String value) {
    if (value.length >= 4) {
      return int.tryParse(value.substring(0, 4)) ?? DateTime.now().year;
    }
    return DateTime.now().year;
  }
}
