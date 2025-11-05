import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class EslestirmeOyunDuzenlePage extends StatefulWidget {
  final int gameId;
  const EslestirmeOyunDuzenlePage({super.key, required this.gameId});

  @override
  State<EslestirmeOyunDuzenlePage> createState() => _EslestirmeOyunDuzenlePageState();
}

class _EslestirmeOyunDuzenlePageState extends State<EslestirmeOyunDuzenlePage> {
  late Box _box;
  String _title = '';
  List<Map<String, dynamic>> _pairs = [];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('es_game_box');
    _load();
  }

  void _load() {
    final gm = Map<String, dynamic>.from(_box.get('game_${widget.gameId}') as Map? ?? {});
    _title = (gm['title'] ?? 'Yeni Eşleştirme').toString();
    _pairs = (gm['pairs'] as List?)?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    setState(() {});
  }

  Future<void> _save() async {
    await _box.put('game_${widget.gameId}', {'title': _title, 'pairs': _pairs});
    // listede de başlık güncel olsun
    final list = List<Map<String, dynamic>>.from(_box.get('_games') as List? ?? []);
    final idx = list.indexWhere((e) => e['id'] == widget.gameId);
    if (idx >= 0) {
      list[idx]['title'] = _title;
      await _box.put('_games', list);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  Future<String?> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/eslestirme');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
    await File(picked.path).copy(file.path);
    return file.path;
  }

  void _addPair() {
    setState(() {
      _pairs.add({
        'leftType': 'text',
        'left': '',
        'rightType': 'text',
        'right': '',
      });
    });
  }

  void _removePair(int i) {
    final p = _pairs[i];
    for (final key in ['left', 'right']) {
      if ((p['${key}Type'] == 'image') && (p[key] ?? '').toString().isNotEmpty) {
        try { final f = File(p[key]); if (f.existsSync()) f.deleteSync(); } catch (_) {}
      }
    }
    setState(() { _pairs.removeAt(i); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isEmpty ? 'Eşleştirme Düzenle' : _title),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPair,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: TextEditingController(text: _title),
            decoration: const InputDecoration(labelText: 'Oyun Başlığı', border: OutlineInputBorder()),
            onChanged: (v) => _title = v,
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _pairs.length; i++) _PairEditor(
            key: ValueKey('pair_$i'),
            index: i,
            data: _pairs[i],
            onChanged: (m) => setState(() => _pairs[i] = m),
            onDelete: () => _removePair(i),
            onPickImage: _pickImage,
          ),
          if (_pairs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('Çift eklemek için sağ alttaki + butonuna bas.')),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PairEditor extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;
  final Future<String?> Function() onPickImage;

  const _PairEditor({
    super.key,
    required this.index,
    required this.data,
    required this.onChanged,
    required this.onDelete,
    required this.onPickImage,
  });

  @override
  State<_PairEditor> createState() => _PairEditorState();
}

class _PairEditorState extends State<_PairEditor> {
  late String leftType;
  late String rightType;
  late String leftVal;
  late String rightVal;

  @override
  void initState() {
    super.initState();
    leftType = (widget.data['leftType'] ?? 'text').toString();
    rightType = (widget.data['rightType'] ?? 'text').toString();
    leftVal = (widget.data['left'] ?? '').toString();
    rightVal = (widget.data['right'] ?? '').toString();
  }

  void _emit() {
    widget.onChanged({
      'leftType': leftType,
      'left': leftVal,
      'rightType': rightType,
      'right': rightVal,
    });
  }

  Widget _side(String label, bool isLeft) {
    final t = isLeft ? leftType : rightType;
    final v = isLeft ? leftVal : rightVal;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'text', label: Text('Metin'), icon: Icon(Icons.title)),
                ButtonSegment(value: 'image', label: Text('Görsel'), icon: Icon(Icons.image)),
              ],
              selected: {t},
              onSelectionChanged: (s) {
                setState(() {
                  if (isLeft) leftType = s.first; else rightType = s.first;
                });
                _emit();
              },
            ),
          ]),
          const SizedBox(height: 12),
          if (t == 'text')
            TextField(
              controller: TextEditingController(text: v),
              decoration: const InputDecoration(
                labelText: 'Metin',
                border: OutlineInputBorder(),
              ),
              onChanged: (txt) {
                setState(() { if (isLeft) leftVal = txt; else rightVal = txt; });
                _emit();
              },
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 140,
                  child: Center(
                    child: v.isEmpty
                        ? const Text('Görsel seçilmedi')
                        : Image.file(File(v), fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await widget.onPickImage();
                    if (p == null) return;
                    setState(() { if (isLeft) leftVal = p; else rightVal = p; });
                    _emit();
                  },
                  icon: const Icon(Icons.image_search),
                  label: const Text('Görsel Seç'),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('row_${widget.index}'),
      background: Container(color: Colors.redAccent),
      onDismissed: (_) => widget.onDelete(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _side('Sol', true)),
              const SizedBox(width: 12),
              Expanded(child: _side('Sağ', false)),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}