import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

double _d(dynamic v, [double def = 0]) =>
    v == null ? def : (v is num ? v.toDouble() : double.tryParse('$v') ?? def);
int _i(dynamic v, [int def = 0]) =>
    v == null ? def : (v is num ? v.toInt() : int.tryParse('$v') ?? def);
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

/// Signataires d'un document : titre (« La Direction », « Le Responsable »…) et nom.
class Signatories {
  String leftTitle;
  String leftName;
  String rightTitle;
  String rightName;
  bool showLeft;
  bool showRight;

  Signatories({
    this.leftTitle = 'Le client',
    this.leftName = '',
    this.rightTitle = 'La Direction',
    this.rightName = '',
    this.showLeft = true,
    this.showRight = true,
  });

  /// Valeurs par défaut selon le type de document.
  factory Signatories.defaultsFor(DocType t) => switch (t) {
        DocType.bordereau => Signatories(leftTitle: 'Reçu par', rightTitle: 'Livré par'),
        DocType.decharge => Signatories(leftTitle: 'Le bénéficiaire', rightTitle: 'Le remettant'),
        DocType.devis => Signatories(leftTitle: 'Bon pour accord (client)', rightTitle: 'La Direction'),
        _ => Signatories(),
      };

  Signatories copy() => Signatories.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'leftTitle': leftTitle,
        'leftName': leftName,
        'rightTitle': rightTitle,
        'rightName': rightName,
        'showLeft': showLeft,
        'showRight': showRight,
      };

  factory Signatories.fromJson(Map<String, dynamic> j) => Signatories(
        leftTitle: j['leftTitle'] ?? '',
        leftName: j['leftName'] ?? '',
        rightTitle: j['rightTitle'] ?? '',
        rightName: j['rightName'] ?? '',
        showLeft: j['showLeft'] ?? true,
        showRight: j['showRight'] ?? true,
      );
}

/// Profil de l'entreprise cliente (une installation = une entreprise).
class Company {
  String name;
  String phone;
  String phone2;
  String email;
  String address;
  String ifu; // N° IFU
  String rccm;
  String? logoB64;
  String? labelLogoB64; // logo imprimé sur les étiquettes
  String? headerB64; // en-tête des documents (image)
  String? footerB64; // pied de page des documents (image)
  String? stampB64; // cachet de l'entreprise (fond transparent)
  List<String> stampTypes; // types de documents cachetés par défaut
  double stampSizeMm;
  Map<String, Signatories> signatories; // signataires par défaut, par type de document
  String currency;
  double defaultVat; // % TVA par défaut
  Map<String, String> prefixes; // préfixes de numérotation par type de document
  Map<String, int> counters;
  Map<String, String> defaultTemplates; // type -> templateId

  Company({
    this.name = '',
    this.phone = '',
    this.phone2 = '',
    this.email = '',
    this.address = '',
    this.ifu = '',
    this.rccm = '',
    this.logoB64,
    this.labelLogoB64,
    this.headerB64,
    this.footerB64,
    this.stampB64,
    List<String>? stampTypes,
    this.stampSizeMm = 38,
    Map<String, Signatories>? signatories,
    this.currency = 'FCFA',
    this.defaultVat = 0,
    Map<String, String>? prefixes,
    Map<String, int>? counters,
    Map<String, String>? defaultTemplates,
  })  : prefixes = prefixes ??
            {for (final t in DocType.values) t.name: t.defaultPrefix},
        counters = counters ?? {},
        defaultTemplates = defaultTemplates ?? {},
        stampTypes = stampTypes ?? ['devis', 'proforma', 'facture'],
        signatories = signatories ?? {};

