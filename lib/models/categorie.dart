class Categorie {
  final int? id;
  final String nom;
  final String type; // 'depense' ou 'revenu'
  final String icone; // nom de l'icône (utilisé pour l'affichage)
  final String couleur; // code hex ex: '#FF6F00'

  Categorie({
    this.id,
    required this.nom,
    required this.type,
    required this.icone,
    required this.couleur,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type': type,
      'icone': icone,
      'couleur': couleur,
    };
  }

  factory Categorie.fromMap(Map<String, dynamic> map) {
    return Categorie(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      type: map['type'] as String,
      icone: map['icone'] as String,
      couleur: map['couleur'] as String,
    );
  }

  /// Liste des catégories par défaut de dépenses
  static List<Categorie> depensesParDefaut() => [
        Categorie(nom: 'Alimentation & courses', type: 'depense', icone: 'restaurant', couleur: '#FF6F00'),
        Categorie(nom: 'Transport & carburant', type: 'depense', icone: 'directions_car', couleur: '#F9A825'),
        Categorie(nom: 'Factures', type: 'depense', icone: 'receipt', couleur: '#1976D2'),
        Categorie(nom: 'Logement', type: 'depense', icone: 'home', couleur: '#5E35B1'),
        Categorie(nom: 'Santé', type: 'depense', icone: 'local_hospital', couleur: '#E53935'),
        Categorie(nom: 'Shopping & achats', type: 'depense', icone: 'shopping_bag', couleur: '#EC407A'),
        Categorie(nom: 'Études', type: 'depense', icone: 'school', couleur: '#00897B'),
        Categorie(nom: 'Envois & aide familiale', type: 'depense', icone: 'send', couleur: '#FB8C00'),
        Categorie(nom: 'Loisirs', type: 'depense', icone: 'sports_esports', couleur: '#7CB342'),
        Categorie(nom: 'Frais de service', type: 'depense', icone: 'build', couleur: '#6D4C41'),
        Categorie(nom: 'Autres dépenses', type: 'depense', icone: 'more_horiz', couleur: '#757575'),
        Categorie(nom: 'À classer', type: 'depense', icone: 'help_outline', couleur: '#9E9E9E'),
      ];

  /// Liste des catégories par défaut de revenus
  static List<Categorie> revenusParDefaut() => [
        Categorie(nom: 'Salaire', type: 'revenu', icone: 'work', couleur: '#43A047'),
        Categorie(nom: 'Activité indépendante', type: 'revenu', icone: 'storefront', couleur: '#00ACC1'),
        Categorie(nom: 'Argent reçu', type: 'revenu', icone: 'call_received', couleur: '#1976D2'),
        Categorie(nom: 'Autres revenus', type: 'revenu', icone: 'more_horiz', couleur: '#757575'),
      ];
}