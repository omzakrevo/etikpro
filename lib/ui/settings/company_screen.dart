import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/image_tools.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/utils.dart';
import '../common.dart';
import '../theme.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

/// Boîte d'édition des signataires (titre + nom, à gauche et à droite).
Future<Signatories?> editSignatories(BuildContext context, DocType t, Signatories sg) {
  final lt = TextEditingController(text: sg.leftTitle);
  final ln = TextEditingController(text: sg.leftName);
  final rt = TextEditingController(text: sg.rightTitle);
  final rn = TextEditingController(text: sg.rightName);
  var showL = sg.showLeft, showR = sg.showRight;
  return showDialog<Signatories>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('Signataires — ${t.label}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: showL,
                onChanged: (v) => set(() => showL = v),
                title: const Text('Signature de gauche', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (showL) ...[
                TextField(controller: lt, decoration: const InputDecoration(labelText: 'Titre (ex. Le client)')),
                const SizedBox(height: 8),
                TextField(controller: ln, decoration: const InputDecoration(labelText: 'Nom (optionnel)')),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: showR,
                onChanged: (v) => set(() => showR = v),
                title: const Text('Signature de droite', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (showR) ...[
                TextField(
                    controller: rt,
                    decoration: const InputDecoration(labelText: 'Titre (ex. Le Responsable, La Direction)')),
                const SizedBox(height: 8),
                TextField(controller: rn, decoration: const InputDecoration(labelText: 'Nom (optionnel)')),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final v in ['La Direction', 'Le Responsable', 'Le Gérant', 'Le Directeur Général', 'Le Comptable', 'Le Chef de service'])
                  ActionChip(label: Text(v), onPressed: () => set(() => rt.text = v)),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(
                c,
                Signatories(
                  leftTitle: lt.text.trim(),
                  leftName: ln.text.trim(),
                  rightTitle: rt.text.trim(),
                  rightName: rn.text.trim(),
                  showLeft: showL,
                  showRight: showR,
                )),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
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

  bool _mono = true;

  Widget _stampCard() {
    final b64 = c.stampB64;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cachet de l’entreprise', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(
              'Photo ou scan du cachet sur papier blanc : le fond blanc est retiré automatiquement. '
              'Il s’appose sur la signature de droite (option dans chaque document).',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (b64 != null)
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                // damier : montre la transparence
                color: Colors.white,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
            ),
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () async {
                try {
                  final raw = await pickImageB64();
                  if (raw == null) return;
                  final v = prepareStamp(base64Decode(raw));
                  setState(() => c.stampB64 = v);
                } catch (e) {
                  if (mounted) snack(context, '$e', error: true);
                }
              },
              icon: const Icon(Icons.approval),
              label: Text(b64 == null ? 'Ajouter le cachet' : 'Remplacer'),
            ),
            if (b64 != null)
              TextButton.icon(
                onPressed: () => setState(() => c.stampB64 = null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Retirer'),
              ),
          ]),
          if (b64 != null) ...[
            Row(children: [
              const Text('Taille'),
              Expanded(
                child: Slider(
                  value: c.stampSizeMm.clamp(25, 55),
                  min: 25,
                  max: 55,
                  divisions: 6,
                  label: '${c.stampSizeMm.round()} mm',
                  onChanged: (v) => setState(() => c.stampSizeMm = v),
                ),
              ),
              Text('${c.stampSizeMm.round()} mm'),
            ]),
            const Text('Cacheter automatiquement :', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in DocType.values)
                FilterChip(
                  label: Text(t.label),
                  selected: c.stampTypes.contains(t.name),
                  onSelected: (v) => setState(() =>
                      v ? c.stampTypes.add(t.name) : c.stampTypes.remove(t.name)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _signatoryTile(DocType t) {
    final sg = c.signatoriesFor(t);
    String side(String title, String name) => [title, if (name.isNotEmpty) name].join(' — ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.draw_outlined),
        title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${sg.showLeft ? side(sg.leftTitle, sg.leftName) : '—'}   |   ${sg.showRight ? side(sg.rightTitle, sg.rightName) : '—'}',
            maxLines: 2),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () async {
          final r = await editSignatories(context, t, sg);
          if (r != null) setState(() => c.signatories[t.name] = r);
        },
      ),
    );
  }

  Future<void> _pickLabelLogo({Uint8List? from}) async {
    try {
      Uint8List? bytes = from;
      if (bytes == null) {
        final b64 = await pickImageB64();
        if (b64 == null) return;
        bytes = base64Decode(b64);
      }
      final processed = prepareLabelLogo(bytes, mono: _mono);
      setState(() => c.labelLogoB64 = processed);
    } catch (e) {
      if (mounted) snack(context, '$e', error: true);
    }
  }

  Widget _labelLogoCard() {
    final b64 = c.labelLogoB64;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Logo des étiquettes', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Imprimé en haut à gauche de chaque étiquette. Image carrée de préférence.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (b64 != null)
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _mono,
            onChanged: (v) => setState(() => _mono = v),
            title: const Text('Convertir en noir et blanc'),
            subtitle: const Text('Recommandé pour les imprimantes thermiques (rendu net)'),
          ),
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () => _pickLabelLogo(),
              icon: const Icon(Icons.image),
              label: Text(b64 == null ? 'Choisir un logo' : 'Remplacer'),
            ),
            if (c.logoB64 != null)
              TextButton.icon(
                onPressed: () => _pickLabelLogo(from: base64Decode(c.logoB64!)),
                icon: const Icon(Icons.content_copy),
                label: const Text('Reprendre le logo des documents'),
              ),
            if (b64 != null)
              TextButton.icon(
                onPressed: () => setState(() => c.labelLogoB64 = null),
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
      appBar: eAppBar(
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
          const SizedBox(height: 10),
          _labelLogoCard(),
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
          _stampCard(),
          const SectionTitle('Signataires par défaut'),
          Text('Titre et nom imprimés sous les signatures. Modifiables aussi dans chaque document.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
          const SizedBox(height: 6),
          for (final t in DocType.values) _signatoryTile(t),
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
