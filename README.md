# Mes Depenses

Application mobile Flutter de gestion des finances personnelles, conçue pour aider l’utilisateur à suivre ses revenus, ses dépenses, ses comptes et ses statistiques de manière simple et rapide.

## Présentation

Mes Depenses permet à un utilisateur de :

- gérer plusieurs comptes;
- enregistrer des opérations de dépenses et de revenus;
- suivre le solde global et les soldes par compte;
- détecter automatiquement des opérations depuis les notifications et SMS;
- visualiser des statistiques et l’évolution financière;
- sécuriser l’accès avec un verrouillage PIN / biométrique;
- conserver les données localement sur le téléphone.

## Version actuelle

La version actuelle correspond à une V1 fonctionnelle et validée sur appareil réel. Elle couvre le cœur de la valeur produit avec une expérience fluide, claire et stable pour un usage quotidien.

## Fonctionnalités de la V1

- Onboarding d’introduction
- Accès sécurisé avec PIN / biométrie
- Gestion des comptes
- Ajout de revenus et dépenses
- Détection d’opérations via notifications / SMS
- Historique des opérations
- Dashboard avec synthèse financière
- Écran de statistiques
- Persistance locale avec SQLite
- Design minimaliste et moderne

## Stack technique

- Flutter
- Dart
- SQLite via sqflite
- Secure storage
- Android native integration for SMS / notification detection
- Material 3 UI

## Structure du projet

```text
lib/
  data/
  models/
  screens/
  services/
  widgets/
android/
ios/
web/
linux/
macos/
windows/
assets/
``` 

## Prérequis

Avant de lancer le projet, il faut installer :

- Flutter SDK
- Android Studio ou Android SDK
- Java / Android toolchain
- Un émulateur ou un téléphone Android réel

## Installation

1. Cloner le projet

```bash
git clone https://github.com/ganafaye/Mes_Depenses.git
```

2. Se placer dans le dossier du projet

```bash
cd mes_depenses
```

3. Installer les dépendances

```bash
flutter pub get
```

4. Lancer l’application

```bash
flutter run
```

## Génération du build Android release

```bash
flutter build apk --release
```

Le fichier APK généré se trouve dans :

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Sécurité

L’application intègre une protection d’accès via verrouillage PIN / biométrie et stocke des données localement sur l’appareil. La sécurité est pensée comme un élément central du produit.

## Statut du projet

- V1 : validée sur téléphone réel
- V2 : roadmap en cours avec optimisations, budgets, statistiques avancées, export et amélioration des performances

## Documentation complémentaire

- [docs/v1_livraison.md](docs/v1_livraison.md)
- [docs/v2_roadmap.md](docs/v2_roadmap.md)

## Licence

Ce projet est fourni à titre de projet personnel / applicatif de développement. La licence exacte peut être ajoutée selon le besoin du propriétaire du dépôt.

## Auteur

Projet développé par Gana Faye.
