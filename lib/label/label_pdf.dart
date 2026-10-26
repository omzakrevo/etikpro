import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import '../core/pdf_fonts.dart';
import '../core/templates.dart';
import '../core/utils.dart';

/// Données imprimées sur une étiquette.
class LabelData {
  final String company;
  final String phone;
  final String product;
  final String dateLabel;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String storageTemp;
  final String durationText;
  final String weight; // texte libre "1,2 kg"
  final String lot;
  final String price; // texte "2 500 FCFA"
  final String extra;
  final Uint8List? logo; // logo de l'entreprise (PNG/JPG)

  const LabelData({
    required this.company,
    required this.phone,
    required this.product,
    required this.dateLabel,
    required this.productionDate,
    required this.expiryDate,
    required this.storageTemp,
    required this.durationText,
    this.weight = '',
    this.lot = '',
    this.price = '',
    this.extra = '',
    this.logo,
  });

  String get qrText => [
    company,
    if (phone.isNotEmpty) 'Tel: $phone',
    product,
    '$dateLabel: ${fmtDate(productionDate)}',
    'Peremption: ${fmtDate(expiryDate)}',
    if (storageTemp.isNotEmpty) 'Conservation: $storageTemp',
    if (lot.isNotEmpty) 'Lot: $lot',
  ].join('\n');
}

const _mm = PdfPageFormat.mm;

