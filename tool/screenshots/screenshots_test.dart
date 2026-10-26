// ignore_for_file: invalid_use_of_visible_for_testing_member
// Génère des captures d'écran des principaux écrans (build/captures/*.png).
// Lancer : flutter test tool/screenshots/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:etikpro/core/models.dart';
import 'package:etikpro/core/store.dart';
import 'package:etikpro/ui/docs/doc_edit_screen.dart';
import 'package:etikpro/ui/home_shell.dart';
import 'package:etikpro/ui/labels/free_label_screen.dart';
import 'package:etikpro/ui/licence_screen.dart';
import 'package:etikpro/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _fontDir = '/home/claude/flutter-sdk/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  if (!Directory(_fontDir).existsSync()) return;
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      final b = File('$_fontDir/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('FlutterTest', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: home,
    );

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/captures/$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await _loadFonts();
    final dir = await Directory.systemTemp.createTemp('etikshot');
    await AppStore.I.initForTest(dir.path);
    final s = AppStore.I;
    s.company
      ..name = 'Volaille du Faso'
      ..phone = '70 12 34 56';
    await s.saveCompany();
    for (final p in [
      Product(name: 'Poulet entier', shelfLifeDays: 5, storageTemp: '0 °C à +4 °C'),
      Product(name: 'Poulet entier congelé', shelfLifeDays: 180, storageTemp: '-18 °C ou moins'),
      Product(name: 'Découpe de poulet', shelfLifeDays: 3, storageTemp: '0 °C à +4 °C'),
      Product(name: 'Pintade', shelfLifeDays: 5, storageTemp: '0 °C à +4 °C'),
    ]) {
      await s.upsertProduct(p);
    }
    await s.addPrintLog(LabelPrintLog(
        productName: 'Poulet entier', productionDate: DateTime.now(), expiryDate: DateTime.now(), copies: 48));
    final now = DateTime.now();
    for (final (t, client, amount, st) in [
      (DocType.facture, 'SUPERMARCHÉ MARINA', 253700.0, 'payé'),
      (DocType.facture, 'Hôtel Silmandé', 480000.0, 'envoyé'),
      (DocType.devis, 'Restaurant Le Verdoyant', 120000.0, 'brouillon'),
      (DocType.proforma, 'Hôtel Silmandé', 480000.0, 'converti'),
      (DocType.bordereau, 'SUPERMARCHÉ MARINA', 0.0, 'envoyé'),
    ]) {
      await s.upsertDoc(CommercialDoc(
        type: t,
        clientName: client,
        date: now,
        subject: 'Fourniture de poulets',
        status: st,
        lines: [DocLine(designation: 'Poulet', qty: 1, unitPrice: amount)],
      ));
    }
  });

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2280);
    t.view.devicePixelRatio = 2.625;
  }

  testWidgets('accueil étiquettes', (t) async {
    await phone(t);
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await _shot(t, '1_etiquettes');
  });

  testWidgets('documents', (t) async {
    await phone(t);
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Documents').last);
    await _shot(t, '2_documents');
  });

  testWidgets('réglages', (t) async {
    await phone(t);
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Réglages').last);
    await _shot(t, '3_reglages');
  });

  testWidgets('édition facture : signataires', (t) async {
    await phone(t);
    final d = CommercialDoc(
      type: DocType.facture,
      clientName: 'Hôtel Silmandé',
      clientExtra: 'RCCM : BF-OUA-2020-B-555\nContact : Mme TRAORÉ',
      signatures: Signatories(rightTitle: 'Le Responsable', rightName: 'M. OUÉDRAOGO Paul'),
      lines: [DocLine(designation: 'Poulet entier', qty: 40, unit: 'pièce', unitPrice: 3500)],
    );
    await t.pumpWidget(_app(DocEditScreen(doc: d)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Sticker (en haut du document)'), 400,
        scrollable: find.byType(Scrollable).first);
    await _shot(t, '4_facture_signataires');
  });

  testWidgets('étiquette libre', (t) async {
    await phone(t);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.nfet.printing'), (call) async => null);
    await t.pumpWidget(_app(const FreeLabelScreen()));
    await t.pump(const Duration(milliseconds: 500));
    await t.drag(find.byType(Scrollable).last, const Offset(0, -420));
    await t.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/captures/5_etiquette_libre.png'));
  });

  testWidgets('clients', (t) async {
    await phone(t);
    final s = AppStore.I;
    for (final c in [
      Client(name: 'SUPERMARCHÉ MARINA', phone: '25 30 00 00', address: 'Ouaga 2000'),
      Client(name: 'Hôtel Silmandé', phone: '25 35 60 00', address: 'Ouagadougou'),
      Client(name: 'Restaurant Le Verdoyant', phone: '70 00 11 22', address: 'Koulouba'),
    ]) {
      await s.upsertClient(c);
    }
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Clients').last);
    await _shot(t, '7_clients');
  });

  testWidgets('licence', (t) async {
    await phone(t);
    await t.pumpWidget(_app(LicenceScreen(onActivated: () {}, onRetry: () {})));
    await t.runAsync(() async {
      final el = find.byType(Image).evaluate().first;
      await precacheImage((el.widget as Image).image, el);
    });
    await _shot(t, '6_licence');
  });
}
