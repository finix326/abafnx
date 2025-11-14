// lib/kart_model.dart
import 'package:hive/hive.dart';

part 'kart_model.g.dart'; // Hive için otomatik oluşturulacak

@HiveType(typeId: 15)
class KartModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String baslik;

  @HiveField(2)
  String? resimYolu;

  @HiveField(3)
  String? sesYolu;

  @HiveField(4)
  String studentId;

  KartModel({
    required this.id,
    required this.baslik,
    this.resimYolu,
    this.sesYolu,
    required this.studentId,
  });
}