/// Contenu d'une étiquette, dessiné dans une boîte de [w] × [h] mm.
/// Marges très faibles (1 mm) : l'étiquette est collée directement sur le colis.
pw.Widget buildLabelWidget(LabelData d, LabelStyle s, double wMm, double hMm, TextMeasure m) {
  const margin = 1.0 * _mm;
  final w = wMm * _mm, h = hMm * _mm;

  // ---------- Petites étiquettes ----------
  // On calcule la taille de texte ; si elle devient illisible, on retire d'abord
  // les infos secondaires (mention, durée, lot/poids, téléphone) au lieu d'écrire minuscule.
  final metaAvailable =
      (s.showLot && d.lot.isNotEmpty) ||
      (s.showWeight && d.weight.isNotEmpty) ||
      (s.showPrice && d.price.isNotEmpty);
  var showPhone = s.showPhone && d.phone.isNotEmpty;
  var showDur = d.durationText.isNotEmpty;
  var showMeta = metaAvailable;
  var showExtra = d.extra.isNotEmpty;
  final showTemp = d.storageTemp.isNotEmpty;
  final showProduct = s.showProduct && d.product.isNotEmpty;
  final qrSize = s.showQr ? ((h - 2 * margin) * 0.62).clamp(0.0, w * 0.32) : 0.0;
  final textW = w - 2 * margin - (s.showQr ? qrSize + 1.5 * _mm : 0);

  double calc() {
    var l = 2.1 + (showProduct ? 1.4 : 0) + 2; // bande + produit + 2 dates
    if (showPhone) l += 1;
    if (showTemp) l += 1;
    if (showDur) l += 1;
    if (showMeta) l += 1;
    if (showExtra) l += 0.9;
    return ((h - 2 * margin) / (l * 1.18)) * s.fontScale;
  }

  const minReadable = 5.8; // points
  var fs = calc();
  for (final drop in <void Function()>[
    () => showExtra = false,
    () => showDur = false,
    () => showMeta = false,
    () => showPhone = false,
  ]) {
    if (fs >= minReadable) break;
    drop();
    fs = calc();
  }
  // Libellés courts sur les petites étiquettes (« Péremption » au lieu de « Date de péremption »)
  final compact = fs < 7 || wMm < 42;
  fs = fs.clamp(4.0, 13.0);
  final dateFmt = wMm < 32 ? (DateTime x) => DateFormat('dd/MM/yy').format(x) : fmtDate;
  String shortDate(String l) {
    final t = l.replaceFirst(RegExp(r"^date\s+(d'|d’|de\s+|du\s+)", caseSensitive: false), '').trim();
    return t.isEmpty ? l : t[0].toUpperCase() + t.substring(1);
  }

  final prodLabel = compact ? shortDate(d.dateLabel) : d.dateLabel;
  final expLabel = compact
      ? (s.expiryLabel.toLowerCase().contains('péremption') ? 'Péremption' : shortDate(s.expiryLabel))
      : s.expiryLabel;
  final tempLabel = compact ? 'Conserv.' : s.tempLabel;
  final durLabel = compact ? 'Durée' : s.durationLabel;

  final black = PdfColors.black;
  pw.TextStyle st(double k, {bool bold = false, bool italic = false}) => pw.TextStyle(
    fontSize: fs * k,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    color: black,
    lineSpacing: 0,
  );

  // Chaque ligne trop longue est réduite (jamais coupée) : on mesure sa largeur.
  double shrink(double widthEm, double size, double avail) =>
      widthEm * size <= avail || widthEm == 0 ? 1 : avail / (widthEm * size);

  pw.Widget line(String t, double k, {bool bold = false, bool italic = false, double? avail}) {
    final f = shrink(m.width(t, isBold: bold), fs * k, avail ?? textW);
    return pw.Text(
      t,
      maxLines: 1,
      style: st(k * f, bold: bold, italic: italic),
    );
  }

  pw.Widget kv(String k, String v, {bool strong = false}) {
    final kk = 0.92, kvv = strong ? 1.08 : 1.0;
    final wEm = m.width('$k : ') * kk + m.width(v, isBold: true) * kvv;
    final f = shrink(wEm, fs, textW);
    return pw.RichText(
      maxLines: 1,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$k : ', style: st(kk * f)),
          pw.TextSpan(text: v, style: st(kvv * f, bold: true)),
        ],
      ),
    );
  }

  final meta = !showMeta
      ? ''
      : <String>[
          if (s.showLot && d.lot.isNotEmpty) 'Lot ${d.lot}',
          if (s.showWeight && d.weight.isNotEmpty) d.weight,
          if (s.showPrice && d.price.isNotEmpty) d.price,
        ].join('  •  ');

  // ---------- En-tête : [logo] + bande entreprise, téléphone, produit ----------
  // Logo retiré sur les toutes petites étiquettes (il mangerait la place du texte)
  final hasLogo = s.showLogo && d.logo != null && d.logo!.isNotEmpty && !(wMm < 35 && hMm < 22);
  final headH = fs * 1.16 * (1.1 + (showPhone ? 0.95 : 0) + (showProduct ? 1.35 : 0)) + 0.6 * _mm;
  final logoSize = hasLogo ? headH.clamp(4 * _mm, textW * 0.34) : 0.0;
  final logoGap = hasLogo ? 1.2 * _mm : 0.0;
  final headW = textW - logoSize - logoGap;

  final bandPad = 1.2 * _mm;
  final companyText = d.company.toUpperCase();
  final bandF = shrink(m.width(companyText, isBold: true), fs * 1.05, headW - 2 * bandPad);

  final headLines = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      if (s.companyBand)
        pw.Container(
          width: headW,
          color: black,
          padding: pw.EdgeInsets.symmetric(horizontal: bandPad, vertical: 0.3 * _mm),
          child: pw.Text(
            companyText,
            maxLines: 1,
            style: st(1.05 * bandF, bold: true).copyWith(color: PdfColors.white),
          ),
        )
      else
        line(companyText, 1.1, bold: true, avail: headW),
      if (showPhone) line('Tél : ${d.phone}', 0.9, avail: headW),
      if (showProduct) line(d.product, 1.3, bold: true, avail: headW),
    ],
  );

  final header = hasLogo
      ? pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: logoSize,
              height: logoSize,
              child: pw.Image(pw.MemoryImage(d.logo!), fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: logoGap),
            headLines,
          ],
        )
      : headLines;

  final text = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      header,
      kv(prodLabel, dateFmt(d.productionDate)),
      kv(expLabel, dateFmt(d.expiryDate), strong: true),
      if (showTemp) kv(tempLabel, d.storageTemp),
      if (showDur) kv(durLabel, d.durationText),
      if (meta.isNotEmpty) line(meta, 0.95, bold: true),
      if (showExtra) line(d.extra, 0.85, italic: true),
    ],
  );

  final body = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.SizedBox(width: textW, height: h - 2 * margin, child: text),
      if (s.showQr) ...[
        pw.SizedBox(width: 1.5 * _mm),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: d.qrText,
          width: qrSize,
          height: qrSize,
          drawText: false,
        ),
      ],
    ],
  );

  return pw.Container(
    width: w,
    height: h,
    padding: const pw.EdgeInsets.all(margin),
    decoration: s.showBorder
        ? pw.BoxDecoration(
            border: pw.Border.all(color: black, width: 0.8),
            borderRadius: pw.BorderRadius.circular(1.2 * _mm),
          )
        : null,
    child: body,
  );
}

