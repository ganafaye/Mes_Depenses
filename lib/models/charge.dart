class Charge {
  final int? id;
  final String libelle;
  final int montantCentimes;
  final DateTime? echeance;
  final bool payee;

  Charge({
    this.id,
    required this.libelle,
    required this.montantCentimes,
    this.echeance,
    this.payee = false,
  });

  /// Convertit la Charge en Map pour l'insérer dans la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'libelle': libelle,
      'montant_centimes': montantCentimes,
      'echeance': echeance?.toIso8601String(),
      'payee': payee ? 1 : 0,
    };
  }

  /// Crée une Charge à partir d'une ligne de la base de données
  factory Charge.fromMap(Map<String, dynamic> map) {
    return Charge(
      id: map['id'] as int?,
      libelle: map['libelle'] as String,
      montantCentimes: map['montant_centimes'] as int,
      echeance: map['echeance'] != null
          ? DateTime.parse(map['echeance'] as String)
          : null,
      payee: (map['payee'] as int) == 1,
    );
  }

  /// Retourne une copie modifiée de la Charge
  Charge copyWith({
    int? id,
    String? libelle,
    int? montantCentimes,
    DateTime? echeance,
    bool? payee,
  }) {
    return Charge(
      id: id ?? this.id,
      libelle: libelle ?? this.libelle,
      montantCentimes: montantCentimes ?? this.montantCentimes,
      echeance: echeance ?? this.echeance,
      payee: payee ?? this.payee,
    );
  }
}