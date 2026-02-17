import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  final String id;
  final String code;
  final double amount;
  final bool isUsed;
  final DateTime? expiryDate;
  final String type; // 'referral_bonus', 'promo'

  CouponModel({
    required this.id,
    required this.code,
    required this.amount,
    this.isUsed = false,
    this.expiryDate,
    this.type = 'referral_bonus',
  });

  factory CouponModel.fromMap(String id, Map<String, dynamic> data) {
    return CouponModel(
      id: id,
      code: data['code'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      isUsed: data['isUsed'] ?? false,
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      type: data['type'] ?? 'referral_bonus',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'amount': amount,
      'isUsed': isUsed,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'type': type,
    };
  }
}
