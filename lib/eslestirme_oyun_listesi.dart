import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'ai/ai_prompt_sheet.dart';
import 'app_state/current_student.dart';
import 'data/finix_data_service.dart';

import 'eslestirme_oyun_duzenle.dart';
import 'eslestirme_oyun_oynat.dart';

/// HIVE kutusu: es_game_box
/// - '_games' : [ {id, title, createdAt}, ... ]
/// - 'game_<id>' : { title, pairs: [ {leftType, left, rightType, right}, ... ] }
class EslestirmeOyunListesiPage extends StatefulWidget {
  const EslestirmeOyunListesiPage({super.key});

  @override
  State<EslestirmeOyunListesiPage> createState() => _EslestirmeOyunListesiPageState();
}

const String _matchingModule = 'matching_game';

class _EslestirmeOyunListesiPageState extends State<EslestirmeOyunListesiPage> {
  late Box _box;
  final FinixDataService _dataService = FinixDataService.instance;

  @override
  void initState() {
    super.initState();
    // main.dart’ta `await Hive.initFlutter(); await Hive.openBox('es_game_box');` çağrılmış olmalı.
    _box = Hive.box('es_game_box');
  }

  /// Güvenli map dönüştürücü (dynamic -> Map<String, dynamic>)
  Map<String, dynamic> _asStrMap(Map raw) =>
      raw.map((k, v) => MapEntry(k.toString(), v));

