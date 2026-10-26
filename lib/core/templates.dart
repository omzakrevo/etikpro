import 'dart:convert';

import 'models.dart';

int _hex(String? s, int def) {
  if (s == null) return def;
  var h = s.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return int.tryParse(h, radix: 16) ?? def;
}

String _toHex(int c) =>
    '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Modèle de document (facture, devis, bordereau...). Importable/exportable en JSON.
class DocTemplate {
  String id;
  String name;
  List<DocType> docTypes; // vide = tous les types
  int primaryColor;
  int accentColor;
  int textColor;
  String font; // helvetica | times | courier
  String tableStyle; // striped | grid | minimal
  String titleStyle; // band | underline | plain
  String titleAlign; // left | center | right
  bool showLogo;
  bool showCompanyBlock; // bloc texte entreprise si pas d'en-tête image
  double headerMaxHeightMm;
  double footerMaxHeightMm;
  double marginMm;
  double fontSize;
  bool showAmountInWords;
  bool showSignatures;
  String signatureLeft;
  String signatureRight;
  String footerText;
  bool builtin;

  DocTemplate({
    required this.id,
    required this.name,
    List<DocType>? docTypes,
    this.primaryColor = 0xFF1F4E79,
    this.accentColor = 0xFFE8EEF5,
    this.textColor = 0xFF222222,
    this.font = 'helvetica',
    this.tableStyle = 'striped',
    this.titleStyle = 'band',
    this.titleAlign = 'right',
    this.showLogo = true,
    this.showCompanyBlock = true,
    this.headerMaxHeightMm = 35,
    this.footerMaxHeightMm = 22,
    this.marginMm = 12,
    this.fontSize = 9.5,
    this.showAmountInWords = true,
    this.showSignatures = true,
    this.signatureLeft = 'Le client',
    this.signatureRight = 'La direction',
    this.footerText = '',
    this.builtin = false,
  }) : docTypes = docTypes ?? [];

  bool appliesTo(DocType t) => docTypes.isEmpty || docTypes.contains(t);

  Map<String, dynamic> toJson() => {
        'kind': 'document',
        'id': id,
        'name': name,
        'docTypes': docTypes.map((e) => e.name).toList(),
        'primaryColor': _toHex(primaryColor),
        'accentColor': _toHex(accentColor),
        'textColor': _toHex(textColor),
        'font': font,
        'tableStyle': tableStyle,
        'titleStyle': titleStyle,
        'titleAlign': titleAlign,
        'showLogo': showLogo,
        'showCompanyBlock': showCompanyBlock,
        'headerMaxHeightMm': headerMaxHeightMm,
        'footerMaxHeightMm': footerMaxHeightMm,
        'marginMm': marginMm,
        'fontSize': fontSize,
        'showAmountInWords': showAmountInWords,
        'showSignatures': showSignatures,
        'signatureLeft': signatureLeft,
        'signatureRight': signatureRight,
        'footerText': footerText,
      };

  factory DocTemplate.fromJson(Map<String, dynamic> j, {bool builtin = false}) {
    double d(String k, double def) =>
        j[k] is num ? (j[k] as num).toDouble() : double.tryParse('${j[k]}') ?? def;
    return DocTemplate(
      id: (j['id'] ?? newId()).toString(),
      name: (j['name'] ?? 'Modèle importé').toString(),
      docTypes: ((j['docTypes'] as List?) ?? [])
          .map((e) => DocType.values.where((t) => t.name == e))
          .expand((e) => e)
          .toList(),
      primaryColor: _hex(j['primaryColor'], 0xFF1F4E79),
      accentColor: _hex(j['accentColor'], 0xFFE8EEF5),
      textColor: _hex(j['textColor'], 0xFF222222),
      font: j['font'] ?? 'helvetica',
      tableStyle: j['tableStyle'] ?? 'striped',
      titleStyle: j['titleStyle'] ?? 'band',
      titleAlign: j['titleAlign'] ?? 'right',
      showLogo: j['showLogo'] ?? true,
      showCompanyBlock: j['showCompanyBlock'] ?? true,
      headerMaxHeightMm: d('headerMaxHeightMm', 35),
      footerMaxHeightMm: d('footerMaxHeightMm', 22),
      marginMm: d('marginMm', 12),
      fontSize: d('fontSize', 9.5),
      showAmountInWords: j['showAmountInWords'] ?? true,
      showSignatures: j['showSignatures'] ?? true,
      signatureLeft: j['signatureLeft'] ?? 'Le client',
      signatureRight: j['signatureRight'] ?? 'La direction',
      footerText: j['footerText'] ?? '',
      builtin: builtin,
    );
  }
}

/// Style d'étiquette. Importable/exportable en JSON.
class LabelStyle {
  String id;
  String name;
  bool companyBand; // nom de l'entreprise sur bande noire
  bool showLogo; // logo de l'entreprise (si défini)
  bool showPhone;
  bool showQr;
  bool showBorder;
  bool showProduct;
  bool showWeight;
  bool showLot;
  bool showPrice;
  double fontScale;
  String expiryLabel; // "À consommer jusqu'au", "Date de péremption"
  String tempLabel; // "Conservation"
  String durationLabel; // "Durée"
  bool builtin;

  LabelStyle({
    required this.id,
    required this.name,
    this.companyBand = true,
    this.showLogo = true,
    this.showPhone = true,
    this.showQr = false,
    this.showBorder = false,
    this.showProduct = true,
    this.showWeight = true,
    this.showLot = true,
    this.showPrice = false,
    this.fontScale = 1,
    this.expiryLabel = 'Date de péremption',
    this.tempLabel = 'Conservation',
    this.durationLabel = 'Durée de conservation',
    this.builtin = false,
  });

