import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'calisilan_programlar.dart';

class VeriSayfasi extends StatefulWidget {
  const VeriSayfasi({super.key});

  @override
  State<VeriSayfasi> createState() => _VeriSayfasiState();
}

class _VeriSayfasiState extends State<VeriSayfasi> {
  final TextEditingController _programController = TextEditingController();
  final TextEditingController _tekrarController = TextEditingController();
  final TextEditingController _genellemeController = TextEditingController();

  final Box programKutusu = Hive.box('program_bilgileri');

  void _kaydet() {
    final program = _programController.text.trim();
    final tekrar = int.tryParse(_tekrarController.text.trim()) ?? 0;
    final genelleme = int.tryParse(_genellemeController.text.trim()) ?? 0;

    if (program.isNotEmpty && tekrar > 0 && genelleme > 0) {
      programKutusu.put(program, {
        'tekrarSayisi': tekrar,
        'genellemeSayisi': genelleme,
      });

      _programController.clear();
      _tekrarController.clear();
      _genellemeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Program başarıyla kaydedildi.")),
      );
    }
  }

  void _programlariGoster() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CalisilanProgramlarSayfasi(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veri Girişi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _programController,
              decoration: const InputDecoration(
                labelText: 'Program Adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tekrarController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tekrar Sayısı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _genellemeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Genelleme Sayısı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _kaydet,
              child: const Text('Kaydet'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _programlariGoster,
              child: const Text('Çalışılan Programları Gör'),
            ),
          ],
        ),
      ),
    );
  }
}
