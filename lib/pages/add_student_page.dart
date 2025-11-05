import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../student.dart';
import '../app_state/current_student.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _veli = TextEditingController();
  final _not = TextEditingController();

  @override
  void dispose() {
    _ad.dispose();
    _veli.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = const Uuid().v4();
    final s = Student(
      id: id,
      ad: _ad.text.trim(),
      veliAd: _veli.text.trim().isEmpty ? null : _veli.text.trim(),
      not: _not.text.trim().isEmpty ? null : _not.text.trim(),
    );

    final students = Hive.box<Student>('students');
    await students.put(id, s);

    // İsteğe bağlı: yeni eklenen öğrenciyi hemen aktif yap
    await context.read<CurrentStudent>().set(id);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Öğrenci')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _ad,
                decoration: const InputDecoration(labelText: 'Öğrenci adı'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              TextFormField(
                controller: _veli,
                decoration: const InputDecoration(labelText: 'Veli adı (opsiyonel)'),
              ),
              TextFormField(
                controller: _not,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
  }
}