// lib/kart_dizileri_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'kart_detay_sayfasi.dart';

class KartDizileriSayfasi extends StatefulWidget {
  const KartDizileriSayfasi({super.key});

  @override
  State<KartDizileriSayfasi> createState() => _KartDizileriSayfasiState();
}

class _KartDizileriSayfasiState extends State<KartDizileriSayfasi> {
  late Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('kart_dizileri');
  }

  Future<void> _yeniDiziEkle() async {
    final controller = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Kart Dizisi'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Örn: Renkler'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (onay == true && controller.text.trim().isNotEmpty) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await _box.put(id, {'id': id, 'ad': controller.text.trim(), 'kartlar': []});
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _box.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kart Dizileri')),
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniDiziEkle,
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('Henüz kart dizisi eklenmedi.'));
          }

          final keys = box.keys.toList();
          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final data = Map<String, dynamic>.from(box.get(keys[i]));
              return ListTile(
                title: Text(data['ad'] ?? 'Adsız Dizi'),
                subtitle: Text('${(data['kartlar'] as List).length} kart'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KartDetaySayfasi(
                      diziId: data['id'],
                      diziAdi: data['ad'],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}