import 'package:flutter/material.dart';
import '../data/secure_store.dart';
import '../services/notification_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  bool _permissionAccordee = false;
  bool _permissionSmsAccordee = false;
  bool _confirmationActive = true;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifierPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifierPermission();
    }
  }

  Future<void> _verifierPermission() async {
    setState(() => _chargement = true);
    final accordee = await NotificationService.isPermissionGranted();
    final smsAccordee = await NotificationService.isSmsPermissionGranted();
    final confirmation = await SecureStore.isConfirmationActive();
    setState(() {
      _permissionAccordee = accordee;
      _permissionSmsAccordee = smsAccordee;
      _confirmationActive = confirmation;
      _chargement = false;
    });
  }

  Future<void> _ouvrirParametres() async {
    await NotificationService.openNotificationSettings();
  }

  Future<void> _demanderPermissionSms() async {
    await NotificationService.requestSmsPermission();
    // Attendre que la popup soit traitée
    await Future.delayed(const Duration(seconds: 1));
    _verifierPermission();
  }

  Future<void> _toggleConfirmation(bool valeur) async {
    await SecureStore.setConfirmationActive(valeur);
    setState(() => _confirmationActive = valeur);
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
          'Détection automatique',
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Statut notifications
                _buildStatut(
                  actif: _permissionAccordee,
                  titreActif: 'Notifications activées',
                  titreInactif: 'Notifications désactivées',
                  sousTitreActif:
                      'Les notifications de Wave et Orange Money seront automatiquement détectées.',
                  sousTitreInactif:
                      'Active la lecture des notifications pour enregistrer automatiquement tes transactions.',
                  iconeActif: Icons.notifications_active,
                  iconeInactif: Icons.notifications_off_outlined,
                ),
                const SizedBox(height: 12),
                // Statut SMS
                _buildStatut(
                  actif: _permissionSmsAccordee,
                  titreActif: 'Lecture SMS activée',
                  titreInactif: 'Lecture SMS désactivée',
                  sousTitreActif:
                      'Les SMS de Wave (code) et Orange Money seront automatiquement détectés.',
                  sousTitreInactif:
                      'Active la lecture des SMS pour enregistrer tes transactions Wave par code ou OM.',
                  iconeActif: Icons.sms,
                  iconeInactif: Icons.sms_outlined,
                ),
                const SizedBox(height: 20),
                _buildExplication(),
                const SizedBox(height: 20),
                _buildSwitchConfirmation(),
                const SizedBox(height: 24),
                // Boutons notifications
                if (!_permissionAccordee)
                  _buildBoutonAction(
                    label: 'Activer la lecture des notifications',
                    icone: Icons.notifications_active,
                    onPressed: _ouvrirParametres,
                    primaire: true,
                  ),
                if (_permissionAccordee)
                  _buildBoutonAction(
                    label: 'Gérer les notifications dans Android',
                    icone: Icons.settings,
                    onPressed: _ouvrirParametres,
                    primaire: false,
                  ),
                const SizedBox(height: 12),
                // Bouton SMS
                if (!_permissionSmsAccordee)
                  _buildBoutonAction(
                    label: 'Activer la lecture des SMS',
                    icone: Icons.sms,
                    onPressed: _demanderPermissionSms,
                    primaire: true,
                  ),
                if (_permissionSmsAccordee)
                  _buildBoutonAction(
                    label: 'SMS déjà autorisés',
                    icone: Icons.check_circle,
                    onPressed: null,
                    primaire: false,
                  ),
                const SizedBox(height: 24),
                _buildInfoConfidentialite(),
              ],
            ),
    );
  }

  // ---------- STATUT GÉNÉRIQUE ----------
  Widget _buildStatut({
    required bool actif,
    required String titreActif,
    required String titreInactif,
    required String sousTitreActif,
    required String sousTitreInactif,
    required IconData iconeActif,
    required IconData iconeInactif,
  }) {
    final couleurFond =
        actif ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final couleurTexte =
        actif ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final icone = actif ? iconeActif : iconeInactif;
    final titre = actif ? titreActif : titreInactif;
    final sousTitre = actif ? sousTitreActif : sousTitreInactif;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: couleurFond,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: couleurTexte, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: couleurTexte,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sousTitre,
                  style: TextStyle(
                    fontSize: 13,
                    color: couleurTexte.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- EXPLICATION ----------
  Widget _buildExplication() {
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
            'Comment ça marche ?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191C1E),
            ),
          ),
          const SizedBox(height: 12),
          _buildEtape(
            '1',
            'Tu fais une transaction Wave ou Orange Money (app ou code).',
          ),
          const SizedBox(height: 10),
          _buildEtape(
            '2',
            'L\'application lit la notification ou le SMS en arrière-plan.',
          ),
          const SizedBox(height: 10),
          _buildEtape(
            '3',
            'L\'opération est enregistrée et ton solde est mis à jour.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber,
                    color: Color(0xFFE65100), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seuls les messages de Wave et Orange Money '
                    'sont analysés. Les autres sont ignorés.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE65100),
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

  Widget _buildEtape(String numero, String texte) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF003178),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              numero,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texte,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF434652),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- SWITCH CONFIRMATION ----------
  Widget _buildSwitchConfirmation() {
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
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF003178),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Notification de confirmation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191C1E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Affiche une notification discrète après chaque détection',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737783),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _confirmationActive,
            onChanged: _toggleConfirmation,
            activeColor: const Color(0xFF003178),
          ),
        ],
      ),
    );
  }

  // ---------- BOUTON ACTION (générique) ----------
  Widget _buildBoutonAction({
    required String label,
    required IconData icone,
    required VoidCallback? onPressed,
    required bool primaire,
  }) {
    if (primaire) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icone, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
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
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icone, color: const Color(0xFF003178)),
          label: Text(
            label,
            style: TextStyle(
              color: onPressed == null
                  ? const Color(0xFF43A047)
                  : const Color(0xFF003178),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: onPressed == null
                  ? const Color(0xFF43A047)
                  : const Color(0xFF003178),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
  }

  // ---------- INFO CONFIDENTIALITÉ ----------
  Widget _buildInfoConfidentialite() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'L\'analyse se fait uniquement sur ton téléphone. '
              'Aucune notification ni SMS n\'est envoyé sur Internet.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}