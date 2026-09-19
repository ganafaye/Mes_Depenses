import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../models/categorie.dart';
import '../models/compte.dart';
import '../models/operation.dart';
import 'ajouter_operation_screen.dart';
import 'assistant_sms_screen.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  final _db = DatabaseService();

  List<Operation> _operations = [];
  List<_SectionHistorique> _sections = [];
  Map<int, Compte> _comptesMap = {};
  Map<int, Categorie> _categoriesMap = {};

  String _filtreType = 'tous'; // 'tous', 'depense', 'revenu'
  int? _filtreCompteId;
  int? _filtreCategorieId;
  final TextEditingController _searchController = TextEditingController();
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);

    final operations = await _db.getOperations(
      type: _filtreType == 'tous' ? null : _filtreType,
    );
    final comptes = await _db.getComptes();
    final categories = await _db.getCategories();

    final comptesMap = {for (final c in comptes) c.id!: c};
    final categoriesMap = {for (final c in categories) c.id!: c};

    final operationsFiltrees = operations.where((op) {
      final matchCompte =
          _filtreCompteId == null || op.compteId == _filtreCompteId;
      final matchCategorie =
          _filtreCategorieId == null || op.categorieId == _filtreCategorieId;
      final termeRecherche = _searchController.text.trim().toLowerCase();
      final matchRecherche =
          termeRecherche.isEmpty ||
          (op.note != null &&
              op.note!.toLowerCase().contains(termeRecherche)) ||
          (categoriesMap[op.categorieId]?.nom.toLowerCase().contains(
                termeRecherche,
              ) ??
              false) ||
          (comptesMap[op.compteId]?.nom.toLowerCase().contains(
                termeRecherche,
              ) ??
              false);

      return matchCompte && matchCategorie && matchRecherche;
    }).toList();

    final operationsTriees = List<Operation>.from(operationsFiltrees)
      ..sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _operations = operationsTriees;
      _comptesMap = comptesMap;
      _categoriesMap = categoriesMap;
      _sections = _grouperParDate(operationsTriees);
      _chargement = false;
    });
  }

  // ---------- MODIFICATION (remplace la suppression) ----------
  Future<void> _modifierOperation(Operation op) async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AjouterOperationScreen(operationAModifier: op),
      ),
    );
    if (resultat == true) {
      _chargerDonnees();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opération modifiée')));
      }
    }
  }

  // ---------- ASSISTANT SMS ----------
  Future<void> _ouvrirAssistantSms() async {
    final resultat = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssistantSmsScreen()),
    );
    if (resultat == true) {
      _chargerDonnees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opération ajoutée depuis le SMS collé'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
      }
    }
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

  String _formatDate(DateTime date) {
    final maintenant = DateTime.now();
    final diff = maintenant.difference(date);

    if (diff.inDays == 0 &&
        maintenant.day == date.day &&
        maintenant.month == date.month &&
        maintenant.year == date.year) {
      return "Aujourd'hui • ${DateFormat('HH:mm', 'fr_FR').format(date)}";
    }
    if (diff.inDays == 1 ||
        (maintenant.subtract(const Duration(days: 1)).day == date.day &&
            maintenant.subtract(const Duration(days: 1)).month == date.month &&
            maintenant.subtract(const Duration(days: 1)).year == date.year)) {
      return 'Hier • ${DateFormat('HH:mm', 'fr_FR').format(date)}';
    }
    return DateFormat('d MMM yyyy • HH:mm', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final totalDepensesMois = _operations
        .where(
          (op) =>
              op.type == 'depense' &&
              op.date.year == DateTime.now().year &&
              op.date.month == DateTime.now().month,
        )
        .fold<int>(0, (sum, op) => sum + op.montantCentimes);

    final totalRevenusMois = _operations
        .where(
          (op) =>
              op.type == 'revenu' &&
              op.date.year == DateTime.now().year &&
              op.date.month == DateTime.now().month,
        )
        .fold<int>(0, (sum, op) => sum + op.montantCentimes);

    final soldeMois = totalRevenusMois - totalDepensesMois;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Historique',
          style: TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste, color: Color(0xFF003178)),
            tooltip: 'Coller un SMS',
            onPressed: _ouvrirAssistantSms,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildBarreRecherche(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildFiltres(),
          ),
          if (!_chargement && _operations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildResumeMois(
                totalDepensesMois,
                totalRevenusMois,
                soldeMois,
              ),
            ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _operations.isEmpty
                ? _buildVide()
                : RefreshIndicator(
                    onRefresh: _chargerDonnees,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: _sections
                          .map((section) => _buildSectionHistorique(section))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarreRecherche() {
    final activeFilters =
        _filtreCompteId != null ||
        _filtreCategorieId != null ||
        _searchController.text.trim().isNotEmpty ||
        _filtreType != 'tous';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF737783), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _chargerDonnees(),
              decoration: const InputDecoration(
                hintText: 'Recherche rapide',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(color: Color(0xFF9AA3AF), fontSize: 13),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _chargerDonnees();
              },
              child: const Icon(
                Icons.close,
                color: Color(0xFF737783),
                size: 18,
              ),
            ),
          if (activeFilters)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _filtreType = 'tous';
                    _filtreCompteId = null;
                    _filtreCategorieId = null;
                    _searchController.clear();
                  });
                  _chargerDonnees();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003178).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003178),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltres() {
    final comptes = _comptesMap.values.toList();
    final categories = _categoriesMap.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip('Tous', 'tous'),
              const SizedBox(width: 8),
              _buildChip('Dépenses', 'depense'),
              const SizedBox(width: 8),
              _buildChip('Revenus', 'revenu'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMenuCompte(comptes),
              const SizedBox(width: 8),
              _buildMenuCategorie(categories),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCompte(List<Compte> comptes) {
    final actif = _filtreCompteId != null;
    return PopupMenuButton<int>(
      initialValue: _filtreCompteId,
      tooltip: 'Filtrer par compte',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: actif ? const Color(0xFFB9D2FF) : const Color(0xFFE0E3E6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 16,
              color: actif ? const Color(0xFF003178) : const Color(0xFF434652),
            ),
            const SizedBox(width: 6),
            Text(
              _filtreCompteId == null
                  ? 'Compte'
                  : (_comptesMap[_filtreCompteId]?.nom ?? 'Compte'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: actif ? FontWeight.w700 : FontWeight.w600,
                color: actif
                    ? const Color(0xFF003178)
                    : const Color(0xFF434652),
              ),
            ),
          ],
        ),
      ),
      onSelected: (value) {
        setState(() => _filtreCompteId = value == -1 ? null : value);
        _chargerDonnees();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<int>(value: -1, child: Text('Tous les comptes')),
        ...comptes.map(
          (compte) =>
              PopupMenuItem<int>(value: compte.id!, child: Text(compte.nom)),
        ),
      ],
    );
  }

  Widget _buildMenuCategorie(List<Categorie> categories) {
    final actif = _filtreCategorieId != null;
    return PopupMenuButton<int>(
      initialValue: _filtreCategorieId,
      tooltip: 'Filtrer par catégorie',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: actif ? const Color(0xFFB9D2FF) : const Color(0xFFE0E3E6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category,
              size: 16,
              color: actif ? const Color(0xFF003178) : const Color(0xFF434652),
            ),
            const SizedBox(width: 6),
            Text(
              _filtreCategorieId == null
                  ? 'Catégorie'
                  : (_categoriesMap[_filtreCategorieId]?.nom ?? 'Catégorie'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: actif ? FontWeight.w700 : FontWeight.w600,
                color: actif
                    ? const Color(0xFF003178)
                    : const Color(0xFF434652),
              ),
            ),
          ],
        ),
      ),
      onSelected: (value) {
        setState(() => _filtreCategorieId = value == -1 ? null : value);
        _chargerDonnees();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          value: -1,
          child: Text('Toutes les catégories'),
        ),
        ...categories.map(
          (categorie) => PopupMenuItem<int>(
            value: categorie.id!,
            child: Text(categorie.nom),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, String valeur) {
    final selectionne = _filtreType == valeur;
    return GestureDetector(
      onTap: () {
        if (_filtreType != valeur) {
          setState(() => _filtreType = valeur);
          _chargerDonnees();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? const Color(0xFF003178) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectionne
                ? const Color(0xFF003178)
                : const Color(0xFFE0E3E6),
          ),
          boxShadow: selectionne
              ? [
                  BoxShadow(
                    color: const Color(0xFF003178).withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selectionne ? Colors.white : const Color(0xFF434652),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeMois(int totalDepenses, int totalRevenus, int solde) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Résumé du mois',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatResume(
                  'Dépenses',
                  _formatFCFA(totalDepenses),
                  const Color(0xFFBA1A1A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatResume(
                  'Revenus',
                  _formatFCFA(totalRevenus),
                  const Color(0xFF007328),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMiniStatResume(
            'Solde net',
            _formatFCFA(solde),
            solde >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFBA1A1A),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatResume(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF737783),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHistorique(_SectionHistorique section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              section.titre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF434652),
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...section.operations.map((op) => _buildOperationTile(op)),
        ],
      ),
    );
  }

  List<_SectionHistorique> _grouperParDate(List<Operation> operations) {
    final Map<String, List<Operation>> parDate = {};

    for (final op in operations) {
      final cle = DateFormat('yyyy-MM-dd').format(op.date);
      parDate.putIfAbsent(cle, () => []);
      parDate[cle]!.add(op);
    }

    final sections = parDate.entries.map((entry) {
      final date = DateTime.parse('${entry.key}T00:00:00');
      return _SectionHistorique(
        titre: _titreSectionDate(date),
        operations: entry.value,
      );
    }).toList();

    sections.sort((a, b) => _datePourSection(b).compareTo(_datePourSection(a)));

    return sections;
  }

  DateTime _datePourSection(_SectionHistorique section) {
    final now = DateTime.now();
    final jours = section.titre.split(' • ');
    if (jours.isEmpty) return now;
    final libelle = jours[0];
    if (libelle == 'Aujourd\'hui') return now;
    if (libelle == 'Hier') return now.subtract(const Duration(days: 1));
    try {
      final date = DateFormat('d MMMM yyyy', 'fr_FR').parse(libelle);
      return date;
    } catch (_) {}
    return now;
  }

  String _titreSectionDate(DateTime date) {
    final now = DateTime.now();
    final dateDuJour = DateTime(now.year, now.month, now.day);
    final dateSection = DateTime(date.year, date.month, date.day);
    final difference = dateDuJour.difference(dateSection).inDays;

    if (difference == 0) {
      return "Aujourd'hui";
    }
    if (difference == 1) {
      return 'Hier';
    }
    return DateFormat('d MMMM yyyy', 'fr_FR').format(dateSection);
  }

  Widget _buildVide() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, color: Color(0xFFC3C6D4), size: 64),
            SizedBox(height: 16),
            Text(
              'Aucune opération',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF434652),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ajoute ta première dépense ou revenu\ndepuis l\'accueil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737783), fontSize: 13),
            ),
          ],
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _afficherDetail(op),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: couleurIcone.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categorie != null
                      ? _iconeDepuisNom(categorie.icone)
                      : Icons.receipt_long,
                  color: couleurIcone,
                  size: 22,
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
                            categorie?.nom ??
                                (estDepense ? 'Dépense' : 'Revenu'),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9E2FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 9,
                                  color: Color(0xFF003178),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Auto',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF003178),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (op.origine == 'collee') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.content_paste,
                                  size: 9,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Collé',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${compte?.nom ?? 'Compte inconnu'} • ${_formatDate(op.date)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF737783),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (op.note != null && op.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        op.note!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF737783),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${estDepense ? '-' : '+'}${_formatFCFA(op.montantCentimes)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: couleurMontant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _afficherDetail(Operation op) {
    final compte = _comptesMap[op.compteId];
    final categorie = op.categorieId != null
        ? _categoriesMap[op.categorieId]
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E3E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              op.type == 'depense' ? 'Dépense' : 'Revenu',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF737783),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatFCFA(op.montantCentimes),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: op.type == 'depense'
                    ? const Color(0xFFBA1A1A)
                    : const Color(0xFF007328),
              ),
            ),
            const SizedBox(height: 20),
            _buildLigneDetail('Catégorie', categorie?.nom ?? '—'),
            _buildLigneDetail('Compte', compte?.nom ?? '—'),
            _buildLigneDetail(
              'Date',
              DateFormat('EEEE d MMMM yyyy • HH:mm', 'fr_FR').format(op.date),
            ),
            _buildLigneDetail('Origine', _labelOrigine(op.origine)),
            if (op.note != null && op.note!.isNotEmpty)
              _buildLigneDetail('Note', op.note!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _modifierOperation(op);
                },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text(
                  'Modifier',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003178),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigneDetail(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF737783)),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF191C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelOrigine(String origine) {
    switch (origine) {
      case 'manuelle':
        return 'Saisie manuelle';
      case 'sms':
        return 'Depuis SMS';
      case 'notification':
        return 'Depuis notification';
      case 'collee':
        return 'Message collé';
      default:
        return origine;
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

class _SectionHistorique {
  final String titre;
  final List<Operation> operations;

  const _SectionHistorique({required this.titre, required this.operations});
}
