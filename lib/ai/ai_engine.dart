import 'package:google_generative_ai/google_generative_ai.dart';

/// Uygulamadaki TÜM yapay zekâ çağrıları için tek beyin.
/// Metin / JSON üretimi buradan yapılır.
class AIEngine {
  static late final GenerativeModel _textModel;

  /// main.dart içinden bir kez çağrılacak.
  static void init(String apiKey) {
    _textModel = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
    );
  }

  /// Genel amaçlı metin / JSON üretimi.
  static Future<String> generateText(String prompt) async {
    final response = await _textModel.generateContent([
      Content.text(prompt),
    ]);

    return response.text ?? '';
  }
}