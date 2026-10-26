import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0', 'fr_FR');
final _money2 = NumberFormat('#,##0.##', 'fr_FR');

/// 125000 -> "125 000" (espace insécable remplacé par une espace simple pour le PDF)
String fmtAmount(double v) {
  final s = (v == v.roundToDouble()) ? _money.format(v) : _money2.format(v);
  return s.replaceAll(' ', ' ').replaceAll(' ', ' ');
}

String fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : _money2.format(v).replaceAll(' ', ' ').replaceAll(' ', ' ');

String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String fmtDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _units = [
  'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
  'dix-sept', 'dix-huit', 'dix-neuf'
];
const _tens = [
  '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante'
];

/// 0..99
String _below100(int n, {bool plural80 = true}) {
  if (n < 20) return _units[n];
  if (n < 70) {
    final t = n ~/ 10, u = n % 10;
    if (u == 0) return _tens[t];
    if (u == 1) return '${_tens[t]} et un';
    return '${_tens[t]}-${_units[u]}';
  }
  if (n < 80) {
    final r = n - 60;
    if (r == 11) return 'soixante et onze';
    return 'soixante-${_units[r]}';
  }
  final r = n - 80;
  if (r == 0) return plural80 ? 'quatre-vingts' : 'quatre-vingt';
  return 'quatre-vingt-${_units[r]}';
}

/// 0..999 ; [last] = vrai si rien ne suit (accord de cent/quatre-vingt).
String _below1000(int n, {bool last = true}) {
  final h = n ~/ 100, r = n % 100;
  final parts = <String>[];
  if (h > 0) {
    if (h == 1) {
      parts.add('cent');
    } else {
      parts.add('${_units[h]} ${r == 0 && last ? 'cents' : 'cent'}');
    }
  }
  if (r > 0) parts.add(_below100(r, plural80: last));
  return parts.join(' ');
}

/// Convertit un entier en toutes lettres (français).
String numberToWords(int n) {
  if (n == 0) return 'zéro';
  if (n < 0) return 'moins ${numberToWords(-n)}';
  final parts = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n ~/ 1000000) % 1000;
  final milliers = (n ~/ 1000) % 1000;
  final reste = n % 1000;
  if (milliards > 0) {
    parts.add('${_below1000(milliards)} milliard${milliards > 1 ? 's' : ''}');
  }
  if (millions > 0) {
    parts.add('${_below1000(millions)} million${millions > 1 ? 's' : ''}');
  }
  if (milliers > 0) {
    parts.add(milliers == 1 ? 'mille' : '${_below1000(milliers, last: false)} mille');
  }
  if (reste > 0) parts.add(_below1000(reste));
  return parts.join(' ');
}

String amountInWords(double amount, String currency) {
  final n = amount.round();
  final words = numberToWords(n);
  final cur = currency.toUpperCase() == 'FCFA' ? 'francs CFA' : currency;
  return '${words[0].toUpperCase()}${words.substring(1)} ($n) $cur'
      .replaceAll('($n)', '(${fmtAmount(n.toDouble())})');
}
