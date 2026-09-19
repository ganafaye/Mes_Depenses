# Mes Depenses - Documentation de livraison V1

## 1. Objectif de la V1
La V1 de l’application a pour objectif de livrer une base fonctionnelle, stable et testée sur appareil réel, permettant à un utilisateur de :

- installer et ouvrir l’application;
- découvrir le parcours d’onboarding;
- sécuriser l’accès via verrouillage et biométrie;
- consulter un tableau de bord de gestion des dépenses;
- détecter automatiquement des opérations depuis les notifications/SMS;
- visualiser les statistiques et l’évolution de ses finances;
- conserver les données localement via SQLite.

## 2. Fonctionnalités livrées dans la V1

### 2.1 Parcours d’accueil
- onboarding premium minimaliste;
- explication claire des fonctionnalités principales;
- navigation fluide vers l’application.

### 2.2 Sécurité
- écran de verrouillage;
- authentification PIN / biométrie;
- protection d’accès à l’application.

### 2.3 Dashboard
- aperçu rapide des soldes;
- synthèse des revenus/dépenses;
- vue d’ensemble de la situation financière.

### 2.4 Détection d’opérations
- analyse des messages / notifications;
- parsing des transactions détectées;
- ajout automatique dans la base de données;
- gestion des doublons et des opérations répétées.

### 2.5 Statistiques
- calcul des montants par catégorie;
- visualisation des tendances et évolution;
- mise à jour des données après ajout d’une nouvelle opération.

### 2.6 Persistance locale
- stockage local des informations importantes;
- gestion simple et fiable des données côté application.

## 3. Critères de validation V1
La V1 est considérée comme validée si les éléments suivants sont vérifiés sur vrai appareil :

- ouverture correcte de l’application;
- onboarding fonctionnel;
- verrouillage accessible et stable;
- navigation sans blocage majeur;
- ajout d’opération réussi;
- mise à jour visible sur le dashboard et les statistiques;
- aucun crash visible sur le parcours principal;
- expérience satisfaisante sur téléphone réel.

## 4. État de la V1
La V1 est livrable et validée sur un vrai téléphone, avec le parcours principal validé et les fonctionnalités essentielles fonctionnelles.

Cette version couvre le cœur de la valeur produit, avec une expérience utile, claire et stable pour un usage réel en conditions standard.

## 5. Limites connues de la V1
Les éléments suivants sont volontairement gardés hors scope de la V1 pour ne pas compromettre la stabilité :

- optimisation avancée de la base de données;
- refonte technique lourde du moteur de données;
- automatisations complexes de catégorisation;
- import/export avancé;
- optimisation de performance sur gros volumes de données;
- modules de reporting premium.

Ces points seront traités en V2.

## 6. Conclusion V1
La V1 constitue une version de base solide, fonctionnelle et utilisable, avec une expérience cohérente et un parcours principal validé. Elle correspond à un produit exploitable pour un premier lancement et une première validation utilisateur.
