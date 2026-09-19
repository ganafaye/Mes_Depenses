import 'package:flutter/material.dart';
import 'configurer_portefeuilles_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Widget _buildExplicationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              // Logo seul, sans contour
              SizedBox(
                width: 180,
                height: 180,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EEFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFCCDAFF), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: Color(0xFF003178),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Gestion budgétaire automatisée',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003178),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Gérez vos finances\nen toute simplicité',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003178),
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Suivez vos dépenses, vos revenus et votre budget\navec une vue claire et sécurisée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF5E6776),
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 24),

              _buildExplicationCard(
                icon: Icons.swap_vert,
                title: 'Les opérations',
                subtitle:
                    'Une opération représente un revenu ou une dépense.\nExemple : salaire, restaurant, facture, transfert.',
                color: const Color(0xFF003178),
                background: const Color(0xFFEAF1FF),
              ),
              const SizedBox(height: 12),

              _buildExplicationCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Les comptes',
                subtitle:
                    'Chaque argent est rattaché à un compte.\nWave, Orange Money, espèces ou banque : tout est suivi.',
                color: const Color(0xFF0F766E),
                background: const Color(0xFFE6FFFB),
              ),
              const SizedBox(height: 12),

              _buildExplicationCard(
                icon: Icons.notifications_active_outlined,
                title: 'Les notifications',
                subtitle:
                    'Pour que l’app détecte automatiquement vos transactions,\nactive les notifications dans les Paramètres Android.',
                color: const Color(0xFFB45309),
                background: const Color(0xFFFFF7ED),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBFE3C8), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF2E7D32),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '100% Hors-ligne & Confidentiel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vos données restent exclusivement stockées sur votre téléphone.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConfigurerPortefeuillesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003178),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Commencer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Aucune donnée envoyée sur Internet',
                style: TextStyle(fontSize: 11, color: Color(0xFF7A8191)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
