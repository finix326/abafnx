import 'package:google_generative_ai/google_generative_ai.dart';

import '../data/finix_data_service.dart';
import '../data/finix_record.dart';

/// Uygulamadaki TÜM yapay zekâ çağrıları için tek beyin.
class AIEngine {
  AIEngine._();

  static GenerativeModel? _textModel;
  static late FinixDataService _dataService;

  /// main.dart içinden bir kez çağrılacak.
  static void init({
    String? apiKey,
    required FinixDataService dataService,
  }) {
    _dataService = dataService;
    if (apiKey != null && apiKey.isNotEmpty) {
      _textModel = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
    } else {
      _textModel = null;
    }
  }

  /// Genel amaçlı metin / JSON üretimi.
  static Future<String> generateText(String prompt) async {
    final model = _textModel;
    if (model == null) {
      return 'AI yapılandırılmadı.';
    }
    try {
      final response = await model.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? '';
    } catch (error) {
      return 'AI hatası: $error';
    }
  }

  /// FinixDataService üzerinden öğrenciye ait kayıtları toparlayıp
  /// analizi modele gönderir. API anahtarı yoksa özet döner.
  static Future<String> analyzeStudent(String studentId) async {
    final records =
        _dataService.fetchAll(studentId: studentId).toList(growable: false);
    if (records.isEmpty) {
      return 'Öğrenci için Finix verisi bulunamadı.';
    }

    final moduleCounts = <String, int>{};
    for (final record in records) {
      moduleCounts.update(record.module, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final buffer = StringBuffer()
      ..writeln('Öğrenci ID: $studentId')
      ..writeln('Toplam kayıt: ${records.length}')
      ..writeln('Modül dağılımı:');
    moduleCounts.forEach((module, count) {
      buffer.writeln('- $module: $count kayıt');
    });

    final preview = records.take(10).map((FinixRecord record) {
      return '${record.module} | ${record.title} | ${record.payload}';
    }).join('\n');

    final model = _textModel;
    if (model == null) {
      buffer
        ..writeln('\nAI anahtarı bulunamadığı için temel özet verildi.')
        ..writeln(preview);
      return buffer.toString();
    }

    final prompt = '''Sen özel eğitim alanında çalışan yardımcı bir yapay zekâsın.
Aşağıdaki öğrenci verilerini analiz ederek özet çıkar:
$preview
''';

    try {
      final response = await model.generateContent([
        Content.text(prompt),
      ]);
      final analysis = response.text;
      if (analysis == null || analysis.trim().isEmpty) {
        buffer.writeln('\nAI yanıtı alınamadı.');
        return buffer.toString();
      }
      return analysis;
    } catch (error) {
      buffer
        ..writeln('\nAI hatası: $error')
        ..writeln('Ham veri özeti:')
        ..writeln(preview);
      return buffer.toString();
    }
  }
}
