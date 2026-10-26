import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prépare un logo pour les étiquettes :
/// - fond transparent remplacé par du blanc,
/// - redimensionné (max 600 px, suffisant pour une étiquette),
/// - [mono] : converti en noir et blanc pur (idéal pour imprimantes thermiques).
String prepareLabelLogo(Uint8List bytes, {bool mono = true, int threshold = 150}) {
  final src = img.decodeImage(bytes);
  if (src == null) throw Exception('Image illisible');
  var im = src;
  final maxSide = im.width > im.height ? im.width : im.height;
  if (maxSide > 600) {
    im = im.width >= im.height
        ? img.copyResize(im, width: 600, interpolation: img.Interpolation.average)
        : img.copyResize(im, height: 600, interpolation: img.Interpolation.average);
  }
  // Aplatit sur fond blanc
  final flat = img.Image(width: im.width, height: im.height);
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, im);
  img.Image out = flat;
  if (mono) {
    out = img.Image(width: flat.width, height: flat.height);
    for (final p in flat) {
      final lum = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;
      final v = lum < threshold ? 0 : 255;
      out.setPixelRgb(p.x, p.y, v, v, v);
    }
  }
  return base64Encode(img.encodePng(out));
}
