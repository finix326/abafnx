import 'package:flutter/material.dart';

class OyunOrnek1 extends StatelessWidget {
  const OyunOrnek1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Örnek Oyun 1")),
      body: const Center(
        child: Text("Buraya oyun ekranı gelecek."),
      ),
    );
  }
}
