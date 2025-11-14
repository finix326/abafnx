// lib/kartlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';
import 'kart_detay_sayfasi.dart';

class KartlarSayfasi extends StatefulWidget {
  const KartlarSayfasi({super.key});

  @override
  State<KartlarSayfasi> createState() => _KartlarSayfasiState();
}

class _KartlarSayfasiState extends State<KartlarSayfasi> {
  Box? _box;

  Future<void> _yeniDiziEkle(Box box, String studentId) async {
    final controller = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Kart Dizisi'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Örn: Hayvanlar'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (onay == true && controller.text.trim().isNotEmpty) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await box.put(id, {
        'id': id,
        'ad': controller.text.trim(),
        'kartlar': <Map<String, dynamic>>[],
        'studentId': studentId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent?>()?.currentId;
    if (currentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kart Dizileri')),
        body: const Center(child: Text('Lütfen önce bir öğrenci seçin.')),
      );
    }

    return FutureBuilder<Box>(
      future: Hive.openBox('kart_dizileri_$currentId'),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            appBar: AppBar(title: Text('Kart Dizileri')),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kart Dizileri')),
            body: Center(child: Text('${snap.error ?? 'Kutu açılamadı'}')),
          );
        }

        final box = snap.data!;
        _box ??= box;

        return Scaffold(
          appBar: AppBar(title: const Text('Kart Dizileri')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _yeniDiziEkle(box, currentId),
            child: const Icon(Icons.add),
          ),
          body: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, valueBox, _) {
              if (valueBox.isEmpty) {
                return const Center(child: Text('Henüz kart dizisi eklenmedi.'));
              }

              final keys = valueBox.keys.toList();
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: keys.length,
                itemBuilder: (_, i) {
                  final raw = valueBox.get(keys[i]);
                  if (raw is! Map) return const SizedBox.shrink();
                  final data = Map<String, dynamic>.from(raw);
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      title: Text(data['ad'] ?? 'Adsız Dizi'),
                      subtitle: Text('${(data['kartlar'] as List?)?.length ?? 0} kart'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KartDetaySayfasi(
                            diziId: data['id'],
                            diziAdi: data['ad'],
                            studentId: currentId,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}