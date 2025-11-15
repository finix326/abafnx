// lib/kartlar_sayfasi.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'ai/finix_ai_button.dart';
import 'app_state/current_student.dart';
import 'kart_detay_sayfasi.dart';
import 'services/finix_data_service.dart';

class KartlarSayfasi extends StatefulWidget {
  const KartlarSayfasi({super.key});

  @override
  State<KartlarSayfasi> createState() => _KartlarSayfasiState();
}

class _KartlarSayfasiState extends State<KartlarSayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('kart_dizileri');
  }

  Future<void> _yeniDiziEkle() async {
    final controller = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Kart Dizisi'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Örn: Hayvanlar'),
              ),
            ),
            const SizedBox(width: 8),
            FinixAIButton.small(
              contextDescription:
                  'Bu kart için açıklama ve kullanım yönergesi öner',
              initialText: controller.text,
              onResult: (aiText) => controller.text = aiText,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (onay == true && controller.text.trim().isNotEmpty) {
      final createdAt = DateTime.now();
      final id = createdAt.millisecondsSinceEpoch.toString();
      final box = await _boxFuture;
      final studentId = context.read<CurrentStudent>().currentId?.trim();
      final data = {
        'id': id,
        'ad': controller.text.trim(),
        'kartlar': <Map<String, dynamic>>[],
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
      final record = FinixDataService.buildRecord(
        id: id,
        module: 'kart_dizileri',
        data: data,
        studentId: studentId,
        programName: data['ad']?.toString(),
        createdAt: createdAt,
      );
      await box.put(id, record.toMap());
      unawaited(FinixDataService.saveRecord(record));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStudentId = context.watch<CurrentStudent>().currentId;

    return Scaffold(
      appBar: AppBar(title: const Text('Kart Dizileri')),
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniDiziEkle,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<Box<Map<dynamic, dynamic>>>(
        future: _boxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Kart dizileri kutusu açılamadı.'));
          }

          final box = snapshot.data!;
          return ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final diziler = <Map<String, dynamic>>[];

              for (final key in box.keys) {
                final raw = box.get(key);
                if (raw is! Map) continue;

                final record = FinixDataService.decode(
                  raw,
                  module: 'kart_dizileri',
                  fallbackStudentId: currentStudentId,
                );
                if (!FinixDataService.isRecord(raw)) {
                  unawaited(box.put(key, record.toMap()));
                }

                final ownerId = record.studentId.trim();

                final matchesStudent = (currentStudentId == null ||
                        currentStudentId.isEmpty)
                    ? ownerId.isEmpty || ownerId == 'unknown'
                    : ownerId == currentStudentId;

                if (!matchesStudent) continue;

                final normalized = Map<String, dynamic>.from(record.payload);
                normalized['id'] = normalized['id'] ?? key.toString();
                normalized['createdAt'] = normalized['createdAt'] ??
                    record.createdAt.millisecondsSinceEpoch;
                normalized['kartlar'] =
                    List<Map<String, dynamic>>.from((normalized['kartlar']
                            as List? ??
                        const [])
                        .map((e) =>
                            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)));

                diziler.add(normalized);
              }

              if (diziler.isEmpty) {
                final emptyText = (currentStudentId == null ||
                        currentStudentId.isEmpty)
                    ? 'Henüz kart dizisi eklenmedi.\nSağ alttan yeni bir tane oluştur.'
                    : 'Bu öğrenci için kart dizisi yok.\nSağ alttan yeni bir tane oluştur.';
                return Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              diziler.sort((a, b) {
                final at = (a['createdAt'] as int?) ??
                    int.tryParse((a['id'] ?? '').toString()) ?? 0;
                final bt = (b['createdAt'] as int?) ??
                    int.tryParse((b['id'] ?? '').toString()) ?? 0;
                return bt.compareTo(at);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: diziler.length,
                itemBuilder: (_, i) {
                  final data = diziler[i];
                  final kartlar = (data['kartlar'] as List).length;

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      title: Text(data['ad']?.toString() ?? 'Adsız Dizi'),
                      subtitle: Text('$kartlar kart'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KartDetaySayfasi(
                            diziId: data['id'].toString(),
                            diziAdi: data['ad']?.toString() ?? 'Adsız Dizi',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}