// Outil d'administration des licences ETIKPRO (à utiliser par OMZAKREVO).
//
// Le fichier licences.json est publié dans le dépôt GitHub public
// omzakrevo/etikpro-licences. Il ne contient que l'empreinte (hash) des clés.
//
// Utilisation (depuis le dossier du projet) :
//   dart run tools/licence_admin.dart nouvelle "Volaille du Faso" 2027-10-31 [complet|etiquettes] [fichier]
//   dart run tools/licence_admin.dart prolonger ETK-XXXX-XXXX-XXXX-XXXX 2028-10-31 [fichier]
//   dart run tools/licence_admin.dart suspendre ETK-XXXX-XXXX-XXXX-XXXX [fichier]
//   dart run tools/licence_admin.dart reactiver ETK-XXXX-XXXX-XXXX-XXXX [fichier]
//   dart run tools/licence_admin.dart appareil ETK-XXXX-XXXX-XXXX-XXXX ID_APPAREIL [fichier]
//   dart run tools/licence_admin.dart liste [fichier]
//
// [fichier] = chemin de licences.json (par défaut : licences/licences.json).
// Ensuite : committez et poussez licences.json sur GitHub. Les applications
// prennent en compte le changement à leur prochaine vérification.

import 'dart:convert';
import 'dart:io';

import 'package:etikpro/core/licence_hash.dart';

const _defaultFile = 'licences/licences.json';

Map<String, dynamic> _read(String path) {
  final f = File(path);
  if (!f.existsSync()) return {'app': 'ETIKPRO', 'licences': []};
  return Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
}

void _write(String path, Map<String, dynamic> data) {
  data['misAJour'] = DateTime.now().toIso8601String().substring(0, 10);
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  stdout.writeln('✔ $path mis à jour. Pensez à le pousser sur GitHub.');
}

Map<String, dynamic> _find(Map<String, dynamic> data, String key) {
  final h = hashKey(key);
  for (final e in data['licences'] as List) {
    if (e['hash'] == h) return Map<String, dynamic>.from(e as Map);
  }
  stderr.writeln('Clé introuvable.');
  exit(1);
}

void _replace(Map<String, dynamic> data, Map<String, dynamic> entry) {
  final list = data['licences'] as List;
  final i = list.indexWhere((e) => e['hash'] == entry['hash']);
  list[i] = entry;
}

bool _isDate(String s) => DateTime.tryParse(s) != null && s.length == 10;

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln(File(Platform.script.toFilePath()).readAsLinesSync().take(18).join('\n'));
    return;
  }
  final cmd = args.first;
  String file(int i) => args.length > i ? args[i] : _defaultFile;

  switch (cmd) {
    case 'nouvelle':
      if (args.length < 3 || !_isDate(args[2])) {
        stderr.writeln('Usage : nouvelle "Nom entreprise" AAAA-MM-JJ [complet|etiquettes] [fichier]');
        exit(1);
      }
      final plan = args.length > 3 && !args[3].endsWith('.json') ? args[3] : 'complet';
      final path = args.length > 3 && args[3].endsWith('.json') ? args[3] : file(4);
      final data = _read(path);
      final key = generateKey();
      (data['licences'] as List).add({
        'hash': hashKey(key),
        'entreprise': args[1],
        'expire': args[2],
        'plan': plan,
        'modules': plan == 'etiquettes' ? ['etiquettes'] : <String>[],
        'actif': true,
        'appareils': <String>[],
        'creeLe': DateTime.now().toIso8601String().substring(0, 10),
      });
      _write(path, data);
      stdout
        ..writeln('')
        ..writeln('  Entreprise : ${args[1]}')
        ..writeln('  Expire le  : ${args[2]}  (formule $plan)')
        ..writeln('  CLÉ        : $key')
        ..writeln('')
        ..writeln('⚠ Notez cette clé et donnez-la au client : elle n\'est stockée nulle part en clair.');
    case 'prolonger':
      final data = _read(file(3));
      final e = _find(data, args[1])..['expire'] = args[2];
      _replace(data, e);
      _write(file(3), data);
    case 'suspendre':
    case 'reactiver':
      final data = _read(file(2));
      final e = _find(data, args[1])..['actif'] = cmd == 'reactiver';
      _replace(data, e);
      _write(file(2), data);
    case 'appareil':
      final data = _read(file(3));
      final e = _find(data, args[1]);
      final devices = List<String>.from(e['appareils'] ?? [])..add(args[2].toUpperCase());
      e['appareils'] = devices.toSet().toList();
      _replace(data, e);
      _write(file(3), data);
    case 'liste':
      final data = _read(file(1));
      for (final e in data['licences'] as List) {
        stdout.writeln('${e['actif'] == false ? '⛔' : '✅'} ${e['entreprise']}  '
            '— expire ${e['expire']}  — ${e['plan']}  — ${(e['appareils'] as List?)?.length ?? 0} appareil(s)');
      }
    default:
      stderr.writeln('Commande inconnue : $cmd');
      exit(1);
  }
}
