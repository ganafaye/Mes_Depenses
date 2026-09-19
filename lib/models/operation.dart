class Operation {
  final int? id;
  final int compteId;
  final int? categorieId;
  final String type; // 'depense' ou 'revenu'
  final int montantCentimes; // en centimes, toujours positif
  final DateTime date;
  final String? note;
  final String origine; // 'manuelle', 'sms', 'notification', 'collee'

  Operation({
    this.id,
    required this.compteId,
    this.categorieId,
    required this.type,
    required this.montantCentimes,
    required this.date,
    this.note,
    this.origine = 'manuelle',
  });

  /// Signe de l'opération : -1 pour dépense, +1 pour revenu
  int get signe => type == 'depense' ? -1 : 1;

  /// Montant signé : négatif pour dépense, positif pour revenu
  int get montantSigne => montantCentimes * signe;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'compte_id': compteId,
      'categorie_id': categorieId,
      'type': type,
      'montant_centimes': montantCentimes,
      'date': date.toIso8601String(),
      'note': note,
      'origine': origine,
    };
  }

  factory Operation.fromMap(Map<String, dynamic> map) {
    return Operation(
      id: map['id'] as int?,
      compteId: map['compte_id'] as int,
      categorieId: map['categorie_id'] as int?,
      type: map['type'] as String,
      montantCentimes: map['montant_centimes'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      origine: map['origine'] as String? ?? 'manuelle',
    );
  }

  Operation copyWith({
    int? id,
    int? compteId,
    int? categorieId,
    String? type,
    int? montantCentimes,
    DateTime? date,
    String? note,
    String? origine,
  }) {
    return Operation(
      id: id ?? this.id,
      compteId: compteId ?? this.compteId,
      categorieId: categorieId ?? this.categorieId,
      type: type ?? this.type,
      montantCentimes: montantCentimes ?? this.montantCentimes,
      date: date ?? this.date,
      note: note ?? this.note,
      origine: origine ?? this.origine,
    );
  }
}