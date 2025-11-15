import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';
import 'cizelge_detay_resimli_sesli_sayfasi.dart';
import 'cizelge_detay_sayfasi.dart';
import 'cizelge_ekle_sayfasi.dart';
import 'services/finix_data_service.dart';

String _normalizeType(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase().trim();
  if (s == 'yazili' ||
      s == 'yazılı' ||
      s == 'text' ||
      s == 'yazi' ||
      s == 'yazı') {
    return 'yazili';
  }
  if (s == 'resimli_sesli' ||
      s == 'media' ||
      s.contains('resim') ||
      s.contains('ses')) {
    return 'resimli_sesli';
  }
  return 'yazili';
}

bool _matchesStudent(String? ownerId, String? currentId) {
  final trimmedOwner = ownerId?.trim();
  final normalizedOwner =
      (trimmedOwner == null || trimmedOwner.isEmpty || trimmedOwner == 'unknown')
          ? null
          : trimmedOwner;
  final trimmedCurrent = currentId?.trim();
  if (trimmedCurrent == null || trimmedCurrent.isEmpty) {
    return normalizedOwner == null;
  }
  return normalizedOwner == trimmedCurrent;
}

class CizelgeListesiSayfasi extends StatefulWidget {
  const CizelgeListesiSayfasi({super.key});

  @override
  State<CizelgeListesiSayfasi> createState() => _CizelgeListesiSayfasiState();
}

class _CizelgeListesiSayfasiState extends State<CizelgeListesiSayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('cizelge_kutusu');
  }

  Future<void> _clearForStudent(
    Box<Map<dynamic, dynamic>> box,
    String? currentStudentId,
  ) async {
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final record = FinixDataService.decode(
        raw,
        module: 'cizelge',
        fallbackStudentId: currentStudentId,
      );
      if (!FinixDataService.isRecord(raw)) {
        unawaited(box.put(key, record.toMap()));
      }
      final ownerId = record.studentId.trim();
      if (_matchesStudent(ownerId, currentStudentId)) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      await box.delete(key);
      unawaited(
        FinixDataService.deleteRecord('cizelge', key.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStudentId = context.watch<CurrentStudent>().currentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çizelgeler'),
        actions: [
          FutureBuilder<Box<Map<dynamic, dynamic>>>(
            future: _boxFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final box = snapshot.data!;
              return IconButton(
                tooltip: 'Tümünü temizle',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () async {
                  final onay = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Çizelgeler silinsin mi?'),
                      content: Text(
                        (currentStudentId == null || currentStudentId.isEmpty)
                            ? 'Genel çizelgelerin hepsi silinecek.'
                            : 'Bu öğrenciye ait tüm çizelgeler silinecek.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Vazgeç'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sil'),
                        ),
                      ],
                    ),
                  );
                  if (onay == true) {
                    await _clearForStudent(box, currentStudentId);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Box<Map<dynamic, dynamic>>>(
        future: _boxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Çizelge kutusu açılamadı.'));
          }

          final box = snapshot.data!;
          return ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final entries = <MapEntry<dynamic, FinixRecord>>[];
              for (final key in box.keys) {
                final raw = box.get(key);
                if (raw is! Map) continue;
                final record = FinixDataService.decode(
                  raw,
                  module: 'cizelge',
                  fallbackStudentId: currentStudentId,
                );
                if (!FinixDataService.isRecord(raw)) {
                  unawaited(box.put(key, record.toMap()));
                }
                final ownerId = record.studentId.trim();
                if (!_matchesStudent(ownerId, currentStudentId)) continue;

                entries.add(MapEntry(key, record));
              }

              entries.sort((a, b) {
                final at = a.value.createdAt;
                final bt = b.value.createdAt;
                return bt.compareTo(at);
              });

              if (entries.isEmpty) {
                final text = (currentStudentId == null ||
                        currentStudentId.trim().isEmpty)
                    ? 'Henüz genel çizelge yok. Sağ alttan ekleyin.'
                    : 'Bu öğrenci için çizelge yok. Sağ alttan ekleyin.';
                return Center(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final map = Map<String, dynamic>.from(entry.value.payload);

                  final tur = _normalizeType(map['tur'] ?? map['type']);
                  final ad = (map['ad'] ??
                          map['cizelgeAdi'] ??
                          entry.key.toString())
                      .toString();

                  final emoji = tur == 'resimli_sesli' ? '🖼️🎙️' : '📝';
                  final subtitle =
                      tur == 'resimli_sesli' ? 'Resimli / Sesli' : 'Yazılı';

                  return ListTile(
                    leading: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(ad),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (tur == 'resimli_sesli') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CizelgeDetayResimliSesliSayfasi(
                              cizelgeAdi: entry.key.toString(),
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CizelgeDetaySayfasi(
                              cizelgeAdi: entry.key.toString(),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
