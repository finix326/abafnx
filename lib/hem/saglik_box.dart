import 'package:hive/hive.dart';

/// Sağlık modülü için kutuyu güvenli aç/kullan.
/// Her çağrıda açık değilse açar ve Box nesnesini döner.
Future<Box> ensureHealthBox() async {
  if (!Hive.isBoxOpen('health_students')) {
    try {
      return await Hive.openBox('health_students');
    } catch (_) {
      // Tekrar dene: bazen eşzamanlı açılışta race olur
      return Hive.box('health_students');
    }
  }
  return Hive.box('health_students');
}