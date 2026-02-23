import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceAgentService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;

  String? _currentLocale;
  int _pauseForSeconds = 3;
  
  // Error tracking
  int _initRetryCount = 0;
  static const int _maxInitRetries = 3;
  
  // Callback to return recognized text
  Function(String)? onResult;
  Function(String)? onError;

  /// Initialize both STT and TTS with multi-locale support
  Future<bool> init() async {
    if (_isInitialized) return true;

    // 1. Request Microphone Permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("❌ Microphone permission denied");
        onError?.call("Microphone permission required");
        return false; 
      }
    }

    // 2. Initialize Speech to Text with multi-locale support
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎤 STT Status: $status');
          if (status == 'notListening' && isListening) {
            // Session ended unexpectedly, could trigger auto-restart
          }
        },
        onError: (error) {
          debugPrint('❌ STT Error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        debugLogging: kDebugMode,
      );

      if (!available) {
        debugPrint("❌ Speech Recognition Unavailable on this device");
        if (_initRetryCount < _maxInitRetries) {
          _initRetryCount++;
          await Future.delayed(Duration(seconds: _initRetryCount * 2));
          return await init(); // Retry
        }
        return false;
      }

      // Try to set preferred locale (Hindi first, then English fallbacks)
      final locales = await _speech.locales();
      final preferredLocales = ['hi_IN', 'en_IN', 'en_US', 'en_GB'];
      
      for (final preferred in preferredLocales) {
        final match = locales.firstWhere(
          (locale) => locale.localeId == preferred,
          orElse: () => locales.first,
        );
        if (match.localeId == preferred) {
          _currentLocale = preferred;
          debugPrint("✅ Using locale: $_currentLocale");
          break;
        }
      }
      
      _currentLocale ??= locales.first.localeId;
      debugPrint("✅ Speech Recognition Initialized with ${locales.length} locales");
      
    } catch (e, stack) {
      debugPrint("❌ STT Init Exception: $e");
      debugPrintStack(stackTrace: stack);
      if (_initRetryCount < _maxInitRetries) {
        _initRetryCount++;
        await Future.delayed(Duration(seconds: _initRetryCount * 2));
        return await init(); // Retry with exponential backoff
      }
      return false;
    }

    // 3. Initialize Text to Speech with enhanced configuration
    try {
      await _tts.setLanguage("hi-IN");
      await _tts.setSpeechRate(0.5); // Moderate pace for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // iOS specific settings
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
      }
      
      debugPrint("✅ Text-to-Speech Initialized");
    } catch (e) {
      debugPrint("⚠️ TTS Init warning: $e");
      // TTS failure is non-fatal, continue
    }
    
    _isInitialized = true;
    _initRetryCount = 0; // Reset on success
    return true;
  }
  
  void setCompletionHandler(VoidCallback onComplete) {
     _tts.setCompletionHandler(() {
       onComplete();
     });
  }

  /// Start Listening with enhanced configuration
  Future<bool> listen({
    required Function(String) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        debugPrint("❌ Cannot listen: Initialization failed");
        onError?.call("Voice initialization failed");
        return false;
      }
    }
    
    this.onResult = onResult;
    
    // Stop TTS if speaking before listening to avoid self-loop
    await stopSpeaking();

    try {
      await _speech.listen(
        onResult: (val) {
          if (val.recognizedWords.isNotEmpty) {
            // Stream results for real-time feedback
            onResult(val.recognizedWords);
          }
        },
        localeId: _currentLocale ?? "hi_IN",
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? Duration(seconds: _pauseForSeconds),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false, // Continue on errors
          partialResults: partialResults,
          onDevice: true, // On-device for speed & privacy
          listenMode: stt.ListenMode.confirmation, // Better accuracy
        ),
      );
      return true;
    } catch (e) {
      debugPrint("❌ Listen error: $e");
      onError?.call("Failed to start listening");
      return false;
    }
  }
  
  /// Adjust pause threshold based on environment (adaptive)
  void setAdaptivePause({required bool isNoisy}) {
    // Shorter pause in noisy environments (less likely to be true silence)
    // Longer pause in quiet environments (more confidence in silence)
    _pauseForSeconds = isNoisy ? 2 : 4;
    debugPrint("🔧 Adaptive pause set to: $_pauseForSeconds seconds");
  }
  
  /// Get available locales for user selection
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await init();
    return await _speech.locales();
  }
  
  /// Switch locale dynamically
  Future<void> setLocale(String localeId) async {
    _currentLocale = localeId;
    debugPrint("🌐 Locale changed to: $localeId");
  }

  /// Stop Listening
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Speak Text
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    
    // Stop listening if active
    // Phonetic correction for "RURBOO" so TTS pronounces it as a word
    final processedText = text.replaceAll("RURBOO", "Roor booo");
    
    await _tts.speak(processedText);
  }

  Future<void> speakWithCompletion(String text, VoidCallback onComplete) async {
    if (!_isInitialized) await init();
    if (_speech.isListening) await _speech.stop();

    // Phonetic correction for "RURBOO" so TTS pronounces it as a word
    final processedText = text.replaceAll("RURBOO", "Roor booo");

    _tts.setCompletionHandler(onComplete);
    await _tts.speak(processedText);
  }

  /// Stop Speaking (Interrupt)
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
