import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Mesure la largeur d'un texte (en « em » : multiplier par la taille de police).
class TextMeasure {
  final TtfParser regular;
  final TtfParser bold;
  TextMeasure(this.regular, this.bold);

  double width(String text, {bool isBold = false}) {
    final p = isBold ? bold : regular;
    var w = 0.0;
    for (final r in text.runes) {
      final g = p.charToGlyphIndexMap[r];
      w += (g == null ? 0.55 : (p.glyphInfoMap[g]?.advanceWidth ?? 0.55));
    }
    return w;
  }
}

/// Polices Unicode embarquées (Liberation, licence SIL OFL) :
/// équivalentes à Arial / Times / Courier, avec les accents, °, •, —, ’…
class PdfFonts {
  static final Map<String, pw.ThemeData> _cache = {};
  static final Map<String, ByteData> _bytes = {};
  static TextMeasure? _measure;

  static Future<ByteData> _load(String name) async =>
      _bytes[name] ??= await rootBundle.load('assets/fonts/$name.ttf');

  static Future<pw.Font> _f(String name) async => pw.Font.ttf(await _load(name));

  /// family : helvetica | times | courier
  static Future<pw.ThemeData> theme(String family) async {
    final key = switch (family) {
      'times' => 'Serif',
      'courier' => 'Mono',
      _ => 'Sans',
    };
    final cached = _cache[key];
    if (cached != null) return cached;
    final t = pw.ThemeData.withFont(
      base: await _f('Liberation$key-Regular'),
      bold: await _f('Liberation$key-Bold'),
      italic: await _f('Liberation$key-Italic'),
      boldItalic: await _f('Liberation$key-BoldItalic'),
    );
    _cache[key] = t;
    return t;
  }

  /// Mesureur pour la police des étiquettes (Liberation Sans).
  static Future<TextMeasure> measure() async => _measure ??= TextMeasure(
        TtfParser(await _load('LiberationSans-Regular')),
        TtfParser(await _load('LiberationSans-Bold')),
      );
}
