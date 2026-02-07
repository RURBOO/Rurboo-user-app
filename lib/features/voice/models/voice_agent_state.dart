enum VoiceAgentState {
  /// Waiting for user activation or command
  idle,

  /// Actively listening to user speech
  listening,

  /// Processing the speech (matching intent)
  processing,

  /// Speaking back to the user (TTS active)
  speaking,

  // --- Profile Creation Flows ---
  welcome,       // "Welcome to Rurboo. Want to create account?"
  askName,       // "What is your name?"
  askAge,        // "What is your age?"
  askCategory,   // "Adult, Student, or Child?"

  // --- Ride Booking Flows ---
  booking,            // "Where do you want to go?"
  confirmingFare,     // "Fare is X. Confirm?"
  searchingDriver,    // "Finding driver..."
  cancellingRide,     // "Cancelling current ride..."
  
  // --- Ride Lifecycle ---
  driverAssigned,     // "Driver found. Arriving in 5 mins."
  rideStarted,        // "Ride started."
  rideCompleted,      // "Ride finished. Thank you."

  // --- Safety ---
  sosActivated,       // "SOS triggered. Alert sent."
  
  // --- Global ---
  error,              // "Sorry, didn't understand."
}
