import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../models/compte.dart';

class AjouterCompteScreen extends StatefulWidget {
  const AjouterCompteScreen({super.key});

  @override
  State<AjouterCompteScreen> createState() => _AjouterCompteScreenState();
}

class _AjouterCompteScreenState extends State<AjouterCompteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _soldeController = TextEditingController();

  String _typeSelectionne = 'wave';
  bool _enregistrement = false;

  final List<Map<String, dynamic>> _types = [
    {'valeur': 'wave', 'label': 'Wave', 'icone': Icons.waves, 'couleur': const Color(0xFF1E88E5)},
    {'valeur': 'orange_money', 'label': 'Orange Money', 'icone': Icons.swap_horiz, 'couleur': const Color(0xFFFF6F00)},
    {'valeur': 'cash', 'label': 'Espèces', 'icone': Icons.payments, 'couleur': const Color(0xFF43A047)},
    {'valeur': 'banque', 'label': 'Banque', 'icone': Icons.account_balance, 'couleur': const Color(0xFF5E35B1)},
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _soldeController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enregistrement = true);

    try {
      // Convertir le solde FCFA en centimes
      final soldeFCFA = double.parse(_soldeController.text.replaceAll(' ', '').replaceAll(',', '.'));
      final soldeCentimes = (soldeFCFA * 100).round();

      final compte = Compte(
        nom: _nomController.text.trim(),
        type: _typeSelectionne,
        soldeDepartCentimes: soldeCentimes,
        dateDebut: DateTime.now(),
      );

      await DatabaseService().insertCompte(compte);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enregistrement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          'Ajouter un compte',
          style: TextStyle(
            color: Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLabel('Type de compte'),
            const SizedBox(height: 10),
            _buildGrilleTypes(),
            const SizedBox(height: 24),
            _buildLabel('Nom du compte'),
            const SizedBox(height: 8),
            _buildChampNom(),
            const SizedBox(height: 20),
            _buildLabel('Solde de départ'),
            const SizedBox(height: 8),
            _buildChampSolde(),
            const SizedBox(height: 8),
            const Text(
              'Montant actuellement présent sur ce compte (en FCFA)',
              style: TextStyle(fontSize: 12, color: Color(0xFF737783)),
            ),
            const SizedBox(height: 32),
            _buildBoutonEnregistrer(),
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

  Widget _buildGrilleTypes() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: _types.length,
      itemBuilder: (context, index) {
        final type = _types[index];
        final selectionne = _typeSelectionne == type['valeur'];
        return GestureDetector(
          onTap: () => setState(() => _typeSelectionne = type['valeur']),
          child: Container(
            decoration: BoxDecoration(
              color: selectionne
                  ? (type['couleur'] as Color).withOpacity(0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectionne
                    ? type['couleur'] as Color
                    : const Color(0xFFE0E3E6),
                width: selectionne ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type['icone'] as IconData,
                  color: type['couleur'] as Color,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  type['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectionne
                        ? type['couleur'] as Color
                        : const Color(0xFF434652),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChampNom() {
    return TextFormField(
      controller: _nomController,
      decoration: InputDecoration(
        hintText: 'Ex: Wave principal',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF003178), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Donne un nom à ce compte';
        if (v.trim().length < 2) return 'Nom trop court';
        return null;
      },
    );
  }

  Widget _buildChampSolde() {
    return TextFormField(
      controller: _soldeController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
      ],
      decoration: InputDecoration(
        hintText: 'Ex: 50000',
        suffixText: 'FCFA',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF003178), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Indique le solde de départ';
        final nettoye = v.replaceAll(' ', '').replaceAll(',', '.');
        final valeur = double.tryParse(nettoye);
        if (valeur == null) return 'Montant invalide';
        if (valeur < 0) return 'Le solde ne peut pas être négatif';
        return null;
      },
    );
  }

  Widget _buildBoutonEnregistrer() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _enregistrement ? null : _enregistrer,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003178),
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
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Enregistrer le compte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}