  Map<String, dynamic> toJson() => {
        'kind': 'etiquette',
        'id': id,
        'name': name,
        'companyBand': companyBand,
        'showLogo': showLogo,
        'showPhone': showPhone,
        'showQr': showQr,
        'showBorder': showBorder,
        'showProduct': showProduct,
        'showWeight': showWeight,
        'showLot': showLot,
        'showPrice': showPrice,
        'fontScale': fontScale,
        'expiryLabel': expiryLabel,
        'tempLabel': tempLabel,
        'durationLabel': durationLabel,
      };

  factory LabelStyle.fromJson(Map<String, dynamic> j, {bool builtin = false}) =>
      LabelStyle(
        id: (j['id'] ?? newId()).toString(),
        name: (j['name'] ?? 'Style importé').toString(),
        companyBand: j['companyBand'] ?? true,
        showLogo: j['showLogo'] ?? true,
        showPhone: j['showPhone'] ?? true,
        showQr: j['showQr'] ?? false,
        showBorder: j['showBorder'] ?? false,
        showProduct: j['showProduct'] ?? true,
        showWeight: j['showWeight'] ?? true,
        showLot: j['showLot'] ?? true,
        showPrice: j['showPrice'] ?? false,
        fontScale: (j['fontScale'] is num) ? (j['fontScale'] as num).toDouble() : 1,
        expiryLabel: j['expiryLabel'] ?? 'Date de péremption',
        tempLabel: j['tempLabel'] ?? 'Conservation',
        durationLabel: j['durationLabel'] ?? 'Durée de conservation',
        builtin: builtin,
      );
}

final builtinDocTemplates = <DocTemplate>[
  DocTemplate(id: 'classique', name: 'Classique bleu', builtin: true),
  DocTemplate(
    id: 'moderne',
    name: 'Moderne vert',
    primaryColor: 0xFF1B7F5B,
    accentColor: 0xFFE6F4EE,
    titleStyle: 'underline',
    titleAlign: 'left',
    tableStyle: 'striped',
    builtin: true,
  ),
  DocTemplate(
    id: 'minimal',
    name: 'Minimal noir',
    primaryColor: 0xFF111111,
    accentColor: 0xFFF2F2F2,
    titleStyle: 'plain',
    titleAlign: 'center',
    tableStyle: 'minimal',
    builtin: true,
  ),
  DocTemplate(
    id: 'elegant',
    name: 'Élégant bordeaux',
    primaryColor: 0xFF7A1F2B,
    accentColor: 0xFFF7ECEE,
    font: 'times',
    fontSize: 10.5,
    titleStyle: 'underline',
    titleAlign: 'center',
    tableStyle: 'grid',
    builtin: true,
  ),
  DocTemplate(
    id: 'orange',
    name: 'Dynamique orange',
    primaryColor: 0xFFD9601A,
    accentColor: 0xFFFDF0E7,
    titleStyle: 'band',
    titleAlign: 'left',
    tableStyle: 'grid',
    builtin: true,
  ),
  DocTemplate(
    id: 'bordereau_simple',
    name: 'Bordereau simple',
    docTypes: [DocType.bordereau, DocType.decharge],
    primaryColor: 0xFF333333,
    accentColor: 0xFFEFEFEF,
    titleStyle: 'band',
    titleAlign: 'center',
    tableStyle: 'grid',
    showAmountInWords: false,
    signatureLeft: 'Livré par',
    signatureRight: 'Reçu par (nom, signature, date)',
    builtin: true,
  ),
];

final builtinLabelStyles = <LabelStyle>[
  LabelStyle(id: 'standard', name: 'Standard', builtin: true),
  LabelStyle(
    id: 'compact',
    name: 'Compact (petites étiquettes)',
    companyBand: true,
    showWeight: false,
    showLot: false,
    fontScale: 0.9,
    builtin: true,
  ),
  LabelStyle(
    id: 'qr',
    name: 'Avec QR code de traçabilité',
    showQr: true,
    builtin: true,
  ),
  LabelStyle(
    id: 'encadre',
    name: 'Encadré, sans bande',
    companyBand: false,
    showBorder: true,
    builtin: true,
  ),
];

/// Résultat d'un import JSON de modèles.
class TemplateImport {
  final List<DocTemplate> docs;
  final List<LabelStyle> labels;
  TemplateImport(this.docs, this.labels);
}

/// Lit un fichier JSON contenant un modèle, une liste de modèles,
/// ou un objet {"modeles": [...]}.
TemplateImport parseTemplatesJson(String source) {
  final data = jsonDecode(source);
  List items;
  if (data is List) {
    items = data;
  } else if (data is Map && (data['modeles'] ?? data['templates']) is List) {
    items = (data['modeles'] ?? data['templates']) as List;
  } else if (data is Map) {
    items = [data];
  } else {
    throw const FormatException('Format JSON non reconnu');
  }
  final docs = <DocTemplate>[];
  final labels = <LabelStyle>[];
  for (final raw in items) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final kind = (m['kind'] ?? m['type_modele'] ?? 'document').toString();
    if (kind == 'etiquette' || kind == 'label') {
      labels.add(LabelStyle.fromJson(m));
    } else {
      docs.add(DocTemplate.fromJson(m));
    }
  }
  if (docs.isEmpty && labels.isEmpty) {
    throw const FormatException('Aucun modèle trouvé dans le fichier');
  }
  return TemplateImport(docs, labels);
}