  /// Signataires par défaut d'un type de document (copie modifiable).
  Signatories signatoriesFor(DocType t) =>
      (signatories[t.name] ?? Signatories.defaultsFor(t)).copy();

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'email': email,
        'address': address,
        'ifu': ifu,
        'rccm': rccm,
        'logoB64': logoB64,
        'labelLogoB64': labelLogoB64,
        'headerB64': headerB64,
        'footerB64': footerB64,
        'stampB64': stampB64,
        'stampTypes': stampTypes,
        'stampSizeMm': stampSizeMm,
        'signatories': signatories.map((k, v) => MapEntry(k, v.toJson())),
        'currency': currency,
        'defaultVat': defaultVat,
        'prefixes': prefixes,
        'counters': counters,
        'defaultTemplates': defaultTemplates,
      };

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        phone2: j['phone2'] ?? '',
        email: j['email'] ?? '',
        address: j['address'] ?? '',
        ifu: j['ifu'] ?? '',
        rccm: j['rccm'] ?? '',
        logoB64: j['logoB64'],
        labelLogoB64: j['labelLogoB64'],
        headerB64: j['headerB64'],
        footerB64: j['footerB64'],
        stampB64: j['stampB64'],
        stampTypes: j['stampTypes'] == null ? null : List<String>.from(j['stampTypes']),
        stampSizeMm: _d(j['stampSizeMm'], 38),
        signatories: Map<String, dynamic>.from(j['signatories'] ?? {})
            .map((k, v) => MapEntry(k, Signatories.fromJson(Map<String, dynamic>.from(v)))),
        currency: j['currency'] ?? 'FCFA',
        defaultVat: _d(j['defaultVat']),
        prefixes: {
          for (final t in DocType.values) t.name: t.defaultPrefix,
          ...Map<String, String>.from(j['prefixes'] ?? {}),
        },
        counters: Map<String, dynamic>.from(j['counters'] ?? {})
            .map((k, v) => MapEntry(k, _i(v))),
        defaultTemplates: Map<String, String>.from(j['defaultTemplates'] ?? {}),
      );
}

/// Produit à étiqueter (poulet entier, découpe, etc.).
class Product {
  String id;
  String name;
  String dateLabel; // "Date d'abattage", "Date de fabrication"...
  int shelfLifeDays; // durée de conservation en jours
  String storageTemp; // "0 °C à +4 °C"
  String unit; // kg, pièce...
  double price; // prix unitaire (optionnel)
  String extra; // mention libre (ex : "Halal", "À consommer cuit")
  String labelStyleId;

  Product({
    String? id,
    this.name = '',
    this.dateLabel = "Date d'abattage",
    this.shelfLifeDays = 5,
    this.storageTemp = '0 °C à +4 °C',
    this.unit = 'kg',
    this.price = 0,
    this.extra = '',
    this.labelStyleId = 'standard',
  }) : id = id ?? newId();

  String get shelfLifeText {
    if (shelfLifeDays >= 30 && shelfLifeDays % 30 == 0) {
      final m = shelfLifeDays ~/ 30;
      return '$m mois';
    }
    return '$shelfLifeDays jour${shelfLifeDays > 1 ? 's' : ''}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dateLabel': dateLabel,
        'shelfLifeDays': shelfLifeDays,
        'storageTemp': storageTemp,
        'unit': unit,
        'price': price,
        'extra': extra,
        'labelStyleId': labelStyleId,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        name: j['name'] ?? '',
        dateLabel: j['dateLabel'] ?? "Date d'abattage",
        shelfLifeDays: _i(j['shelfLifeDays'], 5),
        storageTemp: j['storageTemp'] ?? '',
        unit: j['unit'] ?? 'kg',
        price: _d(j['price']),
        extra: j['extra'] ?? '',
        labelStyleId: j['labelStyleId'] ?? 'standard',
      );
}

class Client {
  String id;
  String name;
  String phone;
  String address;
  String email;
  String ifu;
  String extra; // informations supplémentaires libres

  Client({
    String? id,
    this.name = '',
    this.phone = '',
    this.address = '',
    this.email = '',
    this.ifu = '',
    this.extra = '',
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'email': email,
        'ifu': ifu,
        'extra': extra,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'],
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        email: j['email'] ?? '',
        ifu: j['ifu'] ?? '',
        extra: j['extra'] ?? '',
      );
}

enum DocType {
  devis('Devis', 'DEVIS', 'DV'),
  proforma('Facture proforma', 'FACTURE PROFORMA', 'PF'),
  facture('Facture définitive', 'FACTURE', 'FA'),
  bordereau('Bordereau de livraison', 'BORDEREAU DE LIVRAISON', 'BL'),
  decharge('Décharge', 'DÉCHARGE', 'DC');

  const DocType(this.label, this.title, this.defaultPrefix);
  final String label;
  final String title;
  final String defaultPrefix;

  bool get hasPrices => this != DocType.bordereau && this != DocType.decharge;

  /// Types vers lesquels ce document peut être converti.
  List<DocType> get convertTargets => switch (this) {
        DocType.devis => [DocType.proforma, DocType.facture],
        DocType.proforma => [DocType.facture],
        DocType.facture => [DocType.bordereau, DocType.decharge],
        DocType.bordereau => [DocType.decharge],
        DocType.decharge => [],
      };

