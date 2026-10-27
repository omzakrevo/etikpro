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
Future<MonoBitmap> rasterLabel(
  Uint8List pdf,
  LabelFormat format, {
  int threshold = 160,
  bool escpos = false,
}) async {
  // En ESC/POS, la tête fait 384 points (58 mm) ou 576 points (80 mm) :
  // on réduit la résolution si l'étiquette est plus large, pour ne rien couper.
  var dpi = _dpi;
  final maxDots = format.widthMm > 60 ? 576 : 384;
  final dots = format.widthMm / 25.4 * _dpi;
  if (escpos && dots > maxDots) dpi = _dpi * maxDots / dots;
  final raster = await Printing.raster(pdf, pages: [0], dpi: dpi).first;
  int? target;
  if (escpos && format.mode == PrintMode.escpos) target = maxDots;
  final bmp = MonoBitmap.fromRgba(
    raster.pixels,
    raster.width,
    raster.height,
    threshold: threshold,
    targetWidth: target,
  );
  return escpos && format.mode == PrintMode.escpos ? bmp.trimBottom() : bmp;
}

/// Langage réellement utilisé : réglage de l'imprimante, sinon déduit du format.
bool useEscPos(LabelFormat format, PrinterSettings settings) => switch (settings.language) {
  'escpos' => true,
  'tspl' => false,
  _ => format.mode == PrintMode.escpos,
};

/// Commandes à envoyer pour une étiquette (PDF d'une page).
Future<List<int>> labelBytes(
  Uint8List onePagePdf,
  LabelFormat format,
  PrinterSettings settings, {
  int copies = 1,
}) async {
  final esc = useEscPos(format, settings);
  final bmp = await rasterLabel(onePagePdf, format, threshold: settings.threshold, escpos: esc);
  return esc
      ? buildEscPos(bmp, copies: copies, cut: format.mode == PrintMode.escpos)
      : buildTspl(
          bmp,
          widthMm: format.widthMm,
          heightMm: format.heightMm,
          gapMm: settings.gapMm,
          copies: copies,
          density: settings.density,
          speed: settings.speed,
          invert: settings.invertTspl,
        );
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
  final bytes = await labelBytes(onePagePdf, format, settings, copies: copies);
  return btSend(addr, bytes, ble: settings.btBle);
}

/// Impression directe d'une étiquette produit sur imprimante Bluetooth.
Future<String?> printLabelBluetooth({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  required PrinterSettings settings,
  int copies = 1,
}) async => printPdfLabelBluetooth(
  onePagePdf: await buildLabelsPdf(data: data, style: style, format: format),
  format: format,
  settings: settings,
  copies: copies,
);

/// Impression via le système (Windows, Web, Android avec pilote / PDF).
Future<void> printPdfSystem(Uint8List bytes, LabelFormat format, String name) => Printing.layoutPdf(
  name: name,
  format: format.mode == PrintMode.a4
      ? PdfPageFormat.a4
      : PdfPageFormat(format.widthMm * PdfPageFormat.mm, format.heightMm * PdfPageFormat.mm, marginAll: 0),
  usePrinterSettings: format.mode != PrintMode.a4,
  onLayout: (_) async => bytes,
);

Future<void> printLabelSystem({
  required LabelData data,
  required LabelStyle style,
  required LabelFormat format,
  int copies = 1,
  int skipCells = 0,
}) async => printPdfSystem(
  await buildLabelsPdf(data: data, style: style, format: format, copies: copies, skipCells: skipCells),
  format,
  'Etiquettes_${data.product}',
);
