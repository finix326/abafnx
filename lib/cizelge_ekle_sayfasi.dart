import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';
import 'cizelge_detay_resimli_sesli_sayfasi.dart';
import 'cizelge_detay_sayfasi.dart';

class CizelgeEkleSayfasi extends StatefulWidget {
  final String tur;

  const CizelgeEkleSayfasi({super.key, required this.tur});

  @override
  State<CizelgeEkleSayfasi> createState() => _CizelgeEkleSayfasiState();
}

class _CizelgeEkleSayfasiState extends State<CizelgeEkleSayfasi> {
  final TextEditingController _controller = TextEditingController();
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('cizelge_kutusu');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final ad = _controller.text.trim();
    if (ad.isEmpty) return;

    final kaydedilecekTur = widget.tur == 'yazili' ? 'yazili' : 'resimli_sesli';
    final box = await _boxFuture;
    final now = DateTime.now().millisecondsSinceEpoch;
    final studentId = context.read<CurrentStudent>().currentId?.trim();

    final data = <String, dynamic>{
      'ad': ad,
      'cizelgeAdi': ad,
      'tur': kaydedilecekTur,
      'icerik': <Map<String, dynamic>>[],
      'createdAt': now,
      'updatedAt': now,
    };
    if (studentId != null && studentId.isNotEmpty) {
      data['studentId'] = studentId;
    }

    await box.put(ad, data);

    final hedefSayfa = kaydedilecekTur == 'yazili'
        ? CizelgeDetaySayfasi(cizelgeAdi: ad, tur: kaydedilecekTur)
        : CizelgeDetayResimliSesliSayfasi(cizelgeAdi: ad);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => hedefSayfa),
    );
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
