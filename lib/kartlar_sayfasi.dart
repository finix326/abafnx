import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'app_state/current_student.dart';

class KartlarSayfasi extends StatefulWidget {
  const KartlarSayfasi({Key? key}) : super(key: key);

  @override
  State<KartlarSayfasi> createState() => _KartlarSayfasiState();
}

class _KartlarSayfasiState extends State<KartlarSayfasi> {
  final List<File?> _resimler = List.generate(4, (_) => null);
  final List<String?> _sesYollari = List.generate(4, (_) => null);
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  int? _aktifKayitIndex;
  bool _hazir = false;

  // Kart boyut sabitleri (biraz daha büyük)
  static const double _CARD_WIDTH = 240; // 220 (telefon) – 260 (tablet) arası deneyebilirsin
  static const double _CARD_HEIGHT = 320;

  Box? _box;            // Öğrenciye özel kalıcı kayıt kutusu: kartlar_<studentId>
  String? _studentId;   // Aktif öğrenci ID

  // Yardımcı: Listeleri belirtilen uzunluğa getir
  void _ensureLength(int len) {
    while (_resimler.length < len) {
      _resimler.add(null);
    }
    while (_sesYollari.length < len) {
      _sesYollari.add(null);
    }
  }

  @override
  void initState() {
    super.initState();
    _hazirlikYap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aktif öğrenci id'sini al ve Hive box'ını hazırla
    final id = context.read<CurrentStudent>().currentId;
    if (id != _studentId) {
      _studentId = id;
      _openAndLoadForStudent(id);
    }
  }

