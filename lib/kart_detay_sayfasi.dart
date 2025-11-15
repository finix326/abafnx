// lib/kart_detay_sayfasi.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ai/finix_ai_button.dart';
import 'services/finix_data_service.dart';

class KartDetaySayfasi extends StatefulWidget {
  final String diziId;
  final String diziAdi;

  const KartDetaySayfasi({
    super.key,
    required this.diziId,
    required this.diziAdi,
  });

  @override
  State<KartDetaySayfasi> createState() => _KartDetaySayfasiState();
}

class _KartDetaySayfasiState extends State<KartDetaySayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;
  String? _ownerId;
  DateTime? _recordCreatedAt;

  // Grid boyut kontrolü (kalıcı)
  // maxExtent küçükse daha çok sütun sığar, büyütürsen kareler büyür.
  double _maxExtent = 180; // varsayılan; slider ile değişir

  // Ses
  final FlutterSoundRecorder _rec = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String? _recordingCardId; // şu an hangi kartta kayıt var

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('kart_dizileri');
    _boxFuture.then((box) {
      if (!mounted) return;
      _loadGridPrefs(box);
    });
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _player.openPlayer();
    await _rec.openRecorder();
  }

  @override
  void dispose() {
    _player.closePlayer();
    _rec.closeRecorder();
    super.dispose();
  }

  void _loadGridPrefs(Box<Map<dynamic, dynamic>> box) {
    final record = _readRecord(box);
    if (record == null) return;
    final pref = (record.payload['grid_max_extent'] as num?)?.toDouble();
    if (pref != null && pref > 80 && pref < 420) {
      setState(() {
        _maxExtent = pref;
      });
    }
  }

  FinixRecord? _readRecord(Box<Map<dynamic, dynamic>> box) {
    final raw = box.get(widget.diziId);
    if (raw is! Map) return null;
    final record = FinixDataService.decode(
      raw,
      module: 'kart_dizileri',
    );
    if (!FinixDataService.isRecord(raw)) {
      unawaited(box.put(widget.diziId, record.toMap()));
    }
    final normalizedOwner = record.studentId.trim();
    if (normalizedOwner.isNotEmpty && normalizedOwner != 'unknown') {
      _ownerId ??= normalizedOwner;
    }
    _recordCreatedAt ??= record.createdAt;
    return record;
  }

  Future<void> _saveGridPrefs() async {
    final box = await _boxFuture;
    final record = _readRecord(box);
    if (record == null) return;
    final updatedPayload = Map<String, dynamic>.from(record.payload)
      ..['grid_max_extent'] = _maxExtent;
    final updated = record.copyWith(
      studentId: _ownerId,
      data: updatedPayload,
      createdAt: _recordCreatedAt ?? record.createdAt,
      updatedAt: DateTime.now(),
    );
    await box.put(widget.diziId, updated.toMap());
    unawaited(FinixDataService.saveRecord(updated));
  }

  Future<void> _yeniKartEkle() async {
    final box = await _boxFuture;
    final record = _readRecord(box);
    if (record == null) return;
    final dizi = Map<String, dynamic>.from(record.payload);
    final List kartlar = List<Map<String, dynamic>>.from(
      (dizi['kartlar'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
    );
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    kartlar.add({'id': id, 'foto': null, 'ses': null, 'metin': ''});
    dizi['kartlar'] = kartlar;
    final updated = record.copyWith(
      studentId: _ownerId,
      data: dizi,
      createdAt: _recordCreatedAt ?? record.createdAt,
      updatedAt: DateTime.now(),
    );
    await box.put(widget.diziId, updated.toMap());
    setState(() {});
    unawaited(FinixDataService.saveRecord(updated));
  }

  Future<void> _fotoEkle(Map<String, dynamic> kart) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    kart['foto'] = picked.path;
    await _guncelleKart(kart);
  }

  Future<void> _fotoSil(Map<String, dynamic> kart) async {
    kart['foto'] = null;
    await _guncelleKart(kart);
  }

  Future<void> _sesSil(Map<String, dynamic> kart) async {
    kart['ses'] = null;
    // ses silinince mikrofon yeniden görünsün
    if (_recordingCardId == kart['id']) _recordingCardId = null;
    await _guncelleKart(kart);
  }

  Future<void> _guncelleKart(Map<String, dynamic> kart) async {
    final box = await _boxFuture;
    final record = _readRecord(box);
    if (record == null) return;
    final dizi = Map<String, dynamic>.from(record.payload);
    final List kartlar = List<Map<String, dynamic>>.from(
      (dizi['kartlar'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
    );
    final index = kartlar.indexWhere((k) => k['id'] == kart['id']);
    if (index != -1) kartlar[index] = kart;
    dizi['kartlar'] = kartlar;
    final updated = record.copyWith(
      studentId: _ownerId,
      data: dizi,
      createdAt: _recordCreatedAt ?? record.createdAt,
      updatedAt: DateTime.now(),
    );
    await box.put(widget.diziId, updated.toMap());
    setState(() {});
    unawaited(FinixDataService.saveRecord(updated));
  }

  Future<bool> _ensureMic() async {
    var st = await Permission.microphone.status;
    if (st.isDenied || st.isRestricted || st.isPermanentlyDenied) {
      st = await Permission.microphone.request();
    }
    return st.isGranted;
  }

  Future<void> _startRec(Map<String, dynamic> kart) async {
    if (!await _ensureMic()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni gerekiyor.')),
      );
      return;
    }
    // Aynı anda tek kayıt
    if (_rec.isRecording) {
      await _stopRec(kart); // güvenlik
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${kart['id']}.aac';
    _recordingCardId = kart['id'] as String;
    await _rec.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {});
  }

  Future<void> _stopRec(Map<String, dynamic> kart) async {
    final filePath = await _rec.stopRecorder();
    _recordingCardId = null;
    if (filePath != null) {
      kart['ses'] = filePath;
      await _guncelleKart(kart);
    } else {
      setState(() {});
    }
  }

  Future<void> _playOrStop(Map<String, dynamic> kart) async {
    final uri = kart['ses']?.toString();
    if (uri == null) return;
    if (_player.isPlaying) {
      await _player.stopPlayer();
      return;
    }
    await _player.startPlayer(fromURI: uri);
  }

  void _kartMenusu(BuildContext context, Map<String, dynamic> kart) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Fotoğraf Ekle'),
              onTap: () async {
                Navigator.pop(context);
                await _fotoEkle(kart);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_size_select_large_outlined),
              title: const Text('Fotoğrafı Sil'),
              onTap: () async {
                Navigator.pop(context);
                await _fotoSil(kart);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('Sesi Sil'),
              onTap: () async {
                Navigator.pop(context);
                await _sesSil(kart);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResizeSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (c, setLocal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kart Boyutu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Küçük'),
                      Expanded(
                        child: Slider(
                          value: _maxExtent,
                          min: 120, // daha çok sütun
                          max: 320, // daha büyük kare
                          divisions: 20,
                          label: _maxExtent.toStringAsFixed(0),
                          onChanged: (v) {
                            setLocal(() {});
                            setState(() => _maxExtent = v);
                          },
                        ),
                      ),
                      const Text('Büyük'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Kaydet'),
                        onPressed: () async {
                          await _saveGridPrefs();
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Boyut kaydedildi')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _saveAll() async {
    // Anlık tüm state zaten Hive’a yazılıyor.
    // Yine de “Kaydet” tuşu için kullanıcıya onay/snackbar veriyoruz.
    await _saveGridPrefs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaydedildi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box<Map<dynamic, dynamic>>>(
      future: _boxFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.diziAdi)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.diziAdi)),
            body: const Center(child: Text('Kart dizisi bulunamadı.')),
          );
        }

        final box = snapshot.data!;
        return ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
          valueListenable: box.listenable(keys: [widget.diziId]),
          builder: (context, _, __) {
            final raw = box.get(widget.diziId);
            if (raw is! Map) {
              return Scaffold(
                appBar: AppBar(title: Text(widget.diziAdi)),
                body: const Center(child: Text('Kart dizisi bulunamadı.')),
              );
            }

            final record = FinixDataService.decode(
              raw,
              module: 'kart_dizileri',
            );
            if (!FinixDataService.isRecord(raw)) {
              unawaited(box.put(widget.diziId, record.toMap()));
            }
            _ownerId ??= record.studentId;
            _recordCreatedAt ??= record.createdAt;

            final dizi = Map<String, dynamic>.from(record.payload);
            final List<Map<String, dynamic>> kartlar =
                List<Map<String, dynamic>>.from(
              (dizi['kartlar'] as List? ?? const [])
                  .map((e) =>
                      Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(widget.diziAdi),
                actions: [
                  IconButton(
                    tooltip: 'Boyut',
                    icon: const Icon(Icons.aspect_ratio_outlined),
                    onPressed: _showResizeSheet,
                  ),
                  IconButton(
                    tooltip: 'Kaydet',
                    icon: const Icon(Icons.save_outlined),
                    onPressed: _saveAll,
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: _yeniKartEkle,
                child: const Icon(Icons.add),
              ),
              body: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _maxExtent, // slider ile kontrol
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95, // kare + metin
                ),
                itemCount: kartlar.length,
                itemBuilder: (_, i) {
                  final Map<String, dynamic> kart =
                      Map<String, dynamic>.from(kartlar[i]);
          final String id = kart['id'] as String;
          final bool fotoVar = (kart['foto'] != null && (kart['foto'] as String).isNotEmpty);
          final bool sesVar = (kart['ses'] != null && (kart['ses'] as String).isNotEmpty);
          final bool recording = (_recordingCardId == id);
          final textController =
              TextEditingController(text: (kart['metin'] ?? '').toString());

                  return GestureDetector(
                    onTap: sesVar ? () => _playOrStop(kart) : null,
                    onLongPress: () => _kartMenusu(context, kart),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
                      ),
                      child: Column(
                        children: [
                  // KARE BÖLGE
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: fotoVar
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(kart['foto']),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover, // taşma yok, kareyi doldur
                            ),
                          )
                              : const Center(
                            child: Icon(Icons.add_photo_alternate_outlined, size: 38),
                          ),
                        ),

                        // SES KAYIT BUTONU (başlangıçta mikrofon; kayıt sırasında kare/stop)
                        if (!sesVar || recording)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: GestureDetector(
                              onTap: () async {
                                if (recording) {
                                  await _stopRec(kart);
                                } else {
                                  await _startRec(kart);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: recording ? Colors.red : Colors.white70,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  recording ? Icons.stop_rounded : Icons.mic,
                                  size: 22,
                                  color: recording ? Colors.white : Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // METİN KUTUSU (kalıcı)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Metin ekle...',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            ),
                            onChanged: (v) {
                              kart['metin'] = v;
                              _guncelleKart(kart);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FinixAIButton.small(
                          contextDescription:
                              'Bu kart için açıklama ve kullanım yönergesi öner',
                          initialText: textController.text,
                          onResult: (aiText) {
                            textController.text = aiText;
                            kart['metin'] = aiText;
                            _guncelleKart(kart);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
          },
        );
      },
    );
  }
}