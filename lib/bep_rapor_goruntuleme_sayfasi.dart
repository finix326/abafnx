import 'package:flutter/material.dart';

class BepRaporGoruntulemeSayfasi extends StatelessWidget {
  final Map<String, List<Map<String, String>>> raporVerileri;

  const BepRaporGoruntulemeSayfasi({super.key, required this.raporVerileri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BEP Raporu"),
      ),
      body: ListView.builder(
        itemCount: raporVerileri.keys.length,
        itemBuilder: (context, index) {
          String kategori = raporVerileri.keys.elementAt(index);
          List<Map<String, String>> hedefler = raporVerileri[kategori]!;

          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kategori,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...hedefler.map((hedefMap) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hedefMap["uzun"]?.isNotEmpty ?? false)
                          Text("Uzun Dönemli Hedef: ${hedefMap["uzun"]}"),
                        if (hedefMap["kisa"]?.isNotEmpty ?? false)
                          Text("Kısa Dönemli Hedef: ${hedefMap["kisa"]}"),
                        const SizedBox(height: 6),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}