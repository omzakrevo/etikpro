import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import '../core/pdf_fonts.dart';
import '../core/templates.dart';
import '../core/utils.dart';

const _mm = PdfPageFormat.mm;

pw.MemoryImage? _img(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return pw.MemoryImage(base64Decode(b64));
  } catch (_) {
    return null;
  }
}

String _amountPhrase(DocType t) => switch (t) {
      DocType.devis => 'Arrêté le présent devis à la somme de',
      DocType.proforma => 'Arrêtée la présente facture proforma à la somme de',
      DocType.facture => 'Arrêtée la présente facture à la somme de',
      DocType.bordereau => 'Arrêté le présent bordereau à la somme de',
      DocType.decharge => 'Montant total',
    };

/// Génère le PDF A4 d'un document commercial.
Future<Uint8List> buildDocPdf(
    CommercialDoc d, Company c, DocTemplate t) async {
  final primary = PdfColor.fromInt(t.primaryColor);
  final accent = PdfColor.fromInt(t.accentColor);
  final textColor = PdfColor.fromInt(t.textColor);
  final fs = t.fontSize;
  final header = _img(c.headerB64);
  final footer = _img(c.footerB64);
  final logo = t.showLogo ? _img(c.logoB64) : null;
  final cur = c.currency;
  final withPrices = d.type.hasPrices ||
      (d.type == DocType.bordereau && d.showPricesOnDelivery);

  pw.TextStyle st({double k = 1, bool bold = false, PdfColor? color, bool italic = false}) =>
      pw.TextStyle(
        fontSize: fs * k,
        fontWeight: bold ? pw.FontWeight.bold : null,
        fontStyle: italic ? pw.FontStyle.italic : null,
        color: color ?? textColor,
      );

  final pdf = pw.Document(
    title: '${d.type.title} ${d.number}',
    author: c.name,
    creator: 'ETIKPRO',
    theme: await PdfFonts.theme(t.font),
  );

  // ---------- En-tête ----------
  pw.Widget buildHeader(pw.Context ctx) {
    if (header != null) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4 * _mm),
        alignment: pw.Alignment.center,
        constraints: pw.BoxConstraints(maxHeight: t.headerMaxHeightMm * _mm),
        child: pw.Image(header, fit: pw.BoxFit.contain),
      );
    }
    if (!t.showCompanyBlock) return pw.SizedBox(height: 2 * _mm);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4 * _mm),
      padding: const pw.EdgeInsets.only(bottom: 2 * _mm),
      decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: primary, width: 1.2))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (logo != null)
          pw.Container(
              width: 22 * _mm,
              height: 18 * _mm,
              margin: const pw.EdgeInsets.only(right: 4 * _mm),
              child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(c.name.toUpperCase(), style: st(k: 1.6, bold: true, color: primary)),
            if (c.address.isNotEmpty) pw.Text(c.address, style: st(k: 0.95)),
            pw.Text(
                [
                  if (c.phone.isNotEmpty) 'Tél : ${c.phone}',
                  if (c.phone2.isNotEmpty) c.phone2,
                  if (c.email.isNotEmpty) c.email,
                ].join('  •  '),
                style: st(k: 0.95)),
            if (c.ifu.isNotEmpty || c.rccm.isNotEmpty)
              pw.Text(
                  [
                    if (c.ifu.isNotEmpty) 'IFU : ${c.ifu}',
                    if (c.rccm.isNotEmpty) 'RCCM : ${c.rccm}',
                  ].join('  •  '),
                  style: st(k: 0.9)),
          ]),
        ),
      ]),
    );
  }

  // ---------- Pied de page ----------
  pw.Widget buildFooter(pw.Context ctx) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (t.footerText.isNotEmpty)
            pw.Text(t.footerText, style: st(k: 0.8), textAlign: pw.TextAlign.center),
          if (footer != null)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2 * _mm),
              constraints: pw.BoxConstraints(maxHeight: t.footerMaxHeightMm * _mm),
              alignment: pw.Alignment.center,
              child: pw.Image(footer, fit: pw.BoxFit.contain),
            )
          else if (header == null && (c.ifu.isEmpty && c.rccm.isEmpty) && c.name.isNotEmpty)
            pw.Text('${c.name} — ${c.phone}', style: st(k: 0.75)),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${d.number}  —  Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: st(k: 0.75, color: PdfColors.grey700)),
          ),
        ],
      );

  // ---------- Titre ----------
  final align = switch (t.titleAlign) {
    'left' => pw.CrossAxisAlignment.start,
    'center' => pw.CrossAxisAlignment.center,
    _ => pw.CrossAxisAlignment.end,
  };
  final titleText = pw.Column(crossAxisAlignment: align, children: [
    pw.Text(d.type.title,
        style: st(k: 1.9, bold: true, color: t.titleStyle == 'band' ? PdfColors.white : primary)),
    pw.Text('N° ${d.number}   du   ${fmtDate(d.date)}',
        style: st(k: 1.05, bold: true, color: t.titleStyle == 'band' ? PdfColors.white : textColor)),
  ]);
  final title = switch (t.titleStyle) {
    'band' => pw.Container(
        width: double.infinity,
        color: primary,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4 * _mm, vertical: 2.5 * _mm),
        child: titleText),
    'underline' => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 1.5 * _mm),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: primary, width: 2))),
        child: titleText),
    _ => pw.SizedBox(width: double.infinity, child: titleText),
  };

  // ---------- Blocs client / informations ----------
  pw.Widget box(String label, List<String> lines) => pw.Container(
        padding: const pw.EdgeInsets.all(2.5 * _mm),
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(1.5 * _mm),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: st(k: 0.85, bold: true, color: primary)),
          pw.SizedBox(height: 1 * _mm),
          ...lines.where((e) => e.trim().isNotEmpty).map((e) => pw.Text(e, style: st())),
        ]),
      );

  final clientLines = [
    d.clientName.isEmpty ? '—' : d.clientName,
    d.clientAddress,
    if (d.clientPhone.isNotEmpty) 'Tél : ${d.clientPhone}',
    if (d.clientIfu.isNotEmpty) 'IFU : ${d.clientIfu}',
  ];
  final infoLines = [
    'Date : ${fmtDate(d.date)}',
    if (d.sourceNumber != null) 'Réf. : ${d.sourceNumber}',
    if (d.deliveryPlace.isNotEmpty) 'Lieu de livraison : ${d.deliveryPlace}',
    if (d.receiverName.isNotEmpty) 'Réceptionnaire : ${d.receiverName}',
  ];

  // ---------- Tableau des lignes ----------
  final hasDiscount = d.lines.any((l) => l.discount > 0);
  final headers = <String>[
    'N°',
    'Désignation',
    if (!withPrices) 'Unité',
    'Qté',
    if (withPrices) 'P.U. ($cur)',
    if (withPrices && hasDiscount) 'Remise',
    if (withPrices) 'Montant ($cur)',
    if (!withPrices) 'Observations',
  ];
  final widths = <int, pw.TableColumnWidth>{};
  for (var i = 0; i < headers.length; i++) {
    final h = headers[i];
    widths[i] = h == 'Désignation'
        ? const pw.FlexColumnWidth(5)
        : h == 'N°'
            ? const pw.FixedColumnWidth(8 * _mm)
            : h == 'Observations'
                ? const pw.FlexColumnWidth(2.5)
                : const pw.FlexColumnWidth(1.6);
  }

  List<String> rowOf(int i, DocLine l) => [
        '${i + 1}',
        l.designation,
        if (!withPrices) l.unit,
        withPrices && l.unit.isNotEmpty ? '${fmtQty(l.qty)} ${l.unit}' : fmtQty(l.qty),
        if (withPrices) fmtAmount(l.unitPrice),
        if (withPrices && hasDiscount) l.discount > 0 ? '${fmtQty(l.discount)} %' : '',
        if (withPrices) fmtAmount(l.total),
        if (!withPrices) '',
      ];

  pw.Alignment cellAlign(int col) {
    final h = headers[col];
    if (h == 'Désignation' || h == 'Observations') return pw.Alignment.centerLeft;
    if (h == 'N°' || h == 'Unité' || h == 'Remise') return pw.Alignment.center;
    return pw.Alignment.centerRight;
  }

  final grid = t.tableStyle == 'grid';
  final minimal = t.tableStyle == 'minimal';
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: minimal
          ? pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: primary, width: 1.2)))
          : pw.BoxDecoration(color: primary),
      repeat: true,
      children: [
        for (var i = 0; i < headers.length; i++)
          pw.Container(
            alignment: cellAlign(i),
            padding: const pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm, vertical: 1.8 * _mm),
            child: pw.Text(headers[i],
                style: st(k: 0.92, bold: true, color: minimal ? primary : PdfColors.white)),
          ),
      ],
    ),
    for (var r = 0; r < d.lines.length; r++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: t.tableStyle == 'striped' && r.isOdd ? accent : null,
          border: minimal
              ? const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))
              : null,
        ),
        children: [
          for (final (i, v) in rowOf(r, d.lines[r]).indexed)
            pw.Container(
              alignment: cellAlign(i),
              padding: const pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm, vertical: 1.6 * _mm),
              child: pw.Text(v, style: st()),
            ),
        ],
      ),
  ];
  final table = pw.Table(
    columnWidths: widths,
    border: grid
        ? pw.TableBorder.all(color: PdfColors.grey500, width: 0.5)
        : (minimal ? null : const pw.TableBorder(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
    children: rows,
  );

  // ---------- Totaux ----------
  pw.Widget totalRow(String k, String v, {bool strong = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2 * _mm, vertical: 1.3 * _mm),
        color: strong ? primary : null,
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(k, style: st(bold: strong, color: strong ? PdfColors.white : null))),
          pw.Text('$v $cur',
              style: st(k: strong ? 1.15 : 1, bold: true, color: strong ? PdfColors.white : null)),
        ]),
      );

  final totals = withPrices
      ? pw.Row(children: [
          pw.Spacer(flex: 5),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: primary, width: 0.8)),
              child: pw.Column(children: [
                if (d.globalDiscount > 0 || d.vatRate > 0)
                  totalRow(d.vatRate > 0 ? 'Total HT' : 'Sous-total', fmtAmount(d.subtotal)),
                if (d.globalDiscount > 0)
                  totalRow('Remise', '- ${fmtAmount(d.globalDiscount)}'),
                if (d.globalDiscount > 0 && d.vatRate > 0)
                  totalRow('Net HT', fmtAmount(d.afterDiscount)),
                if (d.vatRate > 0)
                  totalRow('TVA (${fmtQty(d.vatRate)} %)', fmtAmount(d.vatAmount)),
                totalRow(d.vatRate > 0 ? 'TOTAL TTC' : 'TOTAL', fmtAmount(d.total),
                    strong: true),
              ]),
            ),
          ),
        ])
      : pw.Row(children: [
          pw.Spacer(),
          pw.Text(
              'Nombre total d’articles : ${fmtQty(d.lines.fold(0.0, (s, l) => s + l.qty))}',
              style: st(bold: true)),
        ]);

  // ---------- Signatures ----------
  pw.Widget sig(String label) => pw.Expanded(
        child: pw.Column(children: [
          pw.Text(label, style: st(bold: true)),
          pw.SizedBox(height: 18 * _mm),
          pw.Container(height: 0.6, color: PdfColors.grey600, margin: const pw.EdgeInsets.symmetric(horizontal: 6 * _mm)),
        ]),
      );

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(
      marginLeft: t.marginMm * _mm,
      marginRight: t.marginMm * _mm,
      marginTop: (header != null ? 6 : t.marginMm) * _mm,
      marginBottom: (footer != null ? 5 : t.marginMm) * _mm,
    ),
    header: buildHeader,
    footer: buildFooter,
    build: (ctx) => [
      title,
      pw.SizedBox(height: 4 * _mm),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            child: box(
                d.type == DocType.decharge ? 'BÉNÉFICIAIRE' : 'CLIENT', clientLines)),
        pw.SizedBox(width: 4 * _mm),
        pw.Expanded(child: box('INFORMATIONS', infoLines)),
      ]),
      if (d.subject.isNotEmpty) ...[
        pw.SizedBox(height: 3 * _mm),
        pw.RichText(
            text: pw.TextSpan(children: [
          pw.TextSpan(text: 'Objet : ', style: st(bold: true)),
          pw.TextSpan(text: d.subject, style: st()),
        ])),
      ],
      if (d.type == DocType.decharge && d.dischargeText.isNotEmpty) ...[
        pw.SizedBox(height: 4 * _mm),
        pw.Paragraph(text: d.dischargeText, style: st(k: 1.05).copyWith(lineSpacing: 3)),
      ],
      pw.SizedBox(height: 4 * _mm),
      if (d.lines.isNotEmpty) table,
      pw.SizedBox(height: 3 * _mm),
      if (d.lines.isNotEmpty) totals,
      if (withPrices && t.showAmountInWords && d.total > 0) ...[
        pw.SizedBox(height: 3 * _mm),
        pw.RichText(
            text: pw.TextSpan(children: [
          pw.TextSpan(text: '${_amountPhrase(d.type)} : ', style: st()),
          pw.TextSpan(text: amountInWords(d.total, cur), style: st(bold: true, italic: true)),
        ])),
      ],
      if (d.conditions.isNotEmpty) ...[
        pw.SizedBox(height: 4 * _mm),
        pw.Text('Conditions', style: st(bold: true, color: primary)),
        pw.Text(d.conditions, style: st()),
      ],
      if (d.notes.isNotEmpty) ...[
        pw.SizedBox(height: 3 * _mm),
        pw.Text('Notes', style: st(bold: true, color: primary)),
        pw.Text(d.notes, style: st()),
      ],
      if (t.showSignatures) ...[
        pw.SizedBox(height: 8 * _mm),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          sig(d.type == DocType.bordereau || d.type == DocType.decharge
              ? (d.type == DocType.decharge ? 'Le bénéficiaire' : 'Reçu par')
              : t.signatureLeft),
          sig(d.type == DocType.bordereau
              ? 'Livré par'
              : (d.type == DocType.decharge ? 'Le remettant' : t.signatureRight)),
        ]),
      ],
    ],
  ));

  return pdf.save();
}
