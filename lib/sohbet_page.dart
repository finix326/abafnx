import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// HIVE şema (basit Map):
/// sohbet_kutusu:
///   key: photoId (String, ör: 'p_169...' )
///   value: {
///     'title': 'Kullanıcının vereceği başlık',
///     'path': '<appDocs>/sohbet/<photoId>.jpg',
///     'pins': [
///       { 'x': 0.42, 'y': 0.33, 'audio': '<appDocs>/sohbet/<photoId>_<ts>.aac', 'ts': 169... }
///     ],
///     'createdAt': millis
///   }
///
/// Not: x,y [0..1] oransal; cihaz boyutu değişse de doğru yerde görünür.

class SohbetPage extends StatefulWidget {
  const SohbetPage({super.key});
  @override
  State<SohbetPage> createState() => _SohbetPageState();
}

class _SohbetPageState extends State<SohbetPage> {
  late Box _box;
  List<Map<String, dynamic>> _sohbetList = [];
  Map<String, dynamic>? _sohbet;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('sohbet_kutusu');
    _refreshSohbetList();
  }

  void _refreshSohbetList() {
    // Sohbetler: her biri bir sohbet sayfası, id, createdAt, photos:[]
    // V1: sohbetler kutuya _sohbetler anahtarında tutulacak
    final raw = _box.get('_sohbetler') as List?;
    _sohbetList = (raw ?? []).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    // Sona eklenen en üstte
    _sohbetList.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
  }

  Future<void> _createNewSohbet() async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final yeni = {
      'id': id,
      'createdAt': id,
      'title': 'Yeni Sohbet',
      'photos': <String>[],
    };
    final list = List<Map<String, dynamic>>.from(_box.get('_sohbetler') as List? ?? []);
    list.add(yeni);
    await _box.put('_sohbetler', list);
    if (mounted) setState(() {
      _refreshSohbetList();
    });
  }


  Future<void> _deleteSohbet(int sohbetId) async {
    // Sohbetin tüm fotoğraflarını da sil
    final sohbet = _sohbetList.firstWhere((e) => e['id'] == sohbetId, orElse: () => <String, dynamic>{});
    if (sohbet.isNotEmpty) {
      final List photos = sohbet['photos'] ?? [];
      for (final pid in photos) {
        final m = (_box.get(pid) as Map?) ?? {};
        final pins = (m['pins'] as List?)?.cast<Map>() ?? [];
        for (final p in pins) {
          final a = (p['audio'] ?? '').toString();
          if (a.isNotEmpty && File(a).existsSync()) {
            try { File(a).deleteSync(); } catch (_) {}
          }
        }
        final path = (m['path'] ?? '').toString();
        if (path.isNotEmpty && File(path).existsSync()) {
          try { File(path).deleteSync(); } catch (_) {}
        }
        await _box.delete(pid);
      }
    }
    // Sohbeti listeden sil
    final list = List<Map<String, dynamic>>.from(_box.get('_sohbetler') as List? ?? []);
    list.removeWhere((e) => e['id'] == sohbetId);
    await _box.put('_sohbetler', list);
    if (mounted) setState(() {
      _refreshSohbetList();
    });
  }


  Future<void> _renameSohbet(int sohbetId) async {
    final raw = _box.get('_sohbetler') as List? ?? [];
    final list = List<Map<String, dynamic>>.from(
      raw.map((e) => Map<String, dynamic>.from(e)),
    );
    final idx = list.indexWhere((e) => e['id'] == sohbetId);
    if (idx < 0) return;

    final currentTitle = (list[idx]['title'] ?? 'Sohbet #$sohbetId').toString();
    final controller = TextEditingController(text: currentTitle);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sohbet adını düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newTitle == null) return;
    list[idx]['title'] = newTitle.isEmpty ? currentTitle : newTitle;
    await _box.put('_sohbetler', list);

    if (!mounted) return;
    setState(() {
      if (_sohbet != null && (_sohbet!['id'] as int?) == sohbetId) {
        _sohbet!['title'] = list[idx]['title'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _sohbetList;
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewSohbet,
        child: const Icon(Icons.add_comment),
      ),
      body: items.isEmpty
          ? const Center(child: Text('Henüz sohbet sayfası yok. Sağ alttan ekleyin.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final sohbet = items[i];
          final id = sohbet['id'];
          final date = DateTime.fromMillisecondsSinceEpoch(sohbet['createdAt']);
          final title = (sohbet['title'] ?? 'Sohbet #$id').toString();
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.blue.shade50,
            title: Text(title),
            subtitle: Text('${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2,'0')}'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _SohbetEditor(sohbetId: id)),
              ).then((_) {
                if (mounted) setState(() {
                  _refreshSohbetList();
                });
              });
            },
            onLongPress: () async {
              final act = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => SafeArea(
                  child: Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Yeniden adlandır'),
                      onTap: () => Navigator.pop(context, 'rename'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Sohbeti Sil'),
                      onTap: () => Navigator.pop(context, 'delete'),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              );
              if (act == 'delete') _deleteSohbet(id);
              if (act == 'rename') _renameSohbet(id);
            },
          );
        },
      ),
    );
  }
}


