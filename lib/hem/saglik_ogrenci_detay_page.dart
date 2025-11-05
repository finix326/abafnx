import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'saglik_box.dart';
import 'saglik_ogrenci_form_page.dart';

class SaglikOgrenciDetayPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data; // liste sayfasından hızlı render için

  const SaglikOgrenciDetayPage({
    super.key,
    required this.id,
    required this.data,
  });

  @override
  State<SaglikOgrenciDetayPage> createState() => _SaglikOgrenciDetayPageState();
}

class _SaglikOgrenciDetayPageState extends State<SaglikOgrenciDetayPage> {
  late Future<Box> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = ensureHealthBox();
  }

  Future<Map<String, dynamic>> _load() async {
    final box = await _boxFuture;
    final raw = box.get(widget.id) as Map?;
    if (raw == null) return widget.data;
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu öğrencinin sağlık kaydı kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;

    final box = await _boxFuture;
    await box.delete(widget.id);
    if (!mounted) return;
    Navigator.pop(context); // listeye geri
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        final m = (snap.data ?? widget.data);
        final ad = (m['ad'] ?? '').toString();
        final tc = (m['tcKimlik'] ?? '').toString();
        final veliAd = (m['veliAd'] ?? '').toString();
        final veliTel = (m['veliTel'] ?? '').toString();
        final sinif = (m['sinif'] ?? '').toString();
        final ogretmenAd = (m['ogretmenAd'] ?? '').toString();
        final ogretmenTel = (m['ogretmenTel'] ?? '').toString();
        final fiziksel = (m['fizikselDurum'] ?? '').toString();
        final psik = (m['psikiyatrikBilgi'] ?? '').toString();
        final problem = (m['problemDavranis'] ?? '').toString();
        final ilac = (m['ilaclar'] ?? '').toString();
        final fotoPath = (m['fotoPath'] ?? '').toString();

        Widget avatar;
        if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
          avatar = CircleAvatar(radius: 40, backgroundImage: FileImage(File(fotoPath)));
        } else {
          avatar = const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(ad.isEmpty ? 'Öğrenci Detayı' : ad),
            actions: [
              IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SaglikOgrenciFormPage(
                        id: widget.id,
                        initial: m,
                      ),
                    ),
                  );
                  if (mounted) setState(() {}); // güncel veriyi çek
                },
              ),
              IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ),
          body: snap.connectionState != ConnectionState.done && snap.data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: avatar),
              const SizedBox(height: 16),
              _tile('Ad Soyad', ad),
              _tile('TC Kimlik', tc),
              _tile('Sınıf', sinif),
              _tile('Sınıf Öğretmeni', _merge2(ogretmenAd, ogretmenTel)),
              _tile('Veli', _merge2(veliAd, veliTel)),
              _tile('İlaçlar', ilac),
              _tile('Fiziksel Durum', fiziksel),
              _tile('Psikiyatrik Bilgi', psik),
              _tile('Problem Davranış', problem),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value.isEmpty ? '-' : value),
    );
  }

  String _merge2(String a, String b) {
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a • $b';
  }
}