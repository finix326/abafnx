import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'cizelge_detay_sayfasi.dart';
import 'cizelge_ekle_sayfasi.dart';
import 'cizelge_detay_resimli_sesli_sayfasi.dart';

class CizelgeListesiSayfasi extends StatefulWidget {
  const CizelgeListesiSayfasi({super.key});

  @override
  State<CizelgeListesiSayfasi> createState() => _CizelgeListesiSayfasiState();
}

class _CizelgeListesiSayfasiState extends State<CizelgeListesiSayfasi> {
  late Box cizelgeKutusu;

  @override
  void initState() {
    super.initState();
    cizelgeKutusu = Hive.box('cizelge_kutusu');
  }

  void _yeniCizelgeEkle(String tur) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CizelgeEkleSayfasi(tur: tur)),
    );
    setState(() {}); // Sayfayı yenile
  }

  void _cizelgeDetayGoster(String cizelgeAdi) {
    final veri = cizelgeKutusu.get(cizelgeAdi);
    final tur = veri['tur'];

    Widget hedefSayfa;
    if (tur == 'yazili') {
      hedefSayfa = CizelgeDetaySayfasi(cizelgeAdi: cizelgeAdi, tur: tur);
    } else if (tur == 'resimli_sesli') {
      hedefSayfa = CizelgeDetayResimliSesliSayfasi(cizelgeAdi: cizelgeAdi);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçersiz çizelge türü.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => hedefSayfa),
    );
  }

  void _tumCizelgeleriSil() async {
    await cizelgeKutusu.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cizelgeAdlari = cizelgeKutusu.keys.cast<String>().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çizelge Listesi'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _yeniCizelgeEkle,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'yazili',
                child: Text('Yazılı Çizelge Ekle'),
              ),
              PopupMenuItem(
                value: 'resimli_sesli',
                child: Text('Resimli / Sesli Çizelge Ekle'),
              ),
            ],
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _tumCizelgeleriSil,
            child: const Text("Tüm Çizelgeleri Temizle"),
          ),
          Expanded(
            child: cizelgeAdlari.isEmpty
                ? const Center(child: Text('Henüz çizelge eklenmemiş.'))
                : ListView.builder(
              itemCount: cizelgeAdlari.length,
              itemBuilder: (context, index) {
                final ad = cizelgeAdlari[index];
                return ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: Text(ad),
                  onTap: () => _cizelgeDetayGoster(ad),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
