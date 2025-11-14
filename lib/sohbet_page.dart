// lib/sohbet_page.dart

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Ana Sayfa: Sohbet listesini gösterir.
class SohbetHomePage extends StatefulWidget {
  const SohbetHomePage({super.key});

  @override
  State<SohbetHomePage> createState() => _SohbetHomePageState();
}

class _SohbetHomePageState extends State<SohbetHomePage> {
  late final Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('sohbet_kutusu');
  }

  Future<void> _addSohbet() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _box.put(newId, {
      'title': 'Yeni Sohbet',
      'photos': <String>[],
      'createdAt': now,
    });
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SohbetPage(sohbetId: newId),
      ),
    );
  }

  Future<void> _renameSohbet(String sohbetId) async {
    final data = (_box.get(sohbetId) as Map?) ?? {};
    final currentTitle = (data['title'] ?? 'İsimsiz Sohbet').toString();
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
    data['title'] = newTitle.isEmpty ? currentTitle : newTitle;
    await _box.put(sohbetId, data);
  }

  Future<void> _deleteSohbet(String sohbetId) async {
    final data = (_box.get(sohbetId) as Map?) ?? {};
    final photos = (data['photos'] as List?)?.cast<String>() ?? <String>[];

    // Önce fotoğraf kayıtlarını ve dosyalarını sil
    for (final pid in photos) {
      final p = (_box.get(pid) as Map?) ?? {};
      final imgPath = (p['path'] ?? '').toString();
      if (imgPath.isNotEmpty && File(imgPath).existsSync()) {
        try {
          File(imgPath).deleteSync();
        } catch (_) {}
      }
      final regions = (p['regions'] as List?)?.cast<Map>() ?? <Map>[];
      for (final r in regions) {
        final audioPath = (r['audio'] ?? '').toString();
        if (audioPath.isNotEmpty && File(audioPath).existsSync()) {
          try {
            File(audioPath).deleteSync();
          } catch (_) {}
        }
      }
      await _box.delete(pid);
    }

    // Sonra sohbet kaydını sil
    await _box.delete(sohbetId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      body: ValueListenableBuilder<Box>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          // Sadece 'photos' alanı olan kayıtları sohbet olarak kabul et
          final allKeys = box.keys.toList();
          final sohbetKeys = <dynamic>[];
          for (final k in allKeys) {
            final v = box.get(k);
            if (v is Map && v.containsKey('photos')) {
              sohbetKeys.add(k);
            }
          }
          sohbetKeys.sort((a, b) => b.toString().compareTo(a.toString()));
          if (sohbetKeys.isEmpty) {
            return const Center(child: Text('Henüz sohbet yok.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: sohbetKeys.length,
            itemBuilder: (context, index) {
              final key = sohbetKeys[index];
              final data = box.get(key) as Map? ?? {};
              final title = (data['title'] ?? 'İsimsiz Sohbet').toString();
              final photos = (data['photos'] as List?)?.length ?? 0;
              final createdAt = data['createdAt'] as int?;
              String subtitle;
              if (createdAt != null) {
                final dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
                final dateStr =
                    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                subtitle = '$dateStr · $photos fotoğraf';
              } else {
                subtitle = '$photos fotoğraf';
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.chat_bubble_outline),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SohbetPage(sohbetId: key.toString()),
                      ),
                    );
                  },
                  onLongPress: () async {
                    final act = await showModalBottomSheet<String>(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Sohbet adını düzenle'),
                              onTap: () => Navigator.pop(context, 'rename'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete_outline, color: Colors.red),
                              title: const Text('Sohbeti sil'),
                              onTap: () => Navigator.pop(context, 'delete'),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                    if (act == 'rename') {
                      await _renameSohbet(key.toString());
                    } else if (act == 'delete') {
                      await _deleteSohbet(key.toString());
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSohbet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Sohbet Detay Sayfası: Artık doğrudan yeni PageView'i çağırıyor.
class SohbetPage extends StatelessWidget {
  final String sohbetId;
  const SohbetPage({super.key, required this.sohbetId});

  @override
  Widget build(BuildContext context) {
    return _SohbetViewer(sohbetId: sohbetId);
  }
}

// YENİ: Sayfalamayı ve global AppBar'ı yöneten ana widget
class _SohbetViewer extends StatefulWidget {
  final String sohbetId;
  const _SohbetViewer({required this.sohbetId});

  @override
  State<_SohbetViewer> createState() => _SohbetViewerState();
}

class _SohbetViewerState extends State<_SohbetViewer> {
  late final Box _box;
  final PageController _pageController = PageController();
  List<String> _photoIds = [];
  int _currentPageIndex = 0;
  bool _editMode = false;
  bool _selectMode = false;

  // Aktif sayfayı (PhotoViewerPage) dışarıdan kontrol etmek için anahtarlar
  final List<GlobalKey<_PhotoViewerPageState>> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('sohbet_kutusu');
    _loadPhotos();
  }

  void _loadPhotos() {
    final sohbetData = _box.get(widget.sohbetId) as Map? ?? {};
    _photoIds = (sohbetData['photos'] as List?)?.cast<String>() ?? [];
    _pageKeys.clear();
    for (var _ in _photoIds) {
      _pageKeys.add(GlobalKey<_PhotoViewerPageState>());
    }
    setState(() {});
  }

  // Aktif sayfanın state'ini almak için yardımcı fonksiyon
  _PhotoViewerPageState? get _currentPageState {
    if (_currentPageIndex < _pageKeys.length) {
      return _pageKeys[_currentPageIndex].currentState;
    }
    return null;
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/sohbet_fotolar');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final photoId = 'p_${DateTime.now().millisecondsSinceEpoch}';
    final ext = picked.path.split('.').last;
    final targetFile = File('${dir.path}/$photoId.$ext');
    await File(picked.path).copy(targetFile.path);

    // Fotoğraf kaydını kutuya yaz
    await _box.put(photoId, {
      'path': targetFile.path,
      'regions': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Sohbetin photos listesine bu fotoğrafı ekle
    final raw = (_box.get(widget.sohbetId) as Map?) ?? {};
    final photos = (raw['photos'] as List?)?.cast<String>() ?? <String>[];
    photos.add(photoId);
    raw['photos'] = photos;
    await _box.put(widget.sohbetId, raw);

    // Ekranı güncelle ve son sayfaya git
    _loadPhotos();
    if (_photoIds.isNotEmpty) {
      final lastIndex = _photoIds.length - 1;
      _pageController.jumpToPage(lastIndex);
      setState(() {
        _currentPageIndex = lastIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_box.get(widget.sohbetId) as Map? ?? {})['title'] ?? ''),
        actions: [
          IconButton(
            tooltip: 'Fotoğraf ekle',
            icon: const Icon(Icons.add_a_photo),
            onPressed: _addPhoto,
          ),
          IconButton(
            tooltip: _editMode ? 'Bölgeleri Gizle' : 'Bölgeleri Göster',
            icon: Icon(_editMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _editMode = !_editMode);
              _currentPageState?.toggleEditMode();
            },
          ),
          IconButton(
            tooltip: _selectMode ? 'Seçim Modunu Kapat' : 'Kayıt Bölgesi Seç',
            icon: Icon(_selectMode ? Icons.mic_off : Icons.mic),
            onPressed: _editMode // Sadece düzenleme modu aktifken çalışsın
                ? () {
              setState(() => _selectMode = !_selectMode);
              _currentPageState?.toggleSelectMode();
            }
                : null,
          ),
          IconButton(
            tooltip: 'Kaydet',
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _currentPageState?.saveAll(),
          ),
        ],
      ),
      body: _photoIds.isEmpty
          ? const Center(child: Text('Bu sohbette henüz fotoğraf yok.'))
          : Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            // --- DEĞİŞİKLİK: Kaydırmayı devre dışı bırak ---
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photoIds.length,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _PhotoViewerPage(
                key: _pageKeys[index],
                photoId: _photoIds[index],
                initialEditMode: _editMode,
                initialSelectMode: _selectMode,
              );
            },
          ),
          // --- YENİ: Geri butonu ---
          if (_photoIds.length > 1)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white.withOpacity(0.7),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.3)),
                  onPressed: _currentPageIndex > 0
                      ? () {
                    _pageController.animateToPage(
                      _currentPageIndex - 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
          // --- YENİ: İleri butonu ---
          if (_photoIds.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.white.withOpacity(0.7),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.3)),
                  onPressed: _currentPageIndex < _photoIds.length - 1
                      ? () {
                    _pageController.animateToPage(
                      _currentPageIndex + 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// GÜNCELLENDİ: Eskiden _PhotoEditor'dı, şimdi PageView içinde çalışan bir "sayfa".
class _PhotoViewerPage extends StatefulWidget {
  final String photoId;
  final bool initialEditMode;
  final bool initialSelectMode;

  const _PhotoViewerPage({
    super.key,
    required this.photoId,
    this.initialEditMode = false,
    this.initialSelectMode = false,
  });

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late Box _box;
  late String _imgPath;
  List<Map<String, dynamic>> _regions = [];

  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();

  bool _recReady = false;
  bool _isRecording = false;

  bool _editMode = false;
  bool _selectMode = false;

  bool _isSelecting = false;
  Offset? _selStart;
  Rect? _selRect;

  // --- DIŞARIDAN KONTROL İÇİN METODLAR ---
  void toggleEditMode() => setState(() => _editMode = !_editMode);
  void toggleSelectMode() {
    setState(() => _selectMode = !_selectMode);
    if (_selectMode && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kaydedilecek alanı seçmek için sürükleyin.'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> saveAll() async {
    await _box.put(widget.photoId, {
      'path': _imgPath,
      'regions': _regions,
      'createdAt':
      (_box.get(widget.photoId)?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    }
  }
  // --- KONTROL METODLARI SONU ---

  @override
  void initState() {
    super.initState();
    _editMode = widget.initialEditMode;
    _selectMode = widget.initialSelectMode;

    _box = Hive.box('sohbet_kutusu');
    final m = (_box.get(widget.photoId) as Map?) ?? {};
    _imgPath = (m['path'] ?? '').toString();

    // Geriye uyumluluk: eski 'pins' verisini yeni 'regions' formatına çevir
    final pins = (m['pins'] as List?)?.cast<Map>().map<Map<String, dynamic>>((e) => Map.from(e)).toList() ?? [];
    _regions = (m['regions'] as List?)?.cast<Map>().map<Map<String, dynamic>>((e) => Map.from(e)).toList() ?? [];
    if (_regions.isEmpty && pins.isNotEmpty) {
      _regions = pins.map((p) {
        final dx = (p['x'] as num).toDouble();
        final dy = (p['y'] as num).toDouble();
        final r = ((p['r'] as num?)?.toDouble() ?? 0.08);
        return {
          'x': (dx - r).clamp(0.0, 1.0), 'y': (dy - r).clamp(0.0, 1.0),
          'w': (r * 2).clamp(0.02, 1.0), 'h': (r * 2).clamp(0.02, 1.0),
          'audio': p['audio'], 'ts': p['ts'] ?? DateTime.now().millisecondsSinceEpoch,
        };
      }).toList();
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
    if (!await Permission.microphone.request().isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mikrofon izni gerekli')));
      }
      return;
    }
    await _recorder.openRecorder();
    await _player.openPlayer();
    if (mounted) setState(() => _recReady = true);
  }

  Future<String> _newAudioPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/sohbet_audio';
    if (!Directory(path).existsSync()) {
      Directory(path).createSync(recursive: true);
    }
    return '$path/${widget.photoId}_${DateTime.now().millisecondsSinceEpoch}.aac';
  }

  Rect _normRectFromLocal(Offset a, Offset b, Size draw) {
    Offset norm(Offset o) => Offset((o.dx / draw.width).clamp(0.0, 1.0),
        (o.dy / draw.height).clamp(0.0, 1.0));
    final p1 = norm(a);
    final p2 = norm(b);
    return Rect.fromPoints(p1, p2);
  }

  Rect _denormRect(Map<String, dynamic> r, Size draw) {
    return Rect.fromLTWH(
      (r['x'] as num).toDouble() * draw.width, (r['y'] as num).toDouble() * draw.height,
      (r['w'] as num).toDouble() * draw.width, (r['h'] as num).toDouble() * draw.height,
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
    if (mounted) setState(() => _isRecording = true);
    _regions.add({
      'x': nr.left, 'y': nr.top, 'w': nr.width, 'h': nr.height, 'audio': null,
      'ts': DateTime.now().millisecondsSinceEpoch
    });
  }

  Future<void> _stopRecord() async {
    if (!_isRecording) return;
    final filePath = await _recorder.stopRecorder();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isSelecting = false;
      _selStart = null;
      _selRect = null;
      // Son eklenen null audio'lu bölgeyi bul ve güncelle
      final index = _regions.lastIndexWhere((r) => r['audio'] == null);
      if (index != -1) _regions[index]['audio'] = filePath;
    });
  }

  Future<void> _play(String? path) async {
    if (path == null || path.isEmpty) return;
    await _player.stopPlayer();
    await _player.startPlayer(fromURI: path);
  }

  Future<void> _deleteRegion(int index) async {
    final audioPath = _regions[index]['audio'] as String?;
    if (audioPath != null && await File(audioPath).exists()) {
      try {
        await File(audioPath).delete();
      } catch (_) {}
    }
    setState(() => _regions.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final imgFile = File(_imgPath);
    return LayoutBuilder(
      builder: (context, constraints) {
        final drawSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (_editMode) return; // Düzenleme modunda ana tıklama çalışmaz
            final idx = _hitTestRegion(d.localPosition, drawSize);
            if (idx >= 0) _play(_regions[idx]['audio'] as String?);
          },
          onPanStart: (_editMode && _selectMode)
              ? (d) {
            setState(() {
              _isSelecting = true;
              _selStart = d.localPosition;
            });
          }
              : null,
          onPanUpdate: (_editMode && _selectMode)
              ? (d) {
            if (_isSelecting && _selStart != null) {
              setState(
                      () => _selRect = Rect.fromPoints(_selStart!, d.localPosition));
            }
          }
              : null,
          onPanEnd: (_editMode && _selectMode)
              ? (_) async {
            if (_isSelecting && _selRect != null) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Kayıt Başlatılsın mı?'),
                  content: const Text(
                      'Seçtiğiniz alan için ses kaydı başlatılsın mı?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Evet')),
                  ],
                ),
              );
              if (confirm == true) {
                await _startRecordForRect(_selRect!, drawSize);
              } else {
                setState(() {
                  _isSelecting = false;
                  _selRect = null;
                });
              }
            }
          }
              : null,
          onLongPressEnd: null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Tam ekran fotoğraf
              if (imgFile.existsSync())
                Image.file(
                  imgFile,
                  fit: BoxFit.contain,
                )
              else
                Container(
                  color: Colors.black12,
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),

              // Ses bölgeleri overlay'i (sadece edit modunda görünür)
              if (_editMode)
                Stack(
                  children: [
                    for (int i = 0; i < _regions.length; i++)
                      _RegionOverlay(
                        rect: _denormRect(_regions[i], drawSize),
                        recordingNow:
                        _isRecording && _regions[i]['audio'] == null,
                        onTap: () => _play(_regions[i]['audio'] as String?),
                        onLongPress: () async {
                          final act = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => SafeArea(
                                child: Wrap(children: [
                                  ListTile(
                                      leading: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      title: const Text('Bölgeyi Sil'),
                                      onTap: () => Navigator.pop(context, 'del')),
                                ])),
                          );
                          if (act == 'del') _deleteRegion(i);
                        },
                      ),
                  ],
                ),

              // Canlı seçim çerçevesi
              if (_isSelecting && _selRect != null)
                IgnorePointer(
                    child: CustomPaint(
                        painter: _CropOverlayPainter(_selRect!),
                        size: Size.infinite)),

              // Kayıt bildirimi
              if (_isRecording)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(100)),
                    child: const Row(children: [
                      Icon(Icons.fiber_manual_record,
                          size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Kayıt alınıyor...',
                          style: TextStyle(color: Colors.white)),
                    ]),
                  ),
                ),
              // Kaydı durdur butonu (sadece kayıt sırasında görünür)
              if (_isRecording)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _stopRecord,
                      icon: const Icon(Icons.stop),
                      label: const Text('Kaydı durdur'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Görsel Bölge Widget'ı
class _RegionOverlay extends StatelessWidget {
  final Rect rect;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool recordingNow;
  const _RegionOverlay(
      {required this.rect,
        required this.onTap,
        required this.onLongPress,
        this.recordingNow = false});

  @override
  Widget build(BuildContext context) {
    final color = recordingNow ? Colors.orange : Colors.blueAccent;
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// Canlı Seçim Çerçevesi Çizici
class _CropOverlayPainter extends CustomPainter {
  final Rect rect;
  _CropOverlayPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
