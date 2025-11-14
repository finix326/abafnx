// lib/hafiza_oyunu_listesi_sayfasi.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'hafiza_oyunu_model.dart';
import 'hafiza_oyunu_detay_sayfasi.dart';
import 'app_state/current_student.dart';
import 'services/finix_data_service.dart';

class HafizaOyunuListesiSayfasi extends StatefulWidget {
  const HafizaOyunuListesiSayfasi({super.key});

  @override
  State<HafizaOyunuListesiSayfasi> createState() =>
      _HafizaOyunuListesiSayfasiState();
}

class _HafizaOyunuListesiSayfasiState
    extends State<HafizaOyunuListesiSayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('hafiza_oyunlari');
  }

  Future<Box<Map<dynamic, dynamic>>> _getBox() => _boxFuture;

  Future<void> _yeniOyunOlustur() async {
    final titleController = TextEditingController(text: 'Yeni Hafıza Oyunu');
    Map<String, dynamic>? result;
    try {
      result = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) {
          int pairCount = 3; // varsayılan 3 çift (6 kart)
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Yeni Hafıza Oyunu'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Oyun adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Kaç çift olsun?'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: pairCount,
                          items: const [
                            DropdownMenuItem(
                                value: 2, child: Text('2 çift (4 kart)')),
                            DropdownMenuItem(
                                value: 3, child: Text('3 çift (6 kart)')),
                            DropdownMenuItem(
                                value: 4, child: Text('4 çift (8 kart)')),
                            DropdownMenuItem(
                                value: 5, child: Text('5 çift (10 kart)')),
                            DropdownMenuItem(
                                value: 6, child: Text('6 çift (12 kart)')),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              pairCount = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'title': titleController.text.trim(),
                        'pairCount': pairCount,
                      });
                    },
                    child: const Text('Oluştur'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
    }

    if (result == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = now.toString();

    final rawTitle = (result['title'] as String?)?.trim() ?? '';
    final oyun = HafizaOyunu(
      id: id,
      title: rawTitle.isEmpty ? 'Yeni Hafıza Oyunu' : rawTitle,
      pairCount: (result['pairCount'] as int?) ?? 3,
      imagePaths: <String>[],
      createdAt: now,
    );

    final box = await _getBox();
    final studentId = context.read<CurrentStudent>().currentId;
    final record = FinixDataService.buildRecord(
      module: 'hafiza_oyunlari',
      payload: oyun.toMap(),
      studentId: studentId,
      createdAt: oyun.createdAt,
    );

    await box.put(id, record.toMap());

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HafizaOyunuDetaySayfasi(oyunId: id),
      ),
    );
  }

  Future<void> _oyunYenidenAdlandir(String id) async {
    final box = await _getBox();
    final raw = box.get(id);
    if (raw is! Map) return;

    final record = FinixDataService.decode(
      raw,
      module: 'hafiza_oyunlari',
      fallbackStudentId: context.read<CurrentStudent>().currentId,
    );
    final oyun = HafizaOyunu.fromMap(id, record.payload);
    final controller = TextEditingController(text: oyun.title);

    final newTitle = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oyun adını düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newTitle == null) return;
    oyun.title = newTitle.isEmpty ? oyun.title : newTitle;
    final ownerId = record.studentId ??
        context.read<CurrentStudent>().currentId;
    final updated = record.copyWith(
      studentId: ownerId,
      payload: oyun.toMap(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await box.put(id, updated.toMap());
  }

  Future<void> _oyunSil(String id) async {
    // Şimdilik sadece kaydı siliyoruz, görselleri fiziksel olarak silmek
    // istersen ileride buraya ekleyebiliriz.
    final box = await _getBox();
    await box.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final currentStudentId = context.watch<CurrentStudent>().currentId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hafıza Oyunları'),
      ),
      body: FutureBuilder<Box>(
        future: _boxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Hafıza oyunu kutusu açılamadı.'));
          }

          final box = snapshot.data!;

          return ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final oyunlar = <HafizaOyunu>[];

              for (final key in box.keys) {
                final raw = box.get(key);
                if (raw is! Map) continue;

                final record = FinixDataService.decode(
                  raw,
                  module: 'hafiza_oyunlari',
                  fallbackStudentId: currentStudentId,
                );
                if (!FinixDataService.isRecord(raw)) {
                  unawaited(box.put(key, record.toMap()));
                }

                final ownerId = record.studentId?.trim();

                final matchesStudent = (currentStudentId == null ||
                        currentStudentId.isEmpty)
                    ? (ownerId == null || ownerId.isEmpty)
                    : ownerId == currentStudentId;

                if (!matchesStudent) continue;

                final id = key.toString();
                oyunlar.add(HafizaOyunu.fromMap(id, record.payload));
              }

              oyunlar.sort(
                (a, b) => b.createdAt.compareTo(a.createdAt),
              );

              if (oyunlar.isEmpty) {
                final emptyText = (currentStudentId == null ||
                        currentStudentId.isEmpty)
                    ? 'Henüz hafıza oyunu yok.\nSağ alttan yeni oluştur.'
                    : 'Bu öğrenci için hafıza oyunu yok.\nSağ alttan yeni oluştur.';
                return Center(
                  child: Text(emptyText,
                      textAlign: TextAlign.center),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: oyunlar.length,
                itemBuilder: (context, index) {
                  final oyun = oyunlar[index];
                  final totalCards = oyun.pairCount * 2;

                  final dt =
                      DateTime.fromMillisecondsSinceEpoch(oyun.createdAt);
                  final dateStr =
                      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.grid_view),
                      ),
                      title: Text(
                        oyun.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                          '$dateStr · ${oyun.pairCount} çift ($totalCards kart)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HafizaOyunuDetaySayfasi(oyunId: oyun.id),
                          ),
                        );
                      },
                      onLongPress: () async {
                        final act = await showModalBottomSheet<String>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Oyun adını düzenle'),
                                  onTap: () =>
                                      Navigator.pop(context, 'rename'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  title: const Text('Oyun sil'),
                                  onTap: () =>
                                      Navigator.pop(context, 'delete'),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                        if (act == 'rename') {
                          await _oyunYenidenAdlandir(oyun.id);
                        } else if (act == 'delete') {
                          await _oyunSil(oyun.id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniOyunOlustur,
        child: const Icon(Icons.add),
      ),
    );
  }
}