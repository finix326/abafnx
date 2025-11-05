import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class BepRaporDetaySayfasi extends StatelessWidget {
  final Map<String, dynamic> rapor;
  const BepRaporDetaySayfasi({super.key, required this.rapor});

  @override
  Widget build(BuildContext context) {
    final fotoPath = (rapor['fotoPath'] ?? '').toString();

    Widget bilgiSatiri(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );

    Widget hedefListesi(String baslik, Map? alan) {
      final list = (alan?['hedefler'] as List?) ?? const [];
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (list.isEmpty)
              const Text('Hedef yok'),
            for (int i = 0; i < list.length; i++) ...[
              const Divider(height: 18),
              Text('Hedef ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Uzun Dönem: ${list[i]['uzun'] ?? '-'}'),
              const SizedBox(height: 4),
              Text('Kısa Dönem: ${list[i]['kisa'] ?? '-'}'),
            ]
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BEP Raporu'),
        actions: [
          IconButton(
            tooltip: 'PDF indir / paylaş',
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final doc = await _buildPdf(rapor);
              await Printing.sharePdf(bytes: await doc.save(), filename: 'bep_raporu.pdf');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Üst bilgi + foto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        bilgiSatiri('Tarih', rapor['tarihStr']?.toString() ?? ''),
                        bilgiSatiri('Öğrenci', rapor['ogrenciAd']?.toString() ?? ''),
                        bilgiSatiri('TC Kimlik', rapor['tcKimlik']?.toString() ?? ''),
                        bilgiSatiri('Sınıf', rapor['sinif']?.toString() ?? ''),
                        bilgiSatiri('Öğretmen', rapor['ogretmen']?.toString() ?? ''),
                        bilgiSatiri('Veli', rapor['veli']?.toString() ?? ''),
                        bilgiSatiri('Telefon', rapor['telefon']?.toString() ?? ''),
                        bilgiSatiri('Problem Davranış', rapor['problemDavranis']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                height: 96,
                child: (fotoPath.isNotEmpty && File(fotoPath).existsSync())
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(fotoPath), fit: BoxFit.cover),
                )
                    : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 42),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Alanlar
          hedefListesi('Dil Gelişimi', rapor['dil'] as Map?),
          hedefListesi('Motor Beceriler', rapor['motor'] as Map?),
          hedefListesi('Sosyal Etkileşim', rapor['sosyal'] as Map?),
          hedefListesi('Bilişsel Gelişim', rapor['bilissel'] as Map?),
          hedefListesi('Öz Bakım Becerileri', rapor['ozBakim'] as Map?),
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdf(Map<String, dynamic> r) async {
    final doc = pw.Document();
    pw.Widget bilgi(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 120, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );

    pw.Widget hedefler(String baslik, Map? alan) {
      final list = (alan?['hedefler'] as List?) ?? const [];
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(baslik, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (list.isEmpty) pw.Text('Hedef yok'),
          for (int i = 0; i < list.length; i++) ...[
            pw.Divider(),
            pw.Text('Hedef ${i + 1}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Uzun Dönem: ${list[i]['uzun'] ?? '-'}'),
            pw.SizedBox(height: 2),
            pw.Text('Kısa Dönem: ${list[i]['kisa'] ?? '-'}'),
          ],
        ]),
      );
    }

    // Foto
    pw.Widget? fotoWidget;
    final fotoPath = (r['fotoPath'] ?? '').toString();
    if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
      final bytes = await File(fotoPath).readAsBytes();
      final image = pw.MemoryImage(bytes);
      fotoWidget = pw.Container(
        width: 80,
        height: 80,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.ClipRRect(
          verticalRadius: 6,
          horizontalRadius: 6,
          child: pw.Image(image, fit: pw.BoxFit.cover),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(children: [
                    bilgi('Tarih', r['tarihStr']?.toString() ?? ''),
                    bilgi('Öğrenci', r['ogrenciAd']?.toString() ?? ''),
                    bilgi('TC Kimlik', r['tcKimlik']?.toString() ?? ''),
                    bilgi('Sınıf', r['sinif']?.toString() ?? ''),
                    bilgi('Öğretmen', r['ogretmen']?.toString() ?? ''),
                    bilgi('Veli', r['veli']?.toString() ?? ''),
                    bilgi('Telefon', r['telefon']?.toString() ?? ''),
                    bilgi('Problem Davranış', r['problemDavranis']?.toString() ?? ''),
                  ]),
                ),
              ),
              pw.SizedBox(width: 8),
              if (fotoWidget != null) fotoWidget,
            ],
          ),
          pw.SizedBox(height: 12),
          hedefler('Dil Gelişimi', r['dil'] as Map?),
          pw.SizedBox(height: 8),
          hedefler('Motor Beceriler', r['motor'] as Map?),
          pw.SizedBox(height: 8),
          hedefler('Sosyal Etkileşim', r['sosyal'] as Map?),
          pw.SizedBox(height: 8),
          hedefler('Bilişsel Gelişim', r['bilissel'] as Map?),
          pw.SizedBox(height: 8),
          hedefler('Öz Bakım Becerileri', r['ozBakim'] as Map?),
        ],
      ),
    );

    return doc;
  }
}