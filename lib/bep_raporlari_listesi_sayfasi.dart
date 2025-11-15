import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';
import 'bep_rapor_detay_sayfasi.dart';

class BepRaporlariListesiSayfasi extends StatelessWidget {
  const BepRaporlariListesiSayfasi({super.key});

  Future<Box> _openBox(BuildContext context) async {
    final currentId = context.read<CurrentStudent>().currentStudentId;
    final boxName = currentId != null
        ? 'bep_raporlari_$currentId'
        : 'bep_raporlari';
    return Hive.openBox(boxName);
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentStudentId;

    return FutureBuilder<Box>(
      future: _openBox(context),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('BEP Raporları')),
            body: const Center(child: Text('Kutu açılamadı')),
          );
        }
        final box = snap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('BEP Raporları${currentId != null ? '  (Öğrenci: $currentId)' : ''}'),
          ),
          body: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final entries = box.keys.map((k) => MapEntry(k, box.get(k))).toList()
                ..sort((a, b) {
                  final at = (a.value?['tarih'] ?? 0) as int;
                  final bt = (b.value?['tarih'] ?? 0) as int;
                  return bt.compareTo(at); // yeni üstte
                });

              if (entries.isEmpty) {
                return const Center(child: Text('Kayıt bulunamadı'));
              }

              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final m = (e.value as Map?) ?? {};
                  final tarihStr = (m['tarihStr'] ?? '').toString();
                  final ad = (m['ogrenciAd'] ?? '').toString();

                  return ListTile(
                    title: Text(tarihStr.isEmpty ? 'Tarihsiz Kayıt' : tarihStr),
                    subtitle: Text(ad.isEmpty ? 'Öğrenci: -' : 'Öğrenci: $ad'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BepRaporDetaySayfasi(rapor: Map<String, dynamic>.from(m)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}