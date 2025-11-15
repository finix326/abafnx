import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../student.dart';

class CurrentStudent extends ChangeNotifier {
  static const _prefsBox = 'app_prefs';
  static const _key = 'currentStudentId';

  String? _currentId;

  /// Tercih edilen erişim noktası: aktif öğrencinin kimliği.
  String? get currentStudentId => _currentId;

  @Deprecated('currentStudentId kullanın')
  String? get currentId => _currentId;

  Student? get currentStudent {
    final id = _currentId;
    if (id == null) return null;
    if (!Hive.isBoxOpen('students')) return null;
    final box = Hive.box<Student>('students');
    return box.get(id);
  }

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
String programBoxName(String studentId) => 'program_bilgileri_$studentId';
String cizelgeBoxName(String studentId) => 'cizelge_$studentId';