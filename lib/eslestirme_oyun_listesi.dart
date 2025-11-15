import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ai/finix_ai_button.dart';

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

class _EslestirmeOyunListesiPageState extends State<EslestirmeOyunListesiPage> {
  late Box _box;

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
  List<Map<String, dynamic>> _readGames() {
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
        list.add(m);
      }
    }

    list.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
    return list;
  }

  Future<void> _createGame() async {
    final id = DateTime.now().millisecondsSinceEpoch;

    final current = _box.get('_games');
    final list = (current is List)
        ? List<Map<String, dynamic>>.from(
            current.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStrMap(e))),
          )
        : <Map<String, dynamic>>[];

    list.add({'id': id, 'title': 'Yeni Eşleştirme', 'createdAt': id});
    await _box.put('_games', list);
    await _box.put('game_$id', {
      'title': 'Yeni Eşleştirme',
      'pairs': <Map<String, dynamic>>[],
    });

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: id)),
    );
    // ValueListenableBuilder zaten ekranı tazeler; ekstra setState gerekmez.
  }

  Future<void> _createGameFromAI(String aiResponse) async {
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
    list.add({'id': id, 'title': 'AI Eşleştirme', 'createdAt': id});
    await _box.put('_games', list);

    // Oyun içeriğini kaydet
    await _box.put('game_$id', {
      'title': 'AI Eşleştirme',
      'pairs': pairs,
    });

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
            current.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStrMap(e))),
          )
        : <Map<String, dynamic>>[];

    final idx = games.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;

    final controller = TextEditingController(text: (games[idx]['title'] ?? '').toString());
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oyun adını düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Başlık', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Kaydet')),
        ],
      ),
    );
    if (newTitle == null) return;

    games[idx]['title'] = newTitle.isEmpty ? games[idx]['title'] : newTitle;
    await _box.put('_games', games);

    final gmRaw = _box.get('game_$id');
    final gm = (gmRaw is Map) ? Map<String, dynamic>.from(_asStrMap(gmRaw)) : <String, dynamic>{};
    gm['title'] = games[idx]['title'];
    await _box.put('game_$id', gm);
  }

  Future<void> _deleteGame(int id) async {
    // görsel çiftleri varsa dosyaları temizle
    final gmRaw = _box.get('game_$id');
    final gm = (gmRaw is Map) ? Map<String, dynamic>.from(_asStrMap(gmRaw)) : <String, dynamic>{};
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
            current.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStrMap(e))),
          )
        : <Map<String, dynamic>>[];
    list.removeWhere((e) => e['id'] == id);
    await _box.put('_games', list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eşleştirme Oyunları'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FinixAIButton.small(
              contextDescription: 'Eşleştirme oyunu üretim asistanı',
              onResult: (response) {
                _createGameFromAI(response);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGame,
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: _box.listenable(keys: const ['_games']),
        builder: (_, __, ___) {
          final games = _readGames();

          if (games.isEmpty) {
            return const Center(child: Text('Henüz kayıtlı oyun yok. Sağ alttan oluştur.'));
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

              final createdAt = DateTime.fromMillisecondsSinceEpoch(createdMs, isUtc: false);

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
                title: Text(title),
                subtitle: Text(createdAt.toString()),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: g['id'] as int)),
                      );
                    } else if (v == 'rename') {
                      _renameGame(g['id'] as int);
                    } else if (v == 'delete') {
                      _deleteGame(g['id'] as int);
                    } else if (v == 'play') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EslestirmeOyunOynatPage(gameId: g['id'] as int)),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Oynat'))),
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Düzenle'))),
                    PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.drive_file_rename_outline), title: Text('Adı Değiştir'))),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Sil'))),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EslestirmeOyunOynatPage(gameId: g['id'] as int)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}