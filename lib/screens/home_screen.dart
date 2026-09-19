import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../data/secure_store.dart';
import '../models/categorie.dart';
import '../models/compte.dart';
import '../models/operation.dart';
import '../services/detection_service.dart';
import '../widgets/solde_compte.dart';
import 'ajouter_operation_screen.dart';
import 'budget_screen.dart';
import 'comptes_screen.dart';
import 'historique_screen.dart';
import 'profil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<Compte> _comptes = [];
  List<Operation> _dernieresOperations = [];
  Map<int, Compte> _comptesMap = {};
  Map<int, Categorie> _categoriesMap = {};

  bool _chargement = true;
  bool _soldeMasque = false;
  int _soldeTotalCentimes = 0;
  int _depensesMois = 0;
  int _revenusMois = 0;
  int _resteAVivreParJour = 0;
  int _montantDisponible = 0;
  int _joursRestants = 0;
  String _prenom = 'Gana';

  StreamSubscription<Operation>? _subDetection;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
    _ecouterDetection();
  }

  @override
  void dispose() {
    _subDetection?.cancel();
    super.dispose();
  }

  void _ecouterDetection() {
    _subDetection = DetectionService.instance.operationAjoutee.listen((op) {
      if (!mounted) return;
      _chargerDonnees();
      final signe = op.type == 'depense' ? '-' : '+';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Détecté : $signe${_formatFCFA(op.montantCentimes)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF003178),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);

    final comptes = await _db.getComptes(actifsSeulement: true);
    final total = await _db.getSoldeTotalActif();
    final operations = await _db.getDernieresOperations(limite: 5);
    final tousComptes = await _db.getComptes();
    final categories = await _db.getCategories();
    final totauxMois = await _db.getTotauxMoisCourant();
    final resteAVivre = await _db.getResteAVivre();
    final prenom = await SecureStore.getNom();

    if (!mounted) return;

    setState(() {
      _comptes = comptes;
      _soldeTotalCentimes = total;
      _dernieresOperations = operations;
      _comptesMap = {for (final c in tousComptes) c.id!: c};
      _categoriesMap = {for (final c in categories) c.id!: c};
      _depensesMois = totauxMois['depensesCentimes'] ?? 0;
      _revenusMois = totauxMois['revenusCentimes'] ?? 0;
      _resteAVivreParJour = resteAVivre['resteParJourCentimes'] ?? 0;
      _montantDisponible = resteAVivre['montantDisponibleCentimes'] ?? 0;
      _joursRestants = resteAVivre['joursRestants'] ?? 0;
      _prenom = prenom;
      _chargement = false;
    });
  }

  Future<void> _ouvrirGestionComptes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ComptesScreen()),
    );
    _chargerDonnees();
  }

  Future<void> _ouvrirAjouterOperation(String type) async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AjouterOperationScreen(typeInitial: type),
      ),
    );
    if (resultat == true) {
      _chargerDonnees();
    }
  }

  Future<void> _ouvrirHistorique() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoriqueScreen()),
    );
    _chargerDonnees();
  }

  Future<void> _ouvrirBudget() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetScreen()),
    );
    _chargerDonnees();
  }

  Future<void> _ouvrirProfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilScreen()),
    );
    _chargerDonnees();
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

  String _formatDateCourte(DateTime date) {
    final maintenant = DateTime.now();
    if (maintenant.day == date.day &&
        maintenant.month == date.month &&
        maintenant.year == date.year) {
      return DateFormat('HH:mm', 'fr_FR').format(date);
    }
    final hier = maintenant.subtract(const Duration(days: 1));
    if (hier.day == date.day &&
        hier.month == date.month &&
        hier.year == date.year) {
      return 'Hier';
    }
    return DateFormat('d MMM', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header fixe
                  _buildHeaderFixe(),
                  // Contenu scrollable
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _chargerDonnees,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _buildCarteSoldeTotal(),
                          const SizedBox(height: 12),
                          _buildCarteResteAVivre(),
                          const SizedBox(height: 12),
                          _buildMiniKpis(),
                          const SizedBox(height: 16),
                          _buildBoutonsAction(),
                          const SizedBox(height: 24),
                          _buildTitrePortefeuilles(),
                          const SizedBox(height: 12),
                          _buildListePortefeuilles(),
                          const SizedBox(height: 24),
                          _buildTitreOperations(),
                          const SizedBox(height: 12),
                          _buildListeOperations(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------- HEADER FIXE ----------
  Widget _buildHeaderFixe() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'MES DÉPENSES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Bouton rafraîchir
              GestureDetector(
                onTap: _chargerDonnees,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xFF434652),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Avatar cliquable → Profil
              GestureDetector(
                onTap: _ouvrirProfil,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _prenom.isNotEmpty ? _prenom[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- CARTE SOLDE TOTAL ----------
  Widget _buildCarteSoldeTotal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003178), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003178).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFB0C6FF),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SOLDE TOTAL DISPONIBLE',
                    style: TextStyle(
                      color: Color(0xFFB0C6FF),
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _soldeMasque = !_soldeMasque);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _soldeMasque ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _soldeMasque
                    ? '••••••'
                    : _formatFCFA(_soldeTotalCentimes, avecDevise: false),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'FCFA',
                style: TextStyle(
                  color: Color(0xFFB0C6FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: Color(0xFFB0C6FF),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${_comptes.length} portefeuille(s) actif(s) • 100% hors-ligne',
                style: const TextStyle(color: Color(0xFFB0C6FF), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compteurs du mois
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8A80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Dépenses',
                        style: TextStyle(
                          color: Color(0xFFB0C6FF),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _soldeMasque
                              ? '••••'
                              : _formatFCFA(_depensesMois, avecDevise: false),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  color: Colors.white.withOpacity(0.15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF69F0AE),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Revenus',
                        style: TextStyle(
                          color: Color(0xFFB0C6FF),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _soldeMasque
                              ? '••••'
                              : _formatFCFA(_revenusMois, avecDevise: false),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- CARTE RESTE À VIVRE ----------
  Widget _buildCarteResteAVivre() {
    final negatif = _resteAVivreParJour <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: negatif ? const Color(0xFFFFDAD6) : const Color(0xFFB0C6FF),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: negatif
                  ? const Color(0xFFFFDAD6)
                  : const Color(0xFFD9E2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              negatif ? Icons.warning_amber : Icons.trending_up,
              color: negatif
                  ? const Color(0xFFBA1A1A)
                  : const Color(0xFF003178),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reste à vivre / jour',
                  style: TextStyle(fontSize: 12, color: Color(0xFF737783)),
                ),
                const SizedBox(height: 2),
                Text(
                  _soldeMasque ? '••••••' : _formatFCFA(_resteAVivreParJour),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: negatif
                        ? const Color(0xFFBA1A1A)
                        : const Color(0xFF003178),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  negatif
                      ? 'Manque : ${_formatFCFA(_montantDisponible.abs())}'
                      : '$_joursRestants jour${_joursRestants > 1 ? 's' : ''} restant${_joursRestants > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF737783),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _ouvrirBudget,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF003178),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Text(
                    'Gérer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpis() {
    final netDuMois = _revenusMois - _depensesMois;
    final estNetPositif = netDuMois >= 0;

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            label: 'Net du mois',
            valeur: _soldeMasque ? '••••' : _formatFCFA(netDuMois),
            couleur: estNetPositif
                ? const Color(0xFF007328)
                : const Color(0xFFBA1A1A),
            fond: estNetPositif
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFDAD6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            label: 'Budget restant',
            valeur: _soldeMasque ? '••••' : _formatFCFA(_montantDisponible),
            couleur: const Color(0xFF003178),
            fond: const Color(0xFFEAF2FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            label: 'Jours restants',
            valeur: '$_joursRestants',
            couleur: const Color(0xFF434652),
            fond: const Color(0xFFF1F3F6),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String valeur,
    required Color couleur,
    required Color fond,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF737783)),
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------- BOUTONS DÉPENSE / REVENU ----------
  Widget _buildBoutonsAction() {
    return Row(
      children: [
        Expanded(
          child: _buildBoutonAction(
            icon: Icons.remove,
            label: 'Dépense',
            couleurFond: const Color(0xFFFFDAD6),
            couleurIcone: const Color(0xFFBA1A1A),
            onTap: () => _ouvrirAjouterOperation('depense'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBoutonAction(
            icon: Icons.add,
            label: 'Revenu',
            couleurFond: const Color(0xFF64FD7D),
            couleurIcone: const Color(0xFF007328),
            onTap: () => _ouvrirAjouterOperation('revenu'),
          ),
        ),
      ],
    );
  }

  Widget _buildBoutonAction({
    required IconData icon,
    required String label,
    required Color couleurFond,
    required Color couleurIcone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleurFond,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: couleurIcone, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- TITRE PORTEFEUILLES ----------
  Widget _buildTitrePortefeuilles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Mes Portefeuilles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFECEEF1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${_comptes.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF434652),
                  ),
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _ouvrirGestionComptes,
          child: Row(
            children: const [
              Text(
                'Gérer',
                style: TextStyle(
                  color: Color(0xFF003178),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF003178), size: 18),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- LISTE PORTEFEUILLES ----------
  Widget _buildListePortefeuilles() {
    if (_comptes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFC3C6D4),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun portefeuille',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF434652),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajoute ton premier compte pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737783), fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _ouvrirGestionComptes,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un compte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003178),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _comptes.length,
        itemBuilder: (context, index) {
          return _buildCarteCompte(_comptes[index]);
        },
      ),
    );
  }

  Widget _buildCarteCompte(Compte compte) {
    final couleur = _couleurPourType(compte.type);
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconePourType(compte.type),
                  size: 18,
                  color: couleur,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _labelPourType(compte.type),
                  style: TextStyle(
                    fontSize: 10,
                    color: couleur,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Solde actuel',
            style: TextStyle(fontSize: 11, color: Color(0xFF737783)),
          ),
          const SizedBox(height: 2),
          _soldeMasque
              ? const Text(
                  '••••••',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1E),
                  ),
                )
              : SoldeCompte(
                  compteId: compte.id!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1E),
                  ),
                ),
        ],
      ),
    );
  }

  // ---------- TITRE OPÉRATIONS ----------
  Widget _buildTitreOperations() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Dernières opérations',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191C1E),
          ),
        ),
        GestureDetector(
          onTap: _ouvrirHistorique,
          child: const Text(
            'Voir tout',
            style: TextStyle(
              color: Color(0xFF003178),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- LISTE OPÉRATIONS ----------
  Widget _buildListeOperations() {
    if (_dernieresOperations.isEmpty) {
      return _buildMessageOperationsVide();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _dernieresOperations.length; i++) ...[
            _buildOperationTile(_dernieresOperations[i]),
            if (i < _dernieresOperations.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: Color(0xFFF2F4F7),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationTile(Operation op) {
    final compte = _comptesMap[op.compteId];
    final categorie = op.categorieId != null
        ? _categoriesMap[op.categorieId]
        : null;
    final estDepense = op.type == 'depense';

    final couleurMontant = estDepense
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF007328);
    final couleurIcone = categorie != null
        ? _hexToColor(categorie.couleur)
        : const Color(0xFF737783);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: couleurIcone.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              categorie != null
                  ? _iconeDepuisNom(categorie.icone)
                  : Icons.receipt_long,
              color: couleurIcone,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        categorie?.nom ?? (estDepense ? 'Dépense' : 'Revenu'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (op.origine == 'notification' ||
                        op.origine == 'sms') ...[
                      const SizedBox(width: 6),
                      _buildBadge(
                        'Auto',
                        const Color(0xFFD9E2FF),
                        const Color(0xFF003178),
                      ),
                    ],
                    if (op.origine == 'collee') ...[
                      const SizedBox(width: 6),
                      _buildBadge(
                        'Collé',
                        const Color(0xFFE8F5E9),
                        const Color(0xFF2E7D32),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${compte?.nom ?? '—'} • ${_formatDateCourte(op.date)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737783),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _soldeMasque
                ? '••••'
                : '${estDepense ? '-' : '+'}${_formatFCFA(op.montantCentimes)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: couleurMontant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color fond, Color texte) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 9, color: texte),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: texte,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- MESSAGE VIDE OPÉRATIONS ----------
  Widget _buildMessageOperationsVide() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFFC3C6D4), size: 40),
            SizedBox(height: 12),
            Text(
              'Aucune opération pour le moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF434652),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Appuie sur Dépense ou Revenu pour commencer',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737783), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- HELPERS ----------
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
        return 'Orange';
      case 'cash':
        return 'Cash';
      case 'banque':
        return 'Banque';
      default:
        return type;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  IconData _iconeDepuisNom(String nom) {
    switch (nom) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'receipt':
        return Icons.receipt;
      case 'home':
        return Icons.home;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'school':
        return Icons.school;
      case 'send':
        return Icons.send;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'build':
        return Icons.build;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'help_outline':
        return Icons.help_outline;
      case 'work':
        return Icons.work;
      case 'storefront':
        return Icons.storefront;
      case 'call_received':
        return Icons.call_received;
      default:
        return Icons.category;
    }
  }
}
