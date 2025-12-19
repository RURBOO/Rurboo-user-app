import 'package:flutter/material.dart';
import '../../../core/services/language_service.dart';

class LanguageViewModel extends ChangeNotifier {
  final LanguageService _service;

  LanguageViewModel(this._service);

  String _language = 'en';
  bool _loading = false;
  final Map<String, String> _cache = {};

  String get language => _language;
  bool get loading => _loading;

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  Future<List<String>> translate(List<String> items) async {
    if (_language == 'en') return items;

    _loading = true;
    notifyListeners();

    List<String> output = [];

    for (final text in items) {
      final cacheKey = "$text|$_language";

      if (_cache.containsKey(cacheKey)) {
        output.add(_cache[cacheKey]!);
      } else {
        final translated = await _service.translate(text, _language);
        _cache[cacheKey] = translated;
        output.add(translated);
      }
    }

    _loading = false;
    notifyListeners();

    return output;
  }

  Map<String, List<String>> onboardingCache = {};

  Future<List<String>> translateOnboarding(List<String> items) async {
    final key = "$_language-onboarding";

    if (onboardingCache.containsKey(key)) {
      return onboardingCache[key]!;
    }

    _loading = true;
    notifyListeners();

    final list = await translate(items);
    onboardingCache[key] = list;

    _loading = false;
    notifyListeners();

    return list;
  }
}
