import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cizelge_detay_sayfasi.dart';
import 'cizelge_detay_resimli_sesli_sayfasi.dart';

class CizelgeEkleSayfasi extends StatefulWidget {
  final String tur;

  const CizelgeEkleSayfasi({super.key, required this.tur});

  @override
  State<CizelgeEkleSayfasi> createState() => _CizelgeEkleSayfasiState();
}

class _CizelgeEkleSayfasiState extends State<CizelgeEkleSayfasi> {
  final TextEditingController _controller = TextEditingController();
  final Box _box = Hive.box('cizelge_kutusu');

  void _kaydet() {
    final ad = _controller.text.trim();
    if (ad.isNotEmpty) {
      // 🔧 Türü yalnızca "yazili" ya da "resimli_sesli" olarak kaydet
      final kaydedilecekTur = widget.tur == 'yazili' ? 'yazili' : 'resimli_sesli';

      _box.put(ad, {'tur': kaydedilecekTur, 'icerik': []});

      Widget hedefSayfa;
      if (kaydedilecekTur == 'yazili') {
        hedefSayfa = CizelgeDetaySayfasi(cizelgeAdi: ad, tur: kaydedilecekTur);
      } else {
        hedefSayfa = CizelgeDetayResimliSesliSayfasi(cizelgeAdi: ad);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => hedefSayfa),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final turYazi = widget.tur == 'yazili' ? 'Yazılı' : 'Resimli/Sesli';

    return Scaffold(
      appBar: AppBar(title: Text('Yeni Çizelge ($turYazi)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Çizelge Adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _kaydet,
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
