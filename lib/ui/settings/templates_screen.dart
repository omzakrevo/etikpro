import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/templates.dart';
import '../../docs/doc_pdf.dart';
import '../common.dart';
import '../theme.dart';

const _pretty = JsonEncoder.withIndent('  ');

/// Document fictif pour prévisualiser un modèle.
CommercialDoc sampleDoc(DocType t) => CommercialDoc(
      type: t,
      number: '${t.defaultPrefix}-2026-0001',
      clientName: 'SUPERMARCHÉ EXEMPLE SARL',
      clientPhone: '70 00 00 00',
      clientAddress: 'Ouagadougou, Zone du Bois',
      subject: 'Fourniture de poulets',
      vatRate: 18,
      lines: [
        DocLine(designation: 'Poulet entier (sachet)', qty: 40, unit: 'pièce', unitPrice: 3500),
        DocLine(designation: 'Découpe de poulet', qty: 25, unit: 'kg', unitPrice: 2800),
        DocLine(designation: 'Livraison', qty: 1, unitPrice: 5000),
      ],
      conditions: 'Paiement à 30 jours.',
      receiverName: 'M. KABORÉ',
      deliveryPlace: 'Ouaga 2000',
      dischargeText: 'Je soussigné(e) … reconnais avoir reçu les articles ci-dessous.',
    );

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  Future<void> _import(BuildContext context) async {
    try {
      final txt = await pickJsonText();
      if (txt == null) return;
      final n = await AppStore.I.importTemplates(parseTemplatesJson(txt));
      if (context.mounted) snack(context, '$n modèle(s) importé(s)');
    } catch (e) {
      if (context.mounted) snack(context, 'Import impossible : $e', error: true);
    }
  }

  Future<void> _paste(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Coller un modèle JSON'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(hintText: '{ "kind": "document", "name": … }'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Importer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await AppStore.I.importTemplates(parseTemplatesJson(ctrl.text));
      if (context.mounted) snack(context, '$n modèle(s) importé(s)');
    } catch (e) {
      if (context.mounted) snack(context, 'JSON invalide : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Scaffold(
          appBar: eAppBar(
            title: const Text('Modèles'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Importer',
                onSelected: (v) async {
                  if (v == 'file') await _import(context);
                  if (v == 'paste' && context.mounted) await _paste(context);
                  if (v == 'all') {
                    await saveTextFile(
                        'etikpro_modeles.json',
                        _pretty.convert({
                          'modeles': [
                            ...s.allDocTemplates.map((e) => e.toJson()),
                            ...s.allLabelStyles.map((e) => e.toJson()),
                          ]
                        }));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'file', child: Text('Importer un fichier JSON')),
                  PopupMenuItem(value: 'paste', child: Text('Coller du JSON')),
                  PopupMenuItem(value: 'all', child: Text('Exporter tous les modèles')),
                ],
              ),
            ],
            bottom: const TabBar(tabs: [Tab(text: 'Documents'), Tab(text: 'Étiquettes')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _import(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Importer JSON'),
          ),
          body: TabBarView(children: [
            ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
              for (final t in s.allDocTemplates) _DocTemplateTile(t),
            ]),
            ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
              for (final l in s.allLabelStyles)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text(l.name),
                    subtitle: Text([
                      if (l.companyBand) 'bande noire',
                      if (l.showQr) 'QR code',
                      if (l.showBorder) 'cadre',
                      if (l.builtin) 'intégré' else 'importé',
                    ].join(' • ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Exporter JSON',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => saveTextFile('etiquette_${l.id}.json', _pretty.convert(l.toJson())),
                      ),
                      if (!l.builtin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => s.deleteLabelStyle(l.id),
                        ),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _DocTemplateTile extends StatelessWidget {
  final DocTemplate t;
  const _DocTemplateTile(this.t);

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final defaults = DocType.values
        .where((d) => s.defaultTemplateFor(d).id == t.id)
        .map((d) => d.label)
        .toList();
    return Card(
      child: ListTile(
        leading: Container(
          width: 36,
          height: 44,
          decoration: BoxDecoration(
            color: Color(t.accentColor),
            border: Border(top: BorderSide(color: Color(t.primaryColor), width: 8)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(t.name),
        subtitle: Text([
          t.docTypes.isEmpty ? 'Tous documents' : t.docTypes.map((e) => e.label).join(', '),
          if (defaults.isNotEmpty) 'Par défaut : ${defaults.join(', ')}',
        ].join('\n')),
        isThreeLine: defaults.isNotEmpty,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: eAppBar(title: Text('Aperçu : ${t.name}')),
              body: PdfPreview(
                build: (_) => buildDocPdf(
                    sampleDoc(t.docTypes.isEmpty ? DocType.facture : t.docTypes.first), s.company, t),
                initialPageFormat: PdfPageFormat.a4,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
              ),
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'export') {
              await saveTextFile('modele_${t.id}.json', _pretty.convert(t.toJson()));
            } else if (v == 'delete') {
              await s.deleteDocTemplate(t.id);
            } else if (v.startsWith('def:')) {
              s.company.defaultTemplates[v.substring(4)] = t.id;
              await s.saveCompany();
            }
          },
          itemBuilder: (_) => [
            for (final d in DocType.values.where(t.appliesTo))
              PopupMenuItem(value: 'def:${d.name}', child: Text('Par défaut pour : ${d.label}')),
            const PopupMenuItem(value: 'export', child: Text('Exporter en JSON')),
            if (!t.builtin) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}
