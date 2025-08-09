import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';

class CizelgeDetayResimliSesliSayfasi extends StatefulWidget {
  final String cizelgeAdi;

  const CizelgeDetayResimliSesliSayfasi({Key? key, required this.cizelgeAdi}) : super(key: key);

  @override
  State<CizelgeDetayResimliSesliSayfasi> createState() => _CizelgeDetayResimliSesliSayfasiState();
}

class _CizelgeDetayResimliSesliSayfasiState extends State<CizelgeDetayResimliSesliSayfasi> {
  final Box _box = Hive.box('cizelge_kutusu');
  List<Map<String, dynamic>> _icerik = [];
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final data = _box.get(widget.cizelgeAdi);
    if (data != null && data['icerik'] != null) {
      _icerik = List<Map<String, dynamic>>.from(data['icerik']);
    }
    if (_icerik.isEmpty) {
      _icerik.add({'resim': null, 'ses': null, 'metin': ''});
    }
  }

  void _kaydetVeriler() {
    _box.put(widget.cizelgeAdi, {
      'tur': 'resimli',
      'icerik': _icerik,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Çizelge başarıyla kaydedildi")),
    );
  }

  void _kutucukEkle() {
    setState(() {
      _icerik.add({'resim': null, 'ses': null, 'metin': ''});
    });
  }

  void _kutucukSil(int index) {
    setState(() {
      _icerik.removeAt(index);
    });
  }

  Future<void> _resimSec(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _icerik[index]['resim'] = picked.path;
      });
    }
  }

  Future<void> _sesKaydet(int index) async {
    final recorder = FlutterSoundRecorder();
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return;
    await recorder.openRecorder();
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
    await recorder.startRecorder(toFile: path);
    await Future.delayed(Duration(seconds: 3)); // kısa kayıt örnek
    await recorder.stopRecorder();
    await recorder.closeRecorder();
    setState(() {
      _icerik[index]['ses'] = path;
    });
  }

  Future<void> _sesCal(int index) async {
    final sesYolu = _icerik[index]['ses'];
    if (sesYolu == null) return;
    final player = FlutterSoundPlayer();
    await player.openPlayer();
    await player.startPlayer(fromURI: sesYolu);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Çizelge: ${widget.cizelgeAdi}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _kaydetVeriler,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _kutucukEkle,
        child: const Icon(Icons.add),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _icerik.length,
        itemBuilder: (context, index) {
          final kutu = _icerik[index];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => _sesCal(index),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.45,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: kutu['resim'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(kutu['resim']), fit: BoxFit.cover),
                      )
                          : const Center(child: Text("Resim Yok")),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.green),
                      onPressed: () {
                        if (index + 1 < _icerik.length) {
                          _pageController.animateToPage(
                            index + 1,
                            duration: Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _kutucukSil(index),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.image, color: Colors.white),
                      onPressed: () => _resimSec(index),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.mic, color: Colors.white),
                      onPressed: () => _sesKaydet(index),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  onChanged: (val) => _icerik[index]['metin'] = val,
                  controller: TextEditingController(text: kutu['metin']),
                  decoration: InputDecoration(
                    hintText: 'Bu sayfa için açıklama yazın...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
