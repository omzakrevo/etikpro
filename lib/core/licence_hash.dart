import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Fonctions partagées entre l'application et l'outil d'administration.
const licenceSalt = 'ETIKPRO:';

String normalizeKey(String key) =>
    key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String hashKey(String key) =>
    sha256.convert(utf8.encode(licenceSalt + normalizeKey(key))).toString();

/// Génère une clé du type ETK-7K2M-QX9P-4HVA-T3WD (sans 0/O/1/I pour éviter les confusions).
String generateKey([Random? rnd]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rnd ?? Random.secure();
  String block() => List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  return 'ETK-${block()}-${block()}-${block()}-${block()}';
}
