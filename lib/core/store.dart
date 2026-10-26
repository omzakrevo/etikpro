import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'models.dart';
import 'templates.dart';

/// Stockage local (Hive : Android, Windows et Web) + état de l'application.
/// Aucune base de données distante : les données restent chez l'entreprise.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore I = AppStore._();

  late Box<String> _box;

  Company company = Company();
  PrinterSettings printer = PrinterSettings();
  final List<Product> products = [];
  final List<Client> clients = [];
  final List<CommercialDoc> docs = [];
  final List<DocTemplate> customDocTemplates = [];
  final List<LabelStyle> customLabelStyles = [];
  final List<LabelPrintLog> printLogs = [];

  Future<void> init() async {
    await Hive.initFlutter('etikpro');
    _box = await Hive.openBox<String>('data');
    _load();
  }

  /// Pour les tests : stockage en mémoire.
  @visibleForTesting
  Future<void> initForTest(String path) async {
    Hive.init(path);
    _box = await Hive.openBox<String>('data_test');
    await _box.clear();
    _load();
  }

  T? _get<T>(String key, T Function(Map<String, dynamic>) f) {
    final s = _box.get(key);
    if (s == null) return null;
    try {
      return f(Map<String, dynamic>.from(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  List<T> _getList<T>(String key, T Function(Map<String, dynamic>) f) {
    final s = _box.get(key);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _load() {
    company = _get('company', Company.fromJson) ?? Company();
    printer = _get('printer', PrinterSettings.fromJson) ?? PrinterSettings();
    products
      ..clear()
      ..addAll(_getList('products', Product.fromJson));
    clients
      ..clear()
      ..addAll(_getList('clients', Client.fromJson));
    docs
      ..clear()
      ..addAll(_getList('docs', CommercialDoc.fromJson));
    customDocTemplates
      ..clear()
      ..addAll(_getList('docTemplates', (j) => DocTemplate.fromJson(j)));
    customLabelStyles
      ..clear()
      ..addAll(_getList('labelStyles', (j) => LabelStyle.fromJson(j)));
    printLogs
      ..clear()
      ..addAll(_getList('printLogs', LabelPrintLog.fromJson));
  }

  Future<void> _put(String key, Object value) =>
      _box.put(key, jsonEncode(value));

  String? getRaw(String key) => _box.get(key);
  Future<void> putRaw(String key, String value) => _box.put(key, value);
  Future<void> deleteRaw(String key) => _box.delete(key);

  // ---------- Entreprise / imprimante ----------
  Future<void> saveCompany() async {
    await _put('company', company.toJson());
    notifyListeners();
  }

  Future<void> savePrinter() async {
    await _put('printer', printer.toJson());
    notifyListeners();
  }

  // ---------- Formats d'étiquettes ----------
  List<LabelFormat> get labelFormats => [...printer.customFormats, ...builtinLabelFormats];

  LabelFormat formatById(String id) => labelFormats.firstWhere((f) => f.id == id,
      orElse: () => builtinLabelFormats.firstWhere((f) => f.id == 'tspl_40x30'));

  Future<void> saveCustomFormat(LabelFormat f) async {
    printer.customFormats.removeWhere((e) => e.id == f.id);
    printer.customFormats.insert(0, f);
    printer.defaultFormatId = f.id;
    await savePrinter();
  }

  Future<void> deleteCustomFormat(String id) async {
    printer.customFormats.removeWhere((e) => e.id == id);
    if (printer.defaultFormatId == id) printer.defaultFormatId = 'tspl_40x30';
    await savePrinter();
  }

  // ---------- Produits ----------
  Future<void> upsertProduct(Product p) async {
    final i = products.indexWhere((e) => e.id == p.id);
    i >= 0 ? products[i] = p : products.add(p);
    await _put('products', products.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    products.removeWhere((e) => e.id == id);
    await _put('products', products.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------- Clients ----------
  Future<void> upsertClient(Client c) async {
    final i = clients.indexWhere((e) => e.id == c.id);
    i >= 0 ? clients[i] = c : clients.add(c);
    await _put('clients', clients.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteClient(String id) async {
    clients.removeWhere((e) => e.id == id);
    await _put('clients', clients.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------- Documents ----------
  String nextNumber(DocType t, {DateTime? date}) {
    final year = (date ?? DateTime.now()).year;
    final key = '${t.name}_$year';
    final n = (company.counters[key] ?? 0) + 1;
    final prefix = company.prefixes[t.name] ?? t.defaultPrefix;
    return '$prefix-$year-${n.toString().padLeft(4, '0')}';
  }

  Future<void> _consumeNumber(DocType t, DateTime date) async {
    final key = '${t.name}_${date.year}';
    company.counters[key] = (company.counters[key] ?? 0) + 1;
    await _put('company', company.toJson());
  }

  Future<void> upsertDoc(CommercialDoc d) async {
    final i = docs.indexWhere((e) => e.id == d.id);
    if (i < 0) {
      if (d.number.isEmpty || d.number == nextNumber(d.type, date: d.date)) {
        d.number = nextNumber(d.type, date: d.date);
        await _consumeNumber(d.type, d.date);
      }
      docs.add(d);
    } else {
      docs[i] = d;
    }
    await _put('docs', docs.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteDoc(String id) async {
    docs.removeWhere((e) => e.id == id);
    await _put('docs', docs.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Convertit un document : devis → proforma → facture → bordereau/décharge.
  Future<CommercialDoc> convertDoc(CommercialDoc src, DocType target) async {
    final j = src.toJson();
    final d = CommercialDoc.fromJson(j)
      ..id = newId()
      ..type = target
      ..number = ''
      ..date = DateTime.now()
      ..sourceId = src.id
      ..sourceNumber = src.number
      ..convertedTo = []
      ..status = 'brouillon'
      ..templateId = defaultTemplateFor(target).id
      ..signatures = company.signatoriesFor(target)
      ..showStamp = company.stampB64 != null && company.stampTypes.contains(target.name)
      ..stickerB64 = null;
    if (target == DocType.decharge && d.dischargeText.isEmpty) {
      d.dischargeText = defaultDischargeText(d);
    }
    if (target == DocType.facture) d.conditions = '';
    await upsertDoc(d);
    src.convertedTo.add(d.number);
    src.status = 'converti';
    await upsertDoc(src);
    return d;
  }

  String defaultDischargeText(CommercialDoc d) {
    final ref = d.sourceNumber != null ? ' (réf. ${d.sourceNumber})' : '';
    return 'Je soussigné(e) ………………………………………, agissant pour le compte de '
        '${d.clientName.isEmpty ? '………………………' : d.clientName}, reconnais avoir reçu '
        'de ${company.name.isEmpty ? 'la société' : company.name} les articles '
        'ci-dessous désignés$ref, en bon état et en quantité conforme.\n'
        'En foi de quoi, la présente décharge est établie pour servir et valoir ce que de droit.';
  }

  // ---------- Modèles ----------
  List<DocTemplate> get allDocTemplates =>
      [...builtinDocTemplates, ...customDocTemplates];
  List<LabelStyle> get allLabelStyles =>
      [...builtinLabelStyles, ...customLabelStyles];

  DocTemplate templateById(String id) => allDocTemplates
      .firstWhere((t) => t.id == id, orElse: () => builtinDocTemplates.first);

  DocTemplate defaultTemplateFor(DocType t) {
    final id = company.defaultTemplates[t.name];
    if (id != null) {
      final m = allDocTemplates.where((e) => e.id == id);
      if (m.isNotEmpty) return m.first;
    }
    if (t == DocType.bordereau || t == DocType.decharge) {
      return templateById('bordereau_simple');
    }
    return builtinDocTemplates.first;
  }

  LabelStyle labelStyleById(String id) => allLabelStyles
      .firstWhere((t) => t.id == id, orElse: () => builtinLabelStyles.first);

  Future<int> importTemplates(TemplateImport imp) async {
    for (final t in imp.docs) {
      if (builtinDocTemplates.any((b) => b.id == t.id)) t.id = newId();
      customDocTemplates.removeWhere((e) => e.id == t.id);
      customDocTemplates.add(t);
    }
    for (final s in imp.labels) {
      if (builtinLabelStyles.any((b) => b.id == s.id)) s.id = newId();
      customLabelStyles.removeWhere((e) => e.id == s.id);
      customLabelStyles.add(s);
    }
    await _put('docTemplates', customDocTemplates.map((e) => e.toJson()).toList());
    await _put('labelStyles', customLabelStyles.map((e) => e.toJson()).toList());
    notifyListeners();
    return imp.docs.length + imp.labels.length;
  }

  Future<void> deleteDocTemplate(String id) async {
    customDocTemplates.removeWhere((e) => e.id == id);
    await _put('docTemplates', customDocTemplates.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteLabelStyle(String id) async {
    customLabelStyles.removeWhere((e) => e.id == id);
    await _put('labelStyles', customLabelStyles.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------- Historique d'impression ----------
  Future<void> addPrintLog(LabelPrintLog l) async {
    printLogs.insert(0, l);
    if (printLogs.length > 1000) printLogs.removeRange(1000, printLogs.length);
    await _put('printLogs', printLogs.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------- Sauvegarde complète ----------
  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'app': 'ETIKPRO',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'company': company.toJson(),
        'printer': printer.toJson(),
        'products': products.map((e) => e.toJson()).toList(),
        'clients': clients.map((e) => e.toJson()).toList(),
        'docs': docs.map((e) => e.toJson()).toList(),
        'docTemplates': customDocTemplates.map((e) => e.toJson()).toList(),
        'labelStyles': customLabelStyles.map((e) => e.toJson()).toList(),
        'printLogs': printLogs.map((e) => e.toJson()).toList(),
      });

  Future<void> importBackup(String source) async {
    final j = Map<String, dynamic>.from(jsonDecode(source));
    if (j['app'] != 'ETIKPRO') {
      throw const FormatException("Ce fichier n'est pas une sauvegarde ETIKPRO");
    }
    for (final k in [
      'company',
      'printer',
      'products',
      'clients',
      'docs',
      'docTemplates',
      'labelStyles',
      'printLogs'
    ]) {
      if (j[k] != null) await _put(k, j[k]);
    }
    _load();
    notifyListeners();
  }
}
