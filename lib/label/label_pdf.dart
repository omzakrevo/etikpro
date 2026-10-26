import 'dart:typed_data';

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
pw.Widget buildLabelWidget(
    LabelData d, LabelStyle s, double wMm, double hMm, TextMeasure m) {
  const margin = 1.0 * _mm;
  final w = wMm * _mm, h = hMm * _mm;

  // Nombre de lignes de texte, pour calculer une taille de police lisible.
  var lines = 4.6; // bande + produit (x1.4) + 2 dates
  if (s.showPhone && d.phone.isNotEmpty) lines += 1;
  if (d.storageTemp.isNotEmpty) lines += 1;
  if (d.durationText.isNotEmpty) lines += 1;
  final hasMeta = (s.showLot && d.lot.isNotEmpty) ||
      (s.showWeight && d.weight.isNotEmpty) ||
      (s.showPrice && d.price.isNotEmpty);
  if (hasMeta) lines += 1;
  if (d.extra.isNotEmpty) lines += 0.9;
  final qrSize = s.showQr ? ((h - 2 * margin) * 0.62).clamp(0.0, w * 0.32) : 0.0;
  final textW = w - 2 * margin - (s.showQr ? qrSize + 1.5 * _mm : 0);
  var fs = ((h - 2 * margin) / (lines * 1.18)) * s.fontScale;
  fs = fs.clamp(4.0, 13.0);

  final black = PdfColors.black;
  pw.TextStyle st(double k, {bool bold = false, bool italic = false}) =>
      pw.TextStyle(
        fontSize: fs * k,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        color: black,
        lineSpacing: 0,
      );

  // Chaque ligne trop longue est réduite (jamais coupée) : on mesure sa largeur.
  double shrink(double widthEm, double size, double avail) =>
      widthEm * size <= avail || widthEm == 0 ? 1 : avail / (widthEm * size);

  pw.Widget line(String t, double k,
      {bool bold = false, bool italic = false, double? avail}) {
    final f = shrink(m.width(t, isBold: bold), fs * k, avail ?? textW);
    return pw.Text(t, maxLines: 1, style: st(k * f, bold: bold, italic: italic));
  }

  pw.Widget kv(String k, String v, {bool strong = false}) {
    final kk = 0.92, kvv = strong ? 1.08 : 1.0;
    final wEm = m.width('$k : ') * kk + m.width(v, isBold: true) * kvv;
    final f = shrink(wEm, fs, textW);
    return pw.RichText(
      maxLines: 1,
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$k : ', style: st(kk * f)),
        pw.TextSpan(text: v, style: st(kvv * f, bold: true)),
      ]),
    );
  }

  final meta = <String>[
    if (s.showLot && d.lot.isNotEmpty) 'Lot ${d.lot}',
    if (s.showWeight && d.weight.isNotEmpty) d.weight,
    if (s.showPrice && d.price.isNotEmpty) d.price,
  ].join('  •  ');

  // ---------- En-tête : [logo] + bande entreprise, téléphone, produit ----------
  final showPhone = s.showPhone && d.phone.isNotEmpty;
  final showProduct = s.showProduct && d.product.isNotEmpty;
  final hasLogo = s.showLogo && d.logo != null && d.logo!.isNotEmpty;
  final headH = fs * 1.16 * (1.1 + (showPhone ? 0.95 : 0) + (showProduct ? 1.35 : 0)) +
      0.6 * _mm;
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
          child: pw.Text(companyText,
              maxLines: 1,
              style: st(1.05 * bandF, bold: true).copyWith(color: PdfColors.white)),
        )
      else
        line(companyText, 1.1, bold: true, avail: headW),
      if (showPhone) line('Tél : ${d.phone}', 0.9, avail: headW),
      if (showProduct) line(d.product, 1.3, bold: true, avail: headW),
    ],
  );

  final header = hasLogo
      ? pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(
            width: logoSize,
            height: logoSize,
            child: pw.Image(pw.MemoryImage(d.logo!), fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: logoGap),
          headLines,
        ])
      : headLines;

  final text = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      header,
      kv(d.dateLabel, fmtDate(d.productionDate)),
      kv(s.expiryLabel, fmtDate(d.expiryDate), strong: true),
      if (d.storageTemp.isNotEmpty) kv(s.tempLabel, d.storageTemp),
      if (d.durationText.isNotEmpty) kv(s.durationLabel, d.durationText),
      if (meta.isNotEmpty) line(meta, 0.95, bold: true),
      if (d.extra.isNotEmpty) line(d.extra, 0.85, italic: true),
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
            borderRadius: pw.BorderRadius.circular(1.2 * _mm))
        : null,
    child: body,
  );
}

/// PDF d'étiquettes : une page par étiquette (imprimante d'étiquettes / ticket)
/// ou planches A4 avec plusieurs étiquettes par page.
Future<Uint8List> buildLabelsPdf({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0, // planches A4 entamées : cases déjà utilisées
}) async {
  final doc = pw.Document(
      title: 'Étiquettes ${data.product}',
      author: 'ETIKPRO',
      theme: await PdfFonts.theme('helvetica'));
  final m = await PdfFonts.measure();
  copies = copies.clamp(1, 2000);

  if (format.mode != PrintMode.a4) {
    final pf = PdfPageFormat(format.widthMm * _mm, format.heightMm * _mm,
        marginAll: 0);
    for (var i = 0; i < copies; i++) {
      doc.addPage(pw.Page(
        pageFormat: pf,
        build: (_) => buildLabelWidget(data, style, format.widthMm, format.heightMm, m),
      ));
    }
    return doc.save();
  }

  // Planches A4
  final per = format.perSheet;
  final total = copies + skipCells;
  final pages = (total / per).ceil();
  var idx = 0;
  for (var p = 0; p < pages; p++) {
    final cells = <pw.Widget>[];
    for (var r = 0; r < format.rows; r++) {
      for (var c = 0; c < format.cols; c++) {
        final n = p * per + r * format.cols + c;
        if (n < skipCells || idx >= copies) continue;
        idx++;
        cells.add(pw.Positioned(
          left: (format.sheetMarginLeftMm + c * (format.widthMm + format.gapXMm)) * _mm,
          top: (format.sheetMarginTopMm + r * (format.heightMm + format.gapYMm)) * _mm,
          child: buildLabelWidget(data, style, format.widthMm, format.heightMm, m),
        ));
      }
    }
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 0, marginRight: 0, marginTop: 0, marginBottom: 0),
      build: (_) => pw.Stack(children: cells),
    ));
  }
  return doc.save();
}
