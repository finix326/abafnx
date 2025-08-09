import 'package:flutter/material.dart';
import 'eslestirme_oyunu_sayfasi.dart'; // Bu dosyayı önceden oluşturduk

class OyunlarSayfasi extends StatelessWidget {
  const OyunlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final oyunlar = [
      {'ad': 'Eşleştirme Oyunu', 'sayfa': const EslestirmeOyunuSayfasi()},
      // Buraya başka oyunlar da eklenebilir
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Oyunlar')),
      body: ListView.builder(
        itemCount: oyunlar.length,
        itemBuilder: (context, index) {
          final oyun = oyunlar[index];
          return ListTile(
            leading: const Icon(Icons.videogame_asset),
            title: Text(oyun['ad'] as String),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => oyun['sayfa'] as Widget),
              );
            },
          );
        },
      ),
    );
  }
}
