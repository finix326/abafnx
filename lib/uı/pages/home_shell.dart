import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../sohbet_page.dart';
import '../widgets/finix_button.dart';
import '../widgets/finix_card.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    _DashboardPage(),
    SohbetPage(),
    _ReportsPage(),
    _SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Sohbet'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined), selectedIcon: Icon(Icons.insert_chart), label: 'Raporlar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}

// ---------------- Ana Sayfa (örnek dashboard) ----------------
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final fmt = DateFormat('d MMMM y, EEEE', 'tr_TR');

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          title: const Text('Finix'),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverList.list(
            children: [
              FinixCard(
                title: 'Hoş geldin 👋',
                subtitle: fmt.format(now),
                child: const Text('Hızlıca yeni bir sohbet sayfası oluşturabilir veya kayıtlı sohbetleri düzenleyebilirsin.'),
              ),
              FinixCard(
                title: 'Hızlı İşlemler',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FinixButton(text: 'Yeni Sohbet', icon: Icons.add_comment, onPressed: () {
                      // Alt çubuktan Sohbet sekmesine geç
                      final state = context.findAncestorStateOfType<_HomeShellState>();
                      state?.setState(() => state._index = 1);
                    }),
                    FinixButton(text: 'Rapor Al', icon: Icons.picture_as_pdf, onPressed: () {
                      final state = context.findAncestorStateOfType<_HomeShellState>();
                      state?.setState(() => state._index = 2);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Raporlar (placeholder) ----------------
class _ReportsPage extends StatelessWidget {
  const _ReportsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _PlainAppBar(title: 'Raporlar'),
      body: Center(child: Text('PDF/istatistik modülleri burada olacak.')),
    );
  }
}

// ---------------- Ayarlar (placeholder) ----------------
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _PlainAppBar(title: 'Ayarlar'),
      body: Center(child: Text('Tema, yedekleme ve diğer ayarlar.')),
    );
  }
}

// Basit appbar
class _PlainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _PlainAppBar({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}