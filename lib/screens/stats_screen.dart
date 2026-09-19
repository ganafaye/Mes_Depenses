import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../models/categorie.dart';
import '../models/operation.dart';
import '../services/detection_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _db = DatabaseService();

  List<Operation> _operationsMois = [];
  List<_RapportMensuel> _rapportsMensuels = [];
  Map<int, Categorie> _categoriesMap = {};
  bool _chargement = true;

  // Pour l'onglet Évolution
  String _periodeEvolution = 'jour'; // 'jour', 'semaine', 'mois'
  List<Operation> _operationsEvolution = [];
  bool _chargementEvolution = true;

  StreamSubscription<Operation>? _subDetection;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _ecouterDetection();
    _chargerDonnees();
    _chargerEvolution();
  }

  @override
  void dispose() {
    _subDetection?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _ecouterDetection() {
    _subDetection = DetectionService.instance.operationAjoutee.listen((op) {
      if (!mounted) return;
      _chargerDonnees();
      _chargerEvolution();
    });
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    final maintenant = DateTime.now();

    final operations = await _db.getOperations();
    final duMois = operations.where((op) {
      return op.date.year == maintenant.year &&
          op.date.month == maintenant.month;
    }).toList();

    final categories = await _db.getCategories();

    setState(() {
      _operationsMois = duMois;
      _categoriesMap = {for (final c in categories) c.id!: c};
      _rapportsMensuels = _calculerRapportsMensuels(operations);
      _chargement = false;
    });
  }

  Future<void> _chargerEvolution() async {
    setState(() => _chargementEvolution = true);

    final maintenant = DateTime.now();
    DateTime debut;

    if (_periodeEvolution == 'jour') {
      debut = maintenant.subtract(const Duration(days: 6));
    } else if (_periodeEvolution == 'semaine') {
      debut = maintenant.subtract(const Duration(days: 7 * 8 - 1));
    } else {
      debut = DateTime(maintenant.year, maintenant.month - 11, 1);
    }

    final operations = await _db.getOperationsEntreDates(
      DateTime(debut.year, debut.month, debut.day, 0, 0, 0),
      DateTime(maintenant.year, maintenant.month, maintenant.day, 23, 59, 59),
    );

    setState(() {
      _operationsEvolution = operations;
      _chargementEvolution = false;
    });
  }

  String get _nomMois {
    return DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOngletDepenses(),
                        _buildOngletRevenus(),
                        _buildOngletEvolution(),
                        _buildOngletRapports(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _nomMois,
            style: const TextStyle(fontSize: 13, color: Color(0xFF737783)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF003178),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF737783),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Dépenses', height: 36),
          Tab(text: 'Revenus', height: 36),
          Tab(text: 'Évolution', height: 36),
          Tab(text: 'Rapports', height: 36),
        ],
      ),
    );
  }

  // ---------- CALCULS STATS ----------
  List<MapEntry<Categorie, int>> _calculerStats(String type) {
    final Map<int, int> totaux = {};

    for (final op in _operationsMois) {
      if (op.type != type) continue;
      if (op.categorieId == null) continue;

      totaux[op.categorieId!] =
          (totaux[op.categorieId!] ?? 0) + op.montantCentimes;
    }

    final entrees = totaux.entries.map((e) {
      return MapEntry(_categoriesMap[e.key]!, e.value);
    }).toList();

    entrees.sort((a, b) => b.value.compareTo(a.value));
    return entrees;
  }

  int _totalPour(String type) {
    return _operationsMois
        .where((op) => op.type == type)
        .fold(0, (sum, op) => sum + op.montantCentimes);
  }

  // ---------- ONGLET DÉPENSES ----------
  Widget _buildOngletDepenses() {
    final stats = _calculerStats('depense');
    final total = _totalPour('depense');

    if (stats.isEmpty) {
      return _buildOngletVide('Aucune dépense ce mois-ci');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _buildCarteTotal('Total dépensé', total, const Color(0xFFBA1A1A)),
        const SizedBox(height: 20),
        _buildDonut(stats, total),
        const SizedBox(height: 24),
        _buildListeCategories(stats, total),
      ],
    );
  }

  // ---------- ONGLET REVENUS ----------
  Widget _buildOngletRevenus() {
    final stats = _calculerStats('revenu');
    final total = _totalPour('revenu');

    if (stats.isEmpty) {
      return _buildOngletVide('Aucun revenu ce mois-ci');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _buildCarteTotal('Total reçu', total, const Color(0xFF007328)),
        const SizedBox(height: 20),
        _buildDonut(stats, total),
        const SizedBox(height: 24),
        _buildListeCategories(stats, total),
      ],
    );
  }

  // ---------- ONGLET ÉVOLUTION ----------
  Widget _buildOngletEvolution() {
    return Column(
      children: [
        _buildSelecteurPeriode(),
        Expanded(
          child: _chargementEvolution
              ? const Center(child: CircularProgressIndicator())
              : _buildContenuEvolution(),
        ),
      ],
    );
  }

  Widget _buildSelecteurPeriode() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildBoutonPeriode('Jour', 'jour'),
          _buildBoutonPeriode('Semaine', 'semaine'),
          _buildBoutonPeriode('Mois', 'mois'),
        ],
      ),
    );
  }

  Widget _buildBoutonPeriode(String label, String valeur) {
    final selectionne = _periodeEvolution == valeur;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_periodeEvolution != valeur) {
            setState(() => _periodeEvolution = valeur);
            _chargerEvolution();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selectionne ? const Color(0xFF003178) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selectionne ? FontWeight.w600 : FontWeight.w500,
                color: selectionne ? Colors.white : const Color(0xFF737783),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContenuEvolution() {
    final depenses = _operationsEvolution
        .where((op) => op.type == 'depense')
        .toList();
    final revenus = _operationsEvolution
        .where((op) => op.type == 'revenu')
        .toList();

    if (depenses.isEmpty && revenus.isEmpty) {
      return _buildOngletVide('Aucune donnée sur cette période');
    }

    final donneesDepenses = _calculerDonneesEvolution(depenses);
    final donneesRevenus = _calculerDonneesEvolution(revenus);
    final labels = donneesDepenses.map((e) => e.key).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _buildGraphiqueEvolution(labels, donneesDepenses, donneesRevenus),
        const SizedBox(height: 24),
        _buildResumeEvolution(donneesDepenses, donneesRevenus),
      ],
    );
  }

  // ---------- CALCUL DES DONNÉES POUR LE GRAPHIQUE ----------

  /// Retourne une liste de MapEntry<String, int> :
  /// - label = "Lun", "S1", "Jan"...
  /// - valeur = total dépensé ou reçu en centimes
  List<MapEntry<String, int>> _calculerDonneesEvolution(
    List<Operation> operations,
  ) {
    final maintenant = DateTime.now();

    if (_periodeEvolution == 'jour') {
      final Map<String, int> totaux = {};
      final List<String> labels = [];
      final List<DateTime> dates = [];

      for (int i = 6; i >= 0; i--) {
        final jour = maintenant.subtract(Duration(days: i));
        final label = DateFormat('E', 'fr_FR').format(jour);
        final labelCapitalise = label.isNotEmpty
            ? '${label[0].toUpperCase()}${label.substring(1)}'
            : label;
        labels.add(labelCapitalise);
        dates.add(jour);
        totaux[labelCapitalise] = 0;
      }

      for (final op in operations) {
        for (int i = 0; i < dates.length; i++) {
          if (_estMemeJour(op.date, dates[i])) {
            totaux[labels[i]] = (totaux[labels[i]] ?? 0) + op.montantCentimes;
          }
        }
      }

      return labels.map((l) => MapEntry(l, totaux[l] ?? 0)).toList();
    } else if (_periodeEvolution == 'semaine') {
      final Map<String, int> totaux = {};
      final List<String> labels = [];
      final List<DateTime> debutsSemaines = [];

      for (int i = 7; i >= 0; i--) {
        final debutSemaine = _debutDeSemaine(
          maintenant.subtract(Duration(days: i * 7)),
        );
        final label = 'S${_numeroSemaine(debutSemaine)}';
        labels.add(label);
        debutsSemaines.add(debutSemaine);
        totaux[label] = 0;
      }

      for (final op in operations) {
        for (int i = 0; i < debutsSemaines.length; i++) {
          final finSemaine = debutsSemaines[i].add(
            const Duration(days: 6, hours: 23, minutes: 59),
          );
          final dansLaSemaine =
              (op.date.isAfter(debutsSemaines[i]) ||
                  _estMemeJour(op.date, debutsSemaines[i])) &&
              (op.date.isBefore(finSemaine) ||
                  _estMemeJour(op.date, finSemaine));
          if (dansLaSemaine) {
            totaux[labels[i]] = (totaux[labels[i]] ?? 0) + op.montantCentimes;
            break;
          }
        }
      }

      return labels.map((l) => MapEntry(l, totaux[l] ?? 0)).toList();
    } else {
      final Map<String, int> totaux = {};
      final List<String> labels = [];
      final List<DateTime> mois = [];

      for (int i = 11; i >= 0; i--) {
        final moisDate = DateTime(maintenant.year, maintenant.month - i, 1);
        final label = DateFormat('MMM', 'fr_FR').format(moisDate);
        final labelCapitalise = label.isNotEmpty
            ? '${label[0].toUpperCase()}${label.substring(1)}'
            : label;
        labels.add(labelCapitalise);
        mois.add(moisDate);
        totaux[labelCapitalise] = 0;
      }

      for (final op in operations) {
        for (int i = 0; i < mois.length; i++) {
          if (op.date.year == mois[i].year && op.date.month == mois[i].month) {
            totaux[labels[i]] = (totaux[labels[i]] ?? 0) + op.montantCentimes;
          }
        }
      }

      return labels.map((l) => MapEntry(l, totaux[l] ?? 0)).toList();
    }
  }

  bool _estMemeJour(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _debutDeSemaine(DateTime date) {
    // Lundi = 1, Dimanche = 7
    final jourSemaine = date.weekday;
    return DateTime(date.year, date.month, date.day - (jourSemaine - 1));
  }

  int _numeroSemaine(DateTime date) {
    // Numéro de semaine ISO (approximatif)
    final debutAnnee = DateTime(date.year, 1, 1);
    final diff = date.difference(debutAnnee).inDays;
    return (diff / 7).floor() + 1;
  }

  // ---------- GRAPHIQUE ÉVOLUTION ----------

  Widget _buildGraphiqueEvolution(
    List<String> labels,
    List<MapEntry<String, int>> donneesDepenses,
    List<MapEntry<String, int>> donneesRevenus,
  ) {
    final toutesValeurs = <double>[];
    for (final element in donneesDepenses) {
      toutesValeurs.add(element.value.toDouble());
    }
    for (final element in donneesRevenus) {
      toutesValeurs.add(element.value.toDouble());
    }

    final maxValue = toutesValeurs.isEmpty
        ? 0.0
        : toutesValeurs.reduce((a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return _buildOngletVide('Aucune donnée sur cette période');
    }

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
          Text(
            _titreEvolution(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Comparaison revenus / dépenses',
            style: TextStyle(fontSize: 12, color: Color(0xFF737783)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLegendeCouleur(const Color(0xFFBA1A1A), 'Dépenses'),
              const SizedBox(width: 16),
              _buildLegendeCouleur(const Color(0xFF007328), 'Revenus'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue / 100 * 1.2,
                minY: 0,
                groupsSpace: 12,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 100 / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFF2F4F7),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: maxValue / 100 / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        final fcfa = value.toInt();
                        String label;
                        if (fcfa >= 1000000) {
                          label = '${(fcfa / 1000000).toStringAsFixed(1)}M';
                        } else if (fcfa >= 1000) {
                          label = '${(fcfa / 1000).toStringAsFixed(0)}k';
                        } else {
                          label = fcfa.toString();
                        }
                        return Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF737783),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF737783),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: labels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final depense = donneesDepenses[index].value;
                  final revenu = donneesRevenus[index].value;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: depense / 100,
                        color: const Color(0xFFBA1A1A),
                        width: 8,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: revenu / 100,
                        color: const Color(0xFF007328),
                        width: 8,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titreEvolution() {
    switch (_periodeEvolution) {
      case 'jour':
        return '7 derniers jours';
      case 'semaine':
        return '8 dernières semaines';
      case 'mois':
        return '12 derniers mois';
      default:
        return 'Évolution';
    }
  }

  // ---------- RÉSUMÉ ÉVOLUTION ----------

  Widget _buildResumeEvolution(
    List<MapEntry<String, int>> donneesDepenses,
    List<MapEntry<String, int>> donneesRevenus,
  ) {
    final totalDepenses = donneesDepenses.fold<int>(
      0,
      (sum, e) => sum + e.value,
    );
    final totalRevenus = donneesRevenus.fold<int>(0, (sum, e) => sum + e.value);
    final soldeNet = totalRevenus - totalDepenses;

    final moyenneDepenses = donneesDepenses.isNotEmpty
        ? totalDepenses ~/ donneesDepenses.length
        : 0;

    final maxDepense = donneesDepenses.isNotEmpty
        ? donneesDepenses.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final maxRevenu = donneesRevenus.isNotEmpty
        ? donneesRevenus.reduce((a, b) => a.value > b.value ? a : b)
        : null;

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
          const Text(
            'Résumé',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 16),
          _buildLigneResume(
            'Dépenses',
            _formatFCFA(totalDepenses),
            const Color(0xFFBA1A1A),
          ),
          const SizedBox(height: 12),
          _buildLigneResume(
            'Revenus',
            _formatFCFA(totalRevenus),
            const Color(0xFF007328),
          ),
          const SizedBox(height: 12),
          _buildLigneResume(
            'Solde net',
            _formatFCFA(soldeNet),
            soldeNet >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFBA1A1A),
          ),
          const SizedBox(height: 12),
          _buildLigneResume(
            'Moyenne dépenses',
            _formatFCFA(moyenneDepenses),
            const Color(0xFF003178),
          ),
          if (maxDepense != null) ...[
            const SizedBox(height: 12),
            _buildLigneResume(
              'Pic dépenses',
              '${maxDepense.key} • ${_formatFCFA(maxDepense.value)}',
              const Color(0xFFE65100),
            ),
          ],
          if (maxRevenu != null) ...[
            const SizedBox(height: 12),
            _buildLigneResume(
              'Pic revenus',
              '${maxRevenu.key} • ${_formatFCFA(maxRevenu.value)}',
              const Color(0xFF2E7D32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLigneResume(String label, String valeur, Color couleur) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF737783)),
        ),
        Flexible(
          child: Text(
            valeur,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendeCouleur(Color couleur, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF434652),
          ),
        ),
      ],
    );
  }

  // ---------- CARTE TOTAL ----------
  Widget _buildCarteTotal(String label, int totalCentimes, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF737783),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatFCFA(totalCentimes),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- DONUT ----------
  Widget _buildDonut(List<MapEntry<Categorie, int>> stats, int totalCentimes) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              startDegreeOffset: -90,
              sections: stats.map((entree) {
                final pourcentage = totalCentimes > 0
                    ? (entree.value / totalCentimes) * 100
                    : 0.0;
                return PieChartSectionData(
                  value: entree.value.toDouble(),
                  color: _hexToColor(entree.key.couleur),
                  radius: 40,
                  title: pourcentage >= 8
                      ? '${pourcentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatFCFA(totalCentimes, avecDevise: false),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1E),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'FCFA',
                style: TextStyle(fontSize: 12, color: Color(0xFF737783)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- LISTE CATÉGORIES ----------
  Widget _buildListeCategories(
    List<MapEntry<Categorie, int>> stats,
    int totalCentimes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Répartition par catégorie',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191C1E),
          ),
        ),
        const SizedBox(height: 12),
        ...stats.map((entree) {
          final pourcentage = totalCentimes > 0
              ? (entree.value / totalCentimes)
              : 0.0;
          final couleur = _hexToColor(entree.key.couleur);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: couleur,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entree.key.nom,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pourcentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: couleur,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pourcentage,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF2F4F7),
                          valueColor: AlwaysStoppedAnimation<Color>(couleur),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatFCFA(entree.value),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ---------- ONGLET VIDE ----------
  Widget _buildOngletVide(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Color(0xFFC3C6D4)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF434652),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- RAPPORTS MENSUELS ----------
  Widget _buildOngletRapports() {
    if (_rapportsMensuels.isEmpty) {
      return _buildOngletVide('Aucun rapport mensuel disponible');
    }

    final moisCourant = _rapportsMensuels.first;
    final moisPrecedent = _rapportsMensuels.length > 1
        ? _rapportsMensuels[1]
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildDashboardKpis(moisCourant, moisPrecedent),
        const SizedBox(height: 20),
        if (moisPrecedent != null)
          _buildComparatifMois(moisCourant, moisPrecedent),
        const SizedBox(height: 20),
        ..._rapportsMensuels.map(
          (rapport) => _buildCarteRapportMensuel(rapport),
        ),
      ],
    );
  }

  Widget _buildDashboardKpis(
    _RapportMensuel moisCourant,
    _RapportMensuel? moisPrecedent,
  ) {
    final soldeNet = moisCourant.soldeNet;
    final variationMois = moisPrecedent != null
        ? soldeNet - moisPrecedent.soldeNet
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF003178),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003178).withOpacity(0.18),
            blurRadius: 10,
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
              const Text(
                'Performance du mois',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  moisCourant.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatDashboard(
                  'Dépenses',
                  _formatFCFA(moisCourant.totalDepenses),
                  const Color(0xFFFFDADA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatDashboard(
                  'Revenus',
                  _formatFCFA(moisCourant.totalRevenus),
                  const Color(0xFFD9F7E2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatDashboard(
                  'Solde net',
                  _formatFCFA(soldeNet),
                  soldeNet >= 0
                      ? const Color(0xFFC8F7D8)
                      : const Color(0xFFFFDADA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatDashboard(
                  'vs mois pré.',
                  '${variationMois >= 0 ? '+' : ''}${_formatFCFA(variationMois)}',
                  variationMois >= 0
                      ? const Color(0xFFC8F7D8)
                      : const Color(0xFFFFDADA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatDashboard(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDEEAFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparatifMois(
    _RapportMensuel moisCourant,
    _RapportMensuel moisPrecedent,
  ) {
    final maxValue = [
      moisCourant.totalDepenses,
      moisPrecedent.totalDepenses,
      moisCourant.totalRevenus,
      moisPrecedent.totalRevenus,
    ].reduce((a, b) => a > b ? a : b).toDouble();

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
          const Text(
            'Comparaison mois courant vs précédent',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue / 100 * 1.2,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 100 / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFF2F4F7),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final labels = [
                          '${moisPrecedent.label}',
                          '${moisCourant.label}',
                        ];
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF737783),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barsSpace: 8,
                    barRods: [
                      BarChartRodData(
                        toY: moisPrecedent.totalDepenses / 100,
                        color: const Color(0xFFBA1A1A),
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                      BarChartRodData(
                        toY: moisPrecedent.totalRevenus / 100,
                        color: const Color(0xFF007328),
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barsSpace: 8,
                    barRods: [
                      BarChartRodData(
                        toY: moisCourant.totalDepenses / 100,
                        color: const Color(0xFFBA1A1A),
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                      BarChartRodData(
                        toY: moisCourant.totalRevenus / 100,
                        color: const Color(0xFF007328),
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLegendeCouleur(const Color(0xFFBA1A1A), 'Dépenses'),
              const SizedBox(width: 16),
              _buildLegendeCouleur(const Color(0xFF007328), 'Revenus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarteRapportMensuel(_RapportMensuel rapport) {
    final variationCouleur = rapport.variation >= 0
        ? const Color(0xFF007328)
        : const Color(0xFFBA1A1A);

    final maxCategorie = rapport.categories.isNotEmpty
        ? rapport.categories.reduce((a, b) => a.total > b.total ? a : b)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rapport.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191C1E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: variationCouleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rapport.variation >= 0 ? '+' : ''}${_formatFCFA(rapport.variation)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: variationCouleur,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Dépenses',
                  _formatFCFA(rapport.totalDepenses),
                  const Color(0xFFBA1A1A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  'Revenus',
                  _formatFCFA(rapport.totalRevenus),
                  const Color(0xFF007328),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMiniStat(
            'Solde net',
            _formatFCFA(rapport.soldeNet),
            rapport.soldeNet >= 0
                ? const Color(0xFF2E7D32)
                : const Color(0xFFBA1A1A),
          ),
          if (maxCategorie != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _hexToColor(maxCategorie.couleur),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catégorie la plus élevée : ${maxCategorie.nom}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191C1E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatFCFA(maxCategorie.total),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (rapport.categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Détail par catégorie',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF434652),
              ),
            ),
            const SizedBox(height: 8),
            ...rapport.categories.take(4).map((categorie) {
              final totalCategorie = rapport.totalDepenses > 0
                  ? categorie.total / rapport.totalDepenses
                  : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE7EBF0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _hexToColor(categorie.couleur),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categorie.nom,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191C1E),
                            ),
                          ),
                        ),
                        Text(
                          _formatFCFA(categorie.total),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalCategorie.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF2F4F7),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _hexToColor(categorie.couleur),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(10),
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

  List<_RapportMensuel> _calculerRapportsMensuels(List<Operation> operations) {
    final Map<String, List<Operation>> operationsParMois = {};

    for (final op in operations) {
      final cle = '${op.date.year}-${op.date.month.toString().padLeft(2, '0')}';
      operationsParMois.putIfAbsent(cle, () => []);
      operationsParMois[cle]!.add(op);
    }

    final rapports = operationsParMois.entries.map((entry) {
      final moisDate = DateTime(
        int.parse(entry.key.split('-')[0]),
        int.parse(entry.key.split('-')[1]),
        1,
      );

      final operationsDuMois = entry.value;

      final totalDepenses = operationsDuMois
          .where((op) => op.type == 'depense')
          .fold<int>(0, (sum, op) => sum + op.montantCentimes);

      final totalRevenus = operationsDuMois
          .where((op) => op.type == 'revenu')
          .fold<int>(0, (sum, op) => sum + op.montantCentimes);

      final soldeNet = totalRevenus - totalDepenses;

      final categoriesMap = <int, int>{};
      for (final op in operationsDuMois) {
        if (op.type != 'depense' || op.categorieId == null) continue;
        categoriesMap[op.categorieId!] =
            (categoriesMap[op.categorieId!] ?? 0) + op.montantCentimes;
      }

      final categories = categoriesMap.entries.map((entry) {
        final categorie = _categoriesMap[entry.key];
        final nom = categorie?.nom ?? 'Sans catégorie';
        final couleur = categorie?.couleur ?? '#9AA0A6';
        return _DetailCategorieRapport(
          nom: nom,
          total: entry.value,
          couleur: couleur,
        );
      }).toList()..sort((a, b) => b.total.compareTo(a.total));

      return _RapportMensuel(
        label: DateFormat('MMMM yyyy', 'fr_FR').format(moisDate),
        totalDepenses: totalDepenses,
        totalRevenus: totalRevenus,
        soldeNet: soldeNet,
        variation: 0,
        categories: categories,
      );
    }).toList();

    rapports.sort((a, b) => _triMois(a.label).compareTo(_triMois(b.label)));

    for (int i = 0; i < rapports.length; i++) {
      if (i == 0) {
        rapports[i] = rapports[i].copyWith(variation: rapports[i].soldeNet);
        continue;
      }

      final rapportActuel = rapports[i];
      final rapportPrecedent = rapports[i - 1];
      final variation = rapportActuel.soldeNet - rapportPrecedent.soldeNet;
      rapports[i] = rapportActuel.copyWith(variation: variation);
    }

    return rapports.reversed.toList();
  }

  int _triMois(String label) {
    try {
      final date = DateFormat('MMMM yyyy', 'fr_FR').parse(label);
      return DateTime(date.year, date.month).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  // ---------- HELPERS ----------
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class _RapportMensuel {
  final String label;
  final int totalDepenses;
  final int totalRevenus;
  final int soldeNet;
  final int variation;
  final List<_DetailCategorieRapport> categories;

  const _RapportMensuel({
    required this.label,
    required this.totalDepenses,
    required this.totalRevenus,
    required this.soldeNet,
    required this.variation,
    this.categories = const [],
  });

  _RapportMensuel copyWith({
    String? label,
    int? totalDepenses,
    int? totalRevenus,
    int? soldeNet,
    int? variation,
    List<_DetailCategorieRapport>? categories,
  }) {
    return _RapportMensuel(
      label: label ?? this.label,
      totalDepenses: totalDepenses ?? this.totalDepenses,
      totalRevenus: totalRevenus ?? this.totalRevenus,
      soldeNet: soldeNet ?? this.soldeNet,
      variation: variation ?? this.variation,
      categories: categories ?? this.categories,
    );
  }
}

class _DetailCategorieRapport {
  final String nom;
  final int total;
  final String couleur;

  const _DetailCategorieRapport({
    required this.nom,
    required this.total,
    required this.couleur,
  });
}
