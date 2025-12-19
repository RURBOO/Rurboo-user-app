import 'package:translator/translator.dart';

class LanguageService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translate(String text, String to) async {
    final result = await _translator.translate(text, to: to);
    return result.text;
  }

  Future<List<String>> translateList(List<String> texts, String to) async {
    return Future.wait(texts.map((t) => translate(t, to)));
  }
}