  Future<void> _hazirlikYap() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    await _player.openPlayer();
    setState(() {
      _hazir = true;
    });
  }

  Future<void> _openAndLoadForStudent(String? id) async {
    if (id == null) {
      setState(() => _box = null);
      return;
    }
    final name = 'kartlar_$id';
    final b = await Hive.openBox(name);

    // Tüm int index anahtarlarını al ve maksimumu bul
    final keys = b.keys.whereType<int>().toList()..sort();
    final maxIndex = keys.isEmpty ? -1 : keys.last;

    // Listeleri gerekli uzunluğa getir
    _ensureLength(maxIndex + 1);

    // Yükle
    final newImages = List<File?>.from(_resimler);
    final newAudios = List<String?>.from(_sesYollari);
    for (final i in keys) {
      final m = b.get(i);
      if (m is Map) {
        final img = m['image'] as String?;
        final aud = m['audio'] as String?;
        newImages[i] = (img != null && img.isNotEmpty) ? File(img) : null;
        newAudios[i] = (aud != null && aud.isNotEmpty) ? aud : null;
      }
    }
    setState(() {
      _box = b;
      for (int i = 0; i < newImages.length; i++) {
        _resimler[i] = newImages[i];
        _sesYollari[i] = newAudios[i];
      }
    });
  }

  Future<void> _persistCard(int index) async {
    if (_box == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce bir öğrenci seçin (Drawer üstünden).')),
        );
      }
      return;
    }
    await _box!.put(index, {
      'image': _resimler[index]?.path,
      'audio': _sesYollari[index],
    });
  }

  // Yeni: Kart silme ve ekleme yardımcıları
  void _resmiSil(int index) {
    setState(() {
      _resimler[index] = null; // sadece resmi sil
    });
    _persistCard(index);
  }

  void _sesiSil(int index) {
    setState(() {
      _sesYollari[index] = null; // sadece sesi sil
      if (_aktifKayitIndex == index) {
        _aktifKayitIndex = null;
      }
    });
    _persistCard(index);
  }

  void _ikisiniSil(int index) {
    setState(() {
      _resimler[index] = null;
      _sesYollari[index] = null;
    });
    _persistCard(index);
  }

  Future<void> _kartiSil(int index) async {
    // Eğer bu kartta kayıt sürüyorsa durdur
    if (_aktifKayitIndex == index) {
      try { await _recorder.stopRecorder(); } catch (_) {}
      _aktifKayitIndex = null;
    }
    setState(() {
      _resimler.removeAt(index);
      _sesYollari.removeAt(index);
    });
    // Kutuyu baştan yaz (indexler değişeceği için)
    if (_box != null) {
      await _box!.clear();
      for (int i = 0; i < _resimler.length; i++) {
        await _box!.put(i, {
          'image': _resimler[i]?.path,
          'audio': _sesYollari[i],
        });
      }
    }
  }

  void _yeniKartEkle() {
    setState(() {
      _resimler.add(null);
      _sesYollari.add(null);
    });
    // Yeni index için boş bir kayıt açalım ki kalıcılık hazır olsun
    _persistCard(_resimler.length - 1);
  }

  void _kartUzunBas(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Resim Ekle / Değiştir'),
              onTap: () {
                Navigator.pop(context);
                _resimSec(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('Sesi Oynat'),
              onTap: () async {
                Navigator.pop(context);
                await _kartTiklandi(index);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.image_not_supported_outlined),
              title: const Text('Resmi Sil'),
              onTap: () {
                Navigator.pop(context);
                _resmiSil(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('Sesi Sil'),
              onTap: () {
                Navigator.pop(context);
                _sesiSil(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Her ikisini de sil'),
              onTap: () {
                Navigator.pop(context);
                _ikisiniSil(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Kartı Sil'),
              onTap: () async {
                Navigator.pop(context);
                await _kartiSil(index);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Kapat'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getSesYolu(int index) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/kart_sesi_$index.aac';
  }

  bool _hasAudio(int index) {
    final p = _sesYollari[index];
    return p != null && File(p).existsSync();
  }

  bool _shouldShowMic(int index) {
    // Kayıt sırasında görünür; kayıt bittikten ve ses varsa gizli
    if (_aktifKayitIndex == index) return true;
    return !_hasAudio(index);
  }

  Future<void> _resimSec(int index) async {
    final picker = ImagePicker();
    final secilen = await picker.pickImage(source: ImageSource.gallery);
    if (secilen != null) {
      setState(() => _resimler[index] = File(secilen.path));
      await _persistCard(index);
    }
  }

  // Eski _resimSil artık kullanılmıyor, stub bırakıyoruz
  void _resimSilEski(int index) {}

  Future<void> _sesKaydiToggle(int index) async {
    if (!_hazir) return;

    if (_aktifKayitIndex == index) {
      await _recorder.stopRecorder();
      setState(() => _aktifKayitIndex = null);
      await _persistCard(index);
    } else {
      if (_box == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Önce bir öğrenci seçin (Drawer üstünden).')),
          );
        }
        return;
      }
      final path = await _getSesYolu(index);
      await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
      setState(() {
        _aktifKayitIndex = index;
        _sesYollari[index] = path;
      });
    }
  }

  Future<void> _kartTiklandi(int index) async {
    if (_player.isPlaying) {
      await _player.stopPlayer();
      return;
    }
    final path = _sesYollari[index];
    if (path != null && File(path).existsSync()) {
      await _player.startPlayer(fromURI: path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kartta kayıtlı ses yok.')),
      );
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kart Ekle'),
        actions: [
          IconButton(
            tooltip: 'Yeni kart ekle',
            onPressed: _yeniKartEkle,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Ekran genişliğine göre dinamik sütun sayısı (satır dolunca alta sarar)
          final crossAxisCount = (constraints.maxWidth / (_CARD_WIDTH + 16)).floor().clamp(1, 6);
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: _CARD_WIDTH / _CARD_HEIGHT,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _resimler.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _kartTiklandi(index),
                onLongPress: () => _kartUzunBas(index),
                child: Card(
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _resimler[index] != null
                            ? Image.file(_resimler[index]!, fit: BoxFit.contain)
                            : Container(
                                color: Colors.grey.shade300,
                                child: const Center(child: Icon(Icons.image, size: 60)),
                              ),
                      ),
                      // Sağ-alt: Ses kaydı başlat/durdur
                      if (_shouldShowMic(index))
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: IconButton.filled(
                            onPressed: () => _sesKaydiToggle(index),
                            icon: Icon(_aktifKayitIndex == index ? Icons.stop : Icons.mic),
                            style: IconButton.styleFrom(
                              backgroundColor: _aktifKayitIndex == index ? Colors.red : Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
