import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EslestirmeEditorSayfasi extends StatefulWidget {
  const EslestirmeEditorSayfasi({super.key});

  @override
  State<EslestirmeEditorSayfasi> createState() => _EslestirmeEditorSayfasiState();
}

class _EslestirmeEditorSayfasiState extends State<EslestirmeEditorSayfasi> {
  final List<Map<String, File?>> _eslestirmeCiftleri = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> _resimSec(int index, String taraf) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _eslestirmeCiftleri[index][taraf] = File(picked.path);
    });
  }

  void _yeniCiftEkle() {
    setState(() {
      _eslestirmeCiftleri.add({'sol': null, 'sag': null});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Eşleştirme Seti Oluştur")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _eslestirmeCiftleri.length,
              itemBuilder: (context, index) {
                final cift = _eslestirmeCiftleri[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _resimSec(index, 'sol'),
                          child: Container(
                            height: 100,
                            color: Colors.blue.shade100,
                            child: cift['sol'] != null
                                ? Image.file(cift['sol']!, fit: BoxFit.cover)
                                : const Icon(Icons.add_photo_alternate),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _resimSec(index, 'sag'),
                          child: Container(
                            height: 100,
                            color: Colors.green.shade100,
                            child: cift['sag'] != null
                                ? Image.file(cift['sag']!, fit: BoxFit.cover)
                                : const Icon(Icons.add_photo_alternate),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _yeniCiftEkle,
            child: const Text("Yeni Eşleştirme Çifti Ekle"),
          ),
        ],
      ),
    );
  }
}
