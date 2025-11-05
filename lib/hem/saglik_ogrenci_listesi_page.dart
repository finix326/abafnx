// lib/hem/saglik_ogrenci_listesi_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'saglik_box.dart'; // health_students kutusunu güvenli açmak için
import 'saglik_ogrenci_form_page.dart';
import 'saglik_ogrenci_detay_page.dart';

class SaglikOgrenciListesiPage extends StatefulWidget {
  const SaglikOgrenciListesiPage({super.key});

  @override
  State<SaglikOgrenciListesiPage> createState() =>
      _SaglikOgrenciListesiPageState();
}

class _SaglikOgrenciListesiPageState extends State<SaglikOgrenciListesiPage> {
  Future<Box> _boxFuture = ensureHealthBox();

  List<MapEntry<dynamic, dynamic>> _entries(Box box) {
    final keys = box.keys.toList();
    return keys
        .map((k) => MapEntry(k, box.get(k)))
        .toList()
      ..sort((a, b) {
        final an = (a.value?['ad'] ?? '').toString().toLowerCase();
        final bn = (b.value?['ad'] ?? '').toString().toLowerCase();
        return an.compareTo(bn);
      });
  }

  Future<void> _refresh() async {
    setState(() {
      _boxFuture = ensureHealthBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box>(
      future: _boxFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: Text('Sağlık kutusu açılamadı')),
          );
        }

        final box = snap.data!;
        final items = _entries(box);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sağlık'),
            actions: [
              IconButton(
                tooltip: 'Öğrenci Ekle',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SaglikOgrenciFormPage(),
                    ),
                  );
                  await _refresh();
                },
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
            child: Text(
              'Henüz kayıt yok.\nSağ üstten + ile öğrenci ekleyin.',
              textAlign: TextAlign.center,
            ),
          )
              : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = items[i];
                final m = (e.value as Map?) ?? {};
                final ad = (m['ad'] ?? '').toString();
                final tc = (m['tcKimlik'] ?? '').toString();
                final sinif = (m['sinif'] ?? '').toString();
                final foto = (m['fotoPath'] ?? '').toString();

                Widget leading;
                if (foto.isNotEmpty && File(foto).existsSync()) {
                  leading =
                      CircleAvatar(backgroundImage: FileImage(File(foto)));
                } else {
                  leading = const CircleAvatar(child: Icon(Icons.person));
                }

                return ListTile(
                  leading: leading,
                  title: Text(ad.isEmpty ? 'İsimsiz' : ad),
                  subtitle: Text([
                    if (tc.isNotEmpty) 'TC: $tc',
                    if (sinif.isNotEmpty) 'Sınıf: $sinif',
                  ].join(' • ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaglikOgrenciDetayPage(
                          id: e.key.toString(),
                          data: Map<String, dynamic>.from(m),
                        ),
                      ),
                    );
                    await _refresh();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}