/// Sohbet düzenleyici: foto ekle/sil, fotoğrafa tıkla ve pin mantığı
class _SohbetEditor extends StatefulWidget {
  final int sohbetId;
  const _SohbetEditor({required this.sohbetId});
  @override
  State<_SohbetEditor> createState() => _SohbetEditorState();
}

class _SohbetEditorState extends State<_SohbetEditor> {
  late Box _box;
  Map<String, dynamic>? _sohbet;
  List<String> _photos = [];
  // Her fotoğraf kutusunun ekranda kapladığı oran (kalıcı)
  final Map<String, double> _boxScale = {}; // photoId -> scale
  String? _scalingId; // aktif ölçeklenen foto
  double? _pinchStartScale; // geçici: pinch başlangıç ölçeği
  final Duration _resizeAnim = const Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _box = Hive.box('sohbet_kutusu');
    _refresh();
  }

  void _refresh() {
    final raw = _box.get('_sohbetler') as List?;
    final list = (raw ?? []).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    final found = list.firstWhere((e) => e['id'] == widget.sohbetId, orElse: () => <String, dynamic>{});
    _sohbet = found.isEmpty ? null : found;
    _photos = List<String>.from(_sohbet?['photos'] ?? []);
    // boxScale değerlerini oku
    _boxScale.clear();
    for (final pid in _photos) {
      final m = (_box.get(pid) as Map?) ?? {};
      final s = (m['boxScale'] as num?)?.toDouble() ?? 1.0;
      _boxScale[pid] = s.clamp(0.5, 3.0);
      // pinch başlangıcı sıfırla
      _pinchStartScale = null;
    }
    setState(() {});
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sohbet');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final photoId = 'p_${DateTime.now().millisecondsSinceEpoch}';
    final ext = picked.path.split('.').last.toLowerCase();
    final target = File('${dir.path}/$photoId.$ext');
    await File(picked.path).copy(target.path);

    await _box.put(photoId, {
      'path': target.path,
      'pins': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Sohbete ekle
    final raw = _box.get('_sohbetler') as List? ?? [];
    final list = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e)));
    final idx = list.indexWhere((e) => e['id'] == widget.sohbetId);
    if (idx >= 0) {
      final photos = List<String>.from(list[idx]['photos'] ?? []);
      photos.add(photoId);
      list[idx]['photos'] = photos;
      await _box.put('_sohbetler', list);
    }
    _refresh();
  }

  Future<void> _deletePhoto(String photoId) async {
    final m = (_box.get(photoId) as Map?) ?? {};
    // Ses dosyalarını da temizle
    final pins = (m['pins'] as List?)?.cast<Map>() ?? [];
    for (final p in pins) {
      final a = (p['audio'] ?? '').toString();
      if (a.isNotEmpty && File(a).existsSync()) {
        try { File(a).deleteSync(); } catch (_) {}
      }
    }
    // Fotoğrafı da sil
    final path = (m['path'] ?? '').toString();
    if (path.isNotEmpty && File(path).existsSync()) {
      try { File(path).deleteSync(); } catch (_) {}
    }
    await _box.delete(photoId);
    // Sohbetten çıkar
    final raw = _box.get('_sohbetler') as List? ?? [];
    final list = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e)));
    final idx = list.indexWhere((e) => e['id'] == widget.sohbetId);
    if (idx >= 0) {
      final photos = List<String>.from(list[idx]['photos'] ?? []);
      photos.remove(photoId);
      list[idx]['photos'] = photos;
      await _box.put('_sohbetler', list);
    }
    _boxScale.remove(photoId);
    _refresh();
  }

  Future<void> _renameSohbet(int sohbetId) async {
    // _sohbet listesini kutudan çek
    final raw = _box.get('_sohbetler') as List? ?? [];
    final list = List<Map<String, dynamic>>.from(
      raw.map((e) => Map<String, dynamic>.from(e)),
    );
    final idx = list.indexWhere((e) => e['id'] == sohbetId);
    if (idx < 0) return;

    final currentTitle = (list[idx]['title'] ?? 'Sohbet #$sohbetId').toString();
    final controller = TextEditingController(text: currentTitle);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sohbet adını düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newTitle == null) return;
    list[idx]['title'] = newTitle.isEmpty ? currentTitle : newTitle;
    await _box.put('_sohbetler', list);

    if (!mounted) return;
    setState(() {
      // Yerel başlığı da güncelle
      _sohbet ??= {};
      _sohbet!['title'] = list[idx]['title'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = _sohbet != null ? DateTime.fromMillisecondsSinceEpoch(_sohbet!['createdAt']) : null;
    return Scaffold(
      appBar: AppBar(
        title: Text((_sohbet?['title'] ?? 'Sohbet #${_sohbet?['id'] ?? ''}').toString()),
        bottom: date != null
            ? PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${date!.day}.${date!.month}.${date!.year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        )
            : null,
        actions: [
          IconButton(
            tooltip: 'Adı düzenle',
            icon: const Icon(Icons.edit),
            onPressed: () {
              final id = (_sohbet?['id'] as int?);
              if (id != null) _renameSohbet(id);
            },
          ),
          IconButton(
            tooltip: 'Fotoğraf ekle',
            icon: const Icon(Icons.add_a_photo),
            onPressed: _addPhoto,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ---- TABAN: FOTOĞRAF LİSTESİ ----
          if (_photos.isEmpty)
            const Center(child: Text('Henüz fotoğraf yok. Üstten ekleyin.'))
          else
            ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const BouncingScrollPhysics(),
              itemCount: _photos.length,
              itemBuilder: (_, i) {
                final pid = _photos[i];
                final m = (_box.get(pid) as Map?) ?? {};
                final path = (m['path'] ?? '').toString();

                return Padding(
                  key: ValueKey(pid),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onScaleStart: (_) {
                      _scalingId = pid;
                      _pinchStartScale = (_boxScale[pid] ?? 1.0);
                    },
                    onScaleUpdate: (details) {
                      if (_scalingId != pid) return;
                      // Yeni ölçek: başlangıç ölçeği * gesture ölçeği (daha stabil)
                      final start = _pinchStartScale ?? (_boxScale[pid] ?? 1.0);
                      final calc = (start * details.scale).clamp(0.5, 3.0);
                      // Yumuşatma: ani sıçramayı engelle
                      final prev = (_boxScale[pid] ?? 1.0);
                      final smoothed = prev + (calc - prev) * 0.3; // %30 yaklaş
                      setState(() {
                        _boxScale[pid] = smoothed;
                      });
                    },
                    onScaleEnd: (_) async {
                      if (_scalingId != pid) return;
                      _scalingId = null;
                      // kalıcı kaydet
                      final mp = Map<String, dynamic>.from((_box.get(pid) as Map?) ?? {});
                      mp['boxScale'] = (_boxScale[pid] ?? 1.0).clamp(0.5, 3.0);
                      await _box.put(pid, mp);
                      _pinchStartScale = null;
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: _resizeAnim,
                        curve: Curves.easeOut,
                        height: (250.0 * ((_boxScale[pid] ?? 1.0).clamp(0.5, 3.0))),
                        decoration: BoxDecoration(
                          // Arkaplan kutucuk hissini azalt
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (path.isNotEmpty && File(path).existsSync())
                            // Kutu içinde taşmadan göster
                              FittedBox(
                                fit: BoxFit.contain,
                                child: Image.file(File(path)),
                              )
                            else
                              Container(
                                color: Colors.grey.shade300,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            // Uzun basınca menü
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onLongPress: () async {
                                    final act = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (_) => SafeArea(
                                        child: Wrap(children: [
                                          ListTile(
                                            leading: const Icon(Icons.graphic_eq),
                                            title: const Text('Ses bölgelerini düzenle'),
                                            subtitle: const Text('Bölge seç, kaydet, çal'),
                                            onTap: () => Navigator.pop(context, 'audio'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.aspect_ratio),
                                            title: const Text('Boyutu varsayılan yap'),
                                            onTap: () => Navigator.pop(context, 'reset'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.delete_outline, color: Colors.red),
                                            title: const Text('Fotoğrafı Sil'),
                                            onTap: () => Navigator.pop(context, 'delete'),
                                          ),
                                          const SizedBox(height: 8),
                                        ]),
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (act == 'delete') {
                                      _deletePhoto(pid);
                                    } else if (act == 'reset') {
                                      setState(() {
                                        _boxScale[pid] = 1.0;
                                      });
                                      final mp = Map<String, dynamic>.from((_box.get(pid) as Map?) ?? {});
                                      mp['boxScale'] = 1.0;
                                      await _box.put(pid, mp);
                                    } else if (act == 'audio') {
                                      // Ses/dikdörtgen düzenleyiciyi aç
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => _PhotoEditor(photoId: pid)),
                                      );
                                      if (mounted) setState(() {}); // dönüşte tazele
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // (Tam ekran zoom/pan overlay kaldırıldı)
        ],
      ),
    );
  }
}

/// Tam ekran fotoğraf + pin (sesli) düzenleyici (mevcut mantık, sohbet içinde çağrılır)
class _PhotoEditor extends StatefulWidget {
  final String photoId;
  const _PhotoEditor({required this.photoId});

  @override
  State<_PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<_PhotoEditor> {
  // Seçim modu: kullanıcı kayıt bölgesi seçmek için mic'e basar
  bool _selectMode = false;
  late Box _box;
  late String _imgPath;
  // Dikdörtgen bölgeler: {x, y, w, h, audio, ts}  (x,y,w,h: 0..1 normalize)
  List<Map<String, dynamic>> _regions = [];

  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();

  bool _recReady = false;
  bool _isRecording = false;

  // Düzenleme modu (görsel overlay sadece bu modda)
  bool _editMode = false;

  // Bölge seçim animasyonu/kırp çizimi
  bool _isSelecting = false;
  Offset? _selStart;        // local start
  Rect? _selRect;           // geçici seçim dikdörtgeni (local px)
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _box = Hive.box('sohbet_kutusu');
    final m = (_box.get(widget.photoId) as Map?) ?? {};
    _imgPath = (m['path'] ?? '').toString();
    // Yeni şema: regions; eski projelerde pins varsa onları küçük dikdörtgenlere dönüştürelim
    final pins = (m['pins'] as List?)?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    _regions = (m['regions'] as List?)?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    if (_regions.isEmpty && pins.isNotEmpty) {
      for (final p in pins) {
        final dx = (p['x'] as num).toDouble();
        final dy = (p['y'] as num).toDouble();
        final r = ((p['r'] as num?)?.toDouble() ?? 0.08);
        _regions.add({
          'x': (dx - r).clamp(0.0, 1.0),
          'y': (dy - r).clamp(0.0, 1.0),
          'w': (r * 2).clamp(0.02, 1.0),
          'h': (r * 2).clamp(0.02, 1.0),
          'audio': p['audio'],
          'ts': p['ts'] ?? DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    _initAudio();
  }

  @override
  void dispose() {
    _player.closePlayer();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initAudio() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mikrofon izni gerekli')));
      }
      return;
    }
    await _recorder.openRecorder();
    await _player.openPlayer();
    if (mounted) setState(() => _recReady = true);
  }

  Future<String> _newAudioPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sohbet');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${widget.photoId}_$ts.aac';
  }

  // --- Dikdörtgen/normalize yardımcıları ---
  Offset _normPoint(Offset local, Size draw) {
    return Offset(
      (local.dx / (draw.width == 0 ? 1 : draw.width)).clamp(0.0, 1.0),
      (local.dy / (draw.height == 0 ? 1 : draw.height)).clamp(0.0, 1.0),
    );
  }

  Rect _normRectFromLocal(Offset a, Offset b, Size draw) {
    final p1 = _normPoint(a, draw);
    final p2 = _normPoint(b, draw);
    final left = min(p1.dx, p2.dx);
    final top = min(p1.dy, p2.dy);
    final right = max(p1.dx, p2.dx);
    final bottom = max(p1.dy, p2.dy);
    return Rect.fromLTWH(left, top, max(0.02, right - left), max(0.02, bottom - top));
  }

  Rect _denormRect(Map<String, dynamic> r, Size draw) {
    return Rect.fromLTWH(
      (r['x'] as num).toDouble() * draw.width,
      (r['y'] as num).toDouble() * draw.height,
      (r['w'] as num).toDouble() * draw.width,
      (r['h'] as num).toDouble() * draw.height,
    );
  }

  int _hitTestRegion(Offset local, Size draw) {
    for (int i = _regions.length - 1; i >= 0; i--) {
      if (_denormRect(_regions[i], draw).contains(local)) return i;
    }
    return -1;
  }

  Future<void> _startRecordForRect(Rect localRect, Size drawSize) async {
    if (!_recReady || _isRecording) return;
    final nr = _normRectFromLocal(localRect.topLeft, localRect.bottomRight, drawSize);
    final path = await _newAudioPath();
    await _recorder.startRecorder(toFile: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _regions.add({'x': nr.left, 'y': nr.top, 'w': nr.width, 'h': nr.height, 'audio': null, 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  Future<void> _stopRecord() async {
    if (!_isRecording) return;
    final filePath = await _recorder.stopRecorder();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      for (int i = _regions.length - 1; i >= 0; i--) {
        if (_regions[i]['audio'] == null) {
          _regions[i]['audio'] = filePath;
          break;
        }
      }
      // seçim görsellerini gizle
      _isSelecting = false;
      _selStart = null;
      _selRect = null;
    });
  }

  Future<void> _play(String path) async {
    if (path.isEmpty) return;
    await _player.stopPlayer();
    await _player.startPlayer(fromURI: path);
  }

  Future<void> _deleteRegion(int index) async {
    final a = (_regions[index]['audio'] ?? '').toString();
    if (a.isNotEmpty && File(a).existsSync()) {
      try { File(a).deleteSync(); } catch (_) {}
    }
    setState(() { _regions.removeAt(index); });
  }

  Future<void> _reRecordRegion(int index) async {
    final a = (_regions[index]['audio'] ?? '').toString();
    if (a.isNotEmpty && File(a).existsSync()) {
      try { File(a).deleteSync(); } catch (_) {}
    }
    setState(() { _regions[index]['audio'] = null; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bölgeyi tekrar çiz ve kayıt için basılı tut, sonra bırak.')),
    );
  }

  Future<void> _saveAll() async {
    await _box.put(widget.photoId, {
      'path': _imgPath,
      'regions': _regions,
      'createdAt': (_box.get(widget.photoId)?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  @override
  Widget build(BuildContext context) {
    final imgFile = File(_imgPath);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Düzenle'),
        actions: [
          IconButton(
            tooltip: _editMode ? 'Düzenleme modunu kapat' : 'Düzenleme modunu aç',
            icon: Icon(_editMode ? Icons.visibility_off : Icons.edit_square),
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            tooltip: _selectMode ? 'Seçim modunu kapat' : 'Kayıt bölgesi seç',
            icon: Icon(_selectMode ? Icons.mic_off : Icons.mic),
            onPressed: () {
              setState(() {
                _selectMode = !_selectMode;
              });
              if (_selectMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kaydedilecek alanı seçmek için sürükleyin.')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Kaydet',
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveAll,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final drawSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              // Görsel işaret yok; her zaman tıklanan bölge varsa çal
              final idx = _hitTestRegion(d.localPosition, drawSize);
              if (idx >= 0) {
                final a = (_regions[idx]['audio'] ?? '').toString();
                if (a.isNotEmpty) _play(a);
              }
            },
            onPanStart: (_editMode && _selectMode) ? (d) {
              setState(() {
                _isSelecting = true;
                _selStart = d.localPosition;
                _selRect = Rect.fromLTWH(d.localPosition.dx, d.localPosition.dy, 0, 0);
              });
            } : null,
            onPanUpdate: (_editMode && _selectMode) ? (d) {
              if (_isSelecting && _selStart != null) {
                setState(() {
                  final a = _selStart!;
                  final b = d.localPosition;
                  final left = min(a.dx, b.dx);
                  final top = min(a.dy, b.dy);
                  final right = max(a.dx, b.dx);
                  final bottom = max(a.dy, b.dy);
                  _selRect = Rect.fromLTWH(left, top, right - left, bottom - top);
                });
              }
            } : null,
            onPanEnd: (_editMode && _selectMode) ? (_) async {
              if (_isSelecting && _selRect != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Kayıt başlatılsın mı?'),
                    content: const Text('Seçtiğin alan için ses kaydı başlatılsın mı?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _startRecordForRect(_selRect!, drawSize);
                } else {
                  setState(() {
                    _isSelecting = false;
                    _selStart = null;
                    _selRect = null;
                  });
                }
              }
            } : null,
            onLongPressEnd: (_) async {
              // Uzun basmayı salınca kaydı bitir
              if (_isRecording) await _stopRecord();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 8.0,
                    boundaryMargin: const EdgeInsets.all(1000),
                    clipBehavior: Clip.none,
                    constrained: false,
                    child: imgFile.existsSync()
                        ? SizedBox.expand(child: Image.file(imgFile, fit: BoxFit.contain))
                        : SizedBox(width: 800, height: 800, child: Container(color: Colors.black12)),
                  ),
                ),

                // Seçili bölgeleri çizen overlay (SADECE edit modunda görünür)
                if (_editMode)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (_, s) {
                        final ds = Size(s.maxWidth, s.maxHeight);
                        return Stack(children: [
                          // Mevcut bölgeler (yarı saydam dikdörtgenler)
                          for (int i = 0; i < _regions.length; i++)
                            _RegionOverlay(
                              rect: _denormRect(_regions[i], ds),
                              recordingNow: _isRecording && _regions[i]['audio'] == null,
                              onTap: () {
                                final a = (_regions[i]['audio'] ?? '').toString();
                                if (a.isNotEmpty) _play(a);
                              },
                              onLongPress: () async {
                                final act = await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (_) => SafeArea(
                                    child: Wrap(children: [
                                      ListTile(
                                        leading: const Icon(Icons.mic),
                                        title: const Text('Bu bölgeye yeniden kayıt'),
                                        onTap: () => Navigator.pop(context, 're'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                                        title: const Text('Bölgeyi sil'),
                                        onTap: () => Navigator.pop(context, 'del'),
                                      ),
                                      const SizedBox(height: 8),
                                    ]),
                                  ),
                                );
                                if (act == 'del') _deleteRegion(i);
                                if (act == 're') _reRecordRegion(i);
                              },
                            ),

                          // Kırp-animasyonu benzeri canlı seçim dikdörtgeni
                          if (_isSelecting && _selRect != null)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CropOverlayPainter(_selRect!),
                                size: Size.infinite,
                              ),
                            ),
                        ]);
                      },
                    ),
                  ),

                // Kayıt bildirimi (edit modunda görünür)
                if (_isRecording)
                  Positioned(
                    left: 12, top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(children: [
                        Icon(Icons.fiber_manual_record, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Kayıt alınıyor… basılı tutmayı bırakınca biter', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _isRecording
          ? FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.stop),
        label: const Text('Kaydı Durdur'),
        onPressed: _stopRecord,
      )
          : null,
    );
  }
}

/// Edit modunda çizilen şeffaf dikdörtgen
class _RegionOverlay extends StatelessWidget {
  final Rect rect;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool recordingNow;
  const _RegionOverlay({required this.rect, required this.onTap, required this.onLongPress, this.recordingNow = false});

  @override
  Widget build(BuildContext context) {
    final color = recordingNow ? Colors.orange : Colors.blueAccent;
    return Positioned(
      left: rect.left,
      top: rect.top,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: rect.width,
          height: rect.height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Canlı seçim için crop animasyonu benzeri boya
class _CropOverlayPainter extends CustomPainter {
  final Rect rect;
  const _CropOverlayPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.35);
    // Karanlık maske
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Seçim alanını temizle
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(rect, clear);
    canvas.restore();

    // Kenarlık
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);

    // Köşe işaretleri
    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    const h = 14.0;
    // sol-üst
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(h, 0), handle);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, h), handle);
    // sağ-üst
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(h, 0), handle);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, h), handle);
    // sol-alt
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(h, 0), handle);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, h), handle);
    // sağ-alt
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(h, 0), handle);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, h), handle);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) => oldDelegate.rect != rect;
}