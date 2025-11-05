import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BepRaporGoruntulemeSayfasi extends StatelessWidget {
  final Map<String, dynamic> raporVerileri;
  const BepRaporGoruntulemeSayfasi({super.key, required this.raporVerileri});

  String _fmt(int? ms) {
    if (ms == null) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final m = raporVerileri;
    final ogr = (m['ogrenci'] as Map?) ?? {};
    final gelisim = (m['gelisim'] as Map?) ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(m['ad'] ?? 'BEP Raporu'),
        actions: [
          IconButton(
            tooltip: 'PDF olarak kaydet / paylaş',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final doc = pw.Document();

              pw.Widget _row(String k, String v) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 140, child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text(v)),
                  ],
                ),
              );

              doc.addPage(
                pw.MultiPage(
                  build: (ctx) => [
                    pw.Text(m['ad'] ?? 'BEP Raporu',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Durum: ${(m['durum'] ?? 'taslak').toString().toUpperCase()}'),
                    pw.Text('Başlangıç: ${_fmt(m['baslangic'])}   •   Bitiş: ${_fmt(m['bitis'])}'),
                    pw.SizedBox(height: 12),

                    pw.Text('Öğrenci Bilgileri', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    _row('Ad', (ogr['ad'] ?? '').toString()),
                    _row('Sınıf', (ogr['sinif'] ?? '').toString()),
                    _row('Veli', (ogr['veli'] ?? '').toString()),
                    _row('Problem Davranış', (ogr['problemDavranis'] ?? '').toString()),
                    pw.SizedBox(height: 10),

                    pw.Text('Rapor Özeti', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    _row('Hedef(ler)', (m['hedef'] ?? '').toString()),
                    _row('Kısa Vadeli Amaçlar', (m['amaclar'] ?? '').toString()),
                    _row('Ölçüt', (m['olcut'] ?? '').toString()),
                    _row('Sorumlu Terapist', (m['sorumlu'] ?? '').toString()),
                    if ((m['not'] ?? '').toString().isNotEmpty) _row('Not', (m['not'] ?? '').toString()),
                    pw.SizedBox(height: 10),

                    pw.Text('Gelişim Alanları', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    _row('Dil Gelişimi', (gelisim['dil'] ?? '').toString()),
                    _row('Motor Beceriler', (gelisim['motor'] ?? '').toString()),
                    _row('Sosyal Etkileşim', (gelisim['sosyal'] ?? '').toString()),
                    _row('Bilişsel Gelişim', (gelisim['bilissel'] ?? '').toString()),
                    _row('Öz Bakım Becerileri', (gelisim['ozBakim'] ?? '').toString()),
                    _row('Duyusal Profil', (gelisim['duyusal'] ?? '').toString()),
                  ],
                ),
              );

              await Printing.layoutPdf(onLayout: (format) async => doc.save());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Durum / Tarih', [
            _row('Durum', (m['durum'] ?? 'taslak').toString().toUpperCase()),
            _row('Başlangıç', _fmt(m['baslangic'])),
            _row('Bitiş', _fmt(m['bitis'])),
          ]),
          const SizedBox(height: 16),
          _section('Öğrenci Bilgileri', [
            _row('Ad', (ogr['ad'] ?? '').toString()),
            _row('Sınıf', (ogr['sinif'] ?? '').toString()),
            _row('Veli', (ogr['veli'] ?? '').toString()),
            _row('Problem Davranış', (ogr['problemDavranis'] ?? '').toString()),
          ]),
          const SizedBox(height: 16),
          _section('Rapor Özeti', [
            _row('Hedef(ler)', (m['hedef'] ?? '').toString()),
            _row('Kısa Vadeli Amaçlar', (m['amaclar'] ?? '').toString()),
            _row('Ölçüt', (m['olcut'] ?? '').toString()),
            _row('Sorumlu Terapist', (m['sorumlu'] ?? '').toString()),
            if ((m['not'] ?? '').toString().isNotEmpty) _row('Not', (m['not'] ?? '').toString()),
          ]),
          const SizedBox(height: 16),
          _section('Gelişim Alanları', [
            _row('Dil Gelişimi', (gelisim['dil'] ?? '').toString()),
            _row('Motor Beceriler', (gelisim['motor'] ?? '').toString()),
            _row('Sosyal Etkileşim', (gelisim['sosyal'] ?? '').toString()),
            _row('Bilişsel Gelişim', (gelisim['bilissel'] ?? '').toString()),
            _row('Öz Bakım Becerileri', (gelisim['ozBakim'] ?? '').toString()),
            _row('Duyusal Profil', (gelisim['duyusal'] ?? '').toString()),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}