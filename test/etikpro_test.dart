import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:etikpro/core/image_tools.dart';
import 'package:etikpro/core/licence.dart';
import 'package:etikpro/core/models.dart';
import 'package:etikpro/core/store.dart';
import 'package:etikpro/core/templates.dart';
import 'package:etikpro/core/utils.dart';
import 'package:etikpro/docs/doc_pdf.dart';
import 'package:etikpro/label/label_pdf.dart';
import 'package:etikpro/label/printer_commands.dart';
import 'package:etikpro/ui/settings/templates_screen.dart' show sampleDoc;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final dir = await Directory.systemTemp.createTemp('etik');
    await AppStore.I.initForTest(dir.path);
  });

  group('Montants en lettres', () {
    final cases = {
      1: 'un',
      21: 'vingt et un',
      71: 'soixante et onze',
      80: 'quatre-vingts',
      81: 'quatre-vingt-un',
      99: 'quatre-vingt-dix-neuf',
      200: 'deux cents',
      201: 'deux cent un',
      1000: 'mille',
      80000: 'quatre-vingt mille',
      200000: 'deux cent mille',
      1250000: 'un million deux cent cinquante mille',
      2000000: 'deux millions',
      326500: 'trois cent vingt-six mille cinq cents',
    };
    cases.forEach((n, w) => test('$n', () => expect(numberToWords(n), w)));

    test('phrase complète', () {
      expect(amountInWords(326500, 'FCFA'),
          'Trois cent vingt-six mille cinq cents (326 500) francs CFA');
    });
  });

  group('Licences GitHub', () {
    final key = 'ETK-ABCD-EFGH-1234-5678';
    final future = DateTime.now().add(const Duration(days: 60)).toIso8601String().substring(0, 10);
    Map<String, dynamic> list(Map<String, dynamic> extra) => {
          'licences': [
            {'hash': hashKey(key), 'entreprise': 'Volaille du Faso', 'expire': future, ...extra}
          ]
        };

    test('clé valide (insensible à la casse et aux tirets)', () {
      final r = checkAgainstList('etk abcd efgh 1234 5678', list({}), 'DEV1');
      expect(r.valid, isTrue);
      expect(r.info!.company, 'Volaille du Faso');
    });
    test('clé inconnue', () {
      expect(checkAgainstList('ETK-XXXX', list({}), 'DEV1').valid, isFalse);
    });
    test('licence suspendue', () {
      expect(checkAgainstList(key, list({'actif': false}), 'DEV1').valid, isFalse);
    });
    test('licence expirée', () {
      expect(checkAgainstList(key, list({'expire': '2020-01-01'}), 'DEV1').valid, isFalse);
    });
    test('appareil non autorisé', () {
      final l = list({
        'appareils': ['AAA']
      });
      expect(checkAgainstList(key, l, 'DEV1').valid, isFalse);
      expect(checkAgainstList(key, l, 'AAA').valid, isTrue);
    });
  });

  group('Documents', () {
    test('calcul des totaux', () {
      final d = CommercialDoc(type: DocType.facture, vatRate: 18, globalDiscount: 1000, lines: [
        DocLine(qty: 2, unitPrice: 5000),
        DocLine(qty: 1, unitPrice: 10000, discount: 10),
      ]);
      expect(d.subtotal, 19000);
      expect(d.afterDiscount, 18000);
      expect(d.vatAmount, 3240);
      expect(d.total, 21240);
    });

    test('devis → proforma → facture → bordereau, numérotation', () async {
      final s = AppStore.I;
      final devis = CommercialDoc(type: DocType.devis, clientName: 'Client A', lines: [
        DocLine(designation: 'Poulet', qty: 10, unitPrice: 3500),
      ]);
      await s.upsertDoc(devis);
      final y = DateTime.now().year;
      expect(devis.number, 'DV-$y-0001');

      final pf = await s.convertDoc(devis, DocType.proforma);
      expect(pf.number, 'PF-$y-0001');
      expect(pf.sourceNumber, devis.number);
      expect(pf.total, 35000);
      expect(devis.status, 'converti');
      expect(devis.convertedTo, [pf.number]);

      final fa = await s.convertDoc(pf, DocType.facture);
      expect(fa.number, 'FA-$y-0001');
      final bl = await s.convertDoc(fa, DocType.bordereau);
      expect(bl.number, 'BL-$y-0001');
      final dc = await s.convertDoc(bl, DocType.decharge);
      expect(dc.dischargeText, contains('reconnais avoir reçu'));

      final devis2 = CommercialDoc(type: DocType.devis, clientName: 'Client B');
      await s.upsertDoc(devis2);
      expect(devis2.number, 'DV-$y-0002');
    });

    test('sauvegarde / restauration', () async {
      final s = AppStore.I;
      await s.upsertProduct(Product(name: 'Poulet entier'));
      final backup = s.exportBackup();
      final n = s.docs.length;
      await s.importBackup(backup);
      expect(s.docs.length, n);
      expect(s.products.any((p) => p.name == 'Poulet entier'), isTrue);
    });
  });

  group('Modèles JSON', () {
    test('import document + étiquette', () async {
      const json = '''
      {"modeles": [
        {"kind": "document", "id": "rouge", "name": "Rouge", "primaryColor": "#C0392B",
         "docTypes": ["facture", "devis"], "tableStyle": "grid"},
        {"kind": "etiquette", "id": "mini", "name": "Mini", "showQr": true}
      ]}''';
      final imp = parseTemplatesJson(json);
      expect(imp.docs.single.primaryColor, 0xFFC0392B);
      expect(imp.docs.single.docTypes, [DocType.facture, DocType.devis]);
      expect(imp.labels.single.showQr, isTrue);
      final n = await AppStore.I.importTemplates(imp);
      expect(n, 2);
      expect(AppStore.I.templateById('rouge').name, 'Rouge');
    });

    test('aller-retour JSON', () {
      for (final t in builtinDocTemplates) {
        final back = DocTemplate.fromJson(t.toJson());
        expect(back.primaryColor, t.primaryColor);
        expect(back.font, t.font);
      }
    });

    test('JSON invalide', () {
      expect(() => parseTemplatesJson('[1,2]'), throwsFormatException);
    });
  });

  group('Impression', () {
    test('TSPL', () {
      final bmp = MonoBitmap(16, 2, Uint8ListX.from([0xFF, 0x00, 0x00, 0xFF]));
      final bytes = buildTspl(bmp, widthMm: 50, heightMm: 30, copies: 3);
      final txt = String.fromCharCodes(bytes);
      expect(txt, startsWith('SIZE 50 mm,30 mm\r\n'));
      expect(txt, contains('BITMAP 0,0,2,2,0,'));
      expect(txt, contains('PRINT 1,3'));
      // noir (1) -> 0 en TSPL
      final i = txt.indexOf('BITMAP 0,0,2,2,0,') + 'BITMAP 0,0,2,2,0,'.length;
      expect(bytes.sublist(i, i + 4), [0x00, 0xFF, 0xFF, 0x00]);
    });

    test('ESC/POS', () {
      final bmp = MonoBitmap(384, 10, Uint8ListX.zeros(48 * 10));
      final bytes = buildEscPos(bmp);
      expect(bytes.sublist(0, 2), [0x1B, 0x40]);
      expect(bytes.sublist(5, 13), [0x1D, 0x76, 0x30, 0x00, 48, 0, 10, 0]);
    });

    test('monochrome depuis RGBA', () {
      // 2 pixels : noir puis blanc
      final rgba = Uint8ListX.from([0, 0, 0, 255, 255, 255, 255, 255]);
      final m = MonoBitmap.fromRgba(rgba, 2, 1);
      expect(m.data[0], 0x80);
    });
  });

  group('PDF', () {
    final data = LabelData(
      company: 'Volaille du Faso',
      phone: '70 12 34 56 / 76 00 00 00',
      product: 'Poulet entier',
      dateLabel: "Date d'abattage",
      productionDate: DateTime(2026, 10, 26),
      expiryDate: DateTime(2026, 10, 31),
      storageTemp: '0 °C à +4 °C',
      durationText: '5 jours',
      weight: '1,4 kg',
      lot: 'L261026',
      extra: 'Halal',
    );

    test('étiquettes (tous formats et styles)', () async {
      final out = Directory('build/apercus')..createSync(recursive: true);
      for (final f in builtinLabelFormats) {
        for (final st in builtinLabelStyles) {
          final bytes = await buildLabelsPdf(
              data: data, style: st, format: f, copies: f.mode == PrintMode.a4 ? 30 : 2);
          expect(bytes.length, greaterThan(500));
          if (st.id == 'standard' || f.id == 'tspl_50x30') {
            File('${out.path}/etiquette_${f.id}_${st.id}.pdf').writeAsBytesSync(bytes);
          }
        }
      }
    });

    test('étiquettes avec logo', () async {
      final raw = File('assets/logo/logo_icon.png').readAsBytesSync();
      final mono = base64Decode(prepareLabelLogo(raw, mono: true));
      final gray = base64Decode(prepareLabelLogo(raw, mono: false));
      LabelData withLogo(Uint8List l) => LabelData(
            company: data.company,
            phone: data.phone,
            product: data.product,
            dateLabel: data.dateLabel,
            productionDate: data.productionDate,
            expiryDate: data.expiryDate,
            storageTemp: data.storageTemp,
            durationText: data.durationText,
            weight: data.weight,
            lot: data.lot,
            extra: data.extra,
            logo: l,
          );
      for (final f in builtinLabelFormats.where((f) => f.mode != PrintMode.a4 || f.id == 'a4_24')) {
        for (final st in [builtinLabelStyles[0], builtinLabelStyles[2], builtinLabelStyles[3]]) {
          final bytes = await buildLabelsPdf(
              data: withLogo(st.id == 'encadre' ? gray : mono), style: st, format: f, copies: f.mode == PrintMode.a4 ? 24 : 1);
          File('build/apercus/logo_${f.id}_${st.id}.pdf').writeAsBytesSync(bytes);
        }
      }
      // logo désactivé par le style
      final noLogo = LabelStyle(id: 'x', name: 'x', showLogo: false);
      expect((await buildLabelsPdf(data: withLogo(mono), style: noLogo, format: builtinLabelFormats[1])).length,
          greaterThan(500));
    });

    test('documents (tous types et modèles)', () async {
      final out = Directory('build/apercus')..createSync(recursive: true);
      final c = Company(
        name: 'Volaille du Faso',
        phone: '70 12 34 56',
        address: 'Ouagadougou, secteur 15',
        email: 'contact@volaille.bf',
        ifu: '00012345X',
        rccm: 'BF-OUA-2026-B-1234',
      );
      for (final t in builtinDocTemplates) {
        for (final type in DocType.values.where(t.appliesTo)) {
          final d = sampleDoc(type);
          if (type == DocType.bordereau) d.showPricesOnDelivery = false;
          final bytes = await buildDocPdf(d, c, t);
          expect(bytes.length, greaterThan(1000));
          File('${out.path}/doc_${type.name}_${t.id}.pdf').writeAsBytesSync(bytes);
        }
      }
    });

    test('en-tête et pied de page en image', () async {
      img.Image banner(int w, int h, img.Color bg, String txt) {
        final im = img.Image(width: w, height: h);
        img.fill(im, color: bg);
        img.drawString(im, txt, font: img.arial48, x: 40, y: h ~/ 2 - 24,
            color: img.ColorRgb8(255, 255, 255));
        return im;
      }

      final c = Company(
        name: 'Volaille du Faso',
        headerB64: base64Encode(img.encodePng(
            banner(2480, 420, img.ColorRgb8(20, 66, 122), 'EN-TETE PERSONNALISE (image)'))),
        footerB64: base64Encode(img.encodePng(
            banner(2480, 220, img.ColorRgb8(232, 115, 28), 'Pied de page personnalise (image)'))),
      );
      final d = sampleDoc(DocType.facture);
      d.lines = List.generate(
          40, (i) => DocLine(designation: 'Article ${i + 1}', qty: 2, unitPrice: 1500));
      final bytes = await buildDocPdf(d, c, builtinDocTemplates[1]);
      File('build/apercus/doc_entete_image.pdf').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(5000));
    });
  });
}

extension Uint8ListX on List<int> {
  static Uint8List from(List<int> l) => Uint8List.fromList(l);
  static Uint8List zeros(int n) => Uint8List(n);
}
