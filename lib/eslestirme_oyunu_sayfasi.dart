import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EslestirmeOyunuSayfasi extends StatefulWidget {
  const EslestirmeOyunuSayfasi({super.key});

  @override
  State<EslestirmeOyunuSayfasi> createState() => _EslestirmeOyunuSayfasiState();
}

class _EslestirmeOyunuSayfasiState extends State<EslestirmeOyunuSayfasi> {
  final List<Map<String, String>> _veriler = [
    {'gorsel': 'assets/kedi.png', 'etiket': 'Kedi'},
    {'gorsel': 'assets/araba.png', 'etiket': 'Araba'},
    {'gorsel': 'assets/top.png', 'etiket': 'Top'},
  ];

  late List<Map<String, String>> _karisikEtiketler;
  final Map<String, bool> _dogruEslestirmeler = {};
  bool _veriKaydiAcik = true;

  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _sureStr = "00:00";

  @override
  void initState() {
    super.initState();
    _karisikEtiketler = List<Map<String, String>>.from(_veriler)..shuffle();
    for (var item in _veriler) {
      _dogruEslestirmeler[item['etiket']!] = false;
    }
    _startTimer();
    _stopwatch.start();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _stopwatch.elapsed;
      final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _sureStr = "$minutes:$seconds";
      });
    });
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  void _yenidenBaslat() {
    setState(() {
      _karisikEtiketler.shuffle();
      for (var k in _dogruEslestirmeler.keys) {
        _dogruEslestirmeler[k] = false;
      }
      _stopwatch.reset();
      _stopwatch.start();
    });
  }

  void _oyunuBitir() {
    _stopTimer();

    if (_veriKaydiAcik) {
      final dogruSayisi = _dogruEslestirmeler.values.where((v) => v).length;
      final toplamSaniye = _stopwatch.elapsed.inSeconds;

      final now = DateTime.now();
      final tarihStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final veriKutusu = Hive.box('veri_kutusu');
      final programKutusu = Hive.box('program_bilgileri');

      // Günlük veriyi kaydet
      final key = 'Eşleştirme Oyunu-$tarihStr';
      veriKutusu.put(key, {
        'dogruSayisi': dogruSayisi,
        'toplamSure': toplamSaniye,
        'tekrar': 3,
        'genelleme': 3,
      });

      // Program bilgilerini güncelle (tek seferlik sabit tekrar ve genelleme)
      programKutusu.put('Eşleştirme Oyunu', {
        'tekrarSayisi': 3,
        'genellemeSayisi': 3,
        'dogruSayisi': dogruSayisi,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veri başarıyla kaydedildi')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Eşleştirme Oyunu"),
        actions: [
          Row(
            children: [
              const Text("Veri Kaydı"),
              Switch(
                value: _veriKaydiAcik,
                onChanged: (val) {
                  setState(() {
                    _veriKaydiAcik = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/arka_plan.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Text("Geçen Süre: $_sureStr", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _veriler.map((veri) {
                  final etiket = veri['etiket']!;
                  final gorsel = veri['gorsel']!;
                  return Draggable<String>(
                    data: etiket,
                    feedback: Image.asset(gorsel, width: 100),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: Image.asset(gorsel, width: 100),
                    ),
                    child: Image.asset(gorsel, width: 100),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _karisikEtiketler.map((veri) {
                  final etiket = veri['etiket']!;
                  return DragTarget<String>(
                    onAccept: (data) {
                      if (data == etiket) {
                        setState(() {
                          _dogruEslestirmeler[etiket] = true;
                        });
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        width: 100,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _dogruEslestirmeler[etiket] == true
                              ? Colors.green
                              : Colors.white,
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          etiket,
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _yenidenBaslat, child: const Text("Yeniden Başlat")),
                ElevatedButton(onPressed: _oyunuBitir, child: const Text("Oyunu Bitir")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
