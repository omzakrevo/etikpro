import 'dart:io';

import 'package:etikpro/core/models.dart';
import 'package:etikpro/core/store.dart';
import 'package:etikpro/core/templates.dart';
import 'package:etikpro/ui/docs/doc_edit_screen.dart';
import 'package:etikpro/ui/home_shell.dart';
import 'package:etikpro/ui/labels/product_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    final dir = await Directory.systemTemp.createTemp('etikui');
    await AppStore.I.initForTest(dir.path);
  });

  testWidgets('navigation entre les onglets', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await t.pumpAndSettle();
    expect(find.text('Aucun produit'), findsOneWidget);

    // Ajout d'un produit modèle
    await t.runAsync(() async {
      await t.tap(find.text('Poulet entier').first);
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();
    expect(find.text('Imprimer'), findsOneWidget);

    for (final tab in ['Documents', 'Clients', 'Réglages']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
    }
    expect(find.text('Mon entreprise'), findsOneWidget);
    t.view.resetPhysicalSize();
  });

  testWidgets('écrans sur téléphone (pas de débordement)', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(_app(HomeShell(onLogout: () {})));
    await t.pumpAndSettle();
    for (final tab in ['Documents', 'Clients', 'Réglages', 'Étiquettes']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
    }
    t.view.resetPhysicalSize();
  });

  testWidgets('édition produit', (t) async {
    await t.pumpWidget(_app(ProductEditScreen(product: Product())));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Pintade');
    await t.runAsync(() async {
      await t.tap(find.text('Enregistrer'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();
    expect(AppStore.I.products.any((p) => p.name == 'Pintade'), isTrue);
  });

  testWidgets('édition document (écran mobile)', (t) async {
    t.view.physicalSize = const Size(400, 850);
    t.view.devicePixelRatio = 1;
    final d = CommercialDoc(type: DocType.devis, lines: [DocLine(designation: 'Poulet', qty: 3, unitPrice: 3500)]);
    await t.pumpWidget(_app(DocEditScreen(doc: d)));
    await t.pumpAndSettle();
    expect(find.text('10 500 FCFA'), findsWidgets);
    t.view.resetPhysicalSize();
  });

  test('modèles JSON d’exemple', () async {
    final imp = parseTemplatesJson(File('modeles/exemple_modeles.json').readAsStringSync());
    expect(imp.docs.length, 2);
    expect(imp.labels.length, 1);
  });
}
