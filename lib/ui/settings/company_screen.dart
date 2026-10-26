import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final s = AppStore.I;
  late final Company c = Company.fromJson(s.company.toJson());
  late final _name = TextEditingController(text: c.name);
  late final _phone = TextEditingController(text: c.phone);
  late final _phone2 = TextEditingController(text: c.phone2);
  late final _email = TextEditingController(text: c.email);
  late final _address = TextEditingController(text: c.address);
  late final _ifu = TextEditingController(text: c.ifu);
  late final _rccm = TextEditingController(text: c.rccm);
  late final _currency = TextEditingController(text: c.currency);
  late final _vat = TextEditingController(text: c.defaultVat == 0 ? '' : fmtQty(c.defaultVat));
  late final _prefixes = {
    for (final t in DocType.values) t.name: TextEditingController(text: c.prefixes[t.name])
  };

  Future<void> _save() async {
    // Conserve les compteurs à jour (des documents ont pu être créés entre-temps).
    c.counters = s.company.counters;
    c
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..phone2 = _phone2.text.trim()
      ..email = _email.text.trim()
      ..address = _address.text.trim()
      ..ifu = _ifu.text.trim()
      ..rccm = _rccm.text.trim()
      ..currency = _currency.text.trim().isEmpty ? 'FCFA' : _currency.text.trim()
      ..defaultVat = parseNum(_vat.text);
    for (final e in _prefixes.entries) {
      final v = e.value.text.trim().toUpperCase();
      if (v.isNotEmpty) c.prefixes[e.key] = v;
    }
    s.company = c;
    await s.saveCompany();
    if (mounted) {
      snack(context, 'Enregistré');
      Navigator.pop(context);
    }
  }

  Widget _imageSlot(String title, String help, String? b64, ValueChanged<String?> set,
      {double height = 90}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(help, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (b64 != null)
            Container(
              height: height,
              width: double.infinity,
              color: Colors.white,
              child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
            ),
          Row(children: [
            TextButton.icon(
              onPressed: () async {
                try {
                  final v = await pickImageB64();
                  if (v != null) setState(() => set(v));
                } catch (e) {
                  if (mounted) snack(context, '$e', error: true);
                }
              },
              icon: const Icon(Icons.image),
              label: Text(b64 == null ? 'Choisir une image' : 'Remplacer'),
            ),
            if (b64 != null)
              TextButton.icon(
                onPressed: () => setState(() => set(null)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Retirer'),
              ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon entreprise'),
        actions: [TextButton(onPressed: _save, child: const Text('Enregistrer'))],
      ),
      body: FormWidth(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle('Informations (imprimées sur les étiquettes)'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Nom de l'entreprise *")),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone *'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _phone2,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone 2'))),
          ]),
          const SectionTitle('Documents commerciaux'),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
          const SizedBox(height: 10),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _ifu, decoration: const InputDecoration(labelText: 'N° IFU'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _rccm, decoration: const InputDecoration(labelText: 'RCCM'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(controller: _currency, decoration: const InputDecoration(labelText: 'Devise'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _vat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'TVA par défaut', suffixText: '%'))),
          ]),
          const SectionTitle('Images des documents'),
          _imageSlot('En-tête', "Image pleine largeur en haut de chaque page (remplace le bloc texte). Idéal : 2480 × 500 px.",
              c.headerB64, (v) => c.headerB64 = v),
          _imageSlot('Pied de page', 'Image pleine largeur en bas de chaque page. Idéal : 2480 × 300 px.',
              c.footerB64, (v) => c.footerB64 = v, height: 60),
          _imageSlot('Logo', "Utilisé quand il n'y a pas d'image d'en-tête.", c.logoB64,
              (v) => c.logoB64 = v),
          const SectionTitle('Numérotation des documents'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in DocType.values)
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _prefixes[t.name],
                  decoration: InputDecoration(labelText: t.label),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Exemple : ${s.nextNumber(DocType.facture)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ]),
      ),
    );
  }
}
