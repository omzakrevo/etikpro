import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import 'doc_view_screen.dart';

class DocEditScreen extends StatefulWidget {
  final CommercialDoc doc;
  const DocEditScreen({super.key, required this.doc});
  @override
  State<DocEditScreen> createState() => _DocEditScreenState();
}

class _DocEditScreenState extends State<DocEditScreen> {
  final s = AppStore.I;
  late final CommercialDoc d = CommercialDoc.fromJson(widget.doc.toJson());
  late final bool _isNew = !s.docs.any((e) => e.id == d.id);

  late final _clientName = TextEditingController(text: d.clientName);
  late final _clientPhone = TextEditingController(text: d.clientPhone);
  late final _clientAddress = TextEditingController(text: d.clientAddress);
  late final _clientIfu = TextEditingController(text: d.clientIfu);
  late final _subject = TextEditingController(text: d.subject);
  late final _vat = TextEditingController(text: d.vatRate == 0 ? '' : fmtQty(d.vatRate));
  late final _discount =
      TextEditingController(text: d.globalDiscount == 0 ? '' : fmtQty(d.globalDiscount));
  late final _notes = TextEditingController(text: d.notes);
  late final _conditions = TextEditingController(text: d.conditions);
  late final _place = TextEditingController(text: d.deliveryPlace);
  late final _receiver = TextEditingController(text: d.receiverName);
  late final _discharge = TextEditingController(text: d.dischargeText);
  bool _saveClient = false;

  bool get _prices =>
      d.type.hasPrices || (d.type == DocType.bordereau && d.showPricesOnDelivery);

  void _sync() {
    d
      ..clientName = _clientName.text.trim()
      ..clientPhone = _clientPhone.text.trim()
      ..clientAddress = _clientAddress.text.trim()
      ..clientIfu = _clientIfu.text.trim()
      ..subject = _subject.text.trim()
      ..vatRate = parseNum(_vat.text)
      ..globalDiscount = parseNum(_discount.text)
      ..notes = _notes.text.trim()
      ..conditions = _conditions.text.trim()
      ..deliveryPlace = _place.text.trim()
      ..receiverName = _receiver.text.trim()
      ..dischargeText = _discharge.text.trim();
  }

