/// Résultat du parsing d'une notification
class OperationParse {
  final String operateur; // 'wave' ou 'orange_money'
  final String type; // 'depense' ou 'revenu'
  final int montantCentimes; // montant en centimes
  final int? fraisCentimes; // frais en centimes (optionnel)
  final String? contrepartie; // nom de la personne/entreprise
  final String? reference; // ID de transaction
  final DateTime date;

  OperationParse({
    required this.operateur,
    required this.type,
    required this.montantCentimes,
    this.fraisCentimes,
    this.contrepartie,
    this.reference,
    required this.date,
  });

  @override
  String toString() {
    return 'OperationParse($operateur, $type, $montantCentimes centimes, '
        'frais=$fraisCentimes, contrepartie=$contrepartie, ref=$reference)';
  }
}

class NotificationParser {
  /// Point d'entrée : détecte l'opérateur et parse
  static OperationParse? parse(String titre, String contenu) {
    final texte = '$titre\n$contenu';

    if (_estWave(texte)) {
      return _parseWave(texte);
    }
    if (_estOM(texte)) {
      return _parseOM(texte);
    }
    return null;
  }

  // ==================== WAVE ====================

  static bool _estWave(String texte) {
    final t = texte.toLowerCase();
    return t.contains('wave') || t.contains('wdf') || t.contains('avec wdf');
  }

  static OperationParse? _parseWave(String texte) {
    try {
      final propre = _normaliser(texte);

      // Déterminer le sens
      final estDepense =
          propre.contains('envoye') ||
          propre.contains('transfert de') ||
          propre.contains('retrait') ||
          propre.contains('paiement') ||
          propre.contains('achat');

      final estRevenu =
          propre.contains('recu') ||
          propre.contains('reception') ||
          propre.contains('rembourse') ||
          propre.contains('retourne');

      if (!estDepense && !estRevenu) return null;

      final type = estRevenu ? 'revenu' : 'depense';

      final montantCentimes = _extraireMontantPrincipalWave(propre, type);
      if (montantCentimes == null || montantCentimes <= 0) return null;

      final fraisCentimes = _extraireFrais(propre);
      final contrepartie = _extraireContrepartieWave(propre, type);
      final reference = _extraireReferenceWave(texte);
      final date = _extraireDate(propre) ?? DateTime.now();

      return OperationParse(
        operateur: 'wave',
        type: type,
        montantCentimes: montantCentimes,
        fraisCentimes: fraisCentimes,
        contrepartie: contrepartie,
        reference: reference,
        date: date,
      );
    } catch (_) {
      return null;
    }
  }

  /// Wave affiche le montant en premier sur la 1ère ligne (après "envoyé"/"reçu")
  /// Ex: "Vous avez envoyé 100F" → 100F
  ///      "Vous avez reçu 40.000F" → 40000F
  static int? _extraireMontantPrincipalWave(String propre, String type) {
    final regexEnvoye = RegExp(r'envoye\s+([\d\s.]+)\s*f\b');
    final regexRecu = RegExp(r'recu\s+([\d\s.]+)\s*f\b');
    final regexRetourne = RegExp(r'retourne[^.]*?([\d\s.]+)\s*f\b');
    final regexTransfert = RegExp(r'transfert de\s+([\d\s.]+)\s*f\b');

    Match? match;
    if (type == 'revenu') {
      match =
          regexRecu.firstMatch(propre) ??
          regexRetourne.firstMatch(propre) ??
          regexTransfert.firstMatch(propre);
    } else {
      match =
          regexEnvoye.firstMatch(propre) ?? regexTransfert.firstMatch(propre);
    }

    if (match == null) return null;
    return _parseMontantCentimes(match.group(1)!);
  }

  static String? _extraireContrepartieWave(String propre, String type) {
    // "A Abdoulaye Dieye (762101794)" → "Abdoulaye Dieye"
    // "De ECOBANK" → "ECOBANK"
    final regex = type == 'revenu'
        ? RegExp(r'de\s+([^\n]+?)(?:\s*\(|\n|$)')
        : RegExp(r'\ba\s+([^\n]+?)(?:\s*\(|\n|$)');

    final match = regex.firstMatch(propre);
    if (match == null) return null;
    final valeur = match.group(1)?.trim();
    if (valeur == null || valeur.isEmpty) return null;
    return valeur;
  }

