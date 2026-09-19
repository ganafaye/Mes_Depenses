import 'package:flutter/material.dart';
import '../data/database.dart';

/// Widget qui affiche le solde actuel d'un compte (calculé).
/// Utilise un FutureBuilder pour charger le solde depuis la DB.
class SoldeCompte extends StatelessWidget {
  final int compteId;
  final TextStyle? style;
  final bool avecDevise;

  const SoldeCompte({
    super.key,
    required this.compteId,
    this.style,
    this.avecDevise = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: DatabaseService().getSoldeCompte(compteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            '...',
            style: style,
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Erreur',
            style: style?.copyWith(color: Colors.red),
          );
        }
        final solde = snapshot.data ?? 0;
        return Text(
          _formatFCFA(solde, avecDevise: avecDevise),
          style: style,
        );
      },
    );
  }

  String _formatFCFA(int centimes, {bool avecDevise = true}) {
    final negatif = centimes < 0;
    final fcfa = (centimes.abs() / 100).toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < fcfa.length; i++) {
      if (i > 0 && (fcfa.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(fcfa[i]);
    }
    final signe = negatif ? '-' : '';
    return avecDevise
        ? '$signe${buffer.toString()} FCFA'
        : '$signe${buffer.toString()}';
  }
}