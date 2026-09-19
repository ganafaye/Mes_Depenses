import 'package:flutter/material.dart';
import '../data/database.dart';
import '../data/secure_store.dart';
import 'detection_screen.dart';
import 'profil_screen.dart';
import 'securite_screen.dart';

class ReglagesScreen extends StatefulWidget {
  const ReglagesScreen({super.key});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  bool _pinActif = false;
  int _nbOperations = 0;
  int _nbComptes = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final pinActif = await SecureStore.hasPin();
    final db = DatabaseService();
    final operations = await db.getOperations();
    final comptes = await db.getComptes();

    if (mounted) {
      setState(() {
        _pinActif = pinActif;
        _nbOperations = operations.length;
        _nbComptes = comptes.length;
      });
    }
  }

  Future<void> _ouvrirProfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilScreen()),
    );
    _charger();
  }

  Future<void> _ouvrirSecurite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecuriteScreen()),
    );
    _charger();
  }

  Future<void> _ouvrirDetection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetectionScreen()),
    );
    _charger();
  }

  Future<void> _effacerToutesLesDonnees() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer toutes mes données ?'),
        content: const Text(
          'Cette action supprimera TOUS tes comptes, opérations, '
          'charges et réglages.\n\n'
          'Cette action est IRRÉVERSIBLE.\n\n'
          'Ton code PIN sera également supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    final confirme2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dernière confirmation'),
        content: const Text(
          'Es-tu vraiment sûr ?\n\n'
          'Tape "EFFACER" pour confirmer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('EFFACER'),
          ),
        ],
      ),
    );

    if (confirme2 != true) return;

    final db = DatabaseService();
    final dbFile = await db.database;
    await dbFile.delete('operations');
    await dbFile.delete('charges');
    await dbFile.delete('comptes');
    await dbFile.update('budget_config', {'reserve_centimes': 0});

    await SecureStore.clearPin();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les données ont été effacées'),
          backgroundColor: Colors.red,
        ),
      );
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Réglages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1E),
                ),
              ),
            ),

            // Section Profil
            _buildSectionTitre('MON COMPTE'),
            const SizedBox(height: 8),
            _buildCarteAction(
              icon: Icons.person_outline,
              titre: 'Mon profil',
              sousTitre: 'Prénom, préférences',
              onTap: _ouvrirProfil,
            ),
            const SizedBox(height: 8),
            _buildCarteAction(
              icon: Icons.lock_outline,
              titre: 'Sécurité',
              sousTitre: _pinActif ? 'Code PIN activé' : 'Aucun code PIN',
              onTap: _ouvrirSecurite,
              couleurSousTitre: _pinActif
                  ? const Color(0xFF43A047)
                  : const Color(0xFF737783),
            ),
            const SizedBox(height: 8),
            _buildCarteAction(
              icon: Icons.notifications_active_outlined,
              titre: 'Détection automatique',
              sousTitre: 'Wave • Orange Money',
              onTap: _ouvrirDetection,
            ),
            const SizedBox(height: 24),

            // Section Données
            _buildSectionTitre('MES DONNÉES'),
            const SizedBox(height: 8),
            _buildCarteInfo(
              icon: Icons.account_balance_wallet,
              titre: 'Comptes',
              valeur: '$_nbComptes',
            ),
            const SizedBox(height: 8),
            _buildCarteInfo(
              icon: Icons.receipt_long,
              titre: 'Opérations',
              valeur: '$_nbOperations',
            ),
            const SizedBox(height: 24),

            // Section Confidentialité
            _buildSectionTitre('CONFIDENTIALITÉ'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Toutes tes données restent sur ce téléphone. '
                      'Aucune information n\'est envoyée sur Internet.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section Zone dangereuse
            _buildSectionTitre('ZONE DANGEREUSE'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _effacerToutesLesDonnees,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFDAD6)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Effacer toutes mes données',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Action irréversible',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF737783),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    'Mes Dépenses • Version 1.0.0 • 2026',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Développé par Gana Faye',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitre(String titre) {
    return Text(
      titre,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF737783),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCarteAction({
    required IconData icon,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
    Color? couleurSousTitre,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF003178).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF003178), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  if (sousTitre.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sousTitre,
                      style: TextStyle(
                        fontSize: 12,
                        color: couleurSousTitre ?? const Color(0xFF737783),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF737783), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteInfo({
    required IconData icon,
    required String titre,
    required String valeur,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF003178).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF003178), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              titre,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
          ),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003178),
            ),
          ),
        ],
      ),
    );
  }
}
