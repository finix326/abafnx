import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgramDetaySayfasi extends StatefulWidget {
  final String programAdi;

  const ProgramDetaySayfasi({super.key, required this.programAdi});

  @override
  State<ProgramDetaySayfasi> createState() => _ProgramDetaySayfasiState();
}

class _ProgramDetaySayfasiState extends State<ProgramDetaySayfasi> {
  final Box box = Hive.box('veri_kutusu');
  final Box programBox = Hive.box('program_bilgileri');

  Map<String, Map<String, int>> veriler = {};
  DateTime secilenTarih = DateTime.now();
  List<bool> tekrarDurum = [];
  List<bool> genellemeDurum = [];
  int toplamTekrar = 0;
  int toplamGenelleme = 0;
  int sabitTekrarSayisi = 5;
  int sabitGenellemeSayisi = 5;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  void _verileriYukle() {
    final data = box.toMap().entries
        .where((e) => e.key.toString().startsWith('${widget.programAdi}-'))
        .map((e) {
      final tarih = e.key.toString().split('-').skip(1).join('-');
      final veri = Map<String, int>.from(e.value);
      return MapEntry(tarih, veri);
    });

    final programData = programBox.get(widget.programAdi);
    if (programData != null) {
      sabitTekrarSayisi = programData['tekrarSayisi'] ?? 5;
      sabitGenellemeSayisi = programData['genellemeSayisi'] ?? 5;
    }

    setState(() {
      veriler = Map.fromEntries(data);
      _guncelleYuvarlaklar();
    });
  }

  void _guncelleYuvarlaklar() {
    final key = '${widget.programAdi}-${_tarihStr(secilenTarih)}';
    final veri = box.get(key);
    if (veri != null) {
      final tekrar = veri['tekrar'] ?? 0;
      final genelleme = veri['genelleme'] ?? 0;
      tekrarDurum = List.generate(sabitTekrarSayisi, (i) => i < tekrar);
      genellemeDurum = List.generate(sabitGenellemeSayisi, (i) => i < genelleme);
    } else {
      tekrarDurum = List.generate(sabitTekrarSayisi, (_) => false);
      genellemeDurum = List.generate(sabitGenellemeSayisi, (_) => false);
    }
  }

  void _veriKaydet() {
    final seciliGun = _tarihStr(secilenTarih);
    final key = '${widget.programAdi}-$seciliGun';
    final tekrar = tekrarDurum.where((e) => e).length;
    final genelleme = genellemeDurum.where((e) => e).length;

    box.put(key, {'tekrar': tekrar, 'genelleme': genelleme});
    _verileriYukle();
  }

  String _tarihStr(DateTime dt) => dt.toIso8601String().split('T').first;

  Widget _buildTarihSecici() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Tarih: ${_tarihStr(secilenTarih)}"),
        TextButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: const Text("Tarih Seç"),
          onPressed: () async {
            final secilen = await showDatePicker(
              context: context,
              initialDate: secilenTarih,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (secilen != null) {
              setState(() {
                secilenTarih = secilen;
                _guncelleYuvarlaklar();
              });
            }
          },
        )
      ],
    );
  }

  Widget _buildYuvarlaklarKutulu() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildYuvarlaklar("Tekrar", tekrarDurum)),
          const SizedBox(width: 16),
          Expanded(child: _buildYuvarlaklar("Genelleme", genellemeDurum)),
        ],
      ),
    );
  }

  Widget _buildYuvarlaklar(String baslik, List<bool> durumList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(durumList.length, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  durumList[index] = !durumList[index];
                });
              },
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                durumList[index] ? Colors.green : Colors.grey[400],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildYuzdeOran() {
    toplamTekrar = 0;
    toplamGenelleme = 0;

    for (var v in veriler.values) {
      toplamTekrar += v['tekrar'] ?? 0;
      toplamGenelleme += v['genelleme'] ?? 0;
    }

    final toplam = toplamTekrar + toplamGenelleme;
    if (toplam == 0) return const SizedBox();

    final tekrarYuzde = ((toplamTekrar / toplam) * 100).toStringAsFixed(1);
    final genellemeYuzde = ((toplamGenelleme / toplam) * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text("Tekrar: %$tekrarYuzde | Genelleme: %$genellemeYuzde"),
    );
  }

  Widget _buildGrafik() {
    final List<FlSpot> tekrarSpots = [];
    final List<FlSpot> genellemeSpots = [];
    final Map<int, String> xLabels = {};
    int i = 0;

    final sorted = veriler.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (var entry in sorted) {
      tekrarSpots.add(FlSpot(i.toDouble(), (entry.value['tekrar'] ?? 0).toDouble()));
      genellemeSpots.add(FlSpot(i.toDouble(), (entry.value['genelleme'] ?? 0).toDouble()));
      xLabels[i] = entry.key.substring(5);
      i++;
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final label = xLabels[value.toInt()] ?? '';
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: tekrarSpots,
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: true),
            ),
            LineChartBarData(
              spots: genellemeSpots,
              isCurved: true,
              color: Colors.orange,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.programAdi)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTarihSecici(),
            const SizedBox(height: 10),
            _buildYuvarlaklarKutulu(),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _veriKaydet,
                child: const Text("Veriyi Kaydet"),
              ),
            ),
            _buildYuzdeOran(),
            const Divider(height: 30),
            const Text("Zaman Serisi Grafiği",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(child: _buildGrafik()),
          ],
        ),
      ),
    );
  }
}