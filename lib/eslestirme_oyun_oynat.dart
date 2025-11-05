import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class EslestirmeOyunOynatPage extends StatefulWidget {
  final int gameId;
  const EslestirmeOyunOynatPage({super.key, required this.gameId});

  @override
  State<EslestirmeOyunOynatPage> createState() => _EslestirmeOyunOynatPageState();
}

class _EslestirmeOyunOynatPageState extends State<EslestirmeOyunOynatPage> {
  late Box _box;
  List<Map<String, dynamic>> _pairs = [];
  final Map<int, bool> _matched = {}; // index -> matched?

  @override
  void initState() {
    super.initState();
    _box = Hive.box('es_game_box');
    final gm = Map<String, dynamic>.from(_box.get('game_${widget.gameId}') as Map? ?? {});
    _pairs = (gm['pairs'] as List?)?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    for (int i = 0; i < _pairs.length; i++) { _matched[i] = false; }
  }

  @override
  Widget build(BuildContext context) {
    final indices = List<int>.generate(_pairs.length, (i) => i);
    final shuffled = List<int>.from(indices)..shuffle(Random());

    Widget _chipOf(int i, bool isLeft) {
      final t = (isLeft ? _pairs[i]['leftType'] : _pairs[i]['rightType']).toString();
      final v = (isLeft ? _pairs[i]['left'] : _pairs[i]['right']).toString();
      final child = t == 'text'
          ? Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
          : (v.isEmpty ? const Icon(Icons.broken_image_outlined, size: 36) : Image.file(File(v), height: 56, fit: BoxFit.contain));
      return Container(
        constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _matched[i]! ? Colors.green : Theme.of(context).dividerColor,
            width: _matched[i]! ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x22000000), offset: Offset(0,2))],
        ),
        child: Center(child: child),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Eşleştirme')),
      body: _pairs.isEmpty
          ? const Center(child: Text('Bu oyunda henüz çift yok.'))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, cs) {
            return Row(
              children: [
                // SOL (hedefler)
                Expanded(
                  child: ListView.separated(
                    itemCount: _pairs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      return DragTarget<int>(
                        onWillAccept: (data) => data != null && data == i && !_matched[i]!,
                        onAccept: (data) => setState(() => _matched[i] = true),
                        builder: (context, cand, rej) {
                          return Opacity(
                            opacity: _matched[i]! ? 0.5 : 1,
                            child: _chipOf(i, true),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // SAĞ (sürüklenenler)
                Expanded(
                  child: ListView.separated(
                    itemCount: shuffled.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, k) {
                      final i = shuffled[k];
                      return Draggable<int>(
                        data: i,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _chipOf(i, false),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: _chipOf(i, false)),
                        child: _chipOf(i, false),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}