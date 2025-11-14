import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../data/finix_data_service.dart';

class CurrentStudent extends ChangeNotifier {
  static const _prefsBox = 'app_prefs';
  static const _key = 'currentStudentId';

  String? _currentId;
  String? get currentId => _currentId;

  Future<void> load() async {
    final box = await Hive.openBox(_prefsBox);
    _currentId = box.get(_key) as String?;
    notifyListeners();
  }

  Future<void> set(String? id) async {
    final box = await Hive.openBox(_prefsBox);
    if (id == null) {
      await box.delete(_key);
    } else {
      await box.put(_key, id);
    }
    _currentId = id;
    notifyListeners();
  }
}

// Öğrenciye özel kutu adlarını üretmek için yardımcılar
String programBoxName(String studentId) =>
    FinixDataService.scopedBox('program_bilgileri', studentId);
String cizelgeBoxName(String studentId) =>
    FinixDataService.scopedBox('cizelge_kutusu', studentId);
