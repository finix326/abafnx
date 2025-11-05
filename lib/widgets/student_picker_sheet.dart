import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../student.dart';
import '../app_state/current_student.dart';
import '../pages/add_student_page.dart';

Future<void> showStudentPickerSheet(BuildContext context) async {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _StudentPickerSheet(),
  );
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet();

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  late Box<Student> box;

  @override
  void initState() {
    super.initState();
    box = Hive.box<Student>('students'); // main.dart'ta açıyoruz
  }

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentStudent>().currentId;
    final items = box.values.toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Öğrenci seç')),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Henüz öğrenci yok. Aşağıdan ekleyin.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return ListTile(
                      title: Text(s.ad),
                      subtitle: s.veliAd == null ? null : Text('Veli: ${s.veliAd}'),
                      trailing: currentId == s.id ? const Icon(Icons.check) : null,
                      onTap: () async {
                        await context.read<CurrentStudent>().set(s.id);
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Yeni öğrenci ekle'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AddStudentPage(),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}