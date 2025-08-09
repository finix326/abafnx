import 'bep_rapor_goruntuleme_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BepDuzenlemeSayfasi extends StatefulWidget {
  const BepDuzenlemeSayfasi({super.key});

  @override
  State<BepDuzenlemeSayfasi> createState() => _BepDuzenlemeSayfasiState();
}

class _BepDuzenlemeSayfasiState extends State<BepDuzenlemeSayfasi> {
  Map<String, List<Map<String, TextEditingController>>> _controllers = {
    'Dil Gelişimi': [_yeniControllerSeti()],
    'Motor Beceriler': [_yeniControllerSeti()],
    'Sosyal Etkileşim': [_yeniControllerSeti()],
    'Bilişsel Gelişim': [_yeniControllerSeti()],
    'Özbakım Becerileri': [_yeniControllerSeti()],
  };

  static Map<String, TextEditingController> _yeniControllerSeti() {
    return {
      'hedef': TextEditingController(),
      'kisa': TextEditingController(),
      'aciklama': TextEditingController(),
    };
  }

  void _kaydet() {
    final Map<String, List<Map<String, String>>> rapor = {};

    _controllers.forEach((alan, listFields) {
      final List<Map<String, String>> entries = [];
      for (var fields in listFields) {
        final hedef = fields['hedef']!.text.trim();
        final kisa = fields['kisa']!.text.trim();
        final aciklama = fields['aciklama']!.text.trim();
        if (hedef.isNotEmpty || kisa.isNotEmpty || aciklama.isNotEmpty) {
          entries.add({
            'hedef': hedef,
            'kisa': kisa,
            'aciklama': aciklama,
          });
        }
      }
      if (entries.isNotEmpty) {
        rapor[alan] = entries;
      }
    });

    if (rapor.isEmpty) return;

    final box = Hive.box('bep_raporlari');
    final now = DateTime.now().toIso8601String();
    box.put(now, rapor);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BEP Raporu kaydedildi')),
    );
  }

  @override
  void dispose() {
    for (var listFields in _controllers.values) {
      for (var field in listFields) {
        field['hedef']!.dispose();
        field['kisa']!.dispose();
        field['aciklama']!.dispose();
      }
    }
    super.dispose();
  }

  Widget _buildAlanGiris(String alan) {
    final entries = _controllers[alan]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(alan, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  entries.add(_yeniControllerSeti());
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < entries.length; i++) ...[
          TextField(
            controller: entries[i]['hedef'],
            decoration: InputDecoration(
              labelText: 'Uzun Dönemli Hedef ${i + 1}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entries[i]['kisa'],
            decoration: InputDecoration(
              labelText: 'Kısa Dönemli Hedef ${i + 1}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entries[i]['aciklama'],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Açıklama ${i + 1}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BEP Düzenleme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (var alan in _controllers.keys) _buildAlanGiris(alan),
              ElevatedButton(
                onPressed: _kaydet,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}