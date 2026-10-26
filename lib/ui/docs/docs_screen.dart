import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import 'doc_edit_screen.dart';
import 'doc_view_screen.dart';

IconData docIcon(DocType t) => switch (t) {
      DocType.devis => Icons.request_quote_outlined,
      DocType.proforma => Icons.receipt_outlined,
      DocType.facture => Icons.receipt_long,
      DocType.bordereau => Icons.local_shipping_outlined,
      DocType.decharge => Icons.assignment_turned_in_outlined,
    };

Color statusColor(String s) => switch (s) {
      'payé' => Colors.green,
      'envoyé' => Colors.blue,
      'converti' => Colors.purple,
      'annulé' => Colors.red,
      _ => Colors.grey,
    };

Future<void> newDocFlow(BuildContext context, [DocType? type]) async {
  type ??= await showModalBottomSheet<DocType>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Nouveau document', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        for (final t in DocType.values)
          ListTile(
            leading: Icon(docIcon(t)),
            title: Text(t.label),
            onTap: () => Navigator.pop(c, t),
          ),
      ]),
    ),
  );
  if (type == null || !context.mounted) return;
  final s = AppStore.I;
  final d = CommercialDoc(
    type: type,
    vatRate: type.hasPrices ? s.company.defaultVat : 0,
    templateId: s.defaultTemplateFor(type).id,
  );
  if (type == DocType.devis) d.conditions = 'Validité de l’offre : 30 jours.';
  if (type == DocType.decharge) d.dischargeText = s.defaultDischargeText(d);
  await Navigator.push(context, MaterialPageRoute(builder: (_) => DocEditScreen(doc: d)));
}

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  DocType? _filter;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.docs
            .where((d) => _filter == null || d.type == _filter)
            .where((d) =>
                _q.isEmpty ||
                d.number.toLowerCase().contains(_q) ||
                d.clientName.toLowerCase().contains(_q) ||
                d.subject.toLowerCase().contains(_q))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: const Text('Documents')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => newDocFlow(context, _filter),
            icon: const Icon(Icons.add),
            label: Text(_filter == null ? 'Nouveau' : _filter!.label),
          ),
          body: FormWidth(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'Rechercher (n°, client, objet)'),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                          label: const Text('Tous'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null)),
                    ),
                    for (final t in DocType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                            label: Text(t.label),
                            selected: _filter == t,
                            onSelected: (_) => setState(() => _filter = t)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'Aucun document',
                        text:
                            'Créez un devis, puis transformez-le en facture proforma et en facture définitive en un clic.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final d = list[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(docIcon(d.type), size: 20)),
                              title: Text('${d.number}  •  ${d.clientName.isEmpty ? '—' : d.clientName}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${d.type.label} du ${fmtDate(d.date)}'
                                  '${d.subject.isNotEmpty ? '\n${d.subject}' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (d.type.hasPrices)
                                    Text('${fmtAmount(d.total)} ${s.company.currency}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(d.status,
                                      style: TextStyle(fontSize: 12, color: statusColor(d.status))),
                                ],
                              ),
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => DocViewScreen(docId: d.id))),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