typedef LabelCellBuilder = pw.Widget Function(double wMm, double hMm, TextMeasure m);

/// Met en page n'importe quelle étiquette : une page par étiquette
/// (imprimante d'étiquettes / ticket) ou planches A4 avec plusieurs étiquettes.
Future<Uint8List> layoutLabelsPdf({
  required LabelCellBuilder cell,
  required LabelFormat format,
  String title = 'Étiquettes',
  int copies = 1,
  int skipCells = 0, // planches A4 entamées : cases déjà utilisées
}) async {
  final doc = pw.Document(title: title, author: 'ETIKPRO', theme: await PdfFonts.theme('helvetica'));
  final m = await PdfFonts.measure();
  copies = copies.clamp(1, 5000);

  if (format.mode != PrintMode.a4) {
    final pf = PdfPageFormat(format.widthMm * _mm, format.heightMm * _mm, marginAll: 0);
    final w = cell(format.widthMm, format.heightMm, m);
    for (var i = 0; i < copies; i++) {
      doc.addPage(pw.Page(pageFormat: pf, build: (_) => w));
    }
    return doc.save();
  }

  // Planches A4
  final per = format.perSheet;
  final pages = ((copies + skipCells) / per).ceil();
  var idx = 0;
  for (var p = 0; p < pages; p++) {
    final cells = <pw.Widget>[];
    for (var r = 0; r < format.rows; r++) {
      for (var c = 0; c < format.cols; c++) {
        final n = p * per + r * format.cols + c;
        if (n < skipCells || idx >= copies) continue;
        idx++;
        cells.add(
          pw.Positioned(
            left: (format.sheetMarginLeftMm + c * (format.widthMm + format.gapXMm)) * _mm,
            top: (format.sheetMarginTopMm + r * (format.heightMm + format.gapYMm)) * _mm,
            child: cell(format.widthMm, format.heightMm, m),
          ),
        );
      }
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 0, marginRight: 0, marginTop: 0, marginBottom: 0),
        build: (_) => pw.Stack(children: cells),
      ),
    );
  }
  return doc.save();
}

/// PDF d'étiquettes produit (traçabilité).
Future<Uint8List> buildLabelsPdf({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0,
}) => layoutLabelsPdf(
  cell: (w, h, m) => buildLabelWidget(data, style, w, h, m),
  format: format,
  title: 'Étiquettes ${data.product}',
  copies: copies,
  skipCells: skipCells,
);

// ---------------------------------------------------------------------------
// Étiquette libre : l'entreprise écrit ce qu'elle veut.
// ---------------------------------------------------------------------------

class FreeLabelData {
  final String company; // vide = pas d'en-tête entreprise
  final String phone;
  final String title; // ligne en gros
  final List<String> lines; // lignes libres ("Clé : valeur" met la clé en normal, la valeur en gras)
  final Uint8List? logo;
  final bool companyBand;
  final bool border;
  final String qr; // texte du QR (vide = pas de QR)
  final String align; // left | center
  final double fontScale;

