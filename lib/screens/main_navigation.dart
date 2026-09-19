import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'historique_screen.dart';
import 'stats_screen.dart';
import 'reglages_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _indexActif = 0;

  final List<Widget> _ecrans = const [
    HomeScreen(),
    HistoriqueScreen(),
    StatsScreen(),
    ReglagesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indexActif, children: _ecrans),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _buildOnglet(0, Icons.account_balance_wallet, 'Accueil'),
                _buildOnglet(1, Icons.receipt_long, 'Historique'),
                _buildOnglet(2, Icons.bar_chart, 'Statistiques'),
                _buildOnglet(3, Icons.settings, 'Réglages'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnglet(int index, IconData icone, String label) {
    final actif = _indexActif == index;
    final couleur = actif ? const Color(0xFF003178) : const Color(0xFF737783);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _indexActif = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: couleur, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
