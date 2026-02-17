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

// Default Configuration (Fallback if Firestore fails)
const Map<String, Map<String, dynamic>> _defaultRates = {
  'bike': {'base_fare': 40, 'per_km': 9, 'night_charge': 10},
  'auto': {'base_fare': 80, 'per_km': 16, 'night_charge': 20},
  'car': {'base_fare': 150, 'per_km': 25, 'night_charge': 40},
  'erickshaw': {'base_fare': 60, 'per_km': 13, 'night_charge': 15},
  'bigcar': {'base_fare': 200, 'per_km': 30, 'night_charge': 50},
  'carriertruck': {'base_fare': 250, 'per_km': 40, 'night_charge': 60},
};

FareResult calculateFare({
  required String vehicleKey, // e.g., 'bike', 'suv'
  required double distanceKm,
  Map<String, dynamic>? firestoreRates,
}) {
  double baseFare;
  double perKmRate;
  double nightCharge = 0;

  // 1. Resolve Rates
  // Priority: Firestore > Default Map > Generic Fallback (Car)

  Map<String, dynamic> rateData = {};

  if (firestoreRates != null && firestoreRates.containsKey(vehicleKey)) {
    // Online Config Found
    rateData = Map<String, dynamic>.from(firestoreRates[vehicleKey] as Map);
  } else if (_defaultRates.containsKey(vehicleKey)) {
    // Offline / Hardcoded Default Found
    rateData = _defaultRates[vehicleKey]!;
  } else {
    // Unknown Vehicle Type (e.g., 'helicopter') -> Fallback to Car rates
    rateData = _defaultRates['car']!;
  }

  baseFare = (rateData['base_fare'] as num?)?.toDouble() ?? 100.0;
  perKmRate = (rateData['per_km'] as num?)?.toDouble() ?? 20.0;
  
  // 2. Set Platform Commission (Default 20%)
  double commissionPercent = 20;
  if (firestoreRates != null && firestoreRates['commission_percent'] != null) {
    commissionPercent = (firestoreRates['commission_percent'] as num).toDouble();
  }

  // 3. Calculate Final Fare
  const double includedKm = 2; // First 2 km are free/included in base fare

  double fare;
  if (distanceKm <= includedKm) {
    fare = baseFare;
  } else {
    final double extraKm = distanceKm - includedKm;
    fare = baseFare + (extraKm * perKmRate);
  }

  // 4. Night Charge Logic (10 PM to 5 AM)
  final now = DateTime.now();
  final hour = now.hour;

  if (hour >= 22 || hour < 5) {
     nightCharge = (rateData['night_charge'] as num?)?.toDouble() ?? 0.0;
  }
  fare += nightCharge;

  // 5. Split Earnings
  final double platformCommission = fare * (commissionPercent / 100);
  final double driverEarning = fare - platformCommission;

  return FareResult(
    totalFare: fare.roundToDouble(),
    driverEarning: driverEarning.roundToDouble(),
    platformCommission: platformCommission.roundToDouble(),
  );
}