  /// `_games` listesini güvenle oku ve sırala (en yeni en üstte)
  List<Map<String, dynamic>> _readGames(String? currentStudentId) {
    final raw = _box.get('_games');
    if (raw is! List) return const [];

    final list = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(_asStrMap(e));
        // createdAt alanını int'e çevir, yoksa 0 kabul et
        final ca = m['createdAt'];
        final createdAt = (ca is int) ? ca : int.tryParse('${ca ?? ''}') ?? 0;
        m['createdAt'] = createdAt;
        m['studentId'] = (m['studentId'] ?? '').toString();
        list.add(m);
      }
    }

    final detailUpdates = <int, Map<String, dynamic>>{};
    bool needsWriteBack = false;

    if (currentStudentId != null) {
      for (final game in list) {
        final sid = (game['studentId'] ?? '').toString();
        if (sid.isEmpty) {
          game['studentId'] = currentStudentId;
          needsWriteBack = true;
          final detailKey = 'game_${game['id']}';
          final detailRaw = _box.get(detailKey);
          if (detailRaw is Map) {
            final detail = Map<String, dynamic>.from(_asStrMap(detailRaw));
            detail['studentId'] = currentStudentId;
            detailUpdates[game['id'] as int] = detail;
          }
        }
      }
      if (needsWriteBack) {
        Future.microtask(() async {
          await _box.put('_games', list);
          for (final entry in detailUpdates.entries) {
            await _box.put('game_${entry.key}', entry.value);
          }
        });
      }
    }

    final filtered = currentStudentId == null
        ? list
        : list
            .where((game) {
              final sid = (game['studentId'] ?? '').toString();
              return sid == currentStudentId;
            })
            .toList();

    filtered.sort(
        (a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
    return filtered;
  }

  Future<void> _createGame() async {
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
      );
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch;
    const title = 'Yeni Eşleştirme';

    final current = _box.get('_games');
    final list = (current is List)
        ? List<Map<String, dynamic>>.from(
            current.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStrMap(e))),
          )
        : <Map<String, dynamic>>[];

    list.add({
      'id': id,
      'title': title,
      'createdAt': id,
      'studentId': currentId,
    });
    await _box.put('_games', list);
    await _box.put('game_$id', {
      'title': title,
      'pairs': <Map<String, dynamic>>[],
      'studentId': currentId,
    });

    final record = _dataService.buildRecord(
      studentId: currentId,
      module: _matchingModule,
      entityId: id.toString(),
      title: title,
      createdAt: id,
      payload: const {
        'pairCount': 0,
        'source': 'manual',
      },
    );
    await _dataService.upsert(record);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: id)),
    );
    // ValueListenableBuilder zaten ekranı tazeler; ekstra setState gerekmez.
  }

  Future<void> _createGameFromAI(String aiResponse) async {
    final currentId = context.read<CurrentStudent>().currentId;
    if (currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
      );
      return;
    }

    // AI'den dönen cevabı JSON olarak parse et
    List<dynamic> decoded;
    try {
      decoded = List<dynamic>.from(jsonDecode(aiResponse));
    } catch (e) {
      debugPrint("AI JSON parse error: $e");
      return;
    }

    // Her elemanı metin tabanlı bir eşleştirme çiftine çevir
    final pairs = decoded.map<Map<String, dynamic>>((item) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(_asStrMap(item));
        return {
          'leftType': 'text',
          'left': (m['left'] ?? '').toString(),
          'rightType': 'text',
          'right': (m['right'] ?? '').toString(),
        };
      }
      return {
        'leftType': 'text',
        'left': '',
        'rightType': 'text',
        'right': '',
      };
    }).toList();

    // Yeni oyun id'si oluştur
    final id = DateTime.now().millisecondsSinceEpoch;

    // Var olan oyun listesini oku
    final current = _box.get('_games');
    final list = (current is List)
        ? List<Map<String, dynamic>>.from(
            current.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(_asStrMap(e)),
                ),
          )
        : <Map<String, dynamic>>[];

    // Listeye yeni oyunu ekle
    const title = 'AI Eşleştirme';
    list.add({
      'id': id,
      'title': title,
      'createdAt': id,
      'studentId': currentId,
    });
    await _box.put('_games', list);

    // Oyun içeriğini kaydet
    await _box.put('game_$id', {
      'title': title,
      'pairs': pairs,
      'studentId': currentId,
    });

    final record = _dataService.buildRecord(
      studentId: currentId,
      module: _matchingModule,
      entityId: id.toString(),
      title: title,
      createdAt: id,
      payload: {
        'pairCount': pairs.length,
        'source': 'ai',
      },
    );
    await _dataService.upsert(record);

    if (!mounted) return;

    // Kullanıcıyı düzenleme ekranına yönlendir
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: id)),
    );
    // ValueListenableBuilder ekranı otomatik tazeleyecek
  }

  Future<void> _renameGame(int id) async {
    final current = _box.get('_games');
    final games = (current is List)
        ? List<Map<String, dynamic>>.from(
            current.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(_asStrMap(e)),
                ),
          )
        : <Map<String, dynamic>>[];

    final idx = games.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;

    final controller =
        TextEditingController(text: (games[idx]['title'] ?? '').toString());
    final storedStudentId = (games[idx]['studentId'] ?? '').toString();
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oyun adını düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newTitle == null) return;

    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    games[idx]['title'] = trimmed;
    games[idx]['studentId'] = storedStudentId;
    await _box.put('_games', games);

    final gmRaw = _box.get('game_$id');
    final gm =
        (gmRaw is Map) ? Map<String, dynamic>.from(_asStrMap(gmRaw)) : <String, dynamic>{};
    gm['title'] = trimmed;
    gm['studentId'] = (gm['studentId'] ?? storedStudentId).toString();
    await _box.put('game_$id', gm);

    final effectiveStudentId = storedStudentId.isNotEmpty
        ? storedStudentId
        : context.read<CurrentStudent>().currentId;

    if (effectiveStudentId != null && effectiveStudentId.isNotEmpty) {
      final record = _dataService.get(
        studentId: effectiveStudentId,
        module: _matchingModule,
        entityId: id.toString(),
      );
      final payload = Map<String, dynamic>.from(record?.payload ?? {});
      payload['pairCount'] =
          (gm['pairs'] is List) ? (gm['pairs'] as List).length : payload['pairCount'] ?? 0;
      payload.putIfAbsent('source', () => 'manual');

      final targetRecord = record ??
          _dataService.buildRecord(
            studentId: effectiveStudentId,
            module: _matchingModule,
            entityId: id.toString(),
            title: trimmed,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            payload: payload,
          );

      await _dataService.upsert(
        targetRecord.copyWith(
          title: trimmed,
          payload: payload,
        ),
      );
    }
  }

  Future<void> _deleteGame(int id) async {
    // görsel çiftleri varsa dosyaları temizle
    final gmRaw = _box.get('game_$id');
    final gm =
        (gmRaw is Map) ? Map<String, dynamic>.from(_asStrMap(gmRaw)) : <String, dynamic>{};
    final pairs = (gm['pairs'] is List) ? (gm['pairs'] as List).whereType<Map>().toList() : <Map>[];

    for (final p in pairs) {
      final pp = _asStrMap(p);
      for (final key in ['left', 'right']) {
        final t = (pp['${key}Type'] ?? 'text').toString();
        final v = (pp[key] ?? '').toString();
        if (t == 'image' && v.isNotEmpty) {
          try {
            final f = File(v);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {
            // dosya temizleme hatalarını yut
          }
        }
      }
    }
    await _box.delete('game_$id');

    final current = _box.get('_games');
    final list = (current is List)
        ? List<Map<String, dynamic>>.from(
            current.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(_asStrMap(e)),
                ),
          )
        : <Map<String, dynamic>>[];
    String studentId = '';
    list.removeWhere((e) {
      final match = e['id'] == id;
      if (match) {
        studentId = (e['studentId'] ?? '').toString();
      }
      return match;
    });
    await _box.put('_games', list);

    final effectiveStudentId = studentId.isNotEmpty
        ? studentId
        : context.read<CurrentStudent>().currentId;
    if (effectiveStudentId != null && effectiveStudentId.isNotEmpty) {
      await _dataService.delete(
        studentId: effectiveStudentId,
        module: _matchingModule,
        entityId: id.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eşleştirme Oyunları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              showAIPromptSheet(
                context: context,
                onCompleted: _createGameFromAI,
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'eslestirme_ai',
            onPressed: () {
              showAIPromptSheet(
                context: context,
                onCompleted: _createGameFromAI,
              );
            },
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'eslestirme_manual',
            onPressed: _createGame,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: currentId == null
          ? const Center(child: Text('Lütfen bir öğrenci seçin.'))
          : ValueListenableBuilder<Box>(
              valueListenable: _box.listenable(keys: const ['_games']),
              builder: (_, __, ___) {
                final games = _readGames(currentId);

                if (games.isEmpty) {
                  return const Center(
                    child:
                        Text('Henüz kayıtlı oyun yok. Sağ alttan oluştur.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final g = games[i];
                    final title = (g['title'] ?? 'Adsız').toString();

                    final createdMs = (g['createdAt'] is int)
                        ? g['createdAt'] as int
                        : int.tryParse('${g['createdAt'] ?? ''}') ?? 0;

                    final createdAt =
                        DateTime.fromMillisecondsSinceEpoch(createdMs);
                    final formattedDate =
                        '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';

                    return ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      tileColor:
                          Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
                      title: Text(title),
                      subtitle: Text(formattedDate),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      EslestirmeOyunDuzenlePage(gameId: g['id'] as int)),
                            );
                          } else if (v == 'rename') {
                            _renameGame(g['id'] as int);
                          } else if (v == 'delete') {
                            _deleteGame(g['id'] as int);
                          } else if (v == 'play') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      EslestirmeOyunOynatPage(gameId: g['id'] as int)),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'play',
                              child: ListTile(
                                  leading: Icon(Icons.play_arrow),
                                  title: Text('Oynat'))),
                          PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Düzenle'))),
                          PopupMenuItem(
                              value: 'rename',
                              child: ListTile(
                                  leading: Icon(Icons.drive_file_rename_outline),
                                  title: Text('Adı Değiştir'))),
                          PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  title: Text('Sil'))),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                EslestirmeOyunOynatPage(gameId: g['id'] as int)),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}