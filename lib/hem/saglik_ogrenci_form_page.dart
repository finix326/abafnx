import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'saglik_box.dart';
import '../app_state/current_student.dart';

class SaglikOgrenciFormPage extends StatefulWidget {
  /// Kayıt düzenlemek için id + initial gönder.
  final String? id;
  final Map<String, dynamic>? initial;

  const SaglikOgrenciFormPage({super.key, this.id, this.initial});

  @override
  State<SaglikOgrenciFormPage> createState() => _SaglikOgrenciFormPageState();
}

class _SaglikOgrenciFormPageState extends State<SaglikOgrenciFormPage> {
  final _form = GlobalKey<FormState>();

  final _ad = TextEditingController();
  final _tc = TextEditingController();
  final _sinif = TextEditingController();

  final _ogretmenAd = TextEditingController();
  final _ogretmenTel = TextEditingController();

  final _veliAd = TextEditingController();
  final _veliTel = TextEditingController();

  final _ilaclar = TextEditingController();
  final _fiziksel = TextEditingController();
  final _psik = TextEditingController();
  final _problem = TextEditingController();

  String? _fotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? {};
    _ad.text = (m['ad'] ?? '').toString();
    _tc.text = (m['tcKimlik'] ?? '').toString();
    _sinif.text = (m['sinif'] ?? '').toString();

    _ogretmenAd.text = (m['ogretmenAd'] ?? '').toString();
    _ogretmenTel.text = (m['ogretmenTel'] ?? '').toString();

    _veliAd.text = (m['veliAd'] ?? '').toString();
    _veliTel.text = (m['veliTel'] ?? '').toString();

    _ilaclar.text = (m['ilaclar'] ?? '').toString();
    _fiziksel.text = (m['fizikselDurum'] ?? '').toString();
    _psik.text = (m['psikiyatrikBilgi'] ?? '').toString();
    _problem.text = (m['problemDavranis'] ?? '').toString();

    _fotoPath = (m['fotoPath'] ?? '').toString().isEmpty ? null : m['fotoPath'].toString();
  }

  @override
  void dispose() {
    _ad.dispose();
    _tc.dispose();
    _sinif.dispose();
    _ogretmenAd.dispose();
    _ogretmenTel.dispose();
    _veliAd.dispose();
    _veliTel.dispose();
    _ilaclar.dispose();
    _fiziksel.dispose();
    _psik.dispose();
    _problem.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 85);
    if (x == null) return;

    // Kopyalamaya gerek yok; path'i saklıyoruz. (İstersen app doc içine kopyalayabiliriz.)
    setState(() {
      _fotoPath = x.path;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final box = await ensureHealthBox();
      final currentStudentId =
          context.read<CurrentStudent>().currentStudentId;
      if (currentStudentId == null || currentStudentId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
        );
        return;
      }

      final data = {
        'ad': _ad.text.trim(),
        'tcKimlik': _tc.text.trim(),
        'sinif': _sinif.text.trim(),
        'ogretmenAd': _ogretmenAd.text.trim(),
        'ogretmenTel': _ogretmenTel.text.trim(),
        'veliAd': _veliAd.text.trim(),
        'veliTel': _veliTel.text.trim(),
        'ilaclar': _ilaclar.text.trim(),
        'fizikselDurum': _fiziksel.text.trim(),
        'psikiyatrikBilgi': _psik.text.trim(),
        'problemDavranis': _problem.text.trim(),
        'fotoPath': _fotoPath ?? '',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'createdAt': widget.initial?['createdAt'] ??
            DateTime.now().millisecondsSinceEpoch,
        'studentId': currentStudentId,
      };

      if (widget.id == null) {
        // yeni kayıt
        final key = _makeKey(data['ad'], data['tcKimlik']);
        await box.put(key, data);
      } else {
        // güncelle
        await box.put(widget.id, data);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _makeKey(String? ad, String? tc) {
    final a = (ad ?? '').trim();
    final t = (tc ?? '').trim();
    if (t.isNotEmpty) return 'tc_$t';
    if (a.isNotEmpty) return 'ad_${a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    return 'id_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _fotoPath != null && File(_fotoPath!).existsSync()
        ? CircleAvatar(radius: 40, backgroundImage: FileImage(File(_fotoPath!)))
        : const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Öğrenci Ekle' : 'Öğrenci Düzenle'),
        actions: [
          IconButton(
            tooltip: 'Kaydet',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(60),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      avatar,
                      Container(
                        margin: const EdgeInsets.only(right: 2, bottom: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kimlik
              _section('Kimlik'),
              _tf(_ad, 'Ad Soyad', required: true),
              _tf(_tc, 'TC Kimlik (opsiyonel)', keyboard: TextInputType.number),
              _tf(_sinif, 'Sınıf (opsiyonel)'),

              // İletişim
              const SizedBox(height: 16),
              _section('İletişim'),
              _tf(_veliAd, 'Veli Ad Soyad (opsiyonel)'),
              _tf(_veliTel, 'Veli Telefon (opsiyonel)', keyboard: TextInputType.phone),
              _tf(_ogretmenAd, 'Sınıf Öğretmeni (opsiyonel)'),
              _tf(_ogretmenTel, 'Öğretmen Telefon (opsiyonel)', keyboard: TextInputType.phone),

              // Sağlık
              const SizedBox(height: 16),
              _section('Sağlık Bilgileri'),
              _tf(_ilaclar, 'Kullandığı İlaçlar (opsiyonel)', maxLines: 2),
              _tf(_fiziksel, 'Fiziksel Durum (opsiyonel)', maxLines: 2),
              _tf(_psik, 'Psikiyatrik Bilgi (opsiyonel)', maxLines: 2),
              _tf(_problem, 'Problem Davranış (opsiyonel)', maxLines: 2),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _tf(
      TextEditingController c,
      String label, {
        bool required = false,
        int maxLines = 1,
        TextInputType? keyboard,
      }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null
            : null,
      ),
    );
  }
}