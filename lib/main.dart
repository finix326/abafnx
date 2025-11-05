import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// STATE
import 'app_state/current_student.dart';

// MODEL
import 'student.dart';

// WIDGETS
import 'widgets/student_picker_sheet.dart';

// EKRANLAR
import 'login_page.dart';

// Ana sayfa içerikleri (oyunlar ve kartlar ANA SAYFADA)
import 'siniflama_oyunu_sayfasi.dart';
import 'kartlar_sayfasi.dart';

// Terapist modülü ekranları
import 'veri.dart' show VeriSayfasi; // Yeni Program Oluştur
import 'calisilan_programlar.dart' show CalisilanProgramlarSayfasi; // Veri Girişi
import 'cizelge_listesi.dart';
import 'cizelge_ekle_sayfasi.dart';
import 'bep_duzenleme_sayfasi.dart';
import 'bep_raporlari_listesi_sayfasi.dart';

// ✅ SAĞLIK (Hemşire) modülü
import 'hem/saglik_ogrenci_listesi_page.dart';

// ✅ Sohbet modülü
import 'sohbet_page.dart';

// ✅ Yeni: Eşleştirme oyunu listesi (oluştur/oynat akışı)
import 'eslestirme_oyun_listesi.dart'; // <-- yeni sistemin giriş ekranı

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);

  // Eski kutular (geri uyumluluk)
  await Hive.openBox('veri_kutusu');
  await Hive.openBox('program_bilgileri');
  await Hive.openBox('cizelge_kutusu');
  await Hive.openBox('bep_raporlari');
  await Hive.openBox('sohbet_kutusu');

  // ✅ Yeni: Eşleştirme oyunları için kutu
  await Hive.openBox('es_game_box');

  // Öğrenciler
  if (!Hive.isAdapterRegistered(100)) {
    Hive.registerAdapter(StudentAdapter()); // typeId: 100
  }
  await Hive.openBox<Student>('students');

  // (Varsa) auth kutusu giriş ekranının içinde kullanılır
  await Hive.openBox('auth');

  final current = CurrentStudent();
  await current.load();

  runApp(
    ChangeNotifierProvider(
      create: (_) => current,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

/// ANA SAYFA: Oyunlar ve Kartlar burada
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      drawer: const _TerapistDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BigButton(
                text: 'Eşleştirme Oyunu',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EslestirmeOyunListesiPage(), // <-- yeni liste sayfası
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Sınıflama Oyunu',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SiniflamaOyunuSayfasi()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Kartlar',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KartlarSayfasi()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Sohbet',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SohbetPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _BigButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        child: Text(text),
      ),
    );
  }
}

/// TERAPİST MODÜLÜ — Drawer
class _TerapistDrawer extends StatelessWidget {
  const _TerapistDrawer();

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _TerapistDrawerHeader(),

          // Öğrenci Değiştir / Ekle
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Öğrenci Değiştir / Ekle'),
            onTap: () {
              Navigator.pop(context);
              showStudentPickerSheet(context);
            },
          ),
          if (currentId != null) const _AktifOgrenciTile(),
          const Divider(height: 1),

          // PROGRAM / VERİ
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Yeni Program Oluştur'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VeriSayfasi()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Veri Girişi (Çalışılan Programlar)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CalisilanProgramlarSayfasi()));
            },
          ),

          const Divider(height: 1),

          // ÇİZELGE
          ListTile(
            leading: const Icon(Icons.view_list_outlined),
            title: const Text('Çizelge Listesi'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CizelgeListesiSayfasi()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_task),
            title: const Text('Çizelge Ekle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CizelgeEkleSayfasi(tur: 'Genel')));
            },
          ),

          const Divider(height: 1),

          // BEP
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('BEP Düzenleme'),
            onTap: () async {
              Navigator.pop(context);

              final currentId = context.read<CurrentStudent>().currentId;
              final boxName = currentId != null ? 'bep_raporlari_$currentId' : 'bep_raporlari';
              final box = await Hive.openBox(boxName);

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BepDuzenlemeSayfasi(box: box)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('BEP Raporları Listesi'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BepRaporlariListesiSayfasi()),
              );
            },
          ),

          const Divider(height: 1),

          // ✅ SAĞLIK (ÇIKIŞ'IN HEMEN ÜSTÜ)
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Sağlık'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SaglikOgrenciListesiPage()),
              );
            },
          ),

          // ÇIKIŞ
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış Yap'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TerapistDrawerHeader extends StatelessWidget {
  const _TerapistDrawerHeader();

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    final students = Hive.box<Student>('students');
    final ad = (currentId == null) ? null : (students.get(currentId)?.ad);

    return InkWell(
      onTap: () => showStudentPickerSheet(context),
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            ad == null ? 'Terapist Modülü' : 'Terapist Modülü\nÖğrenci: $ad',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AktifOgrenciTile extends StatelessWidget {
  const _AktifOgrenciTile();

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    final students = Hive.box<Student>('students');
    final ad = (currentId == null) ? null : (students.get(currentId)?.ad);

    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text('Aktif Öğrenci'),
      subtitle: Text(ad ?? 'Seçilmedi'),
    );
  }
}