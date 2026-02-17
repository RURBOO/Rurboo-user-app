class RideBookingModel {
  final String driverName;
  final String driverPhone;
  final String carName;
  final String carNumber;
  final double rating;
  final double fare;
  final String paymentMethod;
  final double discountAmount;
  final String? couponCode;
  final DateTime? scheduledTime;
  final String? receiverName;
  final String? receiverPhone;

  RideBookingModel({
    required this.driverName,
    required this.driverPhone,
    required this.carName,
    required this.carNumber,
    required this.rating,
    required this.fare,
    required this.paymentMethod,
    this.discountAmount = 0.0,
    this.couponCode,
    this.scheduledTime,
    this.receiverName,
    this.receiverPhone,
  });
}
