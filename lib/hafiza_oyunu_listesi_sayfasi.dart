// lib/hafiza_oyunu_listesi_sayfasi.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'ai/ai_prompt_sheet.dart';
import 'app_state/current_student.dart';
import 'data/finix_data_service.dart';
import 'hafiza_oyunu_model.dart';
import 'hafiza_oyunu_detay_sayfasi.dart';

const String _memoryModule = 'memory_game';

class HafizaOyunuListesiSayfasi extends StatefulWidget {
  const HafizaOyunuListesiSayfasi({super.key});

  @override
  State<HafizaOyunuListesiSayfasi> createState() =>
      _HafizaOyunuListesiSayfasiState();
}

class _HafizaOyunuListesiSayfasiState
    extends State<HafizaOyunuListesiSayfasi> {
  late final Box _box;
  final FinixDataService _dataService = FinixDataService.instance;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('hafiza_oyunlari');
  }

  Future<void> _yeniOyunOlustur() async {
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
      );
      return;
    }

    int pairCount = 3; // varsayılan 3 çift (6 kart)
    final titleController = TextEditingController(text: 'Yeni Hafıza Oyunu');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
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
                    DropdownMenuItem(value: 2, child: Text('2 çift (4 kart)')),
                    DropdownMenuItem(value: 3, child: Text('3 çift (6 kart)')),
                    DropdownMenuItem(value: 4, child: Text('4 çift (8 kart)')),
                    DropdownMenuItem(value: 5, child: Text('5 çift (10 kart)')),
                    DropdownMenuItem(value: 6, child: Text('6 çift (12 kart)')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    pairCount = val;
                    (context as Element).markNeedsBuild();
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
      ),
    );

    if (result == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = now.toString();
    final title = result['title'].isEmpty
        ? 'Yeni Hafıza Oyunu'
        : result['title'] as String;
    final selectedPairCount = result['pairCount'] as int;

    final oyun = HafizaOyunu(
      id: id,
      studentId: currentId,
      title: title,
      pairCount: selectedPairCount,
      imagePaths: List<String>.filled(selectedPairCount, ''),
      createdAt: now,
    );

    await _box.put(id, oyun.toMap());

    final record = _dataService.buildRecord(
      studentId: currentId,
      module: _memoryModule,
      entityId: id,
      title: title,
      createdAt: now,
      payload: {
        'pairCount': selectedPairCount,
        'source': 'manual',
      },
    );
    await _dataService.upsert(record);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HafizaOyunuDetaySayfasi(oyunId: id),
      ),
    );
  }

  List<String> _parseAiSuggestions(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((e) => e is Map
                ? (e['title'] ?? e['label'] ?? e['value'] ?? '').toString()
                : e.toString())
            .map((e) => e.trim())
            .where((element) => element.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // JSON parse edilemezse manuel devam edeceğiz.
    }

    return trimmed
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList();
  }

  Future<void> _yeniOyunOlusturAI(String aiResponse) async {
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
      );
      return;
    }

    final suggestions = _parseAiSuggestions(aiResponse);
    int pairCount = suggestions.isNotEmpty ? suggestions.length : 3;
    pairCount = pairCount.clamp(2, 10).toInt(); // çok büyük değerleri sınırlayalım

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = now.toString();
    final title = 'AI Hafıza Oyunu';

    final oyun = HafizaOyunu(
      id: id,
      studentId: currentId,
      title: title,
      pairCount: pairCount,
      imagePaths: List<String>.filled(pairCount, ''),
      createdAt: now,
    );

    await _box.put(id, oyun.toMap());

    final payload = {
      'pairCount': pairCount,
      'source': 'ai',
      if (suggestions.isNotEmpty) 'suggestions': suggestions,
    };
    final record = _dataService.buildRecord(
      studentId: currentId,
      module: _memoryModule,
      entityId: id,
      title: title,
      createdAt: now,
      payload: payload,
    );
    await _dataService.upsert(record);

    if (!mounted) return;

    if (suggestions.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${suggestions.length} öneri hazırlandı. Kartlara görseller ekleyebilirsiniz.',
          ),
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HafizaOyunuDetaySayfasi(oyunId: id),
      ),
    );
  }

  Future<void> _oyunYenidenAdlandir(String id) async {
    final raw = (_box.get(id) as Map?) ?? {};
    final oyun = HafizaOyunu.fromMap(id, raw);
    final controller = TextEditingController(text: oyun.title);
    final studentId = oyun.studentId.isNotEmpty
        ? oyun.studentId
        : context.read<CurrentStudent>().currentId;

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
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    oyun.title = trimmed;
    await _box.put(id, oyun.toMap());

    if (studentId != null && studentId.isNotEmpty) {
      final existing = _dataService.get(
        studentId: studentId,
        module: _memoryModule,
        entityId: id,
      );
      final payload = Map<String, dynamic>.from(existing?.payload ?? {});
      payload['pairCount'] = oyun.pairCount;
      payload.putIfAbsent('source', () => 'manual');

      final record = existing ??
          _dataService.buildRecord(
            studentId: studentId,
            module: _memoryModule,
            entityId: id,
            title: oyun.title,
            createdAt: oyun.createdAt,
            payload: payload,
          );

      await _dataService.upsert(
        record.copyWith(
          title: oyun.title,
          payload: payload,
        ),
      );
    }
  }

  Future<void> _oyunSil(String id) async {
    final raw = (_box.get(id) as Map?) ?? {};
    final oyun = HafizaOyunu.fromMap(id, raw);

    // Şimdilik sadece kaydı siliyoruz, görselleri fiziksel olarak silmek
    // istersen ileride buraya ekleyebiliriz.
    await _box.delete(id);

    final targetStudentId = oyun.studentId.isNotEmpty
        ? oyun.studentId
        : context.read<CurrentStudent>().currentId;
    if (targetStudentId != null && targetStudentId.isNotEmpty) {
      await _dataService.delete(
        studentId: targetStudentId,
        module: _memoryModule,
        entityId: id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hafıza Oyunları'),
      ),
      body: currentId == null
          ? const Center(child: Text('Lütfen bir öğrenci seçin.'))
          : ValueListenableBuilder<Box>(
              valueListenable: _box.listenable(),
              builder: (context, box, _) {
                final entries = <MapEntry<String, HafizaOyunu>>[];
                for (final key in box.keys) {
                  final value = box.get(key);
                  if (value is! Map) continue;
                  var oyun = HafizaOyunu.fromMap(key.toString(), value);
                  if (oyun.studentId.isEmpty) {
                    oyun = HafizaOyunu(
                      id: oyun.id,
                      studentId: currentId,
                      title: oyun.title,
                      pairCount: oyun.pairCount,
                      imagePaths: List<String>.from(oyun.imagePaths),
                      createdAt: oyun.createdAt,
                    );
                    box.put(key, oyun.toMap());
                  }
                  if (oyun.studentId == currentId) {
                    entries.add(MapEntry(key.toString(), oyun));
                  }
                }
                entries.sort(
                  (a, b) => b.value.createdAt.compareTo(a.value.createdAt),
                );

                if (entries.isEmpty) {
                  return const Center(
                    child:
                        Text('Henüz hafıza oyunu yok.\nSağ alttan yeni oluştur.'),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final oyun = entries[index].value;
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
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'hafiza_ai',
            onPressed: () {
              showAIPromptSheet(
                context: context,
                onCompleted: _yeniOyunOlusturAI,
              );
            },
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'hafiza_manual',
            onPressed: _yeniOyunOlustur,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}