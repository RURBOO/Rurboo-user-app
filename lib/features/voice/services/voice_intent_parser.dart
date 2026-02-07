class VoiceIntentParser {
  
  VoiceIntent parse(String text) {
    final lower = text.toLowerCase().trim();
    
    // 1. Safety (High Priority)
    if (_isSafety(lower)) {
      return VoiceIntent(type: IntentType.safety);
    }

    // 2. Cancellation / Stop
    if (_isCancellation(lower)) {
      return VoiceIntent(type: IntentType.cancel);
    }
    
    // 3. Actions (Call, Share, OTP) - NEW
    if (_isAction(lower)) {
       if (lower.contains("share") || lower.contains("bhejo") || lower.contains("send")) {
          return VoiceIntent(type: IntentType.shareRide);
       }
       if (lower.contains("call") || lower.contains("phone")) {
          return VoiceIntent(type: IntentType.callDriver);
       }
    }

    // 4. Queries (Fare, Time, Driver, OTP) - NEW
    if (_isQuery(lower)) {
       if (lower.contains("otp") || lower.contains("code") || lower.contains("pin")) {
          return VoiceIntent(type: IntentType.queryOTP);
       }
       if (lower.contains("kahan") || lower.contains("where") || lower.contains("location")) {
          return VoiceIntent(type: IntentType.queryDriverLocation);
       }
       if (lower.contains("kiraya") || lower.contains("fare") || lower.contains("price") || lower.contains("paisa") || lower.contains("cost")) {
           return VoiceIntent(type: IntentType.queryFare);
       }
       if (lower.contains("kab") || lower.contains("time") || lower.contains("der") || lower.contains("eta")) {
           return VoiceIntent(type: IntentType.queryETA);
       }
    }
    
    // 5. Confirmation (Yes/No)
    if (_isConfirmation(lower)) {
      return VoiceIntent(type: IntentType.confirm);
    }
    
    if (_isRejection(lower)) {
      return VoiceIntent(type: IntentType.reject);
    }

    // 6. Booking / Vehicle Selection
    final vehicleData = _extractVehicle(lower);
    final vehicle = vehicleData['vehicle'];
    final negatedVehicle = vehicleData['negated'];
    
    // 7. Destination Extraction
    // Check for Shortcuts first
    String? destination = _extractShortcut(lower);
    destination ??= _extractDestination(text);

    // 8. Generic Booking Intent Check
    if (vehicle != null || destination != null || _isBookingIntent(lower)) {
      return VoiceIntent(
        type: IntentType.booking,
        vehicle: vehicle,
        negatedVehicle: negatedVehicle,
        destination: destination,
        rawText: text,
      );
    }
    
    // 9. Profile Creation specific
    if (_isProfileIntent(lower)) {
        return VoiceIntent(type: IntentType.createProfile);
    }

    return VoiceIntent(type: IntentType.unknown, rawText: text);
  }

  // --- Matchers ---

  bool _isSafety(String text) {
    return text.contains("madad") || 
           text.contains("bachao") || 
           text.contains("sos") || 
           text.contains("help") || 
           text.contains("emergency") ||
           text.contains("khatra");
  }

  bool _isCancellation(String text) {
    // "Bike nahi chahiye" is handled via Booking Intent with negatedVehicle
    // This is for cancelling the ENTIRE process
    return text.contains("cancel") || 
           text.contains("radd") || 
           text.contains("ruko") || 
           text.contains("stop") || 
           text.contains("dont book");
  }
  
  bool _isAction(String text) {
     return text.contains("share") || 
            text.contains("bhejo") || 
            text.contains("send") || 
            text.contains("call") || 
            text.contains("phone") || 
            text.contains("baat");
  }
  
  bool _isQuery(String text) {
     return text.contains("otp") || 
            text.contains("code") || 
            text.contains("pin") ||
            text.contains("kahan") || 
            text.contains("where") ||
            text.contains("kiraya") || 
            text.contains("fare") || 
            text.contains("price") || 
            text.contains("paisa") || 
            text.contains("cost") || 
            text.contains("kab") || 
            text.contains("time") || 
            text.contains("der") || 
            text.contains("eta");
  }
  
  bool _isConfirmation(String text) {
    return text.contains("haan") || 
           text.contains("yes") || 
           text.contains("sahi") || 
           text.contains("thik") || 
           text.contains("kar do") ||
           text.contains("confirm") ||
           text.contains("ok") ||
           text == "ji";
  }
  
  bool _isRejection(String text) {
    // Pure rejection "No", "Nahi"
    return text == "nahi" || text == "no" || text.contains("mat karo") || text.contains("galat");
  }

  bool _isBookingIntent(String text) {
    return text.contains("book") || 
           text.contains("jana hai") || 
           text.contains("chalo") || 
           text.contains("ride") || 
           text.contains("le chalo") ||
           text.contains("drop") ||
           text.contains("gadi") ||
           text.contains("ghar"); // Home shortcut
  }
  
  bool _isProfileIntent(String text) {
      return text.contains("account") || 
             text.contains("profile") || 
             text.contains("banana") ||
             text.contains("panjikaran");
  }

  Map<String, String?> _extractVehicle(String text) {
    // Return { 'vehicle': 'Auto', 'negated': 'Bike' }
    String? vehicle;
    String? negated;

    final vehicles = {
      'auto': ['auto', 'rickshaw', 'tempo', 'tuk tuk', 'ऑटो', 'रिक्शा', 'टेंपो'],
      'bike': ['bike', 'moto', 'motorcycle', 'scooty', 'do pahiya', 'बाइक', 'मोटरसाइकिल', 'स्कूटी'],
      'car': ['car', 'taxi', 'cab', 'gadi', 'four wheeler', 'कार', 'टैक्सी', 'गाड़ी', 'कैब'],
    };

    vehicles.forEach((key, synonyms) {
      for (var s in synonyms) {
        // 1. Direct Match
        bool match = text.contains(s);
        
        // 2. Fuzzy Match (if direct failed, try Levenshtein on words)
        if (!match) {
           final words = text.split(" ");
           for (var w in words) {
              if (_calculateLevenshtein(w, s) <= 2 && s.length > 3) {
                 match = true; // "Boke" -> "Bike"
                 break;
              }
           }
        }

        if (match) {
           // Check for negation near the word
           // regex: (nahi|no|dont)\s+(want\s+)?{word} OR {word}\s+(nahi|no)
           bool isNegated = text.contains("no $s") || 
                            text.contains("$s nahi") || 
                            text.contains("dont want $s") ||
                            text.contains("$s नहीं") || 
                            text.contains("नहीं $s"); 
                            
           if (isNegated) {
             negated = _capitalize(key);
           } else {
             vehicle = _capitalize(key);
           }
        }
      }
    });

    return {'vehicle': vehicle, 'negated': negated};
  }
  
  // Minimal Levenshtein Distance Implementation
  int _calculateLevenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  String? _extractShortcut(String text) {
      if (text.contains("ghar") || text.contains("home")) return "Home";
      if (text.contains("office") || text.contains("work") || text.contains("kaam")) return "Work";
      return null;
  }

  String? _extractDestination(String text) {
    // String lower = text.toLowerCase(); // Unused
    
    // 1. "to [Place]"
    // 2. "[Place] tak"
    // 3. "[Place] jana hai"
    // 4. "[Place] chalo"

    // Patterns prioritized
    final patterns = [
      RegExp(r'\bto\s+(.+)', caseSensitive: false), // "to Station"
      RegExp(r'(.+)\s+tak', caseSensitive: false),  // "Station tak"
      RegExp(r'(.+)\s+jana\s+hai', caseSensitive: false), // "Station jana hai"
      RegExp(r'(.+)\s+chalo', caseSensitive: false), // "Station chalo"
      RegExp(r'drop\s+at\s+(.+)', caseSensitive: false), // "Drop at Station"
      
      // Hindi Devanagari Support
      RegExp(r'(.+)\s+तक', caseSensitive: false),  // "Station तक"
      RegExp(r'(.+)\s+जाना\s+है', caseSensitive: false), // "Station जाना है"
      RegExp(r'(.+)\s+चलो', caseSensitive: false), // "Station चलो"
    ];

    for (var p in patterns) {
      final match = p.firstMatch(text); // Use original text for casing
      if (match != null) {
        String dest = match.group(1) ?? "";
        return _cleanDestination(dest);
      }
    }
    
    return null;
  }
  
  String _cleanDestination(String raw) {
      // Remove common noise words from the extracted chunk
      // e.g. "Mujhe Station" -> "Station"
      String clean = raw.replaceAll(RegExp(r'\b(mujhe|humko|please|kindly|want|book|ride|auto|bike|car|gadi)\b', caseSensitive: false), "");
      clean = clean.replaceAll("  ", " ").trim();
      
      // Stop at common connectors if captured
      // e.g. "Station se" -> "Station"
      if (clean.endsWith(" se")) clean = clean.substring(0, clean.length - 3);
      
      return clean.trim();
  }
  
  String _capitalize(String s) => "${s[0].toUpperCase()}${s.substring(1)}";
}

enum IntentType {
  booking,
  cancel,
  confirm,
  reject,
  safety,
  createProfile,
  
  // Advanced Intents
  shareRide,
  callDriver,
  queryOTP,
  queryFare,
  queryETA,
  queryDriverLocation,
  
  unknown
}

class VoiceIntent {
  final IntentType type;
  final String? vehicle;
  final String? negatedVehicle; // e.g. "Bike nahi"
  final String? destination;
  final String? rawText;

  VoiceIntent({
    required this.type, 
    this.vehicle, 
    this.negatedVehicle,
    this.destination, 
    this.rawText
  });
  
  @override
  String toString() => "Intent: $type, Vehicle: $vehicle (Not: $negatedVehicle), Dest: $destination";
}
