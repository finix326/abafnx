import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'ai/finix_ai_button.dart';
import 'app_state/current_student.dart';
import 'services/finix_data_service.dart';

class CizelgeDetayResimliSesliSayfasi extends StatefulWidget {
  final String cizelgeAdi;

  const CizelgeDetayResimliSesliSayfasi({
    super.key,
    required this.cizelgeAdi,
  });

  @override
  State<CizelgeDetayResimliSesliSayfasi> createState() =>
      _CizelgeDetayResimliSesliSayfasiState();
}

class _CizelgeDetayResimliSesliSayfasiState
    extends State<CizelgeDetayResimliSesliSayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;
  Box<Map<dynamic, dynamic>>? _box;

  // Her kart: {'resimPath': String?, 'sesPath': String?, 'metin': String}
  final List<Map<String, dynamic>> _icerik = [];

  final PageController _page = PageController();
  late final FlutterSoundRecorder _recorder;
  late final FlutterSoundPlayer _player;

  bool _isRecording = false;
  int? _recordingIndex;
  int? _playingIndex;

  Directory? _cizelgeDir;
  late final Future<void> _initialLoad;
  String? _ownerId;
  int? _recordCreatedAt;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('cizelge_kutusu');
    _initialLoad = _init();
  }

  Future<void> _init() async {
    _box = await _boxFuture;
    await _player.openPlayer();
    await _recorder.openRecorder();

    _cizelgeDir = await _ensureCizelgeDir();
    Map<String, dynamic> existing = const <String, dynamic>{};
    final raw = _box!.get(widget.cizelgeAdi);
    if (raw is Map) {
      final record = FinixDataService.decode(
        raw,
        module: 'cizelge',
      );
      if (!FinixDataService.isRecord(raw)) {
        await _box!.put(widget.cizelgeAdi, record.toMap());
      }
      existing = Map<String, dynamic>.from(record.payload);
      _recordCreatedAt = record.createdAt;
      _ownerId = record.studentId;
    }
    final list = (existing['icerik'] as List?) ?? const [];
    final fallback =
        mounted ? context.read<CurrentStudent>().currentId?.trim() : null;
    if (_ownerId == null || _ownerId!.isEmpty) {
      _ownerId = (fallback != null && fallback.isNotEmpty) ? fallback : null;
    }

    _icerik.clear();
    if (list.isEmpty) {
      _icerik.add({'resimPath': null, 'sesPath': null, 'metin': ''});
    } else {
      for (final e in list) {
        final m = Map<String, dynamic>.from(
          (e as Map?)?.cast<dynamic, dynamic>() ?? const <String, dynamic>{},
        );
        final rp = (m['resimPath'] as String?)?.trim();
        if (rp != null && rp.isNotEmpty && !File(rp).existsSync()) {
          m['resimPath'] = null;
        }
        final sp = (m['sesPath'] as String?)?.trim();
        if (sp != null && sp.isNotEmpty && !File(sp).existsSync()) {
          m['sesPath'] = null;
        }
        _icerik.add({
          'resimPath': m['resimPath'],
          'sesPath': m['sesPath'],
          'metin': (m['metin'] ?? '').toString(),
        });
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _player.closePlayer();
    _recorder.closeRecorder();
    _page.dispose();
    super.dispose();
  }

  // ---------- yardımcılar ----------
  Future<Directory> _ensureCizelgeDir() async {
    final base = await getApplicationDocumentsDirectory();
    final safeName = widget.cizelgeAdi.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dir = Directory('${base.path}/cizelgeler/$safeName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String _extOf(String path) {
    final i = path.lastIndexOf('.');
    return i >= 0 ? path.substring(i) : '';
  }

  Future<void> _saveSilent() async {
    final box = _box ?? await _boxFuture;
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = box.get(widget.cizelgeAdi);
    FinixRecord? record;
    if (raw is Map) {
      record = FinixDataService.decode(
        raw,
        module: 'cizelge',
      );
      if (!FinixDataService.isRecord(raw)) {
        await box.put(widget.cizelgeAdi, record.toMap());
      }
    }

    final payload = record != null
        ? Map<String, dynamic>.from(record.payload)
        : <String, dynamic>{};
    payload
      ..['tur'] = 'resimli_sesli'
      ..['icerik'] = _icerik
          .map((e) => {
                'resimPath': e['resimPath'],
                'sesPath': e['sesPath'],
                'metin': (e['metin'] ?? '').toString(),
              })
          .toList()
      ..['updatedAt'] = now
      ..putIfAbsent('createdAt', () => _recordCreatedAt ?? now);

    final fallback =
        mounted ? context.read<CurrentStudent>().currentId?.trim() : null;
    final owner = _ownerId?.trim() ?? fallback;
    _ownerId = owner?.isNotEmpty == true ? owner : null;

    final updatedRecord = FinixDataService.buildRecord(
      module: 'cizelge',
      payload: payload,
      studentId: _ownerId,
      createdAt: _recordCreatedAt ?? record?.createdAt ?? now,
      updatedAt: now,
    );
    _recordCreatedAt = updatedRecord.createdAt;

    await box.put(widget.cizelgeAdi, updatedRecord.toMap());
  }

  void _addCard() {
    setState(() {
      _icerik.add({'resimPath': null, 'sesPath': null, 'metin': ''});
    });
    _saveSilent();
  }

  void _removeCard(int index) {
    setState(() {
      _icerik.removeAt(index);
    });
    _saveSilent();
  }

  // ---------- resim ----------
  Future<void> _pickImageAndSave(int index, {required bool fromCamera}) async {
    try {
      if (fromCamera) {
        final cam = await Permission.camera.request();
        if (!cam.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera izni gerekli')),
          );
          return;
        }
      }
      final picked = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      if (picked == null) return;

      final dir = _cizelgeDir ?? await _ensureCizelgeDir();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}${_extOf(picked.path)}';
      final dest = File('${dir.path}/$fileName');
      await File(picked.path).copy(dest.path);

      setState(() {
        _icerik[index]['resimPath'] = dest.path;
      });
      await _saveSilent();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resim eklendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim eklenemedi: $e')),
      );
    }
  }

  Future<void> _removeImage(int index) async {
    final p = _icerik[index]['resimPath'] as String?;
    if (p != null && p.isNotEmpty) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    setState(() => _icerik[index]['resimPath'] = null);
    _saveSilent();
  }

  // ---------- ses ----------
  Future<void> _toggleRecord(int index) async {
    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _icerik[_recordingIndex ?? index]['sesPath'] = path;
        });
        _saveSilent();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıt kaydedildi')),
        );
      }
      return;
    }

    // start
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni gerekli')),
      );
      return;
    }

    final dir = _cizelgeDir ?? await _ensureCizelgeDir();
    final path = '${dir.path}/aud_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {
      _isRecording = true;
      _recordingIndex = index;
    });
  }

  Future<void> _removeAudio(int index) async {
    final p = _icerik[index]['sesPath'] as String?;
    if (p != null && p.isNotEmpty) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    setState(() => _icerik[index]['sesPath'] = null);
    _saveSilent();
  }

  Future<void> _togglePlay(int index) async {
    final p = _icerik[index]['sesPath'] as String?;
    if (p == null || p.isEmpty) return;

    if (_playingIndex == index && _player.isPlaying) {
      await _player.stopPlayer();
      setState(() => _playingIndex = null);
      return;
    }

    await _player.stopPlayer();
    await _player.startPlayer(fromURI: p, whenFinished: () {
      if (mounted) setState(() => _playingIndex = null);
    });
    setState(() => _playingIndex = index);
  }

  // ---------- menü ----------
  void _showCardMenu(int index) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final hasImg = (_icerik[index]['resimPath'] as String?)?.isNotEmpty == true;
        final hasAud = (_icerik[index]['sesPath'] as String?)?.isNotEmpty == true;

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(hasImg ? 'Resmi Değiştir (Galeri)' : 'Resim Ekle (Galeri)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSave(index, fromCamera: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(hasImg ? 'Resmi Değiştir (Kamera)' : 'Resim Ekle (Kamera)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSave(index, fromCamera: true);
                },
              ),
              if (hasImg)
                ListTile(
                  leading: const Icon(Icons.image_not_supported),
                  title: const Text('Resmi Kaldır'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage(index);
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mic),
                title: Text(hasAud ? 'Sesi Yeniden Kaydet' : 'Ses Kaydet'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleRecord(index);
                },
              ),
              if (hasAud)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Sesi Kaldır'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAudio(index);
                  },
                ),
              const Divider(height: 1),
              if (hasImg)
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('Tam Ekran Gör'),
                  onTap: () {
                    Navigator.pop(context);
                    final p = _icerik[index]['resimPath'] as String;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _FullscreenImage(path: p)),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Kartı Sil'),
                onTap: () {
                  Navigator.pop(context);
                  _removeCard(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(int index) {
    final m = _icerik[index];
    final resim = m['resimPath'] as String?;
    final ses = m['sesPath'] as String?;
    final isPlaying = _playingIndex == index && _player.isPlaying;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => _togglePlay(index), // tek tık = ses çal/dur
        onLongPress: () => _showCardMenu(index), // uzun bas = menü
        child: Column(
          children: [
            // Resim alanı
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: resim != null && resim.isNotEmpty && File(resim).existsSync()
                          ? Image.file(File(resim), fit: BoxFit.cover)
                          : const Center(child: Text('Resim yok • Uzun bas → menü')),
                    ),
                  ),
                  // Sağ-alt: mikrofon / stop
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: FloatingActionButton.small(
                      heroTag: 'mic_$index',
                      onPressed: () => _toggleRecord(index),
                      child: Icon(_isRecording && _recordingIndex == index ? Icons.stop : Icons.mic),
                    ),
                  ),
                  // Sol-alt: oynatma göstergesi
                  if (ses != null && ses.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: Colors.white),
                            const SizedBox(width: 6),
                            const Text('Ses', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Metin
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: (m['metin'] ?? '').toString(),
                    ),
                    onChanged: (v) {
                      _icerik[index]['metin'] = v;
                      _saveSilent();
                    },
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Bu sayfa için not/başlık…',
                      border: OutlineInputBorder(borderSide: BorderSide(width: 2)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 2)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FinixAIButton.small(
                  contextDescription:
                      'Günlük çizelge adımlarını, çocuk için anlaşılır şekilde öner',
                  initialText: (m['metin'] ?? '').toString(),
                  onResult: (aiText) {
                    setState(() {
                      _icerik[index]['metin'] = aiText;
                      // TODO: Çok adımlı yanıtları kartlara paylaştır.
                    });
                    _saveSilent();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Çizelge: ${widget.cizelgeAdi}')),
            body: Center(
              child: Text('Çizelge yüklenemedi: ${snapshot.error}'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Çizelge: ${widget.cizelgeAdi}'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: FinixAIButton.iconOnly(
                  contextDescription:
                      'Günlük çizelge adımlarını, çocuk için anlaşılır şekilde öner',
                  initialText: _icerik.isEmpty
                      ? ''
                      : (_icerik[_currentIndex]['metin'] ?? '').toString(),
                  onResult: (aiText) {
                    setState(() {
                      if (_icerik.isEmpty) {
                        _icerik.add({'resimPath': null, 'sesPath': null, 'metin': aiText});
                      } else {
                        _icerik[_currentIndex]['metin'] = aiText;
                      }
                    });
                    _saveSilent();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Kart Ekle',
                icon: const Icon(Icons.add),
                onPressed: _addCard,
              ),
            ],
          ),
          body: PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: _icerik.length,
            itemBuilder: (_, i) => _buildCard(i),
          ),
        );
      },
    );
  }
}

// Tam ekran resim
class _FullscreenImage extends StatelessWidget {
  final String path;
  const _FullscreenImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
      AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}