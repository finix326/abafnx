import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';

class CizelgeDetaySayfasi extends StatefulWidget {
  final String cizelgeAdi;
  final String tur; // 'yazili'

  const CizelgeDetaySayfasi({
    super.key,
    required this.cizelgeAdi,
    required this.tur,
  });

  @override
  State<CizelgeDetaySayfasi> createState() => _CizelgeDetaySayfasiState();
}

class _CizelgeDetaySayfasiState extends State<CizelgeDetaySayfasi> {
  Box? _box;
  final PageController _pageController = PageController();

  final List<String> _icerik = [];
  final List<Color> _renkler = [];

  Future<Box> _openBox(BuildContext context) async {
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null || currentId.isEmpty) {
      return Future.error('Öğrenci seçimi bulunamadı');
    }
    return Hive.openBox('cizelge_kutusu_$currentId');
  }

  Future<void> _yukle(Box box) async {
    final veri = box.get(widget.cizelgeAdi);
    final list = (veri is Map) ? veri['icerik'] : null;
    _icerik
      ..clear()
      ..addAll(List<String>.from(list ?? const []));
    if (_icerik.isEmpty) _icerik.add('');
    _renkler
      ..clear()
      ..addAll(List<Color>.generate(_icerik.length, (_) => Colors.white));
    setState(() {});
  }

  void _yeniKartEkle() {
    setState(() {
      _icerik.add('');
      _renkler.add(Colors.white);
    });
  }

  Future<void> _kaydet() async {
    final box = _box;
    if (box == null) return;
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null || currentId.isEmpty) return;
    final eski = (box.get(widget.cizelgeAdi) as Map?) ?? {};
    await box.put(widget.cizelgeAdi, {
      ...eski,
      'tur': 'yazili',
      'icerik': _icerik,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'studentId': currentId,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  void _renkSec(int i, Color c) {
    setState(() => _renkler[i] = (_renkler[i] == c) ? Colors.white : c);
  }

  Widget _renkButonlari(int i) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        icon: const Icon(Icons.check, color: Colors.green),
        onPressed: () => _renkSec(i, Colors.green),
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.red),
        onPressed: () => _renkSec(i, Colors.red),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box>(
      future: _openBox(context),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.cizelgeAdi)),
            body: Center(child: Text('${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.cizelgeAdi)),
            body: const Center(child: Text('Kutu açılamadı')),
          );
        }
        if (_box == null) {
          _box = snap.data!;
          _yukle(_box!);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.cizelgeAdi),
            actions: [
              IconButton(icon: const Icon(Icons.save), onPressed: _kaydet),
              IconButton(icon: const Icon(Icons.add), onPressed: _yeniKartEkle),
              IconButton(
                icon: const Icon(Icons.view_agenda),
                tooltip: 'Kart modunda göster',
                onPressed: () {
                  // Sade: Liste görünümünden kart görünümüne hızlı geçiş
                  _pageController.jumpToPage(0);
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: _icerik.length,
            itemBuilder: (context, i) {
              final controller = TextEditingController(text: _icerik[i]);
              return Card(
                margin: const EdgeInsets.all(12),
                color: _renkler[i],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        onChanged: (v) => _icerik[i] = v,
                        decoration: const InputDecoration(border: InputBorder.none),
                        maxLines: null,
                      ),
                      _renkButonlari(i),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}