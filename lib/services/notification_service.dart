import 'dart:async';
import 'package:flutter/services.dart';

/// Représente une notification captée par le service Android
class NotificationRecue {
  final String packageName;
  final String titre;
  final String contenu;

  NotificationRecue({
    required this.packageName,
    required this.titre,
    required this.contenu,
  });

  @override
  String toString() => '[$packageName] $titre — $contenu';
}

/// Service qui fait le pont entre le NotificationListener Android et Flutter
class NotificationService {
  static const _methodChannel =
      MethodChannel('mes_depenses/notifications');
  static const _eventChannel =
      EventChannel('mes_depenses/notifications_stream');

  static Stream<NotificationRecue>? _stream;

  /// Stream des notifications captées par le service Android
  static Stream<NotificationRecue> get notifications {
    _stream ??= _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return NotificationRecue(
        packageName: map['package'] as String? ?? '',
        titre: map['titre'] as String? ?? '',
        contenu: map['contenu'] as String? ?? '',
      );
    });
    return _stream!;
  }

  /// Vérifie si la permission d'accès aux notifications est accordée
  static Future<bool> isPermissionGranted() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isPermissionGranted',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre les paramètres Android pour activer l'accès aux notifications
  static Future<void> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Demande à Android d'afficher une notification de confirmation
  /// discrète (sans montant) après l'enregistrement d'une opération.
  static Future<void> afficherConfirmation({
    required String operateur,
    required String type,
  }) async {
    try {
      await _methodChannel.invokeMethod('afficherConfirmation', {
        'operateur': operateur,
        'type': type,
      });
    } catch (_) {
      // Silencieux : si ça échoue, on ne bloque pas l'enregistrement
    }
  }

  // ==================== PERMISSION SMS ====================

  /// Vérifie si la permission SMS est accordée
  static Future<bool> isSmsPermissionGranted() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isSmsPermissionGranted',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Demande la permission SMS (affiche une popup Android)
  static Future<void> requestSmsPermission() async {
    try {
      await _methodChannel.invokeMethod('requestSmsPermission');
    } catch (_) {}
  }
}