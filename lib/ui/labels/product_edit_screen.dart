import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../common.dart';
import '../theme.dart';

class ProductEditScreen extends StatefulWidget {
  final Product product;
  const ProductEditScreen({super.key, required this.product});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Product p = Product.fromJson(widget.product.toJson());
  late final _name = TextEditingController(text: p.name);
  late final _dateLabel = TextEditingController(text: p.dateLabel);
  late final _days = TextEditingController(text: '${p.shelfLifeDays}');
  late final _temp = TextEditingController(text: p.storageTemp);
  late final _unit = TextEditingController(text: p.unit);
  late final _price = TextEditingController(text: p.price == 0 ? '' : '${p.price}');
  late final _extra = TextEditingController(text: p.extra);

  bool get _isNew => !AppStore.I.products.any((e) => e.id == p.id);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    p
      ..name = _name.text.trim()
      ..dateLabel = _dateLabel.text.trim().isEmpty ? "Date d'abattage" : _dateLabel.text.trim()
      ..shelfLifeDays = int.tryParse(_days.text.trim()) ?? 1
      ..storageTemp = _temp.text.trim()
      ..unit = _unit.text.trim()
      ..price = parseNum(_price.text)
      ..extra = _extra.text.trim();
    await AppStore.I.upsertProduct(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppStore.I.allLabelStyles;
    return Scaffold(
      appBar: eAppBar(
        title: Text(_isNew ? 'Nouveau produit' : 'Modifier le produit'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Supprimer', 'Supprimer « ${p.name} » ?',
                    danger: true, ok: 'Supprimer')) {
                  await AppStore.I.deleteProduct(p.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: FormWidth(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom du produit *', hintText: 'Poulet entier'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateLabel,
              decoration: InputDecoration(
                labelText: 'Libellé de la date de production',
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (v) => setState(() => _dateLabel.text = v),
                  itemBuilder: (_) => [
                    for (final e in const [
                      "Date d'abattage",
                      'Date de fabrication',
                      'Date de production',
                      'Date de conditionnement',
                      'Date de pêche',
                    ])
                      PopupMenuItem(value: e, child: Text(e)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Durée de conservation *', suffixText: 'jours'),
                  validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) <= 0
                      ? 'Nombre de jours'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _temp,
                  decoration: const InputDecoration(
                      labelText: 'Température de conservation', hintText: '0 °C à +4 °C'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final t in ['0 °C à +4 °C', '-18 °C ou moins', '+2 °C à +6 °C', 'Température ambiante'])
                ActionChip(label: Text(t), onPressed: () => setState(() => _temp.text = t)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Unité', hintText: 'kg, pièce…'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Prix unitaire (optionnel)',
                      suffixText: AppStore.I.company.currency),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _extra,
              decoration: const InputDecoration(
                  labelText: 'Mention complémentaire (optionnel)',
                  hintText: 'Ex. : Halal • À consommer bien cuit'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: styles.any((s) => s.id == p.labelStyleId) ? p.labelStyleId : styles.first.id,
              decoration: const InputDecoration(labelText: "Style d'étiquette"),
              items: [
                for (final s in styles) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => p.labelStyleId = v ?? 'standard',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
          ]),
        ),
      ),
    );
  }
}
