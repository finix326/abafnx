import 'package:hive/hive.dart';

class FinixRecord {
  static const String flagKey = '_finixRecord';

  final String module;
  final String? studentId;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int updatedAt;
  final Map<String, dynamic>? metadata;

  const FinixRecord({
    required this.module,
    required this.studentId,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      flagKey: true,
      'module': module,
      if (studentId != null && studentId!.trim().isNotEmpty)
        'studentId': studentId!.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'payload': Map<String, dynamic>.from(payload),
      if (hasMetadata) 'meta': Map<String, dynamic>.from(metadata!),
    };
  }

  FinixRecord copyWith({
    String? module,
    String? studentId,
    Map<String, dynamic>? payload,
    int? createdAt,
    int? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FinixRecord(
      module: module ?? this.module,
      studentId: studentId ?? this.studentId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class FinixDataService {
  const FinixDataService._();

  static FinixRecord buildRecord({
    required String module,
    required Map<String, dynamic> payload,
    String? studentId,
    int? createdAt,
    int? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedCreatedAt = createdAt ?? now;
    final normalizedUpdatedAt = updatedAt ?? now;

    return FinixRecord(
      module: module,
      studentId: (studentId != null && studentId.trim().isNotEmpty)
          ? studentId.trim()
          : null,
      payload: Map<String, dynamic>.from(payload),
      createdAt: normalizedCreatedAt,
      updatedAt: normalizedUpdatedAt,
      metadata: metadata,
    );
  }

  static bool isRecord(dynamic raw) {
    return raw is Map && raw[FinixRecord.flagKey] == true;
  }

  static FinixRecord decode(
    dynamic raw, {
    required String module,
    String? fallbackStudentId,
  }) {
    if (raw is FinixRecord) return raw;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (raw is Map) {
      if (isRecord(raw)) {
        final payloadRaw = raw['payload'];
        final metaRaw = raw['meta'];
        return FinixRecord(
          module: (raw['module'] as String?)?.trim().isNotEmpty == true
              ? raw['module'].toString()
              : module,
          studentId: (raw['studentId'] as String?)?.trim().isNotEmpty == true
              ? raw['studentId'].toString().trim()
              : fallbackStudentId?.trim(),
          payload: payloadRaw is Map
              ? Map<String, dynamic>.from(payloadRaw)
              : <String, dynamic>{},
          createdAt: (raw['createdAt'] as int?) ?? now,
          updatedAt: (raw['updatedAt'] as int?) ??
              (raw['createdAt'] as int?) ??
              now,
          metadata: metaRaw is Map
              ? Map<String, dynamic>.from(metaRaw)
              : null,
        );
      }

      final legacy = Map<String, dynamic>.from(raw);
      final studentId = legacy.remove('studentId') as String?;
      final createdAt = (legacy['createdAt'] as int?) ?? now;
      final updatedAt = (legacy['updatedAt'] as int?) ?? createdAt;

      return FinixRecord(
        module: module,
        studentId: (studentId != null && studentId.trim().isNotEmpty)
            ? studentId.trim()
            : fallbackStudentId?.trim(),
        payload: legacy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }

    return FinixRecord(
      module: module,
      studentId: fallbackStudentId?.trim(),
      payload: const <String, dynamic>{},
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<void> migrateIfNeeded(
    Box<Map<dynamic, dynamic>> box,
    dynamic key,
    Map<dynamic, dynamic>? value, {
    required String module,
    String? fallbackStudentId,
  }) async {
    if (value == null) return;
    if (isRecord(value)) return;

    final record = decode(
      Map<String, dynamic>.from(value),
      module: module,
      fallbackStudentId: fallbackStudentId,
    );
    await box.put(key, record.toMap());
  }

  static String? extractStudentId(
    Map<dynamic, dynamic>? raw, {
    required String module,
    String? fallbackStudentId,
  }) {
    if (raw == null) return fallbackStudentId;
    return decode(raw, module: module, fallbackStudentId: fallbackStudentId)
        .studentId;
  }

  static Map<String, dynamic> extractPayload(
    Map<dynamic, dynamic>? raw, {
    required String module,
    String? fallbackStudentId,
  }) {
    if (raw == null) return <String, dynamic>{};
    return decode(raw, module: module, fallbackStudentId: fallbackStudentId)
        .payload;
  }
}
