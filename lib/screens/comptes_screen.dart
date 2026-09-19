import 'package:flutter/material.dart';
import '../data/database.dart';
import '../models/compte.dart';
import '../widgets/solde_compte.dart';
import 'ajouter_compte_screen.dart';

class ComptesScreen extends StatefulWidget {
  const ComptesScreen({super.key});

  @override
  State<ComptesScreen> createState() => _ComptesScreenState();
}

class _ComptesScreenState extends State<ComptesScreen> {
  final _db = DatabaseService();
  List<Compte> _comptes = [];
  bool _chargement = true;
  int _soldeTotalCentimes = 0;
  String _filtreStatut = 'tous';

  List<Compte> get _comptesAffiches {
    final comptes = List<Compte>.from(_comptes);
    switch (_filtreStatut) {
      case 'actifs':
        comptes.removeWhere((c) => !c.actif);
        break;
      case 'archives':
        comptes.removeWhere((c) => c.actif);
        break;
      default:
        break;
    }
    comptes.sort(
      (a, b) => b.soldeDepartCentimes.compareTo(a.soldeDepartCentimes),
    );
    return comptes;
  }

  @override
  void initState() {
    super.initState();
    _chargerComptes();
  }

  Future<void> _chargerComptes() async {
    setState(() => _chargement = true);
    final comptes = await _db.getComptes();
    final total = await _db.getSoldeTotalActif();
    setState(() {
      _comptes = comptes;
      _soldeTotalCentimes = total;
      _chargement = false;
    });
  }

  Future<void> _ouvrirAjouterCompte() async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AjouterCompteScreen()),
    );
    if (resultat == true) _chargerComptes();
  }

  Future<void> _supprimerCompte(Compte compte) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          'Le compte "${compte.nom}" sera définitivement supprimé.\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await _db.deleteCompte(compte.id!);
      _chargerComptes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compte "${compte.nom}" supprimé')),
        );
      }
    }
  }

  Future<void> _modifierCompte(Compte compte) async {
    final nouveauNom = await _dialogueRenommer(compte);
    if (nouveauNom != null && nouveauNom != compte.nom) {
      await _db.updateCompte(compte.copyWith(nom: nouveauNom));
      _chargerComptes();
    }
  }

  Future<String?> _dialogueRenommer(Compte compte) async {
    final controller = TextEditingController(text: compte.nom);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le compte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nouveau nom',
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
  }

  String _formatFCFA(int centimes) {
    final negatif = centimes < 0;
    final fcfa = (centimes.abs() / 100).toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < fcfa.length; i++) {
      if (i > 0 && (fcfa.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(fcfa[i]);
    }
    final signe = negatif ? '-' : '';
    return '$signe${buffer.toString()} FCFA';
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
          'Mes comptes',
          style: TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF003178)),
            onPressed: _ouvrirAjouterCompte,
            tooltip: 'Ajouter un compte',
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerComptes,
              child: _comptes.isEmpty
                  ? _buildVide()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildResume(),
                        const SizedBox(height: 16),
                        _buildFiltres(),
                        const SizedBox(height: 12),
                        ..._comptesAffiches.map((c) => _buildCarteCompte(c)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildFiltres() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltre('tous', 'Tous'),
                  const SizedBox(width: 8),
                  _buildFiltre('actifs', 'Actifs'),
                  const SizedBox(width: 8),
                  _buildFiltre('archives', 'Archivés'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.sort, size: 15, color: Color(0xFF434652)),
                SizedBox(width: 4),
                Text(
                  'Solde',
                  style: TextStyle(
                    color: Color(0xFF434652),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltre(String valeur, String label) {
    final actif = _filtreStatut == valeur;
    return GestureDetector(
      onTap: () => setState(() => _filtreStatut = valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFF003178) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actif ? const Color(0xFF003178) : const Color(0xFFE6EBF2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: actif ? Colors.white : const Color(0xFF434652),
          ),
        ),
      ),
    );
  }

  Widget _buildVide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Color(0xFFC3C6D4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun compte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF434652),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoute ton premier compte\npour commencer à suivre tes dépenses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737783), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _ouvrirAjouterCompte,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un compte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003178),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResume() {
    final nbActifs = _comptes.where((c) => c.actif).length;
    final nbArchives = _comptes.where((c) => !c.actif).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003178), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003178).withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Color(0xFFB0C6FF),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'TOTAL DES COMPTES',
                style: TextStyle(
                  color: Color(0xFFB0C6FF),
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatFCFA(_soldeTotalCentimes),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniBadge(
                  '$nbActifs actif${nbActifs > 1 ? 's' : ''}',
                  const Color(0xFF64FD7D),
                  const Color(0xFF007328),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniBadge(
                  '$nbArchives archivé${nbArchives > 1 ? 's' : ''}',
                  const Color(0xFFE5E7EB),
                  const Color(0xFF434652),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color fond, Color texte) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: texte,
          ),
        ),
      ),
    );
  }

  Widget _buildCarteCompte(Compte compte) {
    final couleur = _couleurPourType(compte.type);
    final estActif = compte.actif;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estActif ? const Color(0xFFE6EBF2) : const Color(0xFFF0F2F5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconePourType(compte.type), color: couleur, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        compte.nom,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!estActif) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6EBF2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Archivé',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF434652),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: couleur,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _labelPourType(compte.type),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: couleur,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SoldeCompte(
                  compteId: compte.id!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1E),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF434652)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            offset: const Offset(0, 12),
            onSelected: (valeur) {
              if (valeur == 'renommer') _modifierCompte(compte);
              if (valeur == 'supprimer') _supprimerCompte(compte);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'renommer',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Color(0xFF003178)),
                      SizedBox(width: 10),
                      Text(
                        'Renommer',
                        style: TextStyle(
                          color: Color(0xFF191C1E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'supprimer',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFBA1A1A)),
                      SizedBox(width: 10),
                      Text(
                        'Supprimer',
                        style: TextStyle(
                          color: Color(0xFFBA1A1A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
