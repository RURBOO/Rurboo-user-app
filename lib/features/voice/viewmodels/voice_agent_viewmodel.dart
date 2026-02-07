import 'package:flutter/material.dart';
import '../services/voice_intent_parser.dart';
import '../services/voice_agent_service.dart';
import '../services/wake_word_detector.dart';
import '../models/voice_agent_state.dart';
import '../../../core/services/user_preferences.dart';

class VoiceAgentViewModel extends ChangeNotifier {
  final VoiceAgentService _voiceService = VoiceAgentService();
  final VoiceIntentParser _parser = VoiceIntentParser();
  final WakeWordDetector _wakeWordDetector = WakeWordDetector();

  VoiceAgentState _state = VoiceAgentState.idle;
  VoiceAgentState get state => _state;
  
  bool _wakeWordEnabled = false;
  bool get wakeWordEnabled => _wakeWordEnabled;
  
  bool _continuousModeEnabled = false;
  bool get continuousModeEnabled => _continuousModeEnabled;

  String _lastRecognizedText = "";
  String get lastRecognizedText => _lastRecognizedText;
  
  String? _lastError;
  String? get lastError => _lastError;

  // Context-specific data holders
  String? _tempName;
  String? _tempAge;
  String? _tempCategory;
  String? _tempDestination;
  String? get tempDestination => _tempDestination;
  
  String? get tempName => _tempName;
  String? get tempAge => _tempAge;
  String? get tempCategory => _tempCategory;
  
  // Real-time Intent Data
  VoiceIntent? _lastIntent;
  
  int _sessionRetryCount = 0;
  static const int _maxSessionRetries = 2;

  // --- Initialization ---
  Future<void> init() async {
    try {
      final success = await _voiceService.init();
      if (!success) {
        debugPrint("❌ Voice Agent: Service initialization failed");
        _lastError = "Voice service unavailable";
        return;
      }
      
      // Set up error callback
      _voiceService.onError = _handleServiceError;
      _voiceService.onResult = _handleSpeechResult;
      
      // Initialize wake word detector
      await _wakeWordDetector.init();
      _wakeWordDetector.onWakeWordDetected = _onWakeWordDetected;
      
      debugPrint("✅ Voice Agent initialized successfully");
    } catch (e) {
      debugPrint("❌ Voice Agent Init Error: $e");
      _lastError = e.toString();
    }
  }
  
  /// Enable/Disable wake word detection
  Future<void> toggleWakeWord(bool enabled) async {
    _wakeWordEnabled = enabled;
    
    if (enabled) {
      await _wakeWordDetector.startListening();
      debugPrint("🎤 Wake word detection enabled");
    } else {
      await _wakeWordDetector.stopListening();
      debugPrint("🔇 Wake word detection disabled");
    }
    
    notifyListeners();
  }
  
  /// Toggle continuous conversation mode
  void toggleContinuousMode(bool enabled) {
    _continuousModeEnabled = enabled;
    debugPrint("🔄 Continuous mode: ${enabled ? 'ON' : 'OFF'}");
    notifyListeners();
  }
  
  /// Called when wake word is detected
  void _onWakeWordDetected() {
    debugPrint("🎉 Wake word detected! Starting full session...");
    
    // Stop wake word listening temporarily
    _wakeWordDetector.stopListening();
    
    // Start full voice session
    startSession();
  }
  
  void _handleServiceError(String error) {
    _lastError = error;
    debugPrint("🔴 Voice Service Error: $error");
    
    // Auto-recovery: If in listening state and error occurs, try restart
    if (_state == VoiceAgentState.listening && _sessionRetryCount < _maxSessionRetries) {
      _sessionRetryCount++;
      Future.delayed(Duration(seconds: 2), () {
        if (_state == VoiceAgentState.listening) {
          startSession(); // Auto-retry
        }
      });
    } else {
      _transitionTo(VoiceAgentState.error);
      notifyListeners();
    }
  }

  // --- Core State Machine ---
  
