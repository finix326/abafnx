import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'ai/finix_ai_button.dart';
import 'app_state/current_student.dart';
import 'services/finix_data_service.dart';

class CizelgeDetaySayfasi extends StatefulWidget {
  final String cizelgeAdi;
  final String tur; // 'yazili'

  const CizelgeDetaySayfasi({
    super.key,
    required this.cizelgeAdi,
    required this.tur,
  });

  @override
  State<CizelgeDetaySayfasi> createState() => _CizelgeDetaySayfasiState();
}

class _CizelgeDetaySayfasiState extends State<CizelgeDetaySayfasi> {
  late final Future<Box<Map<dynamic, dynamic>>> _boxFuture;
  Box<Map<dynamic, dynamic>>? _box;
  final PageController _pageController = PageController();

  final List<String> _icerik = [];
  final List<Color> _renkler = [];
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _ownerId;
  DateTime? _recordCreatedAt;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('cizelge_kutusu');
  }

  Future<void> _yukle(Box<Map<dynamic, dynamic>> box) async {
    if (!mounted) return;
    final raw = box.get(widget.cizelgeAdi);
    Map<String, dynamic> map = <String, dynamic>{};
    FinixRecord? record;
    if (raw is Map) {
      record = FinixDataService.decode(
        raw,
        module: 'cizelge',
      );
      if (!FinixDataService.isRecord(raw)) {
        unawaited(box.put(widget.cizelgeAdi, record.toMap()));
      }
      map = Map<String, dynamic>.from(record.payload);
    }
    final list = List<String>.from(
      ((map['icerik'] as List?) ?? const [])
          .map((e) => e == null ? '' : e.toString()),
    );
    if (list.isEmpty) list.add('');

    final fallback =
        context.read<CurrentStudent>().currentStudentId?.trim();
    final ownerFromBox = record?.studentId.trim();
    final owner = (ownerFromBox != null &&
            ownerFromBox.isNotEmpty &&
            ownerFromBox != 'unknown')
        ? ownerFromBox
        : fallback;

    final createdFromRecord = record?.createdAt;
    final createdFromMap = (map['createdAt'] as int?);
    final resolvedCreatedAt = createdFromRecord ??
        (createdFromMap != null
            ? DateTime.fromMillisecondsSinceEpoch(createdFromMap)
            : DateTime.now());

    if (!mounted) return;
    setState(() {
      _icerik
        ..clear()
        ..addAll(list);
      _renkler
        ..clear()
        ..addAll(List<Color>.generate(_icerik.length, (_) => Colors.white));
      _ownerId = owner;
      _recordCreatedAt = resolvedCreatedAt;
      _isLoaded = true;
      _isLoading = false;
    });
  }

  void _yeniKartEkle() {
    setState(() {
      _icerik.add('');
      _renkler.add(Colors.white);
    });
  }

  Future<void> _kaydet() async {
    final box = _box ?? await _boxFuture;
    final now = DateTime.now();
    final raw = box.get(widget.cizelgeAdi);
    FinixRecord? record;
    if (raw is Map) {
      record = FinixDataService.decode(
        raw,
        module: 'cizelge',
      );
      if (!FinixDataService.isRecord(raw)) {
        unawaited(box.put(widget.cizelgeAdi, record.toMap()));
      }
    }

    final payload = record != null
        ? Map<String, dynamic>.from(record.payload)
        : <String, dynamic>{};
    payload
      ..['tur'] = 'yazili'
      ..['icerik'] = List<String>.from(_icerik)
      ..['updatedAt'] = now.millisecondsSinceEpoch
      ..putIfAbsent('createdAt',
          () => (_recordCreatedAt ?? record?.createdAt ?? now).millisecondsSinceEpoch);

    final fallbackOwner =
        mounted
            ? context.read<CurrentStudent>().currentStudentId?.trim()
            : null;
    final owner = _ownerId?.trim() ?? fallbackOwner;
    _ownerId = owner?.isNotEmpty == true ? owner : null;

    final updatedRecord = FinixDataService.buildRecord(
      id: widget.cizelgeAdi,
      module: 'cizelge',
      data: payload,
      studentId: _ownerId,
      programName: widget.cizelgeAdi,
      createdAt: _recordCreatedAt ?? record?.createdAt ?? now,
      updatedAt: now,
    );
    _recordCreatedAt = updatedRecord.createdAt;

    await box.put(widget.cizelgeAdi, updatedRecord.toMap());
    unawaited(FinixDataService.saveRecord(updatedRecord));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  void _renkSec(int i, Color c) {
    setState(() => _renkler[i] = (_renkler[i] == c) ? Colors.white : c);
  }

  Widget _renkButonlari(int i) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        icon: const Icon(Icons.check, color: Colors.green),
        onPressed: () => _renkSec(i, Colors.green),
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.red),
        onPressed: () => _renkSec(i, Colors.red),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box<Map<dynamic, dynamic>>>(
      future: _boxFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.cizelgeAdi)),
            body: const Center(child: Text('Kutu açılamadı')),
          );
        }
        final box = snap.data!;
        if (!identical(_box, box)) {
          _box = box;
          _isLoaded = false;
        }

        if (!_isLoaded && !_isLoading) {
          _isLoading = true;
          Future.microtask(() => _yukle(box));
        }

        if (!_isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.cizelgeAdi),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: FinixAIButton.iconOnly(
                  contextDescription:
                      'Günlük çizelge adımlarını, çocuk için anlaşılır şekilde öner',
                  initialText: _icerik.join('\n'),
                  onResult: (aiText) {
                    final suggestions = aiText
                        .split(RegExp(r'\r?\n'))
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    setState(() {
                      final steps = suggestions.isEmpty
                          ? <String>[aiText.trim()]
                          : suggestions;
                      _icerik
                        ..clear()
                        ..addAll(steps);
                      _renkler
                        ..clear()
                        ..addAll(List<Color>.filled(_icerik.length, Colors.white));
                    });
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.save), onPressed: _kaydet),
              IconButton(icon: const Icon(Icons.add), onPressed: _yeniKartEkle),
              IconButton(
                icon: const Icon(Icons.view_agenda),
                tooltip: 'Kart modunda göster',
                onPressed: () {
                  // Sade: Liste görünümünden kart görünümüne hızlı geçiş
                  _pageController.jumpToPage(0);
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: _icerik.length,
            itemBuilder: (context, i) {
              final controller = TextEditingController(text: _icerik[i]);
              return Card(
                margin: const EdgeInsets.all(12),
                color: _renkler[i],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              onChanged: (v) => _icerik[i] = v,
                              decoration:
                                  const InputDecoration(border: InputBorder.none),
                              maxLines: null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FinixAIButton.small(
                            contextDescription:
                                'Günlük çizelge adımlarını, çocuk için anlaşılır şekilde öner',
                            initialText: controller.text,
                            onResult: (aiText) {
                              controller.text = aiText;
                              setState(() {
                                _icerik[i] = aiText;
                                // TODO: Çok adımlı yanıtları ayrı kartlara dağıt.
                              });
                            },
                          ),
                        ],
                      ),
                      _renkButonlari(i),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}