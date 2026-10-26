import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../label/bt.dart';
import '../../label/label_pdf.dart';
import '../../label/label_printer.dart';
import '../common.dart';
import '../theme.dart';
import 'print_widgets.dart';

/// Étiquette au contenu libre : l'entreprise écrit ce qu'elle veut
/// (adresse d'expédition, « FRAGILE », n° de commande, prix, promo…).
class FreeLabelScreen extends StatefulWidget {
  const FreeLabelScreen({super.key});
  @override
  State<FreeLabelScreen> createState() => _FreeLabelScreenState();
}

class _SavedFree {
  final String name;
  final Map<String, dynamic> data;
  _SavedFree(this.name, this.data);
  Map<String, dynamic> toJson() => {'name': name, 'data': data};
}

class _FreeLabelScreenState extends State<FreeLabelScreen> {
  final s = AppStore.I;
  final _title = TextEditingController();
  final List<TextEditingController> _lines = [];
  final _qr = TextEditingController();
  bool _showCompany = true;
  bool _showPhone = true;
  bool _band = true;
  bool _border = false;
  bool _showLogo = true;
  bool _center = false;
  double _scale = 1;
  int _copies = 1;
  int _skip = 0;
  bool _busy = false;
  late String _formatId = s.printer.defaultFormatId;
  late final Uint8List? _logo =
      s.company.labelLogoB64 == null ? null : base64Decode(s.company.labelLogoB64!);

  LabelFormat get _format =>
      s.formatById(_formatId);

  static const _key = 'freeLabels';

  List<_SavedFree> get _saved {
    final raw = s.getRaw(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => _SavedFree(e['name'], Map<String, dynamic>.from(e['data'])))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    final last = s.getRaw('freeLabelLast');
    if (last != null) {
      try {
        _apply(Map<String, dynamic>.from(jsonDecode(last)));
        return;
      } catch (_) {}
    }
    _title.text = 'FRAGILE';
    _lines.addAll([
      TextEditingController(text: 'Commande : N° ………'),
      TextEditingController(text: 'Destinataire : ………'),
      TextEditingController(text: 'Tél : ………'),
    ]);
  }

  Map<String, dynamic> _toMap() => {
        'title': _title.text,
        'lines': _lines.map((e) => e.text).toList(),
        'qr': _qr.text,
        'showCompany': _showCompany,
        'showPhone': _showPhone,
        'band': _band,
        'border': _border,
        'showLogo': _showLogo,
        'center': _center,
        'scale': _scale,
      };

  void _apply(Map<String, dynamic> m) {
    _title.text = m['title'] ?? '';
    for (final c in _lines) {
      c.dispose();
    }
    _lines
      ..clear()
      ..addAll(((m['lines'] as List?) ?? []).map((e) => TextEditingController(text: '$e')));
    _qr.text = m['qr'] ?? '';
    _showCompany = m['showCompany'] ?? true;
    _showPhone = m['showPhone'] ?? true;
    _band = m['band'] ?? true;
    _border = m['border'] ?? false;
    _showLogo = m['showLogo'] ?? true;
    _center = m['center'] ?? false;
    _scale = (m['scale'] as num?)?.toDouble() ?? 1;
  }

  FreeLabelData get _data => FreeLabelData(
        company: _showCompany ? s.company.name : '',
        phone: _showPhone
            ? [s.company.phone, s.company.phone2].where((e) => e.isNotEmpty).join(' / ')
            : '',
        title: _title.text.trim(),
        lines: _lines.map((e) => e.text).toList(),
        logo: _showLogo ? _logo : null,
        companyBand: _band,
        border: _border,
        qr: _qr.text.trim(),
        align: _center ? 'center' : 'left',
        fontScale: _scale,
      );

  Future<void> _remember() => s.putRaw('freeLabelLast', jsonEncode(_toMap()));

  Future<void> _log() => s.addPrintLog(LabelPrintLog(
        productName: 'Libre : ${_title.text.trim().isEmpty ? (_lines.isEmpty ? '' : _lines.first.text) : _title.text.trim()}',
        productionDate: DateTime.now(),
        expiryDate: DateTime.now(),
        copies: _copies,
      ));

