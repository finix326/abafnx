import 'package:hive/hive.dart';
part 'student.g.dart';

@HiveType(typeId: 100) // Projende boş bir typeId kullan
class Student extends HiveObject {
  @HiveField(0)
  final String id;     // uuid

  @HiveField(1)
  final String ad;     // görünen ad

  @HiveField(2)
  final String? veliAd;

  @HiveField(3)
  final String? not;

  Student({
    required this.id,
    required this.ad,
    this.veliAd,
    this.not,
  });
}