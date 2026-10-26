import 'dart:convert';

import 'package:http/http.dart' as http;

import 'licence_hash.dart';
import 'models.dart';
import 'store.dart';

export 'licence_hash.dart';

/// Configuration des licences.
///
/// Les licences sont listées dans un fichier JSON hébergé sur GitHub
/// (dépôt public `omzakrevo/etikpro-licences`, fichier `licences.json`).
/// Seule l'empreinte SHA-256 de chaque clé y figure : la clé elle-même
/// n'est jamais publiée. Pour ajouter / suspendre / prolonger un client,
/// il suffit de modifier ce fichier sur GitHub (voir tools/licence_admin.dart).
class LicenceConfig {
  static const url =
      'https://raw.githubusercontent.com/omzakrevo/etikpro-licences/main/licences.json';
  static const offlineGraceDays = 15; // durée max sans connexion
  static const supportPhone = 'OMZAKREVO INFORMATIQUE';
}

class LicenceInfo {
  final String company;
  final DateTime expires;
  final String plan;
  final List<String> modules;
  final DateTime checkedAt;
  final bool offline;

  LicenceInfo({
    required this.company,
    required this.expires,
    required this.plan,
    required this.modules,
    required this.checkedAt,
    this.offline = false,
  });

  int get daysLeft => expires.difference(_today()).inDays;
  bool has(String module) => modules.isEmpty || modules.contains(module);

  Map<String, dynamic> toJson() => {
        'company': company,
        'expires': expires.toIso8601String(),
        'plan': plan,
        'modules': modules,
        'checkedAt': checkedAt.toIso8601String(),
      };

  factory LicenceInfo.fromJson(Map<String, dynamic> j, {bool offline = false}) =>
      LicenceInfo(
        company: j['company'] ?? '',
        expires: DateTime.parse(j['expires']),
        plan: j['plan'] ?? '',
        modules: List<String>.from(j['modules'] ?? []),
        checkedAt: DateTime.parse(j['checkedAt']),
        offline: offline,
      );
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class LicenceResult {
  final LicenceInfo? info;
  final String? error;
  LicenceResult.ok(this.info) : error = null;
  LicenceResult.fail(this.error) : info = null;
  bool get valid => info != null;
}

/// Vérifie une clé contre le fichier JSON (testable sans réseau).
LicenceResult checkAgainstList(
  String key,
  Map<String, dynamic> data,
  String deviceId,
) {
  final h = hashKey(key);
  final list = (data['licences'] as List?) ?? [];
  for (final raw in list) {
    final e = Map<String, dynamic>.from(raw as Map);
    if ((e['hash'] ?? '').toString().toLowerCase() != h) continue;
    if (e['actif'] == false) {
      return LicenceResult.fail(
          'Cette licence est suspendue. Contactez ${LicenceConfig.supportPhone}.');
    }
    final exp = DateTime.tryParse('${e['expire']}');
    if (exp == null) return LicenceResult.fail('Licence mal configurée (date).');
    if (exp.isBefore(_today())) {
      return LicenceResult.fail(
          'Licence expirée depuis le ${exp.day}/${exp.month}/${exp.year}. Renouvelez votre abonnement.');
    }
    final devices = List<String>.from(e['appareils'] ?? []);
    if (devices.isNotEmpty && !devices.contains(deviceId)) {
      return LicenceResult.fail(
          "Cet appareil n'est pas autorisé pour cette licence.\nIdentifiant de l'appareil : $deviceId");
    }
    return LicenceResult.ok(LicenceInfo(
      company: (e['entreprise'] ?? '').toString(),
      expires: exp,
      plan: (e['plan'] ?? 'complet').toString(),
      modules: List<String>.from(e['modules'] ?? []),
      checkedAt: DateTime.now(),
    ));
  }
  return LicenceResult.fail('Clé de licence inconnue.');
}

class LicenceService {
  LicenceService._();
  static final LicenceService I = LicenceService._();

  LicenceInfo? current;
  http.Client client = http.Client();

  AppStore get _s => AppStore.I;

  String get deviceId {
    var id = _s.getRaw('deviceId');
    if (id == null) {
      id = newId().substring(0, 8).toUpperCase();
      _s.putRaw('deviceId', id);
    }
    return id;
  }

  String? get savedKey => _s.getRaw('licenceKey');

  Future<Map<String, dynamic>> _fetchList() async {
    final uri = Uri.parse(
        '${LicenceConfig.url}?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');
    final r = await client.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('Serveur de licences indisponible (${r.statusCode})');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// Active une nouvelle clé (connexion internet obligatoire).
  Future<LicenceResult> activate(String key) async {
    try {
      final data = await _fetchList();
      final res = checkAgainstList(key, data, deviceId);
      if (res.valid) {
        await _s.putRaw('licenceKey', normalizeKey(key));
        await _s.putRaw('licenceCache', jsonEncode(res.info!.toJson()));
        current = res.info;
        if (_s.company.name.isEmpty && res.info!.company.isNotEmpty) {
          _s.company.name = res.info!.company;
          await _s.saveCompany();
        }
      }
      return res;
    } catch (e) {
      return LicenceResult.fail(
          "Impossible de vérifier la licence. Vérifiez votre connexion internet.\n($e)");
    }
  }

  /// Vérification au démarrage : en ligne si possible, sinon cache hors ligne.
  Future<LicenceResult> verify() async {
    final key = savedKey;
    if (key == null) return LicenceResult.fail(null);
    try {
      final data = await _fetchList();
      final res = checkAgainstList(key, data, deviceId);
      if (res.valid) {
        await _s.putRaw('licenceCache', jsonEncode(res.info!.toJson()));
        current = res.info;
      } else {
        await _s.deleteRaw('licenceCache');
        current = null;
      }
      return res;
    } catch (_) {
      // Hors ligne : on accepte le cache récent.
      final raw = _s.getRaw('licenceCache');
      if (raw == null) {
        return LicenceResult.fail(
            'Connexion internet requise pour vérifier la licence.');
      }
      final cached = LicenceInfo.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw)),
          offline: true);
      final age = DateTime.now().difference(cached.checkedAt).inDays;
      if (cached.expires.isBefore(_today())) {
        return LicenceResult.fail('Licence expirée. Renouvelez votre abonnement.');
      }
      if (age > LicenceConfig.offlineGraceDays) {
        return LicenceResult.fail(
            'Licence non vérifiée depuis $age jours. Connectez-vous à internet.');
      }
      current = cached;
      return LicenceResult.ok(cached);
    }
  }

  Future<void> logout() async {
    await _s.deleteRaw('licenceKey');
    await _s.deleteRaw('licenceCache');
    current = null;
  }
}
