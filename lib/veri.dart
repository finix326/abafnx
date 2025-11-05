import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';

class VeriSayfasi extends StatefulWidget {
  const VeriSayfasi({super.key});

  @override
  State<VeriSayfasi> createState() => _VeriSayfasiState();
}

class _VeriSayfasiState extends State<VeriSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _tekrarCtrl = TextEditingController(text: '3');
  final _genellemeCtrl = TextEditingController(text: '3');

  @override
  void dispose() {
    _adCtrl.dispose();
    _tekrarCtrl.dispose();
    _genellemeCtrl.dispose();
    super.dispose();
  }

  Future<Box> _openProgramBox(String studentId) async {
    try {
      return await Hive.openBox('program_bilgileri_$studentId');
    } catch (_) {
      return await Hive.openBox('program_bilgileri');
    }
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin')),
      );
      return;
    }

    final box = await _openProgramBox(currentId);
    final now = DateTime.now().millisecondsSinceEpoch;

    final tekrar = int.tryParse(_tekrarCtrl.text.trim()) ?? 0;
    final gen = int.tryParse(_genellemeCtrl.text.trim()) ?? 0;

    final kayit = {
      'programAdi': _adCtrl.text.trim(),
      'tekrarSayisi': tekrar,
      'genellemeSayisi': gen,
      'createdAt': now,
      'isActive': true, // listeye düşsün; bitirince false yapılacak
    };

    await box.add(kayit);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program oluşturuldu')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Program Oluştur')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _adCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Program adı (örn. Tak-Çıkar)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tekrarCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tekrar sayısı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'Geçersiz';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _genellemeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Genelleme sayısı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'Geçersiz';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _kaydet,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}