  const FreeLabelData({
    this.company = '',
    this.phone = '',
    this.title = '',
    this.lines = const [],
    this.logo,
    this.companyBand = true,
    this.border = false,
    this.qr = '',
    this.align = 'left',
    this.fontScale = 1,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'lines': lines,
    'companyBand': companyBand,
    'border': border,
    'qr': qr,
    'align': align,
    'fontScale': fontScale,
  };
}

pw.Widget buildFreeLabelWidget(FreeLabelData d, double wMm, double hMm, TextMeasure m) {
  const margin = 1.0 * _mm;
  final w = wMm * _mm, h = hMm * _mm;
  final lines = d.lines.where((e) => e.trim().isNotEmpty).toList();
  final hasCompany = d.company.trim().isNotEmpty;
  final hasPhone = d.phone.trim().isNotEmpty;
  final hasTitle = d.title.trim().isNotEmpty;
  final hasLogo = d.logo != null && d.logo!.isNotEmpty;
  final center = d.align == 'center';

  var units = lines.length * 1.0;
  if (hasCompany) units += 1.1;
  if (hasPhone) units += 0.9;
  if (hasTitle) units += 1.45;
  if (units == 0) units = 1;
  final qrSize = d.qr.isNotEmpty ? ((h - 2 * margin) * 0.62).clamp(0.0, w * 0.32) : 0.0;
  final textW = w - 2 * margin - (qrSize > 0 ? qrSize + 1.5 * _mm : 0);
  final fs = (((h - 2 * margin) / (units * 1.2)) * d.fontScale).clamp(4.0, 22.0);

  pw.TextStyle st(double k, {bool bold = false, PdfColor? color}) => pw.TextStyle(
    fontSize: fs * k,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color ?? PdfColors.black,
  );
  double shrink(double em, double size, double avail) =>
      em * size <= avail || em == 0 ? 1 : avail / (em * size);

  pw.Widget line(String t, double k, double avail, {bool bold = false}) {
    // "Clé : valeur" -> valeur en gras
    final i = t.indexOf(':');
    if (!bold && i > 0 && i < t.length - 1) {
      final key = '${t.substring(0, i).trim()} : ';
      final val = t.substring(i + 1).trim();
      final f = shrink(m.width(key) * 0.92 + m.width(val, isBold: true), fs * k, avail);
      return pw.RichText(
        maxLines: 1,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: key, style: st(k * 0.92 * f)),
            pw.TextSpan(text: val, style: st(k * f, bold: true)),
          ],
        ),
      );
    }
    final f = shrink(m.width(t, isBold: bold), fs * k, avail);
    return pw.Text(
      t,
      maxLines: 1,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: st(k * f, bold: bold),
    );
  }

  // En-tête (logo + entreprise + téléphone)
  final headUnits = (hasCompany ? 1.1 : 0) + (hasPhone ? 0.9 : 0) + (hasTitle ? 1.45 : 0);
  final logoSize = hasLogo ? (fs * 1.2 * (headUnits == 0 ? 2 : headUnits)).clamp(4 * _mm, textW * 0.34) : 0.0;
  final headW = textW - (hasLogo ? logoSize + 1.2 * _mm : 0);
  final companyText = d.company.toUpperCase();
  final head = pw.Column(
    crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      if (hasCompany && d.companyBand)
        pw.Container(
          width: headW,
          color: PdfColors.black,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1.2 * _mm, vertical: 0.3 * _mm),
          alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
          child: pw.Text(
            companyText,
            maxLines: 1,
            style: st(
              1.05 * shrink(m.width(companyText, isBold: true), fs * 1.05, headW - 2.4 * _mm),
              bold: true,
              color: PdfColors.white,
            ),
          ),
        )
      else if (hasCompany)
        line(companyText, 1.1, headW, bold: true),
      if (hasPhone) line('Tél : ${d.phone}', 0.9, headW),
      if (hasTitle) line(d.title, 1.45, headW, bold: true),
    ],
  );
  final header = hasLogo
      ? pw.Row(
          children: [
            pw.SizedBox(
              width: logoSize,
              height: logoSize,
              child: pw.Image(pw.MemoryImage(d.logo!), fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 1.2 * _mm),
            pw.SizedBox(width: headW, child: head),
          ],
        )
      : pw.SizedBox(width: textW, child: head);

  final text = pw.Column(
    crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
    mainAxisAlignment: lines.length + headUnits > 2.5
        ? pw.MainAxisAlignment.spaceBetween
        : pw.MainAxisAlignment.center,
    children: [
      if (headUnits > 0 || hasLogo) header,
      for (final l in lines) pw.SizedBox(width: textW, child: line(l, 1, textW)),
    ],
  );

  return pw.Container(
    width: w,
    height: h,
    padding: const pw.EdgeInsets.all(margin),
    decoration: d.border
        ? pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
            borderRadius: pw.BorderRadius.circular(1.2 * _mm),
          )
        : null,
    child: pw.Row(
      children: [
        pw.SizedBox(width: textW, height: h - 2 * margin, child: text),
        if (qrSize > 0) ...[
          pw.SizedBox(width: 1.5 * _mm),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: d.qr,
            width: qrSize,
            height: qrSize,
            drawText: false,
          ),
        ],
      ],
    ),
  );
}

Future<Uint8List> buildFreeLabelsPdf({
  required FreeLabelData data,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0,
}) => layoutLabelsPdf(
  cell: (w, h, m) => buildFreeLabelWidget(data, w, h, m),
  format: format,
  title: 'Étiquettes ${data.title}',
  copies: copies,
  skipCells: skipCells,
);
