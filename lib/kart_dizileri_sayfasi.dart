import 'package:flutter/material.dart';

import 'kartlar_sayfasi.dart';

/// Eski sayfa için geriye dönük uyumluluk.
class KartDizileriSayfasi extends StatelessWidget {
  const KartDizileriSayfasi({super.key});

  @override
  Widget build(BuildContext context) => const KartlarSayfasi();
}