  static DocType parse(String? s) =>
      DocType.values.firstWhere((e) => e.name == s, orElse: () => DocType.devis);
}

class DocLine {
  String designation;
  double qty;
  String unit;
  double unitPrice;
  double discount; // % remise

  DocLine({
    this.designation = '',
    this.qty = 1,
    this.unit = '',
    this.unitPrice = 0,
    this.discount = 0,
  });

  double get total => qty * unitPrice * (1 - discount / 100);

  Map<String, dynamic> toJson() => {
        'designation': designation,
        'qty': qty,
        'unit': unit,
        'unitPrice': unitPrice,
        'discount': discount,
      };

  factory DocLine.fromJson(Map<String, dynamic> j) => DocLine(
        designation: j['designation'] ?? '',
        qty: _d(j['qty'], 1),
        unit: j['unit'] ?? '',
        unitPrice: _d(j['unitPrice']),
        discount: _d(j['discount']),
      );

  DocLine copy() => DocLine.fromJson(toJson());
}

/// Document commercial : devis, proforma, facture, bordereau, décharge.
class CommercialDoc {
  String id;
  DocType type;
  String number;
  DateTime date;
  String? clientId;
  String clientName;
  String clientPhone;
  String clientAddress;
  String clientIfu;
  String clientExtra; // informations supplémentaires du client
  String subject; // objet
  List<DocLine> lines;
  double vatRate;
  double globalDiscount; // montant de remise globale
  String notes;
  String conditions; // conditions de paiement / validité
  String templateId;
  String? sourceId; // document d'origine (conversion)
  String? sourceNumber;
  List<String> convertedTo; // numéros des documents générés
  bool showPricesOnDelivery; // bordereau : afficher les prix ?
  String deliveryPlace;
  String receiverName; // décharge / bordereau : nom du réceptionnaire
  String dischargeText; // décharge : texte libre
  String status; // brouillon, envoyé, payé, converti
  Signatories? signatures; // null = signataires par défaut de l'entreprise
  bool showStamp; // apposer le cachet de l'entreprise
  String? stickerB64; // sticker (photo détourée) collé en haut du document
  String stickerPos; // left | center | right
  double stickerWidthMm;

  CommercialDoc({
    String? id,
    required this.type,
    this.number = '',
    DateTime? date,
    this.clientId,
    this.clientName = '',
    this.clientPhone = '',
    this.clientAddress = '',
    this.clientIfu = '',
    this.clientExtra = '',
    this.subject = '',
    List<DocLine>? lines,
    this.vatRate = 0,
    this.globalDiscount = 0,
    this.notes = '',
    this.conditions = '',
    this.templateId = 'classique',
    this.sourceId,
    this.sourceNumber,
    List<String>? convertedTo,
    this.showPricesOnDelivery = false,
    this.deliveryPlace = '',
    this.receiverName = '',
    this.dischargeText = '',
    this.status = 'brouillon',
    this.signatures,
    this.showStamp = false,
    this.stickerB64,
    this.stickerPos = 'right',
    this.stickerWidthMm = 42,
  })  : id = id ?? newId(),
        date = date ?? DateTime.now(),
        lines = lines ?? [],
        convertedTo = convertedTo ?? [];

  double get subtotal => lines.fold(0.0, (s, l) => s + l.total);
  double get afterDiscount => (subtotal - globalDiscount).clamp(0, double.infinity);
  double get vatAmount => afterDiscount * vatRate / 100;
  double get total => afterDiscount + vatAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'number': number,
        'date': date.toIso8601String(),
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientAddress': clientAddress,
        'clientIfu': clientIfu,
        'clientExtra': clientExtra,
        'subject': subject,
        'lines': lines.map((e) => e.toJson()).toList(),
        'vatRate': vatRate,
        'globalDiscount': globalDiscount,
        'notes': notes,
        'conditions': conditions,
        'templateId': templateId,
        'sourceId': sourceId,
        'sourceNumber': sourceNumber,
        'convertedTo': convertedTo,
        'showPricesOnDelivery': showPricesOnDelivery,
        'deliveryPlace': deliveryPlace,
        'receiverName': receiverName,
        'dischargeText': dischargeText,
        'status': status,
        'signatures': signatures?.toJson(),
        'showStamp': showStamp,
        'stickerB64': stickerB64,
        'stickerPos': stickerPos,
        'stickerWidthMm': stickerWidthMm,
      };

