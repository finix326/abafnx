// lib/hafiza_oyunu_detay_sayfasi.dart

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'hafiza_oyunu_model.dart';

class HafizaOyunuDetaySayfasi extends StatefulWidget {
  final String oyunId;
  const HafizaOyunuDetaySayfasi({super.key, required this.oyunId});

  @override
  State<HafizaOyunuDetaySayfasi> createState() =>
      _HafizaOyunuDetaySayfasiState();
}

class _HafizaOyunuDetaySayfasiState extends State<HafizaOyunuDetaySayfasi>
    with TickerProviderStateMixin { // Animasyon için TickerProvider eklendi
  late final Box _box;
  HafizaOyunu? _oyun;
  bool _hazirMod = true;

  List<String> _deck = [];
  List<bool> _revealed = [];
  List<bool> _matched = [];
  int? _firstOpenIndex;
  bool _isChecking = false;
  bool _showAllFaces = false;

  // 0 = küçük, 1 = orta, 2 = büyük kartlar
  int _cardSizeIndex = 1;

  int _moveCount = 0; // Yapılan hamle sayısı (her iki kart açıldığında 1 hamle)
  DateTime? _gameStartTime; // Oyunun başladığı an
  int _gameRound = 0; // Her yeni oyunda arttırılır, kart state'lerini sıfırlamak için

  @override
  void initState() {
    super.initState();
    _box = Hive.box('hafiza_oyunlari');
    _loadGame();
  }

  void _loadGame() {
    final raw = (_box.get(widget.oyunId) as Map?) ?? {};
    final oyun = HafizaOyunu.fromMap(widget.oyunId, raw);

    final allImagesSelected =
        oyun.imagePaths.where((p) => p.isNotEmpty).length == oyun.pairCount;

    setState(() {
      _oyun = oyun;
      // Eğer tüm görseller seçiliyse, bu sayfaya girildiğinde direkt oyun moduna hazırlanacağız
      _hazirMod = !allImagesSelected;
      _adjustCardSizeForPairs(oyun.pairCount);
    });

    if (allImagesSelected) {
      // Widget ağaca yerleştikten sonra oyunu otomatik başlat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startGame();
      });
    }
  }

  Future<void> _saveGame() async {
    if (_oyun == null) return;
    await _box.put(_oyun!.id, _oyun!.toMap());
  }

  Future<void> _pickImageForIndex(int index) async {
    if (_oyun == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/hafiza_oyunlari_resimler');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fileName =
        '${_oyun!.id}_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File('${dir.path}/$fileName');
    await File(picked.path).copy(targetFile.path);

    setState(() {
      if (_oyun!.imagePaths.length > index) {
        _oyun!.imagePaths[index] = targetFile.path;
      } else {
        while (_oyun!.imagePaths.length < index) {
          _oyun!.imagePaths.add('');
        }
        _oyun!.imagePaths.add(targetFile.path);
      }
    });

    await _saveGame();
  }

  Future<void> _removeImageAt(int index) async {
    if (_oyun == null) return;
    if (index >= _oyun!.imagePaths.length) return;

    final path = _oyun!.imagePaths[index];
    if (path.isNotEmpty && File(path).existsSync()) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }

    setState(() {
      _oyun!.imagePaths[index] = '';
    });
    await _saveGame();
  }

  void _startGame() {
    final oyun = _oyun;
    if (oyun == null) return;

    final paths = oyun.imagePaths.where((p) => p.isNotEmpty).toList();
    if (paths.length != oyun.pairCount) return;

    // Her görseli 2 kez ekle, karıştır
    final deck = <String>[...paths, ...paths]..shuffle();

    setState(() {
      _gameRound++; // Yeni tur başlıyor
      _deck = deck;
      _revealed = List<bool>.filled(deck.length, false);
      _matched = List<bool>.filled(deck.length, false);
      _firstOpenIndex = null;
      _isChecking = false;
      _hazirMod = false;
      _showAllFaces = false; // oyun başında kartlar kapalı (hafıza oyunu direkt hazır)
      _moveCount = 0;
      _gameStartTime = DateTime.now();
      _adjustCardSizeForPairs(oyun.pairCount);
    });
  }

  void _restartGame() {
    _startGame();
  }

  void _onGameCardTap(int index) {
    if (_hazirMod) return; // hazırlama modunda oyun oynanmaz
    if (_isChecking) return;
    if (index < 0 || index >= _deck.length) return;
    if (_matched[index] || _revealed[index]) return;

    setState(() {
      _revealed[index] = true;
    });

    if (_firstOpenIndex == null) {
      _firstOpenIndex = index;
      return;
    }

    final first = _firstOpenIndex!;
    if (first == index) return;

    // İkinci kart açıldı, bir hamle say
    _moveCount++;
    _isChecking = true;

    if (_deck[first] == _deck[index]) {
      // Doğru eşleşme
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _matched[first] = true;
          _matched[index] = true;
          _firstOpenIndex = null;
          _isChecking = false;
        });

        // Tüm kartlar eşleşti mi?
        final finished =
            _matched.isNotEmpty && _matched.every((matched) => matched);
        if (finished) {
          _showGameResultDialog();
        }
      });
    } else {
      // Yanlış eşleşme
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          _revealed[first] = false;
          _revealed[index] = false;
          _firstOpenIndex = null;
          _isChecking = false;
        });
      });
    }
  }
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _showGameResultDialog() {
    final elapsed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : Duration.zero;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Oyun bitti'),
          content: Text(
            'Toplam hamle: $_moveCount\nSüre: ${_formatDuration(elapsed)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Kapat'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartGame();
              },
              child: const Text('Yeniden oyna'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNextImageSlot() async {
    final oyun = _oyun;
    if (oyun == null) return;

    int? emptyIndex;
    for (var i = 0; i < oyun.pairCount; i++) {
      final hasImage =
          i < oyun.imagePaths.length && oyun.imagePaths[i].isNotEmpty;
      if (!hasImage) {
        emptyIndex = i;
        break;
      }
    }

    if (emptyIndex == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm çiftler için görsel atanmış.')),
        );
      }
      return;
    }

    await _pickImageForIndex(emptyIndex);
  }

  void _adjustCardSizeForPairs(int pairCount) {
    if (pairCount >= 10) {
      _cardSizeIndex = 0;
    } else if (pairCount >= 7) {
      _cardSizeIndex = 1;
    } else {
      _cardSizeIndex = 2;
    }
  }

  void _cycleCardSize() {
    setState(() {
      _cardSizeIndex = (_cardSizeIndex + 1) % 3;
    });
  }

  int _currentCrossAxisCount() {
    switch (_cardSizeIndex) {
      case 0:
        return 5; // küçük
      case 1:
        return 4; // orta
      default:
        return 3; // büyük
    }
  }

  @override
  Widget build(BuildContext context) {
    final oyun = _oyun;
    if (oyun == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allImagesSelected =
        oyun.imagePaths.where((p) => p.isNotEmpty).length == oyun.pairCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(oyun.title),
        actions: [
          if (_hazirMod) ...[
            IconButton(
              tooltip: 'Kart boyutu',
              icon: const Icon(Icons.fit_screen),
              onPressed: _cycleCardSize,
            ),
            IconButton(
              tooltip: allImagesSelected
                  ? 'Oyunu başlat'
                  : 'Önce tüm görselleri seç',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: allImagesSelected ? _startGame : null,
            ),
          ] else ...[
            // Göz ikonu: kartları toplu aç/kapat
            IconButton(
              tooltip: _showAllFaces ? 'Kartları gizle' : 'Kartları göster',
              icon: Icon(
                _showAllFaces ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _showAllFaces = !_showAllFaces;
                });
              },
            ),
            // Üç nokta: diğer aksiyonlar menüde
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'size':
                    _cycleCardSize();
                    break;
                  case 'restart':
                    _restartGame();
                    break;
                  case 'prep':
                    setState(() {
                      _hazirMod = true;
                    });
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'size',
                  child: Text('Kart boyutunu değiştir'),
                ),
                PopupMenuItem(
                  value: 'restart',
                  child: Text('Yeniden oyna'),
                ),
                PopupMenuItem(
                  value: 'prep',
                  child: Text('Hazırlama moduna geç'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Çift sayısı: ${oyun.pairCount} · Toplam kart: ${oyun.pairCount * 2}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _hazirMod
                  ? _buildPreparationGrid(oyun)
                  : _buildGameGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: _hazirMod
          ? FloatingActionButton.extended(
              onPressed: _addNextImageSlot,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Fotoğraf ekle'),
            )
          : null,
    );
  }

  Widget _buildGameGrid() {
    return GridView.builder(
      itemCount: _deck.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _currentCrossAxisCount(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        return _AnimatedGameCard(
          key: ValueKey('round_${_gameRound}_${_deck[index]}_$index'),
          imagePath: _deck[index],
          isRevealed: _revealed[index] || _showAllFaces,
          isMatched: _matched[index],
          onTap: () => _onGameCardTap(index),
          // Giriş animasyonu için gecikme
          animationDelay: Duration(milliseconds: 50 * index),
        );
      },
    );
  }

  Widget _buildPreparationGrid(HafizaOyunu oyun) {
    return GridView.builder(
      itemCount: oyun.pairCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _currentCrossAxisCount(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        String? imgPath;
        if (index < oyun.imagePaths.length) {
          imgPath = oyun.imagePaths[index];
        }
        final hasImage = imgPath != null && imgPath.isNotEmpty;

        return GestureDetector(
          onTap: () => _pickImageForIndex(index),
          onLongPress: hasImage
              ? () async {
            final act = await showModalBottomSheet<String>(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Görseli değiştir'),
                      onTap: () =>
                          Navigator.pop(context, 'change'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete,
                          color: Colors.red),
                      title: const Text('Görseli kaldır'),
                      onTap: () =>
                          Navigator.pop(context, 'delete'),
                    ),
                  ],
                ),
              ),
            );
            if (act == 'change') {
              await _pickImageForIndex(index);
            } else if (act == 'delete') {
              await _removeImageAt(index);
            }
          }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.green : Colors.grey.shade400,
              ),
            ),
            child: hasImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imgPath!),
                fit: BoxFit.cover,
              ),
            )
                : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_photo_alternate, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Çift ${index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---- YENİ: ANİMASYONLU KART WIDGET'I ----

class _AnimatedGameCard extends StatefulWidget {
  final String imagePath;
  final bool isRevealed;
  final bool isMatched;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _AnimatedGameCard({
    super.key,
    required this.imagePath,
    required this.isRevealed,
    required this.isMatched,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  State<_AnimatedGameCard> createState() => _AnimatedGameCardState();
}

class _AnimatedGameCardState extends State<_AnimatedGameCard>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _entryController;
  late AnimationController _matchController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _matchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Scale + Fade
    );

    if (widget.isRevealed) {
      _flipController.value = 1.0;
    }

    // Giriş animasyonunu başlat
    Future.delayed(widget.animationDelay, () {
      if (mounted) {
        _entryController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedGameCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRevealed != oldWidget.isRevealed) {
      widget.isRevealed ? _flipController.forward() : _flipController.reverse();
    }

    if (widget.isMatched && !oldWidget.isMatched) {
      HapticFeedback.mediumImpact();
      _matchController.forward();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _entryController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    final matchScale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 0.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _matchController, curve: Curves.easeInOut),
    );

    return FadeTransition(
      opacity: opacityAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: ScaleTransition(
          scale: matchScale,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _flipController,
              builder: (context, child) {
                final angle = _flipController.value * pi;
                final isFlipping = _flipController.isAnimating;

                final content = angle < pi / 2
                    ? _buildCardFace(isBack: true)
                    : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(pi),
                  child: _buildCardFace(isBack: false),
                );

                return IgnorePointer(
                  ignoring: isFlipping,
                  child: Transform(
                    transform: Matrix4.rotationY(angle),
                    alignment: Alignment.center,
                    child: content,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace({required bool isBack}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: isBack ? Colors.blueGrey.shade400 : Colors.grey.shade100,
          child: isBack
              ? Center(
            child: Icon(
              Icons.question_mark_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.8),
            ),
          )
              : Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.error_outline),
          ),
        ),
      ),
    );
  }
}