  Future<void> _save() async {
    _sync();
    if (d.clientName.isEmpty) {
      snack(context, 'Indiquez le client.', error: true);
      return;
    }
    if (d.lines.isEmpty && d.type != DocType.decharge) {
      snack(context, 'Ajoutez au moins une ligne.', error: true);
      return;
    }
    if (_saveClient) {
      final c = Client(
          name: d.clientName, phone: d.clientPhone, address: d.clientAddress, ifu: d.clientIfu);
      await s.upsertClient(c);
      d.clientId = c.id;
    }
    await s.upsertDoc(d);
    if (!mounted) return;
    if (_isNew) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => DocViewScreen(docId: d.id)));
    } else {
      Navigator.pop(context);
    }
  }

  void _chooseClient(Client c) {
    setState(() {
      d.clientId = c.id;
      _clientName.text = c.name;
      _clientPhone.text = c.phone;
      _clientAddress.text = c.address;
      _clientIfu.text = c.ifu;
      _saveClient = false;
    });
  }

  Future<void> _editLine([int? index]) async {
    final l = index == null ? DocLine() : d.lines[index].copy();
    final res = await showDialog<DocLine>(
      context: context,
      builder: (_) => _LineDialog(line: l, withPrices: _prices),
    );
    if (res == null) return;
    setState(() => index == null ? d.lines.add(res) : d.lines[index] = res);
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final cur = s.company.currency;
    final templates = s.allDocTemplates.where((t) => t.appliesTo(d.type)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouveau : ${d.type.label}' : '${d.type.label} ${d.number}'),
        actions: [
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
        ],
      ),
      body: FormWidth(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final x = await showDatePicker(
                      context: context,
                      initialDate: d.date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (x != null) setState(() => d.date = x);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(fmtDate(d.date)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Numéro'),
                child: Text(d.number.isEmpty ? s.nextNumber(d.type, date: d.date) : d.number),
              ),
            ),
          ]),
          if (d.sourceNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Établi à partir de ${d.sourceNumber}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),

          // ---------- Client ----------
          SectionTitle(d.type == DocType.decharge ? 'Bénéficiaire' : 'Client'),
          if (s.clients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                initialValue: s.clients.any((c) => c.id == d.clientId) ? d.clientId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Choisir un client enregistré'),
                items: [
                  for (final c in s.clients)
                    DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => _chooseClient(s.clients.firstWhere((c) => c.id == id)),
              ),
            ),
          TextField(
              controller: _clientName,
              decoration: const InputDecoration(labelText: 'Nom / raison sociale *'),
              onChanged: (_) => d.clientId = null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _clientPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _clientIfu, decoration: const InputDecoration(labelText: 'IFU'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _clientAddress, decoration: const InputDecoration(labelText: 'Adresse')),
          if (d.clientId == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveClient,
              onChanged: (v) => setState(() => _saveClient = v ?? false),
              title: const Text('Enregistrer ce client'),
            ),
          const SizedBox(height: 10),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Objet')),

          if (d.type == DocType.bordereau || d.type == DocType.decharge) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (d.type == DocType.bordereau)
                Expanded(
                    child: TextField(
                        controller: _place,
                        decoration: const InputDecoration(labelText: 'Lieu de livraison'))),
              if (d.type == DocType.bordereau) const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: _receiver,
                      decoration: const InputDecoration(labelText: 'Nom du réceptionnaire'))),
            ]),
          ],
          if (d.type == DocType.bordereau)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: d.showPricesOnDelivery,
              onChanged: (v) => setState(() => d.showPricesOnDelivery = v),
              title: const Text('Afficher les prix sur le bordereau'),
            ),
          if (d.type == DocType.decharge) ...[
            const SectionTitle('Texte de la décharge'),
            TextField(
              controller: _discharge,
              maxLines: 6,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: 'Texte par défaut',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => setState(() {
                    _sync();
                    _discharge.text = s.defaultDischargeText(d);
                  }),
                ),
              ),
            ),
          ],

          // ---------- Lignes ----------
          SectionTitle(d.type == DocType.decharge ? 'Articles remis (optionnel)' : 'Articles / prestations'),
          if (d.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucune ligne.', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) => setState(() => d.lines.insert(b, d.lines.removeAt(a))),
            children: [
              for (final (i, l) in d.lines.indexed)
                Card(
                  key: ObjectKey(l),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                        index: i, child: const Icon(Icons.drag_indicator)),
                    title: Text(l.designation.isEmpty ? '(sans désignation)' : l.designation),
                    subtitle: Text(_prices
                        ? '${fmtQty(l.qty)} ${l.unit} × ${fmtAmount(l.unitPrice)}'
                            '${l.discount > 0 ? ' – ${fmtQty(l.discount)} %' : ''}'
                        : '${fmtQty(l.qty)} ${l.unit}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_prices)
                        Text(fmtAmount(l.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => d.lines.removeAt(i))),
                    ]),
                    onTap: () => _editLine(i),
                  ),
                ),
            ],
          ),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(
                onPressed: () => _editLine(), icon: const Icon(Icons.add), label: const Text('Ligne')),
            if (s.products.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDialog<Product>(
                    context: context,
                    builder: (c) => SimpleDialog(
                      title: const Text('Depuis un produit'),
                      children: [
                        for (final p in s.products)
                          SimpleDialogOption(
                              onPressed: () => Navigator.pop(c, p), child: Text(p.name)),
                      ],
                    ),
                  );
                  if (p == null || !context.mounted) return;
                  final res = await showDialog<DocLine>(
                    context: context,
                    builder: (_) => _LineDialog(
                        line: DocLine(designation: p.name, unit: p.unit, unitPrice: p.price),
                        withPrices: _prices),
                  );
                  if (res != null) setState(() => d.lines.add(res));
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Depuis un produit'),
              ),
          ]),

          // ---------- Totaux ----------
          if (_prices) ...[
            const SectionTitle('Montants'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Remise globale', suffixText: cur),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _vat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'TVA', suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _TotRow('Sous-total', '${fmtAmount(d.subtotal)} $cur'),
                  if (d.globalDiscount > 0) _TotRow('Remise', '- ${fmtAmount(d.globalDiscount)} $cur'),
                  if (d.vatRate > 0) _TotRow('TVA ${fmtQty(d.vatRate)} %', '${fmtAmount(d.vatAmount)} $cur'),
                  const Divider(),
                  _TotRow(d.vatRate > 0 ? 'TOTAL TTC' : 'TOTAL', '${fmtAmount(d.total)} $cur', big: true),
                  const SizedBox(height: 6),
                  Text(amountInWords(d.total, cur),
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                ]),
              ),
            ),
          ],

          const SectionTitle('Mentions'),
          TextField(
              controller: _conditions,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Conditions (paiement, validité, délai…)')),
          const SizedBox(height: 10),
          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: templates.any((t) => t.id == d.templateId) ? d.templateId : templates.first.id,
            decoration: const InputDecoration(labelText: 'Modèle'),
            items: [for (final t in templates) DropdownMenuItem(value: t.id, child: Text(t.name))],
            onChanged: (v) => d.templateId = v!,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: d.status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: [
              for (final st in ['brouillon', 'envoyé', 'payé', 'converti', 'annulé'])
                DropdownMenuItem(value: st, child: Text(st)),
            ],
            onChanged: (v) => d.status = v!,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _TotRow extends StatelessWidget {
  final String k, v;
  final bool big;
  const _TotRow(this.k, this.v, {this.big = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(k, style: TextStyle(fontWeight: big ? FontWeight.w800 : null)),
          const Spacer(),
          Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: big ? 18 : 14)),
        ]),
      );
}

class _LineDialog extends StatefulWidget {
  final DocLine line;
  final bool withPrices;
  const _LineDialog({required this.line, required this.withPrices});
  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  late final _des = TextEditingController(text: widget.line.designation);
  late final _qty = TextEditingController(text: fmtQty(widget.line.qty));
  late final _unit = TextEditingController(text: widget.line.unit);
  late final _pu =
      TextEditingController(text: widget.line.unitPrice == 0 ? '' : fmtQty(widget.line.unitPrice));
  late final _disc =
      TextEditingController(text: widget.line.discount == 0 ? '' : fmtQty(widget.line.discount));

  @override
  Widget build(BuildContext context) {
    final total = parseNum(_qty.text) * parseNum(_pu.text) * (1 - parseNum(_disc.text) / 100);
    return AlertDialog(
      title: const Text('Ligne'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _des,
                autofocus: widget.line.designation.isEmpty,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(labelText: 'Désignation')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantité'),
                      onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: _unit, decoration: const InputDecoration(labelText: 'Unité'))),
            ]),
            if (widget.withPrices) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: TextField(
                        controller: _pu,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Prix unitaire'),
                        onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: TextField(
                        controller: _disc,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Remise', suffixText: '%'),
                        onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Montant : ${fmtAmount(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            DocLine(
              designation: _des.text.trim(),
              qty: parseNum(_qty.text) == 0 ? 1 : parseNum(_qty.text),
              unit: _unit.text.trim(),
              unitPrice: parseNum(_pu.text),
              discount: parseNum(_disc.text).clamp(0, 100).toDouble(),
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
