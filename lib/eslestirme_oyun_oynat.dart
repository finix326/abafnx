// lib/eslestirme_oyun_oynat.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class EslestirmeOyunOynatPage extends StatefulWidget {
  final int gameId;

  const EslestirmeOyunOynatPage({super.key, required this.gameId});

  @override
  State<EslestirmeOyunOynatPage> createState() =>
      _EslestirmeOyunOynatPageState();
}

class _EslestirmeOyunOynatPageState extends State<EslestirmeOyunOynatPage>
    with TickerProviderStateMixin {
  late final Box _box;

  String _title = 'Eşleştirme';
  final List<_SideItem> _left = [];
  final List<_SideItem> _right = [];

  final Set<int> _matchedLeft = {};
  final Set<int> _matchedRight = {};

  final Map<int, AnimationController> _popLeft = {};
  final Map<int, AnimationController> _popRight = {};
  final Map<int, AnimationController> _wobbleLeft = {};
  final Map<int, AnimationController> _wobbleRight = {};

  int _moves = 0;
  late final Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('es_game_box');
    _sw = Stopwatch()..start();
    _loadGame();
  }

  @override
  void dispose() {
    for (final c in _popLeft.values) {
      c.dispose();
    }
    for (final c in _popRight.values) {
      c.dispose();
    }
    for (final c in _wobbleLeft.values) {
      c.dispose();
    }
    for (final c in _wobbleRight.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _strMap(Map raw) =>
      raw.map((k, v) => MapEntry(k.toString(), v));

  void _loadGame() {
    _left.clear();
    _right.clear();
    _matchedLeft.clear();
    _matchedRight.clear();
    _moves = 0;

    final raw = _box.get('game_${widget.gameId}');
    Map<String, dynamic> gm;
    if (raw is Map) {
      gm = Map<String, dynamic>.from(_strMap(raw));
    } else {
      gm = {
        "title": "Eşleştirme (Örnek)",
        "pairs": [
          {
            "id": 1,
            "leftType": "text",
            "left": "kedi",
            "rightType": "text",
            "right": "kedi"
          },
          {
            "id": 2,
            "leftType": "text",
            "left": "elma",
            "rightType": "text",
            "right": "elma"
          },
          {
            "id": 3,
            "leftType": "text",
            "left": "mavi",
            "rightType": "text",
            "right": "mavi"
          },
        ]
      };
    }

    _title = (gm['title'] as String?) ?? 'Eşleştirme';

    final pairsRaw = gm['pairs'];
    final List<Map<String, dynamic>> pairs = [];
    if (pairsRaw is List) {
      for (final p in pairsRaw.whereType<Map>()) {
        final m = Map<String, dynamic>.from(_strMap(p));
        if (m['id'] == null) continue;
        pairs.add(m);
      }
    }

    for (final p in pairs) {
      final pairId = (p['id'] as num).toInt();
      _left.add(_SideItem(
          idx: _left.length,
          pairId: pairId,
          type: (p['leftType'] as String?) ?? 'text',
          value: (p['left'] as String?) ?? '',
          side: _WhichSide.left));
      _right.add(_SideItem(
          idx: _right.length,
          pairId: pairId,
          type: (p['rightType'] as String?) ?? 'text',
          value: (p['right'] as String?) ?? '',
          side: _WhichSide.right));
    }

    _left.shuffle(Random());
    _right.shuffle(Random());

    for (var i = 0; i < _left.length; i++) {
      _popLeft[i]?.dispose();
      _popLeft[i] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          lowerBound: 0.9,
          upperBound: 1.15);
      _wobbleLeft[i]?.dispose();
      _wobbleLeft[i] =
          AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    }
    for (var i = 0; i < _right.length; i++) {
      _popRight[i]?.dispose();
      _popRight[i] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          lowerBound: 0.9,
          upperBound: 1.15);
      _wobbleRight[i]?.dispose();
      _wobbleRight[i] =
          AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    }

    setState(() {});
  }

  Future<void> _onMatch({
    required _WhichSide fromSide,
    required int fromIdx,
    required int toIdx,
  }) async {
    _moves += 1;
    HapticFeedback.lightImpact();

    final animFrom =
    fromSide == _WhichSide.left ? _popLeft[fromIdx] : _popRight[fromIdx];
    final animTo =
    fromSide == _WhichSide.left ? _popRight[toIdx] : _popLeft[toIdx];

    await Future.wait([
      (animFrom?.forward().then((_) => animFrom.reverse())) ?? Future.value(),
      (animTo?.forward().then((_) => animTo.reverse())) ?? Future.value(),
    ]);

    setState(() {
      if (fromSide == _WhichSide.left) {
        _matchedLeft.add(fromIdx);
        _matchedRight.add(toIdx);
      } else {
        _matchedRight.add(fromIdx);
        _matchedLeft.add(toIdx);
      }
    });

    if (_matchedLeft.length == _left.length &&
        _matchedRight.length == _right.length) {
      _sw.stop();
      _showFinishDialog();
    }
  }

  void _onWrongDrop({required _WhichSide onSide, required int onIndex}) {
    _moves += 1;
    HapticFeedback.heavyImpact();
    final anim =
    onSide == _WhichSide.left ? _wobbleLeft[onIndex] : _wobbleRight[onIndex];
    anim?.forward(from: 0).then((_) => anim.reverse());
  }

  Future<void> _showFinishDialog() async {
    final secs = (_sw.elapsedMilliseconds / 1000.0);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tebrikler!'),
        content: Text(
          'Tüm eşleşmeler tamamlandı.\nHamle: $_moves\nSüre: ${secs.toStringAsFixed(1)} sn',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _sw
                ..reset()
                ..start();
              _loadGame();
            },
            child: const Text('Yeniden Oyna'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftCount = _left.length;
    final rightCount = _right.length;
    final maxCount = max(leftCount, rightCount);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Yeniden karıştır',
            onPressed: () {
              _sw
                ..reset()
                ..start();
              _loadGame();
            },
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: (_left.isEmpty || _right.isEmpty)
          ? const Center(
        child: Text('Bu oyunda kart yok. Düzenle ekranından çift ekleyin.'),
      )
          : Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final isWide = c.maxWidth > 800;
            final spacing = 12.0;

            // Dinamik sütun sayısı: tablet/masaüstü için 3–4, dar ekran için 2
            int cols;
            if (c.maxWidth > 1200) {
              cols = 4;
            } else if (c.maxWidth > 900) {
              cols = 3;
            } else {
              cols = 2;
            }

            final leftList =
            List.generate(maxCount, (i) => i < leftCount ? i : null);
            final rightList =
            List.generate(maxCount, (i) => i < rightCount ? i : null);

            final leftPane = _buildDragDropList(
              side: _WhichSide.left,
              indexList: leftList,
              itemOf: (i) => _left[i!],
              matchedSet: _matchedLeft,
              popControllerOf: (i) => _popLeft[i]!,
              wobbleControllerOf: (i) => _wobbleLeft[i]!,
              crossAxisCount: cols,
            );

            final rightPane = _buildDragDropList(
              side: _WhichSide.right,
              indexList: rightList,
              itemOf: (i) => _right[i!],
              matchedSet: _matchedRight,
              popControllerOf: (i) => _popRight[i]!,
              wobbleControllerOf: (i) => _wobbleRight[i]!,
              crossAxisCount: cols,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: leftPane),
                  SizedBox(width: spacing),
                  Expanded(child: rightPane),
                ],
              );
            } else {
              return Column(
                children: [
                  Expanded(child: leftPane),
                  SizedBox(height: spacing),
                  Expanded(child: rightPane),
                ],
              );
            }
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Hamle: $_moves   Süre: ${(_sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)} sn',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDragDropList({
    required _WhichSide side,
    required List<int?> indexList,
    required _SideItem Function(int?) itemOf,
    required Set<int> matchedSet,
    required AnimationController Function(int) popControllerOf,
    required AnimationController Function(int) wobbleControllerOf,
    required int crossAxisCount,
  }) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1, // her hücre kare
      children: [
        for (final idx in indexList)
          if (idx != null)
            DragTarget<_DragData>(
              builder: (context, candidate, rejected) {
                final item = itemOf(idx);
                final matched = matchedSet.contains(idx);
                final hovering = candidate.isNotEmpty;

                final cell = _CardCell(
                  item: item,
                  matched: matched,
                  popController: popControllerOf(idx),
                  wobbleController: wobbleControllerOf(idx),
                );

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  foregroundDecoration: hovering
                      ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                      : null,
                  child: _DraggableWrapper(
                    enabled: !matched,
                    side: side,
                    index: idx,
                    data: _DragData(side: side, index: idx, pairId: item.pairId),
                    child: cell,
                  ),
                );
              },
              onAcceptWithDetails: (details) {
                final d = details.data;
                final isCorrectPair = d.pairId == itemOf(idx).pairId;
                final isDifferentSide = d.side != side;

                if (isCorrectPair && isDifferentSide) {
                  _onMatch(fromSide: d.side, fromIdx: d.index, toIdx: idx);
                } else {
                  _onWrongDrop(onSide: side, onIndex: idx);
                }
              },
            ),
      ],
    );
  }
}

