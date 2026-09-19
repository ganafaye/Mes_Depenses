import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../data/secure_store.dart';
import 'main_navigation.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();

  String _pin = '';
  String _erreur = '';
  bool _biometrieDisponible = false;
  bool _biometrieActive = false;
  bool _verificationEnCours = false;

  @override
  void initState() {
    super.initState();
    _initialiserBiometrie();
  }

  Future<void> _initialiserBiometrie() async {
    try {
      final disponible = await _localAuth.canCheckBiometrics;
      final active = await SecureStore.isBioEnabled();
      setState(() {
        _biometrieDisponible = disponible;
        _biometrieActive = active && disponible;
      });
      // Lancer automatiquement la biométrie
      if (_biometrieActive) {
        await Future.delayed(const Duration(milliseconds: 400));
        _authentifierBiometrie();
      }
    } catch (_) {}
  }

  Future<void> _authentifierBiometrie() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Déverrouille Mes Dépenses',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (ok && mounted) _deverrouiller();
    } catch (_) {}
  }

  Future<void> _validerPin() async {
    if (_pin.length != 4) return;
    setState(() {
      _verificationEnCours = true;
      _erreur = '';
    });

    final ok = await SecureStore.verifyPin(_pin);

    if (ok && mounted) {
      _deverrouiller();
    } else {
      setState(() {
        _erreur = 'Code PIN incorrect';
        _pin = '';
        _verificationEnCours = false;
      });
    }
  }

  void _deverrouiller() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  void _ajouterChiffre(String chiffre) {
    if (_pin.length >= 4 || _verificationEnCours) return;
    setState(() {
      _pin += chiffre;
      _erreur = '';
    });
    if (_pin.length == 4) {
      _validerPin();
    }
  }

  void _effacer() {
    if (_pin.isEmpty || _verificationEnCours) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _erreur = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo de l'application
            SizedBox(
              width: 138,
              height: 138,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mes Dépenses',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entre ton code PIN',
              style: TextStyle(fontSize: 14, color: Color(0xFF737783)),
            ),
            const SizedBox(height: 32),
            // Points du PIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final rempli = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: rempli
                        ? const Color(0xFF003178)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF003178),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (_erreur.isNotEmpty)
              Text(
                _erreur,
                style: const TextStyle(
                  color: Color(0xFFBA1A1A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const SizedBox(height: 18),
            const SizedBox(height: 16),
            // Pavé numérique
            _buildPave(),
            const SizedBox(height: 16),
            // Biométrie
            if (_biometrieActive)
              TextButton.icon(
                onPressed: _authentifierBiometrie,
                icon: const Icon(Icons.fingerprint, size: 24),
                label: const Text('Utiliser la biométrie'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF003178),
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPave() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildTouche('1'), _buildTouche('2'), _buildTouche('3')],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildTouche('4'), _buildTouche('5'), _buildTouche('6')],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildTouche('7'), _buildTouche('8'), _buildTouche('9')],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _buildTouche('0'),
            _buildToucheEffacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildTouche(String chiffre) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () => _ajouterChiffre(chiffre),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: Text(
              chiffre,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Color(0xFF191C1E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToucheEffacer() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: _effacer,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: const Icon(
              Icons.backspace_outlined,
              color: Color(0xFF191C1E),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
