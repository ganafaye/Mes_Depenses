import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPinHash = 'pin_hash';
  static const _keyPinSalt = 'pin_salt';
  static const _keyBioEnabled = 'bio_enabled';
  static const _keyNom = 'nom_utilisateur';
  static const _keyConfirmationActive = 'confirmation_active';
  static const _keyOnboardingTermine = 'onboarding_termine';

  // ==================== PIN ====================

  /// Vérifie si un PIN a déjà été défini
  static Future<bool> hasPin() async {
    final hash = await _storage.read(key: _keyPinHash);
    return hash != null;
  }

  /// Définit un nouveau PIN (hash + salt)
  static Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPinHash, value: hash);
  }

  /// Vérifie si le PIN est correct
  static Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _keyPinSalt);
    final hash = await _storage.read(key: _keyPinHash);
    if (salt == null || hash == null) return false;
    return _hashPin(pin, salt) == hash;
  }

  /// Supprime le PIN (désactive le verrouillage)
  static Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    await _storage.delete(key: _keyBioEnabled);
  }

  // ==================== BIOMÉTRIE ====================

  static Future<bool> isBioEnabled() async {
    final value = await _storage.read(key: _keyBioEnabled);
    return value == 'true';
  }

  static Future<void> setBioEnabled(bool enabled) async {
    await _storage.write(key: _keyBioEnabled, value: enabled.toString());
  }

  // ==================== PROFIL ====================

  static Future<String> getNom() async {
    return await _storage.read(key: _keyNom) ?? 'Gana';
  }

  static Future<void> setNom(String nom) async {
    await _storage.write(key: _keyNom, value: nom);
  }

  // ==================== PRÉFÉRENCES DÉTECTION ====================

  /// Vérifie si la notification de confirmation est activée
  /// (activée par défaut)
  static Future<bool> isConfirmationActive() async {
    final value = await _storage.read(key: _keyConfirmationActive);
    return value != 'false';
  }

  /// Active ou désactive la notification de confirmation
  static Future<void> setConfirmationActive(bool active) async {
    await _storage.write(
      key: _keyConfirmationActive,
      value: active.toString(),
    );
  }

  // ==================== ONBOARDING ====================

  /// Vérifie si l'onboarding a déjà été fait
  static Future<bool> isOnboardingTermine() async {
    final value = await _storage.read(key: _keyOnboardingTermine);
    return value == 'true';
  }

  /// Marque l'onboarding comme terminé
  static Future<void> setOnboardingTermine(bool termine) async {
    await _storage.write(
      key: _keyOnboardingTermine,
      value: termine.toString(),
    );
  }

  // ==================== HELPERS ====================

  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }
}