enum _WhichSide { left, right }

class _SideItem {
  final int idx;
  final int pairId;
  final String type;
  final String value;
  final _WhichSide side;

  _SideItem({
    required this.idx,
    required this.pairId,
    required this.type,
    required this.value,
    required this.side,
  });
}

class _DragData {
  final _WhichSide side;
  final int index;
  final int pairId;

  _DragData({required this.side, required this.index, required this.pairId});
}

class _DraggableWrapper extends StatelessWidget {
  final bool enabled;
  final _WhichSide side;
  final int index;
  final _DragData data;
  final Widget child;

  const _DraggableWrapper({
    required this.enabled,
    required this.side,
    required this.index,
    required this.data,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Opacity(opacity: .3, child: child);

    return Draggable<_DragData>(
      data: data,
      feedback: _dragFeedback(context, child),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      childWhenDragging: Opacity(opacity: .35, child: child),
      child: child,
    );
  }

  Widget _dragFeedback(BuildContext context, Widget base) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final feedbackWidth = isWide ? screenWidth / 4 : screenWidth / 2;

    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: .95,
        child: Transform.scale(
          scale: 1.05,
          child: SizedBox(width: feedbackWidth, child: base),
        ),
      ),
    );
  }
}

class _CardCell extends StatelessWidget {
  final _SideItem item;
  final bool matched;
  final AnimationController popController;
  final AnimationController wobbleController;

  const _CardCell({
    required this.item,
    required this.matched,
    required this.popController,
    required this.wobbleController,
  });

  @override
  Widget build(BuildContext context) {
    final bg = matched
        ? Colors.green.withOpacity(.18)
        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6);

    final errorColor = ColorTween(
      begin: matched
          ? Colors.green.withOpacity(.6)
          : Theme.of(context).colorScheme.outlineVariant,
      end: Theme.of(context).colorScheme.error,
    ).animate(wobbleController);

    return AnimatedScale(
      scale: matched ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeIn,
      child: ScaleTransition(
        scale: popController,
        child: AnimatedBuilder(
          animation: errorColor,
          builder: (context, child) {
            return AspectRatio(
              aspectRatio: 1.0, // kare
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: errorColor.value!, width: 1.5),
                ),
                child: _content(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (item.type == 'image' && item.value.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Image.file(
          File(item.value),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover, // görsel kareyi doldursun
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 36),
          ),
        ),
      );
    }

    final text = item.value.trim().isEmpty ? '—' : item.value;
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}