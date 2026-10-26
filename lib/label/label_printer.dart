import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../core/models.dart';
import '../core/templates.dart';
import 'bt.dart';
import 'label_pdf.dart';
import 'printer_commands.dart';

const _dpi = 203.0; // 8 points / mm, standard des imprimantes thermiques

/// Rend une étiquette en image monochrome pour l'imprimante thermique.
Future<MonoBitmap> renderLabelBitmap(
    LabelData data, LabelStyle style, LabelFormat format,
    {int threshold = 160}) async {
  final pdf = await buildLabelsPdf(data: data, style: style, format: format);
  final raster = await Printing.raster(pdf, pages: [0], dpi: _dpi).first;
  int? target;
  if (format.mode == PrintMode.escpos) {
    target = format.widthMm >= 70 ? 576 : 384;
  }
  final bmp = MonoBitmap.fromRgba(raster.pixels, raster.width, raster.height,
      threshold: threshold, targetWidth: target);
  return format.mode == PrintMode.escpos ? bmp.trimBottom() : bmp;
}

/// Impression directe sur imprimante Bluetooth. Renvoie null si OK.
Future<String?> printLabelBluetooth({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  required PrinterSettings settings,
  int copies = 1,
}) async {
  if (!btSupported) return 'Impression Bluetooth disponible sur Android et Windows.';
  final addr = settings.btAddress;
  if (addr == null || addr.isEmpty) {
    return 'Choisissez une imprimante Bluetooth dans Réglages › Imprimante.';
  }
  if (format.mode == PrintMode.a4) {
    return 'Les planches A4 s’impriment avec « Imprimer (PDF) ».';
  }
  final bmp = await renderLabelBitmap(data, style, format,
      threshold: settings.threshold);
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

/// Impression via le système (Windows, Web, Android avec pilote / PDF).
Future<void> printLabelSystem({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0,
}) async {
  final Uint8List bytes = await buildLabelsPdf(
      data: data, style: style, format: format, copies: copies, skipCells: skipCells);
  final pf = format.mode == PrintMode.a4
      ? PdfPageFormat.a4
      : PdfPageFormat(format.widthMm * PdfPageFormat.mm,
          format.heightMm * PdfPageFormat.mm,
          marginAll: 0);
  await Printing.layoutPdf(
    name: 'Etiquettes_${data.product}',
    format: pf,
    usePrinterSettings: format.mode != PrintMode.a4,
    onLayout: (_) async => bytes,
  );
}
