import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../models/charge.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _db = DatabaseService();

  int _reserveCentimes = 0;
  int _montantDisponibleCentimes = 0;
  int _resteParJourCentimes = 0;
  int _joursRestants = 0;
  List<Charge> _charges = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    final reserve = await _db.getReserveCentimes();
    final charges = await _db.getCharges();
    final resteAVivre = await _db.getResteAVivre();

    setState(() {
      _reserveCentimes = reserve;
      _charges = charges;
      _montantDisponibleCentimes = resteAVivre['montantDisponibleCentimes'] ?? 0;
      _resteParJourCentimes = resteAVivre['resteParJourCentimes'] ?? 0;
      _joursRestants = resteAVivre['joursRestants'] ?? 0;
      _chargement = false;
    });
  }

  // ---------- ACTIONS ----------
  Future<void> _modifierReserve() async {
    final controller = TextEditingController(
      text: (_reserveCentimes / 100).toStringAsFixed(0),
    );

    final resultat = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réserve à ne pas dépenser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ce montant est mis de côté et ne sera pas compté dans ton reste à vivre.',
              style: TextStyle(fontSize: 13, color: Color(0xFF737783)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Montant',
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (resultat != null) {
      final nettoye = resultat.replaceAll(' ', '').replaceAll(',', '.');
      final valeur = double.tryParse(nettoye) ?? 0;
      final centimes = (valeur * 100).round();
      await _db.setReserveCentimes(centimes);
      _chargerDonnees();
    }
  }

  Future<void> _ajouterCharge() async {
    final libelleController = TextEditingController();
    final montantController = TextEditingController();

    final resultat = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une charge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: libelleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Libellé',
                hintText: 'Ex: Loyer septembre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Montant',
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final libelle = libelleController.text.trim();
              final montant = montantController.text.trim();
              if (libelle.isEmpty || montant.isEmpty) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (resultat == true) {
      final libelle = libelleController.text.trim();
      final nettoye = montantController.text.replaceAll(' ', '').replaceAll(',', '.');
      final valeur = double.tryParse(nettoye) ?? 0;
      final centimes = (valeur * 100).round();

      if (centimes <= 0) return;

      await _db.insertCharge(Charge(
        libelle: libelle,
        montantCentimes: centimes,
      ));
      _chargerDonnees();
    }
  }

  Future<void> _supprimerCharge(Charge charge) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette charge ?'),
        content: Text('"${charge.libelle}" sera retirée de la liste.'),
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
      await _db.deleteCharge(charge.id!);
      _chargerDonnees();
    }
  }

  // ---------- FORMATAGE ----------
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

  // ---------- BUILD ----------
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
          'Mon budget',
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
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCarteResteAVivre(),
                  const SizedBox(height: 20),
                  _buildSectionReserve(),
                  const SizedBox(height: 20),
                  _buildSectionCharges(),
                ],
              ),
            ),
    );
  }

  // ---------- CARTE RESTE À VIVRE ----------
  Widget _buildCarteResteAVivre() {
    final negatif = _resteParJourCentimes <= 0;
    final couleurFond = negatif
        ? const LinearGradient(
            colors: [Color(0xFFBA1A1A), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF003178), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: couleurFond,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (negatif ? const Color(0xFFBA1A1A) : const Color(0xFF003178))
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Text(
                'RESTE À VIVRE PAR JOUR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatFCFA(_resteParJourCentimes),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Il reste $_joursRestants jour${_joursRestants > 1 ? 's' : ''} '
            'avant la fin du mois',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (negatif && _montantDisponibleCentimes < 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manque : ${_formatFCFA(_montantDisponibleCentimes.abs())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- SECTION RÉSERVE ----------
  Widget _buildSectionReserve() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Réserve à ne pas dépenser',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191C1E),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _modifierReserve,
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
                    color: const Color(0xFF5E35B1).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings,
                    color: Color(0xFF5E35B1),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Montant réservé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF737783),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFCFA(_reserveCentimes),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, color: Color(0xFF003178), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- SECTION CHARGES ----------
  Widget _buildSectionCharges() {
    final totalCharges = _charges
        .where((c) => !c.payee)
        .fold(0, (sum, c) => sum + c.montantCentimes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Charges à payer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191C1E),
                  ),
                ),
                if (totalCharges > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Total : ${_formatFCFA(totalCharges)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737783),
                    ),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: _ajouterCharge,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003178),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Ajouter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_charges.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long,
                      color: Color(0xFFC3C6D4), size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Aucune charge enregistrée',
                    style: TextStyle(
                      color: Color(0xFF434652),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ajoute tes charges du mois\n(loyer, factures, etc.)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF737783),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._charges.map((charge) => _buildCarteCharge(charge)),
      ],
    );
  }

  Widget _buildCarteCharge(Charge charge) {
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: charge.payee
                    ? const Color(0xFF43A047).withOpacity(0.15)
                    : const Color(0xFFFB8C00).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                charge.payee ? Icons.check : Icons.receipt,
                color: charge.payee
                    ? const Color(0xFF43A047)
                    : const Color(0xFFFB8C00),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charge.libelle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191C1E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    charge.payee ? 'Payée' : 'À payer',
                    style: TextStyle(
                      fontSize: 12,
                      color: charge.payee
                          ? const Color(0xFF43A047)
                          : const Color(0xFFFB8C00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatFCFA(charge.montantCentimes),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: Color(0xFF737783), size: 20),
              onSelected: (valeur) {
                if (valeur == 'supprimer') _supprimerCharge(charge);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'supprimer',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}