import 'siniflama_oyunu_sayfasi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'kartlar_sayfasi.dart';
import 'oyunlar_sayfasi.dart';
import 'veri.dart';
import 'cizelge_listesi.dart';
import 'bep_duzenleme_sayfasi.dart';
import 'bep_raporlari_listesi_sayfasi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  await Hive.openBox('veri_kutusu');
  await Hive.openBox('program_bilgileri');
  await Hive.openBox('cizelge_kutusu');
  await Hive.openBox('bep_raporlari');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finix',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Terapist Modülü',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text('Hakkında'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Veri Girişi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VeriSayfasi(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Çizelge'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CizelgeListesiSayfasi(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('BEP Düzenleme'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BepDuzenlemeSayfasi(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('BEP Raporları'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BepRaporlariListesiSayfasi(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KartlarSayfasi(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 100),
                textStyle: const TextStyle(fontSize: 24),
              ),
              child: const Text('Kartlar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OyunlarSayfasi(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 100),
                textStyle: const TextStyle(fontSize: 24),
              ),
              child: const Text('Oyunlar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SiniflamaOyunuSayfasi(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 100),
                textStyle: TextStyle(fontSize: 24),
              ),
              child: Text('Sınıflama'),
            ),
          ],
        ),
      ),
    );
  }
}
