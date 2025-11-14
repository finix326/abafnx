import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state/current_student.dart';

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

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox<Map<dynamic, dynamic>>('cizelge_kutusu');
  }

  Future<void> _yukle(Box<Map<dynamic, dynamic>> box) async {
    if (!mounted) return;
    final raw = box.get(widget.cizelgeAdi);
    final map = (raw is Map)
        ? Map<String, dynamic>.from(raw as Map<dynamic, dynamic>)
        : <String, dynamic>{};
    final list = List<String>.from(
      ((map['icerik'] as List?) ?? const [])
          .map((e) => e == null ? '' : e.toString()),
    );
    if (list.isEmpty) list.add('');

    final ownerFromBox = (map['studentId'] as String?)?.trim();
    final fallback = context.read<CurrentStudent>().currentId?.trim();
    final owner =
        (ownerFromBox != null && ownerFromBox.isNotEmpty) ? ownerFromBox : fallback;

    if (!mounted) return;
    setState(() {
      _icerik
        ..clear()
        ..addAll(list);
      _renkler
        ..clear()
        ..addAll(List<Color>.generate(_icerik.length, (_) => Colors.white));
      _ownerId = owner;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final eski = Map<String, dynamic>.from(
      (box.get(widget.cizelgeAdi) as Map?)?.cast<dynamic, dynamic>() ??
          const <String, dynamic>{},
    );
    final data = <String, dynamic>{
      ...eski,
      'tur': 'yazili',
      'icerik': List<String>.from(_icerik),
      'updatedAt': now,
    };
    data['createdAt'] = (data['createdAt'] as int?) ?? now;

    final fallbackOwner =
        mounted ? context.read<CurrentStudent>().currentId?.trim() : null;
    final owner = _ownerId?.trim() ?? fallbackOwner;
    if (owner != null && owner.isNotEmpty) {
      data['studentId'] = owner;
      _ownerId = owner;
    } else {
      data.remove('studentId');
      _ownerId = null;
    }

    await box.put(widget.cizelgeAdi, data);
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
                      TextField(
                        controller: controller,
                        onChanged: (v) => _icerik[i] = v,
                        decoration: const InputDecoration(border: InputBorder.none),
                        maxLines: null,
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