import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../models/compte.dart';
import 'creer_profil_screen.dart';

class ConfigurerPortefeuillesScreen extends StatefulWidget {
  const ConfigurerPortefeuillesScreen({super.key});

  @override
  State<ConfigurerPortefeuillesScreen> createState() =>
      _ConfigurerPortefeuillesScreenState();
}

class _ConfigurerPortefeuillesScreenState
    extends State<ConfigurerPortefeuillesScreen> {
  final _db = DatabaseService();

  // Contrôleurs pour les 3 comptes par défaut
  final _waveController = TextEditingController();
  final _omController = TextEditingController();
  final _cashController = TextEditingController();

  // Comptes supplémentaires ajoutés par l'utilisateur
  final List<Map<String, dynamic>> _comptesSupplementaires = [];

  bool _enregistrement = false;

  @override
  void dispose() {
    _waveController.dispose();
    _omController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _ajouterCompteSupplementaire() async {
    final nomController = TextEditingController();
    final montantController = TextEditingController();
    String typeSelectionne = 'banque';

    final resultat = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Ajouter un compte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Type',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTypeChip(
                      'Wave',
                      'wave',
                      typeSelectionne,
                      const Color(0xFF1E88E5),
                      (v) => setStateDialog(() => typeSelectionne = v),
                    ),
                    _buildTypeChip(
                      'Orange',
                      'orange_money',
                      typeSelectionne,
                      const Color(0xFFFF6F00),
                      (v) => setStateDialog(() => typeSelectionne = v),
                    ),
                    _buildTypeChip(
                      'Espèces',
                      'cash',
                      typeSelectionne,
                      const Color(0xFF43A047),
                      (v) => setStateDialog(() => typeSelectionne = v),
                    ),
                    _buildTypeChip(
                      'Banque',
                      'banque',
                      typeSelectionne,
                      const Color(0xFF5E35B1),
                      (v) => setStateDialog(() => typeSelectionne = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nomController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nom du compte',
                    hintText: 'Ex: Wave perso',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Solde de départ',
                    suffixText: 'FCFA',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                final nom = nomController.text.trim();
                if (nom.isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (resultat == true) {
      setState(() {
        _comptesSupplementaires.add({
          'nom': nomController.text.trim(),
          'type': typeSelectionne,
          'controller': montantController,
        });
      });
    }
  }

  Widget _buildTypeChip(
    String label,
    String valeur,
    String selectionne,
    Color couleur,
    Function(String) onTap,
  ) {
    final actif = valeur == selectionne;
    return GestureDetector(
      onTap: () => onTap(valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? couleur.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: actif ? couleur : const Color(0xFFE0E3E6),
            width: actif ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
            color: actif ? couleur : const Color(0xFF434652),
          ),
        ),
      ),
    );
  }

  Future<void> _valider() async {
    setState(() => _enregistrement = true);

    final comptes = <Compte>[];

    // Wave
    final waveSolde = _parseMontant(_waveController.text);
    if (waveSolde > 0) {
      comptes.add(
        Compte(
          nom: 'Wave',
          type: 'wave',
          soldeDepartCentimes: waveSolde,
          dateDebut: DateTime.now(),
        ),
      );
    }

    // Orange Money
    final omSolde = _parseMontant(_omController.text);
    if (omSolde > 0) {
      comptes.add(
        Compte(
          nom: 'Orange Money',
          type: 'orange_money',
          soldeDepartCentimes: omSolde,
          dateDebut: DateTime.now(),
        ),
      );
    }

    // Cash
    final cashSolde = _parseMontant(_cashController.text);
    if (cashSolde > 0) {
      comptes.add(
        Compte(
          nom: 'Espèces',
          type: 'cash',
          soldeDepartCentimes: cashSolde,
          dateDebut: DateTime.now(),
        ),
      );
    }

    // Comptes supplémentaires
    for (final c in _comptesSupplementaires) {
      final montant = _parseMontant(
        (c['controller'] as TextEditingController).text,
      );
      if (montant > 0) {
        comptes.add(
          Compte(
            nom: c['nom'] as String,
            type: c['type'] as String,
            soldeDepartCentimes: montant,
            dateDebut: DateTime.now(),
          ),
        );
      }
    }

    // Vérifier qu'au moins 1 compte est créé
    if (comptes.isEmpty) {
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute au moins un compte avec un solde'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Enregistrer tous les comptes
    for (final c in comptes) {
      await _db.insertCompte(c);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CreerProfilScreen()),
    );
  }

  int _parseMontant(String texte) {
    if (texte.trim().isEmpty) return 0;
    final nettoye = texte.replaceAll(' ', '').replaceAll(',', '.');
    final valeur = double.tryParse(nettoye) ?? 0;
    return (valeur * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF191C1E),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Configurer vos portefeuilles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003178),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sous-titre
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Indiquez le solde actuel de chaque compte pour un suivi exact.',
                style: TextStyle(fontSize: 13, color: Color(0xFF737783)),
              ),
            ),

            const SizedBox(height: 16),

            // Liste des comptes
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCarteCompte(
                    label: 'Wave',
                    sousTitre: 'Mobile Money',
                    controller: _waveController,
                    couleur: const Color(0xFF1E88E5),
                    icone: Icons.waves,
                  ),
                  const SizedBox(height: 12),
                  _buildCarteCompte(
                    label: 'Orange Money',
                    sousTitre: 'Mobile Money',
                    controller: _omController,
                    couleur: const Color(0xFFFF6F00),
                    icone: Icons.swap_horiz,
                  ),
                  const SizedBox(height: 12),
                  _buildCarteCompte(
                    label: 'Espèces',
                    sousTitre: 'Cash',
                    controller: _cashController,
                    couleur: const Color(0xFF43A047),
                    icone: Icons.payments,
                  ),

                  // Comptes supplémentaires
                  ..._comptesSupplementaires.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildCarteCompte(
                        label: c['nom'] as String,
                        sousTitre: _labelPourType(c['type'] as String),
                        controller: c['controller'] as TextEditingController,
                        couleur: _couleurPourType(c['type'] as String),
                        icone: _iconePourType(c['type'] as String),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 16),

                  // Bouton ajouter
                  OutlinedButton.icon(
                    onPressed: _ajouterCompteSupplementaire,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter un autre compte'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003178),
                      side: const BorderSide(color: Color(0xFF003178)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF0D47A1),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vous pourrez ajuster ces montants '
                            'à tout moment dans les paramètres.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bouton "Valider" fixe en bas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _enregistrement ? null : _valider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003178),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _enregistrement
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Valider mes soldes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarteCompte({
    required String label,
    required String sousTitre,
    required TextEditingController controller,
    required Color couleur,
    required IconData icone,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: couleur, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  Text(
                    sousTitre,
                    style: TextStyle(fontSize: 12, color: couleur),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1E),
            ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'FCFA',
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _couleurPourType(String type) {
    switch (type) {
      case 'wave':
        return const Color(0xFF1E88E5);
      case 'orange_money':
        return const Color(0xFFFF6F00);
      case 'cash':
        return const Color(0xFF43A047);
      case 'banque':
        return const Color(0xFF5E35B1);
      default:
        return Colors.grey;
    }
  }

  IconData _iconePourType(String type) {
    switch (type) {
      case 'wave':
        return Icons.waves;
      case 'orange_money':
        return Icons.swap_horiz;
      case 'cash':
        return Icons.payments;
      case 'banque':
        return Icons.account_balance;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _labelPourType(String type) {
    switch (type) {
      case 'wave':
        return 'Wave';
      case 'orange_money':
        return 'Orange Money';
      case 'cash':
        return 'Espèces';
      case 'banque':
        return 'Banque';
      default:
        return type;
    }
  }
}
