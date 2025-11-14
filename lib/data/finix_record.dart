import 'dart:collection';

/// Uygulamadaki tüm modüller tarafından paylaşılan temel veri şeması.
class FinixRecord {
  const FinixRecord({
    required this.studentId,
    required this.module,
    required this.entityId,
    required this.title,
    required this.createdAt,
    Map<String, dynamic>? payload,
  }) : payload = payload == null
            ? const {}
            : UnmodifiableMapView<String, dynamic>(
                Map<String, dynamic>.from(payload),
              );

  final String studentId;
  final String module;
  final String entityId;
  final String title;
  final int createdAt;
  final Map<String, dynamic> payload;

  static const String _keySeparator = '::';

  static String composeKey(String studentId, String module, String entityId) =>
      '$studentId$_keySeparator$module$_keySeparator$entityId';

  String get storageKey => composeKey(studentId, module, entityId);

  FinixRecord copyWith({
    String? title,
    Map<String, dynamic>? payload,
    int? createdAt,
  }) {
    return FinixRecord(
      studentId: studentId,
      module: module,
      entityId: entityId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'module': module,
      'entityId': entityId,
      'title': title,
      'createdAt': createdAt,
      'payload': Map<String, dynamic>.from(payload),
    };
  }

  factory FinixRecord.fromMap(Map<dynamic, dynamic> raw) {
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    final payloadRaw = map['payload'];
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(
            payloadRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
        : <String, dynamic>{};

    return FinixRecord(
      studentId: (map['studentId'] ?? '').toString(),
      module: (map['module'] ?? '').toString(),
      entityId: (map['entityId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      createdAt: map['createdAt'] is int
          ? map['createdAt'] as int
          : int.tryParse('${map['createdAt'] ?? ''}') ?? 0,
      payload: payload,
    );
  }
}
