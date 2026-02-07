enum VehicleType { bike, auto, car, erickshaw, bigcar, carriertruck }

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
  // String jsonKey;

  // ==========================================
  // 🧮 LOGIC START (Start Editing Here)
  // ==========================================

  // 1. Set Rates based on Vehicle Type
  switch (vehicleType) {
    case VehicleType.bike:
      // Bike Rates - 1 seat
      defaultBase = 40; // Flat fare for first 2 km
      defaultPerKm = 9; // Cost per km after 2 km
      // jsonKey = 'bike';
      break;

    case VehicleType.auto:
      // Auto Rates - 3 seats
      defaultBase = 80;
      defaultPerKm = 16;
      // jsonKey = 'auto';
      break;

    case VehicleType.car:
      // Car Rates - 3 seats
      defaultBase = 150;
      defaultPerKm = 25;
      // jsonKey = 'car';
      break;

    case VehicleType.erickshaw:
      // E-Rickshaw Rates - 4 seats
      defaultBase = 60;
      defaultPerKm = 13;
      // jsonKey = 'erickshaw';
      break;

    case VehicleType.bigcar:
      // Big Car Rates - 5 seats
      defaultBase = 200;
      defaultPerKm = 30;
      // jsonKey = 'bigcar';
      break;

    case VehicleType.carriertruck:
      // Carrier Truck Rates - 0 seats (cargo)
      defaultBase = 250;
      defaultPerKm = 40;
      // jsonKey = 'carriertruck';
      break;
  }

  // 2. Check if Firestore (Online) rates are available
  // FIXME: User reported wrong fare logic. Forcing hardcoded values for now.
  /*
  if (firestoreRates != null && firestoreRates[jsonKey] != null) {
    final data = firestoreRates[jsonKey];
    baseFare = (data['base_fare'] as num?)?.toDouble() ?? defaultBase;
    perKmRate = (data['per_km'] as num?)?.toDouble() ?? defaultPerKm;
  } else {
    // Fallback to the defaults we set above
    baseFare = defaultBase;
    perKmRate = defaultPerKm;
  }
  */
    baseFare = defaultBase;
    perKmRate = defaultPerKm;

  // 3. Set Platform Commission (Default 20%)
  double commissionPercent = 20;
  if (firestoreRates != null && firestoreRates['commission_percent'] != null) {
    commissionPercent = (firestoreRates['commission_percent'] as num).toDouble();
  }

  // 4. Calculate Final Fare
  // Formula:
  // If distance < 2km: Only Base Fare
  // If distance > 2km: Base Fare + ((Total Distance - 2) * Per Km Rate)
  const double includedKm = 2; // First 2 km are free/included in base fare

  double fare;
  if (distanceKm <= includedKm) {
    fare = baseFare;
  } else {
    final double extraKm = distanceKm - includedKm;
    fare = baseFare + (extraKm * perKmRate);
  }

  // 6. Night Charge Logic (10 PM to 5 AM)
  // Logic: +10 for Bike, +20 for Auto, +40 for Car
  final now = DateTime.now();
  final hour = now.hour;
  double nightCharge = 0;

  if (hour >= 22 || hour < 5) {
    switch (vehicleType) {
      case VehicleType.bike:
        nightCharge = 10;
        break;
      case VehicleType.auto:
        nightCharge = 20;
        break;
      case VehicleType.car:
        nightCharge = 40;
        break;
      case VehicleType.erickshaw:
        nightCharge = 15;
        break;
      case VehicleType.bigcar:
        nightCharge = 50;
        break;
      case VehicleType.carriertruck:
        nightCharge = 60;
        break;
    }
  }
  fare += nightCharge;

  // 7. Split Earnings
  final double platformCommission = fare * (commissionPercent / 100);
  final double driverEarning = fare - platformCommission;

  return FareResult(
    totalFare: fare.roundToDouble(),
    driverEarning: driverEarning.roundToDouble(),
    platformCommission: platformCommission.roundToDouble(),
  );
}
