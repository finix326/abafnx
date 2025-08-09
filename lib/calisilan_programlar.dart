import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'program_detay_sayfasi.dart';

class CalisilanProgramlarSayfasi extends StatefulWidget {
  const CalisilanProgramlarSayfasi({super.key});

  @override
  State<CalisilanProgramlarSayfasi> createState() => _CalisilanProgramlarSayfasiState();
}

class _CalisilanProgramlarSayfasiState extends State<CalisilanProgramlarSayfasi> {
  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('program_bilgileri')) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final programBox = Hive.box('program_bilgileri');
    final programlar = programBox.keys.map((key) {
      final data = programBox.get(key);
      final tekrar = data['tekrarSayisi'] ?? 0;
      final genelleme = data['genellemeSayisi'] ?? 0;
      final dogruOran = data['dogruOran'] ?? '0.0';

      return {
        'program': key.toString(),
        'tekrar': tekrar.toString(),
        'genelleme': genelleme.toString(),
        'dogruYuzde': dogruOran.toString(),
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Çalışılan Programlar')),
      body: programlar.isEmpty
          ? const Center(child: Text('Henüz program eklenmemiş.'))
          : ListView.builder(
        itemCount: programlar.length,
        itemBuilder: (context, index) {
          final item = programlar[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: const Icon(Icons.assignment),
              title: Text(item['program'] ?? 'Program'),
              subtitle: Text(
                'Tekrar: ${item['tekrar']}, Genelleme: ${item['genelleme']}, Başarı: %${item['dogruYuzde']}',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProgramDetaySayfasi(
                      programAdi: item['program'] ?? '',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
