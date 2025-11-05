import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'app_state/current_student.dart';

/// Bu sayfa, aktif öğrencinin 'program_bilgileri_<studentId>' kutusundan
/// Eşleştirme Oyunu kayıtlarını çekip ZAMAN SERİSİ olarak:
/// 1) Başarı %
/// 2) Süre (sn)
/// grafikleriyle gösterir.
///
/// Not: Kayıt yapısı, eslestirme_oyunu_sayfasi.dart'ta add edilen Map yapısıdır:
/// {
///   'programAdi': 'Eşleştirme Oyunu',
///   'tarih': <int msSinceEpoch>,
///   'tarihStr': 'YYYY-MM-DD HH:mm:ss',
///   'dogruSayisi': <int>,
///   'toplamCift': <int>,
///   'basariYuzdesi': <double>,
///   'sureSaniye': <int>,
///   'tekrar': 3,
///   'genelleme': 3,
/// }
class ProgramDetaySayfasi extends StatelessWidget {
  const ProgramDetaySayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    if (currentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Program Detay')),
        body: const Center(child: Text('Lütfen bir öğrenci seçin')),
      );
    }

    final boxName = 'program_bilgileri_$currentId';
    return FutureBuilder<Box>(
      future: Hive.openBox(boxName),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Program Detay')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Program Detay')),
            body: const Center(child: Text('Veri bulunamadı')),
          );
        }

        final box = snap.data!;
        // Tüm kayıtları al, Map tipine cast et, tarihine göre sırala
        final raw = box.values
            .where((e) => e is Map)
            .cast<Map>()
            .where((m) => (m['programAdi'] ?? '') == 'Eşleştirme Oyunu')
            .toList()
          ..sort((a, b) => ((a['tarih'] ?? 0) as int).compareTo((b['tarih'] ?? 0) as int));

        final pointsYuzde = <FlSpot>[];
        final pointsSure = <FlSpot>[];
        final labels = <String>[];

        for (int i = 0; i < raw.length; i++) {
          final m = raw[i];
          final yuzde = _toDouble(m['basariYuzdesi']);
          final sure = _toDouble(m['sureSaniye']);
          final ts = (m['tarih'] ?? 0) as int;
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          final label = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';

          pointsYuzde.add(FlSpot(i.toDouble(), yuzde));
          pointsSure.add(FlSpot(i.toDouble(), sure));
          labels.add(label);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Program Detay')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: raw.isEmpty
                ? const Center(child: Text('Henüz kayıt yok'))
                : ListView(
              children: [
                _StatOzet(raw: raw),
                const SizedBox(height: 16),
                Text('Başarı Yüzdesi (%)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: LineChart(
                    _lineData(pointsYuzde, labels, yMin: 0, yMax: 100),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Süre (saniye)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: LineChart(
                    _lineData(pointsSure, labels, yMin: 0, yMax: _autoMax(pointsSure)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Kayıtlar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...raw.reversed.map((m) => _KayitTile(m)).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double _autoMax(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 10) return 10;
    if (maxY <= 30) return 30;
    if (maxY <= 60) return 60;
    if (maxY <= 120) return 120;
    return maxY + 10;
  }

  static LineChartData _lineData(List<FlSpot> spots, List<String> labels,
      {required double yMin, required double yMax}) {
    return LineChartData(
      minX: 0,
      maxX: spots.isEmpty ? 0 : (spots.length - 1).toDouble(),
      minY: yMin,
      maxY: yMax,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ],
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 36),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(labels[i], style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
    );
  }
}

class _StatOzet extends StatelessWidget {
  const _StatOzet({required this.raw});
  final List<Map> raw;

  @override
  Widget build(BuildContext context) {
    if (raw.isEmpty) return const SizedBox.shrink();

    final yuzdeler = raw.map((m) => (m['basariYuzdesi'] ?? 0).toDouble()).toList();
    final sureler = raw.map((m) => (m['sureSaniye'] ?? 0) as int).toList();

    final avgYuzde = yuzdeler.isEmpty ? 0 : (yuzdeler.reduce((a, b) => a + b) / yuzdeler.length);
    final avgSure = sureler.isEmpty ? 0 : (sureler.reduce((a, b) => a + b) / sureler.length);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _chip('Kayıt', raw.length.toString()),
        _chip('Ort. %', avgYuzde.toStringAsFixed(0)),
        _chip('Ort. Süre', '${avgSure.toStringAsFixed(0)} sn'),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _KayitTile extends StatelessWidget {
  const _KayitTile(this.m, {super.key});
  final Map m;

  @override
  Widget build(BuildContext context) {
    final tarihStr = (m['tarihStr'] ?? '') as String;
    final dogru = (m['dogruSayisi'] ?? 0).toString();
    final toplam = (m['toplamCift'] ?? 0).toString();
    final yuzde = ((m['basariYuzdesi'] ?? 0.0) as num).toDouble().toStringAsFixed(0);
    final sure = (m['sureSaniye'] ?? 0).toString();

    return Card(
      child: ListTile(
        title: Text('$tarihStr  •  %$yuzde'),
        subtitle: Text('Doğru: $dogru / $toplam  •  Süre: ${sure}s'),
      ),
    );
  }
}