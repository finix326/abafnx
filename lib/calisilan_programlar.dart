import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'app_state/current_student.dart';

/// Geri uyumluluk için: Projede bazı yerler CalisilanProgramlarSayfasi adını kullanıyor.
/// Bu wrapper, asıl liste sayfasını döndürür.
class CalisilanProgramlarSayfasi extends StatelessWidget {
  final String? initialProgramKey;
  const CalisilanProgramlarSayfasi({super.key, this.initialProgramKey});

  @override
  Widget build(BuildContext context) => _ProgramListeSayfasi(
    initialProgramKey: initialProgramKey,
  );
}

/// PROGRAM LİSTESİ — tıklayınca detay sayfasına gider
class _ProgramListeSayfasi extends StatefulWidget {
  final String? initialProgramKey;
  const _ProgramListeSayfasi({this.initialProgramKey});

  @override
  State<_ProgramListeSayfasi> createState() => _ProgramListeSayfasiState();
}

class _ProgramListeSayfasiState extends State<_ProgramListeSayfasi> {
  String? _autoSelectKey;
  bool _didAutoSelect = false;

  Map<String, dynamic> _normalizeProgram(dynamic v) {
    if (v is Map) {
      return {
        'programAdi': v['programAdi'] ?? v['ad'] ?? v['name'] ?? '',
        'tekrarSayisi': ((v['tekrarSayisi'] ?? 0) as num).toInt(),
        'genellemeSayisi': ((v['genellemeSayisi'] ?? 0) as num).toInt(),
        'createdAt': (v['createdAt'] ?? 0) as int,
      };
    }
    return {
      'programAdi': v?.toString() ?? '',
      'tekrarSayisi': 0,
      'genellemeSayisi': 0,
      'createdAt': 0,
    };
  }

  Future<Box> _openProgramBox(String studentId) async {
    try {
      final studentBox = await Hive.openBox('program_bilgileri_$studentId');
      try {
        final defaultBox = await Hive.openBox('program_bilgileri');
        if (studentBox.isEmpty && defaultBox.isNotEmpty) return defaultBox;
      } catch (_) {}
      return studentBox;
    } catch (_) {
      return Hive.openBox('program_bilgileri');
    }
  }

