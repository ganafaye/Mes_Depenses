import 'package:flutter/material.dart';
import '../data/secure_store.dart';
import 'main_navigation.dart';

class CreerProfilScreen extends StatefulWidget {
  const CreerProfilScreen({super.key});

  @override
  State<CreerProfilScreen> createState() => _CreerProfilScreenState();
}

class _CreerProfilScreenState extends State<CreerProfilScreen> {
  final _nomController = TextEditingController();
  bool _enregistrement = false;

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    final nom = _nomController.text.trim();

    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indique ton prénom pour continuer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enregistrement = true);

    // Sauvegarder le prénom
    await SecureStore.setNom(nom);

    // Marquer l'onboarding comme terminé
    await SecureStore.setOnboardingTermine(true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Avatar dynamique
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFF003178),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _nomController.text.trim().isEmpty
                          ? '?'
                          : _nomController.text.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Titre
              const Text(
                'Comment tu t\'appelles ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003178),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Ton prénom sera affiché sur l\'écran d\'accueil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF737783),
                ),
              ),

              const SizedBox(height: 32),

              // Champ prénom
              TextField(
                controller: _nomController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191C1E),
                ),
                decoration: InputDecoration(
                  hintText: 'Ex: Gana',
                  hintStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFC3C6D4),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E3E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E3E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF003178), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _terminer(),
              ),

              const Spacer(flex: 2),

              // Bouton Terminer
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _enregistrement ? null : _terminer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003178),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Terminer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}