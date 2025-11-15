import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class FinixRecord {
  static const String flagKey = '_finixRecord';
  static const String storageBox = 'finix_records';

  final String id;
  final String studentId;
  final String module;
  final String? programName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> data;

  const FinixRecord({
    required this.id,
    required this.studentId,
    required this.module,
    this.programName,
    required this.createdAt,
    required this.updatedAt,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      flagKey: true,
      'id': id,
      'studentId': studentId,
      'module': module,
      if (programName != null && programName!.trim().isNotEmpty)
        'programName': programName!.trim(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'data': Map<String, dynamic>.from(data),
    };
  }

  FinixRecord copyWith({
    String? id,
    String? studentId,
    String? module,
    String? programName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? data,
  }) {
    return FinixRecord(
      id: (id ?? this.id).trim(),
      studentId: _normalizeStudentId(studentId) ?? this.studentId,
      module: (module ?? this.module).trim(),
      programName: _normalizeProgramName(programName) ?? this.programName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data != null
          ? Map<String, dynamic>.from(data)
          : Map<String, dynamic>.from(this.data),
    );
  }

  Map<String, dynamic> get payload => data;

  static String? _normalizeStudentId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? '' : trimmed;
  }

  static String? _normalizeProgramName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class FinixDataService {
  FinixDataService._();

  static final Uuid _uuid = const Uuid();
  static const String _analyticsKeySeparator = '::';

  static Future<Box<Map<dynamic, dynamic>>> _openAnalyticsBox() {
    return Hive.openBox<Map<dynamic, dynamic>>(FinixRecord.storageBox);
  }

  static FinixRecord buildRecord({
    required String module,
    required Map<String, dynamic> data,
    String? studentId,
    String? programName,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    final normalizedCreatedAt = createdAt ?? now;
    final normalizedUpdatedAt = updatedAt ?? normalizedCreatedAt;

    final normalizedStudentId = studentId?.trim();

    return FinixRecord(
      id: (id?.trim().isNotEmpty ?? false) ? id!.trim() : _uuid.v4(),
      studentId: (normalizedStudentId != null && normalizedStudentId.isNotEmpty)
          ? normalizedStudentId
          : 'unknown',
      module: module.trim(),
      programName: _normalizeProgramName(programName),
      createdAt: normalizedCreatedAt,
      updatedAt: normalizedUpdatedAt,
      data: Map<String, dynamic>.from(data),
    );
  }

  static bool isRecord(dynamic raw) {
    return raw is Map && raw[FinixRecord.flagKey] == true;
  }

  static FinixRecord decode(
    dynamic raw, {
    required String module,
    String? fallbackStudentId,
    String? fallbackProgramName,
    String? fallbackId,
  }) {
    if (raw is FinixRecord) return raw;

    final now = DateTime.now();

    if (raw is Map) {
      if (isRecord(raw)) {
        final payloadRaw = raw['data'] ?? raw['payload'];
        final createdAtRaw = raw['createdAt'];
        final updatedAtRaw = raw['updatedAt'];
        return FinixRecord(
          id: _resolveId(raw['id'], fallbackId),
          studentId: _resolveStudentId(
            raw['studentId'],
            fallbackStudentId,
          ),
          module: _resolveModule(raw['module'], module),
          programName: _normalizeProgramName(
            raw['programName'] as String?,
          ),
          createdAt: _coerceDateTime(createdAtRaw) ?? now,
          updatedAt: _coerceDateTime(updatedAtRaw) ??
              (_coerceDateTime(createdAtRaw) ?? now),
          data: payloadRaw is Map
              ? Map<String, dynamic>.from(
                  payloadRaw.cast<dynamic, dynamic>(),
                )
              : <String, dynamic>{},
        );
      }

      final legacy = Map<String, dynamic>.from(
        raw.cast<dynamic, dynamic>(),
      );
      final studentId = legacy.remove('studentId') as String?;
      final programName = legacy.remove('programName') as String?;
      final createdAt = legacy['createdAt'];
      final updatedAt = legacy['updatedAt'];

      return FinixRecord(
        id: _resolveId(legacy['id'], fallbackId),
        studentId: _resolveStudentId(studentId, fallbackStudentId),
        module: module.trim(),
        programName: _normalizeProgramName(programName),
        createdAt: _coerceDateTime(createdAt) ?? now,
        updatedAt: _coerceDateTime(updatedAt) ??
            (_coerceDateTime(createdAt) ?? now),
        data: legacy,
      );
    }

    return FinixRecord(
      id: _resolveId(null, fallbackId),
      studentId: _resolveStudentId(null, fallbackStudentId),
      module: module.trim(),
      programName: _normalizeProgramName(fallbackProgramName),
      createdAt: now,
      updatedAt: now,
      data: const <String, dynamic>{},
    );
  }

  static Future<void> saveRecord(FinixRecord record) async {
    final box = await _openAnalyticsBox();
    final key = _composeAnalyticsKey(record.module, record.id);
    await box.put(key, record.toMap());
  }

  static Future<List<FinixRecord>> getRecords({
    String? studentId,
    String? module,
    String? programName,
  }) async {
    final box = await _openAnalyticsBox();
    final results = <FinixRecord>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      final record = decode(
        value,
        module: module ?? (value['module'] as String? ?? 'unknown'),
      );

      if (studentId != null && studentId.isNotEmpty) {
        if (record.studentId != studentId.trim()) continue;
      }
      if (module != null && module.isNotEmpty) {
        if (record.module != module.trim()) continue;
      }
      if (programName != null && programName.isNotEmpty) {
        if ((record.programName ?? '') != programName.trim()) continue;
      }
      results.add(record);
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  static Future<void> deleteRecord(String module, String id) async {
    final box = await _openAnalyticsBox();
    final key = _composeAnalyticsKey(module, id);
    await box.delete(key);
  }

  static Future<void> migrateIfNeeded(
    Box<Map<dynamic, dynamic>> box,
    dynamic key,
    Map<dynamic, dynamic>? value, {
    required String module,
    String? fallbackStudentId,
    String? fallbackProgramName,
  }) async {
    if (value == null) return;
    if (isRecord(value)) return;

    final record = decode(
      Map<String, dynamic>.from(value),
      module: module,
      fallbackStudentId: fallbackStudentId,
      fallbackProgramName: fallbackProgramName,
      fallbackId: key?.toString(),
    );
    await box.put(key, record.toMap());
  }

  static String? extractStudentId(
    Map<dynamic, dynamic>? raw, {
    required String module,
    String? fallbackStudentId,
  }) {
    if (raw == null) return fallbackStudentId;
    return decode(
      raw,
      module: module,
      fallbackStudentId: fallbackStudentId,
    ).studentId;
  }

  static Map<String, dynamic> extractPayload(
    Map<dynamic, dynamic>? raw, {
    required String module,
    String? fallbackStudentId,
  }) {
    if (raw == null) return <String, dynamic>{};
    return decode(
      raw,
      module: module,
      fallbackStudentId: fallbackStudentId,
    ).data;
  }

  static String _composeAnalyticsKey(String module, String id) {
    return '${module.trim()}$_analyticsKeySeparator${id.trim()}';
  }

  static String _resolveId(dynamic rawId, String? fallbackId) {
    final idValue = (rawId is String ? rawId : fallbackId)?.trim();
    if (idValue != null && idValue.isNotEmpty) return idValue;
    return _uuid.v4();
  }

  static String _resolveStudentId(dynamic raw, String? fallback) {
    final rawString = raw is String ? raw.trim() : fallback?.trim();
    if (rawString != null && rawString.isNotEmpty) return rawString;
    return 'unknown';
  }

  static String _resolveModule(dynamic raw, String fallback) {
    final rawString = raw is String ? raw.trim() : fallback.trim();
    return rawString.isEmpty ? fallback.trim() : rawString;
  }

  static DateTime? _coerceDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      final millis = int.tryParse(trimmed);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: false);
      }
    }
    return null;
  }

  static String? _normalizeProgramName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
