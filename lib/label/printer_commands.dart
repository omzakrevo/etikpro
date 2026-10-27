import 'dart:convert';
import 'dart:typed_data';

/// Image monochrome : 1 bit par point, lignes de [widthBytes] octets.
/// Bit à 1 = point noir.
class MonoBitmap {
  final int width;
  final int height;
  final Uint8List data;
  MonoBitmap(this.width, this.height, this.data);
  int get widthBytes => (width + 7) ~/ 8;

  /// Convertit des pixels RGBA en monochrome (seuil sur la luminance).
  factory MonoBitmap.fromRgba(
    Uint8List rgba,
    int width,
    int height, {
    int threshold = 160,
    int? targetWidth,
  }) {
    final outW = targetWidth ?? width;
    final wb = (outW + 7) ~/ 8;
    final out = Uint8List(wb * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < outW && x < width; x++) {
        final i = (y * width + x) * 4;
        final a = rgba[i + 3];
        // Pixel transparent = blanc
        final lum = a < 128 ? 255 : (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        if (lum < threshold) {
          out[y * wb + (x >> 3)] |= (0x80 >> (x & 7));
        }
      }
    }
    return MonoBitmap(outW, height, out);
  }

  /// Supprime les lignes blanches en bas (économie de papier en ticket).
  MonoBitmap trimBottom({int keep = 8}) {
    var last = height - 1;
    final wb = widthBytes;
    bool blank(int y) {
      for (var b = 0; b < wb; b++) {
        if (data[y * wb + b] != 0) return false;
      }
      return true;
    }

    while (last > 0 && blank(last)) {
      last--;
    }
    final h = (last + 1 + keep).clamp(1, height);
    return MonoBitmap(width, h, Uint8List.sublistView(data, 0, h * wb));
  }
}

/// Commandes TSPL (imprimantes d'étiquettes Xprinter, HPRT, Gprinter, TSC...).
List<int> buildTspl(
  MonoBitmap bmp, {
  required double widthMm,
  required double heightMm,
  double gapMm = 2,
  int copies = 1,
  int density = 8,
  int speed = 4,
  bool invert = false,
}) {
  String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  final out = BytesBuilder();
  void cmd(String s) => out.add(ascii.encode('$s\r\n'));
  cmd('SIZE ${n(widthMm)} mm,${n(heightMm)} mm');
  cmd('GAP ${n(gapMm)} mm,0 mm');
  cmd('SPEED $speed');
  cmd('DENSITY $density');
  cmd('DIRECTION 1,0');
  cmd('REFERENCE 0,0');
  cmd('CLS');
  out.add(ascii.encode('BITMAP 0,0,${bmp.widthBytes},${bmp.height},0,'));
  // En TSPL, un bit à 0 imprime un point noir : on inverse nos données
  // (sauf si l'imprimante fonctionne à l'envers -> option "invert").
  final data = Uint8List.fromList(bmp.data);
  if (!invert) {
    for (var i = 0; i < data.length; i++) {
      data[i] = ~data[i] & 0xFF;
    }
  }
  out.add(data);
  out.add(ascii.encode('\r\n'));
  cmd('PRINT 1,${copies.clamp(1, 999)}');
  return out.takeBytes();
}

/// Commandes ESC/POS (imprimantes tickets 58 / 80 mm) : image raster GS v 0.
List<int> buildEscPos(MonoBitmap bmp, {int copies = 1, bool cut = true}) {
  final out = BytesBuilder();
  out.add([0x1B, 0x40]); // ESC @ : initialisation
  out.add([0x1B, 0x61, 0x01]); // centré
  for (var c = 0; c < copies.clamp(1, 200); c++) {
    // On découpe en bandes de 256 lignes (meilleure compatibilité)
    const band = 256;
    for (var y0 = 0; y0 < bmp.height; y0 += band) {
      final h = (bmp.height - y0) < band ? bmp.height - y0 : band;
      final wb = bmp.widthBytes;
      out.add([0x1D, 0x76, 0x30, 0x00, wb & 0xFF, (wb >> 8) & 0xFF, h & 0xFF, (h >> 8) & 0xFF]);
      out.add(Uint8List.sublistView(bmp.data, y0 * wb, (y0 + h) * wb));
    }
    out.add([0x1B, 0x64, 0x03]); // avance de 3 lignes
    if (cut) out.add([0x1D, 0x56, 0x42, 0x00]); // coupe partielle
  }
  return out.takeBytes();
}

/// TSPL : calibrage automatique de la taille des étiquettes et de l'espace (GAP).
List<int> buildTsplCalibrate() => ascii.encode('GAPDETECT\r\nHOME\r\n');
