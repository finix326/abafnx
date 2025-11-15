// lib/hem/saglik_ogrenci_listesi_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../app_state/current_student.dart';

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

  List<MapEntry<dynamic, dynamic>> _entries(
    Box box,
    String currentStudentId,
  ) {
    final normalizedCurrent = currentStudentId.trim();
    final keys = box.keys.toList();
    final results = <MapEntry<dynamic, dynamic>>[];

    for (final key in keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(
        (raw as Map).cast<dynamic, dynamic>(),
      );
      final owner = (map['studentId'] ?? '').toString().trim();

      if (owner.isEmpty) {
        map['studentId'] = normalizedCurrent;
        unawaited(box.put(key, map));
        results.add(MapEntry(key, map));
        continue;
      }

      if (owner == normalizedCurrent) {
        results.add(MapEntry(key, map));
      }
    }

    results.sort((a, b) {
      final an = (a.value?['ad'] ?? '').toString().toLowerCase();
      final bn = (b.value?['ad'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    });

    return results;
  }

  Future<void> _refresh() async {
    setState(() {
      _boxFuture = ensureHealthBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStudentId =
        context.watch<CurrentStudent>().currentStudentId;

    if (currentStudentId == null || currentStudentId.trim().isEmpty) {
      return const Scaffold(
        appBar: AppBar(title: Text('Sağlık')),
        body: Center(child: Text('Lütfen önce bir öğrenci seçin.')),
      );
    }

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
        final items = _entries(box, currentStudentId!);

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