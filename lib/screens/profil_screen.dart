import 'package:flutter/material.dart';
import '../data/secure_store.dart';
import 'securite_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  String _nom = 'Gana';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final nom = await SecureStore.getNom();
    setState(() {
      _nom = nom;
      _chargement = false;
    });
  }

  Future<void> _modifierNom() async {
    final controller = TextEditingController(text: _nom);
    final nouveauNom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier ton prénom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Prénom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final nom = controller.text.trim();
              if (nom.isNotEmpty) Navigator.pop(ctx, nom);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (nouveauNom != null && nouveauNom != _nom) {
      await SecureStore.setNom(nouveauNom);
      setState(() => _nom = nouveauNom);
    }
  }

  Future<void> _ouvrirSecurite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecuriteScreen()),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mon profil',
          style: TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar + nom
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Color(0xFF003178),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _nom.isNotEmpty ? _nom[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _nom,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Usage personnel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF737783),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Section Préférences
                _buildSectionTitre('Préférences'),
                const SizedBox(height: 8),
                _buildCarteAction(
                  icon: Icons.person_outline,
                  titre: 'Prénom',
                  valeur: _nom,
                  onTap: _modifierNom,
                ),
                const SizedBox(height: 8),
                _buildCarteAction(
                  icon: Icons.attach_money,
                  titre: 'Devise',
                  valeur: 'FCFA',
                  onTap: null,
                ),
                const SizedBox(height: 8),
                _buildCarteAction(
                  icon: Icons.language,
                  titre: 'Langue',
                  valeur: 'Français',
                  onTap: null,
                ),
                const SizedBox(height: 24),

                // Section Sécurité
                _buildSectionTitre('Sécurité'),
                const SizedBox(height: 8),
                _buildCarteAction(
                  icon: Icons.lock_outline,
                  titre: 'Code PIN et biométrie',
                  valeur: '',
                  onTap: _ouvrirSecurite,
                ),
                const SizedBox(height: 24),

                // Section Confidentialité
                _buildSectionTitre('Confidentialité'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Color(0xFF2E7D32), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% hors-ligne',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tes données restent uniquement sur ce téléphone.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitre(String titre) {
    return Text(
      titre.toUpperCase(),
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
    required String valeur,
    required VoidCallback? onTap,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF003178).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF003178), size: 20),
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
            if (valeur.isNotEmpty)
              Text(
                valeur,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF737783),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF737783), size: 20),
            ],
          ],
        ),
      ),
    );
  }
}