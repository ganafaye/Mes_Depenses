class Compte {
  final int? id;
  final String nom;
  final String type; // 'wave', 'orange_money', 'cash', 'banque'
  final int soldeDepartCentimes; // en centimes (ex: 5000000 = 50000 FCFA)
  final DateTime dateDebut;
  final bool actif;
  final String? couleur; // ex: '#1E88E5'
  final String? icone;   // ex: 'wave_logo'

  Compte({
    this.id,
    required this.nom,
    required this.type,
    required this.soldeDepartCentimes,
    required this.dateDebut,
    this.actif = true,
    this.couleur,
    this.icone,
  });

  /// Convertit le Compte en Map pour l'insérer dans la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type': type,
      'solde_depart_centimes': soldeDepartCentimes,
      'date_debut': dateDebut.toIso8601String(),
      'actif': actif ? 1 : 0,
      'couleur': couleur,
      'icone': icone,
    };
  }

  /// Crée un Compte à partir d'une ligne de la base de données
  factory Compte.fromMap(Map<String, dynamic> map) {
    return Compte(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      type: map['type'] as String,
      soldeDepartCentimes: map['solde_depart_centimes'] as int,
      dateDebut: DateTime.parse(map['date_debut'] as String),
      actif: (map['actif'] as int) == 1,
      couleur: map['couleur'] as String?,
      icone: map['icone'] as String?,
    );
  }

  /// Retourne une copie modifiée du Compte
  Compte copyWith({
    int? id,
    String? nom,
    String? type,
    int? soldeDepartCentimes,
    DateTime? dateDebut,
    bool? actif,
    String? couleur,
    String? icone,
  }) {
    return Compte(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      type: type ?? this.type,
      soldeDepartCentimes: soldeDepartCentimes ?? this.soldeDepartCentimes,
      dateDebut: dateDebut ?? this.dateDebut,
      actif: actif ?? this.actif,
      couleur: couleur ?? this.couleur,
      icone: icone ?? this.icone,
    );
  }
}