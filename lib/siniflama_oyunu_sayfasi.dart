import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';

class SiniflamaOyunuSayfasi extends StatefulWidget {
  const SiniflamaOyunuSayfasi({super.key});

  @override
  State<SiniflamaOyunuSayfasi> createState() => _SiniflamaOyunuSayfasiState();
}

class _SiniflamaOyunuSayfasiState extends State<SiniflamaOyunuSayfasi> {
  List<Map<String, dynamic>> nesneler = [
    {'ad': 'Araba', 'kategori': 'Taşıtlar', 'resim': 'assets/tasitlar/araba.png'},
    {'ad': 'Otobüs', 'kategori': 'Taşıtlar', 'resim': 'assets/tasitlar/otobus.png'},
    {'ad': 'Kamyon', 'kategori': 'Taşıtlar', 'resim': 'assets/tasitlar/kamyon.png'},
    {'ad': 'Doktor', 'kategori': 'Meslekler', 'resim': 'assets/doktor.png'},
    {'ad': 'Öğretmen', 'kategori': 'Meslekler', 'resim': 'assets/ogretmen.png'},
    {'ad': 'Polis', 'kategori': 'Meslekler', 'resim': 'assets/polis.png'},
    {'ad': 'Kedi', 'kategori': 'Diğer', 'resim': 'assets/kedi.png'},
    {'ad': 'Sepet', 'kategori': 'Diğer', 'resim': 'assets/sepet.png'},
  ];

  List<String> tasitlar = [];
  List<String> meslekler = [];

  Stopwatch kronometre = Stopwatch();
  Timer? zamanlayici;
  String gecenSure = "00:00";

  @override
  void initState() {
    super.initState();
    nesneler.shuffle();
    kronometre.start();
    zamanlayici = Timer.periodic(const Duration(seconds: 1), (_) {
      final saniye = kronometre.elapsed.inSeconds;
      setState(() {
        gecenSure =
            "${(saniye ~/ 60).toString().padLeft(2, '0')}:${(saniye % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  @override
  void dispose() {
    zamanlayici?.cancel();
    kronometre.stop();
    super.dispose();
  }

  void yenidenBaslat() {
    setState(() {
      tasitlar.clear();
      meslekler.clear();
      nesneler.shuffle();
      kronometre.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final draggableItems = nesneler
        .where((n) => !tasitlar.contains(n['ad']) && !meslekler.contains(n['ad']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınıflama Oyunu'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text('Süre: $gecenSure'),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: draggableItems.map((nesne) {
              return Draggable<String>(
                data: nesne['ad'],
                child: Image.asset(nesne['resim'], width: 80, height: 80),
                feedback: Material(
                  color: Colors.transparent,
                  child: Image.asset(nesne['resim'], width: 80, height: 80),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.5,
                  child: Image.asset(nesne['resim'], width: 80, height: 80),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSepet('Taşıtlar', tasitlar),
              _buildSepet('Meslekler', meslekler),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: yenidenBaslat,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Yeniden Başlat'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Hive veri kaydı burada yapılabilir
                  var kutu = Hive.box('program_bilgileri');
                  kutu.add({
                    'programAdi': 'Sınıflama Oyunu',
                    'tarih': DateTime.now().toIso8601String(),
                    'sure': gecenSure,
                    'dogru': tasitlar.length + meslekler.length,
                    'toplam': nesneler.length,
                    'basari': ((tasitlar.length + meslekler.length) / nesneler.length * 100).toStringAsFixed(2),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Oyun tamamlandı')),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Oyunu Bitir'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSepet(String kategori, List<String> hedefListe) {
    return DragTarget<String>(
      onWillAccept: (data) {
        final dogruKategori = nesneler.firstWhere((n) => n['ad'] == data)['kategori'];
        return dogruKategori == kategori;
      },
      onAccept: (data) {
        setState(() {
          hedefListe.add(data);
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 150,
          height: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                kategori,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...hedefListe.map((e) {
                final nesne = nesneler.firstWhere((n) => n['ad'] == e);
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(nesne['resim'], width: 50, height: 50),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}