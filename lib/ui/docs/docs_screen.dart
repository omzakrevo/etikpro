import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import 'doc_edit_screen.dart';
import 'doc_view_screen.dart';
import '../theme.dart';

IconData docIcon(DocType t) => switch (t) {
  DocType.devis => Icons.request_quote_outlined,
  DocType.proforma => Icons.receipt_outlined,
  DocType.facture => Icons.receipt_long,
  DocType.bordereau => Icons.local_shipping_outlined,
  DocType.decharge => Icons.assignment_turned_in_outlined,
};

Color docColor(DocType t) => switch (t) {
  DocType.devis => EColors.purple,
  DocType.proforma => EColors.teal,
  DocType.facture => EColors.blue,
  DocType.bordereau => EColors.orange,
  DocType.decharge => EColors.green,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Nouveau document', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          for (final t in DocType.values)
            ListTile(
              leading: IconBadge(docIcon(t), color: docColor(t), size: 40),
              title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(c, t),
            ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return;
  final s = AppStore.I;
  final d = CommercialDoc(
    type: type,
    vatRate: type.hasPrices ? s.company.defaultVat : 0,
    templateId: s.defaultTemplateFor(type).id,
    signatures: s.company.signatoriesFor(type),
    showStamp: s.company.stampB64 != null && s.company.stampTypes.contains(type.name),
  );
  if (type == DocType.devis) d.conditions = 'Validité de l’offre : 30 jours.';
  if (type == DocType.decharge) d.dischargeText = s.defaultDischargeText(d);
  await Navigator.push(context, MaterialPageRoute(builder: (_) => DocEditScreen(doc: d)));
}

class _DocsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final now = DateTime.now();
    final month = s.docs.where(
      (d) => d.type == DocType.facture && d.date.year == now.year && d.date.month == now.month,
    );
    final ca = month.fold(0.0, (t, d) => t + d.total);
    final unpaid = s.docs
        .where((d) => d.type == DocType.facture && d.status != 'payé' && d.status != 'annulé')
        .fold(0.0, (t, d) => t + d.total);
    final quotes = s.docs.where((d) => d.type == DocType.devis && d.status != 'converti').length;
    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 24),
              const SizedBox(width: 10),
              Text(
                'Ce mois-ci',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: .95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatTile(
                value: '${fmtAmount(ca)} ${s.company.currency}',
                label: 'facturé (${month.length})',
                icon: Icons.receipt_long,
              ),
              StatTile(
                value: '${fmtAmount(unpaid)} ${s.company.currency}',
                label: 'à encaisser',
                icon: Icons.hourglass_bottom,
              ),
              StatTile(value: '$quotes', label: 'devis en cours', icon: Icons.request_quote),
            ],
          ),
        ],
      ),
    );
  }
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
        final list =
            s.docs
                .where((d) => _filter == null || d.type == _filter)
                .where(
                  (d) =>
                      _q.isEmpty ||
                      d.number.toLowerCase().contains(_q) ||
                      d.clientName.toLowerCase().contains(_q) ||
                      d.subject.toLowerCase().contains(_q),
                )
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: eAppBar(title: const Text('Documents')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => newDocFlow(context, _filter),
            icon: const Icon(Icons.add),
            label: Text(_filter == null ? 'Nouveau' : _filter!.label),
          ),
          body: FormWidth(
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), child: _DocsBanner()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher (n°, client, objet)',
                    ),
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Tous'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final t in DocType.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: Icon(
                              docIcon(t),
                              size: 16,
                              color: _filter == t ? Colors.white : docColor(t),
                            ),
                            label: Text(t.label),
                            selected: _filter == t,
                            selectedColor: docColor(t),
                            labelStyle: TextStyle(
                              color: _filter == t ? Colors.white : null,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) => setState(() => _filter = t),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.description_outlined,
                          title: 'Aucun document',
                          text: 'Créez un devis, puis transformez-le en facture proforma et en facture définitive en un clic.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final d = list[i];
                            final col = docColor(d.type);
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DocViewScreen(docId: d.id)),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(width: 6, color: col),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              IconBadge(docIcon(d.type), color: col, size: 42),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      d.clientName.isEmpty ? '—' : d.clientName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${d.number} • ${fmtDate(d.date)}',
                                                      style: TextStyle(
                                                        color: col,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 12.5,
                                                      ),
                                                    ),
                                                    if (d.subject.isNotEmpty)
                                                      Text(
                                                        d.subject,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: Colors.blueGrey.shade600,
                                                          fontSize: 12.5,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  if (d.type.hasPrices)
                                                    Text(
                                                      '${fmtAmount(d.total)} ${s.company.currency}',
                                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor(d.status).withValues(alpha: .12),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      d.status,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: statusColor(d.status),
                                                      ),
                                                    ),
                                                  ),
                                                  if (d.stickerB64 != null || d.showStamp)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (d.stickerB64 != null)
                                                            const Icon(
                                                              Icons.verified,
                                                              size: 15,
                                                              color: EColors.green,
                                                            ),
                                                          if (d.showStamp)
                                                            const Icon(
                                                              Icons.approval,
                                                              size: 15,
                                                              color: EColors.blue,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
