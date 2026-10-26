import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../docs/doc_pdf.dart';
import '../common.dart';
import 'doc_edit_screen.dart';

class DocViewScreen extends StatelessWidget {
  final String docId;
  const DocViewScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final m = s.docs.where((e) => e.id == docId);
        if (m.isEmpty) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Document supprimé')));
        }
        final d = m.first;
        final t = s.templateById(d.templateId);
        final fileName = '${d.number}.pdf';

        Future<void> convert(DocType target) async {
          if (!await confirm(context, 'Transformer en ${target.label}',
              'Un nouveau document « ${target.label} » sera créé à partir de ${d.number}.',
              ok: 'Transformer')) {
            return;
          }
          final n = await s.convertDoc(d, target);
          if (context.mounted) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => DocViewScreen(docId: n.id)));
            snack(context, '${target.label} ${n.number} créé(e)');
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${d.type.label} ${d.number}'),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => DocEditScreen(doc: d))),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v.startsWith('conv:')) {
                    await convert(DocType.parse(v.substring(5)));
                  } else if (v == 'dup') {
                    final copy = CommercialDoc.fromJson(d.toJson())
                      ..id = newId()
                      ..number = ''
                      ..date = DateTime.now()
                      ..sourceId = null
                      ..sourceNumber = null
                      ..convertedTo = []
                      ..status = 'brouillon';
                    await s.upsertDoc(copy);
                    if (context.mounted) {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => DocViewScreen(docId: copy.id)));
                    }
                  } else if (v == 'paid') {
                    d.status = 'payé';
                    await s.upsertDoc(d);
                  } else if (v == 'del') {
                    if (await confirm(context, 'Supprimer', 'Supprimer ${d.number} ?',
                        danger: true, ok: 'Supprimer')) {
                      await s.deleteDoc(d.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => [
                  for (final target in d.type.convertTargets)
                    PopupMenuItem(
                      value: 'conv:${target.name}',
                      child: ListTile(
                        leading: const Icon(Icons.transform),
                        title: Text('Transformer en ${target.label.toLowerCase()}'),
                      ),
                    ),
                  const PopupMenuItem(
                      value: 'dup', child: ListTile(leading: Icon(Icons.copy), title: Text('Dupliquer'))),
                  if (d.type == DocType.facture && d.status != 'payé')
                    const PopupMenuItem(
                        value: 'paid',
                        child: ListTile(leading: Icon(Icons.paid), title: Text('Marquer payée'))),
                  const PopupMenuItem(
                      value: 'del',
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Supprimer'))),
                ],
              ),
            ],
          ),
          body: Column(children: [
            if (d.type.convertTargets.isNotEmpty || d.sourceNumber != null || d.convertedTo.isNotEmpty)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    if (d.sourceNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Chip(
                            avatar: const Icon(Icons.call_split, size: 16),
                            label: Text('Issu de ${d.sourceNumber}')),
                      ),
                    for (final n in d.convertedTo)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(avatar: const Icon(Icons.arrow_forward, size: 16), label: Text(n)),
                      ),
                    for (final target in d.type.convertTargets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton.tonalIcon(
                          onPressed: () => convert(target),
                          icon: const Icon(Icons.transform, size: 18),
                          label: Text('→ ${target.label}'),
                        ),
                      ),
                  ]),
                ),
              ),
            Expanded(
              child: PdfPreview(
                key: ValueKey(d.toJson().toString() + t.id),
                build: (_) => buildDocPdf(d, s.company, t),
                initialPageFormat: PdfPageFormat.a4,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                pdfFileName: fileName,
              ),
            ),
          ]),
        );
      },
    );
  }
}
