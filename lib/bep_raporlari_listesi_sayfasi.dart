

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'bep_rapor_goruntuleme_sayfasi.dart';

class BepRaporlariListesiSayfasi extends StatefulWidget {
  const BepRaporlariListesiSayfasi({super.key});

  @override
  State<BepRaporlariListesiSayfasi> createState() => _BepRaporlariListesiSayfasiState();
}

class _BepRaporlariListesiSayfasiState extends State<BepRaporlariListesiSayfasi> {
  List<Map<String, List<Map<String, String>>>> raporlar = [];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  void _verileriYukle() async {
    final box = await Hive.openBox('bep_raporlari');
    setState(() {
      raporlar = box.values.cast<Map>().map((e) => Map<String, List<Map<String, String>>>.from(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BEP Raporları')),
      body: ListView.builder(
        itemCount: raporlar.length,
        itemBuilder: (context, index) {
          final rapor = raporlar[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text("Rapor ${index + 1}"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BepRaporGoruntulemeSayfasi(raporVerileri: rapor),
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