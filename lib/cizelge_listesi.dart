import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';

// Detay sayfaları (sizdeki imzalar korunuyor)
import 'cizelge_detay_sayfasi.dart';
import 'cizelge_detay_resimli_sesli_sayfasi.dart';
import 'cizelge_ekle_sayfasi.dart';

/// Öğrenciye özel kutu adı (yoksa genel kutuya düşer)
/// Eski/yanlış değerleri güvenli bir şekilde normalize et.
String _normalizeType(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase().trim();
  if (s == 'yazili' || s == 'yazılı' || s == 'text' || s == 'yazi' || s == 'yazı') {
    return 'yazili';
  }
  if (s == 'resimli_sesli' || s == 'media' || s.contains('resim') || s.contains('ses')) {
    return 'resimli_sesli';
  }
  // bilinmiyorsa yazılıya düş
  return 'yazili';
}

class CizelgeListesiSayfasi extends StatelessWidget {
  const CizelgeListesiSayfasi({super.key});

  Future<Box> _openBox(String studentId) async =>
      Hive.openBox('cizelge_kutusu_$studentId');

  @override
  Widget build(BuildContext context) {
    // Öğrenci değişiminde rebuild olsun
    final currentId = context.watch<CurrentStudent?>()?.currentId;

    if (currentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Çizelgeler')),
        body: const Center(child: Text('Lütfen önce bir öğrenci seçin.')),
      );
    }

    return FutureBuilder<Box>(
      future: _openBox(currentId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Çizelgeler')),
            body: const Center(child: Text('Kutu açılamadı')),
          );
        }
        final box = snap.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('Çizelgeler  (Öğrenci: $currentId)'),
            actions: [
              IconButton(
                tooltip: 'Tümünü temizle',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Tüm çizelgeler silinsin mi?'),
                      content: const Text('Bu işlem geri alınamaz.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                      ],
                    ),
                  );
                  if (ok == true) await box.clear();
                },
              ),
            ],
          ),
          body: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final entries = box.keys.map((k) {
                final v = box.get(k);
                return MapEntry(k, Map<String, dynamic>.from((v as Map?) ?? {}));
              }).toList()
                ..sort((a, b) {
                  final at = (a.value['createdAt'] ?? 0) as int;
                  final bt = (b.value['createdAt'] ?? 0) as int;
                  return bt.compareTo(at); // yeni en üstte
                });

              if (entries.isEmpty) {
                return const Center(child: Text('Henüz çizelge yok. Sağ alttan ekleyin.'));
              }

              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final m = e.value;

                  final tur = _normalizeType(m['tur'] ?? m['type']);
                  final ad = (m['ad'] ?? m['cizelgeAdi'] ?? e.key.toString()).toString();

                  final emoji = tur == 'resimli_sesli' ? '🖼️🎙️' : '📝';
                  final subtitle = tur == 'resimli_sesli' ? 'Resimli / Sesli' : 'Yazılı';

                  return ListTile(
                    leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(ad),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (tur == 'resimli_sesli') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CizelgeDetayResimliSesliSayfasi(
                              cizelgeAdi: e.key.toString(),
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CizelgeDetaySayfasi(
                              cizelgeAdi: e.key.toString(),
                              tur: 'yazili',
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Çizelge ekle',
            child: const Icon(Icons.add),
            onPressed: () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Text('📝', style: TextStyle(fontSize: 20)),
                        title: const Text('Yazılı Çizelge'),
                        onTap: () => Navigator.pop(context, 'yazili'),
                      ),
                      ListTile(
                        leading: const Text('🖼️🎙️', style: TextStyle(fontSize: 20)),
                        title: const Text('Resimli + Sesli Çizelge'),
                        onTap: () => Navigator.pop(context, 'resimli_sesli'),
                      ),
                    ],
                  ),
                ),
              );
              if (picked == null) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CizelgeEkleSayfasi(
                    tur: _normalizeType(picked),
                    studentId: currentId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}