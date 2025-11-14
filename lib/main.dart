import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'ai/ai_engine.dart';

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
  // 🔹 Yapay zekâ motorunu başlat (Gemini)
  // DÜZELTİLDİ: Fonksiyon çağrısı syntax hatası giderildi.
  AIEngine.init('AIzaSyBpZFzWz5cdTaGiM07Chb1G_-fUUGOSYWQ'); // TODO: Burayı kendi Gemini API anahtarınla değiştir

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

  // Öğrenciler
  if (!Hive.isAdapterRegistered(100)) {
    Hive.registerAdapter(StudentAdapter());
  }
  await Hive.openBox<Student>('students');

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      drawer: const _TerapistDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
            children: [
              _HomeActionCard(
                action: _HomeAction(
                  title: 'Eşleştirme Oyunu',
                  icon: Icons.grid_view_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EslestirmeOyunListesiPage(),
                      ),
                    );
                  },
                ),
              ),
              _HomeActionCard(
                action: _HomeAction(
                  title: 'Sınıflama Oyunu',
                  icon: Icons.category_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SiniflamaOyunuSayfasi(),
                      ),
                    );
                  },
                ),
              ),
              _HomeActionCard(
                action: _HomeAction(
                  title: 'Hafıza Oyunu',
                  icon: Icons.memory_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HafizaOyunuListesiSayfasi(),
                      ),
                    );
                  },
                ),
              ),
              _HomeActionCard(
                action: _HomeAction(
                  title: 'Sohbet',
                  icon: Icons.chat_bubble_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SohbetHomePage(),
                      ),
                    );
                  },
                ),
              ),
              _HomeActionCard(
                action: _HomeAction(
                  title: 'Kartlar',
                  icon: Icons.style_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KartlarSayfasi(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                size: 36,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
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
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CizelgeEkleSayfasi(tur: 'Genel')));
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
