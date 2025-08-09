// Dosya adı: cizelge_detay_resimli_sesli_sayfasi.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CizelgeDetayResimliSesliSayfasi extends StatefulWidget {
  final String cizelgeAdi;

  const CizelgeDetayResimliSesliSayfasi({super.key, required this.cizelgeAdi});

  @override
  State<CizelgeDetayResimliSesliSayfasi> createState() => _CizelgeDetayResimliSesliSayfasiState();
}

class _CizelgeDetayResimliSesliSayfasiState extends State<CizelgeDetayResimliSesliSayfasi> {
  late Box _box;
  List<Map> _icerik = [];
  final PageController _pageController = PageController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _box = Hive.box('cizelge_kutusu');
    final veri = _box.get(widget.cizelgeAdi);
    _icerik = List<Map>.from(veri['icerik']);
    _recorder.openRecorder();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  void _kartEkle() {
    setState(() {
      _icerik.add({'text': '', 'image': null, 'audioPath': null});
    });
  }

  Future<void> _resimEkle(int index) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _icerik[index]['image'] = file.path;
      });
    }
  }

  Future<void> _sesKaydet(int index) async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${const Uuid().v4()}.aac';

      await _recorder.startRecorder(toFile: path);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Kayıt Devam Ediyor"),
          content: const Text("Durdurmak için DUR butonuna bas."),
          actions: [
            TextButton(
              onPressed: () async {
                await _recorder.stopRecorder();
                setState(() {
                  _icerik[index]['audioPath'] = path;
                });
                Navigator.pop(context);
              },
              child: const Text("DUR"),
            )
          ],
        ),
      );
    }
  }

  void _sesCal(int index) async {
    final path = _icerik[index]['audioPath'];
    if (path != null) {
      await _player.startPlayer(fromURI: path);
    }
  }

  void _kaydet() {
    final veri = _box.get(widget.cizelgeAdi);
    veri['icerik'] = _icerik;
    _box.put(widget.cizelgeAdi, veri);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cizelgeAdi),
        actions: [
          IconButton(onPressed: _kaydet, icon: const Icon(Icons.save)),
          IconButton(onPressed: _kartEkle, icon: const Icon(Icons.add))
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _icerik.length,
        itemBuilder: (context, index) {
          final kart = _icerik[index];
          final controller = TextEditingController(text: kart['text']);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (kart['image'] != null)
                      Image.file(File(kart['image']), height: 200),
                    TextField(
                      controller: controller,
                      onChanged: (v) => _icerik[index]['text'] = v,
                      decoration: const InputDecoration(labelText: "Açıklama"),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _resimEkle(index),
                          icon: const Icon(Icons.image),
                          label: const Text("Resim Ekle"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _sesKaydet(index),
                          icon: const Icon(Icons.mic),
                          label: const Text("Ses Kaydet"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _sesCal(index),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Ses Çal"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
