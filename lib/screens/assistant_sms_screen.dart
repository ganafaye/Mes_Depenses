import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../models/categorie.dart';
import '../models/compte.dart';
import '../models/operation.dart';
import '../services/notification_parser.dart';

class AssistantSmsScreen extends StatefulWidget {
  const AssistantSmsScreen({super.key});

  @override
  State<AssistantSmsScreen> createState() => _AssistantSmsScreenState();
}

class _AssistantSmsScreenState extends State<AssistantSmsScreen> {
  final _smsController = TextEditingController();
  final _db = DatabaseService();

  OperationParse? _parse;
  bool _analyseEnCours = false;
  String? _erreur;

  // Données pour la prévisualisation
  List<Compte> _comptes = [];
  List<Categorie> _categories = [];
  int? _compteIdChoisi;
  int? _categorieIdChoisie;

  @override
  void initState() {
    super.initState();
    _chargerComptes();
  }

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _chargerComptes() async {
    final comptes = await _db.getComptes(actifsSeulement: true);
    setState(() => _comptes = comptes);
  }

  Future<void> _collerDepuisPressePapier() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _smsController.text = data.text!;
      });
      _analyser();
    }
  }

  Future<void> _analyser() async {
    final texte = _smsController.text.trim();
    if (texte.isEmpty) {
      setState(() => _erreur = 'Colle d\'abord un message SMS');
      return;
    }

    setState(() {
      _analyseEnCours = true;
      _erreur = null;
      _parse = null;
    });

    // Parser
    final parse = NotificationParser.parse('', texte);

    if (parse == null) {
      setState(() {
        _analyseEnCours = false;
        _erreur = 'Ce message n\'a pas pu être reconnu automatiquement.\n'
            'Tu peux ajouter l\'opération manuellement.';
      });
      return;
    }

    // Charger les catégories du type
    final categories = await _db.getCategories(type: parse.type);

    // Trouver le compte par défaut (premier compte du bon type)
    final compteDefaut = _comptes.firstWhere(
      (c) {
        if (parse.operateur == 'wave') return c.type == 'wave';
        if (parse.operateur == 'orange_money') return c.type == 'orange_money';
        return false;
      },
      orElse: () => _comptes.isNotEmpty ? _comptes.first : Compte(
        nom: '',
        type: '',
        soldeDepartCentimes: 0,
        dateDebut: DateTime.now(),
      ),
    );

    setState(() {
      _parse = parse;
      _categories = categories;
      _compteIdChoisi = compteDefaut.id;
      _categorieIdChoisie = _categorieParDefaut(categories, parse.type);
      _analyseEnCours = false;
    });
  }

  int? _categorieParDefaut(List<Categorie> categories, String type) {
    if (categories.isEmpty) return null;
    if (type == 'depense') {
      return categories
          .firstWhere(
            (c) => c.nom == 'À classer',
            orElse: () => categories.first,
          )
          .id;
    } else {
      return categories
          .firstWhere(
            (c) => c.nom == 'Autres revenus',
            orElse: () => categories.first,
          )
          .id;
    }
  }

  Future<void> _enregistrer() async {
    if (_parse == null || _compteIdChoisi == null) return;

    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l\'enregistrement ?'),
        content: Text(
          'Une opération de ${_formatFCFA(_parse!.montantCentimes)} '
          'sera ajoutée au compte sélectionné.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmation != true) return;

    final operation = Operation(
      compteId: _compteIdChoisi!,
      categorieId: _categorieIdChoisie,
      type: _parse!.type,
      montantCentimes: _parse!.montantCentimes,
      date: _parse!.date,
      note: _construireNote(_parse!),
      origine: 'collee',
    );

    await _db.insertOperation(operation);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opération de ${_formatFCFA(_parse!.montantCentimes)} enregistrée',
          ),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _ouvrirFormulaireManuel() async {
    Navigator.pop(context, true);
    // TODO : ouvrir AjouterOperationScreen (on le fera plus tard)
  }

  // ==================== HELPERS ====================

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

  String _construireNote(OperationParse parse) {
    final parties = <String>[];
    if (parse.contrepartie != null && parse.contrepartie!.isNotEmpty) {
      parties.add(parse.contrepartie!);
    }
    if (parse.fraisCentimes != null && parse.fraisCentimes! > 0) {
      final fraisFCFA = (parse.fraisCentimes! / 100).toStringAsFixed(0);
      parties.add('Frais: ${fraisFCFA}F');
    }
    if (parties.isEmpty) {
      return 'Message collé';
    }
    return parties.join(' • ');
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

  // ==================== BUILD ====================

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
          'Coller un SMS',
          style: TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfo(),
          const SizedBox(height: 16),
          _buildChampSms(),
          const SizedBox(height: 12),
          _buildBoutons(),
          if (_erreur != null) ...[
            const SizedBox(height: 16),
            _buildErreur(),
          ],
          if (_parse != null) ...[
            const SizedBox(height: 24),
            _buildPrevisualisation(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Colle un SMS de Wave ou Orange Money. '
              'L\'application l\'analysera et te proposera d\'enregistrer l\'opération.',
              style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChampSms() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E6)),
      ),
      child: TextField(
        controller: _smsController,
        maxLines: 6,
        minLines: 4,
        style: const TextStyle(fontSize: 13, height: 1.5),
        decoration: const InputDecoration(
          hintText:
              'Colle ici le texte du SMS...\n\nExemple :\nVous avez envoyé 5000F\nA Jean Dupont\n...',
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFFC3C6D4)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildBoutons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _collerDepuisPressePapier,
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('Coller'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF003178),
              side: const BorderSide(color: Color(0xFF003178)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _analyseEnCours ? null : _analyser,
            icon: _analyseEnCours
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_analyseEnCours ? 'Analyse...' : 'Analyser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003178),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErreur() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Message non reconnu',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _erreur!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _ouvrirFormulaireManuel,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Ajouter manuellement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE65100),
                side: const BorderSide(color: Color(0xFFE65100)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrevisualisation() {
    final parse = _parse!;
    final estDepense = parse.type == 'depense';
    final couleur = estDepense
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF007328);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2FF), width: 2),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF43A047), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Transaction détectée',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLigne('Type', estDepense ? 'Dépense' : 'Revenu', couleur: couleur),
          _buildLigne('Opérateur', _labelPourType(parse.operateur)),
          _buildLigne('Montant', _formatFCFA(parse.montantCentimes), couleur: couleur),
          if (parse.fraisCentimes != null && parse.fraisCentimes! > 0)
            _buildLigne('Frais', _formatFCFA(parse.fraisCentimes!)),
          if (parse.contrepartie != null)
            _buildLigne('Contrepartie', parse.contrepartie!),
          if (parse.reference != null)
            _buildLigne('Référence', parse.reference!),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Compte à créditer/débiter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF434652),
            ),
          ),
          const SizedBox(height: 8),
          _buildSelecteurComptes(),
          const SizedBox(height: 16),
          const Text(
            'Catégorie',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF434652),
            ),
          ),
          const SizedBox(height: 8),
          _buildSelecteurCategories(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _enregistrer,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Enregistrer l\'opération',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003178),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLigne(String label, String valeur, {Color? couleur}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF737783),
              ),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: couleur ?? const Color(0xFF191C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelecteurComptes() {
    if (_comptes.isEmpty) {
      return const Text('Aucun compte disponible');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _comptes.map((c) {
        final selectionne = _compteIdChoisi == c.id;
        final couleur = _couleurPourType(c.type);
        return GestureDetector(
          onTap: () => setState(() => _compteIdChoisi = c.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selectionne
                  ? couleur.withOpacity(0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectionne ? couleur : const Color(0xFFE0E3E6),
                width: selectionne ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconePourType(c.type), size: 16, color: couleur),
                const SizedBox(width: 6),
                Text(
                  c.nom,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selectionne ? FontWeight.w600 : FontWeight.w500,
                    color: selectionne ? couleur : const Color(0xFF434652),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelecteurCategories() {
    if (_categories.isEmpty) {
      return const Text('Chargement des catégories...');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final selectionne = _categorieIdChoisie == cat.id;
        final couleur = _hexToColor(cat.couleur);
        return GestureDetector(
          onTap: () => setState(() => _categorieIdChoisie = cat.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selectionne
                  ? couleur.withOpacity(0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectionne ? couleur : const Color(0xFFE0E3E6),
                width: selectionne ? 2 : 1,
              ),
            ),
            child: Text(
              cat.nom,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selectionne ? FontWeight.w600 : FontWeight.w500,
                color: selectionne ? couleur : const Color(0xFF434652),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}