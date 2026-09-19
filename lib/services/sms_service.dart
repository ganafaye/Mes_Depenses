import 'dart:async';
import 'package:flutter/services.dart';

/// Représente un SMS capté par le receiver Android
class SmsRecu {
  final String expediteur;
  final String contenu;

  SmsRecu({
    required this.expediteur,
    required this.contenu,
  });

  @override
  String toString() => '[$expediteur] $contenu';
}

/// Service qui fait le pont entre le SmsReceiver Android et Flutter
class SmsService {
  static const _eventChannel = EventChannel('mes_depenses/sms_stream');

  static Stream<SmsRecu>? _stream;

  /// Stream des SMS captés par le receiver Android
  static Stream<SmsRecu> get sms {
    _stream ??= _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return SmsRecu(
        expediteur: map['expediteur'] as String? ?? '',
        contenu: map['contenu'] as String? ?? '',
      );
    });
    return _stream!;
  }
}