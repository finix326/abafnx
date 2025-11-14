import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

/// HIVE kutusu: es_game_box
/// - '_games' : [ {id, title, createdAt}, ... ]
/// - 'game_<id>' : { title, pairs: [ {id, leftType, left, rightType, right}, ... ] }

class EslestirmeOyunDuzenlePage extends StatefulWidget {
  final int gameId;
  const EslestirmeOyunDuzenlePage({super.key, required this.gameId});

  @override
  State<EslestirmeOyunDuzenlePage> createState() => _EslestirmeOyunDuzenlePageState();
}

class _EslestirmeOyunDuzenlePageState extends State<EslestirmeOyunDuzenlePage> {
  late final Box _box;
  Map<String, dynamic> _game = {};
  final _titleCtrl = TextEditingController();

  /// Kaydetme trafiğini azaltmak için debounce
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('es_game_box');
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _saveDebounce?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _asStrMap(Map raw) => raw.map((k, v) => MapEntry(k.toString(), v));

  void _load() {
    final raw = _box.get('game_${widget.gameId}');
    final gm = (raw is Map) ? Map<String, dynamic>.from(_asStrMap(raw)) : <String, dynamic>{};
    gm['title'] = (gm['title'] ?? 'Yeni Eşleştirme').toString();

    final pairsRaw = gm['pairs'];
    final pairs = <Map<String, dynamic>>[];
    if (pairsRaw is List) {
      for (final p in pairsRaw.whereType<Map>()) {
        final m = Map<String, dynamic>.from(_asStrMap(p));
        // id yoksa üret
        m['id'] ??= DateTime.now().microsecondsSinceEpoch ^ pairs.length;
        m['leftType'] = (m['leftType'] ?? 'text').toString();
        m['rightType'] = (m['rightType'] ?? 'text').toString();
        m['left'] = (m['left'] ?? '').toString();
        m['right'] = (m['right'] ?? '').toString();
        pairs.add(m);
      }
    }
    gm['pairs'] = pairs;

    _game = gm;
    _titleCtrl.text = gm['title'];
    setState(() {});
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), _saveNow);
  }

  Future<void> _saveNow() async {
    final data = {
      'title': _titleCtrl.text.trim().isEmpty ? (_game['title'] ?? 'Eşleştirme') : _titleCtrl.text.trim(),
      'pairs': List<Map<String, dynamic>>.from((_game['pairs'] as List).map((e) => Map<String, dynamic>.from(e))),
    };
    await _box.put('game_${widget.gameId}', data);
  }

  Future<void> _addTextText() async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final pairs = List<Map<String, dynamic>>.from(_game['pairs'] as List);
    pairs.add({
      'id': id,
      'leftType': 'text',
      'left': 'Sol',
      'rightType': 'text',
      'right': 'Sağ',
    });
    _game['pairs'] = pairs;
    setState(_scheduleSave);
  }

  Future<void> _addImageImage() async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final picker = ImagePicker();
    String? leftPath;
    String? rightPath;

    // iki görsel seçtir
    final leftX = await picker.pickImage(source: ImageSource.gallery);
    if (leftX != null) leftPath = leftX.path;

    final rightX = await picker.pickImage(source: ImageSource.gallery);
    if (rightX != null) rightPath = rightX.path;

    final pairs = List<Map<String, dynamic>>.from(_game['pairs'] as List);
    pairs.add({
      'id': id,
      'leftType': 'image',
      'left': leftPath ?? '',
      'rightType': 'image',
      'right': rightPath ?? '',
    });
    _game['pairs'] = pairs;
    setState(_scheduleSave);
  }

  Future<void> _pickSideImage(int pairId, bool isLeft) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;

    final pairs = List<Map<String, dynamic>>.from(_game['pairs'] as List);
    final idx = pairs.indexWhere((e) => e['id'] == pairId);
    if (idx < 0) return;

    pairs[idx][isLeft ? 'leftType' : 'rightType'] = 'image';
    pairs[idx][isLeft ? 'left' : 'right'] = x.path;
    _game['pairs'] = pairs;
    setState(_scheduleSave);
  }

  void _setSideText(int pairId, bool isLeft, String text) {
    final pairs = List<Map<String, dynamic>>.from(_game['pairs'] as List);
    final idx = pairs.indexWhere((e) => e['id'] == pairId);
    if (idx < 0) return;
    pairs[idx][isLeft ? 'leftType' : 'rightType'] = 'text';
    pairs[idx][isLeft ? 'left' : 'right'] = text;
    _game['pairs'] = pairs;
    _scheduleSave();
  }

  void _removePair(int pairId) {
    final pairs = List<Map<String, dynamic>>.from(_game['pairs'] as List);
    // varsa görsel dosyalarını temizle
    final idx = pairs.indexWhere((e) => e['id'] == pairId);
    if (idx >= 0) {
      for (final key in ['left', 'right']) {
        final typeKey = key == 'left' ? 'leftType' : 'rightType';
        if (pairs[idx][typeKey] == 'image') {
          final path = (pairs[idx][key] ?? '').toString();
          if (path.isNotEmpty) {
            try {
              final f = File(path);
              if (f.existsSync()) f.deleteSync();
            } catch (_) {}
          }
        }
      }
      pairs.removeAt(idx);
      _game['pairs'] = pairs;
      setState(_scheduleSave);
    }
  }

  Widget _sideEditor(Map<String, dynamic> pair, bool isLeft) {
    final typeKey = isLeft ? 'leftType' : 'rightType';
    final valKey = isLeft ? 'left' : 'right';
    final type = (pair[typeKey] ?? 'text').toString();
    final val = (pair[valKey] ?? '').toString();

    if (type == 'image') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: val.isEmpty
                ? Container(
              width: 90,
              height: 90,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported),
            )
                : Image.file(File(val), width: 90, height: 90, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickSideImage(pair['id'] as int, isLeft),
            icon: const Icon(Icons.photo),
            label: const Text('Görsel'),
          ),
          TextButton(
            onPressed: () {
              // text’e çevir
              _setSideText(pair['id'] as int, isLeft, '');
              setState(() {});
            },
            child: const Text('Metne Çevir'),
          ),
        ],
      );
    }

    // text
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: TextEditingController(text: val),
            onChanged: (s) => _setSideText(pair['id'] as int, isLeft, s),
            decoration: const InputDecoration(
              labelText: 'Metin',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickSideImage(pair['id'] as int, isLeft),
          icon: const Icon(Icons.photo),
          label: const Text('Görsele Çevir'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairs = List<Map<String, dynamic>>.from((_game['pairs'] ?? const <Map<String, dynamic>>[]) as List);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          onChanged: (_) => _scheduleSave(),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Oyun başlığı'),
        ),
        actions: [
          IconButton(
            onPressed: _saveNow,
            icon: const Icon(Icons.save),
            tooltip: 'Kaydet',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_text',
            onPressed: _addTextText,
            icon: const Icon(Icons.text_fields),
            label: const Text('Metin-Metin'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_img',
            onPressed: _addImageImage,
            icon: const Icon(Icons.image),
            label: const Text('Görsel-Görsel'),
          ),
        ],
      ),
      body: pairs.isEmpty
          ? const Center(child: Text('Henüz çift yok. Alttan ekleyin.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: pairs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = pairs[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sideEditor(p, true),
                const Icon(Icons.link, size: 20),
                _sideEditor(p, false),
                IconButton(
                  onPressed: () => _removePair(p['id'] as int),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Sil',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}