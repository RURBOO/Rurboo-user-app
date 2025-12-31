enum VehicleType { bike, auto, car }

class FareResult {
  final double totalFare;
  final double driverEarning;
  final double platformCommission;

  FareResult({
    required this.totalFare,
    required this.driverEarning,
    required this.platformCommission,
  });
}

FareResult calculateFare({
  required VehicleType vehicleType,
  required double distanceKm,
  Map<String, dynamic>? firestoreRates,
}) {
  double baseFare;
  double perKmRate;

  double defaultBase;
  double defaultPerKm;
  String jsonKey;

  switch (vehicleType) {
    case VehicleType.bike:
      defaultBase = 40;
      defaultPerKm = 9;
      jsonKey = 'bike';
      break;

    case VehicleType.auto:
      defaultBase = 80;
      defaultPerKm = 16;
      jsonKey = 'auto';
      break;

    case VehicleType.car:
      defaultBase = 120;
      defaultPerKm = 22;
      jsonKey = 'car';
      break;
  }

  if (firestoreRates != null && firestoreRates[jsonKey] != null) {
    final data = firestoreRates[jsonKey];
    baseFare = (data['base_fare'] as num?)?.toDouble() ?? defaultBase;
    perKmRate = (data['per_km'] as num?)?.toDouble() ?? defaultPerKm;
  } else {
    baseFare = defaultBase;
    perKmRate = defaultPerKm;
  }

  double commissionPercent = 20;
  if (firestoreRates != null && firestoreRates['commission_percent'] != null) {
    commissionPercent = (firestoreRates['commission_percent'] as num)
        .toDouble();
  }

  const double includedKm = 2;

  double fare;
  if (distanceKm <= includedKm) {
    fare = baseFare;
  } else {
    final double extraKm = distanceKm - includedKm;
    fare = baseFare + (extraKm * perKmRate);
  }

  final double platformCommission = fare * (commissionPercent / 100);
  final double driverEarning = fare - platformCommission;

  return FareResult(
    totalFare: fare.roundToDouble(),
    driverEarning: driverEarning.roundToDouble(),
    platformCommission: platformCommission.roundToDouble(),
  );
}
