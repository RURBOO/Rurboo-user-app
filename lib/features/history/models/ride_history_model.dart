import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/safe_parser.dart';

class RideHistoryModel {
  final String rideId;
  final String destinationAddress;
  final String pickupAddress;
  final double fare;
  final String status;
  final DateTime createdAt;
  final String rideType;

  RideHistoryModel({
    required this.rideId,
    required this.destinationAddress,
    required this.pickupAddress,
    required this.fare,
    required this.status,
    required this.createdAt,
    required this.rideType,
  });

  factory RideHistoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return RideHistoryModel(
      rideId: doc.id,
      destinationAddress: SafeParser.toStr(data['destinationAddress']),
      pickupAddress: SafeParser.toStr(data['pickupAddress']),
      fare: SafeParser.toDouble(data['fare']),
      status: SafeParser.toStr(data['status']),
      rideType: SafeParser.toStr(data['rideType']),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
