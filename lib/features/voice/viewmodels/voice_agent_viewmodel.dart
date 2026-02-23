
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_intent_parser.dart';
import '../services/voice_agent_service.dart';
import '../services/wake_word_detector.dart';
import '../models/voice_agent_state.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/constants/app_strings.dart';

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

  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  void updateLanguage(String langCode) {
    _currentLanguage = langCode;
    notifyListeners();
  }

  String _getText(String key) {
    return AppStrings.translations[key]?[_currentLanguage] ?? key;
  }

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
      
      // Wire wake word callback
      _wakeWordDetector.onWakeWordDetected = _onWakeWordDetected;
      
      
      // Initialize language (wired via main.dart)
      _currentLanguage = 'en'; // Default, will be updated by VM sync in main.dart
      
      debugPrint("✅ Voice Agent initialized successfully with language: $_currentLanguage");
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
           speak(_getText('voice_booking_cancelled'));
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
      } else {
          speak(_getText('voice_where_to'));
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
  
  // --- Highlighting Support ---
  String? _highlightedElementId;
  String? get highlightedElementId => _highlightedElementId;
  
  bool _isAnnouncing = false;

  void stopAnnouncement() {
    if (_isAnnouncing || _state == VoiceAgentState.speaking) {
      _voiceService.stopSpeaking();
      _isAnnouncing = false;
      _highlightedElementId = null;
      notifyListeners();
    }
  }

  /// Announce all vehicle fares sequentially with highlighting
  Future<void> announceAllVehicleFares({
    required String pickup,
    required String destination,
    required double distanceKm,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    // Check announcement preference
    final announcementEnabled = await UserPreferences.getAnnouncementEnabled();
    if (!announcementEnabled) return;

    _isAnnouncing = true;
    _transitionTo(VoiceAgentState.speaking);

    // 1. Intro
    await _speakChunk(_getText('voice_pickup_is').replaceAll('{pickup}', pickup));
    if (!_isAnnouncing) return;

    await _speakChunk(_getText('voice_destination_is').replaceAll('{destination}', destination));
    if (!_isAnnouncing) return;

    await _speakChunk(_getText('voice_distance_is').replaceAll('{distance}', distanceKm.toStringAsFixed(1)));
    if (!_isAnnouncing) return;

    await _speakChunk(_getText('voice_vehicles_available'));
    if (!_isAnnouncing) return;

    // 2. Sequential Vehicle Announcements
    for (var vehicle in vehicles) {
      if (!_isAnnouncing) break;

      final name = vehicle['name'] as String;
      final fare = vehicle['id'] as String; // Use ID for highlighting
      final price = vehicle['fare'] as int;

      // Highlight this vehicle
      _highlightedElementId = fare; // Assuming ID matches keys like 'bike', 'auto'
      notifyListeners();

      await _speakChunk(_getText('voice_fare_result')
          .replaceAll('{name}', name)
          .replaceAll('{price}', price.toString()));
      
      // Small pause between items for better UX
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Reset
    _highlightedElementId = null;
    _isAnnouncing = false;
    notifyListeners();
    
    // Auto-restart listening if in continuous mode
    if (_continuousModeEnabled && _state != VoiceAgentState.sosActivated) {
        startSession();
    } else {
        _transitionTo(VoiceAgentState.idle);
        if (_wakeWordEnabled) _wakeWordDetector.startListening();
    }
  }

  Future<void> _speakChunk(String text) async {
    if (!_isAnnouncing) return;
    Completer<void> completer = Completer();
    
    await _voiceService.speakWithCompletion(text, () {
      if (!completer.isCompleted) completer.complete();
    });
    
    return completer.future;
  }

  void _triggerSOS() {
    _transitionTo(VoiceAgentState.sosActivated);
    speak(_getText('voice_sos_activated'));
  }
  
  void startProfileCreation() {
    _transitionTo(VoiceAgentState.askName);
    speak(_getText('voice_greeting'));
  }
  
  void _askAge() {
     _transitionTo(VoiceAgentState.askAge);
     speak(_getText('voice_ask_age'));
  }
  
  void _askCategory() {
    _transitionTo(VoiceAgentState.askCategory);
    speak(_getText('voice_ask_category'));
  }
  
  Future<void> _completeProfile() async {
    _transitionTo(VoiceAgentState.idle);
    await speak(_getText('voice_profile_complete').replaceAll('{name}', _tempName ?? ""));
  }
  
  void confirmBookingIntent({int? fare, double? distance, String? vehicle}) {
    _transitionTo(VoiceAgentState.confirmingFare);
    String msg = _getText('voice_confirm_booking')
        .replaceAll('{vehicle}', vehicle ?? "")
        .replaceAll('{distance}', distance?.toStringAsFixed(1) ?? "")
        .replaceAll('{fare}', fare?.toString() ?? "");
    
    speak(msg);
  }
  
  void _finalizeBooking() {
     _transitionTo(VoiceAgentState.searchingDriver);
     speak(_getText('voice_booking_finalize'));
  }

  VoiceIntent? get lastIntent => _lastIntent;

  void _handleCancelCommand() {
     speak(_getText('voice_booking_cancelled'));
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