  void _maybeAutoNavigate(
      BuildContext context,
      List<MapEntry<dynamic, Map<String, dynamic>>> entries,
      ) {
    if (_didAutoSelect) return;
    if (entries.isEmpty) return;

    // initialProgramKey öncelikli
    if (widget.initialProgramKey != null) {
      final found = entries.where((e) => e.key.toString() == widget.initialProgramKey).toList();
      if (found.isNotEmpty) _autoSelectKey = found.first.key.toString();
    }
    // tek kayıt varsa onu seç
    _autoSelectKey ??= entries.length == 1 ? entries.first.key.toString() : null;
    // yoksa en son oluşturulanı seç
    _autoSelectKey ??= (entries
      ..sort((a, b) =>
          (a.value['createdAt'] as int).compareTo((b.value['createdAt'] as int))))
        .last
        .key
        .toString();

    _didAutoSelect = true;
    if (_autoSelectKey != null) {
      final sel = entries.firstWhere((e) => e.key.toString() == _autoSelectKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramVeriDetaySayfasi(
              programKey: sel.key.toString(),
              programAdi: (sel.value['programAdi'] ?? sel.key).toString(),
              tekrarSayisi: sel.value['tekrarSayisi'] as int,
              genellemeSayisi: sel.value['genellemeSayisi'] as int,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    if (currentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Veri Girişi')),
        body: const Center(child: Text('Lütfen bir öğrenci seçin')),
      );
    }

    return FutureBuilder<Box>(
      future: _openProgramBox(currentId),
      builder: (context, progSnap) {
        if (progSnap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!progSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Veri Girişi')),
            body: const Center(child: Text('Program kutusu açılamadı')),
          );
        }
        final progBox = progSnap.data!;
        final entries = <MapEntry<dynamic, Map<String, dynamic>>>[];

        for (final k in progBox.keys) {
          final v = progBox.get(k);
          if (v == null) continue;
          entries.add(MapEntry(k, _normalizeProgram(v)));
        }
        entries.sort((a, b) => (a.value['programAdi'] ?? '')
            .toString()
            .compareTo((b.value['programAdi'] ?? '').toString()));

        // Otomatik yönlendirme (isteğe bağlı)
        _maybeAutoNavigate(context, entries);

        return Scaffold(
          appBar: AppBar(title: const Text('Programlar')),
          body: entries.isEmpty
              ? const Center(child: Text('Henüz program yok.'))
              : ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = entries[i];
              final ad = (e.value['programAdi'] ?? e.key).toString();
              final t = (e.value['tekrarSayisi'] as int?) ?? 0;
              final g = (e.value['genellemeSayisi'] as int?) ?? 0;
              return ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(ad),
                subtitle: Text('Tekrar: $t • Genelleme: $g'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProgramVeriDetaySayfasi(
                        programKey: e.key.toString(),
                        programAdi: ad,
                        tekrarSayisi: t,
                        genellemeSayisi: g,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// PROGRAM VERİ DETAY — Üstte switch’ler, altta iki çizgili grafik
class ProgramVeriDetaySayfasi extends StatefulWidget {
  final String programKey;
  final String programAdi;
  final int tekrarSayisi;
  final int genellemeSayisi;

  const ProgramVeriDetaySayfasi({
    super.key,
    required this.programKey,
    required this.programAdi,
    required this.tekrarSayisi,
    required this.genellemeSayisi,
  });

  @override
  State<ProgramVeriDetaySayfasi> createState() => _ProgramVeriDetaySayfasiState();
}

class _ProgramVeriDetaySayfasiState extends State<ProgramVeriDetaySayfasi> {
  DateTime _selectedDate = DateTime.now();
  late List<bool> _tekrarFlags;
  late List<bool> _genellemeFlags;

  Box? _veriBox;

  @override
  void initState() {
    super.initState();
    _tekrarFlags = List<bool>.filled(max(0, widget.tekrarSayisi), false);
    _genellemeFlags = List<bool>.filled(max(0, widget.genellemeSayisi), false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareBoxAndLoadForDate();
      if (mounted) setState(() {});
    });
  }

  Future<void> _prepareBoxAndLoadForDate() async {
    final currentId = context.read<CurrentStudent>().currentId;
    final boxName = currentId != null ? 'veri_kutusu_$currentId' : 'veri_kutusu';
    _veriBox ??= await Hive.openBox(boxName);
    await _loadToday();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadToday() async {
    if (_veriBox == null) return;
    final dk = _fmt(_selectedDate);

    // Bu program + bu gün için son kaydı bul
    final entries = <Map>[];
    for (final k in _veriBox!.keys) {
      final v = _veriBox!.get(k);
      if (v is Map &&
          (v['programKey']?.toString() ?? '') == widget.programKey &&
          (v['tarihStr']?.toString() ?? '') == dk) {
        entries.add(v);
      }
    }
    if (entries.isNotEmpty) {
      final last = entries.last;
      final t = (last['tekrarFlags'] as List?)?.map((e) => e == true).toList() ?? [];
      final g = (last['genellemeFlags'] as List?)?.map((e) => e == true).toList() ?? [];
      _tekrarFlags = List<bool>.filled(widget.tekrarSayisi, false);
      _genellemeFlags = List<bool>.filled(widget.genellemeSayisi, false);
      for (int i = 0; i < _tekrarFlags.length && i < t.length; i++) {
        _tekrarFlags[i] = t[i];
      }
      for (int i = 0; i < _genellemeFlags.length && i < g.length; i++) {
        _genellemeFlags[i] = g[i];
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadToday();
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveToday() async {
    if (_veriBox == null) return;

    final now = DateTime.now();
    final rec = {
      'programKey': widget.programKey,
      'programAdi': widget.programAdi,
      'tarih': DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      ).millisecondsSinceEpoch,
      'tarihStr': _fmt(_selectedDate),
      'tekrarFlags': _tekrarFlags,
      'genellemeFlags': _genellemeFlags,
      // uyumluluk için sayısal özet:
      'tekrarSayisi': _tekrarFlags.where((e) => e).length,
      'genellemeSayisi': _genellemeFlags.where((e) => e).length,
    };
    await _veriBox!.add(rec);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    setState(() {});
  }

  /// Grafikte göstermek için günlük en yüksek değerleri toplar
  _SeriesData _seriesFromBox() {
    if (_veriBox == null) return const _SeriesData.empty();

    final Map<String, int> sumT = {};
    final Map<String, int> sumG = {};

    for (final k in _veriBox!.keys) {
      final v = _veriBox!.get(k);
      if (v is! Map) continue;
      if ((v['programKey']?.toString() ?? '') != widget.programKey) continue;

      final ds = (v['tarihStr'] ?? '').toString();
      if (ds.isEmpty) continue;

      final t = (v['tekrarFlags'] as List?)?.where((e) => e == true).length ??
          ((v['tekrarSayisi'] as num?)?.toInt() ?? 0);
      final g = (v['genellemeFlags'] as List?)?.where((e) => e == true).length ??
          ((v['genellemeSayisi'] as num?)?.toInt() ?? 0);

      // Aynı gün birden fazla kayıt varsa en yükseğini al
      sumT.update(ds, (old) => max(old, t), ifAbsent: () => t);
      sumG.update(ds, (old) => max(old, g), ifAbsent: () => g);
    }

    final dates = {...sumT.keys, ...sumG.keys}.toList()..sort((a, b) => a.compareTo(b));
    return _SeriesData(dates: dates, tekrarByDate: sumT, genellemeByDate: sumG);
  }

  Widget _buildSwitches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarih & Kaydet
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.date_range),
                label: Text(_fmt(_selectedDate)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saveToday,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_tekrarFlags.isNotEmpty) ...[
          Text('Tekrar (${_tekrarFlags.where((e) => e).length}/${_tekrarFlags.length})',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _tekrarFlags.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}'),
                    Switch(
                      value: _tekrarFlags[i],
                      onChanged: (v) => setState(() => _tekrarFlags[i] = v),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (_genellemeFlags.isNotEmpty) ...[
          Text('Genelleme (${_genellemeFlags.where((e) => e).length}/${_genellemeFlags.length})',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _genellemeFlags.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}'),
                    Switch(
                      value: _genellemeFlags[i],
                      onChanged: (v) => setState(() => _genellemeFlags[i] = v),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    if (currentId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.programAdi)),
        body: const Center(child: Text('Lütfen bir öğrenci seçin')),
      );
    }

    // (Kutu zaten initState'de açılıyor; burada sadece UI)
    final series = _seriesFromBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.programAdi.isEmpty ? 'Veri Girişi' : widget.programAdi),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSwitches(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('Çizgi Grafik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _LineChartCard(series: series),
            const SizedBox(height: 8),
            Row(
              children: const [
                _Legend(color: Colors.blue, text: 'Tekrar'),
                SizedBox(width: 16),
                _Legend(color: Colors.green, text: 'Genelleme'),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// --- küçük yardımcılar ---

class _SeriesData {
  final List<String> dates; // yyyy-mm-dd
  final Map<String, int> tekrarByDate;
  final Map<String, int> genellemeByDate;

  const _SeriesData({
    required this.dates,
    required this.tekrarByDate,
    required this.genellemeByDate,
  });

  const _SeriesData.empty()
      : dates = const [],
        tekrarByDate = const {},
        genellemeByDate = const {};
}

/// Çizgi grafik kartı – fl_chart ile iki seri (Tekrar & Genelleme)
class _LineChartCard extends StatelessWidget {
  final _SeriesData series;
  const _LineChartCard({required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.dates.isEmpty) {
      return _emptyChartCard(context);
    }

    final spotsTekrar = <FlSpot>[];
    final spotsGen = <FlSpot>[];
    for (int i = 0; i < series.dates.length; i++) {
      final d = series.dates[i];
      final t = (series.tekrarByDate[d] ?? 0).toDouble();
      final g = (series.genellemeByDate[d] ?? 0).toDouble();
      spotsTekrar.add(FlSpot(i.toDouble(), t));
      spotsGen.add(FlSpot(i.toDouble(), g));
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LegendRow(),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= series.dates.length) return const SizedBox.shrink();
                          final d = series.dates[i];
                          final mm = d.substring(5, 7);
                          final dd = d.substring(8, 10);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('$mm/$dd', style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsTekrar,
                      isCurved: true,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      color: Colors.blue, // Tekrar
                    ),
                    LineChartBarData(
                      spots: spotsGen,
                      isCurved: true,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      color: Colors.green, // Genelleme
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChartCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: const SizedBox(
        height: 220,
        child: Center(
          child: Text('Grafik için henüz veri yok'),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    return Row(
      children: [
        dot(Colors.blue),
        const SizedBox(width: 6),
        const Text('Tekrar'),
        const SizedBox(width: 16),
        dot(Colors.green),
        const SizedBox(width: 6),
        const Text('Genelleme'),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}