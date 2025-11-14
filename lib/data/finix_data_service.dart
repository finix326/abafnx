import 'package:hive/hive.dart';

import 'finix_record.dart';

/// Uygulama genelindeki verileri FinixRecord formatında tutan servis.
class FinixDataService {
  FinixDataService._();

  static const String boxName = 'finix_records';
  static final FinixDataService instance = FinixDataService._();

  /// Returns the scoped Hive box name for a student specific store.
  static String scopedBox(String baseName, String studentId) =>
      '${baseName}_$studentId';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box<dynamic> get _box => Hive.box(boxName);

  FinixRecord buildRecord({
    required String studentId,
    required String module,
    required String entityId,
    required String title,
    int? createdAt,
    Map<String, dynamic>? payload,
  }) {
    final timestamp = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    return FinixRecord(
      studentId: studentId,
      module: module,
      entityId: entityId,
      title: title,
      createdAt: timestamp,
      payload: payload ?? <String, dynamic>{},
    );
  }

  Future<void> upsert(FinixRecord record) async {
    await _box.put(record.storageKey, record.toMap());
  }

  Future<void> delete({
    required String studentId,
    required String module,
    required String entityId,
  }) async {
    await _box.delete(FinixRecord.composeKey(studentId, module, entityId));
  }

  FinixRecord? get({
    required String studentId,
    required String module,
    required String entityId,
  }) {
    final raw = _box.get(FinixRecord.composeKey(studentId, module, entityId));
    if (raw is Map) {
      return FinixRecord.fromMap(raw);
    }
    return null;
  }

  List<FinixRecord> fetchAll({String? studentId, String? module}) {
    return _box.values
        .whereType<Map>()
        .map(FinixRecord.fromMap)
        .where((record) {
          final matchesStudent =
              studentId == null || record.studentId == studentId;
          final matchesModule = module == null || record.module == module;
          return matchesStudent && matchesModule;
        })
        .toList();
  }
}
