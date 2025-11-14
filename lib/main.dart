import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'ai/ai_engine.dart';

// STATE
import 'app_state/current_student.dart';

// DATA
import 'data/finix_data_service.dart';

// MODEL
import 'student.dart';
import 'kart_model.dart';

// WIDGETS
import 'widgets/student_picker_sheet.dart';

// EKRANLAR
import 'login_page.dart';

// Ana sayfa içerikleri (oyunlar ve kartlar ANA SAYFADA)
import 'siniflama_oyunu_sayfasi.dart';
import 'kartlar_sayfasi.dart';

// Terapist modülü ekranları
import 'veri.dart' show VeriSayfasi;
import 'calisilan_programlar.dart' show CalisilanProgramlarSayfasi;
import 'cizelge_listesi.dart';
import 'cizelge_ekle_sayfasi.dart';
import 'bep_duzenleme_sayfasi.dart';
import 'bep_raporlari_listesi_sayfasi.dart';

// ✅ SAĞLIK (Hemşire) modülü
import 'hem/saglik_ogrenci_listesi_page.dart';

// ✅ Sohbet modülü
import 'sohbet_page.dart';

// ✅ Eşleştirme oyunu listesi
import 'eslestirme_oyun_listesi.dart';
// DÜZELTİLDİ: Eksik import eklendi
import 'hafiza_oyunu_listesi_sayfasi.dart';

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

  // ✅ Kartlar için kutu
  await Hive.openBox('kart_dizileri');

  await Hive.openBox('hafiza_oyunlari');

  // Ortak Finix kayıt kutusu
  await FinixDataService.instance.init();

  // Öğrenciler
  if (!Hive.isAdapterRegistered(100)) {
    Hive.registerAdapter(StudentAdapter());
  }
  if (!Hive.isAdapterRegistered(15)) {
    Hive.registerAdapter(KartModelAdapter());
  }
  await Hive.openBox<Student>('students');

  await Hive.openBox('auth');

  // 🔹 Yapay zekâ motorunu başlat (Gemini)
  // TODO: Burayı kendi Gemini API anahtarınla değiştir.
  AIEngine.init(
    apiKey: 'AIzaSyBpZFzWz5cdTaGiM07Chb1G_-fUUGOSYWQ',
    dataService: FinixDataService.instance,
  );

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
                      builder: (_) => const EslestirmeOyunListesiPage(),
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
                    MaterialPageRoute(
                        builder: (_) => const SiniflamaOyunuSayfasi()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Hafıza Oyunu',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HafizaOyunuListesiSayfasi(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Sohbet',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SohbetHomePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _BigButton(
                text: 'Kartlar',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const KartlarSayfasi()),
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
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final studentId = context.read<CurrentStudent>().currentId;
              navigator.pop();
              if (studentId == null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
                );
                return;
              }
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => CizelgeEkleSayfasi(
                    tur: 'Genel',
                    studentId: studentId,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('BEP Düzenleme'),
            onTap: () async {
              // GÜVENLİ YAPI: Önce context'e bağlı değişkenleri al
              final navigator = Navigator.of(context);
              final studentId = context.read<CurrentStudent>().currentId;

              // Sonra context'i son kez kullan (pop)
              navigator.pop();

              // Sonra asenkron işlemi yap
              final boxName = studentId != null ? 'bep_raporlari_$studentId' : 'bep_raporlari';
              final box = await Hive.openBox(boxName);

              // Güvenli navigator ile yeni sayfayı aç
              navigator.push(MaterialPageRoute(builder: (_) => BepDuzenlemeSayfasi(box: box)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('BEP Raporları Listesi'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BepRaporlariListesiSayfasi()));
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Sağlık'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SaglikOgrenciListesiPage()));
            },
          ),
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
