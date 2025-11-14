// lib/hafiza_oyunu_model.dart

class HafizaOyunu {
  final String id;
  final String studentId;
  String title;
  int pairCount; // kaç çift
  List<String> imagePaths; // her görsel 1 kez, oyun başlarken çiftlenir
  int createdAt;

  HafizaOyunu({
    required this.id,
    required this.studentId,
    required this.title,
    required this.pairCount,
    required this.imagePaths,
    required this.createdAt,
  });

  factory HafizaOyunu.fromMap(String id, Map<dynamic, dynamic> map) {
    return HafizaOyunu(
      id: id,
      studentId: (map['studentId'] ?? '').toString(),
      title: (map['title'] ?? 'Yeni Hafıza Oyunu').toString(),
      pairCount: (map['pairCount'] as int?) ?? 2,
      imagePaths:
      (map['imagePaths'] as List?)?.cast<String>() ?? <String>[],
      createdAt: (map['createdAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'title': title,
      'pairCount': pairCount,
      'imagePaths': imagePaths,
      'createdAt': createdAt,
    };
  }
}