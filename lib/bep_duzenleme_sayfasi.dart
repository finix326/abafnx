import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'ai/finix_ai_button.dart';
import 'app_state/current_student.dart';

class BepDuzenlemeSayfasi extends StatefulWidget {
  final Box box;
  const BepDuzenlemeSayfasi({super.key, required this.box});

  @override
  State<BepDuzenlemeSayfasi> createState() => _BepDuzenlemeSayfasiState();
}

class _BepDuzenlemeSayfasiState extends State<BepDuzenlemeSayfasi> {
  DateTime _date = DateTime.now();

  // Öğrenci bilgileri
  final _ad = TextEditingController();
  final _tc = TextEditingController();
  final _sinif = TextEditingController();
  final _ogretmen = TextEditingController();
  final _veli = TextEditingController();
  final _tel = TextEditingController();
  final _problemDavranis = TextEditingController();

  String? _fotoPath;

  // Alanlar: her biri {uzun,kisa} metinlerinden oluşan öğe listesi
  final Map<String, List<_HedefPair>> _alanlar = {
    'Dil Gelişimi': [],
    'Motor Beceriler': [],
    'Sosyal Etkileşim': [],
    'Bilişsel Gelişim': [],
    'Öz Bakım Becerileri': [],
  };

  @override
  void dispose() {
    _ad.dispose();
    _tc.dispose();
    _sinif.dispose();
    _ogretmen.dispose();
    _veli.dispose();
    _tel.dispose();
    _problemDavranis.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img != null) {
        setState(() => _fotoPath = img.path);
      }
    } catch (_) {}
  }

  void _addPair(String alan) {
    setState(() => _alanlar[alan]!.add(_HedefPair()));
  }

  void _removePair(String alan, int index) {
    setState(() => _alanlar[alan]!.removeAt(index));
  }

  Future<void> _save() async {
    final currentId = context.read<CurrentStudent>().currentId;
    final tarihStr = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

    Map<String, dynamic> mapla(List<_HedefPair> list) => {
      'hedefler': list.map((e) => {'uzun': e.uzun.text.trim(), 'kisa': e.kisa.text.trim()}).toList(),
    };

    final kayit = {
      // meta
      'tarih': _date.millisecondsSinceEpoch,
      'tarihStr': tarihStr,
      'ogrenciId': currentId,
      'ogrenciAd': _ad.text.trim(),
      'tcKimlik': _tc.text.trim(),
      'sinif': _sinif.text.trim(),
      'ogretmen': _ogretmen.text.trim(),
      'veli': _veli.text.trim(),
      'telefon': _tel.text.trim(),
      'problemDavranis': _problemDavranis.text.trim(),
      'fotoPath': _fotoPath,

      // alanlar
      'dil': mapla(_alanlar['Dil Gelişimi']!),
      'motor': mapla(_alanlar['Motor Beceriler']!),
      'sosyal': mapla(_alanlar['Sosyal Etkileşim']!),
      'bilissel': mapla(_alanlar['Bilişsel Gelişim']!),
      'ozBakim': mapla(_alanlar['Öz Bakım Becerileri']!),
    };

    await widget.box.add(kayit);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BEP raporu kaydedildi.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final foto = (_fotoPath != null && File(_fotoPath!).existsSync())
        ? CircleAvatar(radius: 36, backgroundImage: FileImage(File(_fotoPath!)))
        : const CircleAvatar(radius: 36, child: Icon(Icons.person));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BEP Düzenleme'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tarih + Foto
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tarih'),
                    subtitle: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.date_range),
                      tooltip: 'Tarih seç',
                    ),
                  ),
                ),
                InkWell(
                  onTap: _pickPhoto,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: foto,
                  ),
                ),
                IconButton(
                  onPressed: _pickPhoto,
                  tooltip: 'Fotoğraf seç',
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Öğrenci Bilgileri
            const Text('Öğrenci Bilgileri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _input(_ad, 'Ad Soyad'),
            Row(
              children: [
                Expanded(child: _input(_tc, 'TC Kimlik No')),
                const SizedBox(width: 8),
                Expanded(child: _input(_sinif, 'Sınıf')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _input(_ogretmen, 'Öğretmen')),
                const SizedBox(width: 8),
                Expanded(child: _input(_veli, 'Veli')),
              ],
            ),
            _input(_tel, 'Telefon'),
            _inputWithAI(
              _problemDavranis,
              'Problem Davranış (opsiyonel)',
              contextDescription: 'BEP hedefi ve kısa vadeli amaçlar için metin öner',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Alanlar
            for (final alan in _alanlar.keys) ...[
              _AlanKart(
                baslik: alan,
                pairs: _alanlar[alan]!,
                onAdd: () => _addPair(alan),
                onRemove: (i) => _removePair(alan, i),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _inputWithAI(
    TextEditingController controller,
    String label, {
    required String contextDescription,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FinixAIButton.small(
            contextDescription: contextDescription,
            initialText: controller.text,
            onResult: (aiText) => controller.text = aiText,
          ),
        ],
      ),
    );
  }
}

class _HedefPair {
  final uzun = TextEditingController();
  final kisa = TextEditingController();
}

class _AlanKart extends StatelessWidget {
  final String baslik;
  final List<_HedefPair> pairs;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _AlanKart({
    super.key,
    required this.baslik,
    required this.pairs,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Hedef ekle',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (pairs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Henüz hedef eklenmedi. Sağ üstten + ile ekle.'),
              ),
            for (int i = 0; i < pairs.length; i++) ...[
              const Divider(height: 18),
              Text('Hedef ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: pairs[i].uzun,
                      decoration: const InputDecoration(
                        labelText: 'Uzun Dönem Hedef',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FinixAIButton.small(
                    contextDescription:
                        'BEP hedefi ve kısa vadeli amaçlar için metin öner',
                    initialText: pairs[i].uzun.text,
                    onResult: (aiText) => pairs[i].uzun.text = aiText,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: pairs[i].kisa,
                      decoration: const InputDecoration(
                        labelText: 'Kısa Dönem Hedef',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FinixAIButton.small(
                    contextDescription:
                        'BEP hedefi ve kısa vadeli amaçlar için metin öner',
                    initialText: pairs[i].kisa.text,
                    onResult: (aiText) => pairs[i].kisa.text = aiText,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Bu hedefi sil',
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.delete_outline),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}