  factory CommercialDoc.fromJson(Map<String, dynamic> j) => CommercialDoc(
        id: j['id'],
        type: DocType.parse(j['type']),
        number: j['number'] ?? '',
        date: _dt(j['date']),
        clientId: j['clientId'],
        clientName: j['clientName'] ?? '',
        clientPhone: j['clientPhone'] ?? '',
        clientAddress: j['clientAddress'] ?? '',
        clientIfu: j['clientIfu'] ?? '',
        clientExtra: j['clientExtra'] ?? '',
        subject: j['subject'] ?? '',
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => DocLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        vatRate: _d(j['vatRate']),
        globalDiscount: _d(j['globalDiscount']),
        notes: j['notes'] ?? '',
        conditions: j['conditions'] ?? '',
        templateId: j['templateId'] ?? 'classique',
        sourceId: j['sourceId'],
        sourceNumber: j['sourceNumber'],
        convertedTo: List<String>.from(j['convertedTo'] ?? []),
        showPricesOnDelivery: j['showPricesOnDelivery'] == true,
        deliveryPlace: j['deliveryPlace'] ?? '',
        receiverName: j['receiverName'] ?? '',
        dischargeText: j['dischargeText'] ?? '',
        status: j['status'] ?? 'brouillon',
        signatures: j['signatures'] == null
            ? null
            : Signatories.fromJson(Map<String, dynamic>.from(j['signatures'])),
        showStamp: j['showStamp'] == true,
        stickerB64: j['stickerB64'],
        stickerPos: j['stickerPos'] ?? 'right',
        stickerWidthMm: _d(j['stickerWidthMm'], 42),
      );
}

/// Format d'étiquette.
enum PrintMode { tspl, escpos, a4 }

class LabelFormat {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final PrintMode mode;
  // Pour les planches A4
  final int cols;
  final int rows;
  final double sheetMarginTopMm;
  final double sheetMarginLeftMm;
  final double gapXMm;
  final double gapYMm;

  const LabelFormat({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.mode,
    this.cols = 1,
    this.rows = 1,
    this.sheetMarginTopMm = 0,
    this.sheetMarginLeftMm = 0,
    this.gapXMm = 0,
    this.gapYMm = 0,
  });

  int get perSheet => cols * rows;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'mode': mode.name,
        'cols': cols,
        'rows': rows,
        'sheetMarginTopMm': sheetMarginTopMm,
        'sheetMarginLeftMm': sheetMarginLeftMm,
        'gapXMm': gapXMm,
        'gapYMm': gapYMm,
      };

  factory LabelFormat.fromJson(Map<String, dynamic> j) => LabelFormat(
        id: j['id'] ?? newId(),
        name: j['name'] ?? 'Format',
        widthMm: _d(j['widthMm'], 50),
        heightMm: _d(j['heightMm'], 30),
        mode: PrintMode.values.firstWhere((m) => m.name == j['mode'],
            orElse: () => PrintMode.tspl),
        cols: _i(j['cols'], 1),
        rows: _i(j['rows'], 1),
        sheetMarginTopMm: _d(j['sheetMarginTopMm']),
        sheetMarginLeftMm: _d(j['sheetMarginLeftMm']),
        gapXMm: _d(j['gapXMm']),
        gapYMm: _d(j['gapYMm']),
      );
}

