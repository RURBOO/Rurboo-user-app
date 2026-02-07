import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wake Word Detector for hands-free voice activation
/// Listens for "Hey Rurboo" or "अरे रूर्बू" to trigger full voice session
class WakeWordDetector {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  
  Function()? onWakeWordDetected;
  
  final List<String> _wakeWords = [
    'hey rurboo',
    'he rurboo', 
    'hai rurboo',
    'अरे रूर्बू',
    'रूर्बू',
    'rurboo',
  ];

  /// Initialize the wake word detector
  Future<bool> init() async {
    if (_isInitialized) return true;
    
    try {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('👂 Wake Word Status: $status'),
        onError: (error) => debugPrint('👂 Wake Word Error: ${error.errorMsg}'),
        debugLogging: kDebugMode,
      );
      
      _isInitialized = available;
      if (available) {
        debugPrint('✅ Wake Word Detector initialized');
      }
      return available;
    } catch (e) {
      debugPrint('❌ Wake Word init failed: $e');
      return false;
    }
  }

  /// Start listening for wake word in background
  Future<void> startListening() async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) return;
    }
    
    if (_isListening) return;
    
    _isListening = true;
    debugPrint('👂 Wake word detection started');
    
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        debugPrint('👂 Heard: $words');
        
        // Check if any wake word is detected
        for (final wakeWord in _wakeWords) {
          if (words.contains(wakeWord)) {
            debugPrint('🎉 Wake word detected: $wakeWord');
            onWakeWordDetected?.call();
            
            // Stop and restart listening to catch next wake word
            stopListening();
            Future.delayed(const Duration(milliseconds: 500), () {
              startListening();
            });
            break;
          }
        }
      },
      listenFor: const Duration(minutes: 60), // Long session
      pauseFor: const Duration(seconds: 5), // Longer pause for wake word
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.deviceDefault, // Low power mode
        partialResults: true,
        onDevice: true,
      ),
    );
  }

  /// Stop wake word detection
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    await _speech.stop();
    _isListening = false;
    debugPrint('👂 Wake word detection stopped');
  }

  /// Check if currently listening for wake word
  bool get isListening => _isListening;
  
  /// Cleanup resources
  Future<void> dispose() async {
    await stopListening();
  }
}
