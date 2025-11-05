import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'app_state/current_student.dart';

/// Bir programın günlük veri giriş sayfası:
/// - Üstte: tekrar & genelleme switch’leri (programda tanımlanan sayıya göre)
/// - Altta: tarih bazlı çizgi grafiği (tekrar ve genelleme ayrı çizgiler)
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
  late DateTime _selectedDate;
  late List<bool> _tekrarFlags;
  late List<bool> _genellemeFlags;

  Box? _veriBox; // öğrenciye özel açacağız
  final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tekrarFlags = List<bool>.filled(max(0, widget.tekrarSayisi), false);
    _genellemeFlags = List<bool>.filled(max(0, widget.genellemeSayisi), false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareBoxesAndLoadForDate();
      setState(() {});
    });
  }

  Future<void> _prepareBoxesAndLoadForDate() async {
    final currentId = context.read<CurrentStudent>().currentId;
    final boxName = currentId != null ? 'veri_kutusu_$currentId' : 'veri_kutusu';
    _veriBox ??= await Hive.openBox(boxName);
    await _loadToday();
  }

  String _dateKey(DateTime d) => _df.format(DateTime(d.year, d.month, d.day));

  Future<void> _loadToday() async {
    if (_veriBox == null) return;
    final dk = _dateKey(_selectedDate);

    // Bu program + bu gün için en son kaydı çek
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
      // son kaydı al
      final last = entries.last;
      final t = (last['tekrarFlags'] as List?)?.map((e) => e == true).toList() ?? [];
      final g = (last['genellemeFlags'] as List?)?.map((e) => e == true).toList() ?? [];
      _tekrarFlags = List<bool>.from(
        List<bool>.filled(widget.tekrarSayisi, false),
      );
      _genellemeFlags = List<bool>.from(
        List<bool>.filled(widget.genellemeSayisi, false),
      );
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
    final first = DateTime(now.year - 1, now.month, now.day);
    final last = DateTime(now.year + 1, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: first,
      lastDate: last,
      helpText: 'Tarih seç',
      locale: const Locale('tr'),
    );
    if (d != null) {
      setState(() {
        _selectedDate = d;
      });
      await _loadToday();
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_veriBox == null) return;
    final now = DateTime.now();
    final dk = _dateKey(_selectedDate);

    final kayit = {
      'programKey': widget.programKey,
      'programAdi': widget.programAdi,
      'tarih': DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
          .millisecondsSinceEpoch,
      'tarihStr': dk,
      'tekrarFlags': _tekrarFlags,
      'genellemeFlags': _genellemeFlags,
      'tekrarSayisi': widget.tekrarSayisi,
      'genellemeSayisi': widget.genellemeSayisi,
      'savedAt': now.millisecondsSinceEpoch,
    };

    await _veriBox!.add(kayit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kayıt alındı')),
    );
    setState(() {}); // grafiği güncelle
  }

  /// Grafikte göstermek için: aynı programa ait tüm günlerin tamamlanan tekrar & genelleme sayıları
  List<Map<String, dynamic>> _timelineData() {
    if (_veriBox == null) return [];

    // tarihStr -> (tekrarCount, genellemeCount)
    final Map<String, Map<String, int>> daily = {};

    for (final k in _veriBox!.keys) {
      final v = _veriBox!.get(k);
      if (v is! Map) continue;
      if ((v['programKey']?.toString() ?? '') != widget.programKey) continue;
      final ts = (v['tarihStr']?.toString() ?? '');
      final tCount = ((v['tekrarFlags'] as List?) ?? []).where((e) => e == true).length;
      final gCount = ((v['genellemeFlags'] as List?) ?? []).where((e) => e == true).length;

      daily.putIfAbsent(ts, () => {'t': 0, 'g': 0});
      daily[ts]!['t'] = max(daily[ts]!['t']!, tCount); // aynı gün birden çok kayıt varsa en yükseği al
      daily[ts]!['g'] = max(daily[ts]!['g']!, gCount);
    }

    final entries = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
        .map((e) => {
      'date': e.key,
      't': e.value['t']!,
      'g': e.value['g']!,
      'x': DateTime.parse(e.key).millisecondsSinceEpoch.toDouble(),
    })
        .toList();
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
                label: Text(_dateKey(_selectedDate)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tekrar
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

        // Genelleme
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

  Widget _buildChart() {
    final data = _timelineData();
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('Grafikte gösterecek veri yok'),
        ),
      );
    }

    // X ekseni: günler (double timestamp), Y: tekrar & genelleme sayıları
    final spotsT = data
        .map((e) => FlSpot(e['x'] as double, (e['t'] as int).toDouble()))
        .toList();
    final spotsG = data
        .map((e) => FlSpot(e['x'] as double, (e['g'] as int).toDouble()))
        .toList();

    final maxY = max(
      (spotsT.map((e) => e.y).fold<double>(0, max)).toInt(),
      (spotsG.map((e) => e.y).fold<double>(0, max)).toInt(),
    ).toDouble();

    String _fmtDate(double x) {
      final d = DateTime.fromMillisecondsSinceEpoch(x.toInt());
      return DateFormat('MM/dd').format(d);
    }

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 1 ? 1 : maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spotsT,
              isCurved: true,
              barWidth: 3,
              color: Colors.blue,
              dotData: const FlDotData(show: true),
            ),
            LineChartBarData(
              spots: spotsG,
              isCurved: true,
              barWidth: 3,
              color: Colors.green,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_fmtDate(value), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(color: Colors.black12),
              bottom: BorderSide(color: Colors.black12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Öğrenci ID değişirse kutu adı değişebilir; fakat bu sayfaya zaten mevcut öğrenci ile geliyoruz.
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
            _buildChart(),
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