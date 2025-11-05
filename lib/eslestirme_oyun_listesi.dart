import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

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
  List<Map<String, dynamic>> _games = [];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('es_game_box');
    _refresh();
  }

  void _refresh() {
    final raw = _box.get('_games') as List? ?? [];
    _games = raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a,b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
    setState(() {});
  }

  Future<void> _createGame() async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final list = List<Map<String, dynamic>>.from(_box.get('_games') as List? ?? []);
    list.add({'id': id, 'title': 'Yeni Eşleştirme', 'createdAt': id});
    await _box.put('_games', list);
    await _box.put('game_$id', {'title': 'Yeni Eşleştirme', 'pairs': <Map<String, dynamic>>[]});
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: id)));
    _refresh();
  }

  Future<void> _renameGame(int id) async {
    final games = List<Map<String, dynamic>>.from(_box.get('_games') as List? ?? []);
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
    final gm = Map<String, dynamic>.from(_box.get('game_$id') as Map? ?? {});
    gm['title'] = games[idx]['title'];
    await _box.put('game_$id', gm);
    _refresh();
  }

  Future<void> _deleteGame(int id) async {
    // görsel çiftleri varsa dosyaları temizle
    final gm = Map<String, dynamic>.from(_box.get('game_$id') as Map? ?? {});
    final pairs = (gm['pairs'] as List?)?.cast<Map>() ?? [];
    for (final p in pairs) {
      for (final key in ['left', 'right']) {
        final t = (p['${key}Type'] ?? 'text').toString();
        final v = (p[key] ?? '').toString();
        if (t == 'image' && v.isNotEmpty) {
          try { final f = File(v); if (f.existsSync()) f.deleteSync(); } catch (_) {}
        }
      }
    }
    await _box.delete('game_$id');

    final list = List<Map<String, dynamic>>.from(_box.get('_games') as List? ?? []);
    list.removeWhere((e) => e['id'] == id);
    await _box.put('_games', list);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eşleştirme Oyunları')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGame,
        child: const Icon(Icons.add),
      ),
      body: _games.isEmpty
          ? const Center(child: Text('Henüz kayıtlı oyun yok. Sağ alttan oluştur.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final g = _games[i];
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
            title: Text(g['title'] ?? 'Adsız'),
            subtitle: Text(DateTime.fromMillisecondsSinceEpoch(g['createdAt']).toString()),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EslestirmeOyunDuzenlePage(gameId: g['id']))).then((_) => _refresh());
                } else if (v == 'rename') {
                  _renameGame(g['id']);
                } else if (v == 'delete') {
                  _deleteGame(g['id']);
                } else if (v == 'play') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EslestirmeOyunOynatPage(gameId: g['id'])));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Oynat'))),
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Düzenle'))),
                const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.drive_file_rename_outline), title: Text('Adı Değiştir'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Sil'))),
              ],
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EslestirmeOyunOynatPage(gameId: g['id']))),
          );
        },
      ),
    );
  }
}