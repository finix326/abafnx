// lib/hafiza_oyunu_listesi_sayfasi.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hafiza_oyunu_model.dart';
import 'hafiza_oyunu_detay_sayfasi.dart';

class HafizaOyunuListesiSayfasi extends StatefulWidget {
  const HafizaOyunuListesiSayfasi({super.key});

  @override
  State<HafizaOyunuListesiSayfasi> createState() =>
      _HafizaOyunuListesiSayfasiState();
}

class _HafizaOyunuListesiSayfasiState
    extends State<HafizaOyunuListesiSayfasi> {
  late final Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('hafiza_oyunlari');
  }

  Future<void> _yeniOyunOlustur() async {
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

    final oyun = HafizaOyunu(
      id: id,
      title: result['title'].isEmpty
          ? 'Yeni Hafıza Oyunu'
          : result['title'] as String,
      pairCount: result['pairCount'] as int,
      imagePaths: <String>[],
      createdAt: now,
    );

    await _box.put(id, oyun.toMap());

    if (!mounted) return;
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
    await _box.put(id, oyun.toMap());
  }

  Future<void> _oyunSil(String id) async {
    // Şimdilik sadece kaydı siliyoruz, görselleri fiziksel olarak silmek
    // istersen ileride buraya ekleyebiliriz.
    await _box.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hafıza Oyunları'),
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          final keys = box.keys.toList()
            ..sort((a, b) => b.toString().compareTo(a.toString()));
          if (keys.isEmpty) {
            return const Center(
              child: Text('Henüz hafıza oyunu yok.\nSağ alttan yeni oluştur.'),
            );
          }

          return ListView.builder(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final raw = (box.get(key) as Map?) ?? {};
              final oyun = HafizaOyunu.fromMap(key.toString(), raw);
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
                  subtitle:
                  Text('$dateStr · ${oyun.pairCount} çift ($totalCards kart)'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniOyunOlustur,
        child: const Icon(Icons.add),
      ),
    );
  }
}