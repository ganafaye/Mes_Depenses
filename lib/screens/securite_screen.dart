import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../data/secure_store.dart';

class SecuriteScreen extends StatefulWidget {
  const SecuriteScreen({super.key});

  @override
  State<SecuriteScreen> createState() => _SecuriteScreenState();
}

class _SecuriteScreenState extends State<SecuriteScreen> {
  final _localAuth = LocalAuthentication();

  bool _pinActif = false;
  bool _bioActive = false;
  bool _bioDisponible = false;

  @override
  void initState() {
    super.initState();
    _chargerEtat();
  }

  Future<void> _chargerEtat() async {
    final pinActif = await SecureStore.hasPin();
    final bioActive = await SecureStore.isBioEnabled();
    bool bioDispo = false;
    try {
      bioDispo = await _localAuth.canCheckBiometrics;
    } catch (_) {}
    setState(() {
      _pinActif = pinActif;
      _bioActive = bioActive;
      _bioDisponible = bioDispo;
    });
  }

  Future<void> _definirPin() async {
    final controller = TextEditingController();
    final confirme = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Définir un code PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisis un code à 4 chiffres.\nIl te sera demandé à chaque ouverture.',
              style: TextStyle(fontSize: 13, color: Color(0xFF737783)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
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
              final pin = controller.text.trim();
              if (pin.length != 4) {
                return;
              }
              Navigator.pop(ctx, pin);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirme == null) return;
    await SecureStore.setPin(confirme);
    await _chargerEtat();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code PIN défini')),
      );
    }
    // Proposer biométrie
    if (_bioDisponible) {
      _proposerBiometrie();
    }
  }

  Future<void> _proposerBiometrie() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer la biométrie ?'),
        content: const Text(
          'Tu pourras déverrouiller l\'application avec ton empreinte '
          'en plus du code PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await SecureStore.setBioEnabled(true);
      await _chargerEtat();
    }
  }

  Future<void> _toggleBiometrie(bool valeur) async {
    if (valeur && !_pinActif) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Définis d\'abord un code PIN')),
      );
      return;
    }
    await SecureStore.setBioEnabled(valeur);
    await _chargerEtat();
  }

  Future<void> _desactiverPin() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver le verrouillage ?'),
        content: const Text(
          'L\'application ne demandera plus de code PIN à l\'ouverture.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await SecureStore.clearPin();
      await _chargerEtat();
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
          'Sécurité',
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
          _buildCarte(
            icon: Icons.lock_outline,
            titre: 'Code PIN',
            sousTitre: _pinActif ? 'Actif' : 'Inactif',
            couleur: _pinActif
                ? const Color(0xFF43A047)
                : const Color(0xFF737783),
            action: _pinActif ? 'Modifier' : 'Définir',
            onAction: _definirPin,
          ),
          const SizedBox(height: 12),
          _buildCarteSwitch(
            icon: Icons.fingerprint,
            titre: 'Biométrie',
            sousTitre: !_bioDisponible
                ? 'Non disponible sur cet appareil'
                : _bioActive
                    ? 'Activée'
                    : 'Désactivée',
            valeur: _bioActive,
            onChanged: _bioDisponible ? _toggleBiometrie : null,
          ),
          const SizedBox(height: 24),
          if (_pinActif)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _desactiverPin,
                icon: const Icon(Icons.lock_open, color: Colors.red),
                label: const Text(
                  'Désactiver le verrouillage',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ton code PIN reste uniquement sur ce téléphone. '
                    'Aucune donnée n\'est envoyée sur Internet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarte({
    required IconData icon,
    required String titre,
    required String sousTitre,
    required Color couleur,
    required String action,
    required VoidCallback onAction,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF003178).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF003178), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  style: TextStyle(
                    fontSize: 12,
                    color: couleur,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildCarteSwitch({
    required IconData icon,
    required String titre,
    required String sousTitre,
    required bool valeur,
    required ValueChanged<bool>? onChanged,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF003178).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF003178), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737783),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: valeur,
            onChanged: onChanged,
            activeColor: const Color(0xFF003178),
          ),
        ],
      ),
    );
  }
}