  static String? _extraireReferenceWave(String texte) {
    // La référence est la dernière ligne non vide et alphanumérique de 15+ caractères
    final lignes = texte.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lignes.isEmpty) return null;
    final derniere = lignes.last.trim();
    // Une réf Wave : 15+ caractères alphanumériques sans espace
    if (derniere.length >= 15 &&
        RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(derniere)) {
      return derniere.toUpperCase();
    }
    return null;
  }

  // ==================== ORANGE MONEY ====================

  static bool _estOM(String texte) {
    final t = texte.toLowerCase();
    return t.contains('ofms') ||
        t.contains('orange money') ||
        t.contains('orangemoney');
  }

  static OperationParse? _parseOM(String texte) {
    try {
      final propre = _normaliser(texte);

      final estRevenu =
          propre.contains('recu un depot') ||
          propre.contains('avez recu') ||
          propre.contains('depot de');

      final estDepense =
          propre.contains('transfert de') ||
          propre.contains('avez retire') ||
          propre.contains('retrait') ||
          propre.contains('facture') ||
          propre.contains('reglee');

      if (!estRevenu && !estDepense) return null;

      final type = estRevenu ? 'revenu' : 'depense';

      final montantCentimes = _extraireMontantPrincipalOM(propre, type);
      if (montantCentimes == null || montantCentimes <= 0) return null;

      final fraisCentimes = _extraireFraisOM(propre);
      final contrepartie = _extraireContrepartieOM(propre, type);
      final reference = _extraireReferenceOM(propre);
      final date = _extraireDate(propre) ?? DateTime.now();

      return OperationParse(
        operateur: 'orange_money',
        type: type,
        montantCentimes: montantCentimes,
        fraisCentimes: fraisCentimes,
        contrepartie: contrepartie,
        reference: reference,
        date: date,
      );
    } catch (_) {
      return null;
    }
  }

  /// OM : montant souvent au format "depot de 15000.00FCFA"
  static int? _extraireMontantPrincipalOM(String propre, String type) {
    if (type == 'revenu') {
      final regex = RegExp(r'depot de\s+([\d\s.]+)\s*fcfa');
      final match = regex.firstMatch(propre);
      if (match != null) return _parseMontantCentimes(match.group(1)!);
      return null;
    } else {
      final regex1 = RegExp(r'transfert de\s+([\d\s.]+)\s*fcfa');
      final regex2 = RegExp(r'retire\s+([\d\s.]+)\s*fcfa');
      final regex3 = RegExp(r'facture[^\d]*([\d\s.]+)\s*f(?:cfa)?\b');
      final match =
          regex1.firstMatch(propre) ??
          regex2.firstMatch(propre) ??
          regex3.firstMatch(propre);
      if (match != null) return _parseMontantCentimes(match.group(1)!);
      return null;
    }
  }

  static int? _extraireFraisOM(String propre) {
    // "Frais d'envoi:0.80Fcfa" ou "Frais retrait: 49.50FCFA" ou "Commission 0.00FCFA"
    final regex = RegExp(r"(?:frais[^:]*|commission)\s*:?\s*([\d\s.]+)\s*fcfa");
    final match = regex.firstMatch(propre);
    if (match == null) return null;
    return _parseMontantCentimes(match.group(1)!);
  }

  static String? _extraireContrepartieOM(String propre, String type) {
    // "de 786493621 REVENDEUR" → "REVENDEUR"
    // "vers 771939787 SAMBA a reussi" → "SAMBA"
    final regex = type == 'revenu'
        ? RegExp(r'de\s+\d+\s+([a-z]+)')
        : RegExp(r'vers\s+\d+\s+([a-z]+)');
    final match = regex.firstMatch(propre);
    if (match == null) return null;
    return match.group(1)!.toUpperCase();
  }

  static String? _extraireReferenceOM(String propre) {
    // "Ref:CI240818.1244.A21416"
    // Pattern : 2 lettres + 6 chiffres + . + 4 chiffres + . + 5-6 alphanum
    final regex = RegExp(r'ref\s*:?\s*([a-z]{2}\d{6}\.\d{4}\.[a-z0-9]{5,6})');
    final match = regex.firstMatch(propre);
    if (match == null) return null;
    return match.group(1)!.toUpperCase();
  }

  // ==================== HELPERS ====================

  /// Enlève les accents, met en minuscules
  static String _normaliser(String texte) {
    var t = texte.toLowerCase();
    t = t
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o');
    return t;
  }

  /// Convertit un montant texte en centimes
  static int? _parseMontantCentimes(String montantStr) {
    var s = montantStr.trim().replaceAll(' ', '');

    // Cas 1 : décimal (ex: "15000.00", "42.80")
    if (s.contains('.') && s.split('.').length == 2) {
      final parties = s.split('.');
      final decimales = parties[1];
      if (decimales.length <= 2 && decimales.isNotEmpty) {
        final valeur = double.tryParse(s);
        if (valeur == null) return null;
        return (valeur * 100).round();
      }
    }

    // Cas 2 : séparateur de milliers (ex: "40.000", "1.500.000")
    if (s.contains('.')) {
      final segments = s.split('.');
      final estSeparateurMilliers =
          segments.length >= 2 &&
          segments.skip(1).every((seg) => seg.length == 3);
      if (estSeparateurMilliers) {
        s = s.replaceAll('.', '');
      }
    }

    final entier = int.tryParse(s);
    if (entier == null) return null;
    return entier * 100;
  }

  /// Extrait les frais (Wave uniquement)
  static int? _extraireFrais(String propre) {
    final regex = RegExp(r"frais\s*:?\s*(?:d'envoi\s*:?\s*)?([\d\s.]+)\s*f");
    final match = regex.firstMatch(propre);
    if (match == null) return null;
    return _parseMontantCentimes(match.group(1)!);
  }

  /// Essaie d'extraire une date du type "09/07/2026 à 09h07"
  static DateTime? _extraireDate(String texte) {
    final regex = RegExp(r'(\d{2})/(\d{2})/(\d{4})\s+a\s+(\d{2})h(\d{2})');
    final match = regex.firstMatch(texte);
    if (match == null) return null;
    try {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
    } catch (_) {
      return null;
    }
  }
}