  void startSession() {
    if (_state == VoiceAgentState.speaking) {
      stopSpeaking();
      return;
    }
    
    _lastError = null;
    _transitionTo(VoiceAgentState.listening);
    
    _voiceService.listen(onResult: _handleSpeechResult).then((success) {
      if (!success) {
        debugPrint("❌ Failed to start listening");
        _transitionTo(VoiceAgentState.error);
      } else {
        _sessionRetryCount = 0; // Reset on successful start
      }
    });
  }

  void stopSession() {
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    
    // In continuous mode, don't go idle - restart listening
    if (_continuousModeEnabled) {
      debugPrint("🔄 Continuous mode: Restarting listening...");
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_state != VoiceAgentState.idle) {
          startSession();
        }
      });
    } else {
      _transitionTo(VoiceAgentState.idle);
      
      // Restart wake word detection if enabled
      if (_wakeWordEnabled) {
        _wakeWordDetector.startListening();
      }
    }
  }

  void stopSpeaking() {
    _voiceService.stopSpeaking();
    _transitionTo(VoiceAgentState.listening); 
    _voiceService.listen(onResult: _handleSpeechResult);
  }

  // --- Speech Handling ---

  void _handleSpeechResult(String text) {
    _lastRecognizedText = text;
    notifyListeners();
    
    // Parse Intent dynamically
    _lastIntent = _parser.parse(text);
    _processIntent(_lastIntent!);
  }

  void _processIntent(VoiceIntent intent) {
    debugPrint("🧠 Voice Intent: $intent");

    // 1. GLOBAL GUARDS
    if (intent.type == IntentType.safety) {
      _triggerSOS();
      return;
    }

    if (intent.type == IntentType.cancel) {
       // If currently speaking, just stop speaking
       if (_state == VoiceAgentState.speaking) {
         stopSpeaking();
         return;
       }
       _handleCancelCommand();
       return;
    }

    // 2. State-Specific Logic
    switch (_state) {
      case VoiceAgentState.welcome:
        if (intent.type == IntentType.createProfile || intent.type == IntentType.confirm) {
          startProfileCreation();
        }
        break;

      case VoiceAgentState.askName:
        if (intent.rawText != null && intent.rawText!.trim().isNotEmpty) { 
           // Better Name extraction needed? For now, raw text is okay.
           _tempName = intent.rawText!.trim();
           notifyListeners();
           _askAge();
        }
        break;
        
      case VoiceAgentState.askAge:
        final age = RegExp(r'\d+').firstMatch(intent.rawText ?? "")?.group(0);
        if (age != null) {
          _tempAge = age; 
           _askCategory();
        } 
        break;

      case VoiceAgentState.askCategory:
        final lower = intent.rawText?.toLowerCase() ?? "";
        if (lower.contains("adult") || lower.contains("bada")) {
          _tempCategory = "Adult";
        } else if (lower.contains("student")) {
          _tempCategory = "Student";
        } else if (lower.contains("child")) {
          _tempCategory = "Child";
        }
        
        if (_tempCategory != null) {
          _completeProfile();
        }
        break;

      case VoiceAgentState.booking:
      case VoiceAgentState.idle:
      case VoiceAgentState.listening:
          if (intent.type == IntentType.booking) {
             _handleBookingIntent(intent);
          }
          break;

      case VoiceAgentState.confirmingFare:
         if (intent.type == IntentType.confirm) {
           _finalizeBooking();
         } else if (intent.type == IntentType.reject) {
           speak("Booking cancel kar di hai.");
           _transitionTo(VoiceAgentState.idle);
         }
         break;
         
      default:
         break;
    }
  }

  void _handleBookingIntent(VoiceIntent intent) {
      // Logic for extracted entities
      
      // 1. Destination Extraction
      if (intent.destination != null) {
          _tempDestination = intent.destination;
          // Notify UI to update destination map logic
      }
      
      // 2. Vehicle Selection
      if (intent.vehicle != null) {
          // Notify UI to select vehicle
      }
      
      if (_tempDestination != null) {
          // If we have destination, check fares
          // This part requires binding to RideSelectionViewModel.
          // Since we can't inject it easily here without context,
          // the View (Widget) will listen to this VM and bridge the gap.
          // We just set the state to "Processing" or "Updating".
      } else {
          speak("Kahan jaana hai?");
          _transitionTo(VoiceAgentState.booking);
      }
  }

  // --- Actions ---

  void _transitionTo(VoiceAgentState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    // Check announcement preference
    final announcementEnabled = await UserPreferences.getAnnouncementEnabled();
    if (!announcementEnabled) {
      debugPrint("🔇 Announcements disabled, skipping: $text");
      return;
    }
    
    _transitionTo(VoiceAgentState.speaking);
    await _voiceService.speakWithCompletion(text, () {
      if (_state != VoiceAgentState.sosActivated) {
        // In continuous mode, automatically restart listening after speaking
        if (_continuousModeEnabled) {
          startSession();
        } else {
          _transitionTo(VoiceAgentState.idle);
          
          // Restart wake word if enabled
          if (_wakeWordEnabled) {
            _wakeWordDetector.startListening();
          }
        }
      }
    });
  }
  
  /// Announce all vehicle fares sequentially
  Future<void> announceAllVehicleFares({
    required String pickup,
    required String destination,
    required double distanceKm,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    // Build comprehensive announcement
    String announcement = "";
    
    // 1. Pickup and Destination
    announcement += "Aapka pickup location hai $pickup. ";
    announcement += "Destination hai $destination. ";
    
    // 2. Distance
    announcement += "Doori hai ${distanceKm.toStringAsFixed(1)} kilometer. ";
    
    // 3. All vehicle fares
    announcement += "Available vehicles aur unka kiraya hai. ";
    
    for (var vehicle in vehicles) {
      final name = vehicle['name'] as String;
      final fare = vehicle['fare'] as int;
      announcement += "$name ka kiraya $fare rupay. ";
    }
    
    await speak(announcement);
  }

  void _triggerSOS() {
    _transitionTo(VoiceAgentState.sosActivated);
    _voiceService.speak("Emergency alert bhej diya gaya hai. Help is on the way.");
  }
  
  void startProfileCreation() {
    _transitionTo(VoiceAgentState.askName);
    speak("Namaste. RURBOO me swagat hai. Apna poora naam batayein?");
  }
  
  void _askAge() {
     _transitionTo(VoiceAgentState.askAge);
     speak("Aapki umar kya hai?");
  }
  
  void _askCategory() {
    _transitionTo(VoiceAgentState.askCategory);
    speak("Aap kya hain? Student, Adult, ya Senior?");
  }
  
  Future<void> _completeProfile() async {
    _transitionTo(VoiceAgentState.idle);
    await speak("Profile ban gayi hai. Shukriya $_tempName.");
  }
  
  void confirmBookingIntent({int? fare, double? distance, String? vehicle}) {
    _transitionTo(VoiceAgentState.confirmingFare);
    String msg = "";
    if (vehicle != null) msg += "$vehicle available hai.";
    if (distance != null) msg += " Distance ${distance.toStringAsFixed(1)} kilometer.";
    if (fare != null) msg += " Kiraya $fare rupay hoga.";
    msg += " Confirm karein?";
    
    speak(msg);
  }
  
  void _finalizeBooking() {
     _transitionTo(VoiceAgentState.searchingDriver);
     speak("Auto book ho raha hai. Please wait.");
  }

  VoiceIntent? get lastIntent => _lastIntent;

  void _handleCancelCommand() {
     speak("Booking cancel kar di gayi hai.");
     _transitionTo(VoiceAgentState.cancellingRide);
     Future.delayed(const Duration(seconds: 3), () {
        if (_state == VoiceAgentState.cancellingRide) {
          _transitionTo(VoiceAgentState.idle);
        }
     });
  }

  void consumeIntent() {
    _lastIntent = null;
    _tempDestination = null;
    _tempName = null;
    _tempAge = null;
    _tempCategory = null;
    // Don't change state here, let the UI decide if it wants to transition
    // But usually we go back to idle or listening
  }
  
  @override
  void dispose() {
    _wakeWordDetector.dispose();
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }
}
