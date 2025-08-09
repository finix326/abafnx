import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CizelgeDetaySayfasi extends StatefulWidget {
  final String cizelgeAdi;
  final String tur;

  const CizelgeDetaySayfasi({super.key, required this.cizelgeAdi, required this.tur});

  @override
  State<CizelgeDetaySayfasi> createState() => _CizelgeDetaySayfasiState();
}

class _CizelgeDetaySayfasiState extends State<CizelgeDetaySayfasi> {
  late Box _box;
  List<String> _icerik = [];
  List<Color> _renkler = [];
  bool kartModu = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _box = Hive.box('cizelge_kutusu');
    final veri = _box.get(widget.cizelgeAdi);
    _icerik = List<String>.from(veri['icerik']);
    _renkler = List.generate(_icerik.length, (_) => Colors.white);
  }

  void _yeniKartEkle() {
    setState(() {
      _icerik.add('');
      _renkler.add(Colors.white);
    });
  }

  void _kaydet() {
    final veri = _box.get(widget.cizelgeAdi);
    veri['icerik'] = _icerik;
    _box.put(widget.cizelgeAdi, veri);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  void _renkSec(int index, Color renk) {
    setState(() {
      if (_renkler[index] == renk) {
        _renkler[index] = Colors.white;
      } else {
        _renkler[index] = renk;
      }
    });
  }

  Widget _renkButonlari(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => _renkSec(index, Colors.green),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _renkSec(index, Colors.red),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cizelgeAdi),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _kaydet),
          IconButton(icon: const Icon(Icons.add), onPressed: _yeniKartEkle),
          IconButton(
            icon: Icon(kartModu ? Icons.list : Icons.view_agenda),
            onPressed: () => setState(() => kartModu = !kartModu),
          ),
        ],
      ),
      body: kartModu
          ? PageView.builder(
        controller: _pageController,
        itemCount: _icerik.length,
        itemBuilder: (context, index) {
          final controller = TextEditingController(text: _icerik[index]);
          return Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Card(
                color: _renkler[index],
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: controller,
                        onChanged: (deger) => _icerik[index] = deger,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24),
                        decoration: const InputDecoration(border: InputBorder.none),
                        maxLines: null,
                      ),
                      const SizedBox(height: 20),
                      _renkButonlari(index),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      )
          : ListView.builder(
        itemCount: _icerik.length,
        itemBuilder: (context, index) {
          final controller = TextEditingController(text: _icerik[index]);
          return Card(
            margin: const EdgeInsets.all(12),
            color: _renkler[index],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    onChanged: (deger) => _icerik[index] = deger,
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                  _renkButonlari(index),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
