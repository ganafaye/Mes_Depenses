import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/operation.dart';

class AjouterOperationScreen extends StatefulWidget {
  final String typeInitial; // 'depense' ou 'revenu'
  final int? compteIdInitial;
  final Operation?
  operationAModifier; // null = création, non-null = modification

  const AjouterOperationScreen({
    super.key,
    this.typeInitial = 'depense',
    this.compteIdInitial,
    this.operationAModifier,
  });

  @override
  State<AjouterOperationScreen> createState() => _AjouterOperationScreenState();
}

class _AjouterOperationScreenState extends State<AjouterOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _noteController = TextEditingController();

  late String _type;
  int? _compteId;
  int? _categorieId;
  DateTime _date = DateTime.now();
  bool _enregistrement = false;

  List<Compte> _comptes = [];
  List<Categorie> _categories = [];
  bool _chargement = true;

  bool get _estEnModification => widget.operationAModifier != null;

  bool get _estOperationAutoDetectee =>
      _estEnModification &&
      (widget.operationAModifier!.origine == 'sms' ||
          widget.operationAModifier!.origine == 'notification');

  @override
  void initState() {
    super.initState();
    if (_estEnModification) {
      // Mode édition : pré-remplir avec l'opération existante
      final op = widget.operationAModifier!;
      _type = op.type;
      _compteId = op.compteId;
      _categorieId = op.categorieId;
      _date = op.date;
      _montantController.text = (op.montantCentimes / 100).toStringAsFixed(0);
      _noteController.text = op.note ?? '';
    } else {
      // Mode création
      _type = widget.typeInitial;
      _compteId = widget.compteIdInitial;
    }
    _chargerDonnees();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    final db = DatabaseService();
    final comptes = await db.getComptes(actifsSeulement: true);
    final categories = await db.getCategories(type: _type);
    setState(() {
      _comptes = comptes;
      _categories = categories;
      // Pré-sélectionner le premier compte si non défini
      if (_compteId == null && comptes.isNotEmpty) {
        _compteId = comptes.first.id;
      }
      // Pré-sélectionner une catégorie si non définie
      if (_categorieId == null && categories.isNotEmpty) {
        if (_type == 'depense') {
          final aClasser = categories.firstWhere(
            (c) => c.nom == 'À classer',
            orElse: () => categories.first,
          );
          _categorieId = aClasser.id;
        } else {
          _categorieId = categories.first.id;
        }
      }
      _chargement = false;
    });
  }

  Future<void> _changerType(String nouveauType) async {
    if (nouveauType == _type) return;
    setState(() {
      _type = nouveauType;
      _categorieId = null;
    });
    // Recharger les catégories du nouveau type
    final categories = await DatabaseService().getCategories(type: nouveauType);
    setState(() {
      _categories = categories;
      if (categories.isNotEmpty) {
        if (nouveauType == 'depense') {
          final aClasser = categories.firstWhere(
            (c) => c.nom == 'À classer',
            orElse: () => categories.first,
          );
          _categorieId = aClasser.id;
        } else {
          _categorieId = categories.first.id;
        }
      }
    });
  }

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr', 'FR'),
    );
    if (choisie != null) {
      setState(() {
        _date = DateTime(
          choisie.year,
          choisie.month,
          choisie.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _enregistrer() async {
    if (_estEnModification) {
      final db = DatabaseService();
      final opOriginal = widget.operationAModifier!;

      if (_estOperationAutoDetectee) {
        final opModifiee = opOriginal.copyWith(
          categorieId: _categorieId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
        await db.updateOperation(opModifiee);
      } else {
        if (!_formKey.currentState!.validate()) return;
        if (_compteId == null) {
          _snack('Sélectionne un compte', Colors.orange);
          return;
        }

        final montantFCFA = double.parse(
          _montantController.text.replaceAll(' ', '').replaceAll(',', '.'),
        );
        final montantCentimes = (montantFCFA * 100).round();

        if (montantCentimes <= 0) {
          _snack('Le montant doit être supérieur à 0', Colors.orange);
          return;
        }

        final opModifiee = opOriginal.copyWith(
          compteId: _compteId!,
          categorieId: _categorieId,
          type: _type,
          montantCentimes: montantCentimes,
          date: _date,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
        await db.updateOperation(opModifiee);
      }

      if (mounted) Navigator.pop(context, true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_compteId == null) {
      _snack('Sélectionne un compte', Colors.orange);
      return;
    }

    setState(() => _enregistrement = true);

    try {
      final montantFCFA = double.parse(
        _montantController.text.replaceAll(' ', '').replaceAll(',', '.'),
      );
      final montantCentimes = (montantFCFA * 100).round();

      if (montantCentimes <= 0) {
        setState(() => _enregistrement = false);
        _snack('Le montant doit être supérieur à 0', Colors.orange);
        return;
      }

      final db = DatabaseService();
      final operation = Operation(
        compteId: _compteId!,
        categorieId: _categorieId,
        type: _type,
        montantCentimes: montantCentimes,
        date: _date,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        origine: 'manuelle',
      );
      await db.insertOperation(operation);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enregistrement = false);
        _snack('Erreur : $e', Colors.red);
      }
    }
  }

  void _snack(String message, Color couleur) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: couleur));
  }

  @override
  Widget build(BuildContext context) {
    final verrouilleDonneesEssentielles =
        _estEnModification && _estOperationAutoDetectee;
    final couleurType = _type == 'depense'
        ? const Color(0xFFBA1A1A)
        : const Color(0xFF007328);
    final couleurFond = _type == 'depense'
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF64FD7D);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF191C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _estEnModification ? 'Modifier l\'opération' : 'Nouvelle opération',
          style: const TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSelecteurType(couleurType, couleurFond),
                  const SizedBox(height: 24),
                  _buildLabel('Montant'),
                  const SizedBox(height: 8),
                  _buildChampMontant(
                    couleurType,
                    verrouille: verrouilleDonneesEssentielles,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Compte'),
                  const SizedBox(height: 8),
                  _buildSelecteurCompte(
                    verrouille: verrouilleDonneesEssentielles,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Catégorie'),
                  const SizedBox(height: 8),
                  _buildSelecteurCategorie(verrouille: false),
                  const SizedBox(height: 20),
                  _buildLabel('Date'),
                  const SizedBox(height: 8),
                  _buildSelecteurDate(
                    verrouille: verrouilleDonneesEssentielles,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Note (optionnel)'),
                  const SizedBox(height: 8),
                  _buildChampNote(),
                  const SizedBox(height: 32),
                  _buildBoutonEnregistrer(couleurType),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String texte) {
    return Text(
      texte,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF191C1E),
      ),
    );
  }

  // ---------- SÉLECTEUR TYPE (Dépense / Revenu) ----------
  Widget _buildSelecteurType(Color couleurType, Color couleurFond) {
    final verrouille = _estEnModification && _estOperationAutoDetectee;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBoutonType(
              'depense',
              'Dépense',
              Icons.remove,
              _type == 'depense',
              const Color(0xFFFFDAD6),
              const Color(0xFFBA1A1A),
              verrouille: verrouille,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildBoutonType(
              'revenu',
              'Revenu',
              Icons.add,
              _type == 'revenu',
              const Color(0xFF64FD7D),
              const Color(0xFF007328),
              verrouille: verrouille,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutonType(
    String valeur,
    String label,
    IconData icone,
    bool selectionne,
    Color couleurFond,
    Color couleurIcone, {
    required bool verrouille,
  }) {
    return IgnorePointer(
      ignoring: verrouille,
      child: GestureDetector(
        onTap: verrouille ? null : () => _changerType(valeur),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selectionne ? couleurFond : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icone,
                color: selectionne ? couleurIcone : const Color(0xFF737783),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selectionne ? couleurIcone : const Color(0xFF737783),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- CHAMP MONTANT ----------
  Widget _buildChampMontant(Color couleurType, {required bool verrouille}) {
    return TextFormField(
      controller: _montantController,
      enabled: !verrouille,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: couleurType,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFC3C6D4),
        ),
        suffixText: 'FCFA',
        suffixStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: couleurType,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: couleurType, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Indique un montant';
        final nettoye = v.replaceAll(' ', '').replaceAll(',', '.');
        final valeur = double.tryParse(nettoye);
        if (valeur == null) return 'Montant invalide';
        if (valeur <= 0) return 'Le montant doit être supérieur à 0';
        return null;
      },
    );
  }

  // ---------- SÉLECTEUR COMPTE ----------
  Widget _buildSelecteurCompte({required bool verrouille}) {
    if (_comptes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucun compte disponible.\nAjoute un compte d\'abord.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E6)),
      ),
      child: Column(
        children: _comptes.map((compte) {
          final selectionne = _compteId == compte.id;
          final couleur = _couleurPourType(compte.type);
          return InkWell(
            onTap: verrouille
                ? null
                : () => setState(() => _compteId = compte.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconePourType(compte.type),
                      color: couleur,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compte.nom,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        Text(
                          _labelPourType(compte.type),
                          style: TextStyle(fontSize: 12, color: couleur),
                        ),
                      ],
                    ),
                  ),
                  if (selectionne)
                    Icon(Icons.check_circle, color: couleur, size: 22)
                  else
                    const Icon(
                      Icons.circle_outlined,
                      color: Color(0xFFC3C6D4),
                      size: 22,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------- SÉLECTEUR CATÉGORIE ----------
  Widget _buildSelecteurCategorie({required bool verrouille}) {
    if (_categories.isEmpty) {
      return const Text('Chargement des catégories...');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final selectionne = _categorieId == cat.id;
        final couleur = _hexToColor(cat.couleur);
        return GestureDetector(
          onTap: () => setState(() => _categorieId = cat.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selectionne ? couleur.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectionne ? couleur : const Color(0xFFE0E3E6),
                width: selectionne ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconeDepuisNom(cat.icone), size: 16, color: couleur),
                const SizedBox(width: 6),
                Text(
                  cat.nom,
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

  // ---------- SÉLECTEUR DATE ----------
  Widget _buildSelecteurDate({required bool verrouille}) {
    final format = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    return GestureDetector(
      onTap: verrouille ? null : _choisirDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E3E6)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: Color(0xFF003178),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                format.format(_date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF191C1E),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF737783)),
          ],
        ),
      ),
    );
  }

  // ---------- CHAMP NOTE ----------
  Widget _buildChampNote() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: 'Ex: Achat au marché',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF003178), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ---------- BOUTON ENREGISTRER ----------
  Widget _buildBoutonEnregistrer(Color couleurType) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _enregistrement || _comptes.isEmpty ? null : _enregistrer,
        style: ElevatedButton.styleFrom(
          backgroundColor: couleurType,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
            : Text(
                _estEnModification
                    ? 'Enregistrer les modifications'
                    : 'Enregistrer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
        return 'Orange Money';
      case 'cash':
        return 'Espèces';
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