  Future<void> _printBt() async {
    if (s.printer.btAddress == null) {
      await showPrinterSheet(context);
      if (s.printer.btAddress == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await _remember();
      final err = await printPdfLabelBluetooth(
        onePagePdf: await buildFreeLabelsPdf(data: _data, format: _format),
        format: _format,
        settings: s.printer,
        copies: _copies,
      );
      if (!mounted) return;
      if (err != null) {
        snack(context, err, error: true);
      } else {
        await _log();
        if (mounted) snack(context, '$_copies étiquette(s) envoyée(s)');
      }
    } catch (e) {
      if (mounted) snack(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printSys() async {
    await _remember();
    await printPdfSystem(
        await buildFreeLabelsPdf(data: _data, format: _format, copies: _copies, skipCells: _skip),
        _format,
        'Etiquettes_libres');
    await _log();
  }

  Future<void> _saveModel() async {
    final name = TextEditingController(text: _title.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enregistrer ce modèle'),
        content: TextField(
            controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom du modèle')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final list = _saved..removeWhere((e) => e.name == name.text.trim());
    list.insert(0, _SavedFree(name.text.trim(), _toMap()));
    await s.putRaw(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
    if (mounted) {
      setState(() {});
      snack(context, 'Modèle « ${name.text.trim()} » enregistré');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isA4 = _format.mode == PrintMode.a4;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final saved = _saved;

    final form = ListView(padding: const EdgeInsets.all(16), children: [
      const PrinterBar(),
      if (saved.isNotEmpty) ...[
        const SectionTitle('Mes modèles d’étiquettes libres'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in saved)
            InputChip(
              avatar: const Icon(Icons.bookmark, size: 18, color: EColors.orange),
              label: Text(m.name),
              onPressed: () => setState(() => _apply(m.data)),
              onDeleted: () async {
                final list = saved..removeWhere((e) => e.name == m.name);
                await s.putRaw(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
                setState(() {});
              },
            ),
        ]),
      ],
      const SectionTitle('Contenu'),
      TextField(
        controller: _title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        decoration: const InputDecoration(labelText: 'Titre (en gros)', hintText: 'FRAGILE, PROMO, Poulet braisé…'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      for (final (i, c) in _lines.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: c,
            decoration: InputDecoration(
              labelText: 'Ligne ${i + 1}',
              hintText: 'Texte libre, ou « Clé : valeur »',
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _lines.removeAt(i).dispose()),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _lines.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une ligne'),
        ),
      ),
      Text('Astuce : « Clé : valeur » met la valeur en gras (ex. « Prix : 2 500 F »).',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
      const SizedBox(height: 10),
      TextField(
        controller: _qr,
        decoration: const InputDecoration(
            labelText: 'QR code (optionnel)', hintText: 'Lien, n° de commande, téléphone…', prefixIcon: Icon(Icons.qr_code)),
        onChanged: (_) => setState(() {}),
      ),
      const SectionTitle('Présentation'),
      Card(
        child: Column(children: [
          SwitchListTile(
              value: _showCompany,
              onChanged: (v) => setState(() => _showCompany = v),
              title: const Text('Nom de l’entreprise')),
          if (_showCompany)
            SwitchListTile(
                value: _band,
                onChanged: (v) => setState(() => _band = v),
                title: const Text('Nom sur bande noire')),
          SwitchListTile(
              value: _showPhone,
              onChanged: (v) => setState(() => _showPhone = v),
              title: const Text('Téléphone')),
          if (_logo != null)
            SwitchListTile(
                value: _showLogo,
                onChanged: (v) => setState(() => _showLogo = v),
                secondary: Image.memory(_logo, width: 32, height: 32),
                title: const Text('Logo')),
          SwitchListTile(
              value: _border, onChanged: (v) => setState(() => _border = v), title: const Text('Cadre')),
          SwitchListTile(
              value: _center, onChanged: (v) => setState(() => _center = v), title: const Text('Texte centré')),
          ListTile(
            title: const Text('Taille du texte'),
            subtitle: Slider(
              value: _scale,
              min: .7,
              max: 1.6,
              divisions: 9,
              label: '${(_scale * 100).round()} %',
              onChanged: (v) => setState(() => _scale = v),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      FormatPicker(value: _formatId, onChanged: (f) => setState(() => _formatId = f.id)),
      const SizedBox(height: 12),
      QuantityPicker(
        value: _copies,
        quick: [1, 5, 10, 20, 50, 100, if (isA4) _format.perSheet],
        onChanged: (v) => setState(() => _copies = v),
      ),
      if (isA4) ...[
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Cases déjà utilisées sur la planche')),
          DropdownButton<int>(
            value: _skip,
            items: [for (var i = 0; i < _format.perSheet; i++) DropdownMenuItem(value: i, child: Text('$i'))],
            onChanged: (v) => setState(() => _skip = v ?? 0),
          ),
        ]),
      ],
      const SizedBox(height: 20),
      if (btSupported && !isA4) ...[
        GradientButton(
          onPressed: _busy ? null : _printBt,
          icon: _busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bluetooth),
          label: 'Imprimer $_copies étiquette${_copies > 1 ? 's' : ''}',
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: _busy ? null : _printSys,
        icon: const Icon(Icons.print),
        label: Text(isA4 ? 'Imprimer la planche A4' : 'Imprimer (pilote / PDF)'),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextButton.icon(
              onPressed: _saveModel, icon: const Icon(Icons.bookmark_add), label: const Text('Enregistrer le modèle')),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () async {
              final b = await buildFreeLabelsPdf(data: _data, format: _format, copies: _copies, skipCells: _skip);
              await Printing.sharePdf(bytes: b, filename: 'etiquettes.pdf');
            },
            icon: const Icon(Icons.share),
            label: const Text('Partager PDF'),
          ),
        ),
      ]),
    ]);

    final preview = Container(
      color: const Color(0xFFDDE5F0),
      child: PdfPreview(
        key: ValueKey(jsonEncode(_toMap()) + _formatId + (isA4 ? '$_copies$_skip' : '')),
        build: (_) => buildFreeLabelsPdf(
            data: _data, format: _format, copies: isA4 ? _copies : 1, skipCells: _skip),
        useActions: false,
        canDebug: false,
        maxPageWidth: isA4 ? 520 : 360,
        initialPageFormat: isA4
            ? PdfPageFormat.a4
            : PdfPageFormat(_format.widthMm * PdfPageFormat.mm, _format.heightMm * PdfPageFormat.mm),
      ),
    );

    return Scaffold(
      appBar: eAppBar(title: const Text('Étiquette libre')),
      body: wide
          ? Row(children: [
              SizedBox(width: 460, child: form),
              const VerticalDivider(width: 1),
              Expanded(child: preview),
            ])
          : Column(children: [
              SizedBox(height: isA4 ? 300 : 210, child: preview),
              const Divider(height: 1),
              Expanded(child: form),
            ]),
    );
  }
}
