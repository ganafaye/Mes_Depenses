import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/database.dart';
import '../data/secure_store.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/operation.dart';
import 'notification_parser.dart';
import 'notification_service.dart';
import 'sms_service.dart';

/// Résultat du traitement d'une notification
class ResultatDetection {
  final bool succes;
  final String message;
  final Operation? operation;

  ResultatDetection({
    required this.succes,
    required this.message,
    this.operation,
  });
}

/// Service qui écoute les notifications et les SMS, puis enregistre les opérations
class DetectionService {
  static final DetectionService instance = DetectionService._internal();
  factory DetectionService() => instance;
  DetectionService._internal();

  StreamSubscription<NotificationRecue>? _subscription;
  StreamSubscription<SmsRecu>? _smsSubscription;
  final _db = DatabaseService();

  /// Stream pour notifier l'UI qu'une opération a été ajoutée
  final _operationAjouteeController = StreamController<Operation>.broadcast();
  Stream<Operation> get operationAjoutee => _operationAjouteeController.stream;

  bool _actif = false;
  bool get actif => _actif;

  /// Démarre l'écoute des notifications et des SMS
  void demarrer() {
    if (_actif) return;
    _actif = true;

    // Écoute des notifications
    _subscription = NotificationService.notifications.listen(
      (notif) => _traiterNotification(notif),
      onError: (e) => debugPrint('Erreur stream notifications : $e'),
    );

    // Écoute des SMS
    _smsSubscription = SmsService.sms.listen(
      (sms) => _traiterSms(sms),
      onError: (e) => debugPrint('Erreur stream SMS : $e'),
    );

    debugPrint('DetectionService démarré');
  }

  /// Arrête l'écoute
  void arreter() {
    _subscription?.cancel();
    _subscription = null;
    _smsSubscription?.cancel();
    _smsSubscription = null;
    _actif = false;
    debugPrint('DetectionService arrêté');
  }

  @override
  void dispose() {
    arreter();
    _operationAjouteeController.close();
  }

  // ==================== TRAITEMENT NOTIFICATIONS ====================

  Future<void> _traiterNotification(NotificationRecue notif) async {
    debugPrint('--- Notification reçue ---');
    debugPrint('Titre : ${notif.titre}');
    debugPrint('Contenu : ${notif.contenu}');

    final parse = NotificationParser.parse(notif.titre, notif.contenu);
    if (parse == null) {
      debugPrint('→ Ignorée (non reconnue par le parser)');
      return;
    }

    await _enregistrerOperation(parse, origine: 'notification');
  }

  // ==================== TRAITEMENT SMS ====================

  Future<void> _traiterSms(SmsRecu sms) async {
    debugPrint('--- SMS reçu ---');
    debugPrint('Expéditeur : ${sms.expediteur}');
    debugPrint('Contenu : ${sms.contenu}');

    // Pour un SMS, on n'a pas de titre → on passe une chaîne vide
    final parse = NotificationParser.parse('', sms.contenu);
    if (parse == null) {
      debugPrint('→ Ignoré (non reconnu par le parser)');
      return;
    }

    await _enregistrerOperation(parse, origine: 'sms');
  }

  // ==================== ENREGISTREMENT COMMUN ====================

  /// Méthode commune pour enregistrer une opération (notif ou SMS)
  Future<void> _enregistrerOperation(
    OperationParse parse, {
    required String origine,
  }) async {
    debugPrint('→ Parsé : $parse');

    // Anti-doublon par référence (OM principalement)
    if (parse.reference != null && parse.reference!.isNotEmpty) {
      final dejaTraitee = await _db.referenceDejaTraitee(parse.reference!);
      if (dejaTraitee) {
        debugPrint('→ Ignoré (référence déjà traitée : ${parse.reference})');
        return;
      }
    }

    // Trouver le compte
    final compte = await _trouverCompte(parse.operateur);
    if (compte == null) {
      debugPrint('→ Ignoré (aucun compte ${parse.operateur} trouvé)');
      return;
    }

    // Anti-doublon Wave : même montant, même compte, dans les 5 dernières secondes
    if (parse.operateur == 'wave') {
      final similaire = await _db.operationSimilaireRecente(
        compteId: compte.id!,
        montantCentimes: parse.montantCentimes,
        type: parse.type,
      );
      if (similaire) {
        debugPrint('→ Ignoré (opération similaire récente)');
        if (parse.reference != null) {
          await _db.marquerReferenceTraitee(parse.reference!);
        }
        return;
      }
    }

    // Catégorie
    final categorie = await _trouverCategorie(parse.type);

    // Note
    final note = _construireNote(parse);

    // Créer l'opération
    final operation = Operation(
      compteId: compte.id!,
      categorieId: categorie?.id,
      type: parse.type,
      montantCentimes: parse.montantCentimes,
      date: parse.date,
      note: note,
      origine: origine,
    );

    // Enregistrer
    final id = await _db.insertOperation(operation);

    // Marquer la référence
    if (parse.reference != null && parse.reference!.isNotEmpty) {
      await _db.marquerReferenceTraitee(parse.reference!);
    }

    // Notifier l'UI
    final operationFinale = operation.copyWith(id: id);
    _operationAjouteeController.add(operationFinale);

    // Notification de confirmation
    final confirmationActive = await SecureStore.isConfirmationActive();
    if (confirmationActive) {
      await NotificationService.afficherConfirmation(
        operateur: parse.operateur,
        type: parse.type,
      );
    }

    debugPrint('✓ Opération enregistrée ($origine, id=$id)');
  }

  // ==================== HELPERS ====================

  /// Trouve le compte correspondant à un opérateur
  Future<Compte?> _trouverCompte(String operateur) async {
    final comptes = await _db.getComptes(actifsSeulement: true);
    final comptesOperateur = comptes.where((c) {
      if (operateur == 'wave') return c.type == 'wave';
      if (operateur == 'orange_money') return c.type == 'orange_money';
      return false;
    }).toList();

    if (comptesOperateur.isEmpty) return null;
    return comptesOperateur.first;
  }

  /// Trouve la catégorie par défaut
  Future<Categorie?> _trouverCategorie(String type) async {
    final categories = await _db.getCategories(type: type);
    if (categories.isEmpty) return null;

    if (type == 'depense') {
      return categories.firstWhere(
        (c) => c.nom == 'À classer',
        orElse: () => categories.first,
      );
    } else {
      return categories.firstWhere(
        (c) => c.nom == 'Autres revenus',
        orElse: () => categories.first,
      );
    }
  }

  /// Construit la note à partir des infos parsées
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
      return 'Détecté automatiquement';
    }
    return parties.join(' • ');
  }
}