const builtinLabelFormats = <LabelFormat>[
  LabelFormat(id: 'tspl_25x15', name: 'Étiquette 25 × 15 mm', widthMm: 25, heightMm: 15, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_30x15', name: 'Étiquette 30 × 15 mm', widthMm: 30, heightMm: 15, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_30x20', name: 'Étiquette 30 × 20 mm', widthMm: 30, heightMm: 20, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_35x25', name: 'Étiquette 35 × 25 mm', widthMm: 35, heightMm: 25, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_40x20', name: 'Étiquette 40 × 20 mm', widthMm: 40, heightMm: 20, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_40x25', name: 'Étiquette 40 × 25 mm', widthMm: 40, heightMm: 25, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_50x20', name: 'Étiquette 50 × 20 mm', widthMm: 50, heightMm: 20, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_50x25', name: 'Étiquette 50 × 25 mm', widthMm: 50, heightMm: 25, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_40x30', name: 'Étiquette 40 × 30 mm', widthMm: 40, heightMm: 30, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_50x30', name: 'Étiquette 50 × 30 mm', widthMm: 50, heightMm: 30, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_50x40', name: 'Étiquette 50 × 40 mm', widthMm: 50, heightMm: 40, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_60x40', name: 'Étiquette 60 × 40 mm', widthMm: 60, heightMm: 40, mode: PrintMode.tspl),
  LabelFormat(id: 'tspl_70x50', name: 'Étiquette 70 × 50 mm', widthMm: 70, heightMm: 50, mode: PrintMode.tspl),
  LabelFormat(id: 'pos_58_court', name: 'Ticket 58 mm (court, 20 mm)', widthMm: 48, heightMm: 20, mode: PrintMode.escpos),
  LabelFormat(id: 'pos_58', name: 'Ticket 58 mm', widthMm: 48, heightMm: 34, mode: PrintMode.escpos),
  LabelFormat(id: 'pos_80', name: 'Ticket 80 mm', widthMm: 72, heightMm: 40, mode: PrintMode.escpos),
  LabelFormat(id: 'a4_24', name: 'Planche A4 – 24 (70 × 37 mm)', widthMm: 70, heightMm: 37, mode: PrintMode.a4, cols: 3, rows: 8, sheetMarginTopMm: 0.5, sheetMarginLeftMm: 0),
  LabelFormat(id: 'a4_21', name: 'Planche A4 – 21 (70 × 42,3 mm)', widthMm: 70, heightMm: 42.3, mode: PrintMode.a4, cols: 3, rows: 7, sheetMarginTopMm: 0, sheetMarginLeftMm: 0),
  LabelFormat(id: 'a4_40', name: 'Planche A4 – 40 (52,5 × 29,7 mm)', widthMm: 52.5, heightMm: 29.7, mode: PrintMode.a4, cols: 4, rows: 10),
  LabelFormat(id: 'a4_14', name: 'Planche A4 – 14 (99,1 × 38,1 mm)', widthMm: 99.1, heightMm: 38.1, mode: PrintMode.a4, cols: 2, rows: 7, sheetMarginTopMm: 15.1, sheetMarginLeftMm: 4.7, gapXMm: 2.5),
];

/// Paramètres de l'imprimante Bluetooth.
class PrinterSettings {
  String? btAddress;
  String? btName;
  String defaultFormatId;
  bool invertTspl; // certaines imprimantes TSPL inversent noir/blanc
  int density; // 1..15
  int speed; // 1..6
  double gapMm;
  int threshold; // seuil noir/blanc 0..255
  List<LabelFormat> customFormats; // tailles personnalisées

  PrinterSettings({
    this.btAddress,
    this.btName,
    this.defaultFormatId = 'tspl_50x30',
    this.invertTspl = false,
    this.density = 8,
    this.speed = 4,
    this.gapMm = 2,
    this.threshold = 160,
    List<LabelFormat>? customFormats,
  }) : customFormats = customFormats ?? [];

  Map<String, dynamic> toJson() => {
        'btAddress': btAddress,
        'btName': btName,
        'defaultFormatId': defaultFormatId,
        'invertTspl': invertTspl,
        'density': density,
        'speed': speed,
        'gapMm': gapMm,
        'threshold': threshold,
        'customFormats': customFormats.map((e) => e.toJson()).toList(),
      };

  factory PrinterSettings.fromJson(Map<String, dynamic> j) => PrinterSettings(
        btAddress: j['btAddress'],
        btName: j['btName'],
        defaultFormatId: j['defaultFormatId'] ?? 'tspl_50x30',
        invertTspl: j['invertTspl'] == true,
        density: _i(j['density'], 8),
        speed: _i(j['speed'], 4),
        gapMm: _d(j['gapMm'], 2),
        threshold: _i(j['threshold'], 160),
        customFormats: ((j['customFormats'] as List?) ?? [])
            .map((e) => LabelFormat.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Historique d'impression d'étiquettes (traçabilité).
class LabelPrintLog {
  String id;
  String productName;
  DateTime productionDate;
  DateTime expiryDate;
  String lot;
  int copies;
  DateTime printedAt;

  LabelPrintLog({
    String? id,
    required this.productName,
    required this.productionDate,
    required this.expiryDate,
    this.lot = '',
    this.copies = 1,
    DateTime? printedAt,
  })  : id = id ?? newId(),
        printedAt = printedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'productionDate': productionDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'lot': lot,
        'copies': copies,
        'printedAt': printedAt.toIso8601String(),
      };

  factory LabelPrintLog.fromJson(Map<String, dynamic> j) => LabelPrintLog(
        id: j['id'],
        productName: j['productName'] ?? '',
        productionDate: _dt(j['productionDate']) ?? DateTime.now(),
        expiryDate: _dt(j['expiryDate']) ?? DateTime.now(),
        lot: j['lot'] ?? '',
        copies: _i(j['copies'], 1),
        printedAt: _dt(j['printedAt']),
      );
}
