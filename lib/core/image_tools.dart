import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prépare un logo pour les étiquettes :
/// - fond transparent remplacé par du blanc,
/// - redimensionné (max 600 px, suffisant pour une étiquette),
/// - [mono] : converti en noir et blanc pur (idéal pour imprimantes thermiques).
String prepareLabelLogo(Uint8List bytes, {bool mono = true, int threshold = 150}) {
  final src = img.decodeImage(bytes);
  if (src == null) throw Exception('Image illisible');
  final im = _limit(img.bakeOrientation(src), 600);
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

img.Image _limit(img.Image im, int maxSide) {
  final m = math.max(im.width, im.height);
  if (m <= maxSide) return im;
  return im.width >= im.height
      ? img.copyResize(im, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(im, height: maxSide, interpolation: img.Interpolation.average);
}

/// Cachet : retire le fond blanc / clair du scan ou de la photo (devient transparent),
/// renforce l'encre et recadre au plus près.
String prepareStamp(Uint8List bytes, {int whiteLevel = 200}) {
  final src = img.decodeImage(bytes);
  if (src == null) throw Exception('Image illisible');
  final im = _limit(img.bakeOrientation(src), 900);
  final out = img.Image(width: im.width, height: im.height, numChannels: 4);
  var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
  for (final p in im) {
    final a0 = p.a.toInt();
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
    final sat = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    // plus c'est clair et peu coloré, plus c'est transparent
    var ink = ((whiteLevel - lum) / (whiteLevel - 90)).clamp(0.0, 1.0);
    if (sat > 40) ink = math.max(ink, ((sat - 40) / 60).clamp(0.0, 1.0));
    final alpha = (ink * (a0 / 255) * 255).round();
    if (alpha > 12) {
      // couleur un peu plus intense pour un rendu « encre »
      out.setPixelRgba(p.x, p.y, (r * .85).round(), (g * .85).round(), (b * .85).round(), alpha);
      if (alpha > 60) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    } else {
      out.setPixelRgba(p.x, p.y, 255, 255, 255, 0);
    }
  }
  if (maxX < 0) throw Exception('Aucun cachet détecté sur l’image');
  final pad = (math.max(maxX - minX, maxY - minY) * .03).round();
  final cropped = img.copyCrop(out,
      x: math.max(0, minX - pad),
      y: math.max(0, minY - pad),
      width: math.min(out.width, maxX + pad) - math.max(0, minX - pad),
      height: math.min(out.height, maxY + pad) - math.max(0, minY - pad));
  return base64Encode(img.encodePng(cropped));
}

/// Rectangle normalisé (0..1).
class NRect {
  final double l, t, r, b;
  const NRect(this.l, this.t, this.r, this.b);
  static const full = NRect(0, 0, 1, 1);
  double get w => r - l;
  double get h => b - t;
  NRect clamp() {
    final l2 = l.clamp(0.0, .98), t2 = t.clamp(0.0, .98);
    return NRect(l2, t2, r.clamp(l2 + .02, 1.0), b.clamp(t2 + .02, 1.0));
  }

  @override
  String toString() =>
      'NRect(${l.toStringAsFixed(3)}, ${t.toStringAsFixed(3)}, ${r.toStringAsFixed(3)}, ${b.toStringAsFixed(3)})';
}

/// Photo de sticker prête à recadrer.
class StickerPhoto {
  final img.Image image; // orientation corrigée, max 1800 px
  final NRect auto; // cadre détecté automatiquement
  StickerPhoto(this.image, this.auto);
}

StickerPhoto loadStickerPhoto(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) throw Exception('Image illisible');
  final im = _limit(img.bakeOrientation(src), 1800);
  return StickerPhoto(im, detectSticker(im));
}

/// Détecte automatiquement le sticker posé sur un fond (table, bureau…).
///
/// Principe : la couleur du fond est estimée sur les bords de la photo, puis on
/// garde la plus grande zone qui s'en distingue nettement (le sticker).
NRect detectSticker(img.Image photo) {
  const target = 320;
  final small = _limit(photo, target);
  final w = small.width, h = small.height;
  if (w < 20 || h < 20) return NRect.full;

  // 1. Couleur et bruit du fond, estimés sur une bande de bord de 4 %
  final band = math.max(2, (math.min(w, h) * .04).round());
  final rs = <int>[], gs = <int>[], bs = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x < band || y < band || x >= w - band || y >= h - band) {
        final p = small.getPixel(x, y);
        rs.add(p.r.toInt());
        gs.add(p.g.toInt());
        bs.add(p.b.toInt());
      }
    }
  }
  int median(List<int> l) => (l..sort())[l.length ~/ 2];
  final br = median(rs), bg = median(gs), bb = median(bs);
  final devs = <int>[];
  for (var i = 0; i < rs.length; i++) {
    devs.add(math.max((rs[i] - br).abs(), math.max((gs[i] - bg).abs(), (bs[i] - bb).abs())));
  }
  final noise = (devs..sort())[(devs.length * .9).floor().clamp(0, devs.length - 1)];
  final threshold = math.max(34, (noise * 1.4).round());

  // 2. Masque des pixels différents du fond
  var mask = List<bool>.filled(w * h, false);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = small.getPixel(x, y);
      final d = math.max((p.r - br).abs(), math.max((p.g - bg).abs(), (p.b - bb).abs()));
      mask[y * w + x] = d > threshold;
    }
  }

  // 3. Fermeture morphologique (dilatation puis érosion) pour boucher les trous
  List<bool> morph(List<bool> m, bool dilate) {
    final o = List<bool>.filled(w * h, !dilate);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = !dilate;
        for (var dy = -1; dy <= 1 && v != dilate; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx, yy = y + dy;
            final inside = xx >= 0 && yy >= 0 && xx < w && yy < h;
            final mv = inside ? m[yy * w + xx] : false;
            if (mv == dilate) {
              v = dilate;
              break;
            }
          }
        }
        o[y * w + x] = v;
      }
    }
    return o;
  }

  for (var i = 0; i < 3; i++) {
    mask = morph(mask, true);
  }
  for (var i = 0; i < 3; i++) {
    mask = morph(mask, false);
  }

  // 4. Plus grande composante connexe
  final label = List<int>.filled(w * h, 0);
  var bestArea = 0, bestMinX = 0, bestMinY = 0, bestMaxX = w - 1, bestMaxY = h - 1;
  var cur = 0;
  for (var i = 0; i < w * h; i++) {
    if (!mask[i] || label[i] != 0) continue;
    cur++;
    var area = 0, minX = w, minY = h, maxX = 0, maxY = 0;
    final q = Queue<int>()..add(i);
    label[i] = cur;
    while (q.isNotEmpty) {
      final k = q.removeFirst();
      final x = k % w, y = k ~/ w;
      area++;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      for (final n in [k - 1, k + 1, k - w, k + w]) {
        if (n < 0 || n >= w * h) continue;
        if ((n == k - 1 && x == 0) || (n == k + 1 && x == w - 1)) continue;
        if (mask[n] && label[n] == 0) {
          label[n] = cur;
          q.add(n);
        }
      }
    }
    if (area > bestArea) {
      bestArea = area;
      bestMinX = minX;
      bestMinY = minY;
      bestMaxX = maxX;
      bestMaxY = maxY;
    }
  }

  final boxArea = (bestMaxX - bestMinX + 1) * (bestMaxY - bestMinY + 1);
  if (bestArea == 0 || boxArea < w * h * .03 || boxArea > w * h * .97) return NRect.full;

  final padX = (bestMaxX - bestMinX) * .004, padY = (bestMaxY - bestMinY) * .004;
  return NRect(
    (bestMinX - padX) / w,
    (bestMinY - padY) / h,
    (bestMaxX + 1 + padX) / w,
    (bestMaxY + 1 + padY) / h,
  ).clamp();
}

/// Applique rotation (quarts de tour) et recadrage, renvoie un JPEG en base64.
String cropSticker(img.Image photo, NRect r, {int quarterTurns = 0}) {
  var im = photo;
  if (quarterTurns % 4 != 0) im = img.copyRotate(im, angle: 90 * (quarterTurns % 4));
  final x = (r.l * im.width).round(), y = (r.t * im.height).round();
  final cw = math.max(8, (r.w * im.width).round()), ch = math.max(8, (r.h * im.height).round());
  var out = img.copyCrop(im,
      x: x, y: y, width: math.min(cw, im.width - x), height: math.min(ch, im.height - y));
  out = _limit(out, 1000);
  return base64Encode(img.encodeJpg(out, quality: 88));
}

/// Rotation d'une image déjà chargée (pour l'écran de recadrage).
img.Image rotateQuarter(img.Image im, int turns) =>
    turns % 4 == 0 ? im : img.copyRotate(im, angle: 90 * (turns % 4));

Uint8List encodePreview(img.Image im) => Uint8List.fromList(img.encodeJpg(_limit(im, 1200), quality: 80));
