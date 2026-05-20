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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get productLabel {
    if (productVariety.trim().isEmpty) {
      return productName;
    }
    return '$productName - $productVariety';
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
      'createdAt': FieldValue.serverTimestamp(),
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
}
