import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../core/models.dart';
import '../core/templates.dart';
import 'bt.dart';
import 'label_pdf.dart';
import 'printer_commands.dart';

const _dpi = 203.0; // 8 points / mm, standard des imprimantes thermiques

/// Convertit la 1re page d'un PDF d'étiquette en image monochrome.
Future<MonoBitmap> rasterLabel(Uint8List pdf, LabelFormat format, {int threshold = 160}) async {
  final raster = await Printing.raster(pdf, pages: [0], dpi: _dpi).first;
  int? target;
  if (format.mode == PrintMode.escpos) {
    target = format.widthMm >= 70 ? 576 : 384;
  }
  final bmp = MonoBitmap.fromRgba(raster.pixels, raster.width, raster.height,
      threshold: threshold, targetWidth: target);
  return format.mode == PrintMode.escpos ? bmp.trimBottom() : bmp;
}

/// Envoie une étiquette (PDF d'une page) sur l'imprimante Bluetooth. Renvoie null si OK.
Future<String?> printPdfLabelBluetooth({
  required Uint8List onePagePdf,
  required LabelFormat format,
  required PrinterSettings settings,
  int copies = 1,
}) async {
  if (!btSupported) return 'Impression Bluetooth disponible sur Android et Windows.';
  final addr = settings.btAddress;
  if (addr == null || addr.isEmpty) {
    return 'Aucune imprimante connectée. Touchez « Imprimante » pour en choisir une.';
  }
  if (format.mode == PrintMode.a4) {
    return 'Les planches A4 s’impriment avec « Imprimer (PDF) ».';
  }
  final bmp = await rasterLabel(onePagePdf, format, threshold: settings.threshold);
  final List<int> bytes = format.mode == PrintMode.tspl
      ? buildTspl(bmp,
          widthMm: format.widthMm,
          heightMm: format.heightMm,
          gapMm: settings.gapMm,
          copies: copies,
          density: settings.density,
          speed: settings.speed,
          invert: settings.invertTspl)
      : buildEscPos(bmp, copies: copies);
  return btSend(addr, bytes);
}

/// Impression directe d'une étiquette produit sur imprimante Bluetooth.
Future<String?> printLabelBluetooth({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  required PrinterSettings settings,
  int copies = 1,
}) async =>
    printPdfLabelBluetooth(
      onePagePdf: await buildLabelsPdf(data: data, style: style, format: format),
      format: format,
      settings: settings,
      copies: copies,
    );

/// Impression via le système (Windows, Web, Android avec pilote / PDF).
Future<void> printPdfSystem(Uint8List bytes, LabelFormat format, String name) =>
    Printing.layoutPdf(
      name: name,
      format: format.mode == PrintMode.a4
          ? PdfPageFormat.a4
          : PdfPageFormat(format.widthMm * PdfPageFormat.mm, format.heightMm * PdfPageFormat.mm,
              marginAll: 0),
      usePrinterSettings: format.mode != PrintMode.a4,
      onLayout: (_) async => bytes,
    );

Future<void> printLabelSystem({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0,
}) async =>
    printPdfSystem(
      await buildLabelsPdf(
          data: data, style: style, format: format, copies: copies, skipCells: skipCells),
      format,
      'Etiquettes_${data.product}',
    );
