import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:etikpro/core/image_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

double iou(NRect a, List b) {
  final l = math.max(a.l, b[0] as double), t = math.max(a.t, b[1] as double);
  final r = math.min(a.r, b[2] as double), btm = math.min(a.b, b[3] as double);
  final inter = math.max(0, r - l) * math.max(0, btm - t);
  final ua = a.w * a.h + ((b[2] as double) - b[0]) * ((b[3] as double) - b[1]) - inter;
  return inter / ua;
}

void main() {
  final cases = jsonDecode(File('test/fixtures/stickers.json').readAsStringSync()) as List;
  for (final c in cases) {
    test('détourage automatique : ${c['file']}', () {
      final photo = loadStickerPhoto(File('test/fixtures/${c['file']}').readAsBytesSync());
      final score = iou(photo.auto, c['box'] as List);
      // ignore: avoid_print
      print('${c['file']} -> ${photo.auto}  IoU=${score.toStringAsFixed(3)}');
      expect(score, greaterThan(0.85));
      final out = cropSticker(photo.image, photo.auto);
      Directory('build/apercus').createSync(recursive: true);
      File('build/apercus/crop_${c['file']}').writeAsBytesSync(base64Decode(out));
    });
  }

  test('cachet : fond blanc retiré', () {
    final im = img.Image(width: 300, height: 300);
    img.fill(im, color: img.ColorRgb8(245, 245, 240));
    img.drawCircle(im, x: 150, y: 150, radius: 110, color: img.ColorRgb8(30, 60, 170));
    img.drawCircle(im, x: 150, y: 150, radius: 108, color: img.ColorRgb8(30, 60, 170));
    img.drawString(im, 'CACHET', font: img.arial24, x: 105, y: 140, color: img.ColorRgb8(30, 60, 170));
    final out = img.decodePng(base64Decode(prepareStamp(img.encodePng(im))))!;
    expect(out.numChannels, 4);
    // coin : transparent ; contour : opaque
    expect(out.getPixel(2, out.height ~/ 2).a, lessThan(20));
    var opaque = 0;
    for (final p in out) {
      if (p.a > 200) opaque++;
    }
    expect(opaque, greaterThan(300));
    expect(out.width, lessThan(300)); // recadré au plus près
    File('build/apercus/cachet_test.png').writeAsBytesSync(img.encodePng(out));
  });
}
