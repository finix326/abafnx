import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  void initState() {
    super.initState();
    _hazirlikYap();
  }

  Future<void> _hazirlikYap() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    await _player.openPlayer();
    setState(() {
      _hazir = true;
    });
  }

  Future<String> _getSesYolu(int index) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/kart_sesi_$index.aac';
  }

  Future<void> _resimSec(int index) async {
    final picker = ImagePicker();
    final secilen = await picker.pickImage(source: ImageSource.gallery);
    if (secilen != null) {
      setState(() => _resimler[index] = File(secilen.path));
    }
  }

  void _resimSil(int index) {
    setState(() {
      _resimler[index] = null;
      _sesYollari[index] = null;
    });
  }

  Future<void> _sesKaydiToggle(int index) async {
    if (!_hazir) return;

    if (_aktifKayitIndex == index) {
      await _recorder.stopRecorder();
      setState(() => _aktifKayitIndex = null);
    } else {
      final path = await _getSesYolu(index);
      await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
      setState(() {
        _aktifKayitIndex = index;
        _sesYollari[index] = path;
      });
    }
  }

  Future<void> _kartTiklandi(int index) async {
    final path = _sesYollari[index];
    if (path != null && File(path).existsSync()) {
      await _player.startPlayer(fromURI: path);
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
      appBar: AppBar(title: const Text('Yeni Kart Ekle')),
      body: GridView.count(
        crossAxisCount: 2,
        children: List.generate(4, (index) {
          return GestureDetector(
            onTap: () => _kartTiklandi(index),
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _resimler[index] != null
                        ? Image.file(_resimler[index]!, fit: BoxFit.cover)
                        : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                          child: Icon(Icons.image, size: 60)),
                    ),
                  ),
                  if (_resimler[index] != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _resimSil(index),
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => _resimSec(index),
                          child: const Text('Resim'),
                        ),
                        IconButton(
                          icon: Icon(
                            _aktifKayitIndex == index
                                ? Icons.stop
                                : Icons.mic,
                            color: Colors.white,
                          ),
                          color: Colors.red,
                          onPressed: () => _sesKaydiToggle(index),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
