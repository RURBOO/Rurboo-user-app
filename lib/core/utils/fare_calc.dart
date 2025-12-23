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
  double baseFare = 0;
  double perKmRate = 0;

  double defaultBase = 0;
  double defaultPerKm = 0;
  String jsonKey = 'car';

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

  double commPercent = 20;
  if (firestoreRates != null && firestoreRates['commission_percent'] != null) {
    commPercent = (firestoreRates['commission_percent'] as num).toDouble();
  }

  double fare;
  double includedKm = 2;

  if (distanceKm <= includedKm) {
    fare = baseFare;
  } else {
    fare = baseFare + ((distanceKm - includedKm) * perKmRate);
  }

  double platformCommission = fare * (commPercent / 100);
  double driverEarning = fare - platformCommission;

  return FareResult(
    totalFare: fare.roundToDouble(),
    driverEarning: driverEarning.roundToDouble(),
    platformCommission: platformCommission.roundToDouble(),
  );
}
